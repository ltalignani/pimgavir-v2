#!/bin/bash

#SBATCH --job-name=viral_comparative
#SBATCH --partition=normal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem=64GB
#SBATCH --time=2-00:00:00
#SBATCH --output=viral_comparative_%j.out
#SBATCH --error=viral_comparative_%j.err

################################################################################
# Phase 4: Viral Comparative Genomics and Network Analysis
################################################################################
#
# Purpose: Compare viral genomes, cluster by protein similarity, and generate
#          viral taxonomic networks
#
# Key Tools:
#   - vConTACT2: Viral taxonomy through protein clustering
#   - geNomad: Gene and taxonomy annotation for viruses
#   - MMseqs2: Fast protein clustering
#   - Prodigal-gv: Viral gene prediction
#
# Input: High-quality viral genomes from Phase 1 (CheckV output)
# Output: Viral clusters, taxonomic networks, comparative genomics plots
#
# Usage:
#   sbatch viral-comparative-genomics.sh <viral_genomes.fasta> <output_dir> <threads> <sample_name>
#
# Author: PIMGAVir Pipeline
# Version: 2.2.0
# Date: 2025-10-31
################################################################################

# Exit on any error
set -e
set -u
set -o pipefail

# Input parameters
VIRAL_GENOMES=${1:-""}
OUTPUT_DIR=${2:-""}
THREADS=${3:-40}
SAMPLE_NAME=${4:-"sample"}

# Validate inputs
if [ -z "$VIRAL_GENOMES" ] || [ -z "$OUTPUT_DIR" ]; then
    echo "Error: Missing required arguments"
    echo "Usage: $0 <viral_genomes.fasta> <output_dir> <threads> <sample_name>"
    exit 1
fi

if [ ! -f "$VIRAL_GENOMES" ]; then
    echo "Error: Viral genomes file not found: $VIRAL_GENOMES"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Log file
LOGFILE="${OUTPUT_DIR}/comparative_genomics.log"
exec 1> >(tee -a "$LOGFILE")
exec 2>&1

echo "=================================================="
echo "VIRAL COMPARATIVE GENOMICS - PHASE 4"
echo "=================================================="
echo "Start time: $(date)"
echo "Viral genomes: $VIRAL_GENOMES"
echo "Output directory: $OUTPUT_DIR"
echo "Threads: $THREADS"
echo "Sample: $SAMPLE_NAME"
echo "=================================================="

# Check conda environment
if [ -z "${CONDA_DEFAULT_ENV:-}" ]; then
    echo "Warning: No conda environment activated"
    echo "Attempting to activate pimgavir_viralgenomes..."
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate pimgavir_viralgenomes || conda activate pimgavir_complete || conda activate pimgavir_minimal
fi

echo "Active conda environment: ${CONDA_DEFAULT_ENV}"

# Define subdirectories
GENOMAD_DIR="${OUTPUT_DIR}/genomad"
VCONTACT2_DIR="${OUTPUT_DIR}/vcontact2"
PROTEIN_DIR="${OUTPUT_DIR}/proteins"
CLUSTER_DIR="${OUTPUT_DIR}/clusters"
RESULTS_DIR="${OUTPUT_DIR}/results"

mkdir -p "$GENOMAD_DIR" "$VCONTACT2_DIR" "$PROTEIN_DIR" "$CLUSTER_DIR" "$RESULTS_DIR"

################################################################################
# Step 1: Gene Prediction with Prodigal-gv (virus-specific)
################################################################################

echo ""
echo "=========================================="
echo "Step 1: Viral Gene Prediction (Prodigal-gv)"
echo "=========================================="
echo "Start time: $(date)"

PROTEINS_FAA="${PROTEIN_DIR}/${SAMPLE_NAME}_proteins.faa"
GENES_FNA="${PROTEIN_DIR}/${SAMPLE_NAME}_genes.fna"
GENES_GFF="${PROTEIN_DIR}/${SAMPLE_NAME}_genes.gff"

if [ -f "$PROTEINS_FAA" ]; then
    echo "Protein file already exists: $PROTEINS_FAA"
    echo "Skipping gene prediction..."
