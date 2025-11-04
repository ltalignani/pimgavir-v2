#!/bin/bash
################################################################################
# Test Script for pimgavir_viralgenomes Conda Environment
#
# Purpose: Verify that all critical tools are installed and functional
#
# Usage:
#   conda activate pimgavir_viralgenomes
#   bash test_viral_environment.sh
#
# Version: 1.0 - 2025-11-01
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

echo "=========================================="
echo "PIMGAVir Viral Environment Test Suite"
echo "=========================================="
echo ""

# Check conda environment
if [ -z "$CONDA_DEFAULT_ENV" ]; then
    echo -e "${RED}ERROR: No conda environment active${NC}"
    echo "Please activate environment first:"
    echo "  conda activate pimgavir_viralgenomes"
    exit 1
fi

echo -e "${BLUE}Testing environment: $CONDA_DEFAULT_ENV${NC}"
echo ""

################################################################################
# Function to test command availability
################################################################################
test_command() {
    local cmd=$1
    local description=$2

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $description ($cmd)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $description ($cmd) - NOT FOUND"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

################################################################################
# Function to test command version
################################################################################
test_version() {
    local cmd=$1
    local version_flag=$2
    local description=$3

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if command -v "$cmd" >/dev/null 2>&1; then
        version_output=$($cmd $version_flag 2>&1 | head -3 | tr '\n' ' ')
        echo -e "${GREEN}✓${NC} $description: ${YELLOW}${version_output}${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $description ($cmd) - NOT FOUND"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

################################################################################
# Base Tools
################################################################################
echo -e "${BLUE}=== Base Tools ===${NC}"
test_command python "Python interpreter"
test_command pip "Python package manager"
test_command perl "Perl interpreter"
test_command java "Java runtime"
echo ""

################################################################################
# Quality Control
################################################################################
echo -e "${BLUE}=== Quality Control and Preprocessing ===${NC}"
test_command fastqc "FastQC"
test_command cutadapt "Cutadapt"
test_command trim_galore "Trim Galore"
test_command bbduk.sh "BBDuk (BBMap)"
echo ""

################################################################################
# Taxonomic Classification
################################################################################
echo -e "${BLUE}=== Taxonomic Classification ===${NC}"
test_command kraken2 "Kraken2"
test_command kaiju "Kaiju"
test_command ktImportTaxonomy "Krona"
echo ""

################################################################################
# Assembly
################################################################################
echo -e "${BLUE}=== Assembly and Improvement ===${NC}"
test_command megahit "MEGAHIT"
test_command spades.py "SPAdes"
test_command quast.py "QUAST"
test_command bowtie2 "Bowtie2"
test_command samtools "SAMtools"
test_command pilon "Pilon"
echo ""

################################################################################
# Sequence Analysis
################################################################################
echo -e "${BLUE}=== Sequence Analysis and Annotation ===${NC}"
test_version makeblastdb "-version" "BLAST+ (makeblastdb)"
test_command blastn "BLAST+ (blastn)"
test_command blastp "BLAST+ (blastp)"
test_command blastx "BLAST+ (blastx)"
test_command diamond "Diamond"
test_command prokka "Prokka"
test_command vsearch "VSEARCH"
test_command seqkit "SeqKit"
test_command seqtk "Seqtk"
echo ""

################################################################################
# Utilities
################################################################################
echo -e "${BLUE}=== Utilities ===${NC}"
test_command taxonkit "TaxonKit"
test_command parallel "GNU Parallel"
test_command wget "wget"
test_command curl "curl"
test_command pigz "pigz"
test_command pbzip2 "pbzip2"
test_command gunzip "gunzip"
test_command bunzip2 "bunzip2"
echo ""

################################################################################
# HMM Tools
################################################################################
echo -e "${BLUE}=== HMMER and Profile Search ===${NC}"
test_command hmmsearch "HMMER (hmmsearch)"
test_command hmmpress "HMMER (hmmpress)"
test_command cmsearch "Infernal"
test_command aragorn "ARAGORN"
test_command barrnap "Barrnap"
test_command minced "MinCED"
test_command tRNAscan-SE "tRNAscan-SE"
echo ""

################################################################################
# Phase 1: Viral Genome Recovery
################################################################################
echo -e "${BLUE}=== Phase 1: Viral Genome Recovery ===${NC}"
test_command virsorter "VirSorter2"
test_command checkv "CheckV"
test_command prodigal "Prodigal"
test_command prodigal-gv "Prodigal-gv"
test_command vrhyme "vRhyme"
echo ""

################################################################################
# Phase 2: Functional Annotation
################################################################################
echo -e "${BLUE}=== Phase 2: Functional Annotation ===${NC}"
test_command DRAM-setup.py "DRAM (setup)"
test_command DRAM.py "DRAM (annotate)"
echo ""

################################################################################
# Phase 3: Phylogenetic Analysis
################################################################################
echo -e "${BLUE}=== Phase 3: Phylogenetic Analysis ===${NC}"
test_command mafft "MAFFT"
test_command trimal "trimAl"
test_command iqtree "IQ-TREE"
test_command mb "MrBayes"
test_command raxml-ng "RAxML-NG"
test_command fasttree "FastTree"
echo ""

################################################################################
# Phase 4: Comparative Genomics
################################################################################
echo -e "${BLUE}=== Phase 4: Comparative Genomics ===${NC}"
test_command mmseqs "MMseqs2"
test_command cd-hit "CD-HIT"
test_command vcontact2 "vConTACT2"
test_command genomad "geNomad"
test_command mash "Mash"
echo ""

################################################################################
# Phase 5: Additional Tools
################################################################################
echo -e "${BLUE}=== Phase 5: Additional Analysis Tools ===${NC}"
test_command bedtools "BEDtools"
test_command seqret "EMBOSS"
echo ""

################################################################################
# Visualization and Reporting
################################################################################
echo -e "${BLUE}=== Visualization and Reporting ===${NC}"
test_command R "R"
test_command Rscript "Rscript"

# Test R packages
TOTAL_TESTS=$((TOTAL_TESTS + 1))
if R -q -e 'library(ggplot2)' >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} R package: ggplot2"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗${NC} R package: ggplot2 - NOT FOUND"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

TOTAL_TESTS=$((TOTAL_TESTS + 1))
if R -q -e 'library(dplyr)' >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} R package: dplyr"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗${NC} R package: dplyr - NOT FOUND"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

