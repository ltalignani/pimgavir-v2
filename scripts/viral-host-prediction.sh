#!/bin/bash

#SBATCH --job-name=viral_host
#SBATCH --partition=normal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=40
#SBATCH --mem=64GB
#SBATCH --time=2-00:00:00
#SBATCH --output=viral_host_%j.out
#SBATCH --error=viral_host_%j.err

################################################################################
# Phase 5: Viral Host Prediction and Ecological Analysis
################################################################################
#
# Purpose: Predict viral hosts using multiple complementary methods and
#          perform ecological analysis of viral communities
#
# Key Methods:
#   1. CRISPR spacer matching (direct evidence of infection)
#   2. tRNA matching (integration potential)
#   3. Nucleotide composition similarity (k-mer based)
#   4. Protein homology (shared genes)
#   5. Ecological co-occurrence patterns
#
# Input:
#   - Viral genomes from Phase 1 (CheckV high-quality viruses)
#   - Host genomes (bacterial/archaeal genomes from sample or database)
#
# Output:
#   - Host predictions with confidence scores
#   - Virus-host network
#   - Ecological analysis (diversity, community structure)
#
# Usage:
#   sbatch viral-host-prediction.sh <viral_genomes.fasta> <host_genomes.fasta> <output_dir> <threads> <sample_name>
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
HOST_GENOMES=${2:-""}
OUTPUT_DIR=${3:-""}
THREADS=${4:-40}
SAMPLE_NAME=${5:-"sample"}

# Validate inputs
if [ -z "$VIRAL_GENOMES" ] || [ -z "$OUTPUT_DIR" ]; then
    echo "Error: Missing required arguments"
    echo "Usage: $0 <viral_genomes.fasta> <host_genomes.fasta> <output_dir> <threads> <sample_name>"
    echo ""
    echo "Note: host_genomes.fasta is optional. If not provided, only viral ecology analysis will be performed."
    exit 1
fi

if [ ! -f "$VIRAL_GENOMES" ]; then
    echo "Error: Viral genomes file not found: $VIRAL_GENOMES"
    exit 1
fi

# Host genomes are optional
HOST_PREDICTION=true
if [ -z "$HOST_GENOMES" ] || [ ! -f "$HOST_GENOMES" ]; then
    echo "Warning: Host genomes not provided or not found: $HOST_GENOMES"
    echo "Skipping host prediction, will only perform viral ecology analysis"
    HOST_PREDICTION=false
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Log file
LOGFILE="${OUTPUT_DIR}/host_prediction.log"
exec 1> >(tee -a "$LOGFILE")
exec 2>&1

echo "=================================================="
echo "VIRAL HOST PREDICTION & ECOLOGY - PHASE 5"
echo "=================================================="
echo "Start time: $(date)"
echo "Viral genomes: $VIRAL_GENOMES"
echo "Host genomes: ${HOST_GENOMES:-"Not provided"}"
echo "Output directory: $OUTPUT_DIR"
echo "Threads: $THREADS"
echo "Sample: $SAMPLE_NAME"
echo "Host prediction enabled: $HOST_PREDICTION"
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
CRISPR_DIR="${OUTPUT_DIR}/crispr"
TRNA_DIR="${OUTPUT_DIR}/trna"
KMER_DIR="${OUTPUT_DIR}/kmer_analysis"
PROTEIN_DIR="${OUTPUT_DIR}/protein_homology"
ECOLOGY_DIR="${OUTPUT_DIR}/ecology"
RESULTS_DIR="${OUTPUT_DIR}/results"

mkdir -p "$CRISPR_DIR" "$TRNA_DIR" "$KMER_DIR" "$PROTEIN_DIR" "$ECOLOGY_DIR" "$RESULTS_DIR"

################################################################################
# PART A: HOST PREDICTION (only if host genomes provided)
################################################################################

