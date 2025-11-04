#!/bin/bash

################################################################################
# PIMGAVir - Viral Genome Recovery Module
#
# Purpose: Identify, extract, and characterize complete viral genomes from
#          metagenomic assemblies
#
# Input:
#   $1: Assembly FASTA file (contigs from MEGAHIT/SPAdes)
#   $2: Output directory name
#   $3: Number of threads
#   $4: Sample name
#   $5: Assembler name (e.g., MEGAHIT, SPADES)
#
# Output:
#   - Viral contigs identified by VirSorter2
#   - Quality-checked viral genomes (CheckV)
#   - Binned viral genomes (vRhyme)
#   - Summary statistics and reports
#
# Dependencies:
#   - VirSorter2 (viral identification)
#   - CheckV (quality assessment)
#   - vRhyme (viral binning)
#   - seqkit (sequence manipulation)
#
# Version: 1.0 - 2025-10-29
################################################################################

set -eo pipefail

################################################################################
# Parse Arguments
################################################################################
CONTIGS=$1
OUTPUT_DIR=$2
THREADS=$3
SAMPLE_NAME=$4
ASSEMBLER=$5

# Validate arguments
if [ -z "$CONTIGS" ] || [ -z "$OUTPUT_DIR" ] || [ -z "$THREADS" ] || [ -z "$SAMPLE_NAME" ] || [ -z "$ASSEMBLER" ]; then
    echo "ERROR: Missing required arguments"
    echo "Usage: viral-genome-recovery.sh <contigs.fasta> <output_dir> <threads> <sample_name> <assembler>"
    exit 1
fi

# Check input file exists
if [ ! -f "$CONTIGS" ]; then
    echo "ERROR: Input file does not exist: $CONTIGS"
    exit 1
fi

################################################################################
# Setup
################################################################################
echo "=========================================="
echo "PIMGAVir - Viral Genome Recovery"
echo "=========================================="
echo "Sample: $SAMPLE_NAME"
echo "Assembler: $ASSEMBLER"
echo "Input: $CONTIGS"
echo "Output: $OUTPUT_DIR"
echo "Threads: $THREADS"
echo "Started: $(date)"
echo ""

# Determine database directory
# Check for PIMGAVIR_DBS_DIR environment variable first (v2.2 optimization)
if [ -n "${PIMGAVIR_DBS_DIR:-}" ]; then
    DB_BASE_DIR="${PIMGAVIR_DBS_DIR}"
else
    # Fall back to relative path
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    DB_BASE_DIR="$(cd "${SCRIPT_DIR}/../DBs" && pwd)"
fi

# VirSorter2 database path
VIRSORTER_DB="${DB_BASE_DIR}/ViralGenomes/virsorter2-db"
if [ ! -d "$VIRSORTER_DB" ]; then
    echo "ERROR: VirSorter2 database not found at: $VIRSORTER_DB"
    echo "Please run: bash scripts/setup_viral_databases.sh"
    exit 1
fi
echo "VirSorter2 database: $VIRSORTER_DB"

# CheckV database path
CHECKV_DB="${DB_BASE_DIR}/ViralGenomes/checkv-db-v1.5"
if [ ! -d "$CHECKV_DB" ]; then
    echo "ERROR: CheckV database not found at: $CHECKV_DB"
    echo "Please run: bash scripts/setup_viral_databases.sh"
    exit 1
fi
echo "CheckV database: $CHECKV_DB"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Define subdirectories
VIRSORTER_DIR="$OUTPUT_DIR/01_virsorter"
CHECKV_DIR="$OUTPUT_DIR/02_checkv"
VRHYME_DIR="$OUTPUT_DIR/03_vrhyme"
FINAL_DIR="$OUTPUT_DIR/04_final_genomes"
STATS_DIR="$OUTPUT_DIR/05_statistics"
HQ_VIRUSES_DIR="$OUTPUT_DIR/high_quality_viruses"  # For compatibility with viral-genome-complete-7phases.sh

mkdir -p "$VIRSORTER_DIR" "$CHECKV_DIR" "$VRHYME_DIR" "$FINAL_DIR" "$STATS_DIR" "$HQ_VIRUSES_DIR"

