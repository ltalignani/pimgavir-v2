#!/bin/bash
################################################################################
# DRAM Complete Fix Script for IRD Cluster
#
# This script fixes BOTH major DRAM issues:
#   1. FTP → HTTPS conversion (firewall blocks FTP)
#   2. VOG HMM path bug (GitHub issue #718)
#
# Usage:
#   bash DRAM_FIX.sh
#
# Requirements:
#   - pimgavir_viralgenomes conda environment
#   - DRAM installed in conda environment
#
# Version: 2.2.0 - 2025-11-03
# Author: PIMGAVir Pipeline
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================="
echo "DRAM Complete Fix Script v2.2.0"
echo "=========================================="
echo ""
echo "This script will fix:"
echo "  1. FTP → HTTPS conversion (firewall bypass)"
echo "  2. VOG HMM path bug (issue #718)"
echo ""

# ============================================================================
# STEP 1: Activate Conda Environment
# ============================================================================

echo -e "${BLUE}[1/7] Activating conda environment...${NC}"

if [ -n "$CONDA_DEFAULT_ENV" ]; then
    echo -e "   ${GREEN}✓ Already active: $CONDA_DEFAULT_ENV${NC}"
else
    if ! conda activate pimgavir_viralgenomes 2>/dev/null; then
        source ~/miniconda3/etc/profile.d/conda.sh
        conda activate pimgavir_viralgenomes
    fi
    echo -e "   ${GREEN}✓ Activated: pimgavir_viralgenomes${NC}"
fi

if [ -z "$CONDA_PREFIX" ]; then
    echo -e "${RED}ERROR: Could not activate conda environment${NC}"
    echo "Please ensure pimgavir_viralgenomes environment exists:"
    echo "  conda env list"
    exit 1
fi

echo "   Environment path: $CONDA_PREFIX"
echo ""

# ============================================================================
# STEP 2: Locate DRAM Installation
# ============================================================================

echo -e "${BLUE}[2/7] Locating DRAM installation...${NC}"

DRAM_DIR=$(python -c "import mag_annotator; import os; print(os.path.dirname(mag_annotator.__file__))" 2>/dev/null)

if [ -z "$DRAM_DIR" ]; then
    echo -e "${RED}ERROR: Could not find DRAM installation${NC}"
    echo ""
    echo "Possible causes:"
    echo "  - DRAM not installed in this environment"
    echo "  - Wrong conda environment active"
    echo ""
    echo "Try:"
    echo "  conda install -c bioconda dram"
    exit 1
fi

echo -e "   ${GREEN}✓ Found: $DRAM_DIR${NC}"
echo ""

TARGET_FILE="$DRAM_DIR/database_processing.py"

if [ ! -f "$TARGET_FILE" ]; then
    echo -e "${RED}ERROR: database_processing.py not found${NC}"
    echo "Expected location: $TARGET_FILE"
    exit 1
fi

echo -e "   ${GREEN}✓ Target file: database_processing.py${NC}"
echo ""

# ============================================================================
# STEP 3: Create Backups
# ============================================================================

echo -e "${BLUE}[3/7] Creating backups...${NC}"

# Timestamped backup directory
BACKUP_DIR=~/DRAM_backups/$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_DIR"
cp "$TARGET_FILE" "$BACKUP_DIR/database_processing.py"
echo -e "   ${GREEN}✓ Timestamped backup: $BACKUP_DIR/${NC}"

# Original backup (only if doesn't exist)
if [ ! -f "${TARGET_FILE}.original" ]; then
    cp "$TARGET_FILE" "${TARGET_FILE}.original"
    echo -e "   ${GREEN}✓ Original backup: ${TARGET_FILE}.original${NC}"
else
    echo -e "   ${YELLOW}ℹ Original backup already exists${NC}"
fi

echo ""

# ============================================================================
# STEP 4: Analyze Current State
# ============================================================================

echo -e "${BLUE}[4/7] Analyzing current file...${NC}"

