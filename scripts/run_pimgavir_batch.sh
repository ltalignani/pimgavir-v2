#!/bin/bash

################################################################################
# PIMGAVir - Batch Launcher with Configurable SLURM Resources
#
# Purpose: Launch PIMGAVir pipeline for multiple samples using SLURM arrays
#
# Usage:
#   bash run_pimgavir_batch.sh INPUT_DIR METHOD [OPTIONS]
#
# Arguments:
#   INPUT_DIR     : Directory containing paired-end FASTQ files
#   METHOD        : ALL, --read_based, --ass_based, or --clust_based
#
# Options:
#   --threads N       : Number of CPU threads per sample (default: 40)
#   --mem N[G|M]      : Memory per sample (default: 128GB)
#   --time D-HH:MM:SS : Time limit per sample (default: 3-23:59:59)
#   --partition NAME  : SLURM partition (default: normal)
#   --filter          : Enable host/contaminant filtering
#   --infiniband      : Use Infiniband scratch (IRD cluster)
#   --email EMAIL     : Email for notifications
#   --mail-type TYPE  : Notification type (default: END,FAIL)
#   --array-limit N   : Max concurrent jobs (default: 4)
#
# File Naming Convention:
#   Files must be named: *_R1*.fastq.gz and *_R2*.fastq.gz
#   or: *_1.fastq.gz and *_2.fastq.gz
#
# Examples:
#   # Process all samples with default resources
#   bash run_pimgavir_batch.sh /data/fastq/ ALL
#
#   # Assembly-only with high memory for 10 samples
#   bash run_pimgavir_batch.sh /data/fastq/ --ass_based --mem 256GB --array-limit 2
#
#   # Full pipeline with filtering on Infiniband
#   bash run_pimgavir_batch.sh /data/fastq/ ALL --filter --infiniband --mem 256GB
#
# Version: 2.2.1 - 2025-11-04
################################################################################

set -e
set -u

################################################################################
# Default Values
################################################################################
DEFAULT_THREADS=20
DEFAULT_MEM="128GB"
DEFAULT_TIME="3-23:59:59"
DEFAULT_PARTITION="normal"
DEFAULT_MAIL_TYPE="END,FAIL"
DEFAULT_EMAIL=""
DEFAULT_ARRAY_LIMIT=4

################################################################################
# Help Message
################################################################################
show_help() {
    cat << EOF
PIMGAVir - Batch Launcher with Configurable Resources

USAGE:
    bash run_pimgavir_batch.sh INPUT_DIR METHOD [OPTIONS]

REQUIRED ARGUMENTS:
    INPUT_DIR          Directory containing paired FASTQ files
    METHOD             Analysis method (ALL, --read_based, --ass_based, --clust_based)

OPTIONS:
    --threads N        CPU threads per sample (default: $DEFAULT_THREADS)
    --mem N[G|M]       Memory per sample (default: $DEFAULT_MEM)
    --time D-HH:MM:SS  Time limit per sample (default: $DEFAULT_TIME)
    --partition NAME   SLURM partition (default: $DEFAULT_PARTITION)
    --filter           Enable host/contaminant filtering
    --infiniband       Use Infiniband scratch (IRD cluster)
    --email EMAIL      Email for job notifications
    --mail-type TYPE   Notification type (default: $DEFAULT_MAIL_TYPE)
    --array-limit N    Max concurrent jobs (default: $DEFAULT_ARRAY_LIMIT)
    -h, --help         Show this help message

FILE NAMING:
    Paired files must follow these patterns:
      - sample_R1.fastq.gz / sample_R2.fastq.gz
      - sample_1.fastq.gz / sample_2.fastq.gz

EXAMPLES:
    # Standard batch processing
    bash run_pimgavir_batch.sh /data/fastq/ ALL

    # High-memory assembly, 2 samples at a time
    bash run_pimgavir_batch.sh /data/fastq/ --ass_based \\
        --mem 256GB --array-limit 2

    # With filtering and email notifications
    bash run_pimgavir_batch.sh /data/fastq/ ALL \\
        --filter --email user@ird.fr --mail-type ALL

EOF
    exit 0
}

