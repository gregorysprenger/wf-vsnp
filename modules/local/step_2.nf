process STEP_2 {
    publishDir "${params.outpath}",
        mode: "${params.publish_dir_mode}",
        pattern: "*.zip"
    publishDir "${params.outpath}",
        mode: "${params.publish_dir_mode}",
        pattern: "*/*"
    publishDir "${params.logpath}",
        mode: "${params.publish_dir_mode}",
        pattern: "*.html"
    publishDir "${params.process_log_dir}",
        mode: "${params.publish_dir_mode}",
        pattern: ".command.*",
        saveAs: { filename -> "${task.process}${filename}" }
   
    container "gregorysprenger/vsnp3@sha256:e4abf8bfe9df05c0c14c88e95c0d57c8524d47c370ef17fe127527f6f5a5a476"

    input:
        path step1_vcf
        path ref
        path vcfs

    output:
        path "*/*"
        path "*.zip"
        path "*.html"
        path ".command.out"
        path ".command.err"
        path "versions.yml", emit: versions
        
    shell:
        '''
        source bash_functions.sh

        # !{params.refpath} is copied to work dir
        # To avoid absolute path, use work dir by using `pwd`
        vsnp3_path_adder.py -d `pwd`

        # Copy vcf from Step 1 to vcf folder
        cp !{step1_vcf} !{vcfs}/

        # Run vSNP3 Step 2
        vsnp3_step2.py -wd !{vcfs} -t !{ref}

        # Clean up work dir before they are moved to publishdir
        rm !{vcfs}/!{step1_vcf}
        rm !{ref}
        rm !{vcfs}

        # Get process version
        cat <<-END_VERSIONS > versions.yml
        "!{task.process}":
            vSNP3: $(vsnp3_step1.py --version | awk 'NF>1{print $NF}')
        END_VERSIONS
        '''
}