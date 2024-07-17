#!/bin/bash
#SBATCH --job-name=segmentation-test
#SBATCH --ntasks=1 --nodes=1
#SBATCH --output=logs/ASHS_segmentation-%j.out
#SBATCH -p psych_day
#SBATCH --time=10:00:00
#SBATCH --mem-per-cpu=25000
#SBATCH --mail-type=ALL
#SBATCH --mail-user=aryan.agarwal@yale.edu

sub="multimem001"

source /gpfs/milgram/project/turk-browne/aa2842/multisensory/ASHS/globals.sh
SUBJ_DIR="$DATA_DIR/$sub"
ANAT_DIR="$SUBJ_DIR/anat"
ROI_DIR="$SUBJ_DIR/rois/ASHS"

if [ ! -d $ROI_DIR ]; then
        mkdir $ROI_DIR
fi

echo "segmenting T2 scan"

# run ASHS segmentation
# `-I` participant Id (This ID gets propagated throughout the pipeline)
# `-a` location of the ASHS trained model 
# `-g` the location of the T1 
# `-f` the location of the T2
# `-w` the output directory
export ASHS_ROOT=/gpfs/milgram/pi/turk-browne/shared_resources/packages/ashs-fastashs_beta

ASHS_TRAINED_MODEL="/gpfs/milgram/project/turk-browne/projects/stat_episodic/ASHS/ashs_atlas_princeton"
T1_PATH="$ANAT_DIR/T1w_acpc_brain.nii.gz"
T2_PATH="$ANAT_DIR/T2w_acpc_brain.nii.gz"

now=`date +%Y-%m-%d_%H:%M:%S`

bash /gpfs/milgram/pi/turk-browne/shared_resources/packages/ashs-fastashs_beta/run_ashs.sh -I $sub -a $ASHS_TRAINED_MODEL -g $T1_PATH -f $T2_PATH -w $ROI_DIR >>${LOG_DIR}/step5A_roi_segment_ASHS_$sub_$now.txt 2>&1

HPC_DIR="$ROI_DIR/final"
FINAL_DIR="$HPC_DIR/func_masks"

if [ ! -d $FINAL_DIR ]; then
        mkdir $FINAL_DIR
fi
