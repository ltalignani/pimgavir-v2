#!/bin/bash

################################################################################
# PIMGAVir Batch Launcher - Conda + Infiniband Version
#
# This script automatically detects and processes all paired-end samples in the
# input/ directory using SLURM array jobs for parallel execution on Infiniband
# network with /scratch-ib/ for optimal I/O performance.
#
# New Usage (Batch Mode):
#   sbatch PIMGAVIR_conda_ib.sh <NumbOfCores> <METHOD> [--filter]
#
# Legacy Usage (Single Sample - Backward Compatible):
#   sbatch PIMGAVIR_conda_ib.sh R1.fastq.gz R2.fastq.gz SampleName <NumbOfCores> <METHOD> [--filter]
#
# Examples:
#   # Batch mode - processes all samples in input/
#   sbatch PIMGAVIR_conda_ib.sh 40 ALL
#   sbatch PIMGAVIR_conda_ib.sh 40 --read_based --filter
#
#   # Legacy mode - single sample
#   sbatch PIMGAVIR_conda_ib.sh sample_R1.fq.gz sample_R2.fq.gz sample1 40 ALL --filter
#
# Directory Structure:
#   input/           - Place all sample FASTQ.gz files here
#   logs/            - SLURM output/error logs
#   samples.list     - Auto-generated sample list (temporary)
#
################################################################################

##Versioning
version="PIMGAVir V.2.1 -- 29.10.2025 (Batch Launcher - Conda + Infiniband Version)"

################################################################################
# Configuration - Project Location on NAS
################################################################################
# IMPORTANT: If you copy this script to a different location (e.g., ~/scripts/),
# you MUST set the absolute path to the project directory on the NAS here:
PIMGAVIR_PROJECT_DIR="/projects/large/PIMGAVIR/pimgavir_dev"

# If empty, the script will try to auto-detect based on submission directory
# PIMGAVIR_PROJECT_DIR=""

################################################################################
# Detect Mode: Batch vs Legacy
################################################################################

# Check if first argument is a FASTQ file (legacy mode)
if [[ "$1" == *.fastq.gz ]] || [[ "$1" == *.fq.gz ]]; then
    LEGACY_MODE=true
    echo "=========================================="
    echo "Legacy Mode Detected (Infiniband)"
    echo "=========================================="
    echo "Forwarding to Infiniband worker script for single sample processing..."
    echo ""

    # Forward all arguments to worker script
    # Legacy usage: R1 R2 SampleName Threads Method [--filter]
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Call Infiniband worker script with all arguments
    exec bash "${SCRIPT_DIR}/PIMGAVIR_worker_ib.sh" "$@"

else
    LEGACY_MODE=false
    echo "=========================================="
    echo "PIMGAVir Batch Launcher (Infiniband)"
    echo "=========================================="
    echo "Version: $version"
    echo "Date: $(date)"
    echo "User: ${USER}"
    echo "Network: Infiniband (/scratch-ib/)"
    echo ""
fi

################################################################################
# Batch Mode: Parse Arguments
################################################################################
JTrim=$1           # Number of cores
METHOD=$2          # Analysis method
filter=$3          # Optional --filter flag

# Validate arguments
if [ -z "$JTrim" ] || [ -z "$METHOD" ]; then
    echo "ERROR: Missing required arguments for batch mode"
    echo ""
    echo "Batch Mode Usage:"
    echo "  sbatch PIMGAVIR_conda_ib.sh <NumbOfCores> <METHOD> [--filter]"
    echo ""
    echo "Legacy Mode Usage:"
    echo "  sbatch PIMGAVIR_conda_ib.sh R1.fastq.gz R2.fastq.gz SampleName <NumbOfCores> <METHOD> [--filter]"
    echo ""
    echo "Examples:"
    echo "  sbatch PIMGAVIR_conda_ib.sh 40 ALL"
    echo "  sbatch PIMGAVIR_conda_ib.sh 40 --read_based --filter"
    echo ""
    exit 1
fi

# Validate threads
if ! [[ "$JTrim" =~ ^[0-9]+$ ]] || [ "$JTrim" -le 0 ]; then
    echo "ERROR: Invalid number of cores: $JTrim"
    echo "Please provide a positive integer"
    exit 1
fi

