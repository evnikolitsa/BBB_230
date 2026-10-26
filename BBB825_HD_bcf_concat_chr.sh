#!/bin/bash
#SBATCH --job-name=bcf_concat_825hd
#SBATCH --output=bcf_concat_825hd_%j.log
#SBATCH --error=bcf_concat_825hd_%j.err
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=12:00:00

module --force purge
module load releases/2022b
module load BCFtools/1.17-GCC-12.2.0

# Clear out any old list files or broken previous outputs
rm -f beagle4.1_phased_chr_list.txt 825HD_beagle4.1_phased_genome.vcf.gz*

echo "=== Step 1: Properly compressing and indexing individual chromosome VCFs ==="
for i in {1..29}; do
    RAW_VCF="cleaned_chr_825bbb_hd_corrected_chr${i}.vcf.gz"
    
    # Check if file exists
    if [ -f "${RAW_VCF}" ]; then
        # If it's plain text disguised as .gz, uncompress and re-compress with bgzip correctly
        # (Or if it's already bgzipped, this handles it safely)
        gunzip -f "${RAW_VCF}" 2>/dev/null || true
        plain_vcf="${RAW_VCF%.gz}"
        
        bgzip -c "${plain_vcf}" > "${RAW_VCF}"
        bcftools index -t "${RAW_VCF}"
        
        echo "${RAW_VCF}" >> beagle4.1_phased_chr_list.txt
    else
        echo "Warning: ${RAW_VCF} not found!"
    fi
done

echo "=== Step 2: Concatenating chromosomes ==="
bcftools concat -f beagle4.1_phased_chr_list.txt -O z -o 825HD_beagle4.1_phased_genome.vcf.gz

echo "=== Step 3: Indexing final merged genome VCF ==="
bcftools index -t 825HD_beagle4.1_phased_genome.vcf.gz

echo "Concatenation and indexing completed successfully!"