# Count FTP URLs
FTP_COUNT=$(grep -c "ftp://" "$TARGET_FILE" || true)
HTTPS_COUNT=$(grep -c "https://" "$TARGET_FILE" || true)

echo "   Current state:"
echo "     FTP URLs: $FTP_COUNT"
echo "     HTTPS URLs: $HTTPS_COUNT"

# Check VOG bug
if grep -q "path\.join(hmm_dir, 'VOG\*\.hmm')" "$TARGET_FILE"; then
    VOG_BUG_PRESENT=true
    echo -e "     VOG bug: ${YELLOW}Present${NC}"
else
    VOG_BUG_PRESENT=false
    echo -e "     VOG bug: ${GREEN}Already fixed${NC}"
fi

echo ""

# Check if already patched
if [ "$FTP_COUNT" -eq 0 ] && [ "$VOG_BUG_PRESENT" = false ]; then
    echo -e "${GREEN}File appears already patched!${NC}"
    echo ""
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Exiting without changes."
        exit 0
    fi
fi

# ============================================================================
# STEP 5: Apply FTP → HTTPS Patches
# ============================================================================

echo -e "${BLUE}[5/7] Applying FTP → HTTPS patches...${NC}"

# Create working backup
cp "$TARGET_FILE" "${TARGET_FILE}.backup"

# Apply all FTP→HTTPS replacements
echo "   Patching URLs..."

# 1. KOfam URLs
sed -i.tmp "s|ftp://ftp\.genome\.jp/pub/db/kofam/|https://www.genome.jp/ftp/db/kofam/|g" "$TARGET_FILE"
echo -e "     ${GREEN}✓${NC} KOfam URLs"

# 2. Pfam URLs
sed -i.tmp "s|ftp://ftp\.ebi\.ac\.uk/pub/databases/Pfam/|https://ftp.ebi.ac.uk/pub/databases/Pfam/|g" "$TARGET_FILE"
echo -e "     ${GREEN}✓${NC} Pfam URLs"

# 3. UniProt/UniRef URLs
sed -i.tmp "s|ftp://ftp\.uniprot\.org/pub/databases/uniprot/|https://ftp.uniprot.org/pub/databases/uniprot/|g" "$TARGET_FILE"
echo -e "     ${GREEN}✓${NC} UniProt URLs"

# 4. MEROPS URLs
sed -i.tmp "s|ftp://ftp\.ebi\.ac\.uk/pub/databases/merops/|https://ftp.ebi.ac.uk/pub/databases/merops/|g" "$TARGET_FILE"
echo -e "     ${GREEN}✓${NC} MEROPS URLs"

# 5. VOG URLs
sed -i.tmp "s|ftp://fileshare\.csb\.univie\.ac\.at/vog/|https://fileshare.csb.univie.ac.at/vog/|g" "$TARGET_FILE"
echo -e "     ${GREEN}✓${NC} VOG URLs"

# 6. Generic FTP URLs (catch-all)
sed -i.tmp "s|ftp://ftp\.|https://ftp.|g" "$TARGET_FILE"
echo -e "     ${GREEN}✓${NC} Generic FTP URLs"

# Clean up temp files
rm -f "${TARGET_FILE}.tmp"

echo ""

# ============================================================================
# STEP 6: Apply VOG HMM Path Fix
# ============================================================================

echo -e "${BLUE}[6/7] Applying VOG HMM path fix...${NC}"
echo "   Issue: https://github.com/metagenome-atlas/atlas/issues/718"
echo ""

