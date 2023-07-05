/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PRINT PARAMS SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryLog; paramsSummaryMap; fromSamplesheet } from 'plugin/nf-validation'

def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
def citation = '\n' + WorkflowMain.citation(workflow) + '\n'
def summary_params = paramsSummaryMap(workflow)

// Print parameter summary log to screen
log.info logo + paramsSummaryLog(workflow) + citation

WorkflowQdnaseq.initialise(params, log)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { FASTA_MAPPABILITY_GENMAP  } from '../subworkflows/local/fasta_mappability_genmap/main'
include { PREP_ALIGNMENTS           } from '../subworkflows/local/prep_alignments/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { SAMTOOLS_FAIDX              } from '../modules/nf-core/samtools/faidx/main'
include { TABIX_BGZIP                 } from '../modules/nf-core/tabix/bgzip/main'
include { GET_BSGENOME                } from '../modules/local/get_bsgenome/main'
include { CREATE_ANNOTATIONS          } from '../modules/local/create_annotations/main'
include { MULTIQC                     } from '../modules/nf-core/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []


workflow QDNASEQ {

    ch_versions = Channel.empty()

    ch_fasta = Channel.fromPath(params.fasta).map { [[id:'reference'], it] }.collect()

    // FASTA index
    if(!params.fai) {
        SAMTOOLS_FAIDX(
            ch_fasta
        )
        ch_versions = ch_versions.mix(SAMTOOLS_FAIDX.out.versions)

        SAMTOOLS_FAIDX.out.fai.collect().set { ch_fai }
    } else {
        ch_fai = Channel.fromPath(params.fai).map { [[id:'reference'], it] }.collect()
    }

    // Blacklist BED
    if(!params.blacklist) {
        encode_url = "https://github.com/Boyle-Lab/Blacklist/raw/master/lists"
        blacklist = file("${encode_url}/${params.annotation_genome}-blacklist.v2.bed.gz")
        if(!blacklist.exists()) {
            exit 1, "Cannot find a blacklist file for ${params.annotation_genome}. Please supply one with the --blacklist option. (Also mind that the pipeline expects short notations of the --annotation_genome (e.g. hg38 instead of GRCh38))"
        }
        ch_blacklist_input = Channel.of([[id:"blacklist_${params.annotation_genome}"], blacklist])
    } else {
        ch_blacklist_input = Channel.of([[id:"blacklist_${params.annotation_genome}"], file(params.blacklist, checkIfExists:true)])
    }

    ch_blacklist_input
        .branch { meta, bed ->
            extension = bed.getExtension()
            no_gz: extension != "gz"
            gz: extension == "gz"
        }
        .set { ch_gz_input }

    TABIX_BGZIP(
        ch_gz_input.gz
    )
    ch_versions = ch_versions.mix(TABIX_BGZIP.out.versions)

    ch_gz_input.no_gz
        .mix(TABIX_BGZIP.out.output)
        .collect()
        .set { ch_blacklist }

    // Samplesheet
    Channel.fromSamplesheet("input", immutable_meta:false)
        .map { cram, crai ->
            meta = [id:cram.baseName]
            [ meta, cram, crai ]
        }
        .set { ch_cram }

    //
    // Prepare the alignment files
    //

    PREP_ALIGNMENTS(
        ch_cram,
        ch_fasta,
        ch_fai
    )
    ch_versions = ch_versions.mix(PREP_ALIGNMENTS.out.versions)

    //
    // Define the mappability of the reference FASTA
    //

    FASTA_MAPPABILITY_GENMAP(
        ch_fasta,
        ch_fai
    )
    ch_versions = ch_versions.mix(FASTA_MAPPABILITY_GENMAP.out.versions)

    //
    // Get the BSgenome for the genome
    //

    GET_BSGENOME(
        params.annotation_genome,
        params.species
    )
    ch_versions = ch_versions.mix(GET_BSGENOME.out.versions)

    //
    // Create the qdnaseq annotations
    //

    CREATE_ANNOTATIONS(
        Channel.fromList(params.bin_sizes.tokenize(",")),
        PREP_ALIGNMENTS.out.bams,
        FASTA_MAPPABILITY_GENMAP.out.bigwig,
        ch_blacklist,
        GET_BSGENOME.out.genome.collect()
    )
    ch_versions = ch_versions.mix(CREATE_ANNOTATIONS.out.versions.first())

    //
    // Dump software versions
    //

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowQdnaseq.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowQdnaseq.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description, params)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )
    multiqc_report = MULTIQC.out.report.toList()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
