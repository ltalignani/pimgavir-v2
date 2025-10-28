# PIMGAVir Setup Guide

## Quick Start (Recommended)

### One-Command Setup

```bash
cd scripts/
./setup_conda_env_fast.sh
```

This script will:
1. ✅ Detect and use mamba (faster) or fall back to conda
2. ✅ Create `pimgavir_complete` environment (or `pimgavir_minimal` if complete fails)
3. ✅ Configure Krona taxonomy database automatically
4. ✅ **Prompt to install BLAST taxonomy database** (~500 MB)
5. ✅ Test all critical tools
6. ✅ Display setup summary

### Interactive Prompts

During setup, you'll see:

```
Setting up BLAST taxonomy database...
This enables BLAST to display organism names instead of just taxid numbers

Do you want to install BLAST taxonomy database (~500 MB download)? [Y/n]:
```

**Recommendations:**
- Press **Enter** or **Y** to install (recommended for complete functionality)
- Press **n** to skip (you can install later with `./setup_blast_taxdb.sh`)

---

## What Gets Installed

### Conda Environment

**Option 1: pimgavir_complete** (recommended)
```yaml
- Python 3.9
- Quality control: fastqc, cutadapt, trim-galore, bbmap
- Taxonomic classification: kraken2, kaiju, krona
- Assembly: megahit, spades, quast, bowtie2, samtools, pilon
- Sequence analysis: blast, diamond, prokka, vsearch, seqkit
- Utilities: taxonkit, parallel, rsync, wget, pigz, pbzip2
- Python packages: biopython, numpy, pandas
```

**Option 2: pimgavir_minimal** (fallback, faster)
```yaml
- Essential tools only
- No prokka, quast, or auxiliary tools
- Faster installation (~50% reduction)
```

### Database Components

#### 1. Krona Taxonomy Database
- **Size**: ~150 MB
- **Purpose**: Interactive HTML visualization of taxonomic classifications
- **Installation**: Automatic (via `ktUpdateTaxonomy.sh`)
- **Location**: Within conda environment

#### 2. BLAST Taxonomy Database
- **Size**: ~500 MB
- **Purpose**: Resolves taxids to organism names in BLAST results
- **Installation**: Optional prompt during setup
- **Location**: `DBs/NCBIRefSeq/`
- **Can skip**: Yes (install later with `./setup_blast_taxdb.sh`)

---

## Setup Workflow

### Visual Flow

```
START
  |
  v
Check for mamba/conda
  |
  v
Create conda environment
  ├─> Try pimgavir_complete
  └─> Fallback to pimgavir_minimal (if needed)
  |
  v
Activate environment
  |
  v
Configure Krona taxonomy database
  |
  v
Test tools (kraken2, kaiju, blast, etc.)
  |
  v
[INTERACTIVE] Install BLAST taxdb? [Y/n]
  ├─> Y: Download and install taxdb (~500 MB)
  └─> n: Skip (can install later)
  |
  v
Display summary
  |
  v
DONE ✓
```

---

## Post-Setup

### Activate Environment

```bash
conda activate pimgavir_complete
# or
conda activate pimgavir_minimal
```

### Verify Installation

All tools should show ✓:
```bash
which kraken2        # ✓ kraken2 - OK
which kaiju          # ✓ kaiju - OK
which ktImportTaxonomy  # ✓ ktImportTaxonomy - OK
which megahit        # ✓ megahit - OK
which blastn         # ✓ blastn - OK
which diamond        # ✓ diamond - OK
which bbduk.sh       # ✓ bbduk.sh - OK
```

### Check BLAST Taxdb

```bash
ls -lh ../DBs/NCBIRefSeq/taxdb.*
```

Expected output if installed:
```
-rw-r--r-- 1 user group 447M Oct 28 12:00 taxdb.btd
-rw-r--r-- 1 user group  56M Oct 28 12:00 taxdb.bti
```

---

## Manual Database Installation

### If You Skipped BLAST Taxdb

Install anytime with:
```bash
cd scripts/
./setup_blast_taxdb.sh
```

