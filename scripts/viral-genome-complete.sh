#!/bin/bash

################################################################################
# PIMGAVir - Complete Viral Genome Analysis Pipeline
#
# Purpose: Orchestrate complete viral genome recovery, annotation, and phylogenetic
#          analysis from metagenomic assemblies
#
# Input:
#   $1: Assembly FASTA file (contigs from MEGAHIT or SPAdes)
#   $2: Output base directory
#   $3: Number of threads
#   $4: Sample name
#   $5: Assembler name (MEGAHIT or SPADES)
#   $6: Reference proteins for phylogeny (optional, use "NONE" to skip)
#
# Workflow:
#   Phase 1: Viral genome recovery (VirSorter2, CheckV, vRhyme)
#   Phase 2: Functional annotation (DRAM-v, InterProScan)
#   Phase 3: Phylogenetic analysis (MAFFT, IQ-TREE, MrBayes)
#
# Output:
#   - Complete viral genomes
#   - Functional annotations
#   - Phylogenetic trees
#   - Comprehensive reports
#
# Version: 1.0 - 2025-10-29
################################################################################

set -eo pipefail

################################################################################
# Parse Arguments
################################################################################
ASSEMBLY=$1
OUTPUT_BASE=$2
THREADS=$3
SAMPLE_NAME=$4
ASSEMBLER=$5
REF_PROTEINS=${6:-"NONE"}

# Validate arguments
if [ -z "$ASSEMBLY" ] || [ -z "$OUTPUT_BASE" ] || [ -z "$THREADS" ] || [ -z "$SAMPLE_NAME" ] || [ -z "$ASSEMBLER" ]; then
    echo "ERROR: Missing required arguments"
    echo "Usage: viral-genome-complete.sh <assembly.fasta> <output_dir> <threads> <sample_name> <assembler> [reference_proteins.faa]"
    echo ""
    echo "Example:"
    echo "  viral-genome-complete.sh megahit_contigs.fasta viral-genomes 40 Sample01 MEGAHIT"
    echo "  viral-genome-complete.sh spades_scaffolds.fasta viral-genomes 40 Sample01 SPADES refs/coronavirus_RdRp.faa"
    exit 1
fi

# Check input file exists
if [ ! -f "$ASSEMBLY" ]; then
    echo "ERROR: Input file does not exist: $ASSEMBLY"
    exit 1
fi

################################################################################
# Setup
################################################################################
VERSION="PIMGAVir Viral Genome Analysis v1.0 - 2025-10-29"

echo "=========================================="
echo "$VERSION"
echo "=========================================="
echo "Sample: $SAMPLE_NAME"
echo "Assembler: $ASSEMBLER"
echo "Input: $ASSEMBLY"
echo "Output: $OUTPUT_BASE"
echo "Threads: $THREADS"
echo "Reference proteins: $REF_PROTEINS"
echo "Started: $(date)"
echo "=========================================="
echo ""

# Create output directory structure
mkdir -p "$OUTPUT_BASE"

# Define phase directories
PHASE1_DIR="$OUTPUT_BASE/phase1_recovery"
PHASE2_DIR="$OUTPUT_BASE/phase2_annotation"
PHASE3_DIR="$OUTPUT_BASE/phase3_phylogenetics"
REPORTS_DIR="$OUTPUT_BASE/reports"

mkdir -p "$PHASE1_DIR" "$PHASE2_DIR" "$PHASE3_DIR" "$REPORTS_DIR"

# Master log file
MASTER_LOG="$OUTPUT_BASE/viral_genome_analysis.log"
echo "=== PIMGAVir Viral Genome Analysis ===" > "$MASTER_LOG"
echo "Version: $VERSION" >> "$MASTER_LOG"
echo "Started: $(date)" >> "$MASTER_LOG"
echo "Sample: $SAMPLE_NAME" >> "$MASTER_LOG"
echo "Assembler: $ASSEMBLER" >> "$MASTER_LOG"
echo "" >> "$MASTER_LOG"

################################################################################
# Phase 1: Viral Genome Recovery
################################################################################
echo ""
echo "=========================================="
echo "PHASE 1: VIRAL GENOME RECOVERY"
echo "=========================================="
echo "Identifying and extracting complete viral genomes..."
echo ""

echo "[$(date)] PHASE 1: Viral genome recovery" >> "$MASTER_LOG"

# Run viral genome recovery module
bash viral-genome-recovery.sh \
    "$ASSEMBLY" \
    "$PHASE1_DIR" \
    "$THREADS" \
    "$SAMPLE_NAME" \
    "$ASSEMBLER" \
    2>&1 | tee -a "$MASTER_LOG"

