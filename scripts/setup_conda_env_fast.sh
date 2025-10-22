#!/bin/bash

# Fast setup script for PIMGAVir conda environment using mamba
# This script uses mamba for faster environment creation

ENV_NAME="pimgavir_complete"

echo "Setting up PIMGAVir conda environment with mamba..."

# Check if mamba is available
if ! command -v mamba &> /dev/null; then
    echo "Warning: mamba not found. Using conda instead (slower)..."
    CONDA_CMD="conda"
else
    echo "Using mamba for faster installation..."
    CONDA_CMD="mamba"
fi

# Check if environment exists
if ! conda info --envs | grep -q "$ENV_NAME"; then
    echo "Creating conda environment from pimgavir_complete.yaml..."
    $CONDA_CMD env create -f pimgavir_complete.yaml
    if [ $? -ne 0 ]; then
        echo "Failed to create conda environment"
        echo "Trying minimal environment instead..."
        $CONDA_CMD env create -f pimgavir_minimal.yaml --name pimgavir_minimal
        if [ $? -eq 0 ]; then
            ENV_NAME="pimgavir_minimal"
            echo "Successfully created minimal environment"
        else
            echo "Failed to create any conda environment"
            exit 1
        fi
    fi
else
    echo "Environment $ENV_NAME already exists"
fi

# Activate the environment
echo "Activating environment $ENV_NAME..."
eval "$(conda shell.bash hook)"
conda activate $ENV_NAME

# Configure Krona taxonomy database
echo "Configuring Krona taxonomy database..."
if command -v ktUpdateTaxonomy.sh &> /dev/null; then
    echo "Downloading and installing Krona taxonomy database..."
    ktUpdateTaxonomy.sh
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

echo ""
echo "Environment setup complete!"
echo "To use this environment, run: conda activate $ENV_NAME"
echo ""
echo "Important notes:"
echo "1. Krona taxonomy database has been configured"
echo "2. All tools are now available via conda, no need for system modules"
echo "3. For cluster usage, make sure this environment is available on compute nodes"
echo "4. Use 'mamba' instead of 'conda' for faster package management"