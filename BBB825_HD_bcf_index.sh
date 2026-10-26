#!/bin/bash
#SBATCH --job-name=bcf_index_825hd
#SBATCH --output=bcf_index_825hd_%j.log
#SBATCH --error=bcf_index_825hd_%j.err
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=12:00:00

module purge
module load releases/2022b
module load BCFtools/1.17-GCC-12.2.0

echo "=== Step 1: Fix VCF header by removing PLINK2's custom chrSet line ==="
# This reads the zipped VCF, removes the incompatible header line, and creates a clean file
zcat HD_qc_mind95_clean.vcf.gz | grep -v "##chrSet" | bgzip > HD_qc_mind95_clean_fixed.vcf.gz

echo "=== Step 2: Index the fixed cleaned VCF ==="
bcftools index -f -t HD_qc_mind95_clean_fixed.vcf.gz

echo "=== Step 3: Count number of variants in cleaned VCF ==="
bcftools view -H HD_qc_mind95_clean_fixed.vcf.gz | wc -l

echo "=== Step 4: Extracting Sample IDs in the cleaned VCF ==="
bcftools query -l HD_qc_mind95_clean_fixed.vcf.gz | sort -u > cleaned95_Test_IDs.txt

echo "Done! Use HD_qc_mind95_clean_fixed.vcf.gz for your Beagle array script."