# Validate method
case $METHOD in
    "ALL"|"--read_based"|"--ass_based"|"--clust_based")
        echo "Parameters:"
        echo "  Threads: $JTrim"
        echo "  Method: $METHOD"
        echo "  Filter: ${filter:-not activated}"
        echo ""
        ;;
    *)
        echo "ERROR: Invalid method: $METHOD"
        echo "Valid methods: ALL, --read_based, --ass_based, --clust_based"
        exit 1
        ;;
esac

################################################################################
# Detect Samples in input/ Directory
################################################################################
# Determine project directory with priority order:
# 1. PIMGAVIR_PROJECT_DIR variable (if set at top of script)
# 2. SLURM_SUBMIT_DIR (when submitted via sbatch)
# 3. Script location (when run interactively from project)

if [ -n "$PIMGAVIR_PROJECT_DIR" ]; then
    # Use configured absolute path (best for scripts copied to ~/scripts/)
    PROJECT_DIR="$PIMGAVIR_PROJECT_DIR"
    SCRIPT_DIR="${PROJECT_DIR}/scripts"
    echo "Using configured project directory: $PROJECT_DIR"
elif [ -n "$SLURM_SUBMIT_DIR" ]; then
    # Running as SLURM job - use submission directory
    PROJECT_DIR="$SLURM_SUBMIT_DIR"
    SCRIPT_DIR="${PROJECT_DIR}/scripts"
    echo "Using SLURM submission directory: $PROJECT_DIR"
else
    # Running interactively - use script location
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
    echo "Auto-detected project directory: $PROJECT_DIR"
fi

INPUT_DIR="${PROJECT_DIR}/input"
SAMPLES_LIST="${PROJECT_DIR}/samples.list"

echo ""
echo "Sample Detection"
echo "=========================================="
echo "Project directory: $PROJECT_DIR"
echo "Scripts directory: $SCRIPT_DIR"
echo "Input directory: $INPUT_DIR"

# Check if input directory exists
if [ ! -d "$INPUT_DIR" ]; then
    echo "ERROR: Input directory does not exist: $INPUT_DIR"
    echo ""
    echo "Please create the input/ directory and place your samples there:"
    echo "  mkdir -p input/"
    echo "  cp /path/to/samples/*_R*.fastq.gz input/"
    echo ""
    exit 1
fi

# Run sample detection script
if [ ! -f "${SCRIPT_DIR}/detect_samples.sh" ]; then
    echo "ERROR: detect_samples.sh script not found"
    exit 1
fi

echo "Running sample detection..."
bash "${SCRIPT_DIR}/detect_samples.sh" "$INPUT_DIR" "$SAMPLES_LIST"
DETECTION_EXIT_CODE=$?

# Check if sample detection succeeded
if [ $DETECTION_EXIT_CODE -ne 0 ]; then
    echo "ERROR: Sample detection failed with exit code $DETECTION_EXIT_CODE"
    exit 1
fi

if [ ! -f "$SAMPLES_LIST" ]; then
    echo "ERROR: samples.list was not created"
    exit 1
fi

# Count samples
NUM_SAMPLES=$(wc -l < "$SAMPLES_LIST")

if [ "$NUM_SAMPLES" -eq 0 ]; then
    echo "ERROR: No samples found in $INPUT_DIR"
    exit 1
fi

echo ""
echo "Summary: Found $NUM_SAMPLES sample(s) to process"
echo ""

################################################################################
# Prepare SLURM Array Job
################################################################################
echo "=========================================="
echo "Preparing SLURM Array Job (Infiniband)"
echo "=========================================="

# Create logs directory if it doesn't exist
LOGS_DIR="${PROJECT_DIR}/logs"
mkdir -p "$LOGS_DIR"

echo "Logs directory: $LOGS_DIR"
echo "Array size: 0-$((NUM_SAMPLES-1))"
echo "Constraint: infiniband (required for /scratch-ib/)"
echo ""

################################################################################
# Build Worker Command Template
################################################################################
# Build the command that each array task will execute
WORKER_SCRIPT="${SCRIPT_DIR}/PIMGAVIR_worker_ib.sh"

if [ ! -f "$WORKER_SCRIPT" ]; then
    echo "ERROR: Infiniband worker script not found: $WORKER_SCRIPT"
    exit 1
fi

# Create a wrapper script that reads from samples.list
WRAPPER_SCRIPT="${PROJECT_DIR}/run_worker_ib_${RANDOM}.sh"

