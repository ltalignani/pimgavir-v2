#!/usr/bin/env bash
#
# Setup script for BLAST taxonomy database (taxdb)
# This database is required for BLAST to resolve taxonomy names from taxids
#
# Usage: ./setup_blast_taxdb.sh [BLASTDB_DIR]
#
# The script will:
# 1. Download taxdb.tar.gz from NCBI FTP
# 2. Extract it to BLASTDB directory
# 3. Set BLASTDB environment variable
#

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default BLASTDB directory
DEFAULT_BLASTDB_DIR="../DBs/NCBIRefSeq"
BLASTDB_DIR="${1:-$DEFAULT_BLASTDB_DIR}"

# NCBI FTP URL for taxdb
TAXDB_URL="https://ftp.ncbi.nlm.nih.gov/blast/db/taxdb.tar.gz"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}BLAST Taxonomy Database Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if wget or curl is available
if command -v wget &> /dev/null; then
    DOWNLOAD_CMD="wget -O"
elif command -v curl &> /dev/null; then
    DOWNLOAD_CMD="curl -L -o"
else
    echo -e "${RED}ERROR: Neither wget nor curl is available. Please install one of them.${NC}"
    exit 1
fi

# Create BLASTDB directory if it doesn't exist
if [ ! -d "$BLASTDB_DIR" ]; then
    echo -e "${YELLOW}Creating directory: $BLASTDB_DIR${NC}"
    mkdir -p "$BLASTDB_DIR"
fi

# Resolve absolute path
BLASTDB_DIR=$(cd "$BLASTDB_DIR" && pwd)
echo -e "${GREEN}BLASTDB directory: $BLASTDB_DIR${NC}"
echo ""

# Check if taxdb already exists
if [ -f "$BLASTDB_DIR/taxdb.bti" ] && [ -f "$BLASTDB_DIR/taxdb.btd" ]; then
    echo -e "${YELLOW}Warning: taxdb database already exists in $BLASTDB_DIR${NC}"
    read -p "Do you want to re-download and overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Skipping download. Using existing taxdb.${NC}"
        echo ""
        echo -e "${BLUE}========================================${NC}"
        echo -e "${GREEN}Setup complete!${NC}"
        echo -e "${BLUE}========================================${NC}"
        exit 0
    fi
fi

# Download taxdb.tar.gz
echo -e "${BLUE}Step 1: Downloading taxdb.tar.gz from NCBI...${NC}"
echo "This may take several minutes (file size: ~500 MB)"
echo ""

TAXDB_FILE="$BLASTDB_DIR/taxdb.tar.gz"

if $DOWNLOAD_CMD "$TAXDB_FILE" "$TAXDB_URL"; then
    echo -e "${GREEN}✓ Download successful${NC}"
else
    echo -e "${RED}ERROR: Download failed. Please check your internet connection.${NC}"
    exit 1
fi
echo ""

# Extract taxdb
echo -e "${BLUE}Step 2: Extracting taxdb archive...${NC}"
cd "$BLASTDB_DIR"
if tar -xzf taxdb.tar.gz; then
    echo -e "${GREEN}✓ Extraction successful${NC}"
else
    echo -e "${RED}ERROR: Extraction failed.${NC}"
    exit 1
fi
echo ""

# Verify extracted files
echo -e "${BLUE}Step 3: Verifying extracted files...${NC}"
if [ -f "$BLASTDB_DIR/taxdb.bti" ] && [ -f "$BLASTDB_DIR/taxdb.btd" ]; then
    echo -e "${GREEN}✓ taxdb.bti found${NC}"
    echo -e "${GREEN}✓ taxdb.btd found${NC}"
else
    echo -e "${RED}ERROR: Expected taxdb files not found after extraction.${NC}"
    exit 1
fi
echo ""

# Clean up tar.gz file
echo -e "${BLUE}Step 4: Cleaning up...${NC}"
rm -f "$BLASTDB_DIR/taxdb.tar.gz"
echo -e "${GREEN}✓ Removed taxdb.tar.gz${NC}"
echo ""

# Display file sizes
echo -e "${BLUE}Installed files:${NC}"
ls -lh "$BLASTDB_DIR"/taxdb.* | awk '{print "  " $9 " (" $5 ")"}'
echo ""

# Instructions
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Setup complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT: Set the BLASTDB environment variable${NC}"
echo ""
echo "Add this line to your script or ~/.bashrc:"
echo ""
echo -e "${GREEN}export BLASTDB=\"$BLASTDB_DIR\"${NC}"
echo ""
echo "Or for the current session only:"
echo -e "${GREEN}export BLASTDB=\"$BLASTDB_DIR\"${NC}"
echo ""
echo "The PIMGAVIR pipeline scripts will be updated to set this automatically."
echo ""
echo -e "${BLUE}========================================${NC}"
