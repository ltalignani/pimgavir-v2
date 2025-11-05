# PIMGAVir - Resource Configuration Guide

## Overview

PIMGAVir v2.2+ provides **flexible resource configuration** through smart launcher scripts. You can now customize memory, CPU threads, and time limits for each run without modifying any script files.

## Quick Start

### Single Sample Analysis

```bash
# Standard run with defaults (40 threads, 128GB RAM, 4 days)
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL

# High-memory assembly (256GB)
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --ass_based --mem 256GB

# Quick read-based analysis (16 threads, 32GB, 6 hours)
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --read_based \
    --threads 16 --mem 32GB --time 6:00:00
```

### Batch Processing

```bash
# Process all samples in directory
bash scripts/run_pimgavir_batch.sh /data/fastq/ ALL

# High-memory batch, 2 samples at a time
bash scripts/run_pimgavir_batch.sh /data/fastq/ --ass_based \
    --mem 256GB --array-limit 2

# With filtering and notifications
bash scripts/run_pimgavir_batch.sh /data/fastq/ ALL \
    --filter --email user@ird.fr --mail-type ALL
```

---

## Resource Recommendations by Analysis Type

### 1. Read-Based Analysis (`--read_based`)

**Fastest, lowest resources**

| Resource | Recommended | Minimum |
|----------|-------------|---------|
| **Threads** | 16-24 | 8 |
| **Memory** | 32-64 GB | 16 GB |
| **Time** | 6-12 hours | 3 hours |

```bash
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --read_based \
    --threads 16 --mem 32GB --time 8:00:00
```

**Best for:**
- Quick exploratory analysis
- Large sample sets where speed matters
- Systems with limited resources

---

### 2. Assembly-Based Analysis (`--ass_based`)

**Most resource-intensive, best viral genome recovery**

| Resource | Recommended | High-Quality | Minimal |
|----------|-------------|--------------|---------|
| **Threads** | 40-64 | 64-96 | 24 |
| **Memory** | 128-256 GB | 256-512 GB | 64 GB |
| **Time** | 2-4 days | 4-7 days | 1 day |

```bash
# Standard assembly
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --ass_based \
    --threads 40 --mem 128GB --time 3-00:00:00

# High-quality assembly (complex metagenomes)
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --ass_based \
    --threads 64 --mem 512GB --time 5-00:00:00
```

**Best for:**
- Viral genome recovery (Phase 1-7)
- Publication-quality results
- Complex environmental samples

---

### 3. Clustering-Based Analysis (`--clust_based`)

**Moderate resources, good for diversity studies**

| Resource | Recommended | Minimum |
|----------|-------------|---------|
| **Threads** | 24-48 | 16 |
| **Memory** | 64-128 GB | 32 GB |
| **Time** | 1-2 days | 12 hours |

```bash
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --clust_based \
    --threads 32 --mem 64GB --time 1-12:00:00
```

**Best for:**
- OTU-based diversity analysis
- Large read datasets
- When assembly is not critical

---

### 4. All Methods (`ALL`)

**Runs all three methods in parallel**

| Resource | Recommended | High-Performance | Minimal |
|----------|-------------|------------------|---------|
| **Threads** | 60-90 | 120+ | 40 |
| **Memory** | 256-512 GB | 512GB-1TB | 128 GB |
| **Time** | 3-5 days | 5-7 days | 2 days |

```bash
# Standard comprehensive analysis
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
    --threads 60 --mem 256GB --time 4-00:00:00

# Maximum quality (large cluster nodes)
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
    --threads 120 --mem 1TB --time 7-00:00:00 --partition highmem
```

**Best for:**
- Complete characterization
- Cross-validation between methods
- When computational resources are available

---

## All Available Options

### `run_pimgavir.sh` - Single Sample

```bash
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz SAMPLE METHOD [OPTIONS]
```

**Required Arguments:**
- `R1.fq.gz` - Forward reads (gzipped FASTQ)
- `R2.fq.gz` - Reverse reads (gzipped FASTQ)
- `SAMPLE` - Sample identifier
- `METHOD` - Analysis method:
  - `ALL` - All three methods in parallel
  - `--read_based` - Direct read classification
  - `--ass_based` - Assembly-based
  - `--clust_based` - Clustering-based

**Resource Options:**
- `--threads N` - CPU threads (default: 40)
- `--mem N[G|M]` - Memory allocation (default: 128GB)
  - Examples: `32GB`, `256GB`, `512GB`, `1TB`
- `--time D-HH:MM:SS` - Time limit (default: 3-23:59:59)
  - Examples: `12:00:00` (12 hours), `2-00:00:00` (2 days)
- `--partition NAME` - SLURM partition (default: normal)

**Pipeline Options:**
- `--filter` - Enable host/contaminant filtering
- `--infiniband` - Use Infiniband scratch (IRD cluster only)

