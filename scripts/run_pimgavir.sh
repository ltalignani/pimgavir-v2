#!/bin/bash

################################################################################
# PIMGAVir - Smart Launcher with Configurable SLURM Resources
#
# Purpose: Launch PIMGAVir pipeline with user-defined resources
#
# Usage:
#   bash run_pimgavir.sh R1.fastq.gz R2.fastq.gz SampleName METHOD [OPTIONS]
#
# Arguments:
#   R1.fastq.gz    : Forward reads
#   R2.fastq.gz    : Reverse reads
#   SampleName     : Sample identifier
#   METHOD         : ALL, --read_based, --ass_based, or --clust_based
#
# Options:
#   --threads N       : Number of CPU threads (default: 40)
#   --mem N[G|M]      : Memory allocation (default: 128GB)
#   --time D-HH:MM:SS : Time limit (default: 3-23:59:59)
#   --partition NAME  : SLURM partition (default: normal)
#   --filter          : Enable host/contaminant filtering
#   --infiniband      : Use Infiniband scratch (IRD cluster)
#   --email EMAIL     : Email for notifications
#   --mail-type TYPE  : Notification type: NONE,BEGIN,END,FAIL,ALL (default: END,FAIL)
#
# Examples:
#   # Standard run with defaults
#   bash run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL
#
#   # High-memory assembly (256GB)
#   bash run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --ass_based --mem 256GB
#
#   # Quick read-based analysis (less memory, 16 threads)
#   bash run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --read_based --threads 16 --mem 32GB
#
#   # Long assembly with filtering (5 days, 512GB)
#   bash run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL --mem 512GB --time 5-00:00:00 --filter
#
#   # Infiniband scratch (IRD cluster)
#   bash run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL --infiniband --mem 256GB
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

################################################################################
# Help Message
################################################################################
show_help() {
    cat << EOF
PIMGAVir - Smart Launcher with Configurable Resources

USAGE:
    bash run_pimgavir.sh R1.fastq.gz R2.fastq.gz SampleName METHOD [OPTIONS]

REQUIRED ARGUMENTS:
    R1.fastq.gz        Forward reads (gzipped FASTQ)
    R2.fastq.gz        Reverse reads (gzipped FASTQ)
    SampleName         Sample identifier
    METHOD             Analysis method:
                         ALL           : All three methods in parallel
                         --read_based  : Direct read classification only
                         --ass_based   : Assembly-based analysis only
                         --clust_based : Clustering-based analysis only

OPTIONS:
    --threads N        Number of CPU threads (default: $DEFAULT_THREADS)
    --mem N[G|M]       Memory allocation (default: $DEFAULT_MEM)
                       Examples: 64GB, 128GB, 256GB, 512GB, 1TB
    --time D-HH:MM:SS  Time limit (default: $DEFAULT_TIME)
                       Examples: 1-00:00:00 (1 day), 12:00:00 (12 hours)
    --partition NAME   SLURM partition (default: $DEFAULT_PARTITION)
    --filter           Enable host/contaminant filtering with Diamond BLAST
    --infiniband       Use Infiniband scratch (/scratch-ib/) - IRD cluster only
    --email EMAIL      Email address for job notifications
    --mail-type TYPE   Notification type (default: $DEFAULT_MAIL_TYPE)
                       Options: NONE, BEGIN, END, FAIL, ALL
    -h, --help         Show this help message

EXAMPLES:
    # Standard run with all methods
    bash run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL

    # Assembly-only with high memory
    bash run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --ass_based --mem 256GB

    # Read-based only, quick analysis
    bash run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --read_based \\
        --threads 16 --mem 32GB --time 6:00:00

    # Full analysis with filtering and long time
    bash run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \\
        --mem 512GB --time 5-00:00:00 --filter

    # Infiniband scratch (IRD cluster)
    bash run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \\
        --infiniband --mem 256GB --email user@ird.fr

RESOURCE RECOMMENDATIONS:
    Read-based only:     16-32 threads, 32-64GB RAM, 6-12 hours
    Assembly-based:      32-64 threads, 128-256GB RAM, 2-4 days
    Clustering-based:    24-48 threads, 64-128GB RAM, 1-2 days
    All methods:         40-64 threads, 128-512GB RAM, 3-5 days

EOF
    exit 0
}

