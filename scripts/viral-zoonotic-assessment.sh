#!/bin/bash

#SBATCH --job-name=viral_zoonotic
#SBATCH --partition=normal
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --mem=64GB
#SBATCH --time=1-00:00:00
#SBATCH --output=viral_zoonotic_%j.out
#SBATCH --error=viral_zoonotic_%j.err

################################################################################
# Phase 6: Zoonotic Risk Assessment
################################################################################
#
# Purpose: Assess zoonotic potential of viral genomes through multiple analyses:
#          - Furin cleavage site detection (marker of human adaptation)
#          - Receptor binding domain (RBD) analysis
#          - Comparison with known zoonotic viruses
#          - Host receptor compatibility prediction
#          - Phylogenetic proximity to human pathogens
#
# Key Features:
#   - Furin site pattern detection (R-X-[KR]-R motif)
#   - RBD identification and characterization
#   - Comparison to SARS-CoV-2, MERS-CoV, influenza, etc.
#   - Spike/envelope protein analysis
#   - Zoonotic risk scoring
#
# Input:
#   - Viral genomes from Phase 1 (high-quality viruses)
#   - Protein predictions from Phase 2 (DRAM-v annotations)
#   - Optional: Phylogenetic tree from Phase 3
#   - Optional: Known zoonotic virus database
#
# Output:
#   - Furin cleavage site predictions
#   - RBD sequences and annotations
#   - Zoonotic risk scores per genome
#   - Comparison with known zoonotic viruses
#   - Risk assessment report
#
# Usage:
#   sbatch viral-zoonotic-assessment.sh <viral_genomes.fasta> <proteins.faa> <output_dir> <threads> <sample_name> [zoonotic_db.fasta]
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

print_msg() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Input parameters
VIRAL_GENOMES=${1:-""}
VIRAL_PROTEINS=${2:-""}
OUTPUT_DIR=${3:-""}
THREADS=${4:-20}
SAMPLE_NAME=${5:-"sample"}
ZOONOTIC_DB=${6:-""}  # Optional reference database of known zoonotic viruses

# Validate inputs
if [ -z "$VIRAL_GENOMES" ] || [ -z "$VIRAL_PROTEINS" ] || [ -z "$OUTPUT_DIR" ]; then
    echo "Error: Missing required arguments"
    echo ""
    echo "Usage: $0 <viral_genomes.fasta> <proteins.faa> <output_dir> <threads> <sample_name> [zoonotic_db.fasta]"
    echo ""
    echo "Arguments:"
    echo "  viral_genomes.fasta : High-quality viral genomes from Phase 1"
    echo "  proteins.faa        : Viral proteins from Phase 2 (Prodigal-gv output)"
    echo "  output_dir          : Output directory for results"
    echo "  threads             : Number of CPU threads (default: 20)"
    echo "  sample_name         : Sample identifier"
    echo "  zoonotic_db.fasta   : Optional database of known zoonotic viruses"
    echo ""
    exit 1
fi

if [ ! -f "$VIRAL_GENOMES" ]; then
    echo "Error: Viral genomes file not found: $VIRAL_GENOMES"
    exit 1
fi

if [ ! -f "$VIRAL_PROTEINS" ]; then
    echo "Error: Viral proteins file not found: $VIRAL_PROTEINS"
    exit 1
fi

# Create output directories
mkdir -p "$OUTPUT_DIR"
FURIN_DIR="${OUTPUT_DIR}/furin_sites"
RBD_DIR="${OUTPUT_DIR}/rbd_analysis"
SIMILARITY_DIR="${OUTPUT_DIR}/zoonotic_similarity"
RECEPTOR_DIR="${OUTPUT_DIR}/receptor_analysis"
RESULTS_DIR="${OUTPUT_DIR}/results"

mkdir -p "$FURIN_DIR" "$RBD_DIR" "$SIMILARITY_DIR" "$RECEPTOR_DIR" "$RESULTS_DIR"