if [ "$VOG_BUG_PRESENT" = true ]; then
    echo "   Fixing VOG path bug..."

    # Apply VOG fix
    sed -i.tmp "s|path\.join(hmm_dir, 'VOG\*\.hmm')|path.join(hmm_dir, 'hmm', 'VOG*.hmm')|g" "$TARGET_FILE"
    rm -f "${TARGET_FILE}.tmp"

    # Verify fix was applied
    if grep -q "path\.join(hmm_dir, 'hmm', 'VOG\*\.hmm')" "$TARGET_FILE"; then
        echo -e "   ${GREEN}✓ VOG path fixed successfully${NC}"
        echo ""
        echo "   Changed in process_vogdb() function:"
        echo -e "     ${RED}OLD:${NC} glob(path.join(hmm_dir, 'VOG*.hmm'))"
        echo -e "     ${GREEN}NEW:${NC} glob(path.join(hmm_dir, 'hmm', 'VOG*.hmm'))"
    else
        echo -e "   ${RED}✗ VOG fix verification failed${NC}"
        echo "   Restoring from backup..."
        cp "${TARGET_FILE}.backup" "$TARGET_FILE"
        exit 1
    fi
else
    echo -e "   ${GREEN}✓ VOG path already fixed (no action needed)${NC}"
fi

# Clean up backup
rm -f "${TARGET_FILE}.backup"

echo ""

# ============================================================================
# STEP 7: Verify All Changes
# ============================================================================

echo -e "${BLUE}[7/7] Verifying patches...${NC}"

# Count URLs after patching
NEW_FTP_COUNT=$(grep -c "ftp://" "$TARGET_FILE" || true)
NEW_HTTPS_COUNT=$(grep -c "https://" "$TARGET_FILE" || true)

echo "   After patching:"
echo "     FTP URLs: $NEW_FTP_COUNT"
echo "     HTTPS URLs: $NEW_HTTPS_COUNT"

# Verify VOG fix
if grep -q "path\.join(hmm_dir, 'hmm', 'VOG\*\.hmm')" "$TARGET_FILE"; then
    echo -e "     VOG fix: ${GREEN}Applied ✓${NC}"
else
    echo -e "     VOG fix: ${YELLOW}Not found (may already be different)${NC}"
fi

echo ""

# Overall status
if [ "$NEW_FTP_COUNT" -eq 0 ]; then
    echo -e "${GREEN}=========================================="
    echo "✓ PATCH SUCCESSFUL!"
    echo "==========================================${NC}"
else
    echo -e "${YELLOW}=========================================="
    echo "⚠ PATCH PARTIALLY SUCCESSFUL"
    echo "==========================================${NC}"
    echo ""
    echo -e "${YELLOW}Warning: $NEW_FTP_COUNT FTP URLs remain${NC}"
    echo ""
    echo "Remaining FTP URLs:"
    grep -n "ftp://" "$TARGET_FILE" || true
    echo ""
    echo "These may require manual review or be non-critical."
fi

echo ""
echo "Backup location: $BACKUP_DIR"
echo ""

# ============================================================================
# Next Steps
# ============================================================================

echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo ""
echo "1. Test DRAM installation:"
echo ""
echo "   cd /projects/large/PIMGAVIR/pimgavir_dev/DBs/ViralGenomes/"
echo ""
echo "   # Clear previous failed attempts (optional)"
echo "   rm -rf dram-db/*"
echo ""
echo "   # Install DRAM databases"
echo "   DRAM-setup.py prepare_databases \\"
echo "       --output_dir ./dram-db \\"
echo "       --skip_uniref \\"
echo "       --threads 8 \\"
echo "       --verbose 2>&1 | tee dram_setup_\$(date +%Y%m%d_%H%M%S).log"
echo ""
echo "2. Monitor installation (takes 3-4 hours):"
echo ""
echo "   # Use screen to prevent disconnection"
echo "   screen -S dram_install"
echo "   # Run command above"
echo "   # Detach: Ctrl+A then D"
echo "   # Reattach: screen -r dram_install"
echo ""
echo "3. Verify installation:"
echo ""
echo "   DRAM-setup.py print_config"
echo ""
echo "4. If problems occur, restore backup:"
echo ""
echo "   cp ${TARGET_FILE}.original $TARGET_FILE"
echo ""
echo "=========================================="
echo "Complete troubleshooting guide:"
echo "fixes/DRAM_TROUBLESHOOTING.md"
echo "=========================================="
echo ""

exit 0