# Check if Phase 1 completed successfully
PHASE1_STATUS=$?
if [ $PHASE1_STATUS -ne 0 ]; then
    echo "ERROR: Phase 1 (Viral genome recovery) failed with exit code $PHASE1_STATUS"
    echo "[$(date)] ERROR: Phase 1 failed" >> "$MASTER_LOG"
    exit 1
fi

# Check if any viral genomes were found
HQ_GENOMES="$PHASE1_DIR/04_final_genomes/${SAMPLE_NAME}_${ASSEMBLER}_viral_genomes_hq.fna"
if [ ! -f "$HQ_GENOMES" ] || [ ! -s "$HQ_GENOMES" ]; then
    echo ""
    echo "=========================================="
    echo "WARNING: No High-Quality Viral Genomes Found"
    echo "=========================================="
    echo "VirSorter2 and CheckV did not identify any high-quality viral genomes."
    echo "This could mean:"
    echo "  - No viral sequences in the assembly"
    echo "  - Viral sequences are too fragmented"
    echo "  - Viral sequences didn't pass quality thresholds"
    echo ""
    echo "Pipeline will stop here. Check intermediate results in:"
    echo "  $PHASE1_DIR"
    echo "=========================================="
    echo ""
    echo "[$(date)] WARNING: No HQ viral genomes found, stopping pipeline" >> "$MASTER_LOG"
    exit 0
fi

# Count recovered genomes
GENOME_COUNT=$(grep -c "^>" "$HQ_GENOMES" || echo 0)
echo ""
echo "Phase 1 Complete: $GENOME_COUNT high-quality viral genomes recovered"
echo "[$(date)] Phase 1 complete: $GENOME_COUNT HQ genomes" >> "$MASTER_LOG"
echo ""

################################################################################
# Phase 2: Functional Annotation
################################################################################
echo ""
echo "=========================================="
echo "PHASE 2: FUNCTIONAL ANNOTATION"
echo "=========================================="
echo "Annotating viral genomes with DRAM-v..."
echo ""

echo "[$(date)] PHASE 2: Functional annotation" >> "$MASTER_LOG"

# Run viral genome annotation module
bash viral-genome-annotation.sh \
    "$HQ_GENOMES" \
    "$PHASE2_DIR" \
    "$THREADS" \
    "$SAMPLE_NAME" \
    "$ASSEMBLER" \
    2>&1 | tee -a "$MASTER_LOG"

# Check if Phase 2 completed successfully
PHASE2_STATUS=$?
if [ $PHASE2_STATUS -ne 0 ]; then
    echo "ERROR: Phase 2 (Functional annotation) failed with exit code $PHASE2_STATUS"
    echo "[$(date)] ERROR: Phase 2 failed" >> "$MASTER_LOG"
    exit 1
fi

# Check if protein predictions were created
PROTEINS="$PHASE2_DIR/01_prodigal/${SAMPLE_NAME}_${ASSEMBLER}_proteins.faa"
if [ ! -f "$PROTEINS" ] || [ ! -s "$PROTEINS" ]; then
    echo "ERROR: No proteins predicted from viral genomes"
    echo "[$(date)] ERROR: No proteins predicted" >> "$MASTER_LOG"
    exit 1
fi

PROTEIN_COUNT=$(grep -c "^>" "$PROTEINS" || echo 0)
echo ""
echo "Phase 2 Complete: $PROTEIN_COUNT proteins predicted and annotated"
echo "[$(date)] Phase 2 complete: $PROTEIN_COUNT proteins" >> "$MASTER_LOG"
echo ""

################################################################################
# Phase 3: Phylogenetic Analysis
################################################################################
echo ""
echo "=========================================="
echo "PHASE 3: PHYLOGENETIC ANALYSIS"
echo "=========================================="
echo ""

echo "[$(date)] PHASE 3: Phylogenetic analysis" >> "$MASTER_LOG"

# Determine if we should run phylogenetics
RUN_PHYLO=false

if [ "$REF_PROTEINS" != "NONE" ] && [ -f "$REF_PROTEINS" ]; then
    echo "Reference proteins provided: $REF_PROTEINS"
    echo "Running phylogenetic analysis with references..."
    RUN_PHYLO=true
elif [ "$PROTEIN_COUNT" -ge 10 ]; then
    echo "Sufficient proteins for phylogenetic analysis ($PROTEIN_COUNT)"
    echo "Running phylogenetic analysis on query proteins only..."
    RUN_PHYLO=true
    REF_PROTEINS="NONE"
