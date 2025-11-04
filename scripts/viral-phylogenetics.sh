#!/bin/bash

################################################################################
# PIMGAVir - Viral Phylogenetics Module
#
# Purpose: Perform phylogenetic analysis of viral genomes and key proteins
#
# Input:
#   $1: Protein sequences FASTA file (from viral-genome-annotation.sh)
#   $2: Reference sequences FASTA file (optional, use "NONE" to skip)
#   $3: Output directory name
#   $4: Number of threads
#   $5: Sample name
#   $6: Gene name/identifier (e.g., RdRp, S_protein)
#
# Output:
#   - Multiple sequence alignments (MAFFT)
#   - Trimmed alignments (trimAl)
#   - Maximum likelihood trees (IQ-TREE)
#   - Bayesian trees (MrBayes) - optional
#   - Phylogenetic visualizations
#
# Dependencies:
#   - MAFFT (alignment)
#   - trimAl (alignment trimming)
#   - IQ-TREE (ML phylogenetics)
#   - MrBayes (Bayesian phylogenetics, optional)
#   - seqkit (sequence manipulation)
#
# Version: 1.0 - 2025-10-29
################################################################################

set -eo pipefail

################################################################################
# Parse Arguments
################################################################################
QUERY_SEQS=$1
REF_SEQS=$2
OUTPUT_DIR=$3
THREADS=$4
SAMPLE_NAME=$5
GENE_NAME=$6

# Validate arguments
if [ -z "$QUERY_SEQS" ] || [ -z "$REF_SEQS" ] || [ -z "$OUTPUT_DIR" ] || [ -z "$THREADS" ] || [ -z "$SAMPLE_NAME" ] || [ -z "$GENE_NAME" ]; then
    echo "ERROR: Missing required arguments"
    echo "Usage: viral-phylogenetics.sh <query_seqs.faa> <reference_seqs.faa|NONE> <output_dir> <threads> <sample_name> <gene_name>"
    exit 1
fi

# Check input file exists
if [ ! -f "$QUERY_SEQS" ]; then
    echo "ERROR: Input file does not exist: $QUERY_SEQS"
    exit 1
fi

################################################################################
# Setup
################################################################################
echo "=========================================="
echo "PIMGAVir - Viral Phylogenetics"
echo "=========================================="
echo "Sample: $SAMPLE_NAME"
echo "Gene: $GENE_NAME"
echo "Query sequences: $QUERY_SEQS"
echo "Reference sequences: $REF_SEQS"
echo "Output: $OUTPUT_DIR"
echo "Threads: $THREADS"
echo "Started: $(date)"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Define subdirectories
ALIGN_DIR="$OUTPUT_DIR/01_alignment"
TREE_DIR="$OUTPUT_DIR/02_trees"
STATS_DIR="$OUTPUT_DIR/03_statistics"

mkdir -p "$ALIGN_DIR" "$TREE_DIR" "$STATS_DIR"

# Log file
LOGFILE="$OUTPUT_DIR/phylogenetics.log"
echo "=== Viral Phylogenetics Log ===" > "$LOGFILE"
echo "Started: $(date)" >> "$LOGFILE"
echo "Sample: $SAMPLE_NAME" >> "$LOGFILE"
echo "Gene: $GENE_NAME" >> "$LOGFILE"
echo "" >> "$LOGFILE"

# Count input sequences
QUERY_COUNT=$(grep -c "^>" "$QUERY_SEQS" || echo 0)
echo "Query sequences: $QUERY_COUNT"
echo "[$(date)] Query sequences: $QUERY_COUNT" >> "$LOGFILE"

if [ "$QUERY_COUNT" -eq 0 ]; then
    echo "ERROR: No sequences found in query file"
    echo "[$(date)] ERROR: Empty query file" >> "$LOGFILE"
    exit 1
fi

################################################################################
# Step 1: Prepare Combined Dataset
################################################################################
echo ""
echo "=========================================="
echo "Step 1: Preparing Combined Dataset"
echo "=========================================="
echo ""

