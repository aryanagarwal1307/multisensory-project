#!/bin/bash

# SLURM Options: Log file, 16 CPUs, 6GB per CPU, 100 hours time limit

#SBATCH --output log/%j-fmriprep.out
#SBATCH --job-name preproc_cloudy
#SBATCH -n 16 -t 100:00:00 
#SBATCH --mem-per-cpu 6G
#SBATCH --mail-type ALL
#SBATCH --partition=psych_week

# Set the subject ID in BIDS (ignoring sub- prefix)

SUB=control01

# Load the version of fMRIprep to be used
module load fmriprep/23.2.1

# Set paths for root directory to the data, freesurfer licence, 
# output directory for derivatives, and work directory for intermediate files.

ROOT=/gpfs/milgram/scratch60/turk-browne/aa2842/ds000171

export FS_LICENSE=/gpfs/milgram/scratch60/turk-browne/aa2842/project/license.txt
 
cd $ROOT
OUT=/gpfs/milgram/scratch60/turk-browne/aa2842/derivatives
WORK=/gpfs/milgram/scratch60/turk-browne/aa2842/workdir

echo $SUB $ROOT $OUT

# This is the command that runs fmriprep. Specify the directories, 'participant' level processing, and templates for spatial normalization (e.g. MNI152).

fmriprep $ROOT $OUT participant --participant-label $SUB --nthreads 16 -w $WORK --output-spaces MNI152Lin anat --ignore slicetiming --fs-license-file /home/aa2842/project/license.txt