else
    echo "Insufficient proteins for meaningful phylogenetic analysis ($PROTEIN_COUNT < 10)"
    echo "Skipping Phase 3"
    echo "[$(date)] Phase 3 skipped: insufficient proteins" >> "$MASTER_LOG"
fi

if [ "$RUN_PHYLO" = true ]; then
    # Run phylogenetic analysis on all proteins
    bash viral-phylogenetics.sh \
        "$PROTEINS" \
        "$REF_PROTEINS" \
        "$PHASE3_DIR" \
        "$THREADS" \
        "$SAMPLE_NAME" \
        "all_proteins" \
        2>&1 | tee -a "$MASTER_LOG"

    # Check if Phase 3 completed successfully
    PHASE3_STATUS=$?
    if [ $PHASE3_STATUS -ne 0 ]; then
        echo "WARNING: Phase 3 (Phylogenetics) failed with exit code $PHASE3_STATUS"
        echo "Continuing to generate final report..."
        echo "[$(date)] WARNING: Phase 3 failed" >> "$MASTER_LOG"
    else
        echo ""
        echo "Phase 3 Complete: Phylogenetic trees generated"
        echo "[$(date)] Phase 3 complete" >> "$MASTER_LOG"
    fi
fi

echo ""

################################################################################
# Generate Master Report
################################################################################
echo ""
echo "=========================================="
echo "GENERATING MASTER REPORT"
echo "=========================================="
echo ""

echo "[$(date)] Generating master report" >> "$MASTER_LOG"

MASTER_REPORT="$REPORTS_DIR/${SAMPLE_NAME}_${ASSEMBLER}_viral_genome_report.txt"

cat > "$MASTER_REPORT" <<EOF
================================================================================
PIMGAVir - Complete Viral Genome Analysis Report
================================================================================
Version: $VERSION
Sample: $SAMPLE_NAME
Assembler: $ASSEMBLER
Date: $(date)

================================================================================
EXECUTIVE SUMMARY
================================================================================
Input assembly: $ASSEMBLY
Total contigs in assembly: $(grep -c "^>" "$ASSEMBLY" || echo 0)

High-quality viral genomes recovered: $GENOME_COUNT
Total proteins predicted: $PROTEIN_COUNT

================================================================================
PHASE 1: VIRAL GENOME RECOVERY
================================================================================
Location: $PHASE1_DIR

VirSorter2 Results:
EOF

# Add VirSorter2 summary
if [ -f "$PHASE1_DIR/01_virsorter/final-viral-combined.fa" ]; then
    VIRSORTER_COUNT=$(grep -c "^>" "$PHASE1_DIR/01_virsorter/final-viral-combined.fa" || echo 0)
    echo "  - Potential viral sequences identified: $VIRSORTER_COUNT" >> "$MASTER_REPORT"
fi

cat >> "$MASTER_REPORT" <<EOF

CheckV Quality Assessment:
EOF

# Add CheckV summary
if [ -f "$PHASE1_DIR/02_checkv/quality_summary.tsv" ]; then
    COMPLETE=$(awk -F'\t' 'NR>1 && $8 == "Complete"' "$PHASE1_DIR/02_checkv/quality_summary.tsv" | wc -l)
    HQ=$(awk -F'\t' 'NR>1 && $7 >= 90' "$PHASE1_DIR/02_checkv/quality_summary.tsv" | wc -l)
    MQ=$(awk -F'\t' 'NR>1 && $7 >= 50 && $7 < 90' "$PHASE1_DIR/02_checkv/quality_summary.tsv" | wc -l)
    LQ=$(awk -F'\t' 'NR>1 && $7 < 50' "$PHASE1_DIR/02_checkv/quality_summary.tsv" | wc -l)

    cat >> "$MASTER_REPORT" <<EOF
  - Complete genomes: $COMPLETE
  - High-quality (≥90%): $HQ
  - Medium-quality (50-90%): $MQ
  - Low-quality (<50%): $LQ

High-quality viral genomes: $HQ_GENOMES

EOF
fi

cat >> "$MASTER_REPORT" <<EOF
================================================================================
PHASE 2: FUNCTIONAL ANNOTATION
================================================================================
Location: $PHASE2_DIR

Gene Prediction (Prodigal-gv):
  - Total genes predicted: $PROTEIN_COUNT
  - Average genes per genome: $(echo "scale=1; $PROTEIN_COUNT / $GENOME_COUNT" | bc)

