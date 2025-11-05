#!/bin/bash

echo "Testing path conversion logic..."
echo ""

# Test with a sample file
r1_file="input/DJ_4_R1.fastq.gz"
echo "Input relative path: $r1_file"
echo ""

# Method used in detect_samples.sh
echo "Method 1: cd + dirname + pwd"
r1_abs=$(cd "$(dirname "$r1_file")" && pwd)/$(basename "$r1_file")
echo "Result: $r1_abs"
echo ""

# Alternative method using realpath
echo "Method 2: realpath"
if command -v realpath &> /dev/null; then
    r1_real=$(realpath "$r1_file")
    echo "Result: $r1_real"
else
    echo "realpath command not available"
fi
echo ""

# Alternative method using readlink
echo "Method 3: readlink -f"
if r1_readlink=$(readlink -f "$r1_file" 2>/dev/null); then
    echo "Result: $r1_readlink"
else
    echo "readlink -f failed or not available"
fi
echo ""

# Show what actually gets written with the current method
echo "What gets written to file with current method:"
echo -e "$r1_abs\t$r1_abs\ttest_sample"