# Log file
LOGFILE="$OUTPUT_DIR/viral_recovery.log"
echo "=== Viral Genome Recovery Log ===" > "$LOGFILE"
echo "Started: $(date)" >> "$LOGFILE"
echo "Sample: $SAMPLE_NAME" >> "$LOGFILE"
echo "Assembler: $ASSEMBLER" >> "$LOGFILE"
echo "" >> "$LOGFILE"

################################################################################
# Step 1: Viral Identification with VirSorter2
################################################################################
echo "=========================================="
echo "Step 1: Viral Identification (VirSorter2)"
echo "=========================================="
echo "Identifying viral sequences in assembled contigs..."
echo ""

echo "[$(date)] Step 1: Running VirSorter2" >> "$LOGFILE"

# Run VirSorter2 to identify viral contigs
# --db-dir: Database directory
# --min-length 1500: Focus on longer contigs for complete genomes
# --min-score 0.5: Default confidence threshold
virsorter run \
    -w "$VIRSORTER_DIR" \
    -i "$CONTIGS" \
    --db-dir "$VIRSORTER_DB" \
    --min-length 1500 \
    --min-score 0.5 \
    -j "$THREADS" \
    all \
    2>&1 | tee -a "$LOGFILE"

# Check if VirSorter2 completed successfully
if [ ! -f "$VIRSORTER_DIR/final-viral-combined.fa" ]; then
    echo "ERROR: VirSorter2 did not produce output file"
    echo "[$(date)] ERROR: VirSorter2 failed" >> "$LOGFILE"
    exit 1
fi

# Count viral sequences found
VIRAL_COUNT=$(grep -c "^>" "$VIRSORTER_DIR/final-viral-combined.fa" || echo 0)
echo "Found $VIRAL_COUNT potential viral sequences"
echo "[$(date)] VirSorter2 identified $VIRAL_COUNT viral sequences" >> "$LOGFILE"
echo ""

if [ "$VIRAL_COUNT" -eq 0 ]; then
    echo "WARNING: No viral sequences identified by VirSorter2"
    echo "Pipeline will continue but downstream steps may produce no results"
    echo "[$(date)] WARNING: No viral sequences found" >> "$LOGFILE"
fi

################################################################################
# Step 2: Quality Assessment with CheckV
################################################################################
echo "=========================================="
echo "Step 2: Quality Assessment (CheckV)"
echo "=========================================="
echo "Assessing completeness and quality of viral genomes..."
echo ""

echo "[$(date)] Step 2: Running CheckV" >> "$LOGFILE"

# Run CheckV to assess viral genome quality
checkv end_to_end \
    "$VIRSORTER_DIR/final-viral-combined.fa" \
    "$CHECKV_DIR" \
    -t "$THREADS" \
    -d "$CHECKV_DB" \
    2>&1 | tee -a "$LOGFILE"

# Check if CheckV completed successfully
if [ ! -f "$CHECKV_DIR/quality_summary.tsv" ]; then
    echo "ERROR: CheckV did not produce quality summary"
    echo "[$(date)] ERROR: CheckV failed" >> "$LOGFILE"
    exit 1
fi

# Extract high-quality and complete viral genomes
# Criteria: completeness >= 90% OR quality = "Complete"
echo "Extracting high-quality viral genomes (≥90% complete)..."
awk -F'\t' 'NR==1 || $7 >= 90 || $8 == "Complete"' "$CHECKV_DIR/quality_summary.tsv" > "$CHECKV_DIR/high_quality_genomes.tsv"

# Count high-quality genomes
HQ_COUNT=$(tail -n +2 "$CHECKV_DIR/high_quality_genomes.tsv" | wc -l)
echo "Found $HQ_COUNT high-quality viral genomes (≥90% complete)"
echo "[$(date)] CheckV identified $HQ_COUNT high-quality genomes" >> "$LOGFILE"
echo ""