################################################################################
# Parse Arguments
################################################################################
if [ $# -lt 2 ]; then
    echo "ERROR: Insufficient arguments"
    echo ""
    show_help
fi

INPUT_DIR="$1"
METHOD="$2"
shift 2

# Initialize optional parameters
THREADS=$DEFAULT_THREADS
MEMORY=$DEFAULT_MEM
TIME_LIMIT=$DEFAULT_TIME
PARTITION=$DEFAULT_PARTITION
FILTER_FLAG=""
USE_INFINIBAND=false
EMAIL=$DEFAULT_EMAIL
MAIL_TYPE=$DEFAULT_MAIL_TYPE
ARRAY_LIMIT=$DEFAULT_ARRAY_LIMIT

# Parse optional arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        --threads)
            THREADS="$2"
            shift 2
            ;;
        --mem)
            MEMORY="$2"
            shift 2
            ;;
        --time)
            TIME_LIMIT="$2"
            shift 2
            ;;
        --partition)
            PARTITION="$2"
            shift 2
            ;;
        --filter)
            FILTER_FLAG="--filter"
            shift
            ;;
        --infiniband)
            USE_INFINIBAND=true
            shift
            ;;
        --email)
            EMAIL="$2"
            shift 2
            ;;
        --mail-type)
            MAIL_TYPE="$2"
            shift 2
            ;;
        --array-limit)
            ARRAY_LIMIT="$2"
            shift 2
            ;;
        *)
            echo "WARNING: Unknown option: $1"
            shift
            ;;
    esac
done

################################################################################
# Validation
################################################################################
echo "=========================================="
echo "PIMGAVir - Batch Job Configuration"
echo "=========================================="
echo ""

if [ ! -d "$INPUT_DIR" ]; then
    echo "ERROR: Input directory not found: $INPUT_DIR"
    exit 1
fi

# Validate method
case "$METHOD" in
    ALL|--read_based|--ass_based|--clust_based)
        ;;
    *)
        echo "ERROR: Invalid METHOD: $METHOD"
        exit 1
        ;;
esac

################################################################################
# Detect Sample Files
################################################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Use detect_samples.sh if available
if [ -f "${SCRIPT_DIR}/detect_samples.sh" ]; then
    SAMPLES_FILE="${PROJECT_DIR}/samples_list.txt"

    # Run detect_samples.sh and redirect output (it creates the file directly)
    # We need to suppress its output to avoid pollution
    bash "${SCRIPT_DIR}/detect_samples.sh" "$INPUT_DIR" "$SAMPLES_FILE" > /dev/null 2>&1

    if [ ! -f "$SAMPLES_FILE" ] || [ ! -s "$SAMPLES_FILE" ]; then
        echo "ERROR: No valid sample pairs detected in: $INPUT_DIR"
        echo ""
        echo "Running detection again with verbose output for debugging:"
        bash "${SCRIPT_DIR}/detect_samples.sh" "$INPUT_DIR" "$SAMPLES_FILE"
        exit 1
    fi

    # Count only non-empty lines
    N_SAMPLES=$(grep -c -v '^[[:space:]]*$' "$SAMPLES_FILE" 2>/dev/null || echo 0)

    if [ "$N_SAMPLES" -eq 0 ]; then
        echo "ERROR: Sample list file is empty or corrupted: $SAMPLES_FILE"
        echo ""
        echo "Running detection again with verbose output for debugging:"
        bash "${SCRIPT_DIR}/detect_samples.sh" "$INPUT_DIR" "$SAMPLES_FILE"
        exit 1
    fi
else
    echo "ERROR: detect_samples.sh not found"
    exit 1
fi

################################################################################
# Determine Worker Script
################################################################################
if [ "$USE_INFINIBAND" = true ]; then
    WORKER_SCRIPT="${SCRIPT_DIR}/PIMGAVIR_worker_ib.sh"
    echo "Mode: Infiniband scratch (/scratch-ib/)"
else
    WORKER_SCRIPT="${SCRIPT_DIR}/PIMGAVIR_worker.sh"
    echo "Mode: Standard scratch (/scratch/)"
fi

if [ ! -f "$WORKER_SCRIPT" ]; then
    echo "ERROR: Worker script not found: $WORKER_SCRIPT"
    exit 1
fi

################################################################################
# Display Configuration
################################################################################
echo "Batch Configuration:"
echo "  Input directory: $INPUT_DIR"
echo "  Number of samples: $N_SAMPLES"
echo "  Method: $METHOD"
echo "  Filter: ${FILTER_FLAG:-No}"
echo ""
echo "SLURM Resources (per sample):"
echo "  Threads: $THREADS"
echo "  Memory: $MEMORY"
echo "  Time limit: $TIME_LIMIT"
echo "  Partition: $PARTITION"
echo "  Array limit: $ARRAY_LIMIT concurrent jobs"
if [ -n "$EMAIL" ]; then
    echo "  Email: $EMAIL"
    echo "  Notifications: $MAIL_TYPE"
fi
echo ""
echo "Worker script: $(basename "$WORKER_SCRIPT")"
echo ""

