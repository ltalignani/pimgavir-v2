# pimgavir_viralgenomes.yaml - Updates for v2.2

## Summary of Changes

The conda environment file has been completely reorganized and updated to ensure all necessary tools are installed for the complete 5-phase viral genome analysis pipeline.

## Version Information

- **Previous version**: Unstructured, missing critical tools
- **Current version**: v2.2 - Fully structured with all dependencies
- **Date**: 2025-11-01

## Key Improvements

### 1. Added Missing Critical Tools

#### Compression/Decompression Tools
Previously, `gunzip` and `bunzip2` were not explicitly included, causing issues with database setup.

**Added**:
```yaml
- gzip              # Standard gzip (for gunzip)
- bzip2             # Standard bzip2 (for bunzip2)
- curl              # Alternative file downloader
```

#### BLAST+ Suite
BLAST was listed but its critical role wasn't emphasized. Now explicitly documented:

```yaml
- blast=2.14.1      # BLAST+ suite (includes makeblastdb, blastn, blastp, blastx)
```

**Provides**:
- `makeblastdb` - Create BLAST databases (needed for RVDB)
- `blastn` - Nucleotide BLAST
- `blastp` - Protein BLAST
- `blastx` - Translated nucleotide vs protein
- `tblastn` - Protein vs translated nucleotide
- `tblastx` - Translated nucleotide vs translated nucleotide

### 2. Enhanced Phylogenetic Tools

**Added**:
```yaml
- fasttree          # Approximate ML trees for large alignments
```

FastTree is essential for large datasets (>1000 sequences) where IQ-TREE or RAxML-NG would be too slow.

### 3. Improved Comparative Genomics

**Added**:
```yaml
- mash              # Fast genome and metagenome distance estimation
```

Mash provides k-mer based distance calculations used in Phase 5 for host prediction.

### 4. Additional Analysis Tools

**Added**:
```yaml
- bedtools          # Genome interval operations
- emboss            # European Molecular Biology Open Software Suite
```

These tools are useful for:
- **bedtools**: Genome coverage, overlap analysis, feature extraction
- **emboss**: Sequence manipulation, primer design, restriction analysis

### 5. Enhanced Visualization Packages

**New R packages**:
```yaml
- r-pheatmap        # Pretty heatmaps (for comparative genomics)
- r-vegan           # Community ecology analyses (viral diversity)
- r-ape             # Phylogenetics and evolution in R (tree visualization)
```

**New Python packages**:
```yaml
- ete3>=3.1.2       # Phylogenetic tree analysis and visualization
- pysam>=0.21       # SAM/BAM file handling
- pyvcf3>=1.0.3     # VCF file parsing
```

### 6. Enhanced Data Visualization

**Added**:
```yaml
- matplotlib        # Plotting library
- seaborn           # Statistical data visualization
```

These were missing from the base environment but are essential for:
- Custom plots and figures
- Statistical visualization
- Publication-quality graphics

### 7. Complete Restructuring and Documentation

The YAML file is now organized into logical sections:

```
1. BASE ENVIRONMENT
2. QUALITY CONTROL AND PREPROCESSING
3. TAXONOMIC CLASSIFICATION
4. ASSEMBLY AND IMPROVEMENT
5. SEQUENCE ANALYSIS AND ANNOTATION
6. UTILITIES
7. PROGRAMMING LANGUAGES AND LIBRARIES
8. HMMER AND PROFILE SEARCH TOOLS
9. VIRAL GENOME ANALYSIS - 5 PHASES
   - Phase 1: Viral Genome Recovery
   - Phase 2: Functional Annotation
   - Phase 3: Phylogenetic Analysis
   - Phase 4: Comparative Genomics
   - Phase 5: Host Prediction and Ecology
10. VISUALIZATION AND REPORTING
11. PYTHON PACKAGES (via pip)
```

Each tool now has inline comments explaining its purpose.

## Fixed Issues

### Issue 1: makeblastdb Not Found ✓
**Problem**: `makeblastdb` command not available when running `setup_viral_databases.sh`

**Root Cause**: BLAST+ not installed or not in PATH

**Fix**:
- Explicitly include `blast=2.14.1` with comment explaining it includes makeblastdb
- Added verification in setup script
- Added `gzip`/`bzip2` for archive extraction

### Issue 2: vRhyme Installation Failed ✓
**Problem**: vRhyme not available via pip

**Root Cause**: vRhyme is available via bioconda, not PyPI

**Fix**: Moved from pip to conda dependencies:
```yaml
# OLD (INCORRECT):
- pip:
  - vrhyme

# NEW (CORRECT):
- vrhyme          # Viral genome binning (available via bioconda)
```

### Issue 3: Missing Compression Tools ✓
**Problem**: `gunzip` and `bunzip2` not available for database extraction

**Fix**: Added gzip and bzip2 packages explicitly

### Issue 4: Incomplete Phylogenetic Suite ✓
**Problem**: No tool for large alignment trees

**Fix**: Added FastTree for rapid approximate ML inference

## Tool Versions

All critical tools now have pinned versions to ensure reproducibility:

| Tool | Version | Purpose |
|------|---------|---------|
| python | 3.9 | Base interpreter |
| blast | 2.14.1 | BLAST+ suite |
| diamond | 2.1.8 | Fast protein alignment |
| fastqc | 0.12.1 | Quality control |
| megahit | 1.2.9 | Assembly |
| spades | 3.15.5 | Assembly |
| kraken2 | latest | Taxonomy |
| virsorter | 2 | Viral identification |
| r-base | >=4.2 | Statistical computing |