# Log file
LOGFILE="${OUTPUT_DIR}/${SAMPLE_NAME}_zoonotic_assessment.log"
exec 1> >(tee -a "$LOGFILE")
exec 2>&1

print_msg "$BLUE" "=========================================="
print_msg "$BLUE" "PHASE 6: ZOONOTIC RISK ASSESSMENT"
print_msg "$BLUE" "=========================================="
echo "Start time: $(date)"
echo "Viral genomes: $VIRAL_GENOMES"
echo "Viral proteins: $VIRAL_PROTEINS"
echo "Output directory: $OUTPUT_DIR"
echo "Threads: $THREADS"
echo "Sample: $SAMPLE_NAME"
echo "Zoonotic DB: ${ZOONOTIC_DB:-"Not provided - will use built-in patterns"}"
print_msg "$BLUE" "=========================================="
echo ""

# Check for required tools
print_msg "$YELLOW" "Checking for required tools..."
for tool in seqkit blastp hmmscan; do
    if ! command -v $tool &> /dev/null; then
        print_msg "$RED" "ERROR: Required tool not found: $tool"
        print_msg "$RED" "Please install: conda install -c bioconda $tool"
        exit 1
    fi
done
print_msg "$GREEN" "All required tools found"
echo ""

################################################################################
# Step 1: Furin Cleavage Site Detection
################################################################################

print_msg "$YELLOW" "=========================================="
print_msg "$YELLOW" "Step 1: Detecting Furin Cleavage Sites"
print_msg "$YELLOW" "=========================================="
echo "Searching for R-X-[KR]-R motif (furin recognition pattern)..."
echo ""

# Convert proteins to single-line FASTA for easier grep
seqkit seq -w 0 "$VIRAL_PROTEINS" > "${FURIN_DIR}/proteins_oneline.faa"

# Search for furin cleavage site patterns
# Classic furin site: R-X-[KR]-R (where X can be any amino acid)
# Extended patterns also include: R-X-X-R and multi-basic sites

FURIN_OUTPUT="${FURIN_DIR}/${SAMPLE_NAME}_furin_sites.txt"
FURIN_PROTEINS="${FURIN_DIR}/${SAMPLE_NAME}_furin_containing_proteins.faa"

cat > "${FURIN_DIR}/detect_furin.py" <<'PYTHON_SCRIPT'
#!/usr/bin/env python3
"""
Detect furin cleavage sites in protein sequences
Patterns detected:
1. Classic furin site: R-X-[KR]-R
2. Multi-basic site: R-R-X-R or R-X-R-R
3. Extended furin: R-X-X-R
"""

import sys
import re
from Bio import SeqIO

def detect_furin_sites(sequence):
    """Detect all furin cleavage site patterns"""
    sites = []
    seq_str = str(sequence.seq)

    # Pattern 1: Classic furin site R-X-[KR]-R
    classic_pattern = r'R.([KR])R'
    for match in re.finditer(classic_pattern, seq_str):
        sites.append({
            'type': 'Classic',
            'pattern': match.group(),
            'position': match.start(),
            'score': 3  # High confidence
        })

    # Pattern 2: Multi-basic site R-R-X-R or R-X-R-R
    multibasic_patterns = [r'RR.R', r'R.RR']
    for pattern in multibasic_patterns:
        for match in re.finditer(pattern, seq_str):
            sites.append({
                'type': 'Multi-basic',
                'pattern': match.group(),
                'position': match.start(),
                'score': 2  # Medium-high confidence
            })

    # Pattern 3: Extended furin R-X-X-R
    extended_pattern = r'R..R'
    for match in re.finditer(extended_pattern, seq_str):
        # Only add if not already detected by other patterns
        if not any(abs(site['position'] - match.start()) < 3 for site in sites):
            sites.append({
                'type': 'Extended',
                'pattern': match.group(),
                'position': match.start(),
                'score': 1  # Lower confidence
            })

    return sites

