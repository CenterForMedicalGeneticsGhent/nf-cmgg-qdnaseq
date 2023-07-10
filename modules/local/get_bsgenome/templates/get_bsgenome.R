#!/usr/bin/env Rscript

# load required packages
library(BiocManager)

Sys.setenv("R_LIBS_SITE" = "BSgenome.${species}.UCSC.${genome}")

dir.create("./BSgenome.${species}.UCSC.${genome}")

install("BSgenome.${species}.UCSC.${genome}", lib="BSgenome.${species}.UCSC.${genome}")

sink("versions.yml")
cat("\\"task.process\\":\n")
cat("    r-biocmanager: 1.30.21\n")