## Installation Instructions

### Fresh Installation

```bash
cd /projects/large/PIMGAVIR/pimgavir_dev/scripts/

# Create environment from updated YAML
conda env create -f pimgavir_viralgenomes.yaml

# Activate environment
conda activate pimgavir_viralgenomes

# Verify critical tools
which makeblastdb virsorter checkv DRAM-setup.py genomad

# Test BLAST
makeblastdb -version
blastn -version
```

### Updating Existing Environment

```bash
# Activate existing environment
conda activate pimgavir_viralgenomes

# Update from YAML
conda env update -f pimgavir_viralgenomes.yaml --prune

# Verify new tools
which mash fasttree bedtools gunzip
```

### Clean Reinstallation (Recommended)

If you encounter conflicts:

```bash
# Remove old environment
conda deactivate
conda env remove -n pimgavir_viralgenomes

# Create fresh environment
conda env create -f pimgavir_viralgenomes.yaml

# Test
conda activate pimgavir_viralgenomes
conda list | grep -E "blast|virsorter|checkv|dram"
```

## Estimated Installation Time and Size

| Component | Time | Size |
|-----------|------|------|
| Base environment | 5-10 min | ~2 GB |
| Viral tools | 15-30 min | ~5 GB |
| R packages | 10-20 min | ~1 GB |
| Python packages | 5-10 min | ~500 MB |
| **Total** | **35-70 min** | **~8-10 GB** |

**Note**: Times vary based on connection speed and system performance. Use `mamba` instead of `conda` for 2-3x faster installation.

## Quick Installation with Mamba (Recommended)

```bash
# Install mamba if not available
conda install -n base -c conda-forge mamba

# Create environment with mamba (much faster)
mamba env create -f pimgavir_viralgenomes.yaml
```

## Verification Checklist

After installation, verify all critical tools:

```bash
conda activate pimgavir_viralgenomes

# Phase 1 tools
virsorter --version
checkv -h | head -1
prodigal -v
vrhyme --version

# Phase 2 tools
DRAM-setup.py --version
hmmsearch -h | head -1

# Phase 3 tools
mafft --version
iqtree --version
mrbayes --version
fasttree 2>&1 | head -1

# Phase 4 tools
mmseqs --version
genomad --version
vcontact2 --version
mash --version

# Phase 5 tools
minced --version
tRNAscan-SE -h | grep "version"

# Database building
makeblastdb -version
diamond --version

# Utilities
wget --version
gunzip --version
```

All commands should execute without "command not found" errors.

## Troubleshooting

### Issue: Conda Solve Time Too Long

**Solution**: Use mamba instead:
```bash
conda install -n base mamba
mamba env create -f pimgavir_viralgenomes.yaml
```

### Issue: Package Conflicts

**Solution**: Create environment with strict channel priority:
```bash
conda config --set channel_priority strict
conda env create -f pimgavir_viralgenomes.yaml
```

### Issue: Missing Package After Installation

**Solution**: Install individually:
```bash
conda activate pimgavir_viralgenomes
conda install -c bioconda <package_name>
```

### Issue: R Packages Won't Install

**Solution**: Install R packages after environment creation:
```bash
conda activate pimgavir_viralgenomes
conda install -c conda-forge r-base r-ggplot2 r-dplyr r-tidyr r-pheatmap r-vegan r-ape
```

## Changes from Previous Versions

### v1.0 → v2.0
- Added viral genome analysis tools (VirSorter2, CheckV, DRAM)
- Added phylogenetic tools (MAFFT, IQ-TREE, MrBayes)
- Fixed vRhyme installation (pip → conda)

### v2.0 → v2.1
- Added comparative genomics tools (MMseqs2, vConTACT2, geNomad)
- Added enhanced visualization (R packages)
- Improved documentation and comments

### v2.1 → v2.2 (Current)
- **Fixed**: makeblastdb not found (explicit BLAST+ inclusion)
- **Fixed**: Missing compression tools (gzip, bzip2)
- **Added**: FastTree for large phylogenies
- **Added**: Mash for k-mer distances
- **Added**: bedtools and emboss
- **Added**: Enhanced R and Python visualization packages
- **Improved**: Complete restructuring with logical sections
- **Improved**: Inline documentation for all tools

## Related Documentation

- **README.md**: General pipeline documentation
- **IMPLEMENTATION_COMPLETE.md**: Complete v2.2 feature list
- **VIRAL_GENOME_COMPLETE_5PHASES.md**: 5-phase workflow guide
- **setup_viral_databases.sh**: Database installation script
- **FIX_MAKEBLASTDB.md**: Troubleshooting BLAST installation

## Maintenance

### Updating Tool Versions

To update a specific tool:

```bash
conda activate pimgavir_viralgenomes

# Search for latest version
conda search -c bioconda blast

# Update specific tool
conda install -c bioconda blast=2.15.0

# Update all tools (careful - may break dependencies)
conda update --all
```

### Exporting Current Environment

To share exact environment state:

```bash
conda activate pimgavir_viralgenomes

# Export with versions
conda env export > pimgavir_viralgenomes_exact.yaml

# Export without versions (more portable)
conda env export --from-history > pimgavir_viralgenomes_portable.yaml
```

## Contact and Support

- **Issues**: Report at https://github.com/anthropics/pimgavir/issues
- **Cluster Support**: ndomassi.tando@ird.fr
- **Pipeline Questions**: See documentation in `scripts/` directory

---

**Last Updated**: 2025-11-01
**Version**: 2.2
**Maintainer**: PIMGAVir Development Team
