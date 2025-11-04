#!/bin/bash

#SBATCH --job-name=setup_pimgavir_env
#SBATCH --partition=normal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=128GB
#SBATCH --time=02:00:00
#SBATCH --output=setup_pimgavir_env_%j.out
#SBATCH --error=setup_pimgavir_env_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=loic.talignani@ird.fr

################################################################################
# PIMGAVir - Fast Conda Environment Setup Script
#
# Purpose: Create unified PIMGAVir conda environment with all tools
#
# Usage:
#   Interactive: bash setup_conda_env_fast.sh
#   SLURM batch: sbatch setup_conda_env_fast.sh
#
# Features:
#   - Uses mamba for faster installation (falls back to conda)
#   - Creates pimgavir_viralgenomes environment (unified, complete)
#   - Automatic Krona taxonomy database configuration
#   - Optional BLAST taxonomy database installation
#   - Optional viral genome databases setup (DRAM, VirSorter2, CheckV)
#
# Version: 2.1 - 2025-11-04 (Added SLURM support)
################################################################################

set -e

# Environment name (unified)
ENV_NAME="pimgavir_viralgenomes"
ENV_FILE="pimgavir_viralgenomes.yaml"

# Detect if running in SLURM batch mode (non-interactive)
if [ -n "$SLURM_JOB_ID" ]; then
    BATCH_MODE=true
    echo "Running in SLURM batch mode (Job ID: $SLURM_JOB_ID)"
else
    BATCH_MODE=false
    echo "Running in interactive mode"
fi

echo "=========================================="
echo "PIMGAVir Environment Setup"
echo "=========================================="
echo ""
echo "This script will create the unified PIMGAVir conda environment:"
echo "  - Environment: $ENV_NAME"
echo "  - Includes: All core tools + viral genome analysis (7 phases)"
echo "  - Size: ~8-10 GB"
echo "  - Time: ~15-30 minutes with mamba, ~45-90 min with conda"
echo ""

################################################################################
# Check if mamba is available
################################################################################
if ! command -v mamba &> /dev/null; then
    echo "Warning: mamba not found. Using conda instead (slower)..."
    echo "To install mamba for faster package management:"
    echo "  conda install -n base -c conda-forge mamba"
    echo ""
    CONDA_CMD="conda"
else
    echo "Using mamba for faster installation..."
    CONDA_CMD="mamba"
fi

################################################################################
# Check if environment already exists
################################################################################
if conda info --envs | grep -q "^$ENV_NAME "; then
    echo ""
    echo "Environment '$ENV_NAME' already exists!"
    echo ""

    if [ "$BATCH_MODE" = true ]; then
        # In batch mode, automatically remove and recreate
        echo "BATCH MODE: Automatically removing and recreating environment..."
        conda env remove -n "$ENV_NAME"
    else
        # In interactive mode, ask user
        read -p "Do you want to remove and recreate it? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Removing existing environment..."
            conda env remove -n "$ENV_NAME"
        else
            echo "Keeping existing environment. Exiting."
            exit 0
        fi
    fi
fi

################################################################################
# Create conda environment
################################################################################
echo ""
echo "Creating conda environment from $ENV_FILE..."
echo "This may take 15-30 minutes with mamba (longer with conda)..."
echo ""

if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: $ENV_FILE not found in current directory"
    echo "Please run this script from the scripts/ directory"
    exit 1
fi

$CONDA_CMD env create -f "$ENV_FILE"

if [ $? -ne 0 ]; then
    echo ""
    echo "ERROR: Failed to create conda environment"
    echo "Please check the error messages above and try again"
    exit 1
fi

echo ""
echo "Environment created successfully!"
echo ""

################################################################################
# Activate the environment
################################################################################
echo "Activating environment $ENV_NAME..."
eval "$(conda shell.bash hook)"
conda activate "$ENV_NAME"

if [ "$CONDA_DEFAULT_ENV" != "$ENV_NAME" ]; then
    echo "Warning: Failed to activate environment automatically"
    echo "Please activate it manually: conda activate $ENV_NAME"
    exit 1
fi

echo "Environment activated: $CONDA_DEFAULT_ENV"
echo ""

