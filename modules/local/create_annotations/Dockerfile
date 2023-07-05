FROM mambaorg/micromamba:1.4-focal

LABEL version="0.0.3" maintainer="Nicolas Vannieuwkerke <nicolas.vannieuwkerke@ugent.be>"

RUN micromamba install -y --name base -c conda-forge -c bioconda -c defaults \
    bioconductor-qdnaseq==1.34.0 \
    bioconductor-biobase==2.58.0 \
    bioconductor-bsgenome==1.66.3 \
    ucsc-bigwigaverageoverbed==377 \
    r-biocmanager==1.30.21 \
    r-xml==3.99_0.14 \
    r-restfulr==0.0.15 \
    bioconductor-rtracklayer==1.58.0 \
    r-r.cache==0.16.0 \
    r-lsr==0.5.2 \
    && micromamba clean --all --yes

ARG MAMBA_DOCKERFILE_ACTIVATE=1