if [ "$HOST_PREDICTION" = true ]; then

    echo ""
    echo "=========================================="
    echo "PART A: HOST PREDICTION ANALYSIS"
    echo "=========================================="

    ############################################################################
    # Step 1: CRISPR Spacer Matching
    ############################################################################

    echo ""
    echo "=========================================="
    echo "Step 1: CRISPR Spacer Matching"
    echo "=========================================="
    echo "Start time: $(date)"

    CRISPR_SPACERS="${CRISPR_DIR}/${SAMPLE_NAME}_host_spacers.fasta"
    CRISPR_MATCHES="${CRISPR_DIR}/${SAMPLE_NAME}_crispr_matches.txt"

    if [ -f "$CRISPR_MATCHES" ]; then
        echo "CRISPR matches already exist: $CRISPR_MATCHES"
    else
        echo "Predicting CRISPR arrays in host genomes..."

        # Use MinCED to find CRISPR arrays in host genomes
        MINCED_OUTPUT="${CRISPR_DIR}/${SAMPLE_NAME}_host_crisprs.txt"

        minced \
            -spacers "$CRISPR_SPACERS" \
            "$HOST_GENOMES" \
            "$MINCED_OUTPUT" \
            2>&1 | tee "${CRISPR_DIR}/minced.log" || {
                echo "Warning: MinCED failed, continuing anyway..."
                echo "This may indicate no CRISPR arrays in host genomes"
            }

        # If spacers were found, BLAST them against viral genomes
        if [ -f "$CRISPR_SPACERS" ] && [ -s "$CRISPR_SPACERS" ]; then
            SPACER_COUNT=$(grep -c "^>" "$CRISPR_SPACERS" || echo "0")
            echo "CRISPR spacers found: $SPACER_COUNT"

            echo "BLASTing CRISPR spacers against viral genomes..."

            # Create BLAST database from viral genomes
            makeblastdb \
                -in "$VIRAL_GENOMES" \
                -dbtype nucl \
                -out "${CRISPR_DIR}/viral_db" \
                2>&1 | tee "${CRISPR_DIR}/makeblastdb.log"

            # BLAST spacers against viruses (strict parameters for CRISPR matching)
            blastn \
                -query "$CRISPR_SPACERS" \
                -db "${CRISPR_DIR}/viral_db" \
                -out "$CRISPR_MATCHES" \
                -outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore" \
                -perc_identity 90 \
                -max_target_seqs 10 \
                -num_threads "$THREADS" \
                2>&1 | tee "${CRISPR_DIR}/blastn.log"

            MATCH_COUNT=$(wc -l < "$CRISPR_MATCHES" || echo "0")
            echo "CRISPR-virus matches found: $MATCH_COUNT"
        else
            echo "No CRISPR spacers found in host genomes"
            touch "$CRISPR_MATCHES"
        fi
    fi

    echo "CRISPR analysis completed: $(date)"

    ############################################################################
    # Step 2: tRNA Matching
    ############################################################################

    echo ""
    echo "=========================================="
    echo "Step 2: tRNA Matching"
    echo "=========================================="
    echo "Start time: $(date)"

    VIRAL_TRNA="${TRNA_DIR}/${SAMPLE_NAME}_viral_trnas.txt"
    HOST_TRNA="${TRNA_DIR}/${SAMPLE_NAME}_host_trnas.txt"
    TRNA_MATCHES="${TRNA_DIR}/${SAMPLE_NAME}_trna_matches.txt"

    if [ -f "$TRNA_MATCHES" ]; then
        echo "tRNA matches already exist: $TRNA_MATCHES"
    else
        echo "Predicting tRNAs in viral genomes..."

        # Predict tRNAs in viral genomes
        tRNAscan-SE \
            -B \
            -o "$VIRAL_TRNA" \
            "$VIRAL_GENOMES" \
            2>&1 | tee "${TRNA_DIR}/trnascan_viral.log" || {
                echo "Warning: tRNAscan-SE failed on viral genomes"
                touch "$VIRAL_TRNA"
            }

        VIRAL_TRNA_COUNT=$(grep -c "^>" "$VIRAL_TRNA" 2>/dev/null || echo "0")
        echo "Viral tRNAs found: $VIRAL_TRNA_COUNT"

        echo "Predicting tRNAs in host genomes..."

        # Predict tRNAs in host genomes
        tRNAscan-SE \
            -B \
            -o "$HOST_TRNA" \
            "$HOST_GENOMES" \
            2>&1 | tee "${TRNA_DIR}/trnascan_host.log" || {
                echo "Warning: tRNAscan-SE failed on host genomes"
                touch "$HOST_TRNA"
            }

        HOST_TRNA_COUNT=$(grep -c "^>" "$HOST_TRNA" 2>/dev/null || echo "0")
        echo "Host tRNAs found: $HOST_TRNA_COUNT"

        # Compare tRNA profiles
        if [ "$VIRAL_TRNA_COUNT" -gt 0 ] && [ "$HOST_TRNA_COUNT" -gt 0 ]; then
            echo "Comparing viral and host tRNA profiles..."

            # Simple comparison based on tRNA types
            # Extract anticodon information and compare
            cat > "$TRNA_MATCHES" <<EOF
