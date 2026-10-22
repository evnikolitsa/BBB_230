#!/bin/bash
#SBATCH --job-name=hardy_missing_freq_qc_mendel
#SBATCH --output=hardy_missing_freq_%j.log
#SBATCH --error=hardy_missing_freq_%j.err
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=12:00:00

# Stop script immediately if any command fails
set -eo pipefail

# 1. Load Environment Modules (NIC5 Toolchain)
module purge
module load releases/2022a
module load PLINK/2.00a3.7-foss-2022a

# Define variables
MERGED_VCF="HD_merged_output.vcf.gz"
THREADS=${SLURM_CPUS_PER_TASK:-8}

# Clean up previous outputs to prevent file collision
rm -f HD_raw.* HD_named.* HD_qc.* HD_mendel_report.* pedigree_check.* 

echo "=== Step 1: Convert Merged VCF to PLINK 2 Binary Format ==="

# --cow = --chr-set 29 no-xy

plink2 --vcf "${MERGED_VCF}" \
       --cow \
       --max-alleles 2 \
       --make-bed \
       --out HD_raw \
       --threads ${THREADS}

echo "=== Step 2: Update Sample IDs from Chip IDs to Animal NOANs ==="
plink2 --bfile HD_raw \
       --update-ids update_825ids.txt \
       --cow \
       --make-bed \
       --out HD_named \
       --threads ${THREADS}



echo "=== Step 3:  Apply QC Filters ==="
# Applied Thresholds:
#   Individual Call Rate         >= 95% (--mind 0.05)
#   Marker Call Rate             >= 95% (--geno 0.05)
#   Minor Allele Frequency       >= 0.5% (--maf 0.005)
#   Hardy-Weinberg Equilibrium p >= 0.001 (--hwe 0.001)

       
plink --bfile HD_named \
       --cow \
       --hardy \
       --missing \
       --freq \
       --geno 0.05 \
       --maf 0.005 \
       --hwe 0.001 \
       --mind 0.05 \
       --make-bed \
       --out HD_qc_mind95 \
       --threads ${THREADS}
       
       
# --missing produces sample-based and variant-based missing data reports. 

# --freq writes a minor allele frequency report to plink.frq. If you add the 'counts' modifier, an allele count report is written to plink.frq.count instead

#--hardy writes a list of genotype counts and Hardy-Weinberg equilibrium exact test statistics to plink.hwe.
       
       
echo "=== Step 4: Harmonize Family IDs for PLINK 1.9 Mendelian Analysis ==="


echo "=== Step 6b: Harmonize Family IDs for PLINK 1.9 Mendelian Analysis ==="

# This awk script reads your pedigree file first to map Offspring -> (Sire, Dam),
# then rewrites HD_qc.fam so columns 3 & 4 are correctly populated and column 1 is set to 1.
awk '
NR==FNR {
    if (NR > 1) {
        # Clean carriage returns if present
        gsub("\r", "", $1); gsub("\r", "", $2); gsub("\r", "", $3);
        sire[$1] = $2;
        dam[$1] = $3;
    }
    next
}
{
    iid = $2;
    # If the animal exists in pedigree, use its sire/dam; otherwise default to 0
    s = (iid in sire && sire[iid] != "") ? sire[iid] : 0;
    d = (iid in dam && dam[iid] != "") ? dam[iid] : 0;
    
    # Print: FID(1) IID Sire Dam Sex(1) Phenotype(-9)
    print 1, iid, s, d, 1, -9;
}
' pedi_noan825.txt HD_qc_mind95.fam > HD_qc_mind95.fam.new && mv HD_qc_mind95.fam.new HD_qc_mind95.fam

echo "=== Step 5: Run Mendelian Error Analysis ==="
plink --bfile HD_qc_mind95 \
       --cow \
       --mendel \
       --mendel-duos \
       --out HD_mendel_report_mind95 \
       --threads ${THREADS}

echo "Pipeline finished successfully!"
       
