#!/bin/bash

################################################################################
# detect_samples.sh
#
# Scans input/ directory for paired-end FASTQ samples and creates samples.list
#
# Supported naming conventions:
#   - sample_R1.fastq.gz / sample_R2.fastq.gz
#   - sample_1.fastq.gz / sample_2.fastq.gz
#   - sample.R1.fastq.gz / sample.R2.fastq.gz
#
# Output format (samples.list):
#   Each line: R1_file<TAB>R2_file<TAB>sample_name
#
# Usage: ./detect_samples.sh [input_dir] [output_file]
################################################################################

set -eo pipefail

# Default parameters
INPUT_DIR="${1:-input}"
OUTPUT_FILE="${2:-samples.list}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "PIMGAVir Sample Detection"
echo "=========================================="
echo "Input directory: $INPUT_DIR"
echo "Output file: $OUTPUT_FILE"
echo ""

# Check if input directory exists
if [ ! -d "$INPUT_DIR" ]; then
    echo -e "${RED}ERROR: Input directory '$INPUT_DIR' does not exist${NC}"
    exit 1
fi

# Clear/create output file
> "$OUTPUT_FILE"

# Counter for samples found
SAMPLE_COUNT=0

# Track processed files to avoid duplicates
declare -A processed_r1_files

################################################################################
# Function to extract sample name from R1 filename
################################################################################
extract_sample_name() {
    local r1_file="$1"
    local basename=$(basename "$r1_file")

    # Remove .fastq.gz or .fq.gz extension
    basename="${basename%.fastq.gz}"
    basename="${basename%.fq.gz}"

    # Remove R1/1 suffix patterns
    # Pattern 1: _R1, _1
    basename="${basename%_R1}"
    basename="${basename%_1}"

    # Pattern 2: .R1, .1
    basename="${basename%.R1}"
    basename="${basename%.1}"

    echo "$basename"
}

################################################################################
# Function to find matching R2 file for a given R1 file
################################################################################
find_r2_file() {
    local r1_file="$1"
    local r2_file=""

    # Try different R2 naming patterns
    # Pattern 1: _R1.fastq.gz -> _R2.fastq.gz
    r2_file="${r1_file/_R1.fastq.gz/_R2.fastq.gz}"
    [ -f "$r2_file" ] && [ "$r2_file" != "$r1_file" ] && echo "$r2_file" && return 0

    # Pattern 2: _R1.fq.gz -> _R2.fq.gz
    r2_file="${r1_file/_R1.fq.gz/_R2.fq.gz}"
    [ -f "$r2_file" ] && [ "$r2_file" != "$r1_file" ] && echo "$r2_file" && return 0

    # Pattern 3: _1.fastq.gz -> _2.fastq.gz
    r2_file="${r1_file/_1.fastq.gz/_2.fastq.gz}"
    [ -f "$r2_file" ] && [ "$r2_file" != "$r1_file" ] && echo "$r2_file" && return 0

    # Pattern 4: _1.fq.gz -> _2.fq.gz
    r2_file="${r1_file/_1.fq.gz/_2.fq.gz}"
    [ -f "$r2_file" ] && [ "$r2_file" != "$r1_file" ] && echo "$r2_file" && return 0

    # Pattern 5: .R1.fastq.gz -> .R2.fastq.gz
    r2_file="${r1_file/.R1.fastq.gz/.R2.fastq.gz}"
    [ -f "$r2_file" ] && [ "$r2_file" != "$r1_file" ] && echo "$r2_file" && return 0

    # Pattern 6: .R1.fq.gz -> .R2.fq.gz
    r2_file="${r1_file/.R1.fq.gz/.R2.fq.gz}"
    [ -f "$r2_file" ] && [ "$r2_file" != "$r1_file" ] && echo "$r2_file" && return 0

    # Pattern 7: .1.fastq.gz -> .2.fastq.gz
    r2_file="${r1_file/.1.fastq.gz/.2.fastq.gz}"
    [ -f "$r2_file" ] && [ "$r2_file" != "$r1_file" ] && echo "$r2_file" && return 0

    # Pattern 8: .1.fq.gz -> .2.fq.gz
    r2_file="${r1_file/.1.fq.gz/.2.fq.gz}"
    [ -f "$r2_file" ] && [ "$r2_file" != "$r1_file" ] && echo "$r2_file" && return 0

    return 1
}

################################################################################
# Search for R1 files with all supported patterns
################################################################################
echo "Scanning for paired-end samples..."
echo ""

# Use find to get all potential R1 files (more reliable than glob)
while IFS= read -r r1_file; do
    # Skip if already processed
    if [ -n "${processed_r1_files[$r1_file]:-}" ]; then
        continue
    fi

    # Find matching R2
    r2_file=$(find_r2_file "$r1_file")

    if [ -z "$r2_file" ]; then
        echo -e "${YELLOW}WARNING: No R2 file found for: $(basename "$r1_file")${NC}"
        continue
    fi

    # Extract sample name
    sample_name=$(extract_sample_name "$r1_file")

    # Validate sample name
    if [ -z "$sample_name" ]; then
        echo -e "${YELLOW}WARNING: Could not extract sample name from: $(basename "$r1_file")${NC}"
        continue
    fi

    # Add to samples list
    echo -e "$r1_file\t$r2_file\t$sample_name" >> "$OUTPUT_FILE"

    # Mark as processed
    processed_r1_files[$r1_file]=1

    # Increment counter
    SAMPLE_COUNT=$((SAMPLE_COUNT + 1))

    # Print confirmation
    echo -e "${GREEN}✓${NC} Sample $SAMPLE_COUNT: $sample_name"
    echo "    R1: $(basename "$r1_file")"
    echo "    R2: $(basename "$r2_file")"
    echo ""

done < <(find "$INPUT_DIR" -maxdepth 1 -type f \( \
    -name "*_R1.fastq.gz" -o \
    -name "*_R1.fq.gz" -o \
    -name "*_1.fastq.gz" -o \
    -name "*_1.fq.gz" -o \
    -name "*.R1.fastq.gz" -o \
    -name "*.R1.fq.gz" -o \
    -name "*.1.fastq.gz" -o \
    -name "*.1.fq.gz" \
\) | sort)

################################################################################
# Summary
################################################################################
echo "=========================================="
if [ $SAMPLE_COUNT -eq 0 ]; then
    echo -e "${RED}ERROR: No paired samples found in $INPUT_DIR${NC}"
    echo ""
    echo "Supported naming patterns:"
    echo "  - sample_R1.fastq.gz / sample_R2.fastq.gz"
    echo "  - sample_1.fastq.gz / sample_2.fastq.gz"
    echo "  - sample.R1.fastq.gz / sample.R2.fastq.gz"
    echo ""
    rm -f "$OUTPUT_FILE"
    exit 1
else
    echo -e "${GREEN}SUCCESS: Found $SAMPLE_COUNT paired sample(s)${NC}"
    echo "Sample list written to: $OUTPUT_FILE"
    echo ""
    echo "Preview of samples.list:"
    echo "----------------------------------------"
    head -n 5 "$OUTPUT_FILE" | while IFS=$'\t' read -r r1 r2 name; do
        echo "Sample: $name"
        echo "  R1: $(basename "$r1")"
        echo "  R2: $(basename "$r2")"
        echo ""
    done
    if [ $SAMPLE_COUNT -gt 5 ]; then
        echo "... and $((SAMPLE_COUNT - 5)) more sample(s)"
    fi
fi
echo "=========================================="

exit 0
