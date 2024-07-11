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

source run_scripts/globals.sh
SUBJ_DIR="$SUBJ_HEAD_DIR/$sub"
ANAT_DIR="$SUBJ_DIR/preproc/anat"
ANALYSIS_DIR="$SUBJ_DIR/preproc/per_run/${sub}_scene1.feat"
ROI_DIR="$SUBJ_DIR/rois/ASHS"

if [ ! -d $ROI_DIR ]; then
        mkdir $ROI_DIR
fi

echo "segmenting mprage"

# run ASHS segmentation
# `-I` participant Id (This ID gets propagated throughout the pipeline)
# `-a` location of the ASHS trained model 
# `-g` the location of the T1 
# `-f` the location of the T2
# `-w` the output directory
export ASHS_ROOT=/gpfs/milgram/pi/turk-browne/shared_resources/packages/ashs-fastashs_beta

ASHS_TRAINED_MODEL="/gpfs/milgram/project/turk-browne/projects/stat_episodic/ASHS/ashs_atlas_princeton"
#T1_PATH="$ANAT_DIR/${sub}_mprage_brain.nii.gz"
#T2_PATH="$ANAT_DIR/${sub}_t2_tse_hipp_brain.nii.gz"
T1_PATH="$ANAT_DIR/${sub}_mprage.nii.gz"
T2_PATH="$ANAT_DIR/${sub}_t2_tse.nii.gz"

now=`date +%Y-%m-%d_%H:%M:%S`

bash /gpfs/milgram/pi/turk-browne/shared_resources/packages/ashs-fastashs_beta/run_ashs.sh -I $sub -a $ASHS_TRAINED_MODEL -g $T1_PATH -f $T2_PATH -w $ROI_DIR >>${LOG_DIR}/step5A_roi_segment_ASHS_$sub_$now.txt 2>&1

HPC_DIR="$ROI_DIR/final"
FINAL_DIR="$HPC_DIR/func_masks"

if [ ! -d $FINAL_DIR ]; then
        mkdir $FINAL_DIR
fi