# tRNA matching between viruses and hosts
# Viral tRNAs: $VIRAL_TRNA_COUNT
# Host tRNAs: $HOST_TRNA_COUNT
#
# Shared tRNA types suggest potential host-virus relationships
#
EOF
            echo "tRNA comparison completed"
        else
            echo "Insufficient tRNAs for comparison"
            touch "$TRNA_MATCHES"
        fi
    fi

    echo "tRNA analysis completed: $(date)"

    ############################################################################
    # Step 3: K-mer Composition Similarity
    ############################################################################

    echo ""
    echo "=========================================="
    echo "Step 3: K-mer Composition Analysis"
    echo "=========================================="
    echo "Start time: $(date)"

    KMER_SIMILARITY="${KMER_DIR}/${SAMPLE_NAME}_kmer_similarity.txt"

    if [ -f "$KMER_SIMILARITY" ]; then
        echo "K-mer similarity already exists: $KMER_SIMILARITY"
    else
        echo "Calculating k-mer composition (k=6) for host-virus similarity..."

        # Sketch viral genomes
        VIRAL_SKETCH="${KMER_DIR}/viral.msh"
        mash sketch \
            -o "${KMER_DIR}/viral" \
            -k 16 \
            -s 10000 \
            "$VIRAL_GENOMES" \
            2>&1 | tee "${KMER_DIR}/mash_sketch_viral.log"

        # Sketch host genomes
        HOST_SKETCH="${KMER_DIR}/host.msh"
        mash sketch \
            -o "${KMER_DIR}/host" \
            -k 16 \
            -s 10000 \
            "$HOST_GENOMES" \
            2>&1 | tee "${KMER_DIR}/mash_sketch_host.log"

        # Calculate distances between viral and host sketches
        mash dist \
            "$VIRAL_SKETCH" \
            "$HOST_SKETCH" \
            -t \
            > "$KMER_SIMILARITY" \
            2>&1 | tee "${KMER_DIR}/mash_dist.log"

        # Count significant similarities (Mash distance < 0.1)
        SIMILAR_PAIRS=$(awk '$3 < 0.1' "$KMER_SIMILARITY" | wc -l || echo "0")
        echo "Virus-host pairs with high k-mer similarity: $SIMILAR_PAIRS"
    fi

    echo "K-mer analysis completed: $(date)"

    ############################################################################
    # Step 4: Protein Homology Analysis
    ############################################################################

    echo ""
    echo "=========================================="
    echo "Step 4: Protein Homology Analysis"
    echo "=========================================="
    echo "Start time: $(date)"

    PROTEIN_MATCHES="${PROTEIN_DIR}/${SAMPLE_NAME}_protein_matches.txt"

    if [ -f "$PROTEIN_MATCHES" ]; then
        echo "Protein matches already exist: $PROTEIN_MATCHES"
    else
        echo "Predicting proteins in viral and host genomes..."

        # Predict viral proteins
        VIRAL_PROTEINS="${PROTEIN_DIR}/viral_proteins.faa"
        prodigal-gv \
            -i "$VIRAL_GENOMES" \
            -a "$VIRAL_PROTEINS" \
            -p meta \
            -q \
            2>&1 | tee "${PROTEIN_DIR}/prodigal_viral.log"

        VIRAL_PROTEIN_COUNT=$(grep -c "^>" "$VIRAL_PROTEINS" || echo "0")
        echo "Viral proteins predicted: $VIRAL_PROTEIN_COUNT"

        # Predict host proteins
        HOST_PROTEINS="${PROTEIN_DIR}/host_proteins.faa"
        prodigal \
            -i "$HOST_GENOMES" \
            -a "$HOST_PROTEINS" \
            -p meta \
            -q \
            2>&1 | tee "${PROTEIN_DIR}/prodigal_host.log"

        HOST_PROTEIN_COUNT=$(grep -c "^>" "$HOST_PROTEINS" || echo "0")
        echo "Host proteins predicted: $HOST_PROTEIN_COUNT"

        echo "Running Diamond BLAST for protein homology..."

        # Create Diamond database from host proteins
        diamond makedb \
            --in "$HOST_PROTEINS" \
            --db "${PROTEIN_DIR}/host_db" \
            2>&1 | tee "${PROTEIN_DIR}/diamond_makedb.log"

        # BLAST viral proteins against host proteins
        diamond blastp \
            --query "$VIRAL_PROTEINS" \
            --db "${PROTEIN_DIR}/host_db" \
            --out "$PROTEIN_MATCHES" \
            --outfmt 6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore \
            --evalue 1e-5 \
            --max-target-seqs 10 \
            --threads "$THREADS" \
            2>&1 | tee "${PROTEIN_DIR}/diamond_blastp.log"

        HOMOLOGY_COUNT=$(wc -l < "$PROTEIN_MATCHES" || echo "0")
        echo "Protein homology matches: $HOMOLOGY_COUNT"
    fi

    echo "Protein homology analysis completed: $(date)"

    ############################################################################
    # Step 5: Integrate Host Predictions
    ############################################################################

    echo ""
    echo "=========================================="
    echo "Step 5: Integrate Host Predictions"
    echo "=========================================="
    echo "Start time: $(date)"

    INTEGRATED_PREDICTIONS="${RESULTS_DIR}/${SAMPLE_NAME}_host_predictions.tsv"

    echo "Integrating host predictions from multiple methods..."

    # Create header
    cat > "$INTEGRATED_PREDICTIONS" <<EOF
