# Infiniband Optimization Guide for PIMGAVir

This guide explains the Infiniband-optimized versions of the PIMGAVir pipeline for the IRD cluster.

## Overview

The IRD cluster provides a high-performance Infiniband scratch storage system (`/scratch-ib/`) with:
- **Capacity**: 128TB shared scratch space
- **Network**: High-bandwidth Infiniband network
- **Performance**: Superior I/O compared to local `/scratch/`
- **Access**: Via bioinfo-san.ird.fr (san-ib alias)

## Script Variants Comparison

| Script | Scratch | Tools | Infiniband | Recommended For |
|--------|---------|-------|------------|-----------------|
| `PIMGAVIR.sh` | `/scratch/` | System modules + conda | No | Generic HPC systems |
| `PIMGAVIR_conda.sh` | `/scratch/` | Pure conda | No | Non-IRD clusters |
| `PIMGAVIR_ib.sh` | `/scratch-ib/` | System modules + conda | Yes | IRD cluster (hybrid) |
| `PIMGAVIR_conda_ib.sh` | `/scratch-ib/` | Pure conda | Yes | **IRD cluster (best)** |

## Key Modifications in Infiniband Scripts

### 1. SLURM Configuration

**Standard scripts**:
```bash
#SBATCH --partition=highmem
```

**Infiniband scripts**:
```bash
#SBATCH --partition=highmem
#SBATCH --constraint=infiniband
```

### 2. Scratch Directory

**Standard**: `/scratch/${USER}_${SLURM_JOB_ID}`
**Infiniband**: `/scratch-ib/${USER}_${SLURM_JOB_ID}`

### 3. Data Transfers

**Standard**:
```bash
scp -r /projects/large/PIMGAVIR/pimgavir_dev/ ${SCRATCH_DIRECTORY}
scp -r scripts/ $PATH_TO_SAVE
```

**Infiniband** (optimized for high-speed network):
```bash
scp -r san-ib:/projects/large/PIMGAVIR/pimgavir_dev/ ${SCRATCH_DIRECTORY}
scp -r scripts/ san-ib:$PATH_TO_SAVE
```

## Usage Examples

### Recommended: Pure Conda + Infiniband

```bash
# Submit to IRD cluster with Infiniband optimization
sbatch PIMGAVIR_conda_ib.sh reads_R1.fastq.gz reads_R2.fastq.gz MySample 40 ALL

# With filtering enabled
sbatch PIMGAVIR_conda_ib.sh reads_R1.fastq.gz reads_R2.fastq.gz MySample 40 ALL --filter

# Single method
sbatch PIMGAVIR_conda_ib.sh reads_R1.fastq.gz reads_R2.fastq.gz MySample 40 --read_based
```

### Alternative: Hybrid + Infiniband

```bash
# Uses system modules where available, falls back to conda
sbatch PIMGAVIR_ib.sh reads_R1.fastq.gz reads_R2.fastq.gz MySample 40 ALL
```

## Performance Benefits

### I/O Performance
- **Standard /scratch/**: Local node storage, variable performance
- **Infiniband /scratch-ib/**: Shared high-speed storage, consistent performance
- **Expected improvement**: 2-5x faster for large dataset transfers

### Scalability
- Standard scratch limited by local node capacity
- Infiniband scratch provides 128TB shared space
- Better for very large metagenomic datasets (>100GB)

### Network Transfers
- `san-ib:` alias uses Infiniband network directly
- Avoids network bottlenecks during data staging
- Faster initial data transfer and final results copying

## Prerequisites

### 1. Verify Infiniband Availability

```bash
# Check if your node supports Infiniband
srun -p short --constraint=infiniband --pty bash -i

# Test /scratch-ib access
cd /scratch-ib
mkdir test_${USER}
ls -la
rm -rf test_${USER}
```

### 2. Test san-ib Connectivity

```bash
# Test file transfer via Infiniband
scp -r san-ib:/projects/large/PIMGAVIR/README.md /tmp/
```

### 3. Conda Environment

Ensure you have the conda environment set up:

```bash
cd scripts/
./setup_conda_env_fast.sh  # Installs pimgavir_complete or pimgavir_minimal
```

## Troubleshooting

### Error: "No nodes available with constraint: infiniband"

**Solution**: Your partition may not have Infiniband nodes. Use standard scripts instead:
```bash
sbatch PIMGAVIR_conda.sh [arguments...]
```

### Error: "Permission denied: /scratch-ib/"

**Solution**: Contact cluster administrator (ndomassi.tando@ird.fr) to verify access rights.

### Error: "san-ib: Name or service not known"

**Solution**:
1. Verify you're on the IRD cluster
2. Check network connectivity: `ping bioinfo-san.ird.fr`
3. Use standard paths instead: `/projects/large/PIMGAVIR/...`

### Slower than Expected

**Possible causes**:
1. Network congestion (check with cluster admin)
2. Many concurrent jobs using /scratch-ib
3. Small dataset (overhead not worth it for <10GB)

**Recommendation**: For datasets <10GB, standard `/scratch/` may be faster due to lower latency.

## When to Use Which Script

### Use Infiniband Scripts When:
✅ Running on IRD cluster
✅ Dataset size >10GB
✅ Multiple samples processed in batch
✅ High I/O workload (assembly, clustering)
✅ Node capacity concerns with local scratch

### Use Standard Scripts When:
✅ Running on non-IRD clusters
✅ Dataset size <10GB
✅ Infiniband nodes unavailable
✅ Testing/debugging (faster job start)

## References

- [IRD Cluster Infiniband Documentation](https://bioinfo.ird.fr/index.php/how-to-utiliser-le-scratch-mutualise/)
- Contact: ndomassi.tando@ird.fr for Infiniband support

## Version History

- **v2.0 (Oct 2025)**: Initial Infiniband optimization
  - Created `PIMGAVIR_ib.sh` and `PIMGAVIR_conda_ib.sh`
  - Integrated san-ib alias for transfers
  - Added SLURM Infiniband constraints
