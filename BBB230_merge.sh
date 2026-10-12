#!/bin/bash
#SBATCH --job-name=vcf_merge
#SBATCH --output=vcf_merge_%j.log
#SBATCH --error=vcf_merge_%j.err
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=04:00:00

# 1. Load required bioinformatics modules
module purge
module load BCFtools

# Define input files
VCF1="HDTom20260121_5_VCF9_20260121.vcf.gz"
VCF2="BullsHD5_5_VCF9_20230414.vcf.gz"
VCF3="BullsHD_Extra8_5_VCF9_20230504.vcf.gz"

echo "=== Step 1: Re-compressing standard gzip files to bgzip ==="

zcat ${VCF1} | bgzip -c > Bulls_HDTom_bgzip.vcf.gz
zcat ${VCF2} | bgzip -c > BullsHD5_5_bgzip.vcf.gz
zcat ${VCF3} | bgzip -c > BullsHD_Extra8_bgzip.vcf.gz

echo "=== Step 2: Indexing all input VCF files ==="
bcftools index --threads 4 Bulls_HDTom_bgzip.vcf.gz
bcftools index --threads 4 BullsHD5_5_bgzip.vcf.gz
bcftools index --threads 4 BullsHD_Extra8_bgzip.vcf.gz

echo "=== Step 3: Merging VCF files ==="
bcftools merge --threads 4 -O z -o HD_merged_output.vcf.gz \
  Bulls_HDTom_bgzip.vcf.gz \
  BullsHD5_5_bgzip.vcf.gz \
  BullsHD_Extra8_bgzip.vcf.gz

echo "=== Step 4: Indexing merged output VCF ==="
bcftools index --threads 4 HD_merged_output.vcf.gz

echo "=== Step 5: Verification ==="
echo "Total samples in merged file:"
bcftools query -l HD_merged_output.vcf.gz | wc -l

echo "Merge completed successfully!"