#!/bin/sh
#BATCH --job-name=_beagle4.1
#SBATCH --output=cleaned_chr_825bbb_hd_correct%j.log
#SBATCH --error=cleaned_chr_825bbb_hd_correct%j.err
#SBATCH --ntasks=1
#SBATCH --array=0-28
#SBATCH --mem-per-cpu=10000
#SBATCH --time=48:00:00


nchr=('1' '2' '3' '4' '5' '6' '7' '8' '9' '10' '11' '12' '13' '14' '15' '16' '17' '18' '19' '20' '21' '22' '23' '24' '25' '26' '27' '28' '29')


module load Java/1.8.0_241

# Create folder temporal files TMP :
ScratchDir=TMP/${SLURM_JOB_ID}
mkdir -p ${ScratchDir}


# Get the current chromosome for this array task
CURRENT_CHR=${nchr[$SLURM_ARRAY_TASK_ID]}

echo "Running Beagle 4.1 for Chromosome ${CURRENT_CHR}..."

# Run Beagle with increased stack size (-Xss5m) and local scratch temp directory
java -Xss5m -Xmx9000m -Djava.io.tmpdir=${ScratchDir} \
     -jar beagle.27Jan18.7e1.jar \
     gt=cleaned_chr_825bbb_hd_${CURRENT_CHR}.vcf \
     out=cleaned_chr_825bbb_hd_corrected_chr${CURRENT_CHR}

# Delete temporal folder files:
rm -rf ${ScratchDir}

echo "Chromosome ${CURRENT_CHR} finished successfully!"