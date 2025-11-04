#!/bin/bash

#SBATCH --job-name=viral_complete
#SBATCH --partition=normal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem=64GB
#SBATCH --time=3-00:00:00
#SBATCH --output=viral_complete_%j.out
#SBATCH --error=viral_complete_%j.err

################################################################################
# Complete Viral Genome Analysis - All 7 Phases
################################################################################
#
# Purpose: Comprehensive viral genome recovery, annotation, phylogenetics,
#          comparative genomics, host prediction, zoonotic assessment, and
#          publication-ready report generation
#
# Workflow:
#   Phase 1: Viral Genome Recovery (VirSorter2 → CheckV → vRhyme)
#   Phase 2: Functional Annotation (DRAM-v → AMG detection)
#   Phase 3: Phylogenetic Analysis (MAFFT → IQ-TREE → MrBayes)
#   Phase 4: Comparative Genomics (geNomad → vConTACT2 → MMseqs2)
#   Phase 5: Host Prediction & Ecology (CRISPR → tRNA → k-mer → proteins)
#   Phase 6: Zoonotic Risk Assessment (Furin sites → RBD → Known pathogens)
#   Phase 7: Publication Report Generation (Figures → Tables → HTML report)
#
# Input:
#   - Assembled contigs (MEGAHIT/SPAdes output)
#   - Optional: Host genomes for Phase 5
#   - Optional: Reference viral genomes for Phase 3
#
# Output:
#   - Complete viral genome catalog
#   - Functional annotations with AMGs
#   - Phylogenetic trees
#   - Viral taxonomy networks
#   - Host predictions
#   - Ecological analysis
#
# Usage:
#   # Run all 7 phases
#   sbatch viral-genome-complete-7phases.sh <contigs.fasta> <output_dir> <threads> <sample_name> [host_genomes.fasta] [reference_viruses.fasta] [zoonotic_db.fasta]
#
#   # Run specific phases only
#   sbatch viral-genome-complete-7phases.sh <contigs.fasta> <output_dir> <threads> <sample_name> "" "" "" --phases 1,2,4,6,7
#
# Author: PIMGAVir Pipeline
# Version: 2.2.0
# Date: 2025-11-03
################################################################################

# Exit on any error
set -e
set -u
set -o pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored message
print_msg() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Input parameters
CONTIGS=${1:-""}
OUTPUT_DIR=${2:-""}
THREADS=${3:-40}
SAMPLE_NAME=${4:-"sample"}
HOST_GENOMES=${5:-""}
REFERENCE_VIRUSES=${6:-""}
ZOONOTIC_DB=${7:-""}
ASSEMBLER=${8:-"UNKNOWN"}  # Assembler name (MEGAHIT, SPADES, etc.)
PHASES_TO_RUN=${9:-"1,2,3,4,5,6,7"}  # Default: run all 7 phases

# Validate inputs
if [ -z "$CONTIGS" ] || [ -z "$OUTPUT_DIR" ]; then
    echo "Error: Missing required arguments"
    echo ""
    echo "Usage: $0 <contigs.fasta> <output_dir> <threads> <sample_name> [host_genomes.fasta] [reference_viruses.fasta] [zoonotic_db.fasta] <assembler> [--phases X,Y,Z]"
    echo ""
    echo "Arguments:"
    echo "  contigs.fasta          : Assembled contigs (MEGAHIT/SPAdes output)"
    echo "  output_dir             : Output directory for all results"
    echo "  threads                : Number of CPU threads (default: 40)"
    echo "  sample_name            : Sample identifier (default: 'sample')"
    echo "  host_genomes.fasta     : Optional host genomes for Phase 5"
    echo "  reference_viruses.fasta: Optional reference viruses for Phase 3"
    echo "  zoonotic_db.fasta      : Optional known zoonotic virus DB for Phase 6"
    echo "  assembler              : Assembler name (MEGAHIT, SPADES, etc.)"
    echo "  --phases X,Y,Z         : Run specific phases only (default: 1,2,3,4,5,6,7)"
    echo ""
    echo "Examples:"
    echo "  # Run all 7 phases"
    echo "  sbatch $0 contigs.fasta results/ 40 DJ_4 \"\" \"\" \"\" MEGAHIT"
    echo ""
    echo "  # Run phases 1-5 only (skip zoonotic assessment and report)"
    echo "  sbatch $0 contigs.fasta results/ 40 DJ_4 \"\" \"\" \"\" SPADES --phases 1,2,3,4,5"
    echo ""
    echo "  # Run with all optional inputs"
    echo "  sbatch $0 contigs.fasta results/ 40 DJ_4 hosts.fasta refs.fasta zoonotic.fasta MEGAHIT"
    exit 1