cat > "$WRAPPER_SCRIPT" << EOFWRAPPER
#!/bin/bash

# Get sample info from samples.list based on SLURM_ARRAY_TASK_ID
PROJECT_DIR="${PROJECT_DIR}"
SCRIPT_DIR="${SCRIPT_DIR}"
SAMPLES_LIST="\${PROJECT_DIR}/samples.list"

# Read the line corresponding to this array task
SAMPLE_LINE=\$(sed -n "\$((SLURM_ARRAY_TASK_ID + 1))p" "\$SAMPLES_LIST")

if [ -z "\$SAMPLE_LINE" ]; then
    echo "ERROR: Could not read sample at index \$SLURM_ARRAY_TASK_ID"
    exit 1
fi

# Parse tab-separated values
R1=\$(echo "\$SAMPLE_LINE" | cut -f1)
R2=\$(echo "\$SAMPLE_LINE" | cut -f2)
SAMPLE_NAME=\$(echo "\$SAMPLE_LINE" | cut -f3)

# Get parameters from environment variables set by launcher
THREADS="\${PIMGAVIR_THREADS}"
METHOD="\${PIMGAVIR_METHOD}"
FILTER="\${PIMGAVIR_FILTER}"

echo "=========================================="
echo "Array Task: \$SLURM_ARRAY_TASK_ID (Infiniband)"
echo "Sample: \$SAMPLE_NAME"
echo "=========================================="

# Call Infiniband worker script
exec bash "\${SCRIPT_DIR}/PIMGAVIR_worker_ib.sh" "\$R1" "\$R2" "\$SAMPLE_NAME" "\$THREADS" "\$METHOD" \$FILTER
EOFWRAPPER

chmod +x "$WRAPPER_SCRIPT"

################################################################################
# Submit SLURM Array Job
################################################################################
echo "Submitting SLURM Array Job (Infiniband)"
echo "=========================================="

# Export parameters as environment variables for the wrapper
export PIMGAVIR_THREADS="$JTrim"
export PIMGAVIR_METHOD="$METHOD"
export PIMGAVIR_FILTER="${filter}"

# Submit array job with Infiniband constraint
SBATCH_CMD="sbatch \
    --array=0-$((NUM_SAMPLES-1)) \
    --job-name=PIMGAVir-IB \
    --output=${LOGS_DIR}/pimgavir_%A_%a.out \
    --error=${LOGS_DIR}/pimgavir_%A_%a.err \
    --time=3-23:59:59 \
    --partition=normal \
    --constraint=infiniband \
    --nodes=1 \
    --cpus-per-task=${JTrim} \
    --mem=64GB \
    --mail-user=loic.talignani@ird.fr \
    --mail-type=ALL \
    --export=ALL,PIMGAVIR_THREADS=${JTrim},PIMGAVIR_METHOD=${METHOD},PIMGAVIR_FILTER=${filter} \
    $WRAPPER_SCRIPT"

echo "SLURM command:"
echo "$SBATCH_CMD"
echo ""

# Execute sbatch
JOB_ID=$(eval $SBATCH_CMD | grep -oP '\d+')

if [ -z "$JOB_ID" ]; then
    echo "ERROR: Failed to submit SLURM array job"
    rm -f "$WRAPPER_SCRIPT"
    exit 1
fi

echo "=========================================="
echo "Job Submission Successful (Infiniband)"
echo "=========================================="
echo "Job ID: $JOB_ID"
echo "Number of samples: $NUM_SAMPLES"
echo "Array indices: 0-$((NUM_SAMPLES-1))"
echo "Network: Infiniband (/scratch-ib/)"
echo ""
echo "Monitoring Commands:"
echo "  squeue -j $JOB_ID                    # View job status"
echo "  squeue -u $USER                      # View all your jobs"
echo "  sacct -j $JOB_ID --format=JobID,JobName,State,ExitCode,Elapsed"
echo "  tail -f ${LOGS_DIR}/pimgavir_${JOB_ID}_*.out"
echo ""
echo "Results will be saved to:"
echo "  /projects/large/PIMGAVIR/results/${JOB_ID}_*"
echo ""
echo "=========================================="

# Keep wrapper script for debugging, but can be removed after job completes
echo "Temporary wrapper script: $WRAPPER_SCRIPT"
echo "(This will be automatically cleaned up after the job completes)"
echo ""

exit 0
