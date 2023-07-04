//
// Prepare the alignment files
//

include { TRIMGALORE        } from '../../../modules/nf-core/trimgalore/main'
include { BWA_ALN           } from '../../../modules/nf-core/bwa/aln/main'
include { BWA_SAMSE         } from '../../../modules/nf-core/bwa/samse/main'
include { BWA_SAMPE         } from '../../../modules/nf-core/bwa/sampe/main'
include { SAMTOOLS_INDEX    } from '../../../modules/nf-core/samtools/index/main'

workflow PREP_ALIGNMENTS {

    take:
    ch_fastq        // channel: [ val(meta), path(fastq_1), path(fastq_2)]
    ch_bwa_index    // channel: [ val(meta2), path(index) ]

    main:

    ch_versions = Channel.empty()

    TRIMGALORE(
        ch_fastq
    )
    ch_versions = ch_versions.mix(TRIMGALORE.out.versions.first())

    BWA_ALN(
        TRIMGALORE.out.reads,
        ch_bwa_index
    )
    ch_versions = ch_versions.mix(BWA_ALN.out.versions.first())

    ch_fastq
        .join(BWA_ALN.out.sai, failOnDuplicate:true, failOnMismatch:true)
        .branch { meta, reads, sai ->
            single_end: meta.single_end
            paired_end: !meta.single_end
        }
        .set { ch_sai }

    BWA_SAMSE(
        ch_sai.single_end,
        ch_bwa_index
    )
    ch_versions = ch_versions.mix(BWA_SAMSE.out.versions.first())

    BWA_SAMPE(
        ch_sai.paired_end,
        ch_bwa_index
    )
    ch_versions = ch_versions.mix(BWA_SAMPE.out.versions.first())

    BWA_SAMPE.out.bam
        .mix(BWA_SAMSE.out.bam)
        .set { ch_bams }

    SAMTOOLS_INDEX(
        ch_bams
    )
    ch_versions = ch_versions.mix(SAMTOOLS_INDEX.out.versions.first())

    ch_bams
        .join(SAMTOOLS_INDEX.out.index)
        .map { meta, bam, bai ->
            [ [id:"bams"], bam, bai]
        }
        .groupTuple()
        .collect()
        .set { ch_bams_out }

    emit:
    bams = ch_bams_out // [ val(meta), path(bam), path(bai) ]

    versions = ch_versions

}