fi

if [ ! -f "$CONTIGS" ]; then
    echo "Error: Contigs file not found: $CONTIGS"
    exit 1
fi

# Parse --phases argument if provided
if [[ "$PHASES_TO_RUN" == --phases* ]]; then
    PHASES_TO_RUN=$(echo "$PHASES_TO_RUN" | sed 's/--phases //')
fi

# Create main output directory
mkdir -p "$OUTPUT_DIR"

# Create phase directories
PHASE1_DIR="${OUTPUT_DIR}/phase1_recovery"
PHASE2_DIR="${OUTPUT_DIR}/phase2_annotation"
PHASE3_DIR="${OUTPUT_DIR}/phase3_phylogenetics"
PHASE4_DIR="${OUTPUT_DIR}/phase4_comparative"
PHASE5_DIR="${OUTPUT_DIR}/phase5_host_ecology"
PHASE6_DIR="${OUTPUT_DIR}/phase6_zoonotic"
PHASE7_DIR="${OUTPUT_DIR}/phase7_publication_report"
FINAL_DIR="${OUTPUT_DIR}/final_results"

mkdir -p "$PHASE1_DIR" "$PHASE2_DIR" "$PHASE3_DIR" "$PHASE4_DIR" "$PHASE5_DIR" "$PHASE6_DIR" "$PHASE7_DIR" "$FINAL_DIR"

# Master log file
MASTER_LOG="${OUTPUT_DIR}/${SAMPLE_NAME}_complete_analysis.log"
exec 1> >(tee -a "$MASTER_LOG")
exec 2>&1

print_msg "$BLUE" "=================================================="
print_msg "$BLUE" "COMPLETE VIRAL GENOME ANALYSIS - ALL 7 PHASES"
print_msg "$BLUE" "=================================================="
echo "Start time: $(date)"
echo "Contigs: $CONTIGS"
echo "Output directory: $OUTPUT_DIR"
echo "Threads: $THREADS"
echo "Sample: $SAMPLE_NAME"
echo "Assembler: $ASSEMBLER"
echo "Host genomes: ${HOST_GENOMES:-"Not provided"}"
echo "Reference viruses: ${REFERENCE_VIRUSES:-"Not provided"}"
echo "Zoonotic DB: ${ZOONOTIC_DB:-"Not provided"}"
echo "Phases to run: $PHASES_TO_RUN"
print_msg "$BLUE" "=================================================="

# Check conda environment
if [ -z "${CONDA_DEFAULT_ENV:-}" ]; then
    echo "Warning: No conda environment activated"
    echo "Attempting to activate pimgavir_viralgenomes..."
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate pimgavir_viralgenomes || conda activate pimgavir_complete || conda activate pimgavir_minimal
fi

print_msg "$GREEN" "Active conda environment: ${CONDA_DEFAULT_ENV}"

# Function to check if a phase should be run
should_run_phase() {
    local phase=$1
    [[ ",$PHASES_TO_RUN," == *",$phase,"* ]]
}

# Track timing for each phase
PHASE_TIMES=()

################################################################################
# PHASE 1: Viral Genome Recovery
################################################################################