else
    echo "Running Prodigal-gv for viral gene prediction..."

    prodigal-gv \
        -i "$VIRAL_GENOMES" \
        -a "$PROTEINS_FAA" \
        -d "$GENES_FNA" \
        -f gff \
        -o "$GENES_GFF" \
        -p meta \
        -q 2>&1 | tee "${PROTEIN_DIR}/prodigal.log"

    # Count proteins
    PROTEIN_COUNT=$(grep -c "^>" "$PROTEINS_FAA" || echo "0")
    echo "Predicted proteins: $PROTEIN_COUNT"

    if [ "$PROTEIN_COUNT" -eq 0 ]; then
        echo "ERROR: No proteins predicted"
        echo "This may indicate issues with the input viral genomes"
        exit 1
    fi
fi

echo "Gene prediction completed: $(date)"

################################################################################
# Step 2: geNomad - Viral Annotation and Classification
################################################################################

echo ""
echo "=========================================="
echo "Step 2: geNomad Annotation"
echo "=========================================="
echo "Start time: $(date)"

GENOMAD_SUMMARY="${GENOMAD_DIR}/${SAMPLE_NAME}_summary/${SAMPLE_NAME}_virus_summary.tsv"

if [ -f "$GENOMAD_SUMMARY" ]; then
    echo "geNomad results already exist: $GENOMAD_SUMMARY"
    echo "Skipping geNomad..."
else
    echo "Running geNomad end-to-end analysis..."
    echo "This includes: virus identification, gene annotation, and taxonomy assignment"

    # geNomad requires a database - check if it exists
    GENOMAD_DB="${HOME}/.genomad_db"

    if [ ! -d "$GENOMAD_DB" ]; then
        echo "geNomad database not found at: $GENOMAD_DB"
        echo "Downloading geNomad database (this is a one-time operation)..."
        genomad download-database "$GENOMAD_DB"
    else
        echo "Using geNomad database: $GENOMAD_DB"
    fi

    # Run geNomad end-to-end
    genomad end-to-end \
        --threads "$THREADS" \
        --cleanup \
        "$VIRAL_GENOMES" \
        "$GENOMAD_DIR" \
        "$GENOMAD_DB" \
        2>&1 | tee "${GENOMAD_DIR}/genomad.log"

    # Check if results were generated
    if [ -f "$GENOMAD_SUMMARY" ]; then
        VIRUS_COUNT=$(tail -n +2 "$GENOMAD_SUMMARY" | wc -l)
        echo "geNomad identified viruses: $VIRUS_COUNT"
    else
        echo "Warning: geNomad summary not found, continuing anyway..."
    fi
fi

echo "geNomad annotation completed: $(date)"

################################################################################
# Step 3: Protein Clustering with MMseqs2
################################################################################

echo ""
echo "=========================================="
echo "Step 3: Protein Clustering (MMseqs2)"
echo "=========================================="
echo "Start time: $(date)"

MMSEQS_CLUSTERS="${CLUSTER_DIR}/${SAMPLE_NAME}_protein_clusters.tsv"

if [ -f "$MMSEQS_CLUSTERS" ]; then
    echo "MMseqs2 clusters already exist: $MMSEQS_CLUSTERS"
    echo "Skipping MMseqs2..."
