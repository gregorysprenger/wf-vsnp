process STEP_1 {
    publishDir "${params.outpath}",
        mode: "${params.publish_dir_mode}",
        pattern: "alignment*/*"
    publishDir "${params.logpath}",
        mode: "${params.publish_dir_mode}",
        pattern: "run_log.txt"
    publishDir "${params.process_log_dir}",
        mode: "${params.publish_dir_mode}",
        pattern: ".command.*",
        saveAs: { filename -> "${task.process}${filename}" }
   
    container "gregorysprenger/vsnp3@sha256:e4abf8bfe9df05c0c14c88e95c0d57c8524d47c370ef17fe127527f6f5a5a476"

    input:
        tuple val(sample_id), path(input)
        path ref

    output:
        path "alignment*/*_zc.vcf", emit: step1_vcf
        path "alignment*/*"
        path "run_log.txt"
        path ".command.out"
        path ".command.err"
        path "versions.yml", emit: versions
        
    shell:
        '''
        source bash_functions.sh

        # !{params.refpath} is copied to work dir
        # To avoid absolute path, use work dir by using `pwd`
        vsnp3_path_adder.py -d `pwd`
        
        # Run vSNP3 Step 1
        vsnp3_step1.py -r1 !{input[0]} -r2 !{input[1]} -t !{ref}

        # Rename alignment_reference_name to alignment_sample_id
        # to allow for multiple alignments
        mv alignment* alignment_!{sample_id}

        # Get process version
        cat <<-END_VERSIONS > versions.yml
        "!{task.process}":
            vSNP3: $(vsnp3_step1.py --version | awk 'NF>1{print $NF}')
        END_VERSIONS
        '''
}