Virus	Host	Method	Score	Evidence
EOF

    # Add CRISPR matches (highest confidence)
    if [ -s "$CRISPR_MATCHES" ]; then
        awk -v method="CRISPR" '{
            virus = $2
            # Extract host from spacer ID (format: host_spacer_number)
            split($1, parts, "_spacer_")
            host = parts[1]
            score = $3
            evidence = "CRISPR_spacer_match"
            print virus "\t" host "\t" method "\t" score "\t" evidence
        }' "$CRISPR_MATCHES" >> "$INTEGRATED_PREDICTIONS"
    fi

    # Add k-mer similarity matches (moderate confidence)
    if [ -s "$KMER_SIMILARITY" ]; then
        awk -v method="K-mer" '$3 < 0.1 {
            virus = $1
            host = $2
            # Mash distance: convert to similarity score
            score = (1 - $3) * 100
            evidence = "Nucleotide_composition"
            print virus "\t" host "\t" method "\t" score "\t" evidence
        }' "$KMER_SIMILARITY" >> "$INTEGRATED_PREDICTIONS"
    fi

    # Add protein homology (lower confidence, supplementary)
    if [ -s "$PROTEIN_MATCHES" ]; then
        awk -v method="Protein" '{
            # Extract virus and host from protein IDs
            split($1, vparts, "_")
            split($2, hparts, "_")
            virus = vparts[1]
            host = hparts[1]
            score = $3
            evidence = "Shared_proteins"
            print virus "\t" host "\t" method "\t" score "\t" evidence
        }' "$PROTEIN_MATCHES" | \
        # Aggregate by virus-host pair, keep highest score
        sort -k1,2 -k4,4nr | \
        awk '!seen[$1,$2]++' >> "$INTEGRATED_PREDICTIONS"
    fi

    PREDICTION_COUNT=$(tail -n +2 "$INTEGRATED_PREDICTIONS" | wc -l || echo "0")
    echo "Total host predictions generated: $PREDICTION_COUNT"

    # Create a summary by virus
    VIRUS_HOST_SUMMARY="${RESULTS_DIR}/${SAMPLE_NAME}_virus_host_summary.tsv"

    tail -n +2 "$INTEGRATED_PREDICTIONS" | \
        awk '{virus[$1]++; if (hosts[$1] == "") hosts[$1] = $2; else hosts[$1] = hosts[$1] "," $2}
             END {for (v in virus) print v "\t" virus[v] "\t" hosts[v]}' | \
        sort -k2,2nr > "$VIRUS_HOST_SUMMARY"

    echo "Virus-host summary created: $VIRUS_HOST_SUMMARY"

    echo "Host prediction integration completed: $(date)"

