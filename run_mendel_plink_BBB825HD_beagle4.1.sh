#!/bin/bash
#SBATCH --job-name=mendel_plink_hd_beagle4.1
#SBATCH --output=mendel_plink_hd_beagle4.1_%j.log
#SBATCH --error=mendel_plink_hd_beagle4.1_%j.err
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=12:00:00

# Stop script immediately if any command fails
set -eo pipefail

# 1. Load Environment Modules (NIC5 Toolchain)
module purge
module load releases/2022a
module load PLINK/2.00a3.7-foss-2022a

THREADS=${SLURM_CPUS_PER_TASK:-8}

echo "=== Step 1: Convert VCF to PLINK 2 Binary Format ==="
plink2 --vcf 825HD_beagle4.1_phased_genome.vcf.gz \
       --cow \
       --make-bed \
       --out 825HD_beagle4.1_phased \
       --threads ${THREADS}


echo "=== Step 2: Strip Prefix from IDs and Restore Pedigree ==="
# This awk script strips the '1_' prefix from the .fam IID column 
# so it matches the pure NOANs in the pedigree file (pedi_noan825.txt)
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
    # Extract the true NOAN by splitting or stripping the prefix (e.g., "1_17744128" -> "17744128")
    raw_iid = $2;
    sub(/^[^_]*_/, "", raw_iid);
    iid = raw_iid;
    
    # If the animal exists in pedigree, use its sire/dam; otherwise default to 0
    s = (iid in sire && sire[iid] != "") ? sire[iid] : 0;
    d = (iid in dam && dam[iid] != "") ? dam[iid] : 0;
    
    # Print: FID(1) Cleaned_IID Sire Dam Sex(1) Phenotype(-9)
    print 1, iid, s, d, 1, -9;
}
' pedi_noan825.txt 825HD_beagle4.1_phased.fam > 825HD_beagle4.1_phased.fam.new && mv 825HD_beagle4.1_phased.fam.new 825HD_beagle4.1_phased.fam

echo "=== Step 3: Run Mendelian Error Analysis ==="
# PLINK 1.9 handles --mendel robustly
plink --bfile 825HD_beagle4.1_phased \
       --cow \
       --mendel \
       --mendel-duos \
       --out 825HD_mendel_report_beagle4.1_mind95 \
       --threads ${THREADS}

echo "Pipeline finished successfully!"
       