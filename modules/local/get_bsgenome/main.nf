process GET_BSGENOME {
    tag "$genome"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://datasets.datalad.org/shub/Bioconductor/bioconductor_docker/release_3_12/2021-04-08-792069e8-db467071/db4670716951ba90ef19e9af4cb734b9.sif' :
        'docker.io/bioconductor/bioconductor:3.12' }"

    input:
    val(genome)
    val(species)

    output:
    path("BSgenome.${species}.UCSC.${genome}")  , emit: genome
    path "versions.yml"                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    template "get_bsgenome.R"

    stub:
    """
    mkdir BSgenome.${species}.UCSC.${genome}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-biocmanager: 3.17
    END_VERSIONS
    """
}