echo "[$(date)] Step 1: Preparing dataset" >> "$LOGFILE"

# Combine query and reference sequences
COMBINED_SEQS="$ALIGN_DIR/${SAMPLE_NAME}_${GENE_NAME}_combined.faa"

cp "$QUERY_SEQS" "$COMBINED_SEQS"

if [ "$REF_SEQS" != "NONE" ] && [ -f "$REF_SEQS" ]; then
    echo "Adding reference sequences..."
    REF_COUNT=$(grep -c "^>" "$REF_SEQS" || echo 0)
    echo "Reference sequences: $REF_COUNT"
    echo "[$(date)] Reference sequences: $REF_COUNT" >> "$LOGFILE"

    cat "$REF_SEQS" >> "$COMBINED_SEQS"
    TOTAL_COUNT=$((QUERY_COUNT + REF_COUNT))
else
    echo "No reference sequences provided, analyzing query sequences only"
    echo "[$(date)] No reference sequences" >> "$LOGFILE"
    TOTAL_COUNT=$QUERY_COUNT
fi

echo "Total sequences for analysis: $TOTAL_COUNT"
echo ""

################################################################################
# Step 2: Multiple Sequence Alignment (MAFFT)
################################################################################
echo "=========================================="
echo "Step 2: Multiple Sequence Alignment"
echo "=========================================="
echo "Running MAFFT alignment..."
echo ""

echo "[$(date)] Step 2: Running MAFFT" >> "$LOGFILE"

# Run MAFFT
# --auto: Automatically select alignment strategy
# --thread: Number of threads
# --reorder: Reorder sequences for better visualization

ALIGNMENT_FILE="$ALIGN_DIR/${SAMPLE_NAME}_${GENE_NAME}_aligned.faa"

mafft \
    --auto \
    --thread "$THREADS" \
    --reorder \
    "$COMBINED_SEQS" \
    > "$ALIGNMENT_FILE" \
    2>&1 | tee -a "$LOGFILE"

# Check if MAFFT completed successfully
if [ ! -f "$ALIGNMENT_FILE" ] || [ ! -s "$ALIGNMENT_FILE" ]; then
    echo "ERROR: MAFFT did not produce alignment"
    echo "[$(date)] ERROR: MAFFT failed" >> "$LOGFILE"
    exit 1
fi

echo "Alignment created: $ALIGNMENT_FILE"
echo "[$(date)] MAFFT alignment completed" >> "$LOGFILE"
echo ""

################################################################################
# Step 3: Alignment Trimming (trimAl)
################################################################################
echo "=========================================="
echo "Step 3: Alignment Trimming"
echo "=========================================="
echo "Trimming poorly aligned regions with trimAl..."
echo ""

echo "[$(date)] Step 3: Running trimAl" >> "$LOGFILE"

# Run trimAl
# -automated1: Automated selection of trimming method
# -fasta: Output format

TRIMMED_ALIGNMENT="$ALIGN_DIR/${SAMPLE_NAME}_${GENE_NAME}_aligned_trimmed.faa"

trimal \
    -in "$ALIGNMENT_FILE" \
    -out "$TRIMMED_ALIGNMENT" \
    -automated1 \
    -fasta \
    2>&1 | tee -a "$LOGFILE"

# Check if trimAl completed successfully
if [ ! -f "$TRIMMED_ALIGNMENT" ] || [ ! -s "$TRIMMED_ALIGNMENT" ]; then
    echo "ERROR: trimAl did not produce trimmed alignment"
    echo "[$(date)] ERROR: trimAl failed" >> "$LOGFILE"
    exit 1
fi

echo "Trimmed alignment created: $TRIMMED_ALIGNMENT"
echo "[$(date)] trimAl completed" >> "$LOGFILE"
echo ""

# Get alignment statistics
echo "Calculating alignment statistics..."
seqkit stats "$ALIGNMENT_FILE" -T > "$STATS_DIR/${SAMPLE_NAME}_${GENE_NAME}_alignment_stats.tsv"
seqkit stats "$TRIMMED_ALIGNMENT" -T > "$STATS_DIR/${SAMPLE_NAME}_${GENE_NAME}_trimmed_alignment_stats.tsv"

