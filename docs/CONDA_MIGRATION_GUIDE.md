# PIMGAVir Conda Migration Guide

## Issues Identified with Current Configuration

1. **Mixed system modules/conda**: The pipeline currently uses a mixture of system modules (`module load`) and conda tools

2. **Deficient Krona configuration**: Krona requires post-installation configuration that was not automated

3. **Missing dependencies**: Several tools were absent from existing conda environments

4. **Hardcoded paths**: Scripts used absolute paths to conda tools

## New Approach: Complete Conda Configuration

### 1. New Complete Conda Environment

**File**: `pimgavir_complete.yaml`

- Includes all tools necessary for the pipeline
- Recent and compatible versions
- Consistent configuration

### 2. Automated Setup Script

**File**: `setup_conda_env_fast.sh`

- Creates conda environment automatically (uses mamba if available)
- Configures Krona with taxonomy database
- Offers BLAST taxonomy database installation
- Tests all tools after installation
- Automatic fallback to `pimgavir_minimal` if installation fails

### 3. Conda-Adapted Scripts

**New files created**:

- `pre-process_conda.sh`: Version without module loading
- `taxonomy_conda.sh`: Uses conda tools directly
- `krona-blast_conda.sh`: Corrected Krona configuration

## Installation Instructions

### Step 1: Environment Setup

```bash
cd scripts/
./setup_conda_env_fast.sh
```

### Step 2: Environment Activation

```bash
conda activate pimgavir_complete
```

### Step 3: Krona Verification

```bash
# Test Krona configuration
ktImportTaxonomy -h
ktUpdateTaxonomy.sh --only-build  # If not done automatically
```

## Advantages of This Approach

1. **Reproducibility**: All tools are versioned in conda

2. **Portability**: Works on different clusters without dependency on system modules

3. **Maintenance**: Easier to update versions

4. **Configured Krona**: Taxonomy database installed automatically

5. **No conflicts**: Avoids conflicts between system and conda versions

## Migrating Existing Scripts

### Option 1: Progressive Replacement

1. Use the new `*_conda.sh` scripts
2. Test with a sample
3. Progressively replace old scripts

### Option 2: Modifying Existing Scripts

1. Remove `module load/unload` commands
2. Replace hardcoded paths with tool names
3. Ensure conda environment is activated

## Tools Included in Complete Environment

- **Preprocessing**: fastqc, cutadapt, trim-galore, bbmap
- **Taxonomy**: kraken2, kaiju, krona (with automatic configuration)
- **Assembly**: megahit, spades, quast, bowtie2, samtools, pilon
- **Analysis**: blast, diamond, prokka, vsearch, seqkit, seqtk
- **Utilities**: taxonkit, parallel, rsync, wget, pigz
- **Bio-Python**: biopython, numpy, pandas

## Troubleshooting

### Krona Issues

If Krona doesn't work:

```bash
conda activate pimgavir_complete
ktUpdateTaxonomy.sh
```

### Tool Verification

```bash
conda activate pimgavir_complete
which kraken2 kaiju ktImportTaxonomy megahit blastn
```

### Permission Issues

```bash
chmod +x scripts/setup_conda_env_fast.sh
chmod +x scripts/*_conda.sh
```

## Usage Example

```bash
# Initial setup (one time only)
./scripts/setup_conda_env_fast.sh

# For each use
conda activate pimgavir_complete
sbatch PIMGAVIR.sh R1.fastq.gz R2.fastq.gz sample 40 ALL
```
