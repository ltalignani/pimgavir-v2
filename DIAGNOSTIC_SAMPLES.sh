#!/bin/bash
################################################################################
# Diagnostic script to check samples_list.txt content and regenerate correctly
################################################################################

echo "=========================================="
echo "PIMGAVir - Samples List Diagnostic"
echo "=========================================="
echo ""

# Show current working directory
echo "Current working directory:"
pwd
echo ""

# Show samples_list.txt content
echo "Current samples_list.txt content:"
echo "----------------------------------------"
if [ -f "samples_list.txt" ]; then
    cat samples_list.txt
    echo ""
    echo "Number of lines: $(wc -l < samples_list.txt)"
else
    echo "ERROR: samples_list.txt not found!"
fi
echo ""

# Show input directory content
echo "Input directory content:"
echo "----------------------------------------"
if [ -d "input/" ]; then
    ls -lh input/*.fastq.gz 2>/dev/null || echo "No .fastq.gz files found"
else
    echo "ERROR: input/ directory not found!"
fi
echo ""

# Regenerate samples_list.txt with absolute paths
echo "=========================================="
echo "Regenerating samples_list.txt..."
echo "=========================================="
echo ""

# Make sure we're in the project root
cd /projects/large/PIMGAVIR/pimgavir_dev/

# Run detect_samples.sh
bash scripts/detect_samples.sh input/ samples_list.txt

echo ""
echo "=========================================="
echo "Verification - New samples_list.txt:"
echo "=========================================="
cat samples_list.txt
echo ""

echo "=========================================="
echo "Testing path validity..."
echo "=========================================="
while IFS=$'\t' read -r r1 r2 sample; do
    [ -z "$sample" ] && continue
    echo "Sample: $sample"
    if [ -f "$r1" ]; then
        echo "  ✓ R1 exists: $r1"
    else
        echo "  ✗ R1 NOT FOUND: $r1"
    fi
    if [ -f "$r2" ]; then
        echo "  ✓ R2 exists: $r2"
    else
        echo "  ✗ R2 NOT FOUND: $r2"
    fi
    echo ""
done < samples_list.txt

echo "=========================================="
echo "Diagnostic complete!"
echo "=========================================="
