#!/bin/bash

################################################################################
# PIMGAVir - Viral Genome Annotation Module
#
# Purpose: Functionally annotate viral genomes using DRAM-v and InterProScan
#
# Input:
#   $1: Viral genomes FASTA file (from viral-genome-recovery.sh)
#   $2: Output directory name
#   $3: Number of threads
#   $4: Sample name
#   $5: Assembler name (e.g., MEGAHIT, SPADES)
#
# Output:
#   - DRAM-v annotations (AMGs, auxiliary metabolic genes)
#   - Protein predictions with Prodigal-gv
#   - InterProScan domain annotations
#   - Functional summaries and reports
#
# Dependencies:
#   - DRAM (v1.4+)
#   - Prodigal-gv (viral gene prediction)
#   - InterProScan
#   - HMMER (included with DRAM)
#
# Version: 1.0 - 2025-10-29
################################################################################

set -eo pipefail

################################################################################
# Parse Arguments
################################################################################
VIRAL_GENOMES=$1
OUTPUT_DIR=$2
THREADS=$3
SAMPLE_NAME=$4
ASSEMBLER=$5

# Validate arguments
if [ -z "$VIRAL_GENOMES" ] || [ -z "$OUTPUT_DIR" ] || [ -z "$THREADS" ] || [ -z "$SAMPLE_NAME" ] || [ -z "$ASSEMBLER" ]; then
    echo "ERROR: Missing required arguments"
    echo "Usage: viral-genome-annotation.sh <viral_genomes.fna> <output_dir> <threads> <sample_name> <assembler>"
    exit 1
fi

# Check input file exists
if [ ! -f "$VIRAL_GENOMES" ]; then
    echo "ERROR: Input file does not exist: $VIRAL_GENOMES"
    exit 1
fi

################################################################################
# Setup
################################################################################
echo "=========================================="
echo "PIMGAVir - Viral Genome Annotation"
echo "=========================================="
echo "Sample: $SAMPLE_NAME"
echo "Assembler: $ASSEMBLER"
echo "Input: $VIRAL_GENOMES"
echo "Output: $OUTPUT_DIR"
echo "Threads: $THREADS"
echo "Started: $(date)"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Define subdirectories
PRODIGAL_DIR="$OUTPUT_DIR/01_prodigal"
DRAMV_DIR="$OUTPUT_DIR/02_dramv"
INTERPRO_DIR="$OUTPUT_DIR/03_interproscan"
SUMMARY_DIR="$OUTPUT_DIR/04_summary"

mkdir -p "$PRODIGAL_DIR" "$DRAMV_DIR" "$INTERPRO_DIR" "$SUMMARY_DIR"

# Log file
LOGFILE="$OUTPUT_DIR/viral_annotation.log"
echo "=== Viral Genome Annotation Log ===" > "$LOGFILE"
echo "Started: $(date)" >> "$LOGFILE"
echo "Sample: $SAMPLE_NAME" >> "$LOGFILE"
echo "Assembler: $ASSEMBLER" >> "$LOGFILE"
echo "" >> "$LOGFILE"

# Count input sequences
GENOME_COUNT=$(grep -c "^>" "$VIRAL_GENOMES" || echo 0)
echo "Processing $GENOME_COUNT viral genomes"
echo "[$(date)] Input: $GENOME_COUNT viral genomes" >> "$LOGFILE"
echo ""

if [ "$GENOME_COUNT" -eq 0 ]; then
    echo "ERROR: No sequences found in input file"
    echo "[$(date)] ERROR: Empty input file" >> "$LOGFILE"
    exit 1
fi

################################################################################
# Step 1: Gene Prediction with Prodigal-gv
################################################################################
echo "=========================================="
echo "Step 1: Gene Prediction (Prodigal-gv)"
echo "=========================================="
echo "Predicting genes in viral genomes..."
echo ""

echo "[$(date)] Step 1: Running Prodigal-gv" >> "$LOGFILE"

# Run Prodigal-gv (gene prediction optimized for viruses)
# -p meta: Metagenomic mode for diverse viral genomes
# -a: Output protein translations
# -d: Output nucleotide sequences
# -f gff: Output GFF format annotations
# -q: Quiet mode