if should_run_phase 1; then
    print_msg "$YELLOW" ""
    print_msg "$YELLOW" "=================================================="
    print_msg "$YELLOW" "PHASE 1: VIRAL GENOME RECOVERY"
    print_msg "$YELLOW" "=================================================="
    PHASE1_START=$(date +%s)

    bash viral-genome-recovery.sh \
        "$CONTIGS" \
        "$PHASE1_DIR" \
        "$THREADS" \
        "$SAMPLE_NAME" \
        "$ASSEMBLER"

    PHASE1_END=$(date +%s)
    PHASE1_TIME=$((PHASE1_END - PHASE1_START))
    PHASE_TIMES+=("Phase 1: ${PHASE1_TIME}s")

    # Set high-quality viral genomes for subsequent phases
    VIRAL_GENOMES="${PHASE1_DIR}/high_quality_viruses/${SAMPLE_NAME}_hq_viruses.fasta"

    if [ ! -f "$VIRAL_GENOMES" ]; then
        print_msg "$RED" "ERROR: Phase 1 did not produce high-quality viral genomes"
        print_msg "$RED" "Expected file: $VIRAL_GENOMES"
        exit 1
    fi

    VIRUS_COUNT=$(grep -c "^>" "$VIRAL_GENOMES")
    print_msg "$GREEN" "Phase 1 completed: $VIRUS_COUNT high-quality viral genomes recovered"
else
    print_msg "$YELLOW" "Skipping Phase 1 (not in --phases list)"
    # Look for existing viral genomes from previous run
    VIRAL_GENOMES="${PHASE1_DIR}/high_quality_viruses/${SAMPLE_NAME}_hq_viruses.fasta"
    if [ ! -f "$VIRAL_GENOMES" ]; then
        print_msg "$RED" "ERROR: Phase 1 was skipped but no viral genomes found from previous run"
        print_msg "$RED" "Please run Phase 1 first or provide viral genomes"
        exit 1
    fi
fi

################################################################################
# PHASE 2: Functional Annotation
################################################################################

if should_run_phase 2; then
    print_msg "$YELLOW" ""
    print_msg "$YELLOW" "=================================================="
    print_msg "$YELLOW" "PHASE 2: FUNCTIONAL ANNOTATION"
    print_msg "$YELLOW" "=================================================="
    PHASE2_START=$(date +%s)

    bash viral-genome-annotation.sh \
        "$VIRAL_GENOMES" \
        "$PHASE2_DIR" \
        "$THREADS" \
        "$SAMPLE_NAME"

    PHASE2_END=$(date +%s)
    PHASE2_TIME=$((PHASE2_END - PHASE2_START))
    PHASE_TIMES+=("Phase 2: ${PHASE2_TIME}s")

    print_msg "$GREEN" "Phase 2 completed: Functional annotation finished"
else
    print_msg "$YELLOW" "Skipping Phase 2 (not in --phases list)"
fi

################################################################################
# PHASE 3: Phylogenetic Analysis
################################################################################

if should_run_phase 3; then
    print_msg "$YELLOW" ""
    print_msg "$YELLOW" "=================================================="
    print_msg "$YELLOW" "PHASE 3: PHYLOGENETIC ANALYSIS"
    print_msg "$YELLOW" "=================================================="
    PHASE3_START=$(date +%s)

    # Prepare reference sequences argument
    REF_ARG=""
    if [ -n "$REFERENCE_VIRUSES" ] && [ -f "$REFERENCE_VIRUSES" ]; then
        REF_ARG="$REFERENCE_VIRUSES"
        print_msg "$GREEN" "Using reference viruses: $REFERENCE_VIRUSES"
    else
        print_msg "$YELLOW" "No reference viruses provided - using only sample viruses"
    fi

    bash viral-phylogenetics.sh \
        "$VIRAL_GENOMES" \
        "$PHASE3_DIR" \
        "$THREADS" \
        "$SAMPLE_NAME" \
        "$REF_ARG"

    PHASE3_END=$(date +%s)
    PHASE3_TIME=$((PHASE3_END - PHASE3_START))
    PHASE_TIMES+=("Phase 3: ${PHASE3_TIME}s")

    print_msg "$GREEN" "Phase 3 completed: Phylogenetic trees generated"
else
    print_msg "$YELLOW" "Skipping Phase 3 (not in --phases list)"
fi

################################################################################
# PHASE 4: Comparative Genomics
################################################################################