EOF

# Add DRAM-v summary
if [ -f "$PHASE2_DIR/02_dramv/annotations.tsv" ]; then
    AMG_COUNT=$(awk -F'\t' 'NR>1 && ($NF == "M" || $NF == "A")' "$PHASE2_DIR/02_dramv/annotations.tsv" 2>/dev/null | wc -l || echo 0)
    ANNOTATED=$(awk -F'\t' 'NR>1 && $2 != ""' "$PHASE2_DIR/02_dramv/annotations.tsv" 2>/dev/null | wc -l || echo 0)

    cat >> "$MASTER_REPORT" <<EOF
DRAM-v Functional Annotation:
  - Functionally annotated genes: $ANNOTATED
  - Auxiliary Metabolic Genes (AMGs): $AMG_COUNT
  - Hypothetical proteins: $(($PROTEIN_COUNT - $ANNOTATED))

Key Annotations:
  - See DRAM-v distillate for detailed AMG analysis
  - Location: $PHASE2_DIR/02_dramv/distillate/

EOF
fi

cat >> "$MASTER_REPORT" <<EOF
================================================================================
PHASE 3: PHYLOGENETIC ANALYSIS
================================================================================
EOF

if [ "$RUN_PHYLO" = true ] && [ -d "$PHASE3_DIR" ]; then
    cat >> "$MASTER_REPORT" <<EOF
Location: $PHASE3_DIR

Phylogenetic Tree:
EOF

    if [ -f "$PHASE3_DIR/02_trees/${SAMPLE_NAME}_all_proteins_iqtree.treefile" ]; then
        cat >> "$MASTER_REPORT" <<EOF
  - Maximum likelihood tree: $PHASE3_DIR/02_trees/${SAMPLE_NAME}_all_proteins_iqtree.treefile
  - Bootstrap support: 1000 ultrafast bootstrap replicates
  - Alignment: $PHASE3_DIR/01_alignment/${SAMPLE_NAME}_all_proteins_aligned_trimmed.faa

Visualization:
  - Use FigTree, iTOL, or R ggtree to visualize the tree
  - Tree file can be uploaded to https://itol.embl.de/ for interactive exploration

EOF
    else
        echo "  - Status: Failed or incomplete" >> "$MASTER_REPORT"
    fi
else
    echo "  - Status: Skipped (insufficient proteins or no references)" >> "$MASTER_REPORT"
fi

cat >> "$MASTER_REPORT" <<EOF

================================================================================
KEY OUTPUT FILES
================================================================================

1. Viral Genomes:
   - High-quality genomes: $HQ_GENOMES
   - CheckV quality report: $PHASE1_DIR/04_final_genomes/${SAMPLE_NAME}_${ASSEMBLER}_checkv_quality.tsv

2. Functional Annotations:
   - Protein sequences: $PROTEINS
   - DRAM-v annotations: $PHASE2_DIR/02_dramv/annotations.tsv
   - DRAM-v summary: $PHASE2_DIR/02_dramv/distillate/
   - Gene-to-genome mapping: $PHASE2_DIR/04_summary/${SAMPLE_NAME}_${ASSEMBLER}_gene_to_genome.tsv

3. Phylogenetic Analysis:
EOF

if [ "$RUN_PHYLO" = true ]; then
    cat >> "$MASTER_REPORT" <<EOF
   - ML tree: $PHASE3_DIR/02_trees/${SAMPLE_NAME}_all_proteins_iqtree.treefile
   - Alignment: $PHASE3_DIR/01_alignment/${SAMPLE_NAME}_all_proteins_aligned_trimmed.faa
EOF
else
    echo "   - Not performed" >> "$MASTER_REPORT"
fi

cat >> "$MASTER_REPORT" <<EOF

4. Summary Reports:
   - Phase 1 summary: $PHASE1_DIR/05_statistics/${SAMPLE_NAME}_${ASSEMBLER}_viral_recovery_summary.txt
   - Phase 2 summary: $PHASE2_DIR/04_summary/${SAMPLE_NAME}_${ASSEMBLER}_annotation_summary.txt
EOF

if [ "$RUN_PHYLO" = true ]; then
    echo "   - Phase 3 summary: $PHASE3_DIR/03_statistics/${SAMPLE_NAME}_all_proteins_phylogenetics_summary.txt" >> "$MASTER_REPORT"
fi

cat >> "$MASTER_REPORT" <<EOF

================================================================================
NEXT STEPS FOR PUBLICATION
================================================================================