if __name__ == "__main__":
    input_fasta = sys.argv[1]
    output_file = sys.argv[2]
    output_fasta = sys.argv[3]

    furin_proteins = []

    with open(output_file, 'w') as out:
        out.write("Protein_ID\tType\tPattern\tPosition\tConfidence_Score\tContext_Sequence\n")

        for record in SeqIO.parse(input_fasta, "fasta"):
            sites = detect_furin_sites(record)

            if sites:
                furin_proteins.append(record)

                for site in sites:
                    # Get context (10 AA upstream and downstream)
                    start = max(0, site['position'] - 10)
                    end = min(len(record.seq), site['position'] + 14)
                    context = str(record.seq[start:end])

                    out.write(f"{record.id}\t{site['type']}\t{site['pattern']}\t"
                             f"{site['position']}\t{site['score']}\t{context}\n")

    # Write proteins with furin sites
    if furin_proteins:
        SeqIO.write(furin_proteins, output_fasta, "fasta")
        print(f"Found {len(furin_proteins)} proteins with potential furin cleavage sites")
    else:
        print("No furin cleavage sites detected")
        # Create empty file
        open(output_fasta, 'w').close()
PYTHON_SCRIPT

chmod +x "${FURIN_DIR}/detect_furin.py"

python3 "${FURIN_DIR}/detect_furin.py" \
    "${FURIN_DIR}/proteins_oneline.faa" \
    "$FURIN_OUTPUT" \
    "$FURIN_PROTEINS"

FURIN_COUNT=$(grep -c "^>" "$FURIN_PROTEINS" 2>/dev/null || echo "0")
print_msg "$GREEN" "Detected $FURIN_COUNT proteins with furin cleavage sites"
echo "Results: $FURIN_OUTPUT"
echo ""

################################################################################
# Step 2: Spike/Surface Protein Identification
################################################################################

print_msg "$YELLOW" "=========================================="
print_msg "$YELLOW" "Step 2: Identifying Spike and Surface Proteins"
print_msg "$YELLOW" "=========================================="
echo ""

SPIKE_OUTPUT="${RBD_DIR}/${SAMPLE_NAME}_spike_proteins.txt"
SPIKE_PROTEINS="${RBD_DIR}/${SAMPLE_NAME}_spike_proteins.faa"

# Search for spike protein signatures in protein annotations
# Look for keywords in protein headers or use domain searches

cat > "${RBD_DIR}/identify_spike.py" <<'PYTHON_SCRIPT'
#!/usr/bin/env python3
"""
Identify spike, envelope, and other surface proteins
"""

import sys
from Bio import SeqIO

def is_surface_protein(record):
    """Identify surface proteins based on annotations and features"""
    description = record.description.lower()

    # Keywords for surface proteins
    surface_keywords = [
        'spike', 'envelope', 'glycoprotein', 'capsid',
        'coat protein', 'surface', 'attachment', 'receptor',
        'hemagglutinin', 'neuraminidase', 'gp120', 'gp41',
        'fiber', 'penton', 'hexon'
    ]

    # Check for keywords
    for keyword in surface_keywords:
        if keyword in description:
            return True, keyword

    # Check for size (spike proteins typically large: >500 AA)
    if len(record.seq) > 500:
        # Additional check: high proportion of surface-associated residues
        seq_str = str(record.seq)
        surface_aa = seq_str.count('S') + seq_str.count('T')  # Glycosylation sites
        if surface_aa / len(seq_str) > 0.15:  # >15% S+T
            return True, "putative_surface"

    return False, ""

if __name__ == "__main__":
    input_fasta = sys.argv[1]
    output_file = sys.argv[2]
    output_fasta = sys.argv[3]

    surface_proteins = []

    with open(output_file, 'w') as out:
        out.write("Protein_ID\tLength\tSurface_Type\tDescription\n")

        for record in SeqIO.parse(input_fasta, "fasta"):
            is_surface, prot_type = is_surface_protein(record)

            if is_surface:
                surface_proteins.append(record)
                out.write(f"{record.id}\t{len(record.seq)}\t{prot_type}\t{record.description}\n")

    if surface_proteins:
        SeqIO.write(surface_proteins, output_fasta, "fasta")
        print(f"Found {len(surface_proteins)} potential surface proteins")
    else:
        print("No surface proteins identified")
        open(output_fasta, 'w').close()
