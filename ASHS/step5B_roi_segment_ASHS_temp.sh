#!/bin/bash
#SBATCH --job-name=step5B_ASHS_multimem001-test
#SBATCH --ntasks=1 --nodes=1
#SBATCH --output=logs/step5B_ASHS_segmentation-%j.out
#SBATCH -p psych_day
#SBATCH --time=10:00:00
#SBATCH --mem-per-cpu=25000
#SBATCH --mail-type=ALL
#SBATCH --mail-user=aryan.agarwal@yale.edu

sub="multimem001"

# Get the important variables and load FSL from the cluster
source /gpfs/milgram/project/turk-browne/aa2842/multisensory/ASHS/globals.sh
source "$FSLDIR/etc/fslconf/fsl.sh"
module load FSL
SUBJ_DIR="$DATA_DIR/$sub"
ANAT_DIR="$SUBJ_DIR/anat"

# Main directories for the variables, where MASK_DIRs are to store the T2 and T1 masks 
ROI_DIR="$SUBJ_DIR/rois/ASHS"
HPC_DIR="$ROI_DIR/final"
FINAL_DIR="$HPC_DIR/func_masks"
MASK_DIR_T2="$FINAL_DIR/bin_masks_5B_T2"
MASK_DIR_T1="$FINAL_DIR/bin_masks_5B_T1"

# Paths for the T1 and T2 scans
T1_PATH="$ANAT_DIR/T1w_acpc_brain.nii.gz"
T2_PATH="$ANAT_DIR/T2w_acpc_brain.nii.gz"

# Paths to the segmentation mask files generetaed by ASHS 
LEFT_SEG_PATH="$HPC_DIR/${sub}_left_lfseg_corr_nogray.nii.gz"
RIGHT_SEG_PATH="$HPC_DIR/${sub}_right_lfseg_corr_nogray.nii.gz"

# Create the directories since they don't exist yet
mkdir -p "$MASK_DIR_T2"
mkdir -p "$MASK_DIR_T1"

# Define the region codes in the file and the segmentation array for loops 
declare -A regions
regions=( ["CA1"]=1 ["CA2+3"]=2 ["DG"]=3 ["EC"]=4 ["PHC"]=5 ["PRC"]=6 ["Subiculum"]=7 )
segmentations=()

######################################################################################################################################
######################################################################################################################################

# NOW WE ARE BUILDING SEGMENTATIONS IN T2 SPACE:

# Generate masks for each region (left + right + combined)
for region in "${!regions[@]}"; do
  code=${regions[$region]}
  # Make the left mask for ROI
  fslmaths "$LEFT_SEG_PATH" -thr "$code" -uthr "$code" -bin "$MASK_DIR_T2/left_${region}_mask_T2.nii.gz"
  segmentations+=("left_${region}_mask")
  # Make the right mask for ROI
  fslmaths "$RIGHT_SEG_PATH" -thr "$code" -uthr "$code" -bin "$MASK_DIR_T2/right_${region}_mask_T2.nii.gz"
  segmentations+=("right_${region}_mask")
  # Make the combined mask for ROI
  fslmaths "$MASK_DIR_T2/left_${region}_mask_T2.nii.gz" -add "$MASK_DIR_T2/right_${region}_mask_T2.nii.gz" -bin "$MASK_DIR_T2/combined_${region}_mask_T2.nii.gz"
  segmentations+=("combined_${region}_mask")
done

# Create a combined mask for the left hippocampus
fslmaths "$MASK_DIR_T2/left_CA1_mask_T2.nii.gz" -add "$MASK_DIR_T2/left_CA2+3_mask_T2.nii.gz" -add "$MASK_DIR_T2/left_DG_mask_T2.nii.gz" -add "$MASK_DIR_T2/left_Subiculum_mask_T2.nii.gz" -bin "$MASK_DIR_T2/left_HPC_mask_T2.nii.gz"
segmentations+=("left_HPC_mask")

# Create a combined mask for the right hippocampus
fslmaths "$MASK_DIR_T2/right_CA1_mask_T2.nii.gz" -add "$MASK_DIR_T2/right_CA2+3_mask_T2.nii.gz" -add "$MASK_DIR_T2/right_DG_mask_T2.nii.gz" -add "$MASK_DIR_T2/right_Subiculum_mask_T2.nii.gz" -bin "$MASK_DIR_T2/right_HPC_mask_T2.nii.gz"
segmentations+=("right_HPC_mask")

# Create a combined mask for the whole hippocampus
fslmaths "$MASK_DIR_T2/left_HPC_mask_T2.nii.gz" -add "$MASK_DIR_T2/right_HPC_mask_T2.nii.gz" -bin "$MASK_DIR_T2/combined_HPC_mask_T2.nii.gz"
segmentations+=("combined_HPC_mask")

######################################################################################################################################
######################################################################################################################################

# NOW WE ARE BUILDING SEGMENTATIONS IN T1 SPACE (TRANSFORMATION OF ASHS OUTPUT FROM T2 TO T1 USING FLIRT)
echo "finding matrix for T2 to T1 transformation"

transform_mat_T2_to_T1="$ANAT_DIR/t2_to_t1"

flirt -in "$T2_PATH" -ref "$T1_PATH" -dof 6 -cost mutualinfo -omat "$transform_mat_T2_to_T1.mat" -out "$transform_mat_T2_to_T1.nii.gz"

for seg in "${segmentations[@]}"; do
  # Declare the paths for each segmentation and the names of outputs
  in_name="$MASK_DIR_T2/${seg}_T2.nii.gz"
  out_name="$MASK_DIR_T1/${seg}_T1_non-bin.nii.gz"
  bin_out_name="$MASK_DIR_T1/${seg}_T1.nii.gz"

  # Use flirt to do the T2 to T1 transformation
  flirt -in "$in_name" -ref "$T1_PATH" -out "$out_name" -init "$transform_mat_T2_to_T1.mat" -applyxfm -interp nearestneighbour
  # Use FSL to binarize the realigned mask
  fslmaths "$out_name" -thr 0.5 -bin "$bin_out_name"
done

######################################################################################################################################
######################################################################################################################################