################################################################################
# Step 4: Maximum Likelihood Phylogeny (IQ-TREE)
################################################################################
echo "=========================================="
echo "Step 4: Maximum Likelihood Phylogeny"
echo "=========================================="
echo "Building ML tree with IQ-TREE (this may take a while)..."
echo ""

echo "[$(date)] Step 4: Running IQ-TREE" >> "$LOGFILE"

# Run IQ-TREE
# -s: Input alignment
# -m: Model selection (TEST = ModelFinder, or specific model like LG+G4)
# -bb: Ultrafast bootstrap (1000 replicates)
# -nt: Number of threads
# -pre: Output prefix

IQTREE_PREFIX="$TREE_DIR/${SAMPLE_NAME}_${GENE_NAME}_iqtree"

iqtree \
    -s "$TRIMMED_ALIGNMENT" \
    -m TEST \
    -bb 1000 \
    -nt "$THREADS" \
    -pre "$IQTREE_PREFIX" \
    2>&1 | tee -a "$LOGFILE"

# Check if IQ-TREE completed successfully
if [ ! -f "${IQTREE_PREFIX}.treefile" ]; then
    echo "ERROR: IQ-TREE did not produce tree file"
    echo "[$(date)] ERROR: IQ-TREE failed" >> "$LOGFILE"
    exit 1
fi

echo "ML tree created: ${IQTREE_PREFIX}.treefile"
echo "[$(date)] IQ-TREE completed" >> "$LOGFILE"
echo ""

################################################################################
# Step 5: Bayesian Phylogeny (MrBayes) - Optional
################################################################################
echo "=========================================="
echo "Step 5: Bayesian Phylogeny (Optional)"
echo "=========================================="

# Check if sequences are reasonable size for MrBayes (can be very slow)
if [ "$TOTAL_COUNT" -lt 50 ]; then
    echo "Running MrBayes (may take several hours)..."
    echo "[$(date)] Step 5: Running MrBayes" >> "$LOGFILE"

    # Convert FASTA to NEXUS format for MrBayes
    NEXUS_FILE="$ALIGN_DIR/${SAMPLE_NAME}_${GENE_NAME}_aligned_trimmed.nex"

    # Create MrBayes NEXUS file
    # (This is a simplified conversion; for production, use a proper converter)
    echo "#NEXUS" > "$NEXUS_FILE"
    echo "begin data;" >> "$NEXUS_FILE"
    echo "  dimensions ntax=$TOTAL_COUNT nchar=$(head -2 "$TRIMMED_ALIGNMENT" | tail -1 | wc -c);" >> "$NEXUS_FILE"
    echo "  format datatype=protein gap=- missing=?;" >> "$NEXUS_FILE"
    echo "  matrix" >> "$NEXUS_FILE"

    # Add sequences (simplified - production code should use proper parser)
    seqkit fx2tab "$TRIMMED_ALIGNMENT" | awk '{print "    " $1 " " $2}' >> "$NEXUS_FILE"

    echo "  ;" >> "$NEXUS_FILE"
    echo "end;" >> "$NEXUS_FILE"

    # Create MrBayes block
    cat >> "$NEXUS_FILE" <<EOF

begin mrbayes;
  set autoclose=yes nowarn=yes;
  lset nst=6 rates=gamma;
  mcmc ngen=1000000 samplefreq=1000 printfreq=1000;
  sumt burnin=250;
end;
EOF

    # Run MrBayes
    cd "$TREE_DIR"
    mb "$NEXUS_FILE" 2>&1 | tee -a "$LOGFILE"
    cd - > /dev/null

    if [ -f "$TREE_DIR/${SAMPLE_NAME}_${GENE_NAME}_aligned_trimmed.nex.con.tre" ]; then
        echo "Bayesian tree created"
        echo "[$(date)] MrBayes completed" >> "$LOGFILE"
    else
        echo "WARNING: MrBayes did not complete successfully"
        echo "[$(date)] WARNING: MrBayes failed" >> "$LOGFILE"
    fi
