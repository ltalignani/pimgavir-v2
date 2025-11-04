# PIMGAVir Batch Processing Guide

**Version**: 2.1+
**Date**: October 29, 2025

## Overview

PIMGAVir v2.1 introduces automated batch processing that allows you to process multiple samples simultaneously using SLURM array jobs. Simply place your samples in the `input/` directory and run a single command - the pipeline automatically detects all samples and processes them in parallel.

## Table of Contents

- [Quick Start](#quick-start)
- [How It Works](#how-it-works)
- [Usage Examples](#usage-examples)
- [Supported File Naming](#supported-file-naming)
- [Monitoring Jobs](#monitoring-jobs)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage](#advanced-usage)

## Quick Start

### 1. Prepare Your Samples

```bash
# Create input directory (if not already exists)
mkdir -p input/

# Copy your paired-end FASTQ files to input/
cp /path/to/samples/*_R1.fastq.gz input/
cp /path/to/samples/*_R2.fastq.gz input/

# Verify files are in place
ls -lh input/
```

### 2. Run Batch Processing

**Standard Scratch** (`/scratch/`)
```bash
cd scripts/
sbatch PIMGAVIR_conda.sh 40 ALL
```

**Infiniband Scratch** (`/scratch-ib/` - IRD Cluster)
```bash
cd scripts/
sbatch PIMGAVIR_conda_ib.sh 40 ALL
```

That's it! The pipeline will:
- Automatically detect all samples in `input/`
- Create SLURM array jobs (one job per sample)
- Process all samples in parallel
- Save results to `/projects/large/PIMGAVIR/results/`

## How It Works

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Batch Processing Flow                     │
└─────────────────────────────────────────────────────────────┘

1. PIMGAVIR_conda.sh (Launcher)
   ├─ Scans input/ directory
   ├─ Calls detect_samples.sh
   ├─ Generates samples.list
   └─ Submits SLURM array job
        │
        ▼
2. SLURM Array Job
   ├─ Job Array [0-N] (one per sample)
   │   ├─ Task 0 → PIMGAVIR_worker.sh (Sample 1)
   │   ├─ Task 1 → PIMGAVIR_worker.sh (Sample 2)
   │   ├─ Task 2 → PIMGAVIR_worker.sh (Sample 3)
   │   └─ Task N → PIMGAVIR_worker.sh (Sample N)
   │
   └─ Each worker processes one sample independently
        │
        ▼
3. Results
   └─ /projects/large/PIMGAVIR/results/JOBID_SampleName_METHOD/
```

### Components

1. **Launcher** (`PIMGAVIR_conda.sh` or `PIMGAVIR_conda_ib.sh`)
   - Detects samples in `input/` directory
   - Creates `samples.list` with sample metadata
   - Submits SLURM array job

2. **Sample Detection** (`detect_samples.sh`)
   - Scans for paired-end FASTQ files
   - Matches R1/R2 pairs
   - Extracts sample names
   - Supports multiple naming conventions

3. **Worker** (`PIMGAVIR_worker.sh` or `PIMGAVIR_worker_ib.sh`)
   - Processes one sample per array task
   - Uses unique scratch directory per sample
   - Saves results to permanent storage
   - Cleans up temporary files

## Usage Examples

### Basic Usage

**All Analysis Methods**
```bash
sbatch PIMGAVIR_conda.sh 40 ALL
```

**Read-based Only**
```bash
sbatch PIMGAVIR_conda.sh 40 --read_based
```

**Assembly-based Only**
```bash
sbatch PIMGAVIR_conda.sh 40 --ass_based
```

**Clustering-based Only**
```bash
sbatch PIMGAVIR_conda.sh 40 --clust_based
```

**With Host Filtering**
```bash
sbatch PIMGAVIR_conda.sh 40 ALL --filter
```

### Infiniband Version (IRD Cluster)

For optimal performance on the IRD cluster with Infiniband network:

```bash
# All methods with Infiniband
sbatch PIMGAVIR_conda_ib.sh 40 ALL

# Read-based only with filtering
sbatch PIMGAVIR_conda_ib.sh 40 --read_based --filter
```

### Thread Allocation

The launcher automatically allocates threads to each sample:

```bash
# 40 threads per sample
sbatch PIMGAVIR_conda.sh 40 ALL

# 64 threads per sample (for large samples)
sbatch PIMGAVIR_conda.sh 64 ALL

# When using ALL method, threads are divided by 3:
# 40 threads → 13 threads per method (read/assembly/clustering)
```

## Supported File Naming

The sample detection script supports these paired-end naming conventions:

### Pattern 1: Underscore separator

```
sample1_R1.fastq.gz  ←→  sample1_R2.fastq.gz
sample2_1.fastq.gz   ←→  sample2_2.fastq.gz
```

### Pattern 2: Dot separator

```
sample1.R1.fastq.gz  ←→  sample1.R2.fastq.gz
sample2.1.fastq.gz   ←→  sample2.2.fastq.gz
```

### Pattern 3: Alternative extensions

```
sample1_R1.fq.gz     ←→  sample1_R2.fq.gz
sample2.R1.fq.gz     ←→  sample2.R2.fq.gz
```

### Sample Name Extraction

The pipeline automatically extracts sample names by removing R1/R2 suffixes:

| Input Files | Extracted Sample Name |
|-------------|----------------------|
| `ABC_R1.fastq.gz` + `ABC_R2.fastq.gz` | `ABC` |
| `sample01_1.fq.gz` + `sample01_2.fq.gz` | `sample01` |
| `data.R1.fastq.gz` + `data.R2.fastq.gz` | `data` |

## Monitoring Jobs

### View Job Status

```bash
# View specific job
squeue -j JOBID

# View all your jobs
squeue -u $USER

# View detailed job information
sacct -j JOBID --format=JobID,JobName,State,ExitCode,Elapsed
```

### Check Sample-Specific Logs

```bash
# Each array task has its own log files
tail -f logs/pimgavir_JOBID_0.out   # Sample 0
tail -f logs/pimgavir_JOBID_1.out   # Sample 1
tail -f logs/pimgavir_JOBID_2.out   # Sample 2

# View errors
tail -f logs/pimgavir_JOBID_*.err
```

### Monitor Progress

```bash
# Watch all jobs
watch -n 5 'squeue -u $USER'

# Count completed tasks
sacct -j JOBID --format=JobID,State | grep COMPLETED | wc -l

# Check for failed tasks
sacct -j JOBID --format=JobID,State | grep FAILED
```

## Troubleshooting

### No Samples Detected

**Problem**: `ERROR: No paired samples found in input/`

**Solutions**:
```bash
# 1. Check if files exist
ls -lh input/

# 2. Verify file naming matches supported patterns
# Must be: *_R1.fastq.gz / *_R2.fastq.gz (or similar)

# 3. Run sample detection manually to see details
cd scripts/
./detect_samples.sh ../input samples_test.list
```

### R2 File Not Found for R1

**Problem**: `WARNING: No R2 file found for: sample_R1.fastq.gz`

**Solutions**:
```bash
# Check if both R1 and R2 exist
ls -lh input/sample_*

# Ensure consistent naming:
# ✓ sample_R1.fastq.gz + sample_R2.fastq.gz  (correct)
# ✗ sample_R1.fastq.gz + sample_R2.fq.gz     (inconsistent extensions)
# ✗ sample_R1.fastq.gz + sample_R3.fastq.gz  (R3 not R2)
```

### Job Failed to Submit

**Problem**: `ERROR: Failed to submit SLURM array job`

**Solutions**:
```bash
# 1. Check SLURM is available
sinfo

# 2. Verify partition exists
sinfo -o "%P"

# 3. Check for correct permissions
ls -l scripts/PIMGAVIR_conda.sh
chmod +x scripts/PIMGAVIR_conda.sh
```

### Array Task Failed

**Problem**: Individual array task shows `FAILED` status

**Solutions**:
```bash
# 1. Check task-specific error log
cat logs/pimgavir_JOBID_TASKID.err

# 2. Common issues:
#    - Input file not found: check if R1/R2 are in input/
#    - Out of memory: increase --mem in worker script
#    - Conda environment issue: verify activation

# 3. Rerun single failed sample manually
sbatch PIMGAVIR_conda.sh sample_R1.fq.gz sample_R2.fq.gz sample 40 ALL
```

### Infiniband Issues

**Problem**: Infiniband jobs fail on some nodes

**Solutions**:
```bash
# 1. Verify node has Infiniband capability
srun -p highmem --constraint=infiniband --pty bash
cd /scratch-ib/
ls  # Should work without errors

# 2. If Infiniband unavailable, use standard version
sbatch PIMGAVIR_conda.sh 40 ALL  # Instead of _ib version

# 3. Check san-ib connection
scp san-ib:/projects/large/PIMGAVIR/test_file .
```

## Advanced Usage

### Limiting Concurrent Jobs

To limit the number of samples processed simultaneously:

**Method 1: Modify launcher (before submission)**
```bash
# Edit PIMGAVIR_conda.sh line ~240
# Change:
--array=0-$((NUM_SAMPLES-1))
# To:
--array=0-$((NUM_SAMPLES-1))%5    # Max 5 concurrent samples
```

**Method 2: Use SLURM constraints**
```bash
# Submit with dependency
sbatch --dependency=singleton PIMGAVIR_conda.sh 40 ALL
```

### Custom Resource Allocation

Edit worker scripts to adjust resources per sample:

**PIMGAVIR_worker.sh** lines 8-12:
```bash
#SBATCH --time=6-23:59:59      # Adjust runtime
#SBATCH --partition=highmem    # Change partition
#SBATCH --mem=256GB            # Adjust memory
```

### Processing Subset of Samples

**Option 1: Temporary input directory**
```bash
mkdir -p input_subset/
cp input/sample1_* input/sample2_* input_subset/
# Edit launcher to use input_subset/
```

**Option 2: Move unwanted samples temporarily**
```bash
mkdir -p input_archived/
mv input/unwanted_* input_archived/
# Run batch processing
mv input_archived/* input/  # Restore later
```

### Legacy Single-Sample Mode

The batch launchers maintain backward compatibility:

```bash
# Automatically detected as single-sample mode
sbatch PIMGAVIR_conda.sh sample_R1.fq.gz sample_R2.fq.gz sample01 40 ALL --filter

# This will:
# 1. Detect FASTQ argument (legacy mode)
# 2. Forward to PIMGAVIR_worker.sh
# 3. Process single sample
```

## Directory Structure

### Before Running

```
pimgavir_dev/
├── input/                          # Place samples here
│   ├── sample1_R1.fastq.gz
│   ├── sample1_R2.fastq.gz
│   ├── sample2_R1.fastq.gz
│   └── sample2_R2.fastq.gz
├── logs/                           # Created automatically
└── scripts/
    ├── PIMGAVIR_conda.sh          # Batch launcher
    ├── PIMGAVIR_worker.sh         # Worker script
    └── detect_samples.sh          # Sample detection
```

### After Running

```
pimgavir_dev/
├── input/                          # Original samples (preserved)
├── logs/
│   ├── pimgavir_12345_0.out       # Sample 1 output
│   ├── pimgavir_12345_0.err       # Sample 1 errors
│   ├── pimgavir_12345_1.out       # Sample 2 output
│   └── pimgavir_12345_1.err       # Sample 2 errors
├── samples.list                    # Generated sample list
└── /projects/large/PIMGAVIR/results/
    ├── 12345_sample1_ALL/         # Sample 1 results
    │   ├── read-based-taxonomy/
    │   ├── assembly-based/
    │   ├── clustering-based/
    │   └── report/
    └── 12345_sample2_ALL/         # Sample 2 results
        └── ...
```

## Best Practices

### Sample Organization

1. **Use consistent naming**: Stick to one pattern (_R1/_R2 or .R1/.R2)
2. **Avoid special characters**: Use alphanumeric and underscores only
3. **Keep sample names short**: Easier to manage and monitor
4. **Compress files**: Always use .gz compression for FASTQ files

### Resource Management

1. **Start small**: Test with 1-2 samples before processing many
2. **Monitor resources**: Check memory/CPU usage during runs
3. **Use Infiniband**: On IRD cluster, always use `_ib` versions for better performance
4. **Limit concurrent jobs**: For large batches, use `%N` array syntax

### Data Management

1. **Backup originals**: Keep original FASTQ files safe
2. **Clean input/ regularly**: Archive processed samples
3. **Monitor storage**: Results can be large (~100GB per sample)
4. **Document runs**: Keep notes on parameters used

## Performance Expectations

### Processing Time per Sample

| Method | Typical Runtime | Notes |
|--------|----------------|-------|
| `--read_based` | 4-8 hours | Fastest, no assembly |
| `--ass_based` | 1-3 days | Assembly takes most time |
| `--clust_based` | 12-24 hours | Clustering + classification |
| `ALL` | 2-4 days | All methods in parallel |

### Resource Usage

| Resource | Typical Usage | Recommended |
|----------|--------------|-------------|
| CPU | 30-40 cores | 40 cores |
| Memory | 150-200 GB | 256 GB |
| Scratch | 100-200 GB | 500 GB available |
| Results | 50-100 GB | Plan accordingly |

### Scalability

| Number of Samples | Expected Completion | Notes |
|-------------------|---------------------|-------|
| 1-5 samples | 2-5 days | Quick batch |
| 10-20 samples | 3-7 days | Medium batch |
| 50+ samples | 1-2 weeks | Large batch, use array limits |

## Migration from V.2.0

### Old Way (Single samples, manual submission)

```bash
# Process 3 samples - required 3 separate commands
sbatch PIMGAVIR_conda.sh sample1_R1.fq.gz sample1_R2.fq.gz sample1 40 ALL
sbatch PIMGAVIR_conda.sh sample2_R1.fq.gz sample2_R2.fq.gz sample2 40 ALL
sbatch PIMGAVIR_conda.sh sample3_R1.fq.gz sample3_R2.fq.gz sample3 40 ALL
```

### New Way (Batch mode, automatic)

```bash
# Process all samples - single command
cp *.fastq.gz input/
sbatch PIMGAVIR_conda.sh 40 ALL
```

### Backward Compatibility

All old commands still work! The launcher auto-detects mode:

```bash
# This still works (legacy mode detected)
sbatch PIMGAVIR_conda.sh sample1_R1.fq.gz sample1_R2.fq.gz sample1 40 ALL
```

## Summary

✅ **Simple**: Just place files in `input/` and run one command
✅ **Automatic**: Detects and processes all samples without intervention
✅ **Parallel**: Uses SLURM array jobs for maximum efficiency
✅ **Compatible**: Old single-sample commands still work
✅ **Monitored**: Easy job tracking with SLURM tools
✅ **Optimized**: Infiniband support for IRD cluster

For more information, see:
- [BATCH_PROCESSING_PLAN.md](BATCH_PROCESSING_PLAN.md) - Implementation details
- [SETUP_GUIDE.md](SETUP_GUIDE.md) - Initial setup instructions
- [INFINIBAND_SETUP.md](INFINIBAND_SETUP.md) - IRD cluster configuration