**Notification Options:**
- `--email EMAIL` - Email address for job notifications
- `--mail-type TYPE` - Notification type (default: END,FAIL)
  - Options: `NONE`, `BEGIN`, `END`, `FAIL`, `ALL`

**Help:**
- `-h, --help` - Show detailed help message

---

### `run_pimgavir_batch.sh` - Multiple Samples

```bash
bash scripts/run_pimgavir_batch.sh INPUT_DIR METHOD [OPTIONS]
```

**Required Arguments:**
- `INPUT_DIR` - Directory containing paired FASTQ files
- `METHOD` - Analysis method (same as single sample)

**All single-sample options PLUS:**
- `--array-limit N` - Max concurrent jobs (default: 4)
  - Use lower values (2-4) for high-memory jobs
  - Use higher values (8-16) for read-based analysis

**File Naming Convention:**
Files must be named:
- `sample_R1.fastq.gz` / `sample_R2.fastq.gz`
- OR `sample_1.fastq.gz` / `sample_2.fastq.gz`

---

## Special Configurations

### IRD Cluster (Infiniband)

```bash
# Use Infiniband scratch for best I/O performance
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
    --infiniband --mem 256GB --partition normal
```

**Requirements:**
- Only available on IRD cluster nodes with Infiniband
- Automatically adds `--constraint=infiniband` to SLURM
- Uses `/scratch-ib/` instead of `/scratch/`

---

### With Host Filtering

```bash
# Enable Diamond BLAST filtering of host/contaminant sequences
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
    --filter --mem 256GB

# Recommended: Add 50-100% more memory and time when filtering
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
    --filter --mem 384GB --time 5-00:00:00
```

**Resource Impact:**
- **Memory**: +50-100 GB for Diamond BLAST
- **Time**: +6-12 hours (depends on database size)

---

### Long Running Jobs

For very large datasets or comprehensive analysis:

```bash
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz large_sample ALL \
    --threads 96 \
    --mem 768GB \
    --time 7-00:00:00 \
    --partition highmem \
    --email user@ird.fr \
    --mail-type END,FAIL
```

---

## Memory Requirements by Dataset Size

| Dataset Size | Read-Based | Clustering | Assembly | All Methods |
|--------------|------------|------------|----------|-------------|
| **Small** (<5M reads) | 16-32 GB | 32-64 GB | 64-128 GB | 128-256 GB |
| **Medium** (5-20M reads) | 32-64 GB | 64-128 GB | 128-256 GB | 256-512 GB |
| **Large** (20-50M reads) | 64-128 GB | 128-256 GB | 256-512 GB | 512GB-1TB |
| **Very Large** (>50M reads) | 128-256 GB | 256-512 GB | 512GB-1TB | 1TB+ |

**Note:** Add 50-100 GB if using `--filter` option.

---

## Time Estimates

| Analysis Type | Small Dataset | Medium Dataset | Large Dataset |
|---------------|---------------|----------------|---------------|
| **Read-based** | 2-4 hours | 4-8 hours | 8-16 hours |
| **Assembly** | 1-2 days | 2-4 days | 4-7 days |
| **Clustering** | 8-16 hours | 1-2 days | 2-3 days |
| **All methods** | 1-3 days | 3-5 days | 5-10 days |

**Factors affecting time:**
- Read count and quality
- Metagenomic complexity
- Assembly parameters (MEGAHIT + SPAdes)
- Filtering enabled/disabled
- Viral genome analysis (Phase 1-7)

---

## Batch Processing Tips

### Strategy 1: Conservative (Guaranteed Success)

```bash
# Start with high resources, limit concurrency
bash scripts/run_pimgavir_batch.sh /data/fastq/ ALL \
    --mem 256GB \
    --time 5-00:00:00 \
    --array-limit 2
```

**Pros:** Jobs rarely fail due to resources
**Cons:** Slower overall (less parallelization)

---

### Strategy 2: Aggressive (Maximum Throughput)

```bash
# Lower resources, high concurrency
bash scripts/run_pimgavir_batch.sh /data/fastq/ --read_based \
    --threads 16 \
    --mem 32GB \
    --time 8:00:00 \
    --array-limit 16
```

**Pros:** Fast for large sample sets
**Cons:** May fail on complex samples

---

### Strategy 3: Adaptive (Recommended)

```bash
# Start with read-based (fast screening)
bash scripts/run_pimgavir_batch.sh /data/fastq/ --read_based \
    --mem 32GB --array-limit 8

# Then assembly on interesting samples only
bash scripts/run_pimgavir.sh interesting_R1.fq.gz interesting_R2.fq.gz sample1 --ass_based \
    --mem 256GB --time 3-00:00:00
```

---

## Troubleshooting Resource Issues

### Job Killed / Out of Memory (OOM)

**Symptom:** Job ends with "Killed" or "Out of memory" message

**Solution:**
```bash
# Increase memory by 50-100%
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
    --mem 256GB  # was 128GB
```