################################################################################
# Configure Krona taxonomy database
################################################################################
echo "=========================================="
echo "Configuring Krona Taxonomy Database"
echo "=========================================="
echo ""

if command -v ktUpdateTaxonomy.sh &> /dev/null; then
    echo "Downloading and installing Krona taxonomy database..."
    echo "This may take 5-10 minutes..."
    ktUpdateTaxonomy.sh
    if [ $? -eq 0 ]; then
        echo "✓ Krona taxonomy database successfully configured"
    else
        echo "✗ Warning: Krona taxonomy database configuration failed"
        echo "  You may need to run 'ktUpdateTaxonomy.sh' manually after environment activation"
    fi
else
    echo "✗ Warning: ktUpdateTaxonomy.sh not found. Please check Krona installation"
fi

echo ""

################################################################################
# Test key tools installation
################################################################################
echo "=========================================="
echo "Testing Tool Installation"
echo "=========================================="
echo ""

# Core pipeline tools
echo "Core pipeline tools:"
core_tools=("kraken2" "kaiju" "ktImportTaxonomy" "megahit" "spades.py" "blastn" "diamond" "bbduk.sh")
for tool in "${core_tools[@]}"; do
    if command -v "$tool" &> /dev/null; then
        echo "  ✓ $tool"
    else
        echo "  ✗ $tool - NOT FOUND"
    fi
done

echo ""
echo "Viral genome analysis tools:"
viral_tools=("virsorter" "checkv" "prodigal-gv" "vrhyme" "DRAM-setup.py" "mafft" "iqtree" "genomad" "vcontact2")
for tool in "${viral_tools[@]}"; do
    if command -v "$tool" &> /dev/null; then
        echo "  ✓ $tool"
    else
        echo "  ✗ $tool - NOT FOUND"
    fi
done

echo ""

################################################################################
# Install BLAST taxonomy database (optional)
################################################################################
echo "=========================================="
echo "BLAST Taxonomy Database Setup"
echo "=========================================="
echo ""
echo "The BLAST taxonomy database enables BLAST to display organism names"
echo "instead of just numeric taxid numbers."
echo "Size: ~500 MB download"
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [ -f "$SCRIPT_DIR/setup_blast_taxdb.sh" ]; then
    if [ "$BATCH_MODE" = true ]; then
        # In batch mode, automatically install BLAST taxdb
        echo "BATCH MODE: Automatically installing BLAST taxonomy database..."
        bash "$SCRIPT_DIR/setup_blast_taxdb.sh" "$SCRIPT_DIR/../DBs/NCBIRefSeq"
        if [ $? -eq 0 ]; then
            echo "  ✓ BLAST taxonomy database successfully installed"
        else
            echo "  ✗ Failed to install BLAST taxonomy database"
        fi
    else
        # In interactive mode, ask user
        read -p "Install BLAST taxonomy database? [Y/n]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            echo "Installing BLAST taxdb..."
            bash "$SCRIPT_DIR/setup_blast_taxdb.sh" "$SCRIPT_DIR/../DBs/NCBIRefSeq"
            if [ $? -eq 0 ]; then
                echo "  ✓ BLAST taxonomy database successfully installed"
            else
                echo "  ✗ Failed to install BLAST taxonomy database"
                echo "    You can install it manually later by running: ./scripts/setup_blast_taxdb.sh"
            fi
        else
            echo "Skipping BLAST taxonomy database installation"
            echo "You can install it later by running: ./scripts/setup_blast_taxdb.sh"
        fi
    fi
else
    echo "Warning: setup_blast_taxdb.sh not found in $SCRIPT_DIR"
fi

echo ""

################################################################################
# Configure viral genome databases (optional)
################################################################################
echo "=========================================="
echo "Viral Genome Databases Setup"
echo "=========================================="
echo ""
echo "For viral genome analysis (Phases 1-7), you need additional databases:"
echo "  - VirSorter2 database (~10 GB)"
echo "  - CheckV database (~1.5 GB)"
echo "  - DRAM databases (~150 GB) - requires DRAM_FIX.sh first"
echo "  - Optional: RVDB (~5 GB)"
echo ""
echo "Total space required: ~170 GB"
echo "Total time: 4-8 hours (mostly DRAM download)"
echo ""
echo "IMPORTANT: You must run DRAM_FIX.sh BEFORE setting up databases!"
echo ""

