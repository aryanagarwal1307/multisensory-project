#!/bin/bash
#SBATCH --output log/%j-fmriprep.out
#SBATCH --job-name preproc_cloudy
#SBATCH -n 16 -t 100:00:00 
#SBATCH --mem-per-cpu 6G
#SBATCH --mail-type ALL
#SBATCH --partition=psych_week

SUB=control01
module load fmriprep/23.2.1
ROOT=/gpfs/milgram/scratch60/turk-browne/aa2842/ds000171

export FS_LICENSE=/gpfs/milgram/scratch60/turk-browne/aa2842/project/license.txt

cd $ROOT
OUT=/gpfs/milgram/scratch60/turk-browne/aa2842/derivatives
WORK=/gpfs/milgram/scratch60/turk-browne/aa2842/workdir

echo $SUB $ROOT $OUT

fmriprep $ROOT $OUT participant --participant-label $SUB --nthreads 16 -w $WORK --output-spaces MNI152Lin --ignore slicetiming --fs-license-file /home/aa2842/project/license.txt