# Conda Environment Setup - SLURM Batch Mode

**Version**: 2.1
**Date**: 2025-11-04
**Status**: ✅ READY FOR USE

## Overview

The `setup_conda_env_fast.sh` script can now be run in **SLURM batch mode** to create the complete PIMGAVir conda environment on the cluster with proper resources allocated.

## Why Use Batch Mode?

Creating the complete conda environment requires:
- **Time**: 15-30 minutes with mamba, up to 90 minutes with conda
- **Memory**: Up to 32 GB during package resolution
- **Network**: Downloading ~8-10 GB of packages

Running via SLURM ensures:
- ✅ Sufficient resources allocated
- ✅ No interruption from SSH disconnection
- ✅ Proper logging of installation process
- ✅ Can run overnight without monitoring

## Usage

### Method 1: SLURM Batch (Recommended)

```bash
# On the cluster, from project root
cd /projects/large/PIMGAVIR/pimgavir_dev/

# Submit as SLURM job
sbatch scripts/setup_conda_env_fast.sh
```

**What happens in batch mode:**
- Automatically removes and recreates environment if it exists (no prompts)
- Installs BLAST taxonomy database automatically (~500 MB)
- Skips viral genome databases (too long - run separately)
- Runs for up to 2 hours on `short` partition
- Outputs to: `setup_pimgavir_env_<JOBID>.out/err`

### Method 2: Interactive (Local testing)

```bash
# On your local machine or in interactive session
cd scripts/
bash setup_conda_env_fast.sh
```

**What happens in interactive mode:**
- Prompts before removing existing environment
- Asks if you want to install BLAST taxdb
- Asks if you want to install viral databases
- Can be interrupted and resumed

## SLURM Configuration

The script includes these SLURM directives:

```bash
#SBATCH --job-name=setup_pimgavir_env
#SBATCH --partition=short           # 2-hour time limit
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4           # Parallel package downloads
#SBATCH --mem=32GB                  # For package resolution
#SBATCH --time=02:00:00             # Maximum 2 hours
#SBATCH --output=setup_pimgavir_env_%j.out
#SBATCH --error=setup_pimgavir_env_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=your.email@ird.fr
```

**Note**: Update `--mail-user` in the script with your email address.

## What Gets Installed

The `pimgavir_viralgenomes` environment includes:

### Core Pipeline Tools (Essential)
- **Quality Control**: TrimGalore, cutadapt, FastQC, BBDuk
- **Taxonomy**: Kraken2, Kaiju, Krona
- **Assembly**: MEGAHIT, SPAdes, QUAST, Bowtie2, SAMtools, Pilon
- **Alignment**: BLAST+, Diamond
- **Utilities**: vsearch, seqkit, taxonkit, parallel

### Viral Genome Analysis Tools (Phases 1-7)
- **Phase 1**: VirSorter2, CheckV, vRhyme, Prodigal-gv
- **Phase 2**: DRAM (functional annotation)
- **Phase 3**: MAFFT, trimAl, IQ-TREE, MrBayes, RAxML-NG
- **Phase 4**: MMseqs2, CD-HIT, vConTACT2, geNomad, Mash
- **Phase 5**: Host prediction tools (CRISPR, tRNA, k-mer)
- **Phase 6**: Zoonotic assessment tools
- **Phase 7**: R packages for visualization and reporting

### Total Size
- **Environment**: ~8-10 GB
- **Installation time**: 15-30 minutes (mamba) or 45-90 minutes (conda)

## Monitoring Progress

```bash
# Check job status
squeue -u $USER

# View output in real-time (once job starts)
tail -f setup_pimgavir_env_<JOBID>.out

# Check for errors
tail -f setup_pimgavir_env_<JOBID>.err
```

## Verification

After the job completes, verify the environment:

```bash
# Activate the environment
conda activate pimgavir_viralgenomes

# Check key tools
which trim_galore
which bbduk.sh
which kraken2
which megahit
which virsorter
which DRAM-setup.py

# List all installed packages
conda list | head -50
```

## Troubleshooting

### Job Fails During Package Resolution

**Symptom**: Error during conda/mamba package resolution
**Solution**: Increase memory to 64GB in SLURM header

```bash
#SBATCH --mem=64GB
```

### Environment Already Exists Error

**In batch mode**: The script automatically removes and recreates the environment.

**If you want to keep existing environment**: Run interactively instead:
```bash
bash scripts/setup_conda_env_fast.sh
```

### Mamba Not Available

The script automatically falls back to conda if mamba is not installed. To speed up future installations, install mamba:

```bash
conda install -n base -c conda-forge mamba
```

### Installation Times Out

If installation takes longer than 2 hours (rare), increase time limit:

```bash
#SBATCH --time=03:00:00
```

Or switch to a different partition with longer time limits.

## What About Viral Genome Databases?

The batch mode **skips** viral genome database setup because it's very time-consuming (4-8 hours) and requires ~170 GB of downloads.