else
    echo "Running MMseqs2 for protein clustering..."
    echo "Parameters: 90% sequence identity, 80% coverage"

    # Create MMseqs2 database
    MMSEQS_DB="${CLUSTER_DIR}/mmseqs_db"
    MMSEQS_TMP="${CLUSTER_DIR}/tmp"
    mkdir -p "$MMSEQS_TMP"

    # Convert proteins to MMseqs2 database
    mmseqs createdb "$PROTEINS_FAA" "$MMSEQS_DB" \
        2>&1 | tee "${CLUSTER_DIR}/mmseqs_createdb.log"

    # Cluster proteins
    MMSEQS_CLUST="${CLUSTER_DIR}/mmseqs_clust"
    mmseqs cluster \
        "$MMSEQS_DB" \
        "$MMSEQS_CLUST" \
        "$MMSEQS_TMP" \
        --min-seq-id 0.9 \
        -c 0.8 \
        --cov-mode 0 \
        --threads "$THREADS" \
        2>&1 | tee "${CLUSTER_DIR}/mmseqs_cluster.log"

    # Convert to readable format
    mmseqs createtsv \
        "$MMSEQS_DB" \
        "$MMSEQS_DB" \
        "$MMSEQS_CLUST" \
        "$MMSEQS_CLUSTERS" \
        2>&1 | tee "${CLUSTER_DIR}/mmseqs_createtsv.log"

    # Generate representative sequences
    MMSEQS_REP="${CLUSTER_DIR}/mmseqs_rep"
    mmseqs createsubdb \
        "$MMSEQS_CLUST" \
        "$MMSEQS_DB" \
        "$MMSEQS_REP" \
        2>&1 | tee "${CLUSTER_DIR}/mmseqs_createsubdb.log"

    # Convert to FASTA
    MMSEQS_REP_FAA="${CLUSTER_DIR}/${SAMPLE_NAME}_rep_proteins.faa"
    mmseqs convert2fasta \
        "$MMSEQS_REP" \
        "$MMSEQS_REP_FAA" \
        2>&1 | tee "${CLUSTER_DIR}/mmseqs_convert2fasta.log"

    # Count clusters
    CLUSTER_COUNT=$(cut -f1 "$MMSEQS_CLUSTERS" | sort -u | wc -l)
    echo "Protein clusters identified: $CLUSTER_COUNT"

    # Cleanup temporary files
    rm -rf "$MMSEQS_TMP"
fi

echo "Protein clustering completed: $(date)"

################################################################################
# Step 4: vConTACT2 - Viral Taxonomy through Protein Clustering
################################################################################

echo ""
echo "=========================================="
echo "Step 4: vConTACT2 Network Analysis"
echo "=========================================="
echo "Start time: $(date)"

VCONTACT2_RESULTS="${VCONTACT2_DIR}/genome_by_genome_overview.csv"

if [ -f "$VCONTACT2_RESULTS" ]; then
    echo "vConTACT2 results already exist: $VCONTACT2_RESULTS"
    echo "Skipping vConTACT2..."
else
    echo "Preparing input for vConTACT2..."

    # vConTACT2 requires a specific input format
    # Gene-to-genome file: protein_id, contig_id, keywords
    GENE2GENOME="${VCONTACT2_DIR}/gene2genome.csv"

    # Create gene2genome file from Prodigal output
    echo "protein_id,contig_id,keywords" > "$GENE2GENOME"

    grep "^>" "$PROTEINS_FAA" | sed 's/^>//' | while read line; do
        # Extract protein ID (first field)
        protein_id=$(echo "$line" | awk '{print $1}')
        # Extract contig ID (everything before the underscore in the last field)
        contig_id=$(echo "$protein_id" | sed 's/_[0-9]*$//')
        # Add to gene2genome file
        echo "${protein_id},${contig_id},viral" >> "$GENE2GENOME"
    done

    GENE_COUNT=$(tail -n +2 "$GENE2GENOME" | wc -l)
    echo "Gene-to-genome mapping created: $GENE_COUNT genes"

    echo "Running vConTACT2..."
    echo "This will cluster viruses based on protein similarity networks"

    vcontact2 \
        --raw-proteins "$PROTEINS_FAA" \
        --rel-mode Diamond \
        --proteins-fp "$GENE2GENOME" \
        --db 'ProkaryoticViralRefSeq211-Merged' \
        --output-dir "$VCONTACT2_DIR" \
        --threads "$THREADS" \
        2>&1 | tee "${VCONTACT2_DIR}/vcontact2.log" || {
            echo "Warning: vConTACT2 failed, but continuing with analysis..."
            echo "This may be due to insufficient reference matches"
        }

    # Check results
    if [ -f "$VCONTACT2_RESULTS" ]; then
        # Count viral clusters
        VIRAL_CLUSTERS=$(tail -n +2 "$VCONTACT2_RESULTS" | cut -d',' -f2 | sort -u | wc -l)
        echo "Viral clusters identified by vConTACT2: $VIRAL_CLUSTERS"

        # Count singleton viruses (not in any cluster)
        SINGLETONS=$(tail -n +2 "$VCONTACT2_RESULTS" | grep -c "Singleton" || echo "0")
        echo "Singleton viruses: $SINGLETONS"
    else
        echo "Note: vConTACT2 results not generated (may require more sequences)"
    fi
fi

echo "vConTACT2 analysis completed: $(date)"

