# PIMGAVir - Resource Configuration Guide

**Version:** 2.2.2
**Date:** 2025-11-05
**Launcher Scripts:** `run_pimgavir.sh` and `run_pimgavir_batch.sh`

---

## Overview

PIMGAVir v2.2.2+ provides **flexible resource configuration** through smart launcher scripts. You can customize memory, CPU threads, time limits, and SLURM options for each run **without editing any script files**.

### Key Features

- ✅ **Command-line resource control** - No script editing required
- ✅ **Single & batch processing** - Same interface for both
- ✅ **Per-sample customization** - Different resources per sample
- ✅ **Infiniband support** - IRD cluster optimization
- ✅ **Email notifications** - Job completion alerts
- ✅ **Dry-run mode** - Test without submission

---

## Quick Start Examples

### Single Sample Analysis

```bash
# Standard run with defaults (20 threads, 128GB RAM, ~4 days)
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL

# High-memory assembly (512GB)
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --ass_based \
    --mem 512GB --threads 64

# Quick read-based analysis (16 threads, 32GB, 8 hours)
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --read_based \
    --threads 16 --mem 32GB --time 8:00:00

# With email notifications
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
    --email user@ird.fr --mail-type ALL
```

### Batch Processing

```bash
# Process all samples in directory with defaults
bash scripts/run_pimgavir_batch.sh /data/samples/ ALL

# High-memory batch, 2 samples at a time
bash scripts/run_pimgavir_batch.sh /data/samples/ --ass_based \
    --mem 512GB --threads 64 --array-limit 2

# With filtering and notifications
bash scripts/run_pimgavir_batch.sh /data/samples/ ALL \
    --filter --mem 384GB --email user@ird.fr
```

---

## Resource Recommendations by Analysis Type

### 1. Read-Based Analysis (`--read_based`)

**Fastest, lowest resource requirements**

| Resource | Recommended | Minimum | Maximum |
|----------|-------------|---------|---------|
| **Threads** | 16-24 | 8 | 32 |
| **Memory** | 32-64 GB | 16 GB | 128 GB |
| **Time** | 6-12 hours | 3 hours | 24 hours |
| **Partition** | normal | short | normal |

```bash
# Recommended configuration
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --read_based \
    --threads 16 --mem 32GB --time 8:00:00

# Minimal resources
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --read_based \
    --threads 8 --mem 16GB --time 6:00:00
```

**Best for:**
- Quick exploratory analysis
- Large sample sets where speed matters
- Systems with limited resources
- Screening samples before deeper analysis

**Typical runtime:** 4-8 hours per sample

---

### 2. Assembly-Based Analysis (`--ass_based`)

**Most resource-intensive, best viral genome recovery**

| Resource | Standard | High-Quality | Minimal |
|----------|----------|--------------|---------|
| **Threads** | 40-64 | 64-96 | 24 |
| **Memory** | 256-512 GB | 512GB-1TB | 128 GB |
| **Time** | 3-5 days | 5-7 days | 2 days |
| **Partition** | normal/highmem | highmem | normal |

```bash
# Standard assembly (recommended)
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --ass_based \
    --threads 48 --mem 256GB --time 4-00:00:00

# High-quality assembly (complex metagenomes)
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --ass_based \
    --threads 64 --mem 512GB --time 6-00:00:00 --partition highmem

# Minimal (small samples)
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --ass_based \
    --threads 24 --mem 128GB --time 2-00:00:00
```

**Best for:**
- **Viral genome recovery** (Phase 1-7 analysis)
- Publication-quality results
- Complex environmental samples
- Complete metagenomic characterization

**Typical runtime:** 2-4 days per sample
**Includes:** Automatic 7-phase viral genome analysis

---

### 3. Clustering-Based Analysis (`--clust_based`)

**Moderate resources, good for diversity studies**

| Resource | Recommended | Minimum | Maximum |
|----------|-------------|---------|---------|
| **Threads** | 24-48 | 16 | 64 |
| **Memory** | 64-128 GB | 32 GB | 256 GB |
| **Time** | 1-2 days | 12 hours | 3 days |
| **Partition** | normal | short | normal |

