//
// Get the mappability bigwig file
//

include { GAWK                  } from '../../../modules/nf-core/gawk/main'
include { GENMAP_INDEX          } from '../../../modules/nf-core/genmap/index/main'
include { GENMAP_MAP            } from '../../../modules/nf-core/genmap/map/main'
include { UCSC_WIGTOBIGWIG      } from '../../../modules/nf-core/ucsc/wigtobigwig/main'

workflow FASTA_MAPPABILITY_GENMAP {

    take:
    ch_fasta        // channel: [ val(meta), path(fasta) ]
    ch_fai          // channel: [ val(meta), path(fai) ]

    main:

    ch_versions = Channel.empty()

    GAWK(
        ch_fai,
        []
    )
    ch_versions = ch_versions.mix(GAWK.out.versions)

    GENMAP_INDEX(
        ch_fasta
    )
    ch_versions = ch_versions.mix(GENMAP_INDEX.out.versions)

    GENMAP_MAP(
        GENMAP_INDEX.out.index,
        [[],[]]
    )
    ch_versions = ch_versions.mix(GENMAP_MAP.out.versions)

    UCSC_WIGTOBIGWIG(
        GENMAP_MAP.out.wig,
        GAWK.out.output.map { it[1] }
    )
    ch_versions = ch_versions.mix(UCSC_WIGTOBIGWIG.out.versions)

    emit:
    bigwig = UCSC_WIGTOBIGWIG.out.bw

    versions = ch_versions

}