#!/bin/bash

################################################################################
# PIMGAVir - Test Viral Genome Databases
#
# Purpose: Verify that all required viral genome databases are properly installed
#
# Usage: bash scripts/test_viral_databases.sh
#
# Version: 1.0 - 2025-11-04
################################################################################

set -e

echo "=========================================="
echo "PIMGAVir - Viral Database Verification"
echo "=========================================="
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Check for PIMGAVIR_DBS_DIR environment variable (v2.2)
if [ -n "${PIMGAVIR_DBS_DIR:-}" ]; then
    DB_BASE_DIR="${PIMGAVIR_DBS_DIR}"
    echo "Using PIMGAVIR_DBS_DIR: $DB_BASE_DIR"
else
    DB_BASE_DIR="${PROJECT_DIR}/DBs"
    echo "Using default DBs directory: $DB_BASE_DIR"
fi
echo ""

# Track status
ALL_OK=true

################################################################################
# Check VirSorter2 Database
################################################################################
echo "Checking VirSorter2 database..."
VIRSORTER_DB="${DB_BASE_DIR}/ViralGenomes/virsorter2-db"

if [ -d "$VIRSORTER_DB" ]; then
    if [ -f "$VIRSORTER_DB/done" ]; then
        echo "  ✓ VirSorter2 database found and installed"
        echo "    Location: $VIRSORTER_DB"
        # Check database size
        DB_SIZE=$(du -sh "$VIRSORTER_DB" | cut -f1)
        echo "    Size: $DB_SIZE"
    else
        echo "  ⚠ VirSorter2 database directory exists but installation incomplete"
        echo "    Location: $VIRSORTER_DB"
        echo "    Run: bash scripts/setup_viral_databases.sh"
        ALL_OK=false
    fi
else
    echo "  ✗ VirSorter2 database NOT found"
    echo "    Expected location: $VIRSORTER_DB"
    echo "    Run: bash scripts/setup_viral_databases.sh"
    ALL_OK=false
fi
echo ""

################################################################################
# Check CheckV Database
################################################################################
echo "Checking CheckV database..."
CHECKV_DB="${DB_BASE_DIR}/ViralGenomes/checkv-db-v1.5"

if [ -d "$CHECKV_DB" ]; then
    if [ -f "$CHECKV_DB/genome_db/checkv_reps.dmnd" ]; then
        echo "  ✓ CheckV database found and installed"
        echo "    Location: $CHECKV_DB"
        # Check database size
        DB_SIZE=$(du -sh "$CHECKV_DB" | cut -f1)
        echo "    Size: $DB_SIZE"
    else
        echo "  ⚠ CheckV database directory exists but installation incomplete"
        echo "    Location: $CHECKV_DB"
        echo "    Missing: genome_db/checkv_reps.dmnd"
        echo "    Run: bash scripts/setup_viral_databases.sh"
        ALL_OK=false
    fi
else
    echo "  ✗ CheckV database NOT found"
    echo "    Expected location: $CHECKV_DB"
    echo "    Run: bash scripts/setup_viral_databases.sh"
    ALL_OK=false
fi
echo ""

################################################################################
# Check DRAM Database (Optional)
################################################################################
echo "Checking DRAM database (optional for Phase 2)..."
DRAM_DB="${DB_BASE_DIR}/ViralGenomes/dram-data"

if [ -d "$DRAM_DB" ]; then
    echo "  ✓ DRAM database found"
    echo "    Location: $DRAM_DB"
    # Check database size
    DB_SIZE=$(du -sh "$DRAM_DB" | cut -f1)
    echo "    Size: $DB_SIZE"
else
    echo "  ⚠ DRAM database not found (optional)"
    echo "    Expected location: $DRAM_DB"
    echo "    Phase 2 (functional annotation) will not be available"
    echo "    To install: bash scripts/setup_viral_databases.sh"
fi
echo ""

################################################################################
# Check RVDB (Optional)
################################################################################
echo "Checking RVDB database (optional)..."
RVDB_DB="${DB_BASE_DIR}/ViralGenomes/rvdb"

if [ -d "$RVDB_DB" ]; then
    echo "  ✓ RVDB database found"
    echo "    Location: $RVDB_DB"
    # Check database size
    DB_SIZE=$(du -sh "$RVDB_DB" | cut -f1)
    echo "    Size: $DB_SIZE"
else
    echo "  ⚠ RVDB database not found (optional)"
    echo "    Expected location: $RVDB_DB"
    echo "    Can be used for additional BLAST comparisons"
    echo "    To install: bash scripts/setup_viral_databases.sh"
fi
echo ""

################################################################################
# Summary
################################################################################
echo "=========================================="
echo "Summary"
echo "=========================================="

if [ "$ALL_OK" = true ]; then
    echo "✓ All REQUIRED viral databases are properly installed!"
    echo ""
    echo "You can now run viral genome analysis (Phase 1):"
    echo "  bash scripts/viral-genome-recovery.sh <contigs> <output> <threads> <sample> <assembler>"
    echo ""
    echo "Or run the complete 7-phase analysis:"
    echo "  bash scripts/viral-genome-complete-7phases.sh <contigs> <output> <threads> <sample> \"\" \"\" \"\" <assembler>"
else
    echo "✗ Some REQUIRED databases are missing or incomplete"
    echo ""
    echo "To install missing databases, run:"
    echo "  cd scripts/"
    echo "  bash DRAM_FIX.sh              # Run FIRST (iTrop cluster only)"
    echo "  bash setup_viral_databases.sh  # Then install databases"
    echo ""
    echo "Estimated time: 4-8 hours"
    echo "Required space: ~170 GB (with DRAM) or ~12 GB (minimal)"
    exit 1
fi

echo "=========================================="
exit 0
