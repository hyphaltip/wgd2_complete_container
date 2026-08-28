# container_wgd2_complete

A **complete** container image for [wgd](https://github.com/arzwa/wgd) 2.0.38 —
whole-genome duplication dating — published to GitHub Container Registry
(`ghcr.io/hyphaltip/container_wgd2_complete`).

## Why "complete"

The official biocontainer `quay.io/biocontainers/wgd:2.0.38--pyhdfd78af_0` is a
`noarch: python` package whose recipe has only `mafft, paml, diamond, mcl` as run
dependencies. The published image therefore cannot run anything non-trivial — it
lacks numpy/scipy/biopython/click (so even `wgd --help` fails) and every external
CLI that `wgd dmd` / `wgd ksd` / `wgd syn` need (FastTree, muscle, mafft, paml,
diamond, mcl, phyml, i-ADHoRe, zoem).

This image vendors all of them:

| Component        | Version      | Source                                                              |
|------------------|--------------|---------------------------------------------------------------------|
| wgd              | 2.0.38       | PyPI (`pip install --no-deps` + relaxed dep set, see below)         |
| python           | 3.9          | conda-forge (wgd 2.0.38's old pins require py3.9 wheels)            |
| diamond / mcl / mafft / paml / fasttree / muscle / phyml | latest bioconda | conda-forge + bioconda                          |
| cimfomfa/tingea  | 21-341       | micans.org release tarball (autotools)                              |
| zoem             | 21-341       | micans.org release tarball (autotools)                              |
| i-ADHoRe         | 3.0          | VIB-PSB/i-ADHoRe tag `3.0` (CMake)                                  |

The cimfomfa/zoem `21-341` and i-ADHoRe `3.0` versions intentionally match the
HPCC `module load wgd` toolchain (`/rhome/jstajich/local_modules/wgd/2`) that this
distribution was validated against.

### wgd python dependencies

wgd 2.0.38's `setup.py` hard-pins ancient versions (e.g. `numpy==1.19.0`,
`matplotlib==3.2.2`, `tornado==6.0.4`, `fastcluster==1.1.28`), many with no py3.9
wheels. We install `wgd==2.0.38 --no-deps` and then the relaxed, wheel-compatible
set in [`requirements-wgd.txt`](requirements-wgd.txt) (the exact set verified to
run `wgd dmd` and `wgd ksd`). The GUI-only `pyqt5`/`pyqtwebengine` are omitted.

## Versioning

- `VERSION` holds the wgd version (currently `2.0.38`); it is the default tag
  for `main` builds.
- Release tags follow `v<version>`, e.g. `v2.0.38` — they drive `:latest` /
  `:<version>` image tags.

## Building locally (HPCC, apptainer only — no docker daemon)

Build the SIF from the in-repo [`wgd.def`](wgd.def) (kept in sync with the
[Dockerfile](Dockerfile)) under SLURM — login-node builds hit the interactive
session's 24 GB memory cap:

```bash
sbatch -p epyc build_slurm.sh     # module load apptainer; ./pull_sif.sh
```

`pull_sif.sh` produces `wgd-2.0.38.sif`. Cache/tmp are forced onto node-local
`$SCRATCH` so the multi-step build (conda solve + pip + three C toolchains)
does not fill an NFS home quota.

With docker (anywhere else, e.g. CI):

```bash
docker build -t container_wgd2_complete:2.0.38 --build-arg WGD_VERSION=2.0.38 .
```

## Pulling from ghcr.io (recommended)

```bash
module load apptainer squashfuse   # squashfuse gives native SIF mounts (fast)
apptainer pull wgd.sif docker://ghcr.io/hyphaltip/container_wgd2_complete:2.0.38
```

### Running wgd from the container

`wgd ksd` shells out to `mafft`, whose wrapper needs a *writable* `$TMPDIR`.
Inside the container `/scratch` is not writable by default, and the host
`$TMPDIR` (a node-local scratch path) is not mounted. Bind `$SCRATCH`
(fail-loud if unset) and point `TMPDIR` at it:

```bash
module load apptainer squashfuse
apptainer exec --bind "${SCRATCH:?}:${SCRATCH:?}" --env TMPDIR="${SCRATCH:?}" \
    wgd.sif wgd ksd wgd_dmd/cds.fa.tsv cds.fa
```

Outside the HPCC, `--bind`/`--env TMPDIR=/tmp` are typically unnecessary
(`/tmp` inside the container is writable); only the HPCC's node-local
scratch-based `$TMPDIR` breaks mafft.

## Smoke test

```bash
./smoke_test.sh wgd-2.0.38.sif     # wgd --help, dmd, ksd on the bundled 6-gene test set
```

## Automated builds

GitHub Actions (`.github/workflows/build.yml`) builds and pushes the image on
every push to `main`, every `v*` tag, and manual `workflow_dispatch`, then signs
it with Cosign and attaches a SLSA provenance attestation. No repo secrets
required — signing uses the workflow's OIDC token.

Tags published by CI:

| Event          | Tags                              |
|----------------|-----------------------------------|
| push to `main` | `:latest`, `:main`                |
| tag `v<ver>`   | `:<version>`, `:latest`           |