if should_run_phase 4; then
    print_msg "$YELLOW" ""
    print_msg "$YELLOW" "=================================================="
    print_msg "$YELLOW" "PHASE 4: COMPARATIVE GENOMICS"
    print_msg "$YELLOW" "=================================================="
    PHASE4_START=$(date +%s)

    bash viral-comparative-genomics.sh \
        "$VIRAL_GENOMES" \
        "$PHASE4_DIR" \
        "$THREADS" \
        "$SAMPLE_NAME"

    PHASE4_END=$(date +%s)
    PHASE4_TIME=$((PHASE4_END - PHASE4_START))
    PHASE_TIMES+=("Phase 4: ${PHASE4_TIME}s")

    print_msg "$GREEN" "Phase 4 completed: Comparative genomics and taxonomy networks generated"
else
    print_msg "$YELLOW" "Skipping Phase 4 (not in --phases list)"
fi

################################################################################
# PHASE 5: Host Prediction & Ecology
################################################################################

if should_run_phase 5; then
    print_msg "$YELLOW" ""
    print_msg "$YELLOW" "=================================================="
    print_msg "$YELLOW" "PHASE 5: HOST PREDICTION & ECOLOGY"
    print_msg "$YELLOW" "=================================================="
    PHASE5_START=$(date +%s)

    # Prepare host genomes argument
    HOST_ARG=""
    if [ -n "$HOST_GENOMES" ] && [ -f "$HOST_GENOMES" ]; then
        HOST_ARG="$HOST_GENOMES"
        print_msg "$GREEN" "Using host genomes: $HOST_GENOMES"
    else
        print_msg "$YELLOW" "No host genomes provided - only viral ecology will be analyzed"
    fi

    bash viral-host-prediction.sh \
        "$VIRAL_GENOMES" \
        "$HOST_ARG" \
        "$PHASE5_DIR" \
        "$THREADS" \
        "$SAMPLE_NAME"

    PHASE5_END=$(date +%s)
    PHASE5_TIME=$((PHASE5_END - PHASE5_START))
    PHASE_TIMES+=("Phase 5: ${PHASE5_TIME}s")

    print_msg "$GREEN" "Phase 5 completed: Host prediction and ecology analysis finished"
else
    print_msg "$YELLOW" "Skipping Phase 5 (not in --phases list)"
fi

################################################################################
# PHASE 6: Zoonotic Risk Assessment
################################################################################

if should_run_phase 6; then
    print_msg "$YELLOW" ""
    print_msg "$YELLOW" "=================================================="
    print_msg "$YELLOW" "PHASE 6: ZOONOTIC RISK ASSESSMENT"
    print_msg "$YELLOW" "=================================================="
    PHASE6_START=$(date +%s)

    # Check that Phase 2 was completed (need proteins)
    VIRAL_PROTEINS="${PHASE2_DIR}/prodigal/${SAMPLE_NAME}_proteins.faa"
    if [ ! -f "$VIRAL_PROTEINS" ]; then
        print_msg "$RED" "ERROR: Phase 2 output (proteins) not found"
        print_msg "$RED" "Phase 6 requires Phase 2 to be completed first"
        exit 1
    fi

    # Prepare zoonotic database argument
    ZOONOTIC_ARG=""
    if [ -n "$ZOONOTIC_DB" ] && [ -f "$ZOONOTIC_DB" ]; then
        ZOONOTIC_ARG="$ZOONOTIC_DB"
        print_msg "$GREEN" "Using zoonotic virus database: $ZOONOTIC_DB"
    else
        print_msg "$YELLOW" "No zoonotic virus database provided - using pattern-based detection only"
    fi

    bash viral-zoonotic-assessment.sh \
        "$VIRAL_GENOMES" \
        "$VIRAL_PROTEINS" \
        "$PHASE6_DIR" \
        "$THREADS" \
        "$SAMPLE_NAME" \
        "$ZOONOTIC_ARG"

    PHASE6_END=$(date +%s)
    PHASE6_TIME=$((PHASE6_END - PHASE6_START))
    PHASE_TIMES+=("Phase 6: ${PHASE6_TIME}s")

    print_msg "$GREEN" "Phase 6 completed: Zoonotic risk assessment finished"
else
    print_msg "$YELLOW" "Skipping Phase 6 (not in --phases list)"
fi

################################################################################
# PHASE 7: Publication Report Generation
################################################################################

