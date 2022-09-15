#!/usr/bin/env nextflow


/*
==============================================================================
                              wf-vsnp                              
==============================================================================
usage: nextflow run main.nf [--help]
----------------------------------------------------------------------------
*/

def helpMessage() {
    log.info"""
    =========================================
     wf-vsnp v${version}
    =========================================
    Usage:
    nextflow run -profile <docker|singularity> main.nf --inpath <input directory> --outpath <directory for results>

    Run with test data:
    nextflow run main.nf -profile test,<docker|singularity>
    
    Input/output options:
      --inpath             Path to input data directory containing FastQ assemblies. Recognized extensions are:  fastq.gz, fq.gz.
      --refpath            Path to reference data directory containing FastA files. Recognized extenesions are: fasta.
      --vcfpath            Path to vcf data directory containing .vcf files. Recognzied extensions are: vcf.
      --outpath            The output directory where the results will be saved.
    Analysis options:
      --bigdata            Whether or not to use more compute resources. Options are true, false (default).
      --max_memory         Specify memory limit on your machine/infrastructure, e.g. '128.GB'. Useful to ensure workflow doesn't request too many resources.
      --max_time           Specify time limit for each process, e.g. '240.h'. Useful to ensure workflow doesn't request too many resources.
      --max_cpus           Specify CPU limit on your machine/infrastructure, e.g. 16. Useful to ensure workflow doesn't request too many resources.
    Profile options:
      -profile singularity Use Singularity images to run the workflow. Will pull and convert Docker images from Dockerhub if not locally available.
      -profile docker      Use Docker images to run the workflow. Will pull images from Dockerhub if not locally available.
      -profile conda       TODO: this is not implemented yet.
    Other options:
      -resume              Re-start a workflow using cached results. May not behave as expected with containerization profiles docker or singularity.
      -stub                Use example output files for any process with an uncommented stub block. For debugging/testing purposes.
      -name                Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic
    """.stripIndent()
}

version = "1.0.0"
nextflow.enable.dsl=2

if (params.help) {
    helpMessage()
    exit 0
}

if (params.version){
    println "VERSION: $version"
    exit 0
}

/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

// Check if inpath parameter is specified
if (!params.inpath) {
    System.err.println "ERROR: parameter inpath must be specified"
    exit 1
}
File inpathFileObj = new File(params.inpath)
if (!inpathFileObj.exists()){
    System.err.println "ERROR: $params.inpath doesn't exist"
    exit 1
}

// Check if refpath parameter is specified
if (!params.refpath) {
    System.err.println "ERROR: parameter refpath must be specified"
    exit 1
}
File refpathFileObj = new File(params.refpath)
if (!refpathFileObj.exists()){
    System.err.println "ERROR: $params.refpath doesn't exist"
    exit 1
}

// Check if vcfpath parameter is specified
if (!params.vcfpath) {
    System.err.println "ERROR: parameter vcfpath must be specified"
    exit 1
}
File vcfpathFileObj = new File(params.vcfpath)
if (!vcfpathFileObj.exists()){
    System.err.println "ERROR: $params.vcfpath doesn't exist"
    exit 1
}

// Set outpath parameter and create directory if not found
File outpathFileObj = new File(params.outpath)
if (outpathFileObj.exists()){
    // Per the config file, outpath stores log & trace files so it is created before this point
    // Check that outpath only contains a trace file created this hour
    dayAndHour = new java.util.Date().format('yyyy-MM-dd_HH-mm-ss')
    outFiles = outpathFileObj.list()
    if (!(outFiles[0] ==~ /trace.($dayAndHour):\d\d:\d\d.txt/ && outFiles.size() == 1)) {
        // If it contains an older trace file or other files, warn the user
        System.out.println "WARNING: $params.outpath already exists. Output files will be overwritten."
    }
} else {
    outpathFileObj.mkdirs()
}

// Set logpath
File logpathFileObj = new File(params.logpath)
if (logpathFileObj.exists()){
    System.out.println "WARNING: $params.logpath already exists. Log files will be overwritten."
} else {
    logpathFileObj.mkdirs()
}

// Print parameters used
log.info """
    =====================================
    wf-vsnp $version
    =====================================
    inpath:             ${params.inpath}
    refpath:            ${params.refpath}
    outpath:            ${params.outpath}
    logpath:            ${params.logpath}
    workDir:            ${workflow.workDir}
    =====================================
    """
    .stripIndent()

/*
========================================================================================
                 Import local custom modules and subworkflows                 
========================================================================================
*/

include { STEP_1 } from "./modules/local/step_1.nf"
include { STEP_2 } from "./modules/local/step_2.nf"

/*
========================================================================================
                   Import nf-core modules and subworkflows                    
========================================================================================
*/

// None

/*
========================================================================================
                            Run the main workflow                             
========================================================================================
*/

workflow {

    // SETUP: Define input, output, and dependency channels
    input_ch = Channel.fromFilePairs(params.inpath+'/*R{1,2}*.fastq.gz', checkIfExists: true)
    ref_ch = Channel.fromPath(params.refpath, checkIfExists: true)
    vcf_ch = Channel.fromPath(params.vcfpath, checkIfExists: true)
    ch_versions = Channel.empty()

    // PROCESS: Read files from input directory, validate and stage input files
    STEP_1 (
        input_ch,
        ref_ch
    )

    ch_versions = ch_versions.mix(STEP_1.out.versions)

    STEP_2 (
        STEP_1.out.step1_vcf,
        ref_ch,
        vcf_ch
    )

    ch_versions = ch_versions.mix(STEP_2.out.versions)

    
    // PATTERN: Collate method version information
    ch_versions.collectFile(name: 'software_versions.yml', storeDir: params.logpath)
}

/*
========================================================================================
                        Completion e-mail and summary                         
========================================================================================
*/

workflow.onComplete {
    log.info """
                |=====================================
                |Pipeline Execution Summary
                |=====================================
                |Workflow Version : ${version}
                |Nextflow Version : ${nextflow.version}
                |Command Line     : ${workflow.commandLine}
                |Resumed          : ${workflow.resume}
                |Completed At     : ${workflow.complete}
                |Duration         : ${workflow.duration}
                |Success          : ${workflow.success}
                |Exit Code        : ${workflow.exitStatus}
                |Launch Dir       : ${workflow.launchDir}
                |=====================================
             """.stripMargin()
}

workflow.onError {
    def err_msg = """
                     |=====================================
                     |Error summary
                     |=====================================
                     |Completed at : ${workflow.complete}
                     |exit status  : ${workflow.exitStatus}
                     |workDir      : ${workflow.workDir}
                     |Error Report :
                     |${workflow.errorReport ?: '-'}
                     |=====================================
                  """.stripMargin()
    log.info err_msg
}


