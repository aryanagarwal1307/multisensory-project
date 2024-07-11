#!/bin/bash
#SBATCH --job-name=step5B_ASHS_stresslearn003
#SBATCH --ntasks=1 --nodes=1
#SBATCH --output=logs/step5B_ASHS_segmentation-%j.out
#SBATCH -p psych_day
#SBATCH --time=10:00:00
#SBATCH --mem-per-cpu=25000
#SBATCH --mail-type=ALL
#SBATCH --mail-user=irene.zhou@yale.edu

sub="stresslearn003"

source run_scripts/globals.sh
SUBJ_DIR="$SUBJ_HEAD_DIR/$sub"
ANAT_DIR="$SUBJ_DIR/preproc/anat"
ANALYSIS_DIR="$SUBJ_DIR/preproc/per_run/${sub}_scene1.feat"
ROI_DIR="$SUBJ_DIR/rois/ASHS"
HPC_DIR="$ROI_DIR/final"
FINAL_DIR="$HPC_DIR/func_masks"

T1_PATH="$ANAT_DIR/${sub}_mprage_brain.nii.gz"
T2_PATH="$ANAT_DIR/${sub}_t2_tse_hipp_brain.nii.gz"

# calculate transformation matrix from T2 to T1 space
echo "calculating transformation matrix from T2 to T1 space"

transform_name=$ANAT_DIR/t2_to_t1_MI
flirt -in $T2_PATH -ref $T1_PATH -dof 6 -cost mutualinfo -omat ${transform_name}.mat -out ${transform_name}.nii.gz


# transform ASHS output from T2 to T1 space
echo "transforming ASHS output from T2 to T1 space"

segmentations="[YOUR 0/1 ROI MASKS HERE]"

for seg in $segmentations
do

in_name=$FINAL_DIR/${seg}
out_name=$FINAL_DIR/${seg}_realigned
bin_out_name=${out_name}_bin
transform_mat=${transform_name}.mat

flirt -in $in_name -ref $T1_PATH -out $out_name -init $transform_mat -applyxfm -interp nearestneighbour
fslmaths $out_name -thr 0.5 -bin ${bin_out_name}.nii.gz

done


# align to match functional scan using FSL FLIRT
echo "aligning to match func scan"
for seg in $segmentations
do

out_name=$FINAL_DIR/${seg}_realigned
bin_out_name=${out_name}_bin

flirt -ref $ANALYSIS_DIR/reg/example_func.nii.gz -in ${bin_out_name} -out $FINAL_DIR/${seg}_mprage_func_temp.nii.gz -applyxfm -init $ANALYSIS_DIR/reg/highres2example_func.mat -interp trilinear
fslmaths $FINAL_DIR/${seg}_mprage_func_temp.nii.gz -thr 0.5 -bin $FINAL_DIR/${seg}_func.nii.gz

done

rm -rf $FINAL_DIR/*_temp.nii.gz


# save sizes of all ROIs
for seg in $segmentations
do
nvox=`cluster -i $FINAL_DIR/${seg}_func.nii.gz -t 1 | awk 'FNR == 2 { print $2 }'`

echo -e "${seg}_func \t $nvox" >> $FINAL_DIR/ASHS_anat_roi_size.txt

done