################################################################################
# Step 5: Generate Summary Report
################################################################################

echo ""
echo "=========================================="
echo "Step 5: Generate Summary Report"
echo "=========================================="
echo "Start time: $(date)"

SUMMARY_REPORT="${RESULTS_DIR}/${SAMPLE_NAME}_comparative_summary.txt"

cat > "$SUMMARY_REPORT" <<EOF
================================================================================
VIRAL COMPARATIVE GENOMICS SUMMARY - PHASE 4
================================================================================

Sample: $SAMPLE_NAME
Analysis Date: $(date)
Input Genomes: $VIRAL_GENOMES

--------------------------------------------------------------------------------
GENE PREDICTION (Prodigal-gv)
--------------------------------------------------------------------------------

Protein sequences: $PROTEINS_FAA
Predicted proteins: $(grep -c "^>" "$PROTEINS_FAA" 2>/dev/null || echo "0")
Gene coordinates: $GENES_GFF

Average genes per genome: $(awk "BEGIN {if ($(grep -c "^>" "$VIRAL_GENOMES" 2>/dev/null || echo "1") > 0) print $(grep -c "^>" "$PROTEINS_FAA" 2>/dev/null || echo "0") / $(grep -c "^>" "$VIRAL_GENOMES" 2>/dev/null || echo "1"); else print 0}")

--------------------------------------------------------------------------------
GENOMAD ANNOTATION
--------------------------------------------------------------------------------

Output directory: $GENOMAD_DIR
Summary file: $GENOMAD_SUMMARY

EOF

if [ -f "$GENOMAD_SUMMARY" ]; then
    echo "Annotated viruses: $(tail -n +2 "$GENOMAD_SUMMARY" | wc -l)" >> "$SUMMARY_REPORT"
    echo "" >> "$SUMMARY_REPORT"
    echo "Top viral taxa identified:" >> "$SUMMARY_REPORT"
    tail -n +2 "$GENOMAD_SUMMARY" | cut -f8 | sort | uniq -c | sort -rn | head -10 >> "$SUMMARY_REPORT"
else
    echo "geNomad annotation not completed" >> "$SUMMARY_REPORT"
fi

cat >> "$SUMMARY_REPORT" <<EOF

--------------------------------------------------------------------------------
PROTEIN CLUSTERING (MMseqs2)
--------------------------------------------------------------------------------

Cluster file: $MMSEQS_CLUSTERS
Total protein clusters: $(cut -f1 "$MMSEQS_CLUSTERS" 2>/dev/null | sort -u | wc -l || echo "0")
Representative proteins: ${CLUSTER_DIR}/${SAMPLE_NAME}_rep_proteins.faa

Cluster size distribution:
EOF

if [ -f "$MMSEQS_CLUSTERS" ]; then
    cut -f1 "$MMSEQS_CLUSTERS" | sort | uniq -c | awk '{print $1}' | sort -n | uniq -c | \
        awk '{printf "  %d proteins in cluster: %d times\n", $2, $1}' >> "$SUMMARY_REPORT"
else
    echo "  No clusters generated" >> "$SUMMARY_REPORT"
fi

cat >> "$SUMMARY_REPORT" <<EOF

--------------------------------------------------------------------------------
VCONTACT2 NETWORK ANALYSIS
--------------------------------------------------------------------------------

Output directory: $VCONTACT2_DIR
Results file: $VCONTACT2_RESULTS

EOF

if [ -f "$VCONTACT2_RESULTS" ]; then
    echo "Viral clusters: $(tail -n +2 "$VCONTACT2_RESULTS" | cut -d',' -f2 | sort -u | wc -l)" >> "$SUMMARY_REPORT"
    echo "Singleton viruses: $(tail -n +2 "$VCONTACT2_RESULTS" | grep -c "Singleton" || echo "0")" >> "$SUMMARY_REPORT"
    echo "" >> "$SUMMARY_REPORT"
    echo "Cluster distribution:" >> "$SUMMARY_REPORT"
    tail -n +2 "$VCONTACT2_RESULTS" | cut -d',' -f2 | sort | uniq -c | sort -rn | head -10 | \
        awk '{printf "  Cluster %s: %d genomes\n", $2, $1}' >> "$SUMMARY_REPORT"