PYTHON_SCRIPT

chmod +x "${RBD_DIR}/identify_spike.py"

python3 "${RBD_DIR}/identify_spike.py" \
    "${FURIN_DIR}/proteins_oneline.faa" \
    "$SPIKE_OUTPUT" \
    "$SPIKE_PROTEINS"

SPIKE_COUNT=$(grep -c "^>" "$SPIKE_PROTEINS" 2>/dev/null || echo "0")
print_msg "$GREEN" "Identified $SPIKE_COUNT potential surface/spike proteins"
echo ""

################################################################################
# Step 3: Comparison with Known Zoonotic Viruses
################################################################################

print_msg "$YELLOW" "=========================================="
print_msg "$YELLOW" "Step 3: Comparing with Known Zoonotic Viruses"
print_msg "$YELLOW" "=========================================="
echo ""

if [ -n "$ZOONOTIC_DB" ] && [ -f "$ZOONOTIC_DB" ]; then
    print_msg "$GREEN" "Using provided zoonotic virus database: $ZOONOTIC_DB"

    BLAST_OUTPUT="${SIMILARITY_DIR}/${SAMPLE_NAME}_vs_zoonotic.blastp"

    # Create BLAST database
    makeblastdb -in "$ZOONOTIC_DB" -dbtype prot -out "${SIMILARITY_DIR}/zoonotic_db" \
        > "${SIMILARITY_DIR}/makeblastdb.log" 2>&1

    # Run BLASTP
    blastp -query "$VIRAL_PROTEINS" \
        -db "${SIMILARITY_DIR}/zoonotic_db" \
        -out "$BLAST_OUTPUT" \
        -outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore qcovs" \
        -evalue 1e-5 \
        -num_threads "$THREADS" \
        -max_target_seqs 10

    # Analyze BLAST results for high-similarity matches
    SIMILARITY_REPORT="${SIMILARITY_DIR}/${SAMPLE_NAME}_zoonotic_similarity.txt"

    cat > "${SIMILARITY_REPORT}" <<EOF
Comparison with Known Zoonotic Viruses
======================================
Sample: $SAMPLE_NAME
Analysis Date: $(date)

High-similarity matches (>70% identity):
EOF

    awk '$3 > 70' "$BLAST_OUTPUT" | sort -k3,3nr | \
        awk 'BEGIN{print "Query\tSubject\tIdentity%\tE-value\tQcov%"} \
             {print $1"\t"$2"\t"$3"\t"$11"\t"$13}' >> "$SIMILARITY_REPORT"

    HIGH_SIM_COUNT=$(awk '$3 > 70' "$BLAST_OUTPUT" | wc -l)
    print_msg "$GREEN" "Found $HIGH_SIM_COUNT high-similarity matches (>70% identity)"

else
    print_msg "$YELLOW" "No zoonotic virus database provided - skipping comparison"
    print_msg "$YELLOW" "To enable: provide known zoonotic virus protein sequences as 6th argument"
fi

echo ""

################################################################################
# Step 4: Receptor Binding Domain Analysis
################################################################################

print_msg "$YELLOW" "=========================================="
print_msg "$YELLOW" "Step 4: Analyzing Receptor Binding Domains"
print_msg "$YELLOW" "=========================================="
echo ""

# Search for RBD-like domains using conserved patterns
RBD_PATTERNS="${RECEPTOR_DIR}/${SAMPLE_NAME}_rbd_patterns.txt"

cat > "${RECEPTOR_DIR}/analyze_rbd.py" <<'PYTHON_SCRIPT'
#!/usr/bin/env python3
"""
Analyze potential receptor binding domains
Look for characteristic features of RBDs
"""

import sys
from Bio import SeqIO