if should_run_phase 7; then
    print_msg "$YELLOW" ""
    print_msg "$YELLOW" "=================================================="
    print_msg "$YELLOW" "PHASE 7: PUBLICATION REPORT GENERATION"
    print_msg "$YELLOW" "=================================================="
    PHASE7_START=$(date +%s)

    bash viral-report-generation.sh \
        "$OUTPUT_DIR" \
        "$PHASE7_DIR" \
        "$SAMPLE_NAME"

    PHASE7_END=$(date +%s)
    PHASE7_TIME=$((PHASE7_END - PHASE7_START))
    PHASE_TIMES+=("Phase 7: ${PHASE7_TIME}s")

    print_msg "$GREEN" "Phase 7 completed: Publication report generated"
else
    print_msg "$YELLOW" "Skipping Phase 7 (not in --phases list)"
fi

################################################################################
# Generate Master Summary Report
################################################################################

print_msg "$YELLOW" ""
print_msg "$YELLOW" "=================================================="
print_msg "$YELLOW" "GENERATING MASTER SUMMARY REPORT"
print_msg "$YELLOW" "=================================================="

MASTER_REPORT="${FINAL_DIR}/${SAMPLE_NAME}_complete_analysis_summary.txt"

cat > "$MASTER_REPORT" <<EOF
================================================================================
COMPLETE VIRAL GENOME ANALYSIS - MASTER SUMMARY
================================================================================

Sample: $SAMPLE_NAME
Analysis Date: $(date)
Input Contigs: $CONTIGS
Threads Used: $THREADS

Phases Executed: $PHASES_TO_RUN

================================================================================
PHASE 1: VIRAL GENOME RECOVERY
================================================================================

EOF

if should_run_phase 1; then
    if [ -f "${PHASE1_DIR}/results/${SAMPLE_NAME}_recovery_summary.txt" ]; then
        cat "${PHASE1_DIR}/results/${SAMPLE_NAME}_recovery_summary.txt" >> "$MASTER_REPORT"
    else
        echo "Phase 1 summary not available" >> "$MASTER_REPORT"
    fi
else
    echo "Phase 1 was skipped" >> "$MASTER_REPORT"
fi

cat >> "$MASTER_REPORT" <<EOF

================================================================================
PHASE 2: FUNCTIONAL ANNOTATION
================================================================================

EOF

if should_run_phase 2; then
    if [ -f "${PHASE2_DIR}/results/${SAMPLE_NAME}_annotation_summary.txt" ]; then
        cat "${PHASE2_DIR}/results/${SAMPLE_NAME}_annotation_summary.txt" >> "$MASTER_REPORT"
    else
        echo "Phase 2 summary not available" >> "$MASTER_REPORT"
    fi
else
    echo "Phase 2 was skipped" >> "$MASTER_REPORT"
fi

cat >> "$MASTER_REPORT" <<EOF

================================================================================
PHASE 3: PHYLOGENETIC ANALYSIS
================================================================================

EOF

if should_run_phase 3; then
    if [ -f "${PHASE3_DIR}/results/${SAMPLE_NAME}_phylo_summary.txt" ]; then
        cat "${PHASE3_DIR}/results/${SAMPLE_NAME}_phylo_summary.txt" >> "$MASTER_REPORT"
    else
        echo "Phase 3 summary not available" >> "$MASTER_REPORT"
    fi
else
    echo "Phase 3 was skipped" >> "$MASTER_REPORT"
fi

cat >> "$MASTER_REPORT" <<EOF

================================================================================
PHASE 4: COMPARATIVE GENOMICS
================================================================================

EOF

if should_run_phase 4; then
    if [ -f "${PHASE4_DIR}/results/${SAMPLE_NAME}_comparative_summary.txt" ]; then
        cat "${PHASE4_DIR}/results/${SAMPLE_NAME}_comparative_summary.txt" >> "$MASTER_REPORT"
    else
        echo "Phase 4 summary not available" >> "$MASTER_REPORT"
    fi
else
    echo "Phase 4 was skipped" >> "$MASTER_REPORT"
fi

cat >> "$MASTER_REPORT" <<EOF

================================================================================
PHASE 5: HOST PREDICTION & ECOLOGY
================================================================================

EOF