if [ "$BATCH_MODE" = true ]; then
    # In batch mode, skip viral databases (too long, should be separate job)
    echo "BATCH MODE: Skipping viral genome databases setup"
    echo "  To setup viral databases, run separately:"
    echo "  1. bash scripts/DRAM_FIX.sh"
    echo "  2. bash scripts/setup_viral_databases.sh"
    INSTALL_VIRAL_DBS=false
else
    # In interactive mode, ask user
    read -p "Do you want to setup viral genome databases now? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        INSTALL_VIRAL_DBS=true
    else
        INSTALL_VIRAL_DBS=false
    fi
fi

if [ "$INSTALL_VIRAL_DBS" = true ]; then
    echo ""
    echo "Checking for DRAM_FIX.sh..."

    if [ -f "$SCRIPT_DIR/DRAM_FIX.sh" ]; then
        echo "Found DRAM_FIX.sh"
        echo ""
        echo "Step 1/2: Applying DRAM HTTPS fix..."
        bash "$SCRIPT_DIR/DRAM_FIX.sh"

        if [ $? -eq 0 ]; then
            echo "✓ DRAM fix applied successfully"
            echo ""

            if [ -f "$SCRIPT_DIR/setup_viral_databases.sh" ]; then
                echo "Step 2/2: Setting up viral databases..."
                echo "This will take several hours. You can interrupt and resume later."
                echo ""

                if [ "$BATCH_MODE" = true ]; then
                    # Auto-continue in batch mode
                    CONTINUE_DB_SETUP=true
                else
                    # Ask in interactive mode
                    read -p "Continue with database setup? [Y/n]: " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
                        CONTINUE_DB_SETUP=true
                    else
                        CONTINUE_DB_SETUP=false
                    fi
                fi

                if [ "$CONTINUE_DB_SETUP" = true ]; then
                    bash "$SCRIPT_DIR/setup_viral_databases.sh"
                else
                    echo "Skipping database setup for now."
                    echo "To setup databases later, run:"
                    echo "  conda activate $ENV_NAME"
                    echo "  bash scripts/setup_viral_databases.sh"
                fi
            else
                echo "✗ setup_viral_databases.sh not found"
                echo "  Please check scripts/ directory"
            fi
        else
            echo "✗ DRAM fix failed"
            echo "  Cannot proceed with database setup"
        fi
    else
        echo "✗ DRAM_FIX.sh not found in $SCRIPT_DIR"
        echo "  Cannot setup databases without fixing DRAM first"
    fi
else
    echo "Skipping viral database setup."
    echo ""
    echo "To setup databases later:"
    echo "  1. conda activate $ENV_NAME"
    echo "  2. bash scripts/DRAM_FIX.sh"
    echo "  3. bash scripts/setup_viral_databases.sh"
fi

echo ""

################################################################################
# Summary
################################################################################
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Environment: $ENV_NAME"
echo ""
echo "Next steps:"
echo ""
echo "1. Activate the environment:"
echo "   conda activate $ENV_NAME"
echo ""
echo "2. Run the pipeline (single sample):"
echo "   sbatch PIMGAVIR_conda.sh R1.fq.gz R2.fq.gz SampleName 40 ALL"
echo ""
echo "3. Or use batch processing (multiple samples):"
echo "   bash detect_samples.sh"
echo "   sbatch PIMGAVIR_worker.sh"
echo ""
echo "Important notes:"
echo "  - All tools are available via conda (no system modules needed)"
echo "  - Krona taxonomy database has been configured"
echo "  - For viral genome analysis, setup databases as described above"
echo "  - Use 'mamba' instead of 'conda' for faster package management"
echo ""
echo "Documentation:"
echo "  - README.md - User guide"
echo "  - CLAUDE.md - Developer documentation"
echo "  - VIRAL_GENOME_QUICKSTART.md - Viral genome analysis guide"
echo ""

exit 0
