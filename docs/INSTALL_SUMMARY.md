# PIMGAVir Installation - Summary

## Issue Resolved
The package `parallel=20230422` was not available in conda channels. The version was corrected to `parallel=20230522`.

## Successful Installation
The minimal environment `pimgavir_minimal` was successfully created and tested. All main tools are functional:

### ✅ Tested and Functional Tools
- ✓ kraken2 (version 2.1.6)
- ✓ kaiju (version 1.10.1)
- ✓ megahit
- ✓ diamond
- ✓ bbduk.sh
- ✓ blastn
- ✓ krona (with configured taxonomy database)

## Cluster Instructions

### 1. Quick Installation (Recommended)
```bash
cd scripts/
./setup_conda_env_fast.sh
```

### 2. Activation for Use
```bash
conda activate pimgavir_minimal
# or if the complete environment is installed:
# conda activate pimgavir_complete
```

### 3. Using on SLURM Cluster
The `PIMGAVIR.sh` script has already been adapted to automatically detect and use the conda environment. It searches in priority order:
1. `pimgavir_complete`
2. `pimgavir_env`
3. `pimgavir`

### 4. For Cluster Installation
Copy these files to the cluster:
- `scripts/pimgavir_minimal.yaml` (or `pimgavir_complete.yaml`)
- `scripts/setup_conda_env_fast.sh`

Then execute:
```bash
./setup_conda_env_fast.sh
```

## Advantages of This Solution
1. **Quick installation**: mamba used automatically if available
2. **Configured Krona**: Taxonomy database installed automatically
3. **Compatibility**: The main script `PIMGAVIR.sh` detects the conda environment automatically
4. **Fallback**: If the complete environment fails, automatic installation of minimal environment

## Available Environments
- **pimgavir_minimal**: Tested and functional environment with essential tools
- **pimgavir_complete**: Environment with all tools (in creation)

## Cluster Considerations
1. Ensure conda/mamba is available on compute nodes
2. Copy conda environment to scratch if necessary
3. The main script already copies data to `/scratch/${USER}_${SLURM_JOB_ID}`