if should_run_phase 5; then
    if [ -f "${PHASE5_DIR}/results/${SAMPLE_NAME}_host_ecology_summary.txt" ]; then
        cat "${PHASE5_DIR}/results/${SAMPLE_NAME}_host_ecology_summary.txt" >> "$MASTER_REPORT"
    else
        echo "Phase 5 summary not available" >> "$MASTER_REPORT"
    fi
else
    echo "Phase 5 was skipped" >> "$MASTER_REPORT"
fi

cat >> "$MASTER_REPORT" <<EOF

================================================================================
PHASE 6: ZOONOTIC RISK ASSESSMENT
================================================================================

EOF

if should_run_phase 6; then
    if [ -f "${PHASE6_DIR}/results/${SAMPLE_NAME}_zoonotic_risk_report.txt" ]; then
        # Extract summary from zoonotic report (first 100 lines)
        head -100 "${PHASE6_DIR}/results/${SAMPLE_NAME}_zoonotic_risk_report.txt" >> "$MASTER_REPORT"
    else
        echo "Phase 6 summary not available" >> "$MASTER_REPORT"
    fi
else
    echo "Phase 6 was skipped" >> "$MASTER_REPORT"
fi

cat >> "$MASTER_REPORT" <<EOF

================================================================================
PHASE 7: PUBLICATION REPORT GENERATION
================================================================================

EOF

if should_run_phase 7; then
    if [ -f "${PHASE7_DIR}/${SAMPLE_NAME}_publication_report_summary.txt" ]; then
        cat "${PHASE7_DIR}/${SAMPLE_NAME}_publication_report_summary.txt" >> "$MASTER_REPORT"
    else
        echo "Phase 7 completed - see publication report directory" >> "$MASTER_REPORT"
        echo "HTML report: ${PHASE7_DIR}/html_report/interactive_report.html" >> "$MASTER_REPORT"
    fi
else
    echo "Phase 7 was skipped" >> "$MASTER_REPORT"
fi

cat >> "$MASTER_REPORT" <<EOF

================================================================================
TIMING SUMMARY
================================================================================

EOF

for timing in "${PHASE_TIMES[@]}"; do
    echo "$timing" >> "$MASTER_REPORT"
done

TOTAL_TIME=0
for timing in "${PHASE_TIMES[@]}"; do
    phase_time=$(echo "$timing" | grep -oP '\d+(?=s)')
    TOTAL_TIME=$((TOTAL_TIME + phase_time))
done

cat >> "$MASTER_REPORT" <<EOF

Total execution time: ${TOTAL_TIME}s ($(($TOTAL_TIME / 3600))h $(($TOTAL_TIME % 3600 / 60))m $(($TOTAL_TIME % 60))s)

================================================================================
KEY OUTPUT FILES
================================================================================

Phase 1 - Viral Recovery:
  - High-quality viruses: ${PHASE1_DIR}/high_quality_viruses/${SAMPLE_NAME}_hq_viruses.fasta
  - CheckV summary: ${PHASE1_DIR}/checkv/${SAMPLE_NAME}_checkv_summary.tsv
  - vRhyme bins: ${PHASE1_DIR}/vrhyme/

Phase 2 - Annotation:
  - DRAM-v annotations: ${PHASE2_DIR}/dramv/annotations.tsv
  - AMG summary: ${PHASE2_DIR}/dramv/distill/amg_summary.tsv
  - Genome summaries: ${PHASE2_DIR}/dramv/distill/genome_stats.tsv

Phase 3 - Phylogenetics:
  - Maximum likelihood tree: ${PHASE3_DIR}/iqtree/${SAMPLE_NAME}_viral.treefile
  - Bayesian tree: ${PHASE3_DIR}/mrbayes/${SAMPLE_NAME}_viral.con.tre
  - Alignment: ${PHASE3_DIR}/alignment/${SAMPLE_NAME}_trimmed.fasta

Phase 4 - Comparative:
  - Protein clusters: ${PHASE4_DIR}/clusters/${SAMPLE_NAME}_protein_clusters.tsv
  - vConTACT2 networks: ${PHASE4_DIR}/vcontact2/genome_by_genome_overview.csv
  - geNomad annotations: ${PHASE4_DIR}/genomad/

