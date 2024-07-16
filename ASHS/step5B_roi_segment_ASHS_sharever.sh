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

# Get the important variables
source /gpfs/milgram/project/turk-browne/aa2842/multisensory/ASHS/globals.sh
SUBJ_DIR="$SUBJ_HEAD_DIR/$sub"
ANAT_DIR="$SUBJ_DIR/anat"
FUNC_DIR="$SUBJ_DIR/func"

# Main directories for the variables
ROI_DIR="$SUBJ_DIR/rois/ASHS"
HPC_DIR="$ROI_DIR/final"
FINAL_DIR="$HPC_DIR/func_masks"
MASK_DIR_T2="$FINAL_DIR/bin_masks_5B_T2"
MASK_DIR_T1="$FINAL_DIR/bin_masks_5B_T1"
MASK_DIR_func="$FINAL_DIR/bin_masks_5B_func"

# Paths for the T1 and T2 scans
T1_PATH="$ANAT_DIR/ENTER/PATH/TO/T1/SCAN/HERE"
T2_PATH="$ANAT_DIR/ENTER/PATH/TO/T2/SCAN/HERE"
func_PATH="$FUNC_DIR/ENTER/PATH/TO/FUNCTIONAL/SCAN/HERE"

# Paths to the segmentation mask files
LEFT_SEG_PATH="$HPC_DIR/${sub}_left_lfseg_corr_nogray.nii.gz"
RIGHT_SEG_PATH="$HPC_DIR/${sub}_right_lfseg_corr_nogray.nii.gz"

# Create the directories if they don't exist
mkdir -p "$MASK_DIR_T2"
mkdir -p "$MASK_DIR_T1"
mkdir -p "$MASK_DIR_func"

# Define the region codes and segmentation list
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
  fslmaths $LEFT_SEG_PATH -thr $code -uthr $code -bin $MASK_DIR_T2/left_${region}_mask_T2.nii.gz
  segmentations+=("/left_${region}_mask")
  # Make the right mask for ROI
  fslmaths $RIGHT_SEG_PATH -thr $code -uthr $code -bin $MASK_DIR_T2/right_${region}_mask_T2.nii.gz
  segmentations+=("/right_${region}_mask")
  # Make the combined mask for ROI
  fslmaths $MASK_DIR_T2/left_${region}_mask.nii.gz -add $MASK_DIR_T2/right_${region}_mask.nii.gz -bin $MASK_DIR_T2/combined_${region}_mask_T2.nii.gz
  segmentations+=("/combined_${region}_mask")
done

# Create a combined mask for the left hippocampus
fslmaths $MASK_DIR_T2/left_CA1_mask_T2.nii.gz -add $MASK_DIR_T2/left_CA2+3_mask_T2.nii.gz -add $MASK_DIR_T2/left_DG_mask_T2.nii.gz -add $MASK_DIR_T2/left_Subiculum_mask_T2.nii.gz -bin $MASK_DIR_T2/left_HPC_mask_T2.nii.gz
segmentations+=("/left_HPC_mask")

# Create a combined mask for the right hippocampus
fslmaths $MASK_DIR_T2/right_CA1_mask_T2.nii.gz -add $MASK_DIR_T2/right_CA2+3_mask_T2.nii.gz -add $MASK_DIR_T2/right_DG_mask_T2.nii.gz -add $MASK_DIR_T2/right_Subiculum_mask_T2.nii.gz -bin $MASK_DIR_T2/right_HPC_mask_T2.nii.gz
segmentations+=("/right_HPC_mask")

# Create a combined mask for the whole hippocampus
fslmaths $MASK_DIR_T2/left_HPC_mask_T2.nii.gz -add $MASK_DIR_T2/right_HPC_mask_T2.nii.gz -bin $MASK_DIR_T2/combined_HPC_mask_T2.nii.gz
segmentations+=("/combined_HPC_mask")

######################################################################################################################################
######################################################################################################################################

