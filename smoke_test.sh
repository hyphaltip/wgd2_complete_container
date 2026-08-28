#!/usr/bin/env bash
# Smoke-test a wgd image/sif: --help, dmd, and ksd on the bundled 6-gene
# synthetic test set (3 paralog families). Exits non-zero on any failure.
#
# Runs the work under $SCRATCH (node-local) and binds it read-write into the
# container so mafft's temp dir works (/scratch is not writable inside the
# image by default and the host TMPDIR points into it).
#
# Usage:
#   ./smoke_test.sh <image>          # image = path to .sif OR docker://ghcr.io/...
set -euo pipefail

source /etc/profile.d/modules.sh >/dev/null 2>&1 || true
module load apptainer squashfuse fuse >/dev/null 2>&1 || true

HERE="$(cd "$(dirname "$0")" && pwd)"
IMG="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
[ -e "$IMG" ] || { echo "image not found: $1" >&2; exit 1; }
SCR="${SCRATCH:?SCRATCH is unset/empty: run on the HPCC (node-local scratch required)}"
RUN="apptainer exec --bind ${SCR}:${SCR} --env TMPDIR=${SCR} "$IMG""

TMP="$(mktemp -d "${SCR}/wgd-smoke.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
cp "$HERE/test/cds.fa" "$TMP/"
cd "$TMP"

echo "== wgd --help =="
$RUN wgd --help >/dev/null
echo "   ok"

echo "== wgd dmd =="
$RUN wgd dmd cds.fa >/dev/null
test -s wgd_dmd/cds.fa.tsv
N_FAM="$(cut -f2 wgd_dmd/cds.fa.tsv | tail -n +2 | sort -u | wc -l)"
echo "   ok: $N_FAM paralog families detected"
test "$N_FAM" -eq 3

echo "== wgd ksd =="
$RUN wgd ksd wgd_dmd/cds.fa.tsv cds.fa >/dev/null
ls wgd_ksd/cds.fa.tsv.ks.tsv >/dev/null
echo "   ok: wgd_ksd/cds.fa.tsv.ks.tsv produced"

echo "SMOKE TEST PASSED"