1. TAXONOMIC CLASSIFICATION:
   - Use phylogenetic tree to determine viral family/genus
   - Compare to reference sequences from NCBI/RVDB
   - Check ICTV taxonomy for classification

2. GENOME CHARACTERIZATION:
   - Identify key genes (RdRp, spike, capsid, etc.)
   - Calculate G+C content and codon usage
   - Identify genome organization and gene order

3. ZOONOTIC POTENTIAL ASSESSMENT (for relevant viruses):
   - Search for furin cleavage sites in spike/fusion proteins
   - Analyze receptor binding domains
   - Compare to known zoonotic viruses

4. COMPARATIVE GENOMICS:
   - Calculate pairwise amino acid identity to known viruses
   - Perform synteny analysis with close relatives
   - Identify unique genes or domains

5. HOST PREDICTION:
   - Use host signals from AMG profile
   - Compare to host-associated viruses
   - Check CRISPR spacer matches if available

6. VISUALIZATION FOR PUBLICATION:
   - Generate genome maps with gene annotations
   - Create publication-quality phylogenetic trees
   - Produce comparative genomics figures

================================================================================
COMPUTATIONAL ENVIRONMENT
================================================================================
Analysis completed: $(date)
Total runtime: $SECONDS seconds ($(($SECONDS / 3600))h $(($SECONDS % 3600 / 60))m)

Conda environment: \${CONDA_DEFAULT_ENV:-unknown}
Key tools used:
  - VirSorter2 (viral identification)
  - CheckV (quality assessment)
  - vRhyme (genome binning)
  - Prodigal-gv (gene prediction)
  - DRAM-v (functional annotation)
  - MAFFT (alignment)
  - IQ-TREE (phylogenetics)

================================================================================
CITATION
================================================================================
If you use these results in a publication, please cite:

1. PIMGAVir pipeline
2. VirSorter2: Guo et al. (2021) Microbiome
3. CheckV: Nayfach et al. (2021) Nat Biotechnol
4. DRAM: Shaffer et al. (2020) Nucleic Acids Res
5. IQ-TREE: Nguyen et al. (2015) Mol Biol Evol

================================================================================
END OF REPORT
================================================================================
EOF

# Display report
echo "Master report generated:"
cat "$MASTER_REPORT"

echo ""
echo "[$(date)] Master report generated" >> "$MASTER_LOG"

################################################################################
# Copy Key Files to Reports Directory
################################################################################
echo ""
echo "Copying key output files to reports directory..."

# Copy summaries
cp "$PHASE1_DIR/05_statistics/${SAMPLE_NAME}_${ASSEMBLER}_viral_recovery_summary.txt" \
   "$REPORTS_DIR/" 2>/dev/null || true

cp "$PHASE2_DIR/04_summary/${SAMPLE_NAME}_${ASSEMBLER}_annotation_summary.txt" \
   "$REPORTS_DIR/" 2>/dev/null || true

if [ "$RUN_PHYLO" = true ]; then
    cp "$PHASE3_DIR/03_statistics/${SAMPLE_NAME}_all_proteins_phylogenetics_summary.txt" \
       "$REPORTS_DIR/" 2>/dev/null || true
fi

# Copy key data files
cp "$HQ_GENOMES" "$REPORTS_DIR/" 2>/dev/null || true
cp "$PROTEINS" "$REPORTS_DIR/" 2>/dev/null || true

echo "[$(date)] Key files copied to reports directory" >> "$MASTER_LOG"

################################################################################
# Completion
################################################################################
echo ""
echo "=========================================="
echo "VIRAL GENOME ANALYSIS COMPLETE"
echo "=========================================="
echo ""
echo "Summary:"
echo "  - Viral genomes recovered: $GENOME_COUNT"
echo "  - Proteins predicted: $PROTEIN_COUNT"
echo "  - Phylogenetic analysis: $([ "$RUN_PHYLO" = true ] && echo "Complete" || echo "Skipped")"
echo ""
echo "Results saved to: $OUTPUT_BASE"
echo "Master report: $MASTER_REPORT"
echo ""
echo "Total runtime: $SECONDS seconds ($(($SECONDS / 3600))h $(($SECONDS % 3600 / 60))m)"
echo ""
echo "=========================================="
echo "Completed: $(date)"
echo "=========================================="
echo ""

echo "[$(date)] Viral genome analysis completed successfully" >> "$MASTER_LOG"
echo "Total runtime: $SECONDS seconds" >> "$MASTER_LOG"
echo "=== End of Master Log ===" >> "$MASTER_LOG"

exit 0