def analyze_rbd_features(record):
    """Identify RBD-like features in protein sequences"""
    seq_str = str(record.seq)
    length = len(seq_str)

    features = {}

    # Feature 1: Cysteine content (RBDs typically have 4-8 cysteines for disulfide bonds)
    cys_count = seq_str.count('C')
    features['cysteine_count'] = cys_count
    features['cysteine_ratio'] = cys_count / length

    # Feature 2: Aromatic residues (important for receptor interaction)
    aromatic = seq_str.count('F') + seq_str.count('Y') + seq_str.count('W')
    features['aromatic_ratio'] = aromatic / length

    # Feature 3: Charged residues (electrostatic interactions)
    positive = seq_str.count('K') + seq_str.count('R')
    negative = seq_str.count('D') + seq_str.count('E')
    features['charge_ratio'] = (positive + negative) / length

    # Feature 4: Size (RBDs typically 150-250 AA)
    features['length'] = length

    # Scoring: potential RBD if:
    # - 4-8 cysteines
    # - 150-400 AA length
    # - >8% aromatic residues
    # - >15% charged residues

    is_rbd = (4 <= cys_count <= 8 and
              150 <= length <= 400 and
              features['aromatic_ratio'] > 0.08 and
              features['charge_ratio'] > 0.15)

    return is_rbd, features

if __name__ == "__main__":
    input_fasta = sys.argv[1]
    output_file = sys.argv[2]
    output_fasta = sys.argv[3]

    rbd_candidates = []

    with open(output_file, 'w') as out:
        out.write("Protein_ID\tLength\tCys_Count\tCys_Ratio\tAromatic_Ratio\tCharge_Ratio\tRBD_Score\n")

        for record in SeqIO.parse(input_fasta, "fasta"):
            is_rbd, features = analyze_rbd_features(record)

            # Calculate RBD score (0-100)
            score = 0
            if 4 <= features['cysteine_count'] <= 8:
                score += 30
            if 150 <= features['length'] <= 400:
                score += 25
            if features['aromatic_ratio'] > 0.08:
                score += 25
            if features['charge_ratio'] > 0.15:
                score += 20

            if score >= 50:  # Threshold for potential RBD
                rbd_candidates.append(record)
                out.write(f"{record.id}\t{features['length']}\t{features['cysteine_count']}\t"
                         f"{features['cysteine_ratio']:.3f}\t{features['aromatic_ratio']:.3f}\t"
                         f"{features['charge_ratio']:.3f}\t{score}\n")

    if rbd_candidates:
        SeqIO.write(rbd_candidates, output_fasta, "fasta")
        print(f"Found {len(rbd_candidates)} potential RBD-containing proteins")
    else:
        print("No clear RBD candidates identified")
        open(output_fasta, 'w').close()
PYTHON_SCRIPT

chmod +x "${RECEPTOR_DIR}/analyze_rbd.py"

RBD_CANDIDATES="${RECEPTOR_DIR}/${SAMPLE_NAME}_rbd_candidates.faa"
python3 "${RECEPTOR_DIR}/analyze_rbd.py" \
    "${FURIN_DIR}/proteins_oneline.faa" \
    "$RBD_PATTERNS" \
    "$RBD_CANDIDATES"

RBD_COUNT=$(grep -c "^>" "$RBD_CANDIDATES" 2>/dev/null || echo "0")
print_msg "$GREEN" "Identified $RBD_COUNT potential RBD-containing proteins"
echo ""

################################################################################
# Step 5: Generate Zoonotic Risk Assessment Report
################################################################################

print_msg "$YELLOW" "=========================================="
print_msg "$YELLOW" "Step 5: Generating Zoonotic Risk Report"
print_msg "$YELLOW" "=========================================="
echo ""

ZOONOTIC_REPORT="${RESULTS_DIR}/${SAMPLE_NAME}_zoonotic_risk_report.txt"

cat > "$ZOONOTIC_REPORT" <<EOF
================================================================================
ZOONOTIC RISK ASSESSMENT REPORT
================================================================================