```bash
# Recommended configuration
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --clust_based \
    --threads 32 --mem 64GB --time 1-12:00:00

# High diversity samples
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --clust_based \
    --threads 48 --mem 128GB --time 2-00:00:00
```

**Best for:**
- OTU-based diversity analysis
- Large read datasets
- When assembly is not critical
- Rapid taxonomic profiling

**Typical runtime:** 12-24 hours per sample

---

### 4. All Methods (`ALL`)

**Comprehensive analysis - runs all three methods in parallel**

| Resource | Standard | High-Performance | Minimal |
|----------|----------|------------------|---------|
| **Threads** | 60-90 | 120+ | 40 |
| **Memory** | 256-512 GB | 512GB-1TB | 128 GB |
| **Time** | 4-6 days | 6-7 days | 3 days |
| **Partition** | highmem | highmem | normal |

```bash
# Standard comprehensive analysis
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
    --threads 60 --mem 256GB --time 5-00:00:00

# Maximum quality (large cluster nodes)
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
    --threads 120 --mem 1TB --time 7-00:00:00 --partition highmem

# Minimal (constrained resources)
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
    --threads 40 --mem 128GB --time 4-00:00:00
```

**Best for:**
- Complete sample characterization
- Cross-validation between methods
- Publication-quality comprehensive analysis
- When computational resources are available

**Thread allocation:** Automatically divided by 3 (one-third per method)
**Typical runtime:** 3-5 days per sample
**Includes:** All 3 taxonomic approaches + 7-phase viral genome analysis

---

## Complete Option Reference

### `run_pimgavir.sh` - Single Sample Launcher

```bash
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz SAMPLE METHOD [OPTIONS]
```

#### Required Arguments

| Argument | Description | Examples |
|----------|-------------|----------|
| `R1.fq.gz` | Forward reads (gzipped FASTQ) | `sample_R1.fastq.gz` |
| `R2.fq.gz` | Reverse reads (gzipped FASTQ) | `sample_R2.fastq.gz` |
| `SAMPLE` | Sample identifier | `sample1`, `ENV001` |
| `METHOD` | Analysis method | `ALL`, `--read_based`, `--ass_based`, `--clust_based` |

#### Resource Options

| Option | Default | Description | Examples |
|--------|---------|-------------|----------|
| `--threads N` | 20 | CPU threads | `16`, `32`, `64`, `96` |
| `--mem N[G\|M]` | 128GB | Memory allocation | `32GB`, `256GB`, `512GB`, `1TB` |
| `--time D-HH:MM:SS` | 3-23:59:59 | Time limit | `12:00:00`, `2-00:00:00`, `7-00:00:00` |
| `--partition NAME` | normal | SLURM partition | `normal`, `highmem`, `long` |

#### Pipeline Options

| Option | Description |
|--------|-------------|
| `--filter` | Enable host/contaminant filtering (adds Diamond BLAST step) |
| `--infiniband` | Use Infiniband scratch (`/scratch-ib/`) - IRD cluster only |

#### Notification Options

| Option | Default | Description | Examples |
|--------|---------|-------------|----------|
| `--email EMAIL` | None | Email for notifications | `user@ird.fr` |
| `--mail-type TYPE` | END,FAIL | When to notify | `NONE`, `BEGIN`, `END`, `FAIL`, `ALL` |

#### Help

| Option | Description |
|--------|-------------|
| `-h, --help` | Show detailed help message |

---

### `run_pimgavir_batch.sh` - Batch Launcher

```bash
bash scripts/run_pimgavir_batch.sh INPUT_DIR METHOD [OPTIONS]
```

#### Required Arguments

| Argument | Description | Examples |
|----------|-------------|----------|
| `INPUT_DIR` | Directory with paired FASTQ files | `/data/samples/`, `./input/` |
| `METHOD` | Analysis method (same as single) | `ALL`, `--read_based`, etc. |

#### Additional Batch Options

| Option | Default | Description |
|--------|---------|-------------|
| `--array-limit N` | 4 | Max concurrent SLURM jobs |

**All single-sample options also available**

#### File Naming Requirements