prodigal-gv \
    -i "$VIRAL_GENOMES" \
    -o "$PRODIGAL_DIR/${SAMPLE_NAME}_${ASSEMBLER}_genes.gff" \
    -a "$PRODIGAL_DIR/${SAMPLE_NAME}_${ASSEMBLER}_proteins.faa" \
    -d "$PRODIGAL_DIR/${SAMPLE_NAME}_${ASSEMBLER}_genes.fna" \
    -p meta \
    -f gff \
    -q \
    2>&1 | tee -a "$LOGFILE"

# Check if Prodigal completed successfully
if [ ! -f "$PRODIGAL_DIR/${SAMPLE_NAME}_${ASSEMBLER}_proteins.faa" ]; then
    echo "ERROR: Prodigal-gv did not produce protein output"
    echo "[$(date)] ERROR: Prodigal-gv failed" >> "$LOGFILE"
    exit 1
fi

# Count predicted genes
GENE_COUNT=$(grep -c "^>" "$PRODIGAL_DIR/${SAMPLE_NAME}_${ASSEMBLER}_proteins.faa" || echo 0)
echo "Predicted $GENE_COUNT genes across all viral genomes"
echo "[$(date)] Prodigal-gv predicted $GENE_COUNT genes" >> "$LOGFILE"
echo ""

################################################################################
# Step 2: Functional Annotation with DRAM-v
################################################################################
echo "=========================================="
echo "Step 2: Functional Annotation (DRAM-v)"
echo "=========================================="
echo "Annotating viral genomes with DRAM-v..."
echo ""

echo "[$(date)] Step 2: Running DRAM-v" >> "$LOGFILE"

# DRAM-v annotates viral genomes with special focus on:
# - AMGs (Auxiliary Metabolic Genes) - genes stolen from hosts
# - Viral hallmark genes
# - Functional categories

# Run DRAM-v annotate
echo "Running DRAM-v annotation (this may take several hours)..."
DRAM-v.py annotate \
    -i "$VIRAL_GENOMES" \
    -o "$DRAMV_DIR" \
    --threads "$THREADS" \
    --min_contig_size 1000 \
    2>&1 | tee -a "$LOGFILE"

# Check if DRAM-v annotate completed
if [ ! -f "$DRAMV_DIR/annotations.tsv" ]; then
    echo "ERROR: DRAM-v annotate did not produce annotations"
    echo "[$(date)] ERROR: DRAM-v annotate failed" >> "$LOGFILE"
    exit 1
fi

echo "[$(date)] DRAM-v annotation completed" >> "$LOGFILE"

# Run DRAM-v distill to create summary
echo "Generating DRAM-v summary reports..."
DRAM-v.py distill \
    -i "$DRAMV_DIR/annotations.tsv" \
    -o "$DRAMV_DIR/distillate" \
    2>&1 | tee -a "$LOGFILE"

# Check if DRAM-v distill completed
if [ ! -d "$DRAMV_DIR/distillate" ]; then
    echo "WARNING: DRAM-v distill did not produce distillate directory"
    echo "[$(date)] WARNING: DRAM-v distill failed" >> "$LOGFILE"
else
    echo "[$(date)] DRAM-v distill completed" >> "$LOGFILE"
fi

echo ""

################################################################################
# Step 3: Domain Annotation with InterProScan (Optional but Recommended)
################################################################################
echo "=========================================="
echo "Step 3: Domain Annotation (InterProScan)"
echo "=========================================="
echo "Annotating protein domains with InterProScan..."
echo ""

echo "[$(date)] Step 3: Running InterProScan" >> "$LOGFILE"

# InterProScan provides detailed domain and motif annotations
# -appl: Applications to run (Pfam, TIGRFAM, SMART, etc.)
# -f TSV: Output format

# Check if protein file is not too large (InterProScan can be slow)
PROTEIN_SIZE=$(wc -l < "$PRODIGAL_DIR/${SAMPLE_NAME}_${ASSEMBLER}_proteins.faa")

if [ "$PROTEIN_SIZE" -lt 10000 ]; then
    echo "Running InterProScan (protein count: $GENE_COUNT)..."

    interproscan.sh \
        -i "$PRODIGAL_DIR/${SAMPLE_NAME}_${ASSEMBLER}_proteins.faa" \
        -d "$INTERPRO_DIR" \
        -f TSV \
        -cpu "$THREADS" \
        -appl Pfam,TIGRFAM,SMART,ProSiteProfiles \
        2>&1 | tee -a "$LOGFILE"

    if [ -f "$INTERPRO_DIR/${SAMPLE_NAME}_${ASSEMBLER}_proteins.faa.tsv" ]; then
        echo "[$(date)] InterProScan completed successfully" >> "$LOGFILE"
    else
        echo "WARNING: InterProScan did not complete successfully"
        echo "[$(date)] WARNING: InterProScan failed" >> "$LOGFILE"
    fi