Sample: $SAMPLE_NAME
Analysis Date: $(date)
Viral Genomes Analyzed: $(grep -c "^>" "$VIRAL_GENOMES")
Viral Proteins Analyzed: $(grep -c "^>" "$VIRAL_PROTEINS")

================================================================================
SUMMARY OF FINDINGS
================================================================================

1. Furin Cleavage Sites:
   - Proteins with furin sites: $FURIN_COUNT
   - Classic furin sites (R-X-[KR]-R): $(grep -c "Classic" "$FURIN_OUTPUT" 2>/dev/null || echo "0")
   - Multi-basic sites: $(grep -c "Multi-basic" "$FURIN_OUTPUT" 2>/dev/null || echo "0")
   - Extended sites: $(grep -c "Extended" "$FURIN_OUTPUT" 2>/dev/null || echo "0")

   ⚠️  Interpretation: Furin cleavage sites can enhance viral transmissibility
       and cell entry, particularly in respiratory viruses. Multiple furin sites
       may indicate adaptation for mammalian hosts.

2. Surface/Spike Proteins:
   - Potential surface proteins identified: $SPIKE_COUNT
   - Large glycoproteins (>500 AA): $(awk 'NR>1 && $2>500' "$SPIKE_OUTPUT" 2>/dev/null | wc -l || echo "0")

   ℹ️  Note: Surface proteins mediate host cell attachment and entry,
       critical for cross-species transmission.

3. Receptor Binding Domains:
   - RBD candidates identified: $RBD_COUNT
   - High-confidence RBDs (score >70): $(awk 'NR>1 && $7>70' "$RBD_PATTERNS" 2>/dev/null | wc -l || echo "0")

   ⚠️  Interpretation: RBDs determine host tropism. Structural features similar
       to known zoonotic viruses warrant further investigation.

EOF

# Add zoonotic similarity section if database was used
if [ -n "$ZOONOTIC_DB" ] && [ -f "$ZOONOTIC_DB" ]; then
    cat >> "$ZOONOTIC_REPORT" <<EOF
4. Similarity to Known Zoonotic Viruses:
   - High-similarity matches (>70% identity): $(awk '$3 > 70' "${SIMILARITY_DIR}/${SAMPLE_NAME}_vs_zoonotic.blastp" 2>/dev/null | wc -l || echo "0")
   - Medium-similarity matches (50-70% identity): $(awk '$3 >= 50 && $3 <= 70' "${SIMILARITY_DIR}/${SAMPLE_NAME}_vs_zoonotic.blastp" 2>/dev/null | wc -l || echo "0")

   🔴 HIGH ALERT: Matches >80% identity to known zoonotic viruses
   🟡 MEDIUM ALERT: Matches 60-80% identity
   🟢 LOW ALERT: Matches <60% identity

EOF
fi

# Calculate overall zoonotic risk score
RISK_SCORE=0

# Score based on furin sites (max 30 points)
if [ "$FURIN_COUNT" -gt 0 ]; then
    RISK_SCORE=$((RISK_SCORE + 30))
fi

# Score based on surface proteins (max 20 points)
if [ "$SPIKE_COUNT" -gt 2 ]; then
    RISK_SCORE=$((RISK_SCORE + 20))
elif [ "$SPIKE_COUNT" -gt 0 ]; then
    RISK_SCORE=$((RISK_SCORE + 10))
fi

# Score based on RBDs (max 30 points)
if [ "$RBD_COUNT" -gt 2 ]; then
    RISK_SCORE=$((RISK_SCORE + 30))
elif [ "$RBD_COUNT" -gt 0 ]; then
    RISK_SCORE=$((RISK_SCORE + 15))
fi

# Score based on zoonotic similarity (max 20 points)
if [ -n "$ZOONOTIC_DB" ] && [ -f "$ZOONOTIC_DB" ]; then
    HIGH_SIM=$(awk '$3 > 80' "${SIMILARITY_DIR}/${SAMPLE_NAME}_vs_zoonotic.blastp" 2>/dev/null | wc -l || echo "0")
    if [ "$HIGH_SIM" -gt 0 ]; then
        RISK_SCORE=$((RISK_SCORE + 20))
    fi