**To setup viral databases separately** (after environment is created):

### Option A: Interactive Setup
```bash
# SSH to cluster
conda activate pimgavir_viralgenomes
cd /projects/large/PIMGAVIR/pimgavir_dev/scripts/

# Step 1: Apply DRAM HTTPS fix
bash DRAM_FIX.sh

# Step 2: Setup databases (interactive, can take 4-8 hours)
bash setup_viral_databases.sh
```

### Option B: SLURM Batch (Recommended)
```bash
# Submit as separate long-running job
sbatch --partition=long --time=12:00:00 --mem=16GB \
       --wrap="conda activate pimgavir_viralgenomes && cd /projects/large/PIMGAVIR/pimgavir_dev/scripts && bash DRAM_FIX.sh && bash setup_viral_databases.sh"
```

## Expected Output

### Successful Installation Log

```
==========================================
PIMGAVir Environment Setup
==========================================

Running in SLURM batch mode (Job ID: 123456)

This script will create the unified PIMGAVir conda environment:
  - Environment: pimgavir_viralgenomes
  - Includes: All core tools + viral genome analysis (7 phases)
  - Size: ~8-10 GB
  - Time: ~15-30 minutes with mamba, ~45-90 min with conda

Using mamba for faster installation...

BATCH MODE: Automatically removing and recreating environment...
Removing existing environment...

Creating conda environment from pimgavir_viralgenomes.yaml...
This may take 15-30 minutes with mamba (longer with conda)...

[... package download and installation progress ...]

Environment created successfully!

Activating environment pimgavir_viralgenomes...
Environment activated: pimgavir_viralgenomes

==========================================
Configuring Krona Taxonomy Database
==========================================

Downloading and installing Krona taxonomy database...
✓ Krona taxonomy database successfully configured

==========================================
Testing Tool Installation
==========================================

Core pipeline tools:
  ✓ kraken2
  ✓ kaiju
  ✓ ktImportTaxonomy
  ✓ megahit
  ✓ spades.py
  ✓ blastn
  ✓ diamond
  ✓ bbduk.sh

Viral genome analysis tools:
  ✓ virsorter
  ✓ checkv
  ✓ prodigal-gv
  ✓ vrhyme
  ✓ DRAM-setup.py
  ✓ mafft
  ✓ iqtree
  ✓ genomad
  ✓ vcontact2

==========================================
BLAST Taxonomy Database Setup
==========================================

BATCH MODE: Automatically installing BLAST taxonomy database...
Downloading taxdb.tar.gz from NCBI...
✓ BLAST taxonomy database successfully installed

==========================================
Viral Genome Databases Setup
==========================================

BATCH MODE: Skipping viral genome databases setup
  To setup viral databases, run separately:
  1. bash scripts/DRAM_FIX.sh
  2. bash scripts/setup_viral_databases.sh

==========================================
Setup Complete!
==========================================

Your unified PIMGAVir conda environment is ready!

Environment name: pimgavir_viralgenomes
```

## Next Steps

After successful environment creation:

1. **Test the environment**:
   ```bash
   conda activate pimgavir_viralgenomes
   which trim_galore kraken2 megahit virsorter
   ```

2. **Setup viral databases** (if needed for viral genome analysis):
   ```bash
   bash scripts/DRAM_FIX.sh
   bash scripts/setup_viral_databases.sh
   ```

3. **Run the pipeline**:
   ```bash
   sbatch scripts/PIMGAVIR_conda.sh \
          input/sample_R1.fastq.gz \
          input/sample_R2.fastq.gz \
          MySample 40 ALL
   ```

## Comparison: Interactive vs Batch Mode

| Feature | Interactive Mode | Batch Mode (SLURM) |
|---------|------------------|-------------------|
| User prompts | Yes (asks before actions) | No (automatic) |
| Remove existing env | Asks user | Automatic |
| BLAST taxdb | Asks user | Automatic install |
| Viral databases | Asks user | Skipped (run separately) |
| SSH disconnect safe | ❌ No | ✅ Yes |
| Resource allocation | Uses current session | Dedicated SLURM resources |
| Logging | Terminal only | .out and .err files |
| Best for | Local testing | Cluster installation |

## Related Documentation

- **CLAUDE.md**: Main project documentation
- **CONDA_MIGRATION_GUIDE.md**: Migration from old environments
- **setup_viral_databases.sh**: Viral genome database setup
- **DRAM_FIX.sh**: DRAM HTTPS fix prerequisite

## Support

If you encounter issues:

1. Check the `.err` file for error messages
2. Verify conda is properly initialized on the cluster
3. Check available disk space: `df -h $HOME`
4. Check conda cache: `conda clean --all --dry-run`
5. Contact cluster admin if conda is not available

## Version History

- **v2.1** (2025-11-04): Added SLURM batch mode support
- **v2.0** (2025-11-03): Unified environment (viralgenomes only)
- **v1.0** (2024): Original version with multiple environments