Files must be paired with these patterns:
- `sample_R1.fastq.gz` + `sample_R2.fastq.gz` ✅
- `sample_1.fq.gz` + `sample_2.fq.gz` ✅
- `sample.R1.fastq.gz` + `sample.R2.fastq.gz` ✅

---

## Special Configurations

### IRD Cluster with Infiniband

```bash
# Use Infiniband scratch for best I/O performance
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
    --infiniband --mem 256GB --partition normal
```

**Requirements:**
- Only available on IRD cluster nodes with Infiniband
- Automatically adds `--constraint=infiniband` to SLURM
- Uses `/scratch-ib/` instead of `/scratch/`
- Higher I/O throughput (128TB shared scratch)

**Batch processing:**
```bash
bash scripts/run_pimgavir_batch.sh /data/samples/ ALL \
    --infiniband --mem 512GB --array-limit 2
```

---

### With Host/Contaminant Filtering

```bash
# Enable Diamond BLAST filtering
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
    --filter --mem 384GB --time 5-00:00:00

# Batch with filtering
bash scripts/run_pimgavir_batch.sh /data/samples/ ALL \
    --filter --mem 384GB --array-limit 2
```

**Resource impact when using `--filter`:**
- **Memory:** +50-100 GB (Diamond BLAST)
- **Time:** +6-12 hours
- **Recommended:** Add 50% more memory and time

---

### Long-Running Jobs

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
| **Small** (<5M reads) | 16-32 GB | 32-64 GB | 128-256 GB | 256-384 GB |
| **Medium** (5-20M reads) | 32-64 GB | 64-128 GB | 256-512 GB | 384-768 GB |
| **Large** (20-50M reads) | 64-128 GB | 128-256 GB | 512GB-1TB | 768GB-1TB |
| **Very Large** (>50M reads) | 128-256 GB | 256-512 GB | 1TB+ | 1TB+ |

**Note:** Add 50-100 GB if using `--filter` option.

---

## Time Estimates

| Analysis Type | Small Dataset | Medium Dataset | Large Dataset |
|---------------|---------------|----------------|---------------|
| **Read-based** | 2-4 hours | 4-8 hours | 8-16 hours |
| **Assembly** | 1-2 days | 2-4 days | 4-7 days |
| **Clustering** | 8-16 hours | 1-2 days | 2-3 days |
| **All methods** | 2-3 days | 3-5 days | 5-10 days |

**Factors affecting time:**
- Read count and quality
- Metagenomic complexity
- Assembly parameters (MEGAHIT + SPAdes)
- Filtering enabled/disabled
- Viral genome analysis (Phase 1-7)

---

## Batch Processing Strategies

### Strategy 1: Conservative (Guaranteed Success)

```bash
# Start with high resources, limit concurrency
bash scripts/run_pimgavir_batch.sh /data/samples/ ALL \
    --mem 512GB \
    --threads 64 \
    --time 6-00:00:00 \
    --array-limit 2
```

**Pros:** Jobs rarely fail due to resources
**Cons:** Slower overall (less parallelization)
**Use when:** Sample complexity unknown, critical analysis

---

### Strategy 2: Aggressive (Maximum Throughput)

```bash
# Lower resources, high concurrency
bash scripts/run_pimgavir_batch.sh /data/samples/ --read_based \
    --threads 16 \
    --mem 32GB \
    --time 8:00:00 \
    --array-limit 12
```

**Pros:** Fast for large sample sets
**Cons:** May fail on complex samples
**Use when:** Simple samples, screening phase, re-running if needed is acceptable

---

### Strategy 3: Adaptive (Recommended)

```bash
# Step 1: Fast screening with read-based
bash scripts/run_pimgavir_batch.sh /data/samples/ --read_based \
    --mem 32GB --threads 16 --array-limit 8

# Step 2: Assembly on interesting samples only
bash scripts/run_pimgavir.sh interesting_R1.fq.gz interesting_R2.fq.gz sample1 --ass_based \
    --mem 512GB --threads 64 --time 5-00:00:00
```

**Pros:** Optimal resource usage, fast results, focused deep analysis
**Use when:** Large sample sets, limited resources, exploratory projects