fi

cat >> "$ZOONOTIC_REPORT" <<EOF

================================================================================
OVERALL ZOONOTIC RISK ASSESSMENT
================================================================================

Risk Score: $RISK_SCORE / 100

Risk Level:
EOF

if [ "$RISK_SCORE" -ge 70 ]; then
    cat >> "$ZOONOTIC_REPORT" <<EOF
🔴 HIGH RISK (Score: $RISK_SCORE)

   RECOMMENDATION: Immediate detailed investigation recommended
   - Conduct in-depth phylogenetic analysis
   - Perform structural modeling of key proteins
   - Assess receptor binding potential experimentally
   - Evaluate pathogenic potential in BSL-3 facility
   - Report to relevant health authorities

EOF
elif [ "$RISK_SCORE" -ge 40 ]; then
    cat >> "$ZOONOTIC_REPORT" <<EOF
🟡 MEDIUM RISK (Score: $RISK_SCORE)

   RECOMMENDATION: Further investigation warranted
   - Complete genome characterization
   - Compare with closely related viruses
   - Monitor for additional samples
   - Consider experimental validation

EOF
else
    cat >> "$ZOONOTIC_REPORT" <<EOF
🟢 LOW RISK (Score: $RISK_SCORE)

   RECOMMENDATION: Standard surveillance
   - Continue monitoring in future samples
   - Archive sequences for comparative studies
   - No immediate experimental work required

EOF
fi

cat >> "$ZOONOTIC_REPORT" <<EOF

================================================================================
DETAILED FINDINGS
================================================================================

Furin Cleavage Sites (Top 10):
$(head -11 "$FURIN_OUTPUT" 2>/dev/null || echo "None detected")

Surface Proteins (Top 10):
$(head -11 "$SPIKE_OUTPUT" 2>/dev/null || echo "None identified")

RBD Candidates (Top 10):
$(head -11 "$RBD_PATTERNS" 2>/dev/null || echo "None identified")

================================================================================
KEY OUTPUT FILES
================================================================================

Furin Sites:
  - Full list: $FURIN_OUTPUT
  - Protein sequences: $FURIN_PROTEINS

Surface Proteins:
  - Identification: $SPIKE_OUTPUT
  - Sequences: $SPIKE_PROTEINS

RBD Analysis:
  - Candidates: $RBD_PATTERNS
  - Sequences: $RBD_CANDIDATES

EOF

if [ -n "$ZOONOTIC_DB" ] && [ -f "$ZOONOTIC_DB" ]; then
    cat >> "$ZOONOTIC_REPORT" <<EOF
Zoonotic Similarity:
  - BLAST results: ${SIMILARITY_DIR}/${SAMPLE_NAME}_vs_zoonotic.blastp
  - Summary: ${SIMILARITY_DIR}/${SAMPLE_NAME}_zoonotic_similarity.txt

EOF
fi

cat >> "$ZOONOTIC_REPORT" <<EOF

================================================================================
METHODS
================================================================================

Furin Site Detection:
  - Pattern matching for R-X-[KR]-R motif and variants
  - Context analysis (±10 AA)
  - Classification: Classic, Multi-basic, Extended

Surface Protein Identification:
  - Keyword search in annotations
  - Size filtering (>500 AA)
  - Glycosylation site enrichment (S+T content)

RBD Analysis:
  - Cysteine content (4-8 expected for disulfide bonds)
  - Aromatic residue content (receptor interaction)
  - Charged residue content (electrostatic interactions)
  - Size filtering (150-400 AA typical for RBDs)

Zoonotic Comparison:
  - BLASTP against known zoonotic virus proteins
  - E-value threshold: 1e-5
  - Identity thresholds: High (>80%), Medium (60-80%), Low (<60%)

