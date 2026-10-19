#!/bin/bash
#SBATCH --job-name=vcf_merge
#SBATCH --output=vcf_merge_%j.log
#SBATCH --error=vcf_merge_%j.err
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=04:00:00

# 1. Load required bioinformatics modules
module purge
module load releases/2022b
module load BCFtools/1.17-GCC-12.2.0

set -euo pipefail

# Define input files
VCF1="HDTom20260121_5_VCF9_20260121.vcf.gz"
VCF2="BullsHD5_5_VCF9_20230414.vcf.gz"
VCF3="BullsHD_Extra8_5_VCF9_20230504.vcf.gz"

echo "=== Step 1: Re-compressing standard gzip files to bgzip ==="
zcat ${VCF1} | bgzip -c > BullsHDTom_bgzip.vcf.gz
zcat ${VCF2} | bgzip -c > BullsHD5_5_bgzip.vcf.gz
zcat ${VCF3} | bgzip -c > BullsHD_Extra8_bgzip.vcf.gz

echo "=== Step 2: Filtering VCFs to keep only standard cattle chromosomes (1-29, X) ==="
# This drops unplaced scaffolds like chr1000 where allele mismatches occur
# Defining standard cattle chromosomes with 'chr' prefix (adjust if your VCF uses bare numbers like 1, 2...)
CHRS="chr1,chr2,chr3,chr4,chr5,chr6,chr7,chr8,chr9,chr10,chr11,chr12,chr13,chr14,chr15,chr16,chr17,chr18,chr19,chr20,chr21,chr22,chr23,chr24,chr25,chr26,chr27,chr28,chr29,chrX"

bcftools view -r ${CHRS} BullsHDTom_bgzip.vcf.gz -Oz -o BullsHDTom_filtered.vcf.gz
bcftools view -r ${CHRS} BullsHD5_5_bgzip.vcf.gz -Oz -o BullsHD5_5_filtered.vcf.gz
bcftools view -r ${CHRS} BullsHD_Extra8_bgzip.vcf.gz -Oz -o BullsHD_Extra8_filtered.vcf.gz

echo "=== Step 3: Indexing filtered VCF files ==="
bcftools index --threads 4 BullsHDTom_filtered.vcf.gz
bcftools index --threads 4 BullsHD5_5_filtered.vcf.gz
bcftools index --threads 4 BullsHD_Extra8_filtered.vcf.gz


echo "=== Step 4: List the exact chromosome, position, and alleles (variants) that are missing from specific files (bcftools isec -p (intersection)) ==="

# Check whether the exact same set of variants is present across all three filtered VCF files

bcftools isec -p vcf_diff_output \
  BullsHDTom_filtered.vcf.gz \
  BullsHD5_5_filtered.vcf.gz \
  BullsHD_Extra8_filtered.vcf.gz
  
echo "File 1 count:" && bcftools view -H BullsHDTom_filtered.vcf.gz | wc -l
echo "File 2 count:" && bcftools view -H BullsHD5_5_filtered.vcf.gz | wc -l
echo "File 3 count:" && bcftools view -H BullsHD_Extra8_filtered.vcf.gz | wc -l
  
awk '$NF != "111" {print $1, $2, $3, $4, "Flags:", $NF}' vcf_diff_output/sites.txt
awk '$NF == "111" {count++} END {print "Shared in all 3 files:", count}' vcf_diff_output/sites.txt

# 110: Present in File 1 & File 2, missing in File 3
# 101: Present in File 1 & File 3, missing in File 2
# 011: Present in File 2 & File 3, missing in File 1
# 100, 010, 001: Unique to only one file

echo "=== Step 5: Merging VCF files ==="
bcftools merge --threads 4 -O z -o HD_merged_output.vcf.gz \
  BullsHDTom_filtered.vcf.gz \
  BullsHD5_5_filtered.vcf.gz \
  BullsHD_Extra8_filtered.vcf.gz

echo "=== Step 6: Indexing merged output VCF ==="
bcftools index --threads 4 HD_merged_output.vcf.gz

echo "=== Step 8: Extracting Sample IDs (NOANs) ==="
bcftools query -l HD_merged_output.vcf.gz | sort -u > unique_TestIDs.txt
echo "Extracted $(wc -l < unique_TestIDs.txt) unique sample IDs to unique_TestIDs.txt."

echo "Merge completed successfully!"