---

## Troubleshooting Resource Issues

### Job Killed / Out of Memory (OOM)

**Symptom:** Job ends with "Killed", "Out of memory", or "Segmentation fault"

**Check memory usage:**
```bash
sacct -j JOBID --format=JobID,MaxRSS,ReqMem,State
```

**Solutions:**
```bash
# Increase memory by 50-100%
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
    --mem 512GB  # was 256GB

# For assembly specifically (most memory-intensive)
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --ass_based \
    --mem 768GB --partition highmem
```

---

### Job Timeout

**Symptom:** Job reaches time limit and is terminated

**Check elapsed time:**
```bash
sacct -j JOBID --format=JobID,Elapsed,Timelimit,State
```

**Solutions:**
```bash
# Double or triple the time limit
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
    --time 7-00:00:00  # was 3-23:59:59

# Use longer partition if available
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
    --time 10-00:00:00 --partition long
```

---

### Slow Performance

**Symptom:** Job progressing very slowly

**Possible causes and solutions:**

1. **Insufficient threads:**
   ```bash
   # Increase thread count
   bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
       --threads 96  # was 40
   ```

2. **I/O bottleneck (IRD cluster):**
   ```bash
   # Use Infiniband scratch
   bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
       --infiniband
   ```

3. **Resource contention on node:**
   ```bash
   # Use dedicated partition
   bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
       --partition highmem
   ```

4. **BLAST taking too long (read-based mode):**
   ```bash
   # Switch to assembly-based (BLAST runs on contigs, much faster)
   bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --ass_based
   ```

---

## Monitoring Jobs

### Check Job Status

```bash
# View your running jobs
squeue -u $USER

# View specific job
squeue -j JOBID

# Detailed job info
scontrol show job JOBID
```

### View Resource Usage (Running Job)

```bash
# Real-time monitoring
sstat -j JOBID --format=JobID,MaxRSS,AveCPU,AveVMSize

# Alternative: SSH to node and use htop
squeue -j JOBID -o "%N"  # Get node name
ssh nodeXXX
htop -u $USER
```

### View Resource Usage (Completed Job)

```bash
# Summary
sacct -j JOBID --format=JobID,JobName,MaxRSS,Elapsed,State

# Detailed
sacct -j JOBID --format=JobID,JobName,MaxRSS,MaxVMSize,AveCPU,Elapsed,State,ExitCode
```

### View Logs

```bash
# Standard output
tail -f logs/pimgavir_sample1_JOBID.out

# Error output
tail -f logs/pimgavir_sample1_JOBID.err

# Search for errors
grep -i "error\|fail\|killed" logs/pimgavir_sample1_JOBID.err
```

---

## Practical Examples

### Example 1: Quick Viral Screening (Many Samples)

```bash
bash scripts/run_pimgavir_batch.sh /data/samples/ --read_based \
    --threads 16 \
    --mem 32GB \
    --time 8:00:00 \
    --array-limit 12 \
    --email user@ird.fr \
    --mail-type END
```

**Use case:** Screening 50+ samples for viral presence
**Resources:** Low (16 threads, 32GB)
**Concurrency:** High (12 samples at once)
**Expected completion:** 8-12 hours total

---

### Example 2: High-Quality Viral Genomes (Publication)

```bash
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --ass_based \
    --threads 64 \
    --mem 512GB \
    --time 6-00:00:00 \
    --partition highmem \
    --filter \
    --email user@ird.fr \
    --mail-type ALL
```

**Use case:** Complete viral genome recovery for publication
**Resources:** High (64 threads, 512GB)
**Includes:** Phase 1-7 viral genome analysis + filtering
**Expected completion:** 4-6 days

---

### Example 3: Comprehensive Metagenomic Study

```bash
bash scripts/run_pimgavir_batch.sh /data/project/ ALL \
    --threads 60 \
    --mem 384GB \
    --time 5-00:00:00 \
    --array-limit 3 \
    --infiniband \
    --filter \
    --email user@ird.fr \
    --mail-type END,FAIL
```

**Use case:** All methods + filtering on 10-20 samples
**Resources:** High (60 threads, 384GB)
**Concurrency:** Low (3 samples, resource-intensive)
**Expected completion:** 2-3 weeks total

