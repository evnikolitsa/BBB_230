#!/bin/bash
#SBATCH --job-name=vcf_merge_qc
#SBATCH --output=vcf_merge_qc_%j.log
#SBATCH --error=vcf_merge_qc_%j.err
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=12:00:00

# Halt execution immediately if any command or pipe fails
set -eo pipefail

# ------------------------------------------------------------------------------
# 1. Load Environment Modules (NIC5 Toolchain: releases/2022a)
# ------------------------------------------------------------------------------
module purge
module load releases/2022a
module load PLINK/2.00a3.7-foss-2022a

# Clean up broken/intermediate output from previous failed attempts
rm -f HD_merged_raw.* vcf_merge_list.txt

# Input VCF File Names
VCF1="HDTom20260121_5_VCF9_20260121.vcf.gz"
VCF2="BullsHD5_5_VCF9_20230414.vcf.gz"
VCF3="BullsHD_Extra8_5_VCF9_20230504.vcf.gz"

PEDIGREE_FILE="pedigree.fam"
UNIQUE_NOANS="unique_NOANs.txt"

THREADS=${SLURM_CPUS_PER_TASK:-8}

# ------------------------------------------------------------------------------
# 2. Directly Merge VCFs into PLINK2 Binary Format
# ------------------------------------------------------------------------------
echo "=== Step 1: Creating VCF Merge List ==="
cat << EOF > vcf_merge_list.txt
${VCF1}
${VCF2}
${VCF3}
EOF

echo "=== Step 2: Directly Converting & Merging VCFs into PLINK2 Format ==="
plink2 --vcf-merge-list vcf_merge_list.txt \
       --chr-set 29 \
       --allow-extra-chr \
       --max-alleles 2 \
       --make-bed \
       --out HD_merged_raw \
       --threads ${THREADS}

echo "=== Step 3: Extracting Unique Sample IDs (NOANs) ==="
awk '{print $2}' HD_merged_raw.fam | sort -u > "${UNIQUE_NOANS}"
echo "Extracted $(wc -l < "${UNIQUE_NOANS}") unique sample IDs to ${UNIQUE_NOANS}."

# ------------------------------------------------------------------------------
# 3. Quality Control & Mendelian Filtering
# ------------------------------------------------------------------------------
echo "=== Step 4: PLINK Quality Control Filtering ==="
# Applied Thresholds:
#   Individual Genotyping Rate >= 90% (--mind 0.10)
#   Marker Call Rate           >= 95% (--geno 0.05)
#   Minor Allele Frequency     >= 1%  (--maf 0.01)
#   Hardy-Weinberg Equilibrium p >= 0.001 (--hwe 0.001)

plink2 --bfile HD_merged_raw \
       --chr-set 29 \
       --allow-extra-chr \
       --mind 0.10 \
       --geno 0.05 \
       --maf 0.01 \
       --hwe 0.001 \
       --make-bed \
       --out HD_filtered_qc1 \
       --threads ${THREADS}

echo "=== Step 5: Mendelian Error Filtering (>10 Errors) ==="
if [ -f "${PEDIGREE_FILE}" ]; then
    echo "Pedigree found (${PEDIGREE_FILE}). Filtering Mendelian inconsistencies..."

    # Link updated pedigree file to dataset
    cp HD_filtered_qc1.bed HD_filtered_qc1_ped.bed
    cp HD_filtered_qc1.bim HD_filtered_qc1_ped.bim
    cp ${PEDIGREE_FILE} HD_filtered_qc1_ped.fam

    # Run Mendelian error check with PLINK 1.9
    plink --bfile HD_filtered_qc1_ped \
          --chr-set 29 \
          --allow-extra-chr \
          --mendel \
          --out mendel_check \
          --threads ${THREADS}

    # Extract variants exceeding 10 errors (column 5 of .lmendel)
    awk 'NR > 1 && $5 > 10 {print $2}' mendel_check.lmendel > mendel_fail_snps.txt
    echo "Identified $(wc -l < mendel_fail_snps.txt) markers exceeding 10 Mendelian errors."

    # Exclude failed variants and zero out sporadic inconsistencies
    plink --bfile HD_filtered_qc1_ped \
          --chr-set 29 \
          --allow-extra-chr \
          --exclude mendel_fail_snps.txt \
          --set-me-missing \
          --make-bed \
          --out HD_final_clean \
          --threads ${THREADS}

    echo "Final clean dataset ready: HD_final_clean"
else
    echo "Pedigree file (${PEDIGREE_FILE}) not found. Skipping Mendelian error step."
    echo "Extract sample IDs from '${UNIQUE_NOANS}' to generate the pedigree file."
fi

echo "All steps finished successfully!"