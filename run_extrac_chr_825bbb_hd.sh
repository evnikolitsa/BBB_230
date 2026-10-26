#!/bin/sh
#SBATCH --job-name=extract_chr_825bbb_hd
#SBATCH --output=extract_chr_825bbb_hd_%j.log
#SBATCH --error=extract_chr_825bbb_hd_%j.err
#SBATCH --ntasks=1
#SBATCH --array=0-28
#SBATCH --mem-per-cpu=10000
#SBATCH --time=01:00:00

# Stop script immediately if any command fails
set -eo pipefail

nchr=('1' '2' '3' '4' '5' '6' '7' '8' '9' '10' '11' '12' '13' '14' '15' '16' '17' '18' '19' '20' '21' '22' '23' '24' '25' '26' '27' '28' '29')

# Load modules cleanly without mixing releases
module purge
module load releases/2022b
module load BCFtools/1.17-GCC-12.2.0

# Extract the specific chromosome: 
bcftools view HD_qc_mind95_clean_fixed.vcf.gz --regions ${nchr[${SLURM_ARRAY_TASK_ID}]} > cleaned_chr_825bbb_hd_${nchr[${SLURM_ARRAY_TASK_ID}]}.vcf

echo "Chromosome ${nchr[${SLURM_ARRAY_TASK_ID}]} extracted successfully!"