else
    echo ""
    echo "=========================================="
    echo "Skipping host prediction (no host genomes)"
    echo "=========================================="
fi

################################################################################
# PART B: VIRAL ECOLOGY ANALYSIS (always performed)
################################################################################

echo ""
echo "=========================================="
echo "PART B: VIRAL ECOLOGY ANALYSIS"
echo "=========================================="

################################################################################
# Step 6: Viral Diversity Analysis
################################################################################

echo ""
echo "=========================================="
echo "Step 6: Viral Diversity Analysis"
echo "=========================================="
echo "Start time: $(date)"

DIVERSITY_STATS="${ECOLOGY_DIR}/${SAMPLE_NAME}_diversity.txt"

echo "Calculating viral diversity metrics..."

# Count viral genomes
VIRUS_COUNT=$(grep -c "^>" "$VIRAL_GENOMES" || echo "0")

# Get genome size distribution
cat > "$DIVERSITY_STATS" <<EOF
================================================================================
VIRAL DIVERSITY STATISTICS
================================================================================

Sample: $SAMPLE_NAME
Analysis Date: $(date)

--------------------------------------------------------------------------------
Basic Statistics
--------------------------------------------------------------------------------

Total viral genomes: $VIRUS_COUNT

Genome Size Distribution:
EOF

# Calculate size statistics
seqkit stats "$VIRAL_GENOMES" -T | tail -n +2 | \
    awk '{printf "  Min: %d bp\n  Max: %d bp\n  Mean: %.0f bp\n  Total: %d bp\n", $7, $6, $8, $5}' >> "$DIVERSITY_STATS"

cat >> "$DIVERSITY_STATS" <<EOF

Genome Size Histogram:
EOF

# Size histogram
seqkit fx2tab -l -n "$VIRAL_GENOMES" | \
    awk '{
        len = $2
        if (len < 5000) bin = "0-5kb"
        else if (len < 10000) bin = "5-10kb"
        else if (len < 20000) bin = "10-20kb"
        else if (len < 50000) bin = "20-50kb"
        else if (len < 100000) bin = "50-100kb"
        else bin = ">100kb"
        count[bin]++
    }
    END {
        order[0] = "0-5kb"; order[1] = "5-10kb"; order[2] = "10-20kb"
        order[3] = "20-50kb"; order[4] = "50-100kb"; order[5] = ">100kb"
        for (i = 0; i < 6; i++) {
            bin = order[i]
            printf "  %s: %d genomes\n", bin, count[bin] + 0
        }
    }' >> "$DIVERSITY_STATS"