Phase 5 - Host & Ecology:
  - Host predictions: ${PHASE5_DIR}/results/${SAMPLE_NAME}_host_predictions.tsv
  - Diversity stats: ${PHASE5_DIR}/ecology/${SAMPLE_NAME}_diversity.txt
  - CRISPR matches: ${PHASE5_DIR}/crispr/${SAMPLE_NAME}_crispr_matches.txt

Phase 6 - Zoonotic Assessment:
  - Risk report: ${PHASE6_DIR}/results/${SAMPLE_NAME}_zoonotic_risk_report.txt
  - Furin sites: ${PHASE6_DIR}/furin_sites/${SAMPLE_NAME}_furin_sites.txt
  - RBD candidates: ${PHASE6_DIR}/rbd_analysis/${SAMPLE_NAME}_rbd_candidates.faa
  - Summary table: ${PHASE6_DIR}/results/${SAMPLE_NAME}_zoonotic_summary.tsv

Phase 7 - Publication Report:
  - HTML report: ${PHASE7_DIR}/html_report/interactive_report.html
  - Publication figures: ${PHASE7_DIR}/figures/
  - Supplementary tables: ${PHASE7_DIR}/tables/
  - Methods section: ${PHASE7_DIR}/methods/methods_section.txt

Master Summary:
  - This report: $MASTER_REPORT
  - Complete log: $MASTER_LOG

================================================================================
PUBLICATION-READY OUTPUTS
================================================================================

For manuscript figures:
1. Phylogenetic tree (Phase 3): Use IQ-TREE output with FigTree or iTOL
2. Viral taxonomy network (Phase 4): Use vConTACT2 output with Cytoscape
3. Host-virus network (Phase 5): Use predictions with Gephi or Cytoscape
4. Functional annotation (Phase 2): AMG heatmap from DRAM-v
5. Publication-ready figures (Phase 7): See figures/ directory

For supplementary tables:
1. High-quality viral genomes with quality metrics (Phase 1)
2. Functional annotations with AMG predictions (Phase 2)
3. Host predictions with confidence scores (Phase 5)
4. Viral diversity and ecology statistics (Phase 5)
5. Zoonotic risk assessment (Phase 6)
6. Pre-formatted tables (Phase 7): See tables/ directory

For methods section:
- Complete methods text: See Phase 7 output (methods/methods_section.txt)
- Or use citation information below for manual methods writing

For publication materials:
- Interactive HTML report: Phase 7 (html_report/interactive_report.html)
- All figures, tables, and methods in one place

================================================================================
NEXT STEPS
================================================================================

1. Quality Control:
   - Review CheckV quality metrics
   - Verify high-quality viral genomes (>90% complete, <5% contamination)

2. Functional Analysis:
   - Examine AMG predictions in DRAM-v output
   - Identify key metabolic pathways

3. Phylogenetic Validation:
   - Check tree topology and bootstrap support
   - Compare ML and Bayesian trees for consistency

4. Taxonomy Assignment:
   - Review vConTACT2 clusters
   - Validate with NCBI taxonomy

5. Host Validation:
   - Prioritize CRISPR matches (highest confidence)
   - Cross-validate with k-mer and protein similarity

6. Comparative Analysis:
   - Compare across multiple samples
   - Identify sample-specific vs. shared viruses

7. Publication:
   - Generate publication-quality figures
   - Prepare supplementary tables
   - Write methods section

================================================================================
CITATION
================================================================================

If you use this pipeline, please cite:

PIMGAVir v2.2 - Complete 7-Phase Viral Genome Analysis Module
- VirSorter2: Guo et al., 2021, Microbiome
- CheckV: Nayfach et al., 2021, Nature Biotechnology
- vRhyme: Kieft et al., 2022, Nucleic Acids Research
- DRAM-v: Shaffer et al., 2020, Nucleic Acids Research
- IQ-TREE: Nguyen et al., 2015, Molecular Biology and Evolution
- vConTACT2: Bin Jang et al., 2019, Nature Biotechnology
- geNomad: Camargo et al., 2023, Nature Biotechnology
- MMseqs2: Steinegger & Söding, 2017, Nature Biotechnology

See Phase 7 methods section for complete citation list

================================================================================
End of Master Summary Report
================================================================================
Analysis completed: $(date)
================================================================================
EOF