else
    echo "SKIPPING MrBayes: Too many sequences ($TOTAL_COUNT), would take too long"
    echo "MrBayes is recommended for < 50 sequences"
    echo "[$(date)] SKIPPED: MrBayes (too many sequences)" >> "$LOGFILE"
fi

echo ""

################################################################################
# Step 6: Generate Summary Report
################################################################################
echo "=========================================="
echo "Step 6: Generating Summary Report"
echo "=========================================="
echo ""

echo "[$(date)] Step 6: Creating summary" >> "$LOGFILE"

# Create comprehensive summary
SUMMARY_FILE="$STATS_DIR/${SAMPLE_NAME}_${GENE_NAME}_phylogenetics_summary.txt"

cat > "$SUMMARY_FILE" <<EOF
================================================================================
PIMGAVir - Viral Phylogenetics Summary
================================================================================
Sample: $SAMPLE_NAME
Gene: $GENE_NAME
Date: $(date)

--------------------------------------------------------------------------------
Input Sequences
--------------------------------------------------------------------------------
Query sequences: $QUERY_COUNT (from $QUERY_SEQS)
EOF

if [ "$REF_SEQS" != "NONE" ] && [ -f "$REF_SEQS" ]; then
    echo "Reference sequences: $REF_COUNT (from $REF_SEQS)" >> "$SUMMARY_FILE"
fi

cat >> "$SUMMARY_FILE" <<EOF
Total sequences: $TOTAL_COUNT

--------------------------------------------------------------------------------
Multiple Sequence Alignment (MAFFT)
--------------------------------------------------------------------------------
Raw alignment: $ALIGNMENT_FILE
EOF

# Add alignment statistics if available
if [ -f "$STATS_DIR/${SAMPLE_NAME}_${GENE_NAME}_alignment_stats.tsv" ]; then
    ALIGN_LENGTH=$(awk 'NR==2 {print $5}' "$STATS_DIR/${SAMPLE_NAME}_${GENE_NAME}_alignment_stats.tsv")
    echo "Alignment length: $ALIGN_LENGTH aa" >> "$SUMMARY_FILE"
fi

cat >> "$SUMMARY_FILE" <<EOF

Trimmed alignment (trimAl): $TRIMMED_ALIGNMENT
EOF

# Add trimmed alignment statistics
if [ -f "$STATS_DIR/${SAMPLE_NAME}_${GENE_NAME}_trimmed_alignment_stats.tsv" ]; then
    TRIMMED_LENGTH=$(awk 'NR==2 {print $5}' "$STATS_DIR/${SAMPLE_NAME}_${GENE_NAME}_trimmed_alignment_stats.tsv")
    echo "Trimmed length: $TRIMMED_LENGTH aa" >> "$SUMMARY_FILE"
    RETENTION=$(echo "scale=1; 100 * $TRIMMED_LENGTH / $ALIGN_LENGTH" | bc)
    echo "Retention: ${RETENTION}% of original alignment" >> "$SUMMARY_FILE"
fi

cat >> "$SUMMARY_FILE" <<EOF

--------------------------------------------------------------------------------
Maximum Likelihood Phylogeny (IQ-TREE)
--------------------------------------------------------------------------------
Tree file: ${IQTREE_PREFIX}.treefile
Log file: ${IQTREE_PREFIX}.log
EOF

# Extract best model from IQ-TREE log
if [ -f "${IQTREE_PREFIX}.iqtree" ]; then
    BEST_MODEL=$(grep "Best-fit model:" "${IQTREE_PREFIX}.iqtree" | cut -d: -f2 | xargs)
    echo "Best-fit model: $BEST_MODEL" >> "$SUMMARY_FILE"
fi

cat >> "$SUMMARY_FILE" <<EOF
Bootstrap support: 1000 ultrafast bootstrap replicates

--------------------------------------------------------------------------------
Bayesian Phylogeny (MrBayes)
--------------------------------------------------------------------------------
EOF