else
    echo "SKIPPING InterProScan: Too many proteins ($GENE_COUNT), would take too long"
    echo "Consider running InterProScan manually on specific proteins of interest"
    echo "[$(date)] SKIPPED: InterProScan (too many proteins)" >> "$LOGFILE"
fi

echo ""

################################################################################
# Step 4: Generate Annotation Summary
################################################################################
echo "=========================================="
echo "Step 4: Generating Annotation Summary"
echo "=========================================="
echo ""

echo "[$(date)] Step 4: Creating summary" >> "$LOGFILE"

# Create comprehensive summary file
SUMMARY_FILE="$SUMMARY_DIR/${SAMPLE_NAME}_${ASSEMBLER}_annotation_summary.txt"

cat > "$SUMMARY_FILE" <<EOF
================================================================================
PIMGAVir - Viral Genome Annotation Summary
================================================================================
Sample: $SAMPLE_NAME
Assembler: $ASSEMBLER
Date: $(date)

--------------------------------------------------------------------------------
Input Statistics
--------------------------------------------------------------------------------
Input file: $VIRAL_GENOMES
Number of viral genomes: $GENOME_COUNT

--------------------------------------------------------------------------------
Gene Prediction (Prodigal-gv)
--------------------------------------------------------------------------------
Total genes predicted: $GENE_COUNT
Average genes per genome: $(echo "scale=1; $GENE_COUNT / $GENOME_COUNT" | bc)
Protein sequences: $PRODIGAL_DIR/${SAMPLE_NAME}_${ASSEMBLER}_proteins.faa
Gene sequences: $PRODIGAL_DIR/${SAMPLE_NAME}_${ASSEMBLER}_genes.fna
GFF annotations: $PRODIGAL_DIR/${SAMPLE_NAME}_${ASSEMBLER}_genes.gff

--------------------------------------------------------------------------------
DRAM-v Functional Annotation
--------------------------------------------------------------------------------
Annotations file: $DRAMV_DIR/annotations.tsv
Distillate summary: $DRAMV_DIR/distillate/

Key Functional Categories:
EOF

# Extract key statistics from DRAM-v if available
if [ -f "$DRAMV_DIR/annotations.tsv" ]; then
    # Count AMGs (Auxiliary Metabolic Genes)
    AMG_COUNT=$(awk -F'\t' '$NF == "M" || $NF == "A"' "$DRAMV_DIR/annotations.tsv" 2>/dev/null | wc -l || echo 0)
    echo "  Auxiliary Metabolic Genes (AMGs): $AMG_COUNT" >> "$SUMMARY_FILE"

    # Count viral hallmark genes
    HALLMARK_COUNT=$(grep -i "viral hallmark" "$DRAMV_DIR/annotations.tsv" 2>/dev/null | wc -l || echo 0)
    echo "  Viral hallmark genes: $HALLMARK_COUNT" >> "$SUMMARY_FILE"

    # Count annotated genes
    ANNOTATED_COUNT=$(awk -F'\t' 'NR>1 && $2 != ""' "$DRAMV_DIR/annotations.tsv" 2>/dev/null | wc -l || echo 0)
    echo "  Functionally annotated genes: $ANNOTATED_COUNT" >> "$SUMMARY_FILE"
    echo "  Hypothetical proteins: $(($GENE_COUNT - $ANNOTATED_COUNT))" >> "$SUMMARY_FILE"
fi

cat >> "$SUMMARY_FILE" <<EOF

--------------------------------------------------------------------------------
InterProScan Domain Annotation
--------------------------------------------------------------------------------
EOF

if [ -f "$INTERPRO_DIR/${SAMPLE_NAME}_${ASSEMBLER}_proteins.faa.tsv" ]; then
    DOMAIN_COUNT=$(wc -l < "$INTERPRO_DIR/${SAMPLE_NAME}_${ASSEMBLER}_proteins.faa.tsv")
    echo "Status: Completed" >> "$SUMMARY_FILE"
    echo "Domain annotations: $DOMAIN_COUNT" >> "$SUMMARY_FILE"
    echo "Output file: $INTERPRO_DIR/${SAMPLE_NAME}_${ASSEMBLER}_proteins.faa.tsv" >> "$SUMMARY_FILE"
