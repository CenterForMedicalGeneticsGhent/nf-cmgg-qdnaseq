#!/usr/bin/env Rscript

# load required packages
library(BiocManager)

dir.create("./BSgenome.${species}.UCSC.${genome}")

install("BSgenome.${species}.UCSC.${genome}", lib="./BSgenome.${species}.UCSC.${genome}")

sink("versions.yml")
cat("\\"task.process\\":\n")
cat("    r-biocmanager: 3.17\n")