# Show first 5 samples
echo "Samples to process (showing first 5):"
DISPLAY_COUNT=0
while IFS=$'\t' read -r r1 r2 sample; do
    # Skip empty lines
    [ -z "$sample" ] && continue
    echo "  - $sample"
    DISPLAY_COUNT=$((DISPLAY_COUNT + 1))
    [ $DISPLAY_COUNT -ge 5 ] && break
done < "$SAMPLES_FILE"

if [ $N_SAMPLES -gt 5 ]; then
    echo "  ... and $((N_SAMPLES - 5)) more"
fi
echo ""

################################################################################
# Build SLURM Command
################################################################################
SBATCH_CMD="sbatch"
SBATCH_CMD="$SBATCH_CMD --job-name=PIMGAVir_batch"
SBATCH_CMD="$SBATCH_CMD --output=${PROJECT_DIR}/logs/pimgavir_%A_%a.out"
SBATCH_CMD="$SBATCH_CMD --error=${PROJECT_DIR}/logs/pimgavir_%A_%a.err"
SBATCH_CMD="$SBATCH_CMD --cpus-per-task=$THREADS"
SBATCH_CMD="$SBATCH_CMD --mem=$MEMORY"
SBATCH_CMD="$SBATCH_CMD --time=$TIME_LIMIT"
SBATCH_CMD="$SBATCH_CMD --partition=$PARTITION"
SBATCH_CMD="$SBATCH_CMD --nodes=1"
SBATCH_CMD="$SBATCH_CMD --array=1-${N_SAMPLES}%${ARRAY_LIMIT}"

# Add email notifications if provided
if [ -n "$EMAIL" ]; then
    SBATCH_CMD="$SBATCH_CMD --mail-user=$EMAIL"
    SBATCH_CMD="$SBATCH_CMD --mail-type=$MAIL_TYPE"
fi

# Add Infiniband constraint if needed
if [ "$USE_INFINIBAND" = true ]; then
    SBATCH_CMD="$SBATCH_CMD --constraint=infiniband"
fi

# Create wrapper script that reads from samples file
WRAPPER_SCRIPT="${PROJECT_DIR}/logs/batch_wrapper_$$.sh"
cat > "$WRAPPER_SCRIPT" <<EOF
#!/bin/bash
# Auto-generated wrapper script for batch processing

SAMPLES_FILE="$SAMPLES_FILE"
WORKER_SCRIPT="$WORKER_SCRIPT"

# Read sample info from array task ID
SAMPLE_LINE=\$(sed -n "\${SLURM_ARRAY_TASK_ID}p" "\$SAMPLES_FILE")
R1=\$(echo "\$SAMPLE_LINE" | cut -f1)
R2=\$(echo "\$SAMPLE_LINE" | cut -f2)
SAMPLE=\$(echo "\$SAMPLE_LINE" | cut -f3)

# Execute worker script
bash "\$WORKER_SCRIPT" "\$R1" "\$R2" "\$SAMPLE" $THREADS $METHOD $FILTER_FLAG
EOF

chmod +x "$WRAPPER_SCRIPT"

# Submit wrapper script
SBATCH_CMD="$SBATCH_CMD $WRAPPER_SCRIPT"

################################################################################
# Create logs directory
################################################################################
mkdir -p "${PROJECT_DIR}/logs"

################################################################################
# Submit Job
################################################################################
echo "Submitting batch job to SLURM..."
echo ""

JOB_ID=$(eval $SBATCH_CMD | grep -oE '[0-9]+')

if [ $? -eq 0 ] && [ -n "$JOB_ID" ]; then
    echo "=========================================="
    echo "Batch job submitted successfully!"
    echo "=========================================="
    echo "Job ID: $JOB_ID"
    echo "Number of samples: $N_SAMPLES"
    echo "Concurrent jobs: $ARRAY_LIMIT"
    echo "Method: $METHOD"
    echo ""
    echo "Monitor job status:"
    echo "  squeue -j $JOB_ID"
    echo "  squeue -u \$USER"
    echo ""
    echo "View logs for specific sample (task N):"
    echo "  tail -f ${PROJECT_DIR}/logs/pimgavir_${JOB_ID}_N.out"
    echo ""
    echo "Cancel all array jobs:"
    echo "  scancel $JOB_ID"
    echo ""
    echo "Cancel specific task (e.g., task 5):"
    echo "  scancel ${JOB_ID}_5"
    echo "=========================================="
else
    echo "ERROR: Job submission failed"
    rm -f "$WRAPPER_SCRIPT"
    exit 1
fi

exit 0