else
    echo "Status: Skipped (too many proteins) or failed" >> "$SUMMARY_FILE"
    echo "Note: Run InterProScan manually if needed on specific proteins" >> "$SUMMARY_FILE"
fi

cat >> "$SUMMARY_FILE" <<EOF

--------------------------------------------------------------------------------
Key Output Files
--------------------------------------------------------------------------------
1. Gene Predictions:
   - Proteins: $PRODIGAL_DIR/${SAMPLE_NAME}_${ASSEMBLER}_proteins.faa
   - Genes (DNA): $PRODIGAL_DIR/${SAMPLE_NAME}_${ASSEMBLER}_genes.fna
   - GFF: $PRODIGAL_DIR/${SAMPLE_NAME}_${ASSEMBLER}_genes.gff

2. Functional Annotations:
   - DRAM-v annotations: $DRAMV_DIR/annotations.tsv
   - DRAM-v summary: $DRAMV_DIR/distillate/
   - AMG predictions: Check DRAM-v distillate for AMG summary

3. Domain Annotations:
   - InterProScan: $INTERPRO_DIR/${SAMPLE_NAME}_${ASSEMBLER}_proteins.faa.tsv

--------------------------------------------------------------------------------
Next Steps
--------------------------------------------------------------------------------
1. Review DRAM-v distillate summary for key functional insights
2. Identify AMGs (genes that interact with host metabolism)
3. Search for genes related to:
   - Host interaction (receptor binding, entry)
   - Replication and transcription
   - Structural proteins
4. Proceed to phylogenetic analysis for taxonomy assignment

================================================================================
EOF

# Display summary
cat "$SUMMARY_FILE"

# Copy key files to summary directory for easy access
cp "$DRAMV_DIR/annotations.tsv" "$SUMMARY_DIR/${SAMPLE_NAME}_${ASSEMBLER}_dramv_annotations.tsv" 2>/dev/null || true
if [ -d "$DRAMV_DIR/distillate" ]; then
    cp -r "$DRAMV_DIR/distillate" "$SUMMARY_DIR/" 2>/dev/null || true
fi

echo ""
echo "[$(date)] Summary generated" >> "$LOGFILE"

################################################################################
# Step 5: Create Gene-to-Genome Mapping
################################################################################
echo "=========================================="
echo "Step 5: Creating Gene-to-Genome Mapping"
echo "=========================================="
echo ""

echo "[$(date)] Step 5: Creating gene mapping" >> "$LOGFILE"

# Create a mapping file: Gene ID -> Genome ID
# This is useful for downstream analyses

MAPPING_FILE="$SUMMARY_DIR/${SAMPLE_NAME}_${ASSEMBLER}_gene_to_genome.tsv"

echo -e "gene_id\tgenome_id\tgene_start\tgene_end\tstrand" > "$MAPPING_FILE"

# Parse GFF file to extract gene-to-genome mapping
if [ -f "$PRODIGAL_DIR/${SAMPLE_NAME}_${ASSEMBLER}_genes.gff" ]; then
    awk -F'\t' '$3 == "CDS" {
        match($9, /ID=([^;]+)/, gene);
        print gene[1] "\t" $1 "\t" $4 "\t" $5 "\t" $7
    }' "$PRODIGAL_DIR/${SAMPLE_NAME}_${ASSEMBLER}_genes.gff" >> "$MAPPING_FILE"

    echo "Gene-to-genome mapping created: $MAPPING_FILE"
    echo "[$(date)] Gene mapping created" >> "$LOGFILE"
fi

echo ""

################################################################################
# Completion
################################################################################
echo "=========================================="
echo "Viral Genome Annotation Complete"
echo "=========================================="
echo "Results saved to: $OUTPUT_DIR"
echo "Summary: $SUMMARY_FILE"
echo "Completed: $(date)"
echo "=========================================="
echo ""

echo "[$(date)] Viral genome annotation completed successfully" >> "$LOGFILE"
echo "=== End of Log ===" >> "$LOGFILE"

exit 0
