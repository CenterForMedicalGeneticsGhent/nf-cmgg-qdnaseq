//
// Get the mappability bigwig file
//

include { GEM2_GEMINDEXER           } from '../../../modules/nf-core/gem2/gemindexer/main'
include { GEM2_GEMMAPPABILITY       } from '../../../modules/nf-core/gem2/gemmappability/main'
include { GEM2_GEM2BEDMAPPABILITY   } from '../../../modules/local/gem2/gem2bedmappability/main'
include { UCSC_BEDGRAPHTOBIGWIG     } from '../../../modules/nf-core/ucsc/bedgraphtobigwig/main'

workflow FASTA_MAPPABILITY_GEM2 {

    take:
    ch_fasta        // channel: [ val(meta), path(fasta) ]
    ch_fai          // channel: [ val(meta), path(fai) ]
    val_read_length // value: the mean read length

    main:

    ch_versions = Channel.empty()

    GEM2_GEMINDEXER(
        ch_fasta
    )
    ch_versions = ch_versions.mix(GEM2_GEMINDEXER.out.versions)

    GEM2_GEMMAPPABILITY(
        GEM2_GEMINDEXER.out.index,
        val_read_length
    )
    ch_versions = ch_versions.mix(GEM2_GEMMAPPABILITY.out.versions)

    GEM2_GEM2BEDMAPPABILITY(
        GEM2_GEMMAPPABILITY.out.map,
        GEM2_GEMINDEXER.out.index
    )
    ch_versions = ch_versions.mix(GEM2_GEM2BEDMAPPABILITY.out.versions)

    UCSC_BEDGRAPHTOBIGWIG(
        GEM2_GEM2BEDMAPPABILITY.out.bedgraph,
        GEM2_GEM2BEDMAPPABILITY.out.sizes.map { it[1] }
    )

    emit:
    bigwig = UCSC_BEDGRAPHTOBIGWIG.out.bigwig

    versions = ch_versions

}