################################################################################
# Parse Arguments
################################################################################
if [ $# -lt 4 ]; then
    echo "ERROR: Insufficient arguments"
    echo ""
    show_help
fi

# Required arguments
R1="$1"
R2="$2"
SAMPLE_NAME="$3"
METHOD="$4"
shift 4

# Initialize optional parameters
THREADS=$DEFAULT_THREADS
MEMORY=$DEFAULT_MEM
TIME_LIMIT=$DEFAULT_TIME
PARTITION=$DEFAULT_PARTITION
FILTER_FLAG=""
USE_INFINIBAND=false
EMAIL=$DEFAULT_EMAIL
MAIL_TYPE=$DEFAULT_MAIL_TYPE

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
echo "PIMGAVir - Job Configuration"
echo "=========================================="
echo ""

# Check if files exist
if [ ! -f "$R1" ]; then
    echo "ERROR: R1 file not found: $R1"
    exit 1
fi

if [ ! -f "$R2" ]; then
    echo "ERROR: R2 file not found: $R2"
    exit 1
fi

# Validate method
case "$METHOD" in
    ALL|--read_based|--ass_based|--clust_based)
        ;;
    *)
        echo "ERROR: Invalid METHOD: $METHOD"
        echo "Must be: ALL, --read_based, --ass_based, or --clust_based"
        exit 1
        ;;
esac

# Get absolute paths
R1=$(readlink -f "$R1" 2>/dev/null || realpath "$R1" 2>/dev/null || echo "$R1")
R2=$(readlink -f "$R2" 2>/dev/null || realpath "$R2" 2>/dev/null || echo "$R2")

################################################################################
# Determine Worker Script
################################################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
echo "Sample Configuration:"
echo "  R1: $(basename "$R1")"
echo "  R2: $(basename "$R2")"
echo "  Sample: $SAMPLE_NAME"
echo "  Method: $METHOD"
echo "  Filter: ${FILTER_FLAG:-No}"
echo ""
echo "SLURM Resources:"
echo "  Threads: $THREADS"
echo "  Memory: $MEMORY"
echo "  Time limit: $TIME_LIMIT"
echo "  Partition: $PARTITION"
if [ -n "$EMAIL" ]; then
    echo "  Email: $EMAIL"
    echo "  Notifications: $MAIL_TYPE"
fi
echo ""
echo "Worker script: $(basename "$WORKER_SCRIPT")"
echo ""

################################################################################
# Build SLURM Command
################################################################################
SBATCH_CMD="sbatch"
SBATCH_CMD="$SBATCH_CMD --job-name=PIMGAVir_${SAMPLE_NAME}"
SBATCH_CMD="$SBATCH_CMD --output=${SCRIPT_DIR}/../logs/pimgavir_${SAMPLE_NAME}_%j.out"
SBATCH_CMD="$SBATCH_CMD --error=${SCRIPT_DIR}/../logs/pimgavir_${SAMPLE_NAME}_%j.err"
SBATCH_CMD="$SBATCH_CMD --cpus-per-task=$THREADS"
SBATCH_CMD="$SBATCH_CMD --mem=$MEMORY"
SBATCH_CMD="$SBATCH_CMD --time=$TIME_LIMIT"
SBATCH_CMD="$SBATCH_CMD --partition=$PARTITION"
SBATCH_CMD="$SBATCH_CMD --nodes=1"

# Add email notifications if provided
if [ -n "$EMAIL" ]; then
    SBATCH_CMD="$SBATCH_CMD --mail-user=$EMAIL"
    SBATCH_CMD="$SBATCH_CMD --mail-type=$MAIL_TYPE"
fi

# Add Infiniband constraint if needed
if [ "$USE_INFINIBAND" = true ]; then
    SBATCH_CMD="$SBATCH_CMD --constraint=infiniband"
fi

# Add worker script and arguments
SBATCH_CMD="$SBATCH_CMD $WORKER_SCRIPT"
SBATCH_CMD="$SBATCH_CMD \"$R1\" \"$R2\" \"$SAMPLE_NAME\" $THREADS $METHOD $FILTER_FLAG"

################################################################################
# Create logs directory if needed
################################################################################
mkdir -p "${SCRIPT_DIR}/../logs"

################################################################################
# Dry Run Check
################################################################################
if [ "${DRY_RUN:-false}" = "true" ]; then
    echo "DRY RUN - Command that would be executed:"
    echo "$SBATCH_CMD"
    exit 0
fi

################################################################################
# Submit Job
################################################################################
echo "Submitting job to SLURM..."
echo ""

# Execute sbatch command
JOB_ID=$(eval $SBATCH_CMD | grep -oE '[0-9]+')

if [ $? -eq 0 ] && [ -n "$JOB_ID" ]; then
    echo "=========================================="
    echo "Job submitted successfully!"
    echo "=========================================="
    echo "Job ID: $JOB_ID"
    echo "Sample: $SAMPLE_NAME"
    echo "Method: $METHOD"
    echo ""
    echo "Monitor job status:"
    echo "  squeue -j $JOB_ID"
    echo ""
    echo "View logs:"
    echo "  tail -f ${SCRIPT_DIR}/../logs/pimgavir_${SAMPLE_NAME}_${JOB_ID}.out"
    echo "  tail -f ${SCRIPT_DIR}/../logs/pimgavir_${SAMPLE_NAME}_${JOB_ID}.err"
    echo ""
    echo "Cancel job:"
    echo "  scancel $JOB_ID"
    echo "=========================================="
else
    echo "ERROR: Job submission failed"
    exit 1
fi

exit 0