print_msg "$GREEN" "Master summary report generated: $MASTER_REPORT"

################################################################################
# Copy Key Files to Final Results
################################################################################

print_msg "$YELLOW" ""
print_msg "$YELLOW" "=================================================="
print_msg "$YELLOW" "COPYING KEY FILES TO FINAL RESULTS"
print_msg "$YELLOW" "=================================================="

# Copy most important files for easy access
if should_run_phase 1 && [ -f "$VIRAL_GENOMES" ]; then
    cp "$VIRAL_GENOMES" "${FINAL_DIR}/"
    print_msg "$GREEN" "Copied: High-quality viral genomes"
fi

if should_run_phase 2 && [ -f "${PHASE2_DIR}/dramv/distill/amg_summary.tsv" ]; then
    cp "${PHASE2_DIR}/dramv/distill/amg_summary.tsv" "${FINAL_DIR}/"
    print_msg "$GREEN" "Copied: AMG summary"
fi

if should_run_phase 3 && [ -f "${PHASE3_DIR}/iqtree/${SAMPLE_NAME}_viral.treefile" ]; then
    cp "${PHASE3_DIR}/iqtree/${SAMPLE_NAME}_viral.treefile" "${FINAL_DIR}/"
    print_msg "$GREEN" "Copied: Phylogenetic tree"
fi

if should_run_phase 4 && [ -f "${PHASE4_DIR}/vcontact2/genome_by_genome_overview.csv" ]; then
    cp "${PHASE4_DIR}/vcontact2/genome_by_genome_overview.csv" "${FINAL_DIR}/"
    print_msg "$GREEN" "Copied: vConTACT2 taxonomy"
fi

if should_run_phase 5 && [ -f "${PHASE5_DIR}/results/${SAMPLE_NAME}_host_predictions.tsv" ]; then
    cp "${PHASE5_DIR}/results/${SAMPLE_NAME}_host_predictions.tsv" "${FINAL_DIR}/"
    print_msg "$GREEN" "Copied: Host predictions"
fi

if should_run_phase 6 && [ -f "${PHASE6_DIR}/results/${SAMPLE_NAME}_zoonotic_risk_report.txt" ]; then
    cp "${PHASE6_DIR}/results/${SAMPLE_NAME}_zoonotic_risk_report.txt" "${FINAL_DIR}/"
    print_msg "$GREEN" "Copied: Zoonotic risk report"
fi

if should_run_phase 7 && [ -f "${PHASE7_DIR}/html_report/interactive_report.html" ]; then
    cp "${PHASE7_DIR}/html_report/interactive_report.html" "${FINAL_DIR}/"
    print_msg "$GREEN" "Copied: Interactive HTML report"
fi

################################################################################
# Completion
################################################################################

print_msg "$GREEN" ""
print_msg "$GREEN" "=================================================="
print_msg "$GREEN" "ALL PHASES COMPLETED SUCCESSFULLY!"
print_msg "$GREEN" "=================================================="
echo "End time: $(date)"
echo ""
echo "Total execution time: ${TOTAL_TIME}s ($(($TOTAL_TIME / 3600))h $(($TOTAL_TIME % 3600 / 60))m $(($TOTAL_TIME % 60))s)"
echo ""
print_msg "$GREEN" "Master summary report: $MASTER_REPORT"
print_msg "$GREEN" "Key results directory: $FINAL_DIR"
if should_run_phase 7; then
    print_msg "$GREEN" "Interactive HTML report: ${PHASE7_DIR}/html_report/interactive_report.html"
    print_msg "$GREEN" "Publication materials: ${PHASE7_DIR}/"
fi
echo ""
print_msg "$BLUE" "=================================================="
print_msg "$BLUE" "Complete 7-phase viral genome analysis finished!"
print_msg "$BLUE" "=================================================="
if should_run_phase 7; then
    print_msg "$BLUE" ""
    print_msg "$BLUE" "Next steps:"
    print_msg "$BLUE" "  1. Open HTML report in browser"
    print_msg "$BLUE" "  2. Review publication figures and tables"
    print_msg "$BLUE" "  3. Customize for your journal requirements"
fi

exit 0
