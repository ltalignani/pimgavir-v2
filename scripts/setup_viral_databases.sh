#!/bin/bash

################################################################################
# PIMGAVir - Viral Genome Database Setup Script
#
# Purpose: Download and configure required databases for viral genome analysis
#
# Databases installed:
#   1. VirSorter2 database (~10 GB)
#   2. CheckV database (~1.5 GB)
#   3. DRAM databases (KEGG, Pfam, etc.) (~150 GB total)
#   4. Optional: RVDB (Reference Viral Database) for BLAST
#
# Requirements:
#   - Internet connection
#   - ~200 GB free disk space (for all databases)
#   - conda environment: pimgavir_viralgenomes
#
# IMPORTANT PREREQUISITE:
#   *** Run DRAM_FIX.sh BEFORE using this script ***
#   This fixes DRAM's HTTPS download issues. Run:
#     bash scripts/DRAM_FIX.sh
#
# Version: 1.1 - 2025-11-03
################################################################################

set -eo pipefail

################################################################################
# Activate Conda Environment
################################################################################

# Initialize conda for bash shell
if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
elif [ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/anaconda3/etc/profile.d/conda.sh"
elif [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then
    source "/opt/conda/etc/profile.d/conda.sh"
else
    echo "ERROR: Cannot find conda installation"
    echo "Please ensure conda is installed and initialized"
    exit 1
fi

# Activate the viral genomes environment
echo "Activating pimgavir_viralgenomes conda environment..."
conda activate pimgavir_viralgenomes || {
    echo "ERROR: Failed to activate pimgavir_viralgenomes environment"
    echo "Please create it first using:"
    echo "  conda env create -f scripts/pimgavir_viralgenomes.yaml"
    exit 1
}

echo "Using conda environment: $CONDA_DEFAULT_ENV"
echo ""

################################################################################
# Configuration
################################################################################

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Database directory
DB_BASE_DIR="${PROJECT_DIR}/DBs/ViralGenomes"
mkdir -p "$DB_BASE_DIR"

# Log file
LOGFILE="${DB_BASE_DIR}/setup_log_$(date +%Y%m%d_%H%M%S).log"

echo "==========================================" | tee -a "$LOGFILE"
echo "PIMGAVir - Viral Genome Database Setup" | tee -a "$LOGFILE"
echo "==========================================" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"
echo "IMPORTANT: Make sure you have run DRAM_FIX.sh before this script!" | tee -a "$LOGFILE"
echo "This fixes DRAM's HTTPS download issues." | tee -a "$LOGFILE"
echo "If not done yet, stop this script (Ctrl+C) and run:" | tee -a "$LOGFILE"
echo "  bash scripts/DRAM_FIX.sh" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"
read -p "Press ENTER to continue if DRAM_FIX.sh has already been run, or Ctrl+C to stop..."
echo "" | tee -a "$LOGFILE"
echo "Database directory: $DB_BASE_DIR" | tee -a "$LOGFILE"
echo "Started: $(date)" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

################################################################################
# Check Conda Environment
################################################################################
echo "Checking conda environment..." | tee -a "$LOGFILE"

if [ -z "$CONDA_DEFAULT_ENV" ]; then
    echo "ERROR: No conda environment active" | tee -a "$LOGFILE"
    echo "Please activate pimgavir_viralgenomes environment:" | tee -a "$LOGFILE"
    echo "  conda activate pimgavir_viralgenomes" | tee -a "$LOGFILE"
    exit 1
fi

echo "Active environment: $CONDA_DEFAULT_ENV" | tee -a "$LOGFILE"

# Check for required tools
echo "Checking required tools..." | tee -a "$LOGFILE"
MISSING_TOOLS=()

command -v virsorter >/dev/null 2>&1 || MISSING_TOOLS+=("virsorter")
command -v checkv >/dev/null 2>&1 || MISSING_TOOLS+=("checkv")
command -v makeblastdb >/dev/null 2>&1 || MISSING_TOOLS+=("blast (makeblastdb)")
command -v wget >/dev/null 2>&1 || MISSING_TOOLS+=("wget")

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo "WARNING: Some tools are missing:" | tee -a "$LOGFILE"
    for tool in "${MISSING_TOOLS[@]}"; do
        echo "  - $tool" | tee -a "$LOGFILE"
    done
    echo "" | tee -a "$LOGFILE"
    echo "Installing missing tools..." | tee -a "$LOGFILE"
    conda install -y -c bioconda blast wget || {
        echo "ERROR: Failed to install missing tools" | tee -a "$LOGFILE"
        echo "Please install manually with:" | tee -a "$LOGFILE"
        echo "  conda install -c bioconda blast wget" | tee -a "$LOGFILE"
        exit 1
    }
else
    echo "All required tools found: OK" | tee -a "$LOGFILE"
fi
echo "" | tee -a "$LOGFILE"

################################################################################
# Function: Check disk space
################################################################################
check_disk_space() {
    local required_gb=$1
    local available_kb=$(df "$DB_BASE_DIR" | tail -1 | awk '{print $4}')
    local available_gb=$((available_kb / 1024 / 1024))

    echo "Available disk space: ${available_gb} GB" | tee -a "$LOGFILE"
    echo "Required disk space: ${required_gb} GB" | tee -a "$LOGFILE"

    if [ "$available_gb" -lt "$required_gb" ]; then
        echo "ERROR: Insufficient disk space" | tee -a "$LOGFILE"
        echo "Please free up at least $((required_gb - available_gb)) GB" | tee -a "$LOGFILE"
        return 1
    fi

    echo "Disk space: OK" | tee -a "$LOGFILE"
    return 0
}

################################################################################
# 1. VirSorter2 Database
################################################################################
echo "==========================================" | tee -a "$LOGFILE"
echo "1. Setting up VirSorter2 Database" | tee -a "$LOGFILE"
echo "==========================================" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

VIRSORTER_DB="${DB_BASE_DIR}/virsorter2-db"

if [ -d "$VIRSORTER_DB" ] && [ -f "$VIRSORTER_DB/done" ]; then
    echo "VirSorter2 database already exists: $VIRSORTER_DB" | tee -a "$LOGFILE"
else
    echo "Downloading VirSorter2 database (~10 GB)..." | tee -a "$LOGFILE"
    echo "This may take 30-60 minutes depending on connection speed..." | tee -a "$LOGFILE"

    check_disk_space 15 || exit 1

    # Download VirSorter2 database
    virsorter setup -d "$VIRSORTER_DB" -j 4 2>&1 | tee -a "$LOGFILE"

    if [ $? -eq 0 ]; then
        touch "$VIRSORTER_DB/done"
        echo "VirSorter2 database installed successfully" | tee -a "$LOGFILE"
    else
        echo "ERROR: VirSorter2 database installation failed" | tee -a "$LOGFILE"
        exit 1
    fi
fi

# Set environment variable for VirSorter2
echo "export VIRSORTER_DATA=\"$VIRSORTER_DB\"" >> "${DB_BASE_DIR}/viral_db_env.sh"

echo "" | tee -a "$LOGFILE"

################################################################################
# 2. CheckV Database
################################################################################
echo "==========================================" | tee -a "$LOGFILE"
echo "2. Setting up CheckV Database" | tee -a "$LOGFILE"
echo "==========================================" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

CHECKV_DB="${DB_BASE_DIR}/checkv-db-v1.5"

if [ -d "$CHECKV_DB" ] && [ -f "$CHECKV_DB/genome_db/checkv_reps.dmnd" ]; then
    echo "CheckV database already exists: $CHECKV_DB" | tee -a "$LOGFILE"
else
    echo "Downloading CheckV database (~1.5 GB)..." | tee -a "$LOGFILE"

    check_disk_space 3 || exit 1

    cd "$DB_BASE_DIR"

    # Download CheckV database
    wget https://portal.nersc.gov/CheckV/checkv-db-v1.5.tar.gz 2>&1 | tee -a "$LOGFILE"

    if [ $? -eq 0 ]; then
        echo "Extracting CheckV database..." | tee -a "$LOGFILE"
        tar -xzf checkv-db-v1.5.tar.gz 2>&1 | tee -a "$LOGFILE"
        rm checkv-db-v1.5.tar.gz

        # Build diamond database
        echo "Building CheckV Diamond database..." | tee -a "$LOGFILE"
        diamond makedb \
            --in "${CHECKV_DB}/genome_db/checkv_reps.faa" \
            --db "${CHECKV_DB}/genome_db/checkv_reps" \
            2>&1 | tee -a "$LOGFILE"

        echo "CheckV database installed successfully" | tee -a "$LOGFILE"
    else
        echo "ERROR: CheckV database download failed" | tee -a "$LOGFILE"
        exit 1
    fi
fi

# Set environment variable for CheckV
echo "export CHECKVDB=\"$CHECKV_DB\"" >> "${DB_BASE_DIR}/viral_db_env.sh"

echo "" | tee -a "$LOGFILE"

################################################################################
# 3. DRAM Databases
################################################################################
echo "==========================================" | tee -a "$LOGFILE"
echo "3. Setting up DRAM Databases" | tee -a "$LOGFILE"
echo "==========================================" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

DRAM_DB="${DB_BASE_DIR}/dram-db"

echo "WARNING: DRAM database setup requires ~150 GB disk space" | tee -a "$LOGFILE"
echo "This includes KEGG, Pfam, dbCAN, MEROPS, and other databases" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

read -p "Do you want to install DRAM databases? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    check_disk_space 180 || exit 1

    echo "Setting up DRAM databases..." | tee -a "$LOGFILE"
    echo "This will take several hours (4-8 hours typically)" | tee -a "$LOGFILE"
    echo "" | tee -a "$LOGFILE"

    # Setup DRAM databases
    DRAM-setup.py prepare_databases \
        --output_dir "$DRAM_DB" \
        --skip_uniref \
        --threads 8 \
        --verbose 2>&1 | tee -a "$LOGFILE"

    if [ $? -eq 0 ]; then
        echo "DRAM databases installed successfully" | tee -a "$LOGFILE"

        # Set DRAM config
        DRAM-setup.py set_database_locations \
            --output_dir "$DRAM_DB" \
            2>&1 | tee -a "$LOGFILE"
    else
        echo "ERROR: DRAM database installation failed" | tee -a "$LOGFILE"
        echo "You can retry later by running this script again" | tee -a "$LOGFILE"
    fi
else
    echo "Skipping DRAM database installation" | tee -a "$LOGFILE"
    echo "WARNING: DRAM-v annotation will not work without these databases" | tee -a "$LOGFILE"
    echo "You can install them later by running:" | tee -a "$LOGFILE"
    echo "  DRAM-setup.py prepare_databases --output_dir $DRAM_DB" | tee -a "$LOGFILE"
fi

echo "" | tee -a "$LOGFILE"

################################################################################
# 4. RVDB (Reference Viral Database) - Optional
################################################################################
echo "==========================================" | tee -a "$LOGFILE"
echo "4. Setting up RVDB (Optional)" | tee -a "$LOGFILE"
echo "==========================================" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

RVDB_DIR="${DB_BASE_DIR}/RVDB"

echo "RVDB is a reference viral database useful for BLAST comparisons" | tee -a "$LOGFILE"
echo "Size: ~5 GB" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

read -p "Do you want to install RVDB? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    check_disk_space 10 || exit 1

    mkdir -p "$RVDB_DIR"
    cd "$RVDB_DIR"

    echo "Downloading RVDB..." | tee -a "$LOGFILE"

    # Download latest RVDB
    RVDB_VERSION="30.0"
    RVDB_FILE="U-RVDBv${RVDB_VERSION}.fasta"

    wget https://rvdb.dbi.udel.edu/download/${RVDB_FILE}.gz 2>&1 | tee -a "$LOGFILE"

    if [ $? -eq 0 ]; then
        echo "Extracting RVDB..." | tee -a "$LOGFILE"
        gunzip -f ${RVDB_FILE}.gz

        echo "Building BLAST database..." | tee -a "$LOGFILE"
        makeblastdb \
            -in ${RVDB_FILE} \
            -dbtype nucl \
            -out RVDB \
            -title "Reference Viral Database v${RVDB_VERSION}" \
            2>&1 | tee -a "$LOGFILE"

        # Note: RVDB contains nucleotide sequences, not protein
        # If protein database is needed, translate sequences first
        echo "Note: RVDB nucleotide database created" | tee -a "$LOGFILE"
        echo "For protein searches, use Diamond with translated sequences" | tee -a "$LOGFILE"

        echo "RVDB installed successfully" | tee -a "$LOGFILE"
    else
        echo "ERROR: RVDB download failed" | tee -a "$LOGFILE"
    fi
else
    echo "Skipping RVDB installation" | tee -a "$LOGFILE"
fi

# Set environment variable for RVDB
echo "export RVDB=\"$RVDB_DIR/RVDB\"" >> "${DB_BASE_DIR}/viral_db_env.sh"

echo "" | tee -a "$LOGFILE"

################################################################################
# Summary
################################################################################
echo "==========================================" | tee -a "$LOGFILE"
echo "Database Setup Summary" | tee -a "$LOGFILE"
echo "==========================================" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

echo "Installed databases:" | tee -a "$LOGFILE"
[ -d "$VIRSORTER_DB" ] && echo "  ✓ VirSorter2: $VIRSORTER_DB" | tee -a "$LOGFILE"
[ -d "$CHECKV_DB" ] && echo "  ✓ CheckV: $CHECKV_DB" | tee -a "$LOGFILE"
[ -d "$DRAM_DB" ] && echo "  ✓ DRAM: $DRAM_DB" | tee -a "$LOGFILE"
[ -d "$RVDB_DIR" ] && echo "  ✓ RVDB: $RVDB_DIR" | tee -a "$LOGFILE"

echo "" | tee -a "$LOGFILE"
echo "Environment variables saved to: ${DB_BASE_DIR}/viral_db_env.sh" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"
echo "To use these databases, add to your scripts:" | tee -a "$LOGFILE"
echo "  source ${DB_BASE_DIR}/viral_db_env.sh" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

# Calculate total size
TOTAL_SIZE=$(du -sh "$DB_BASE_DIR" | cut -f1)
echo "Total database size: $TOTAL_SIZE" | tee -a "$LOGFILE"

echo "" | tee -a "$LOGFILE"
echo "==========================================" | tee -a "$LOGFILE"
echo "Database Setup Complete" | tee -a "$LOGFILE"
echo "==========================================" | tee -a "$LOGFILE"
echo "Completed: $(date)" | tee -a "$LOGFILE"
echo "Log file: $LOGFILE" | tee -a "$LOGFILE"
echo "" | tee -a "$LOGFILE"

exit 0
