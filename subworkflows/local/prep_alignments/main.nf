//
// Prepare the alignment files
//

include { SAMTOOLS_MERGE    } from '../../../modules/nf-core/samtools/merge/main'
include { SAMTOOLS_INDEX    } from '../../../modules/nf-core/samtools/index/main'
include { SAMTOOLS_CONVERT  } from '../../../modules/nf-core/samtools/convert/main'

workflow PREP_ALIGNMENTS {

    take:
    ch_cram     // channel: [ val(meta), path(cram), path(crai)]
    ch_fasta    // channel: [ val(meta2), path(fasta) ]
    ch_fai      // channel: [ val(meta3), path(fai) ]

    main:

    ch_versions = Channel.empty()

    ch_cram
        .groupTuple() // No size needed here because it cannot create a bottleneck
        .branch { meta, cram, crai ->
            multiple: cram.size() > 1
                return [ meta, cram ]
            single: cram.size() == 1
                return [ meta, cram[0], crai[0] ]
        }
        .set { ch_merge_input}

    SAMTOOLS_MERGE(
        ch_merge_input.multiple,
        ch_fasta,
        ch_fai
    )
    ch_versions = ch_versions.mix(SAMTOOLS_MERGE.out.versions.first())

    SAMTOOLS_MERGE.out.bam.map { it + [[]] }
        .mix(ch_merge_input.single)
        .branch { meta, cram, crai ->
            extension = cram.extension
            cram: extension == "cram"
            bam:  extension == "bam"
        }
        .set { ch_convert_input }

    SAMTOOLS_CONVERT(
        ch_convert_input.cram,
        ch_fasta.map { it[1] },
        ch_fai.map{ it[1] }
    )
    ch_versions = ch_versions.mix(SAMTOOLS_CONVERT.out.versions.first())

    SAMTOOLS_CONVERT.out.alignment_index
        .mix(ch_convert_input.bam)
        .branch { meta, bam, bai ->
            index: bai
            no_index: !bai
                return [ meta, bam ]
        }
        .set { ch_index_input }

    SAMTOOLS_INDEX(
        ch_index_input.no_index
    )
    ch_versions = ch_versions.mix(SAMTOOLS_INDEX.out.versions.first())

    ch_index_input.no_index
        .join(SAMTOOLS_INDEX.out.index, failOnDuplicate:true, failOnMismatch:true)
        .mix(ch_index_input.index)
        .map { meta, bam, bai ->
            [ [id:"bams"], bam, bai ]
        }
        .groupTuple()
        .collect()
        .set { ch_bams_out }

    emit:
    bams = ch_bams_out // [ val(meta), path(bam), path(bai) ]

    versions = ch_versions

}