# Extract sequences of high-quality genomes
if [ "$HQ_COUNT" -gt 0 ]; then
    # Get contig IDs of high-quality genomes
    tail -n +2 "$CHECKV_DIR/high_quality_genomes.tsv" | cut -f1 > "$CHECKV_DIR/hq_genome_ids.txt"

    # Extract sequences using seqkit
    seqkit grep \
        -f "$CHECKV_DIR/hq_genome_ids.txt" \
        "$CHECKV_DIR/proviruses.fna" \
        "$CHECKV_DIR/viruses.fna" \
        > "$CHECKV_DIR/high_quality_genomes.fna" 2>/dev/null || true

    echo "[$(date)] Extracted $HQ_COUNT high-quality genome sequences" >> "$LOGFILE"
fi

################################################################################
# Step 3: Viral Genome Binning with vRhyme
################################################################################
echo "=========================================="
echo "Step 3: Viral Genome Binning (vRhyme)"
echo "=========================================="
echo "Binning viral sequences into genome groups..."
echo ""

echo "[$(date)] Step 3: Running vRhyme" >> "$LOGFILE"

# vRhyme bins viral sequences into cohesive genome groups
# This helps identify which contigs belong to the same viral genome
vRhyme \
    -i "$VIRSORTER_DIR/final-viral-combined.fa" \
    -o "$VRHYME_DIR" \
    -t "$THREADS" \
    2>&1 | tee -a "$LOGFILE"

# Check if vRhyme completed successfully
if [ -d "$VRHYME_DIR/vRhyme_best_bins" ]; then
    BIN_COUNT=$(ls -1 "$VRHYME_DIR/vRhyme_best_bins/"*.fasta 2>/dev/null | wc -l)
    echo "vRhyme created $BIN_COUNT viral genome bins"
    echo "[$(date)] vRhyme created $BIN_COUNT bins" >> "$LOGFILE"
else
    echo "WARNING: vRhyme did not produce bins directory"
    echo "[$(date)] WARNING: vRhyme produced no bins" >> "$LOGFILE"
    BIN_COUNT=0
fi
echo ""

################################################################################
# Step 4: Compile Final Viral Genome Set
################################################################################
echo "=========================================="
echo "Step 4: Compiling Final Genome Set"
echo "=========================================="
echo "Creating final collection of viral genomes..."
echo ""

echo "[$(date)] Step 4: Compiling final genomes" >> "$LOGFILE"

# Copy high-quality genomes to final directory AND to the expected location for viral-genome-complete-7phases.sh
if [ -f "$CHECKV_DIR/high_quality_genomes.fna" ]; then
    # Copy to final directory with assembler name
    cp "$CHECKV_DIR/high_quality_genomes.fna" "$FINAL_DIR/${SAMPLE_NAME}_${ASSEMBLER}_viral_genomes_hq.fna"
    echo "Copied high-quality genomes to: ${SAMPLE_NAME}_${ASSEMBLER}_viral_genomes_hq.fna"

    # Also copy to expected location for viral-genome-complete-7phases.sh (without assembler suffix for compatibility)
    cp "$CHECKV_DIR/high_quality_genomes.fna" "$HQ_VIRUSES_DIR/${SAMPLE_NAME}_hq_viruses.fasta"
    echo "Copied high-quality genomes to: high_quality_viruses/${SAMPLE_NAME}_hq_viruses.fasta"
fi

# Copy binned genomes to final directory
if [ "$BIN_COUNT" -gt 0 ]; then
    cp "$VRHYME_DIR/vRhyme_best_bins/"*.fasta "$FINAL_DIR/" 2>/dev/null || true
    echo "Copied $BIN_COUNT binned genomes to final directory"
fi

# Copy all CheckV results for reference
cp "$CHECKV_DIR/quality_summary.tsv" "$FINAL_DIR/${SAMPLE_NAME}_${ASSEMBLER}_checkv_quality.tsv"
cp "$CHECKV_DIR/completeness.tsv" "$FINAL_DIR/${SAMPLE_NAME}_${ASSEMBLER}_checkv_completeness.tsv"

echo "[$(date)] Final genomes compiled" >> "$LOGFILE"
echo ""

################################################################################
# Step 5: Generate Statistics and Summary
################################################################################
echo "=========================================="
echo "Step 5: Generating Statistics"
echo "=========================================="
echo ""

echo "[$(date)] Step 5: Generating statistics" >> "$LOGFILE"