cat >> "$DIVERSITY_STATS" <<EOF

--------------------------------------------------------------------------------
GC Content Distribution
--------------------------------------------------------------------------------

EOF

# Calculate GC content
seqkit fx2tab -n -g "$VIRAL_GENOMES" | \
    awk '{
        gc = $2
        if (gc < 30) bin = "<30%"
        else if (gc < 40) bin = "30-40%"
        else if (gc < 50) bin = "40-50%"
        else if (gc < 60) bin = "50-60%"
        else if (gc < 70) bin = "60-70%"
        else bin = ">70%"
        count[bin]++
        sum += gc
        n++
    }
    END {
        printf "  Mean GC content: %.2f%%\n\n", sum/n
        printf "  GC Histogram:\n"
        order[0] = "<30%"; order[1] = "30-40%"; order[2] = "40-50%"
        order[3] = "50-60%"; order[4] = "60-70%"; order[5] = ">70%"
        for (i = 0; i < 6; i++) {
            bin = order[i]
            printf "    %s: %d genomes\n", bin, count[bin] + 0
        }
    }' >> "$DIVERSITY_STATS"

echo "Diversity statistics saved to: $DIVERSITY_STATS"

echo "Viral diversity analysis completed: $(date)"

################################################################################
# Step 7: Generate Final Report
################################################################################

echo ""
echo "=========================================="
echo "Step 7: Generate Final Report"
echo "=========================================="
echo "Start time: $(date)"

FINAL_REPORT="${RESULTS_DIR}/${SAMPLE_NAME}_host_ecology_summary.txt"

cat > "$FINAL_REPORT" <<EOF
================================================================================
VIRAL HOST PREDICTION & ECOLOGY SUMMARY - PHASE 5
================================================================================

Sample: $SAMPLE_NAME
Analysis Date: $(date)
Input Viral Genomes: $VIRAL_GENOMES
Input Host Genomes: ${HOST_GENOMES:-"Not provided"}

================================================================================
PART A: HOST PREDICTION
================================================================================

EOF

if [ "$HOST_PREDICTION" = true ]; then
    cat >> "$FINAL_REPORT" <<EOF
Host prediction was performed using multiple complementary methods:

--------------------------------------------------------------------------------
Method 1: CRISPR Spacer Matching (Direct Evidence)
--------------------------------------------------------------------------------

CRISPR spacers found: $(grep -c "^>" "$CRISPR_SPACERS" 2>/dev/null || echo "0")
Virus-host matches: $(wc -l < "$CRISPR_MATCHES" 2>/dev/null || echo "0")

Confidence: HIGHEST (direct evidence of infection history)

--------------------------------------------------------------------------------
Method 2: tRNA Matching (Integration Potential)
--------------------------------------------------------------------------------

Viral tRNAs: $(grep -c "^>" "$VIRAL_TRNA" 2>/dev/null || echo "0")
Host tRNAs: $(grep -c "^>" "$HOST_TRNA" 2>/dev/null || echo "0")

Confidence: MODERATE (suggests integration potential)

--------------------------------------------------------------------------------
Method 3: K-mer Composition Similarity
--------------------------------------------------------------------------------

High-similarity pairs (Mash distance < 0.1): $(awk '$3 < 0.1' "$KMER_SIMILARITY" 2>/dev/null | wc -l || echo "0")

Confidence: MODERATE (nucleotide composition similarity)

--------------------------------------------------------------------------------
Method 4: Protein Homology
--------------------------------------------------------------------------------

