# =============================================================================
# wgd 2.0.38 — whole-genome duplication dating (https://github.com/arzwa/wgd)
#
# A COMPLETE wgd distribution. The official biocontainer
# (quay.io/biocontainers/wgd:2.0.38--pyhdfd78af_0) is a `noarch` python package
# that carries almost none of wgd's runtime dependencies (no numpy/scipy/
# biopython/click...) and none of the external CLIs (FastTree, muscle, mafft,
# paml, diamond, mcl, phyml, i-ADHoRe, zoem). This image vendors every one of
# them so wgd dmd / ksd / syn / mix / peak / viz all work out of the box.
#
# Build (default version from VERSION file):
#   docker build -t container_wgd2_complete:2.0.38 .
#
# Local HPC build with apptainer (no docker daemon on cluster): build from the
# in-repo wgd.def (kept in sync with this Dockerfile) -- see pull_sif.sh.
#
# Run on HPCC:
#   apptainer exec wgd-2.0.38.sif wgd --help
#
# Version matrix:
#   python 3.9            wgd 2.0.38 requires old pinned deps with py39 wheels
#   cimfomfa/zoem 21-341  same tags as the HPCC module build (mcl dep)
#   i-ADHoRe 3.0          matches HPCC module wgd/2 (not 3.1)
# =============================================================================

FROM mambaorg/micromamba:2.0.5-ubuntu22.04

# Version of wgd to install (the CI workflow passes this as a build arg from
# the VERSION file or the git tag; default keeps source-controlled build simple).
ARG WGD_VERSION=2.0.38

# micromamba image defaults to a non-root user; we need root for apt + builds.
USER root
ENV MAMBA_ROOT_PREFIX=/opt/conda \
    PATH="/opt/conda/bin:$PATH" \
    BIO_ROOT=/opt/bio

# ---------------------------------------------------------------------------
# 1. Build toolchain + base system deps
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        autoconf \
        automake \
        libtool \
        pkg-config \
        perl \
        libpng-dev \
        wget \
        git \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 2. Conda: python 3.9 + wgd's external CLIs from bioconda
#    (bioconda has diamond, mcl, mafft, paml, fasttree, muscle, phyml;
#     i-ADHoRe and zoem are NOT on conda -- built from source in step 4)
# ---------------------------------------------------------------------------
RUN micromamba install -y -n base -c conda-forge -c bioconda \
        python=3.9 \
        diamond \
        mcl \
        mafft \
        paml \
        fasttree \
        muscle \
        phyml \
    && micromamba clean -ay

# ---------------------------------------------------------------------------
# 3. wgd + python deps
#    wgd 2.0.38's setup.py hard-pins ancient versions (numpy==1.19.0 etc.) many
#    of which have no py3.9 wheels. Install wgd with --no-deps, then install the
#    relaxed, py3.9-wheel-compatible set from requirements-wgd.txt (the set
#    verified to make wgd dmd/ksd run).
# ---------------------------------------------------------------------------
RUN mkdir -p /opt/wgd
COPY requirements-wgd.txt /opt/wgd/requirements-wgd.txt
RUN /opt/conda/bin/python -m pip install --no-cache-dir --no-deps wgd==${WGD_VERSION} && \
    /opt/conda/bin/python -m pip install --no-cache-dir \
        --requirement /opt/wgd/requirements-wgd.txt
# wgd's cli.py calls pkg_resources.require("wgd"), which validates the original
# hard-pinned Requires-Dist; relax == to >= and drop the GUI-only pyqt deps.
RUN /opt/conda/bin/python - <<'PY'
import glob, re
paths = (glob.glob('/opt/conda/lib/python3.9/site-packages/wgd-*.dist-info/METADATA')
         + glob.glob('/opt/conda/lib/python3.9/site-packages/wgd.egg-info/requires.txt'))
for path in paths:
    s = open(path).read()
    s = re.sub(r'(?m)^Requires-Dist: pyqt.*\n', '', s)
    s = s.replace('==', '>=')
    open(path, 'w').write(s)
    print("relaxed", path)
PY

# ---------------------------------------------------------------------------
# 4. cimfomfa/tingea + zoem (autotools, release tarballs from micans.org --
#    the git repos ship no generated `configure`; 21-341 matches HPCC)
# ---------------------------------------------------------------------------
RUN mkdir -p /tmp/micans && cd /tmp/micans \
    && wget -q http://micans.org/cimfomfa/src/cimfomfa-21-341.tar.gz \
    && tar xzf cimfomfa-21-341.tar.gz \
    && cd cimfomfa-21-341 \
    && ./configure --prefix=${BIO_ROOT} \
    && make -j"$(nproc)" \
    && make install \
    && cd /tmp/micans \
    && wget -q http://micans.org/zoem/src/zoem-21-341.tar.gz \
    && tar xzf zoem-21-341.tar.gz \
    && cd zoem-21-341 \
    && ./configure CFLAGS="-I${BIO_ROOT}/include -fcommon" LDFLAGS="-L${BIO_ROOT}/lib" \
           --prefix=${BIO_ROOT} \
    && make -j"$(nproc)" \
    && make install \
    && cd /tmp \
    && rm -rf /tmp/micans

# ---------------------------------------------------------------------------
# 5. i-ADHoRe 3.0 (CMake build, official source; 3.0 not 3.1 to match the
#    validated HPCC module wgd/2 toolchain)
# ---------------------------------------------------------------------------
RUN git clone --depth 1 --branch 3.0 https://github.com/VIB-PSB/i-ADHoRe.git /tmp/i-ADHoRe \
    && mkdir /tmp/i-ADHoRe/build \
    && cd /tmp/i-ADHoRe/build \
    && cmake .. -DCMAKE_INSTALL_PREFIX=${BIO_ROOT} \
    && make -j"$(nproc)" \
    && make install \
    && rm -rf /tmp/i-ADHoRe

# ---------------------------------------------------------------------------
# 6. Environment
# ---------------------------------------------------------------------------
ENV PATH="${BIO_ROOT}/bin:/opt/conda/bin:${PATH}" \
    PERL5LIB="${BIO_ROOT}/API"

WORKDIR /data
LABEL org.opencontainers.image.title="wgd"
LABEL org.opencontainers.image.description="Complete wgd 2.0.38 distribution: python deps + diamond/mcl/mafft/paml/fasttree/muscle/phyml/i-ADHoRe/zoem"
LABEL org.opencontainers.image.source="https://github.com/hyphaltip/container_wgd2_complete"
LABEL org.opencontainers.image.licenses="MIT"

CMD ["wgd", "--help"]