else
    echo "vConTACT2 analysis not completed" >> "$SUMMARY_REPORT"
fi

cat >> "$SUMMARY_REPORT" <<EOF

--------------------------------------------------------------------------------
OUTPUT FILES
--------------------------------------------------------------------------------

Proteins:
  - Predicted proteins (FAA): $PROTEINS_FAA
  - Predicted genes (FNA): $GENES_FNA
  - Gene annotations (GFF): $GENES_GFF

Clusters:
  - Protein clusters (TSV): $MMSEQS_CLUSTERS
  - Representative proteins: ${CLUSTER_DIR}/${SAMPLE_NAME}_rep_proteins.faa

Annotation:
  - geNomad summary: $GENOMAD_SUMMARY
  - geNomad full results: $GENOMAD_DIR

Network Analysis:
  - vConTACT2 overview: $VCONTACT2_RESULTS
  - vConTACT2 full results: $VCONTACT2_DIR

Summary:
  - This report: $SUMMARY_REPORT

--------------------------------------------------------------------------------
NEXT STEPS
--------------------------------------------------------------------------------

1. Visualize viral networks using Cytoscape:
   - Import: ${VCONTACT2_DIR}/c1.ntw (network file)
   - Import: ${VCONTACT2_DIR}/genome_by_genome_overview.csv (node attributes)

2. Analyze protein clusters for conserved viral functions:
   - Use representative proteins: ${CLUSTER_DIR}/${SAMPLE_NAME}_rep_proteins.faa
   - BLAST against NCBI nr or Pfam for functional annotation

3. Examine geNomad results for auxiliary metabolic genes (AMGs):
   - Check: ${GENOMAD_DIR}/${SAMPLE_NAME}_summary/${SAMPLE_NAME}_virus_genes.tsv

4. Proceed to Phase 5: Host Prediction and Ecological Analysis
   - Script: viral-host-prediction.sh

================================================================================
End of Report
================================================================================
EOF

echo "Summary report generated: $SUMMARY_REPORT"
cat "$SUMMARY_REPORT"

################################################################################
# Step 6: Create Summary Statistics
################################################################################

echo ""
echo "=========================================="
echo "Step 6: Create Summary Statistics"
echo "=========================================="

STATS_FILE="${RESULTS_DIR}/${SAMPLE_NAME}_comparative_stats.tsv"

cat > "$STATS_FILE" <<EOF
Metric	Value
Input_Genomes	$(grep -c "^>" "$VIRAL_GENOMES" 2>/dev/null || echo "0")
Predicted_Proteins	$(grep -c "^>" "$PROTEINS_FAA" 2>/dev/null || echo "0")
Protein_Clusters	$(cut -f1 "$MMSEQS_CLUSTERS" 2>/dev/null | sort -u | wc -l || echo "0")
geNomad_Annotated_Viruses	$(tail -n +2 "$GENOMAD_SUMMARY" 2>/dev/null | wc -l || echo "0")
vConTACT2_Viral_Clusters	$(tail -n +2 "$VCONTACT2_RESULTS" 2>/dev/null | cut -d',' -f2 | sort -u | wc -l || echo "0")
vConTACT2_Singletons	$(tail -n +2 "$VCONTACT2_RESULTS" 2>/dev/null | grep -c "Singleton" || echo "0")
EOF

echo "Statistics saved to: $STATS_FILE"
cat "$STATS_FILE"

################################################################################
# Completion
################################################################################

echo ""
echo "=================================================="
echo "PHASE 4 COMPLETED SUCCESSFULLY"
echo "=================================================="
echo "End time: $(date)"
echo ""
echo "Key Output Files:"
echo "  - Summary report: $SUMMARY_REPORT"
echo "  - Statistics: $STATS_FILE"
echo "  - Proteins: $PROTEINS_FAA"
echo "  - Clusters: $MMSEQS_CLUSTERS"
echo "  - geNomad results: $GENOMAD_DIR"
echo "  - vConTACT2 results: $VCONTACT2_DIR"
echo ""
echo "Next: Run Phase 5 (Host Prediction) with:"
echo "  sbatch viral-host-prediction.sh $VIRAL_GENOMES <host_genomes.fasta> <output_dir> $THREADS $SAMPLE_NAME"
echo "=================================================="

exit 0
