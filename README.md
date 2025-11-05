# PIMGAVir v2.2

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-2.2-blue.svg)](https://github.com/ltalignani/PIMGAVIR-v2)

**PIMGAVir** (Pipeline for Identification and Metagenomic Analysis of Viral sequences) is a comprehensive viral metagenomic analysis pipeline for high-performance computing (HPC) environments.

## Overview

PIMGAVir identifies and characterizes viruses from environmental samples using **three complementary approaches**:

1. **Read-based taxonomy**: Direct Kraken2/Kaiju classification
2. **Assembly-based taxonomy**: MEGAHIT + SPAdes → classification
3. **Clustering-based taxonomy**: VSEARCH OTU clustering → classification

Plus **🆕 7-phase viral genome analysis** (v2.2): Recovery → Annotation → Phylogenetics → Comparative genomics → Host prediction → Zoonotic assessment → Publication reports

## Key Features

- ✅ **SLURM batch processing**: Multi-sample automation with array jobs
- ✅ **Unified conda environment**: All 200+ tools in one environment
- ✅ **Fast setup**: SLURM batch mode installation (SSH-disconnect safe)
- ✅ **Database optimization**: Direct NAS access (saves ~170 GB + 25-55 min per job)
- ✅ **Dual assemblers**: MEGAHIT + metaSPAdes for optimal viral genome recovery
- ✅ **Complete viral analysis**: 7 phases from recovery to publication
- ✅ **Infiniband support**: Optimized for IRD cluster (128TB shared scratch)
- ✅ **Smart BLAST**: Auto-skips large files (>5 GB) in read-based mode

## Quick Start

### 1. Clone Repository

```bash
git clone https://github.com/ltalignani/PIMGAVIR-v2.git
cd PIMGAVIR-v2
```

### 2. Install Environment

**On HPC Cluster (Recommended)**

```bash
# Submit installation as SLURM job (SSH-disconnect safe)
sbatch scripts/setup_conda_env_fast.sh

# Monitor progress (15-90 min)
tail -f setup_pimgavir_env_<JOBID>.out

# Verify installation
conda activate pimgavir_viralgenomes
which trim_galore kraken2 megahit virsorter
```

**Locally (Testing)**

```bash
cd scripts/
bash setup_conda_env_fast.sh
# Follow prompts
```

**Resources**: 128GB RAM, 16 CPUs, 2h time (completes in 15-90 min)

### 3. Setup Databases

**Core databases** (Krona, BLAST taxdb): ✅ Installed automatically in batch mode

**Viral genome databases** (VirSorter2, CheckV, DRAM - 170 GB, 4-8 hours):

```bash
# iTrop cluster: DRAM fix required first
sbatch --partition=long --time=12:00:00 --mem=16GB \
       --wrap="source ~/miniconda3/etc/profile.d/conda.sh && \
               conda activate pimgavir_viralgenomes && \
               cd /projects/large/PIMGAVIR/pimgavir_dev/scripts && \
               bash DRAM_FIX.sh && \
               bash setup_viral_databases.sh"
```

**Interactive mode** (use screen/tmux):

```bash
srun -p normal -c 16 --mem=128GB --pty bash -i
cd scripts/
bash DRAM_FIX.sh               # iTrop cluster only (ssh/ftp issues)
bash setup_viral_databases.sh  # 4-8 hours
```

### 4. Run Pipeline

**Single sample**:

```bash
# Standard execution
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz Sample1 ALL

# With custom resources (256GB RAM, 64 threads)
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz Sample1 ALL \
    --mem 256GB --threads 64

# IRD cluster with Infiniband
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz Sample1 ALL --infiniband
```

**Batch mode** (multiple samples):

```bash
# Auto-detect all samples in directory
bash scripts/run_pimgavir_batch.sh /path/to/samples/ ALL

# With custom resources and concurrency limit
bash scripts/run_pimgavir_batch.sh /path/to/samples/ ALL \
    --mem 256GB --threads 64 --array-limit 4

# Assembly-based (best for large datasets >5 GB)
bash scripts/run_pimgavir_batch.sh /path/to/samples/ --ass_based \
    --mem 512GB --time 5-00:00:00
```

## What's New in v2.2

### 🦠 7-Phase Viral Genome Analysis

Runs automatically after assembly (phases 1-7):

1. **Recovery**: VirSorter2 → CheckV → vRhyme (viral genome identification)
2. **Annotation**: DRAM-v (functional genes, AMG detection)
3. **Phylogenetics**: MAFFT → IQ-TREE → MrBayes (evolutionary trees)
4. **Comparative**: geNomad → MMseqs2 → vConTACT2 (taxonomy networks)
5. **Host prediction**: CRISPR/tRNA/k-mer/protein (4 complementary methods)
6. **Zoonotic assessment**: Furin sites, RBD detection, risk scoring (0-100)
7. **Publication reports**: Figures (PDF/PNG), tables (TSV), methods, HTML

**Output**: `viral-genomes-megahit/` and `viral-genomes-spades/` with publication-ready results

See [`VIRAL_GENOME_QUICKSTART.md`](VIRAL_GENOME_QUICKSTART.md) for details.

### ⚡ Performance Optimizations

- **Database access**: Direct NAS access (saves ~170 GB + 25-55 min per job)
- **SLURM installation**: Robust, uninterrupted environment setup
- **Smart BLAST**: Auto-skips large files (>5 GB) in read-based mode
- **Unified environment**: Single `pimgavir_viralgenomes` (was 3 environments)

### 🔧 iTrop Cluster Support

- **DRAM HTTPS fix**: `DRAM_FIX.sh` for SSL certificate / ftp issues
- **Infiniband scripts**: `*_ib.sh` for 128TB shared scratch
- **Batch installation**: Pre-configured SLURM headers for `normal` partition

## Installation Details

### What Gets Installed

| Component | Size | Batch Mode | Interactive | Time |
|-----------|------|------------|-------------|------|
| **Environment** | 8-10 GB | ✅ Auto | ✅ Auto | 15-90 min |
| **Krona taxonomy** | 200 MB | ✅ Auto | ✅ Auto | 5 min |
| **BLAST taxdb** | 500 MB | ✅ Auto | ❓ Prompts | 5 min |
| **VirSorter2** | 10 GB | ⏭️ Skipped | ❓ Prompts | 30 min |
| **CheckV** | 1.5 GB | ⏭️ Skipped | ❓ Prompts | 10 min |
| **DRAM-v** | 150 GB | ⏭️ Skipped | ❓ Prompts | 3-6 hours |
| **RVDB** | 5 GB | ⏭️ Skipped | ❓ Prompts | 20 min |

**Batch mode**: Installs environment + core databases, skips viral databases (too long)
**Interactive mode**: Prompts for each optional database
**Viral databases**: Best installed separately via SLURM batch (see step 3 above)

### Environment Contents

**Core pipeline** (~100 packages):
- Quality control: TrimGalore, cutadapt, FastQC, BBDuk
- Taxonomy: Kraken2, Kaiju, Krona
- Assembly: MEGAHIT, SPAdes, QUAST, Bowtie2, SAMtools, Pilon
- Alignment: BLAST+, Diamond, vsearch
- Utilities: seqkit, taxonkit, parallel

**Viral analysis** (~100 packages):
- Phase 1: VirSorter2, CheckV, vRhyme, Prodigal-gv
- Phase 2: DRAM (KOfam, Pfam, VOG annotation)
- Phase 3: MAFFT, trimAl, IQ-TREE, MrBayes, RAxML-NG
- Phase 4: geNomad, MMseqs2, vConTACT2, CD-HIT, Mash
- Phase 5: minced (CRISPR), tRNAscan-SE, EMBOSS, bedtools
- Phase 6-7: R (ggplot2, pheatmap, vegan, ape), Python (matplotlib, seaborn, ete3)

## Usage Examples

### Process Multiple Samples (Batch Mode)

```bash
# Auto-detect samples in directory
bash scripts/run_pimgavir_batch.sh /data/samples/ ALL

# Samples detected: sample1, sample2, sample3...
# Launches SLURM array job
# Results: results/<JOBID>_<sample>_ALL/
```

### Assembly-Based Only (Large Datasets >5 GB)

```bash
# Recommended for large samples - BLAST runs on contigs (much faster)
bash scripts/run_pimgavir_batch.sh /data/samples/ --ass_based \
    --mem 512GB --threads 64

# Includes automatic viral genome analysis (7 phases)
# Results: viral-genomes-megahit/ and viral-genomes-spades/
```

### With Host Filtering

```bash
# Filter out host/unwanted sequences with Diamond BLAST
bash scripts/run_pimgavir_batch.sh /data/samples/ ALL --filter \
    --mem 384GB  # Add extra memory for filtering
```

### IRD Cluster (Infiniband)

```bash
# Uses 128TB shared scratch, high-speed I/O
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample ALL --infiniband
```

## Output Structure

```
results/<JOBID>_<SampleName>_<METHOD>/
├── read-based-taxonomy/          # Kraken2, Kaiju results
│   ├── kraken2_output.txt
│   ├── kaiju_output.txt
│   └── krona_plot.html
├── assembly-based/               # MEGAHIT + SPAdes assemblies
│   ├── megahit/
│   ├── spades/
│   └── polished/
├── clustering-based/             # VSEARCH OTU clustering
│   ├── otus.fasta
│   └── taxonomy/
├── viral-genomes-megahit/        # 7-phase viral analysis (MEGAHIT)
│   ├── phase1_recovery/
│   ├── phase2_annotation/
│   ├── phase3_phylogenetics/
│   ├── phase4_comparative/
│   ├── phase5_host_ecology/
│   ├── phase6_zoonotic/
│   └── phase7_publication_report/
├── viral-genomes-spades/         # 7-phase viral analysis (SPAdes)
└── report/                       # Logs and processing reports
```

See [`OUTPUT_FILES.md`](OUTPUT_FILES.md) for complete file listing.

## Troubleshooting

### Environment Installation Fails

```bash
# Check logs
cat setup_pimgavir_env_<JOBID>.err

# Common fixes:
# - Increase memory: --mem=256GB
# - Increase time: --time=12:00:00
# - Clean conda cache: conda clean --all
```

### DRAM Database Download Fails (iTrop Cluster)

```bash
# SSL certificate / ftp issues - apply fix first
cd scripts/
bash DRAM_FIX.sh

# Then retry
bash setup_viral_databases.sh
```

### Pipeline Fails: "command not found"

```bash
# Verify environment activation
conda activate pimgavir_viralgenomes
which trim_galore bbduk.sh kraken2

# If missing tools, recreate environment
conda env remove -n pimgavir_viralgenomes
cd scripts/
sbatch setup_conda_env_fast.sh
```

### BLAST Takes Too Long

```bash
# For large samples (>5 GB), use assembly-based mode instead
# BLAST runs on contigs (much faster than reads)
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample --ass_based
```

### Resource Configuration Issues

```bash
# Check resource recommendations
cat RESOURCE_CONFIGURATION_GUIDE.md

# Common fixes:
# - Increase memory: --mem 512GB
# - Increase time: --time 7-00:00:00
# - Use high-memory partition: --partition highmem
```

## Requirements

- **HPC cluster** with SLURM job scheduler
- **Conda/Mamba** package manager
- **Disk space**:
  - Environment: ~10 GB
  - Databases: ~170 GB (core) + ~170 GB (viral, optional)
  - Scratch: ~50-100 GB per sample
- **Memory**: 128-256 GB for large samples
- **CPUs**: 16+ recommended

## Citation

If you use PIMGAVir in your research, please cite:

```
Talignani L, et al. (2025). PIMGAVir v2.2: A comprehensive pipeline for viral
metagenomic analysis with complete genome characterization.
GitHub: https://github.com/ltalignani/PIMGAVIR-v2
```

## Documentation

### User Guides
- **[RESOURCE_CONFIGURATION_GUIDE.md](RESOURCE_CONFIGURATION_GUIDE.md)**: Resource allocation guide for run_pimgavir scripts
- **[CONDA_ENVIRONMENT_SETUP_BATCH.md](docs/CONDA_ENVIRONMENT_SETUP_BATCH.md)**: Detailed installation guide
- **[VIRAL_GENOME_QUICKSTART.md](VIRAL_GENOME_QUICKSTART.md)**: Viral genome analysis guide
- **[OUTPUT_FILES.md](OUTPUT_FILES.md)**: Complete output file reference

### Technical Documentation
- **[CLAUDE.md](CLAUDE.md)**: Complete technical documentation
- **[CHANGELOG.md](CHANGELOG.md)**: Version history and updates
- **[BLAST_SKIP_SOLUTION.md](docs/BLAST_SKIP_SOLUTION.md)**: BLAST optimization details
- **[INFINIBAND_SETUP.md](docs/INFINIBAND_SETUP.md)**: IRD cluster Infiniband configuration

## Support

- **Issues**: https://github.com/ltalignani/PIMGAVIR-v2/issues
- **Email**: loic.talignani@ird.fr
- **Cluster support** (iTrop/IRD): ndomassi.tando@ird.fr

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

**Version**: 2.2
**Last updated**: 2025-11-04
**Maintained by**: Loïc Talignani (IRD, iTrop)
