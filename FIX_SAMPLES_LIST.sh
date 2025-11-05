#!/bin/bash
################################################################################
# Quick fix script to regenerate samples_list.txt on the cluster
#
# Run this on the cluster to detect all samples in input/ directory
################################################################################

echo "=========================================="
echo "Regenerating samples_list.txt on cluster"
echo "=========================================="
echo ""

# Change to project directory on cluster
cd /projects/large/PIMGAVIR/pimgavir_dev/

# Run detect_samples script
bash scripts/detect_samples.sh input/ samples_list.txt

echo ""
echo "=========================================="
echo "Samples list updated successfully!"
echo "=========================================="
echo ""
echo "You can now resubmit the batch job:"
echo "  cd /projects/large/PIMGAVIR/pimgavir_dev/"
echo "  bash scripts/run_pimgavir_batch.sh input/ --ass_based --mem 256GB --email loic.talignani@ird.fr --mail-type ALL"
echo ""