# Create summary statistics file
SUMMARY_FILE="$STATS_DIR/${SAMPLE_NAME}_${ASSEMBLER}_viral_recovery_summary.txt"

cat > "$SUMMARY_FILE" <<EOF
================================================================================
PIMGAVir - Viral Genome Recovery Summary
================================================================================
Sample: $SAMPLE_NAME
Assembler: $ASSEMBLER
Date: $(date)

--------------------------------------------------------------------------------
Input Assembly Statistics
--------------------------------------------------------------------------------
Input file: $CONTIGS
Total contigs in assembly: $(grep -c "^>" "$CONTIGS" || echo 0)

--------------------------------------------------------------------------------
VirSorter2 Results
--------------------------------------------------------------------------------
Viral sequences identified: $VIRAL_COUNT
Output: $VIRSORTER_DIR/final-viral-combined.fa

--------------------------------------------------------------------------------
CheckV Quality Assessment
--------------------------------------------------------------------------------
Total viral sequences assessed: $VIRAL_COUNT
High-quality genomes (≥90% complete): $HQ_COUNT
Quality summary: $CHECKV_DIR/quality_summary.tsv

Quality Distribution:
EOF

# Add quality distribution from CheckV
if [ -f "$CHECKV_DIR/quality_summary.tsv" ]; then
    echo "  Complete genomes: $(awk -F'\t' '$8 == "Complete"' "$CHECKV_DIR/quality_summary.tsv" | wc -l)" >> "$SUMMARY_FILE"
    echo "  High-quality (≥90%): $(awk -F'\t' '$7 >= 90' "$CHECKV_DIR/quality_summary.tsv" | wc -l)" >> "$SUMMARY_FILE"
    echo "  Medium-quality (50-90%): $(awk -F'\t' '$7 >= 50 && $7 < 90' "$CHECKV_DIR/quality_summary.tsv" | wc -l)" >> "$SUMMARY_FILE"
    echo "  Low-quality (<50%): $(awk -F'\t' '$7 < 50' "$CHECKV_DIR/quality_summary.tsv" | wc -l)" >> "$SUMMARY_FILE"
fi

cat >> "$SUMMARY_FILE" <<EOF

--------------------------------------------------------------------------------
vRhyme Binning Results
--------------------------------------------------------------------------------
Number of viral genome bins: $BIN_COUNT
Bins directory: $VRHYME_DIR/vRhyme_best_bins/

--------------------------------------------------------------------------------
Final Output
--------------------------------------------------------------------------------
High-quality genomes: $FINAL_DIR/${SAMPLE_NAME}_${ASSEMBLER}_viral_genomes_hq.fna
High-quality genomes (pipeline format): $HQ_VIRUSES_DIR/${SAMPLE_NAME}_hq_viruses.fasta
Binned genomes: $FINAL_DIR/ (individual bin files)
Quality reports: $FINAL_DIR/${SAMPLE_NAME}_${ASSEMBLER}_checkv_*.tsv

================================================================================
EOF

# Display summary
cat "$SUMMARY_FILE"

# Generate sequence length statistics for high-quality genomes
if [ -f "$HQ_VIRUSES_DIR/${SAMPLE_NAME}_hq_viruses.fasta" ]; then
    echo "Generating sequence statistics for high-quality genomes..."
    seqkit stats \
        "$HQ_VIRUSES_DIR/${SAMPLE_NAME}_hq_viruses.fasta" \
        -T -o "$STATS_DIR/${SAMPLE_NAME}_${ASSEMBLER}_hq_genome_stats.tsv" \
        2>&1 | tee -a "$LOGFILE"
fi

echo ""
echo "[$(date)] Statistics generated" >> "$LOGFILE"

################################################################################
# Completion
################################################################################
echo "=========================================="
echo "Viral Genome Recovery Complete"
echo "=========================================="
echo "Results saved to: $OUTPUT_DIR"
echo "Summary: $SUMMARY_FILE"
echo "Completed: $(date)"
echo "=========================================="
echo ""

echo "[$(date)] Viral genome recovery completed successfully" >> "$LOGFILE"
echo "=== End of Log ===" >> "$LOGFILE"

exit 0