# NOW WE ARE BUILDING SEGMENTATIONS IN T1 SPACE (TRANSFORMATION OF ASHS OUTPUT FROM T2 TO T1 USING FLIRT)
echo "finding parameters for T2 to T1 transformation"

# Extract the transformation matrix from the ITK .txt file
transform_mat_T2_to_T1_xfm="/ENTER/PATH/TO/TRANSFORMATION/HERE"
transform_mat_T2_to_T1="/ENTER/THIS/IS/RENAMED/TRANSFORMATION/MATRIX/IN/MAT/FORMAT/DECIDE/WHERE/TO/PLACE/IT"
parameters=$(grep "Parameters:" "$transform_mat_T2_to_T1_xfm" | sed 's/Parameters: //')

# Create the .mat file and write the matrix
cat << EOF > "$transform_mat_T2_to_T1"
$(echo "$parameters" | awk '{print $1, $2, $3, $4}')
$(echo "$parameters" | awk '{print $5, $6, $7, $8}')
$(echo "$parameters" | awk '{print $9, $10, $11, $12}')
0 0 0 1
EOF

echo "Converted $transform_mat_T2_to_T1_xfm to $transform_mat_T2_to_T1"

for seg in "${segmentations[@]}"; do
  # Declare the paths for each segmentation and the names of outputs
  in_name=$MASK_DIR_T2/${seg}_T2.nii.gz
  out_name=$MASK_DIR_T1/${seg}_T1_non-bin.nii.gz
  bin_out_name=$MASK_DIR_T1/${seg}_T1.nii.gz

  # Use flirt to do the T2 to T1 transformation
  flirt -in "$in_name" -ref "$T1_PATH" -out "$out_name" -init $transform_mat_T2_to_T1 -applyxfm -interp nearestneighbour
  # Use FSL to binarize the realigned mask
  fslmaths "$out_name" -thr 0.5 -bin "$bin_out_name"
done

######################################################################################################################################
######################################################################################################################################

# NOW WE ARE BUILDING SEGMENTATIONS IN FUNCTIONAL SPACE (TRANSFORMATION OF ASHS OUTPUT FROM T1 TO BOLDREF USING FLIRT)
# align to match functional scan using FSL FLIRT
echo "finding parameters for T1 to functional transformation"

# Extract the transformation matrix from the ITK .txt file
transform_mat_T1_to_func_xfm="/ENTER/PATH/TO/TRANSFORMATION/HERE"
transform_mat_T1_to_func="/ENTER/THIS/IS/RENAMED/TRANSFORMATION/MATRIX/IN/MAT/FORMAT/DECIDE/WHERE/TO/PLACE/IT"
parameters=$(grep "Parameters:" "$transform_mat_T1_to_func_xfm" | sed 's/Parameters: //')

# Create the .mat file and write the matrix
cat << EOF > "$transform_mat_T1_to_func"
$(echo "$parameters" | awk '{print $1, $2, $3, $4}')
$(echo "$parameters" | awk '{print $5, $6, $7, $8}')
$(echo "$parameters" | awk '{print $9, $10, $11, $12}')
0 0 0 1
EOF

echo "Converted $transform_mat_T1_to_func_xfm to $transform_mat_T1_to_func"

for seg in "${segmentations[@]}"; do
  # Declare the paths for each segmentation and the names of outputs
  in_name=$MASK_DIR_T1/${seg}_T1_non-bin.nii.gz
  out_name=$MASK_DIR_func/${seg}_func_non-bin.nii.gz
  bin_out_name=$MASK_DIR_func/${seg}_func.nii.gz

  # Use flirt to do the T1 to functional transformation
  flirt -ref $func_PATH -in "$in_name" -out "$out_name" -applyxfm -init $transform_mat_T1_to_func -interp trilinear
  # Use FSL to binarize the realigned mask
  fslmaths "$out_name" -thr 0.5 -bin "$bin_out_name"
done

######################################################################################################################################
######################################################################################################################################

# Delete any temporary files generated
rm -rf $FINAL_DIR/*_temp.nii.gz