################################################################################
# Python Packages
################################################################################
echo -e "${BLUE}=== Python Packages ===${NC}"
python -c "import biopython" 2>/dev/null && echo -e "${GREEN}✓${NC} Python: biopython" || echo -e "${RED}✗${NC} Python: biopython"
python -c "import networkx" 2>/dev/null && echo -e "${GREEN}✓${NC} Python: networkx" || echo -e "${RED}✗${NC} Python: networkx"
python -c "import scipy" 2>/dev/null && echo -e "${GREEN}✓${NC} Python: scipy" || echo -e "${RED}✗${NC} Python: scipy"
python -c "import sklearn" 2>/dev/null && echo -e "${GREEN}✓${NC} Python: scikit-learn" || echo -e "${RED}✗${NC} Python: scikit-learn"
python -c "import numpy" 2>/dev/null && echo -e "${GREEN}✓${NC} Python: numpy" || echo -e "${RED}✗${NC} Python: numpy"
python -c "import pandas" 2>/dev/null && echo -e "${GREEN}✓${NC} Python: pandas" || echo -e "${RED}✗${NC} Python: pandas"
python -c "import matplotlib" 2>/dev/null && echo -e "${GREEN}✓${NC} Python: matplotlib" || echo -e "${RED}✗${NC} Python: matplotlib"
python -c "import seaborn" 2>/dev/null && echo -e "${GREEN}✓${NC} Python: seaborn" || echo -e "${RED}✗${NC} Python: seaborn"
echo ""

################################################################################
# Summary
################################################################################
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Total tests: ${BLUE}$TOTAL_TESTS${NC}"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed! Environment is ready.${NC}"
    exit 0
else
    PASS_RATE=$((100 * PASSED_TESTS / TOTAL_TESTS))
    echo -e "${YELLOW}⚠ Some tests failed (${PASS_RATE}% pass rate)${NC}"
    echo ""
    echo "To install missing packages:"
    echo "  conda install -c bioconda <package_name>"
    echo ""
    echo "Or update entire environment:"
    echo "  conda env update -f pimgavir_viralgenomes.yaml --prune"
    exit 1
fi
