#!/usr/bin/env bash
# Build the wgd Apptainer SIF from the repo's wgd.def (kept in sync with the
# Dockerfile used by CI).
#
# Named pull_sif.sh to match the sibling container dirs; this one BUILDS from
# the def file rather than pulling a ready-made .sif, so no remote image is
# needed. Requires --fakeroot, which is enabled on this cluster. Run under
# SLURM (see build_slurm.sh) — local login-node builds hit the interactive
# session's 24GB memory cap.
#
# Cache and tmp are forced onto node-local $SCRATCH: apptainer defaults them
# under $HOME, and this multi-stage build (conda solve + pip + three C
# toolchains) would fill an NFS home quota.
#
# Usage:
#   module load apptainer
#   ./pull_sif.sh [dest-path]
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(tr -d '[:space:]' < "$HERE/VERSION")"
DEST="${1:-$HERE/wgd-${VERSION}.sif}"

module load apptainer 2>/dev/null || true

export APPTAINER_CACHEDIR="${APPTAINER_CACHEDIR:-${SCRATCH:-/tmp}/apptainer_cache}"
export APPTAINER_TMPDIR="${APPTAINER_TMPDIR:-${SCRATCH:-/tmp}/apptainer_tmp}"
mkdir -p "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR"

echo "Building $HERE/wgd.def -> $DEST (version $VERSION)" >&2
apptainer build --fakeroot -F "$DEST" "$HERE/wgd.def"