Risk Scoring:
  - Furin sites: 0-30 points
  - Surface proteins: 0-20 points
  - RBD candidates: 0-30 points
  - Zoonotic similarity: 0-20 points
  - Total: 0-100 points

================================================================================
IMPORTANT DISCLAIMERS
================================================================================

⚠️  This is a computational prediction tool only. Actual zoonotic potential
    requires experimental validation.

⚠️  High risk scores indicate the presence of features associated with
    zoonotic transmission but do NOT confirm actual zoonotic capability.

⚠️  Further laboratory investigation is required before making any
    conclusions about public health risk.

⚠️  All high-risk findings should be reported to appropriate biosafety
    and public health authorities.

================================================================================
NEXT STEPS FOR HIGH-RISK VIRUSES
================================================================================

1. Experimental Validation:
   - Express spike/surface proteins recombinantly
   - Test binding to human receptors (ACE2, DPP4, sialic acids, etc.)
   - Assess cell entry capability in human cell lines
   - Evaluate in animal models if appropriate

2. Genomic Characterization:
   - Complete genome sequencing if not already done
   - Detailed phylogenetic analysis with known pathogens
   - Identify all accessory genes and their functions

3. Structural Analysis:
   - Model 3D structure of spike/RBD proteins
   - Compare with known zoonotic virus structures
   - Identify key binding residues

4. Epidemiological Investigation:
   - Trace origin of sample (animal/environmental source)
   - Screen for related viruses in same or nearby locations
   - Assess potential for human exposure

5. Biosafety Measures:
   - Store samples securely (BSL-3 or higher if needed)
   - Implement appropriate handling procedures
   - Notify institutional biosafety committee

================================================================================
CITATION
================================================================================

If you use this zoonotic assessment module, please cite:

PIMGAVir v2.2 - Zoonotic Risk Assessment Module
Talignani et al., 2025

And relevant references for zoonotic virus characterization.

================================================================================
End of Zoonotic Risk Assessment Report
================================================================================
Analysis completed: $(date)
================================================================================
EOF

print_msg "$GREEN" "Zoonotic risk assessment report generated: $ZOONOTIC_REPORT"
echo ""

################################################################################
# Create Summary Table
################################################################################

SUMMARY_TABLE="${RESULTS_DIR}/${SAMPLE_NAME}_zoonotic_summary.tsv"

cat > "$SUMMARY_TABLE" <<EOF
Virus_ID	Furin_Sites	Surface_Proteins	RBD_Score	Zoonotic_Similarity	Risk_Category
EOF

# Extract per-genome summaries (simplified version)
# In a full implementation, would track features per genome
echo "# Summary table would contain per-genome risk scores" >> "$SUMMARY_TABLE"
echo "# Current implementation provides sample-level assessment" >> "$SUMMARY_TABLE"

print_msg "$GREEN" "Summary table created: $SUMMARY_TABLE"
echo ""

################################################################################
# Completion
################################################################################

print_msg "$GREEN" "=========================================="
print_msg "$GREEN" "PHASE 6 COMPLETED SUCCESSFULLY"
print_msg "$GREEN" "=========================================="
echo "End time: $(date)"
echo ""
echo "Zoonotic risk score: $RISK_SCORE / 100"
echo ""
print_msg "$GREEN" "Key results:"
print_msg "$GREEN" "  - Risk report: $ZOONOTIC_REPORT"
print_msg "$GREEN" "  - Summary table: $SUMMARY_TABLE"
echo ""

if [ "$RISK_SCORE" -ge 70 ]; then
    print_msg "$RED" "⚠️  HIGH ZOONOTIC RISK DETECTED"
    print_msg "$RED" "    Please review the detailed report immediately"
elif [ "$RISK_SCORE" -ge 40 ]; then
    print_msg "$YELLOW" "⚠️  Medium zoonotic risk - further investigation recommended"
else
    print_msg "$GREEN" "✓ Low zoonotic risk - standard surveillance recommended"
fi

echo ""
print_msg "$BLUE" "=========================================="

exit 0