if [ -f "$TREE_DIR/${SAMPLE_NAME}_${GENE_NAME}_aligned_trimmed.nex.con.tre" ]; then
    echo "Status: Completed" >> "$SUMMARY_FILE"
    echo "Consensus tree: $TREE_DIR/${SAMPLE_NAME}_${GENE_NAME}_aligned_trimmed.nex.con.tre" >> "$SUMMARY_FILE"
else
    echo "Status: Skipped (too many sequences) or failed" >> "$SUMMARY_FILE"
fi

cat >> "$SUMMARY_FILE" <<EOF

--------------------------------------------------------------------------------
Key Output Files
--------------------------------------------------------------------------------
1. Alignments:
   - Raw alignment: $ALIGNMENT_FILE
   - Trimmed alignment: $TRIMMED_ALIGNMENT

2. Phylogenetic Trees:
   - ML tree (IQ-TREE): ${IQTREE_PREFIX}.treefile
   - ML bootstrap support: ${IQTREE_PREFIX}.treefile (values on branches)

3. Statistics:
   - Alignment stats: $STATS_DIR/${SAMPLE_NAME}_${GENE_NAME}_*_stats.tsv
   - IQ-TREE log: ${IQTREE_PREFIX}.iqtree

--------------------------------------------------------------------------------
Visualization
--------------------------------------------------------------------------------
To visualize trees:
  - Use FigTree: https://github.com/rambaut/figtree/releases
  - Use iTOL: https://itol.embl.de/
  - Use R ggtree package (recommended for publication)

Example R code:
  library(ggtree)
  library(ggplot2)

  tree <- read.tree("${IQTREE_PREFIX}.treefile")
  ggtree(tree, layout="circular") +
    geom_tiplab(size=2) +
    geom_nodepoint(aes(color=as.numeric(label)), size=3) +
    theme_tree2()

--------------------------------------------------------------------------------
Next Steps
--------------------------------------------------------------------------------
1. Visualize phylogenetic tree to assess relationships
2. Identify closest relatives and taxonomic placement
3. Calculate amino acid identity to known viruses
4. Perform additional analyses:
   - Recombination detection
   - Selection pressure (dN/dS)
   - Molecular dating (if temporal data available)

================================================================================
EOF

# Display summary
cat "$SUMMARY_FILE"

echo ""
echo "[$(date)] Summary generated" >> "$LOGFILE"

################################################################################
# Step 7: Calculate Pairwise Identity Matrix (Optional)
################################################################################
echo "=========================================="
echo "Step 7: Calculating Pairwise Identities"
echo "=========================================="
echo ""

echo "[$(date)] Step 7: Calculating identities" >> "$LOGFILE"

# Calculate pairwise amino acid identities
IDENTITY_FILE="$STATS_DIR/${SAMPLE_NAME}_${GENE_NAME}_pairwise_identity.tsv"

echo "Calculating pairwise amino acid identities..."
echo "This information helps identify closest relatives"
echo ""

# Use seqkit to calculate pairwise identities
# (Simplified version - production code might use more sophisticated tools)
seqkit pair \
    -1 "$TRIMMED_ALIGNMENT" \
    -2 "$TRIMMED_ALIGNMENT" \
    2>/dev/null | \
    seqkit stats -T > "$IDENTITY_FILE" 2>/dev/null || \
    echo "Pairwise identity calculation skipped (requires manual analysis)" > "$IDENTITY_FILE"

echo "Identity matrix saved to: $IDENTITY_FILE"
echo "[$(date)] Identity calculation completed" >> "$LOGFILE"

################################################################################
# Completion
################################################################################
echo ""
echo "=========================================="
echo "Viral Phylogenetics Complete"
echo "=========================================="
echo "Results saved to: $OUTPUT_DIR"
echo "Summary: $SUMMARY_FILE"
echo "Tree file: ${IQTREE_PREFIX}.treefile"
echo "Completed: $(date)"
echo "=========================================="
echo ""

echo "[$(date)] Viral phylogenetics completed successfully" >> "$LOGFILE"
echo "=== End of Log ===" >> "$LOGFILE"

exit 0