**For assembly jobs specifically:**
```bash
# Assembly often needs the most memory
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --ass_based \
    --mem 512GB --partition highmem
```

---

### Job Timeout

**Symptom:** Job reaches time limit and is killed

**Solution:**
```bash
# Double the time limit
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
    --time 7-00:00:00  # was 3-23:59:59
```

---

### Slow Performance

**Symptom:** Job is very slow or not progressing

**Possible causes and solutions:**

1. **Not enough threads:**
   ```bash
   # Increase threads (if node capacity allows)
   bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
       --threads 64  # was 40
   ```

2. **I/O bottleneck (IRD cluster):**
   ```bash
   # Use Infiniband scratch
   bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
       --infiniband
   ```

3. **Resource contention:**
   ```bash
   # Use dedicated partition
   bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
       --partition highmem
   ```

---

## Monitoring Jobs

### Check Job Status

```bash
# View your running jobs
squeue -u $USER

# View specific job
squeue -j JOB_ID

# Detailed job info
scontrol show job JOB_ID
```

### View Resource Usage

```bash
# Real-time resource monitoring
sstat -j JOB_ID --format=JobID,MaxRSS,AveCPU,AveVMSize

# After completion
sacct -j JOB_ID --format=JobID,JobName,MaxRSS,Elapsed,State
```

### View Logs

```bash
# Standard output
tail -f logs/pimgavir_sample1_JOB_ID.out

# Error output
tail -f logs/pimgavir_sample1_JOB_ID.err
```

---

## Examples Library

### 1. Quick Viral Screening (Many Samples)

```bash
bash scripts/run_pimgavir_batch.sh /data/samples/ --read_based \
    --threads 16 \
    --mem 32GB \
    --time 8:00:00 \
    --array-limit 12 \
    --email user@ird.fr
```

**Use case:** Screening 50+ samples for viral presence

---

### 2. High-Quality Viral Genomes (Publication)

```bash
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --ass_based \
    --threads 64 \
    --mem 512GB \
    --time 5-00:00:00 \
    --partition highmem \
    --filter \
    --email user@ird.fr \
    --mail-type ALL
```

**Use case:** Complete viral genome recovery (Phase 1-7) for publication

---

### 3. Comprehensive Metagenomic Study

```bash
bash scripts/run_pimgavir_batch.sh /data/project/ ALL \
    --threads 60 \
    --mem 256GB \
    --time 4-00:00:00 \
    --array-limit 3 \
    --infiniband \
    --filter \
    --email user@ird.fr
```

**Use case:** All methods + filtering on 10-20 samples

---

### 4. Resource-Limited Environment

```bash
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --read_based \
    --threads 8 \
    --mem 16GB \
    --time 12:00:00 \
    --partition short
```

**Use case:** Running on nodes with limited capacity

---

## Migration from Old Scripts

### Before (v2.1 and earlier)

```bash
# Had to modify #SBATCH directives in script files
sbatch PIMGAVIR_worker.sh R1.fq.gz R2.fq.gz sample1 40 ALL
```

**Problems:**
- ❌ Required manual script editing
- ❌ Hard to track which resources were used
- ❌ Difficult to adjust per-sample

### After (v2.2+)

```bash
# Pass resources as command-line arguments
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
    --threads 40 --mem 256GB --time 3-00:00:00
```

**Benefits:**
- ✅ No script editing needed
- ✅ Resources documented in command
- ✅ Easy per-sample customization
- ✅ Backward compatible (old scripts still work)

---

## Best Practices

1. **Start conservative:** Begin with recommended resources, adjust if needed
2. **Monitor first job:** Check resource usage of first sample before launching batch
3. **Use array limits wisely:** Don't overload the cluster (2-4 for assembly, 8-16 for read-based)
4. **Email notifications:** Always use for long-running jobs
5. **Log everything:** Keep command history for reproducibility
6. **Test small first:** Run one sample before full batch
7. **Plan partitions:** Use appropriate partitions (normal, highmem, long)

---

## Getting Help

```bash
# Show help for single sample
bash scripts/run_pimgavir.sh --help

# Show help for batch processing
bash scripts/run_pimgavir_batch.sh --help

# Test resources without submitting (dry run)
DRY_RUN=true bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
    --mem 256GB --threads 64
```

---

## Summary

The new launcher scripts provide **complete flexibility** for resource configuration:

- ✅ **No script editing required**
- ✅ **Per-sample customization**
- ✅ **Batch processing support**
- ✅ **Clear documentation**
- ✅ **Email notifications**
- ✅ **Infiniband support**
- ✅ **Backward compatible**

**Recommended workflow:**
1. Check dataset size
2. Choose method based on goals
3. Select resources from recommendation tables
4. Use appropriate launcher script
5. Monitor first job
6. Adjust if needed

For questions or issues, refer to main documentation: `README.md` and `CLAUDE.md`
