# PIMGAVir v2

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**PIMGAVir** (Pipeline for Identification and Metagenomic Analysis of Viral sequences) is a comprehensive viral metagenomic analysis pipeline designed for high-performance computing (HPC) environments with SLURM job scheduler.

## Overview

PIMGAVir identifies viruses from environmental samples using three complementary approaches:

- **Read-based taxonomy**: Direct classification of reads using Kraken2 and Kaiju
- **Assembly-based taxonomy**: Assembly of contigs followed by classification
- **Clustering-based taxonomy**: OTU clustering followed by classification

## Features

- ✅ **SLURM integration**: Optimized for HPC clusters
- ✅ **Conda environments**: Complete dependency management
- ✅ **Fast installation**: Automated setup with mamba support
- ✅ **Quality control**: TrimGalore, rRNA removal with BBDuk
- ✅ **Multiple assemblers**: MEGAHIT and SPAdes for redundancy
- ✅ **Visualization**: Krona plots and BLAST reports
- ✅ **Scratch management**: Automatic data transfer for cluster environments

## Quick Start

### 1. Clone the repository
```bash
git clone https://github.com/ltalignani/PIMGAVIR-v2.git
cd PIMGAVIR-v2
```

### 2. Setup conda environment
```bash
cd scripts/
./setup_conda_env_fast.sh
```

### 3. Activate environment
```bash
conda activate pimgavir_minimal
# or: conda activate pimgavir_complete
```

### 4. Run the pipeline
```bash
sbatch PIMGAVIR.sh R1.fastq.gz R2.fastq.gz SampleName 40 ALL [--filter]
```

## Installation Options

### Recommended: Fast Setup
Uses mamba for rapid installation:
```bash
./scripts/setup_conda_env_fast.sh
```

### Manual Setup
```bash
# Minimal environment (essential tools only)
mamba env create -f scripts/pimgavir_minimal.yaml

# Complete environment (all tools)
mamba env create -f scripts/pimgavir_complete.yaml
```

## Usage Examples

```bash
# Full pipeline with all methods
sbatch PIMGAVIR.sh sample_R1.fastq.gz sample_R2.fastq.gz sample01 40 ALL

# Single method execution
sbatch PIMGAVIR.sh sample_R1.fastq.gz sample_R2.fastq.gz sample01 40 --read_based

# With host filtering
sbatch PIMGAVIR.sh sample_R1.fastq.gz sample_R2.fastq.gz sample01 40 ALL --filter
```

## Pipeline Architecture

### Core Modules
- `PIMGAVIR.sh`: Main SLURM job script and pipeline orchestrator
- `pre-process.sh`: Quality trimming and rRNA removal
- `reads-filtering.sh`: Host/unwanted sequence removal
- `assembly.sh`: Genome assembly using MEGAHIT and SPAdes
- `clustering.sh`: OTU clustering with VSEARCH
- `taxonomy.sh`: Taxonomic classification with Kraken2/Kaiju
- `krona-blast.sh`: Visualization and BLAST annotation

### Dependencies
All tools are available in conda environments:
- **Quality control**: fastqc, cutadapt, trim-galore
- **rRNA removal**: bbmap (BBDuk)
- **Taxonomic classification**: kraken2, kaiju, krona
- **Assembly**: megahit, spades, quast, bowtie2, samtools
- **Sequence analysis**: blast, diamond, prokka, vsearch
- **Utilities**: seqkit, parallel, rsync, pigz

## Requirements

- **HPC cluster** with SLURM scheduler
- **Conda/Mamba** package manager
- **Memory**: 256GB recommended
- **Storage**: Fast scratch filesystem for temporary data
- **Runtime**: ~7 days for large datasets

## Output Structure

```
results/
├── read-based-taxonomy/     # Direct read classification
├── assembly-based/          # Assembly and classification
├── clustering-based/        # OTU clustering and classification
└── report/                  # Logs and processing reports
```

## Documentation

- [`CONDA_MIGRATION_GUIDE.md`](scripts/CONDA_MIGRATION_GUIDE.md): Migration from system modules
- [`INSTALL_SUMMARY.md`](scripts/INSTALL_SUMMARY.md): Installation troubleshooting
- [`SCRIPT_VERSIONS_GUIDE.md`](scripts/SCRIPT_VERSIONS_GUIDE.md): Script variants explanation

## Citation

If you use PIMGAVir in your research, please cite:

```
[Citation to be added]
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## Support

- 📧 Issues: [GitHub Issues](https://github.com/ltalignani/PIMGAVIR-v2/issues)
- 📖 Documentation: See `scripts/` directory
- 💬 Questions: Open a discussion on GitHub

## Acknowledgments

- BBDuk for efficient rRNA removal
- Kraken2 and Kaiju for taxonomic classification
- MEGAHIT and SPAdes for assembly
- Krona for interactive visualizations