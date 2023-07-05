#!/usr/bin/env Rscript

# load required packages
library(Biobase)
library(BiocManager)
library(QDNAseq)
library(future)

library($genomes, lib.loc="$genomes")

binsize <- ${bin_size}

bins <- createBins(bsgenome=$genomes, binSize=binsize)
bins\$mappability <- calculateMappability(
    bins,
    bigWigFile="${bigwig}",
    bigWigAverageOverBed="bigWigAverageOverBed"
)

bins\$blacklist <- calculateBlacklist(bins, bedFiles=c("${blacklist}"))

bins\$residual <- NA
bins\$use <- bins\$bases > 0

#
tg <- binReadCounts(bins, path="bams")

bins\$residual <- iterateResiduals(tg)

bins <- AnnotatedDataFrame(bins,
    varMetadata=data.frame(
        labelDescription=c(
            "Chromosome name",
            "Base pair start position",
            "Base pair end position",
            "Percentage of non-N nucleotides (of full bin size)",
            "Percentage of C and G nucleotides (of non-N nucleotides)",
            "Average mappability of 50mers with a maximum of 2 mismatches",
            "Percent overlap with ENCODE blacklisted regions",
            "Median loess residual from 1000 Genomes (50mers)",
            "Whether the bin should be used in subsequent analysis steps"
        ),
        row.names=colnames(bins)
    )
)

save(bins, file=paste0("${params.annotation_genome}.${bin_size}kbp.rds"), compress='xz')

sink("versions.yml")
cat("\\"task.process\\":\n")
cat("    bioconductor-qdnaseq: 1.34.0\n")
cat("    bioconductor-biobase: 2.58.0\n")
cat("    ucsc-bigwigaverageoverbed: 377\n")