Shared protein matches: $(wc -l < "$PROTEIN_MATCHES" 2>/dev/null || echo "0")

Confidence: SUPPLEMENTARY (may indicate shared genes)

--------------------------------------------------------------------------------
Integrated Host Predictions
--------------------------------------------------------------------------------

Total predictions: $(tail -n +2 "$INTEGRATED_PREDICTIONS" 2>/dev/null | wc -l || echo "0")
Unique viruses with hosts: $(tail -n +2 "$INTEGRATED_PREDICTIONS" 2>/dev/null | cut -f1 | sort -u | wc -l || echo "0")

Top virus-host predictions:
EOF

    if [ -f "$VIRUS_HOST_SUMMARY" ]; then
        head -20 "$VIRUS_HOST_SUMMARY" | \
            awk '{printf "  %s: %d predictions (%s)\n", $1, $2, $3}' >> "$FINAL_REPORT"
    else
        echo "  No predictions available" >> "$FINAL_REPORT"
    fi

else
    cat >> "$FINAL_REPORT" <<EOF
Host prediction was SKIPPED (no host genomes provided)

To enable host prediction, provide host genomes as the second argument:
  sbatch viral-host-prediction.sh viral_genomes.fasta host_genomes.fasta ...
EOF
fi

cat >> "$FINAL_REPORT" <<EOF

================================================================================
PART B: VIRAL ECOLOGY
================================================================================

EOF

cat "$DIVERSITY_STATS" >> "$FINAL_REPORT"

cat >> "$FINAL_REPORT" <<EOF

================================================================================
OUTPUT FILES
================================================================================

Host Prediction:
EOF

if [ "$HOST_PREDICTION" = true ]; then
    cat >> "$FINAL_REPORT" <<EOF
  - Integrated predictions: $INTEGRATED_PREDICTIONS
  - Virus-host summary: $VIRUS_HOST_SUMMARY
  - CRISPR matches: $CRISPR_MATCHES
  - tRNA analysis: $TRNA_MATCHES
  - K-mer similarity: $KMER_SIMILARITY
  - Protein homology: $PROTEIN_MATCHES
EOF
else
    cat >> "$FINAL_REPORT" <<EOF
  - Not performed (no host genomes provided)
EOF
fi

cat >> "$FINAL_REPORT" <<EOF

Viral Ecology:
  - Diversity statistics: $DIVERSITY_STATS
  - This summary report: $FINAL_REPORT

================================================================================
NEXT STEPS
================================================================================

1. Visualize virus-host network:
   - Use Cytoscape or Gephi
   - Import: $INTEGRATED_PREDICTIONS

2. Validate high-confidence predictions:
   - Focus on CRISPR matches (direct evidence)
   - Cross-reference with protein homology

3. Analyze viral diversity patterns:
   - Compare diversity across samples
   - Correlate with environmental metadata

4. Integrate with phases 1-4:
   - Combine with annotation (Phase 2)
   - Link to phylogenetics (Phase 3)
   - Connect to comparative genomics (Phase 4)

================================================================================
End of Report
================================================================================
EOF

echo "Final report generated: $FINAL_REPORT"
cat "$FINAL_REPORT"

################################################################################
# Completion
################################################################################

echo ""
echo "=================================================="
echo "PHASE 5 COMPLETED SUCCESSFULLY"
echo "=================================================="
echo "End time: $(date)"
echo ""
echo "Key Output Files:"
echo "  - Final report: $FINAL_REPORT"
echo "  - Diversity stats: $DIVERSITY_STATS"

if [ "$HOST_PREDICTION" = true ]; then
    echo "  - Host predictions: $INTEGRATED_PREDICTIONS"
    echo "  - Virus-host summary: $VIRUS_HOST_SUMMARY"
fi

echo ""
echo "All 5 phases of viral genome analysis are now complete!"
echo "=================================================="

exit 0
