# Conda Environment Inheritance Fix

**Date**: 2025-11-03
**Version**: PIMGAVir v2.2
**Status**: ✅ FIXED

## Problem Description

### Symptoms
- Pipeline failing with `trim_galore: commande introuvable` (command not found)
- TrimGalore and other conda tools not found despite conda environment being activated
- Error occurred in pre-process step and would affect all subsequent steps

### Root Cause
When the worker script calls processing scripts using `bash script.sh`, it creates a **new subprocess shell** that does NOT inherit the parent shell's conda environment activation.

```bash
# INCORRECT - creates subprocess without conda environment
bash pre-process_conda.sh $R1 $R2 $SampleName $JTrim $METHOD

# In the subprocess:
which trim_galore  # Returns nothing - not in PATH!
```

Even though the worker script had activated the conda environment with:
```bash
conda activate pimgavir_viralgenomes
```

...the subprocess created by `bash` doesn't inherit this activation.

## Solution

Replace all `bash script.sh` calls with `source script.sh` to execute scripts in the **current shell** instead of creating a subprocess.

```bash
# CORRECT - executes in current shell, inherits conda environment
source pre-process_conda.sh $R1 $R2 $SampleName $JTrim $METHOD

# In the same shell:
which trim_galore  # Returns: /path/to/conda/envs/pimgavir_viralgenomes/bin/trim_galore
```

## Files Modified

### 1. PIMGAVIR_worker.sh
Replaced 13 occurrences of `bash` with `source`:
- Line 261: `source assembly.sh`
- Line 263: `source taxonomy_conda.sh` (assembly-based, MEGAHIT)
- Line 264: `source krona-blast_conda.sh` (assembly-based, SPAdes)
- Line 265: `source taxonomy_conda.sh` (assembly-based, SPAdes)
- Line 266: `source krona-blast_conda.sh` (assembly-based, MEGAHIT)
- Line 273: `source viral-genome-complete-7phases.sh` (MEGAHIT)
- Line 287: `source viral-genome-complete-7phases.sh` (SPAdes)
- Line 302: `source clustering.sh`
- Line 303: `source taxonomy_conda.sh` (clustering-based)
- Line 304: `source krona-blast_conda.sh` (clustering-based)
- Line 337: `source pre-process_conda.sh`
- Line 366: `source reads-filtering.sh`
- Line 392: `source taxonomy_conda.sh` (read-based, parallel)
- Line 407: `source taxonomy_conda.sh` (read-based, single)
- Line 409: `source krona-blast_conda.sh` (read-based, single)

### 2. PIMGAVIR_worker_ib.sh
Applied identical changes (15 replacements) for Infiniband-optimized worker.

## Technical Details

### Why `source` instead of `bash`?

| Command | Effect | Conda Environment | Use Case |
|---------|--------|-------------------|----------|
| `bash script.sh` | Creates new subprocess | ❌ NOT inherited | Independent scripts |
| `source script.sh` | Executes in current shell | ✅ Inherited | Scripts needing environment |

### Conda Environment Activation

When you activate a conda environment:
```bash
conda activate pimgavir_viralgenomes
```

It modifies the **current shell's** environment variables:
- `PATH`: Prepends `/path/to/conda/envs/pimgavir_viralgenomes/bin`
- `CONDA_DEFAULT_ENV`: Set to `pimgavir_viralgenomes`
- `CONDA_PREFIX`: Set to environment path
- Many other environment variables for libraries, etc.

A subprocess created with `bash` starts fresh and doesn't inherit these modifications.

### Background Jobs
Note that background jobs (`&`) still work correctly with `source`:
```bash
source taxonomy_conda.sh $args & ##It will run in bg mode
```

The `&` makes the sourced script run in the background, but it still inherits the conda environment.

## Verification

To verify the fix works, check that tools are found:
```bash
# After conda activation in worker script
which trim_galore   # Should show conda path
which bbduk.sh      # Should show conda path
which kraken2       # Should show conda path
which megahit       # Should show conda path
```

## Impact

**Before fix**: Pipeline would fail immediately at pre-process step.

**After fix**: All processing scripts (pre-process, taxonomy, assembly, clustering, reads-filtering, krona-blast, viral-genome analysis) now correctly inherit the conda environment and can find all required tools.

## Related Fixes

This fix was part of a series of improvements:
1. **BUGFIX_REPORT_DIRECTORY.md**: Added `mkdir -p report` to scripts
2. **DATABASE_OPTIMIZATION.md**: Use NAS databases directly (rsync with exclusions)
3. **CONDA_ENVIRONMENT_INHERITANCE_FIX.md**: This fix - use `source` instead of `bash`

## Testing

After applying this fix, test with:
```bash
cd /projects/large/PIMGAVIR/pimgavir_dev/
sbatch scripts/PIMGAVIR_conda.sh input/sample_R1.fastq.gz input/sample_R2.fastq.gz TestSample 40 --read_based
```

Check the output logs to verify:
- TrimGalore runs successfully
- BBDuk runs successfully
- Kraken2 and Kaiju run successfully
- No "command not found" errors

## References

- Bash `source` documentation: https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Builtins.html
- Conda environment activation: https://docs.conda.io/projects/conda/en/latest/user-guide/tasks/manage-environments.html
- Related to issue: Environment setup in HPC SLURM jobs
