#!/bin/bash

# Setup script for PIMGAVir conda environment
# This script configures Krona and other tools after conda environment creation

ENV_NAME="pimgavir_complete"

echo "Setting up PIMGAVir conda environment..."

# Check if environment exists
if ! conda info --envs | grep -q "$ENV_NAME"; then
    echo "Creating conda environment from pimgavir_complete.yaml..."
    conda env create -f pimgavir_complete.yaml
    if [ $? -ne 0 ]; then
        echo "Failed to create conda environment"
        exit 1
    fi
else
    echo "Environment $ENV_NAME already exists"
fi

# Activate the environment
echo "Activating environment $ENV_NAME..."
source activate $ENV_NAME

# Configure Krona taxonomy database
echo "Configuring Krona taxonomy database..."
if command -v ktUpdateTaxonomy.sh &> /dev/null; then
    echo "Downloading and installing Krona taxonomy database..."
    ktUpdateTaxonomy.sh --only-build
    if [ $? -eq 0 ]; then
        echo "Krona taxonomy database successfully configured"
    else
        echo "Warning: Krona taxonomy database configuration failed"
        echo "You may need to run 'ktUpdateTaxonomy.sh' manually after environment activation"
    fi
else
    echo "Warning: ktUpdateTaxonomy.sh not found. Please check Krona installation"
fi

# Test key tools
echo "Testing key tools installation..."
tools=("kraken2" "kaiju" "ktImportTaxonomy" "megahit" "spades.py" "blastn" "diamond" "bbduk.sh")

for tool in "${tools[@]}"; do
    if command -v "$tool" &> /dev/null; then
        echo "✓ $tool - OK"
    else
        echo "✗ $tool - NOT FOUND"
    fi
done

# Create symlinks for commonly used krona tools if needed
CONDA_PREFIX=$(conda info --base)/envs/$ENV_NAME
if [ -f "$CONDA_PREFIX/bin/ktImportTaxonomy" ]; then
    echo "Krona tools available in: $CONDA_PREFIX/bin/"
    echo "ktImportTaxonomy path: $CONDA_PREFIX/bin/ktImportTaxonomy"
    echo "ktImportText path: $CONDA_PREFIX/bin/ktImportText"
fi

echo ""
echo "Environment setup complete!"
echo "To use this environment, run: conda activate $ENV_NAME"
echo ""
echo "Important notes:"
echo "1. Krona taxonomy database should be updated regularly"
echo "2. All tools are now available via conda, no need for system modules"
echo "3. Update your scripts to use conda tools instead of module load commands"