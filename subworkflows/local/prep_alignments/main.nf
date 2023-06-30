//
// Prepare the alignment files
//

include { SAMTOOLS_INDEX    } from '../../../modules/nf-core/samtools/index/main'
include { SAMTOOLS_CONVERT  } from '../../../modules/nf-core/samtools/convert/main'

workflow PREP_ALIGNMENTS {

    take:
    ch_crams // channel: [ val(meta), path(cram), path(crai)]
    ch_fasta // channel: [ val(meta), path(fasta) ]
    ch_fai   // channel: [ val(meta), path(fai) ]

    main:

    ch_versions = Channel.empty()

    ch_crams
        .branch { meta, cram, crai ->
            index: crai
            no_index: !crai
                return [ meta, cram ]
        }
        .set { ch_index }

    SAMTOOLS_INDEX(
        ch_index.no_index
    )
    ch_versions = ch_versions.mix(SAMTOOLS_INDEX.out.versions.first())

    ch_index.no_index
        .join(SAMTOOLS_INDEX.out.index, failOnDuplicate:true, failOnMismatch:true)
        .mix(ch_index.index)
        .branch { meta, cram, crai ->
            bam: cram.getExtension() == "bam"
            cram: cram.getExtension() == "cram"
        }
        .set { ch_convert }

    SAMTOOLS_CONVERT(
        ch_convert.cram,
        ch_fasta.map { it[1] },
        ch_fai.map { it[1] }
    )
    ch_versions = ch_versions.mix(SAMTOOLS_CONVERT.out.versions.first())

    ch_convert.bam
        .mix(SAMTOOLS_CONVERT.out.alignment_index)
        .set { ch_bams }

    emit:
    bams = ch_bams // [ val(meta), path(bam), path(bai) ]

    versions = ch_versions

}