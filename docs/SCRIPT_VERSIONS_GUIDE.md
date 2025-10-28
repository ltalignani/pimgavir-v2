# PIMGAVir Script Versions Guide

## Issues Identified in Original Version

The `pimgavir_dev.sh` script (now `PIMGAVIR.sh`) had several issues in its initial configuration:

### 1. Inconsistent System Modules/Conda Mix

**Before** (problematic):
```bash
module purge
#module load FastQC/0.11.9  # Commented but...
#module load cutadapt/3.1
module load seqkit/2.1.0     # ...some still active
module load python/3.8.12

# Then conda activation
conda activate pimgavir      # Potential conflicts
```

### 2. Confusing Environment Logic

**Before**:
```bash
if ls ~/miniconda3/etc/profile.d/conda.sh 2> /dev/null
then
    conda activate pimgavir          # One name
else
    # Automatic miniconda installation (!!)
    conda activate pimgavir_env      # Different name
fi
```

**Issues**:
- Automatic miniconda installation (inappropriate for HPC)
- Inconsistent environment names
- No error handling if environment doesn't exist

### 3. Hardcoded Paths

In called scripts, paths like:
```bash
ktImportTaxonomy=${HOME}"/miniconda3/envs/pimgavir/bin/ktImportTaxonomy"
```

## Developed Solutions

### Option 1: PIMGAVIR.sh (Improved Hybrid Version)

**Improved conda logic**:
```bash
# Try to find conda installation
if [ -f "${HOME}/miniconda3/etc/profile.d/conda.sh" ]; then
    source "${HOME}/miniconda3/etc/profile.d/conda.sh"
elif [ -f "${HOME}/anaconda3/etc/profile.d/conda.sh" ]; then
    source "${HOME}/anaconda3/etc/profile.d/conda.sh"
elif [ -f "/opt/miniconda3/etc/profile.d/conda.sh" ]; then
    source "/opt/miniconda3/etc/profile.d/conda.sh"
else
    echo "Warning: Conda not found. Using system modules only."
fi

# Try environments in order of preference
if conda env list | grep -q "pimgavir_complete"; then
    conda activate pimgavir_complete    # Recommended
elif conda env list | grep -q "pimgavir_env"; then
    conda activate pimgavir_env         # Legacy
elif conda env list | grep -q "pimgavir"; then
    conda activate pimgavir             # Legacy
else
    echo "Warning: No conda environment found. Using system tools."
fi
```

**Advantages**:
- Backward compatibility with old environments
- Graceful fallback to system modules if conda unavailable
- Improved error handling

### Option 2: PIMGAVIR_conda.sh (Pure Conda Version)

**Fully conda configuration**:
```bash
# Purge all system modules to avoid conflicts
module purge

# Activate conda environment - all tools are included
if [ -f "${HOME}/miniconda3/etc/profile.d/conda.sh" ]; then
    source "${HOME}/miniconda3/etc/profile.d/conda.sh"
# ... other paths ...
else
    echo "Error: Cannot find conda installation"
    exit 1
fi

# Activate the complete PIMGAVir environment
conda activate pimgavir_complete

# Verify activation
if [ $? -ne 0 ]; then
    echo "Error: Failed to activate pimgavir_complete environment"
    exit 1
fi
```

**Advantages**:
- No conflicts between system modules and conda
- Cleaner and more predictable configuration
- Better reproducibility

## Conda-Adapted Scripts Created

### Main Scripts
1. `pre-process_conda.sh` - Preprocessing without system modules
2. `taxonomy_conda.sh` - Taxonomic classification with conda
3. `krona-blast_conda.sh` - Krona visualization with conda

### Key Differences
- Removal of all `module load/unload` commands
- Direct use of conda tools (e.g., `ktImportTaxonomy` instead of absolute paths)
- Improved error handling

## Usage Recommendations

### For New Users
1. **Install the complete environment**:
   ```bash
   ./setup_conda_env_fast.sh
   ```

2. **Use the pure conda version**:
   ```bash
   sbatch PIMGAVIR_conda.sh R1.fastq.gz R2.fastq.gz sample 40 ALL
   ```

### For Existing Users
1. **Progressive migration**:
   - Use `PIMGAVIR.sh` (improved hybrid version)
   - Install `pimgavir_complete` when possible
   - Migrate to `PIMGAVIR_conda.sh` after testing

2. **Compatibility**:
   - `PIMGAVIR.sh` automatically detects available environment
   - Fallback to system modules if conda unavailable

## Summary of Improvements

| Aspect | Original Version | PIMGAVIR.sh | PIMGAVIR_conda.sh |
|--------|-----------------|-------------|-------------------|
| **System modules** | Inconsistent mix | Intelligent fallback | None (purge) |
| **Conda environment** | Confusing logic | Multiple detection | Single environment |
| **Error handling** | Basic | Improved | Robust |
| **Reproducibility** | Low | Medium | High |
| **Performance** | Variable | Good | Optimal |
| **Maintenance** | Difficult | Medium | Easy |

## Recommended Next Steps

1. **Test**: Validate `PIMGAVIR_conda.sh` with a sample
2. **Migration**: Progressively replace old scripts
3. **Documentation**: Update user documentation
4. **Training**: Inform users of new practices
