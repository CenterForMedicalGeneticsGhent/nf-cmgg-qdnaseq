process GET_BSGENOME {
    tag "$genome"
    label 'process_single'

    container 'docker.io/bioconductor/bioconductor:3.17'

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