The script is interactive and provides progress updates:
```
========================================
BLAST Taxonomy Database Setup
========================================

BLASTDB directory: /path/to/DBs/NCBIRefSeq

Step 1: Downloading taxdb.tar.gz from NCBI...
This may take several minutes (file size: ~500 MB)

✓ Download successful

Step 2: Extracting taxdb archive...
✓ Extraction successful

Step 3: Verifying extracted files...
✓ taxdb.bti found
✓ taxdb.btd found

Step 4: Cleaning up...
✓ Removed taxdb.tar.gz

========================================
Setup complete!
========================================
```

---

## Troubleshooting

### Environment Creation Failed

**Problem**: `conda env create` fails
**Solutions**:
1. Check internet connectivity
2. Update conda: `conda update conda`
3. Install mamba: `conda install -c conda-forge mamba`
4. Try minimal environment: `mamba env create -f pimgavir_minimal.yaml`

### Krona Database Failed

**Problem**: `ktUpdateTaxonomy.sh` fails
**Solutions**:
```bash
conda activate pimgavir_complete
ktUpdateTaxonomy.sh --only-build
```

### BLAST Taxdb Download Failed

**Problem**: Download interrupted or failed
**Solutions**:
1. Check internet connectivity
2. Try manual download:
   ```bash
   cd DBs/NCBIRefSeq/
   wget https://ftp.ncbi.nlm.nih.gov/blast/db/taxdb.tar.gz
   tar -xzf taxdb.tar.gz
   rm taxdb.tar.gz
   ```
3. Verify files exist: `ls -lh taxdb.*`

### BLAST Warning Still Appears

**Problem**: Warning persists after taxdb installation

**Check 1**: Verify taxdb files exist
```bash
ls -lh DBs/NCBIRefSeq/taxdb.*
```

**Check 2**: Verify BLASTDB is set (automatic in pipeline scripts)
```bash
echo $BLASTDB
# Should output: /path/to/DBs/NCBIRefSeq
```

**Solution**: The pipeline scripts automatically set `BLASTDB`. If running BLAST manually, export:
```bash
export BLASTDB="/path/to/DBs/NCBIRefSeq"
```

---

## Alternative: Manual Setup

### Step-by-Step

```bash
# 1. Create environment
cd scripts/
mamba env create -f pimgavir_complete.yaml

# 2. Activate
conda activate pimgavir_complete

# 3. Configure Krona
ktUpdateTaxonomy.sh

# 4. Install BLAST taxdb
./setup_blast_taxdb.sh

# 5. Verify
which kraken2 kaiju blastn
```

---

## Environment Comparison

| Feature | pimgavir_complete | pimgavir_minimal | pimgavir_env (legacy) |
|---------|-------------------|------------------|----------------------|
| Install time (mamba) | ~15-20 min | ~5-10 min | ~20-30 min |
| Disk space | ~5 GB | ~3 GB | ~6 GB |
| Core tools | ✅ All | ✅ All | ✅ All (outdated) |
| Prokka | ✅ | ❌ | ✅ |
| QUAST | ✅ | ❌ | ✅ |
| Auto Krona setup | ✅ | ✅ | ❌ |
| Auto BLAST taxdb prompt | ✅ | ✅ | ❌ |
| Version pinning | ✅ Recent | ⚠️ Flexible | ⚠️ 2022 |
| Maintenance | ✅ Active | ✅ Active | ❌ Deprecated |

**Recommendation**: Use `pimgavir_complete` for full functionality.

---

## Next Steps

After successful setup:

1. **Test the pipeline** on a small dataset:
   ```bash
   sbatch PIMGAVIR_conda.sh test_R1.fastq.gz test_R2.fastq.gz test 4 --read_based
   ```

2. **Check documentation**:
   - `CLAUDE.md`: Comprehensive usage guide
   - `README.md`: Quick reference
   - `CHANGELOG.md`: Recent changes

3. **Configure for your cluster** (if needed):
   - Adjust SLURM parameters in pipeline scripts
   - Set up scratch directories
   - Configure email notifications

---

## Support

- **Issues**: Report at GitHub repository
- **Questions**: Check `CLAUDE.md` for detailed documentation
- **Updates**: Pull latest changes regularly