---

### Example 4: Resource-Limited Environment

```bash
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 --read_based \
    --threads 8 \
    --mem 16GB \
    --time 12:00:00 \
    --partition short
```

**Use case:** Running on nodes with limited capacity
**Resources:** Minimal (8 threads, 16GB)
**Expected completion:** 8-12 hours

---

## Testing Without Submission (Dry Run)

```bash
# Test configuration without submitting job
DRY_RUN=true bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
    --mem 512GB --threads 64

# Output shows SLURM command that would be submitted
```

---

## Best Practices

### 1. Start Conservative
Begin with recommended resources, adjust if needed based on monitoring

### 2. Monitor First Job
Check resource usage of first sample before launching full batch

### 3. Use Array Limits Wisely
- Assembly jobs: 2-4 concurrent (resource-intensive)
- Read-based: 8-16 concurrent (lighter)
- Consider cluster fairshare policies

### 4. Email Notifications
Always enable for long-running jobs (>1 day)

### 5. Document Commands
Keep command history for reproducibility
```bash
# Save commands to file
history | grep run_pimgavir >> pimgavir_commands.log
```

### 6. Test Small First
Run one sample before launching full batch

### 7. Plan Partitions
Use appropriate partitions for job duration:
- `short`: < 2 hours
- `normal`: < 7 days
- `long`: > 7 days
- `highmem`: High memory nodes

---

## Migration from Old System (v2.1 and earlier)

### Before (Old System)

Had to manually edit SBATCH directives in `PIMGAVIR_worker.sh`:

```bash
# Edit script file
vim scripts/PIMGAVIR_worker.sh

# Change lines:
#SBATCH --mem=256GB
#SBATCH --cpus-per-task=40
#SBATCH --time=6-23:59:59

# Then submit
sbatch scripts/PIMGAVIR_conda.sh 40 ALL
```

**Problems:**
- ❌ Required manual script editing
- ❌ Hard to track which resources were used
- ❌ Difficult to adjust per-sample
- ❌ Risk of accidental commits with modified resources

### After (New System)

Pass resources as command-line arguments:

```bash
# No editing needed!
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
    --threads 40 --mem 256GB --time 6-00:00:00
```

**Benefits:**
- ✅ No script editing needed
- ✅ Resources documented in command
- ✅ Easy per-sample customization
- ✅ Command history = reproducibility
- ✅ No risk of accidental commits

### Backward Compatibility

Old commands still work but are deprecated:
```bash
# Still works (legacy mode)
sbatch scripts/PIMGAVIR_conda.sh R1.fq.gz R2.fq.gz sample1 40 ALL
```

Migrate to new system for better control:
```bash
# New recommended way
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL --threads 40
```

---

## Summary

The new launcher scripts provide **complete flexibility** for resource configuration:

- ✅ **No script editing required** - All options via command line
- ✅ **Per-sample customization** - Different resources per sample
- ✅ **Batch processing support** - Process multiple samples easily
- ✅ **Clear documentation** - All options in help message
- ✅ **Email notifications** - Stay informed of job status
- ✅ **Infiniband support** - IRD cluster optimization
- ✅ **Backward compatible** - Old commands still work
- ✅ **Reproducible** - Commands in shell history

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

## Additional Documentation

- **[README.md](README.md)** - Quick start guide
- **[CLAUDE.md](CLAUDE.md)** - Complete technical documentation
- **[OUTPUT_FILES.md](OUTPUT_FILES.md)** - Output file reference
- **[VIRAL_GENOME_QUICKSTART.md](VIRAL_GENOME_QUICKSTART.md)** - Viral genome analysis
- **[CHANGELOG.md](CHANGELOG.md)** - Version history

---

**For questions or issues:**
- GitHub: https://github.com/ltalignani/PIMGAVIR-v2/issues
- Email: loic.talignani@ird.fr
- Cluster support: ndomassi.tando@ird.fr

---

**Document version:** 2.2.2
**Last updated:** 2025-11-05
**Maintained by:** Loïc Talignani (IRD, iTrop)
