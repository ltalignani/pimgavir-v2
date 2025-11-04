# CHANGELOG

## [2.2.1] - 2025-11-04 - Critical Bug Fixes

### Fixed

**🔧 Variable Scoping Fix in assembly_conda.sh**
- **Fixed variable name conflict**: Variables `megahit_contigs_improved` and `spades_contigs_improved` now correctly include `.fasta` extension
  - Pilon creates files with `.fasta` extension automatically
  - Variables now match actual filenames created by Pilon
  - Prevents "0 sequences processed" error in taxonomy_conda.sh
  - Uses `_base` variables for Pilon output (without .fasta), then sets final variables with .fasta extension

**🔧 Assembly Pipeline Fixes**
- **Created `assembly_conda.sh`**: Pure conda version without system module dependencies
  - Eliminates module loading conflicts (blast/2.8.1+, MEGAHIT, SPAdes, prokka, etc.)
  - All tools use conda packages from `pimgavir_viralgenomes` environment
  - Prevents "Unable to locate modulefile" errors on HPC systems
  - Ensures consistent tool versions across different clusters

**🔧 Clustering Pipeline Fixes**
- **Created `clustering_conda.sh`**: Pure conda version without system module dependencies
  - Eliminates module loading conflicts (seqkit/2.1.0, vsearch/2.21.1)
  - All tools use conda packages from `pimgavir_viralgenomes` environment
  - Consistent with assembly_conda.sh approach
  - Prevents module-related errors in clustering-based analysis

**🔧 Reads Filtering Fixes**
- **Created `reads-filtering_conda.sh`**: Pure conda version without system module dependencies
  - Eliminates module loading conflicts (diamond/2.0.11)
  - All tools use conda packages from `pimgavir_viralgenomes` environment
  - Enables --filter option without module system dependencies

- **Fixed execution order in PIMGAVIR_worker.sh and PIMGAVIR_worker_ib.sh**:
  - **Before** (incorrect): MEGAHIT taxonomy → **SPADES krona** → SPADES taxonomy → MEGAHIT krona
  - **After** (correct): MEGAHIT taxonomy → MEGAHIT krona → SPADES taxonomy → SPADES krona
  - Prevents race conditions and file path errors
  - Each assembler now processes taxonomy first, then visualization (krona-blast)

**🎯 Impact**: These fixes resolve the errors seen in sample9 where:
- Line 1 error: `ERROR: Unable to locate a modulefile for 'blast/2.8.1+'` → Fixed by using conda tools
- Line 684 error: Missing `krakViral.out_MEGAHIT` file → Fixed by correct execution order
- Line 685 error: Cannot open `megahit_contigs_improved` → Fixed by proper file dependencies

### Changed
- `PIMGAVIR_worker.sh`: Now uses conda versions of all subscripts
  - `assembly_conda.sh` (instead of `assembly.sh`)
  - `clustering_conda.sh` (instead of `clustering.sh`)
  - `reads-filtering_conda.sh` (instead of `reads-filtering.sh`)
- `PIMGAVIR_worker_ib.sh`: Now uses conda versions of all subscripts
  - `assembly_conda.sh` (instead of `assembly.sh`)
  - `clustering_conda.sh` (instead of `clustering.sh`)
  - `reads-filtering_conda.sh` (instead of `reads-filtering.sh`)
- Both worker scripts now have correct sequential processing (taxonomy → krona-blast per assembler)
- All analysis modes (--read_based, --ass_based, --clust_based, ALL) now use pure conda tools
- The --filter option now uses conda diamond instead of module-based diamond

## [2.2.0] - 2025-11-04 - Complete 7-Phase Viral Genome Analysis + Infrastructure Improvements

### Added

#### 🆕 Phase 6: Zoonotic Risk Assessment (`viral-zoonotic-assessment.sh`)
- **Furin cleavage site detection**: Searches for R-X-[KR]-R motif and variants
  - Classic furin sites (R-X-[KR]-R)
  - Multi-basic sites (R-R-X-R, R-X-R-R)
  - Extended patterns (R-X-X-R)
  - Context analysis (±10 amino acids)
  - Python-based pattern detection with scoring

- **Receptor Binding Domain (RBD) analysis**: Identifies potential RBDs
  - Cysteine content analysis (4-8 expected for disulfide bonds)
  - Aromatic residue enrichment (receptor interaction)
  - Charged residue analysis (electrostatic interactions)
  - Size filtering (150-400 AA typical for RBDs)
  - Feature-based scoring system

- **Surface protein identification**: Detects spike, envelope, glycoproteins
  - Keyword-based search in annotations
  - Size filtering (>500 AA for large glycoproteins)
  - Glycosylation site enrichment (S+T content)

- **Zoonotic virus comparison** (optional): BLASTP against known pathogens
  - E-value threshold: 1e-5
  - Identity thresholds: High (>80%), Medium (60-80%), Low (<60%)
  - Requires user-provided zoonotic virus database

- **Risk scoring system**: Automated 0-100 point scale
  - Furin sites: 0-30 points
  - Surface proteins: 0-20 points
  - RBD candidates: 0-30 points
  - Zoonotic similarity: 0-20 points
  - Risk categories: 🔴 HIGH (≥70), 🟡 MEDIUM (40-69), 🟢 LOW (<40)

- **Comprehensive reports**: Publication-ready risk assessment
  - Detailed zoonotic risk report with interpretation
  - Per-protein furin site listings
  - RBD candidate sequences and features
  - Zoonotic similarity matches
  - Summary tables (TSV format)
  - Safety disclaimers and next steps

#### 🆕 Phase 7: Publication Report Generation (`viral-report-generation.sh`)
- **Publication-quality figures** (PDF + PNG, 300 DPI):
  - Figure 2: AMG functional heatmap (R/pheatmap, clustered)
  - Figure 3: Phylogenetic tree (R/ggtree, circular/rectangular)
  - Figure 4: Viral diversity plots (Python/matplotlib, 4-panel)
  - Figure 1 data prepared (viral recovery flowchart)

- **Supplementary tables** (TSV format, Excel-compatible):
  - Table S1: High-quality viral genomes with quality metrics
  - Table S2: AMG predictions with confidence scores
  - Table S3: Host predictions with evidence
  - Table S4: Zoonotic risk assessment per genome

- **Methods section**: Ready-to-use manuscript text
  - Complete methods for all 7 phases
  - Software versions and citations
  - Database versions
  - Parameter settings
  - Statistical analysis templates
  - Data availability statement template

- **Interactive HTML report**: Comprehensive analysis dashboard
  - Executive summary with key metrics
  - Phase-by-phase results with color coding
  - Links to all output files
  - Publication materials checklist
  - Next steps for manuscript preparation
  - Modern responsive design

- **Automated package installation**: R and Python dependencies
  - Attempts automatic installation if packages missing
  - BiocManager for Bioconductor packages
  - Graceful degradation if installation fails
  - Clear error messages

#### 🆕 Master Orchestration: `viral-genome-complete-7phases.sh`
- **Complete 7-phase workflow**: Orchestrates all phases sequentially
  - Phases 1-5: Original viral genome analysis
  - Phase 6: NEW zoonotic risk assessment
  - Phase 7: NEW publication report generation
  - Smart phase dependencies (e.g., Phase 6 requires Phase 2 proteins)

- **Flexible execution modes**:
  - Run all 7 phases (default)
  - Run specific phases only (--phases flag)
  - Optional inputs: host genomes, reference viruses, zoonotic DB
  - Graceful handling of missing optional inputs

- **Enhanced reporting**:
  - Master summary report includes all 7 phases
  - Per-phase timing statistics
  - Key output files highlighted
  - Publication-ready materials section

### Changed

#### 🚀 Infrastructure & Installation Improvements

**SLURM Batch Mode for Environment Setup** (`setup_conda_env_fast.sh` v2.1)
- **NEW**: Script can now be submitted as SLURM job for robust installation
  - SLURM header added: `normal` partition, 128GB RAM, 16 CPUs, 8h time
  - SSH-disconnect safe: continues running even if connection drops
  - Persistent logs: `.out` and `.err` files for troubleshooting
  - Fully automated: no user prompts in batch mode
  - Email notifications on completion/failure

- **Automatic vs Interactive behavior**:
  - Batch mode (via `sbatch`): Auto-removes existing env, installs BLAST taxdb, skips viral DBs
  - Interactive mode (via `bash`): Prompts for all optional components
  - Smart detection via `$SLURM_JOB_ID` environment variable

- **Configuration updated**:
  - Email: `loic.talignani@ird.fr`
  - Resources: 128GB RAM (up from 32GB), 16 CPUs (up from 4), 8h time (up from 2h)
  - Partition: `normal` (changed from `short`)

**Database Access Optimization (v2.2)**
- **Major performance improvement**: Databases accessed directly from NAS
  - Worker scripts use `rsync --exclude='DBs/'` to copy only pipeline code
  - Environment variable `PIMGAVIR_DBS_DIR` points to NAS: `/projects/large/PIMGAVIR/pimgavir_dev/DBs/`
  - All processing scripts use `${PIMGAVIR_DBS_DIR:-../DBs}` pattern
  - **Benefits**:
    * ⚡ ~25-55 min saved per job (no database transfer)
    * 💾 ~170 GB saved on scratch per job
    * 🔄 Always current (single source of truth)
    * 📊 Scalable (unlimited concurrent jobs)

- **Scripts modified for direct DB access**:
  - `pre-process_conda.sh`: SILVA rRNA databases
  - `taxonomy_conda.sh`: Kraken2, Kaiju databases
  - `krona-blast_conda.sh`: BLAST RefSeq databases
  - `reads-filtering.sh`: Diamond protein database
  - `PIMGAVIR_worker.sh` and `PIMGAVIR_worker_ib.sh`: DiamondDB path export

**Conda Environment Inheritance Fix**
- **Critical fix**: Scripts now use `source` instead of `bash` to preserve conda environment
  - Problem: `bash script.sh` creates subprocess without conda activation
  - Solution: `source script.sh` executes in current shell, preserves environment
  - **15 replacements** in `PIMGAVIR_worker.sh`:
    * Lines 261, 263-266, 273, 287, 302-304, 337, 366, 392, 407, 409
  - **15 replacements** in `PIMGAVIR_worker_ib.sh` (same locations)
  - Prevents "command not found" errors for TrimGalore, BBDuk, Kraken2, etc.

**Report Directory Fix**
- **Bug fix**: Added `mkdir -p report` to all processing scripts
  - Scripts were writing to `report/` before creating directory
  - Fixed in: `pre-process_conda.sh`, `taxonomy_conda.sh`, `assembly.sh`, `clustering.sh`, `reads-filtering.sh`
  - Prevents "No such file or directory" errors

**Environment Unification**
- **Unified environment**: Single `pimgavir_viralgenomes` replaces 3 previous environments
  - Merges `pimgavir_minimal`, `pimgavir_complete`, and adds viral tools
  - ~200-300 packages total (core pipeline + viral analysis)
  - Size: ~8-10 GB (optimal balance)

- **Deprecated environments** (moved to `scripts/deprecated/`):
  - `pimgavir_complete.yaml`
  - `pimgavir_minimal.yaml`
  - Backward compatibility maintained until May 2025
  - Migration guide: `scripts/deprecated/README.md`

**iTrop/IRD Cluster Specific**
- **DRAM HTTPS Fix** (`DRAM_FIX.sh`):
  - Patches DRAM to use HTTP instead of HTTPS for problematic downloads
  - Required only on iTrop cluster (SSL certificate issues)
  - Idempotent (safe to run multiple times)
  - Must run before `setup_viral_databases.sh`

#### Pipeline Integration
- **PIMGAVIR_worker.sh**: Updated to use `viral-genome-complete-7phases.sh`
  - Automatically runs all 7 phases after assembly
  - Separate outputs for MEGAHIT and SPAdes
  - Graceful error handling (continues even if viral analysis fails)

- **PIMGAVIR_worker_ib.sh**: Infiniband version updated
  - Same 7-phase integration as standard worker
  - Optimized for Infiniband scratch storage

#### Documentation

**README.md - Complete Restructure**
- **Completely rewritten** for clarity and conciseness (v2.2)
  - Eliminated redundancy between "Quick Start" and "Installation Options"
  - Clear hierarchy: Quick Start → What's New → Installation → Usage → Troubleshooting
  - **Installation table**: Shows what's auto-installed vs manual (batch vs interactive)
  - **iTrop cluster section**: DRAM_FIX.sh clearly documented with usage context
  - **Database sizes**: All databases with precise sizes for disk planning
  - Removed 200+ lines of duplicate content
  - Added troubleshooting section with common issues
  - Better visual organization with tables and clear sections

**CLAUDE.md - Enhanced Technical Documentation**
- **Environment Setup**: SLURM batch mode documented as primary method
  - Configuration details: partition, memory, CPUs, time limit
  - Advantages listed with checkmarks
  - Interactive mode repositioned as alternative

- **Database Setup**: Comprehensive section added
  - Core vs viral database separation
  - BLAST taxdb: automatic (batch) vs prompt (interactive)
  - Viral databases: iTrop DRAM_FIX requirement highlighted
  - Two setup options: SLURM batch (recommended) vs interactive (with screen/tmux)
  - **Installation matrix table**: Clear overview of what's auto/manual/prompt
  - Total database sizes: ~170-280 GB depending on DRAM

- **7-phase workflow**: Comprehensive documentation
  - Detailed phase descriptions in "Workflow Logic" section
  - Output structure for all phases
  - Timing estimates for complete workflow
  - Link to specialized documentation files

**NEW: VIRAL_GENOME_PHASES_6_7.md**
- Detailed guide for phases 6 & 7
- Complete usage instructions
- Output file descriptions
- Interpretation guidelines
- Troubleshooting section
- Publication checklist
- Safety notes for zoonotic findings

**NEW: VIRAL_GENOME_COMPLETE_7PHASES.md**
- Full 7-phase documentation
- Workflow summary with all phases
- Quick start examples
- Timing estimates (14.5-29 hours total)
- Output structure
- Methods section templates
- Citation information

**NEW: docs/CONDA_ENVIRONMENT_SETUP_BATCH.md**
- Comprehensive SLURM batch installation guide
- Step-by-step instructions with examples
- Monitoring and verification procedures
- Troubleshooting common issues
- Comparison: batch vs interactive modes

**NEW: updates/ directory documentation**
- `SETUP_CONDA_ENV_SLURM_SUPPORT.md`: SLURM feature summary
- `README_CLAUDE_DATABASE_DOCUMENTATION.md`: Database documentation changes
- `CONDA_ENVIRONMENT_INHERITANCE_FIX.md`: Technical details of bash→source fix

**NEW: fixes/ directory documentation**
- `BUGFIX_REPORT_DIRECTORY.md`: Report directory creation fix
- `CONDA_ENVIRONMENT_INHERITANCE_FIX.md`: Environment inheritance fix details

### Performance

#### Timing Estimates (typical ~1,000 contig sample)
- **Phase 6**: 1-2 hours
  - Furin detection: 5-10 min
  - RBD analysis: 10-20 min
  - Surface protein ID: 5-10 min
  - BLAST comparison: 30-60 min (if zoonotic DB provided)

- **Phase 7**: 30 minutes - 1 hour
  - Figure generation: 10-30 min
  - Table preparation: 5-10 min
  - Methods section: Instant (template-based)
  - HTML report: 5-10 min

- **Complete 7-Phase Workflow**: 14.5-29 hours
  - Phases 1-5: 13-26 hours (as before)
  - Phase 6: +1-2 hours
  - Phase 7: +0.5-1 hour
  - Total: ~1-1.5 days on typical HPC

### Output Structure

```
viral-genomes-megahit/
├── phase1_recovery/           # VirSorter2, CheckV, vRhyme
├── phase2_annotation/         # DRAM-v, AMG predictions
├── phase3_phylogenetics/      # Trees, alignments
├── phase4_comparative/        # vConTACT2 networks, protein clusters
├── phase5_host_ecology/       # Host predictions, diversity
├── phase6_zoonotic/           # 🆕 Risk assessment, furin sites, RBDs
│   ├── furin_sites/          # Furin cleavage site detections
│   ├── rbd_analysis/         # RBD candidates and features
│   ├── zoonotic_similarity/  # BLAST vs known pathogens
│   ├── receptor_analysis/    # Receptor binding analysis
│   └── results/              # Risk reports and summaries
├── phase7_publication_report/ # 🆕 Publication materials
│   ├── figures/              # PDF and PNG figures
│   ├── tables/               # Supplementary tables (TSV)
│   ├── methods/              # Methods section text
│   └── html_report/          # Interactive HTML report
└── final_results/            # Key files from all phases

viral-genomes-spades/         # Same structure for SPAdes
```

### Important Notes

#### Zoonotic Risk Assessment
⚠️ **Computational predictions only** - requires experimental validation
- High risk scores indicate presence of concerning features
- Do NOT confirm actual zoonotic capability
- All HIGH RISK findings (≥70 points) must be reported to:
  - Institutional biosafety committee
  - Public health authorities (if appropriate)
- BSL-3 or higher containment required for experimental work

#### Publication Reports
- Figures customizable in R/Python (scripts included)
- Tables formatted for easy Excel import
- Methods section requires adaptation to specific study
- HTML report shareable with collaborators
- All materials journal-submission ready

### Backward Compatibility
- ✅ Original 5-phase scripts remain functional
- ✅ `viral-genome-complete.sh` still available (3-phase version)
- ✅ Can run phases 1-5 only using `--phases 1,2,3,4,5`
- ✅ All previous documentation preserved
- ✅ No breaking changes to existing workflows

### Next Steps
1. Review generated HTML report (open in browser)
2. Examine zoonotic risk scores (check for HIGH alerts)
3. Customize figures for journal requirements
4. Adapt methods section to your study
5. Prepare supplementary materials

---

## [Unreleased] - 2025-10-28

### Added
- **New script**: `setup_blast_taxdb.sh` to download and install NCBI BLAST taxonomy database
  - Automatically downloads taxdb.tar.gz (~500 MB) from NCBI FTP
  - Extracts to `DBs/NCBIRefSeq/`
  - Provides clear instructions for setting BLASTDB environment variable

- **Integrated taxdb installation**: Both setup scripts now offer automatic taxdb installation
  - `setup_conda_env_fast.sh` prompts user to install taxdb during environment setup
  - `setup_conda_env.sh` prompts user to install taxdb during environment setup
  - Default answer is 'Yes' (press Enter to accept)
  - Users can skip and install manually later if needed

- **BLASTDB environment variable**: Automatically set in `krona-blast.sh` and `krona-blast_conda.sh`
  - Prevents warning: "Taxonomy name lookup from taxid requires installation of taxdb database"
  - Enables BLAST to display organism names instead of just taxid numbers

- **Taxdb presence check**: Both krona-blast scripts now verify taxdb installation
  - Displays helpful warning if taxdb is not found
  - Provides instructions to install using `setup_blast_taxdb.sh`
  - Pipeline continues even if taxdb is missing (taxids still available)

- **Documentation**: Added comprehensive taxdb setup instructions
  - Updated CLAUDE.md with database setup section
  - Added troubleshooting section for BLAST taxonomy warnings
  - Updated README.md with database setup instructions

### Fixed
- **HTML file naming**: Fixed incorrect suffix placement in taxonomy output files
  - Before: `krakViral.krona.html_READ` (invalid extension)
  - After: `krakViral.krona_READ.html` (valid, browser-compatible)
  - Affects: `taxonomy.sh`, `taxonomy_conda.sh`

### Removed
- **Obsolete script**: `taxonomy-gzip.sh` deleted
  - Kraken2 2.0.8+ automatically detects gzipped files
  - The `--gzip-compressed` flag is no longer necessary
  - All pipeline scripts now use `taxonomy.sh` or `taxonomy_conda.sh` directly

- **Redundant script**: `setup_conda_env.sh` deleted
  - `setup_conda_env_fast.sh` does everything `setup_conda_env.sh` did and more
  - `setup_conda_env_fast.sh` auto-detects mamba (faster) and falls back to conda
  - `setup_conda_env_fast.sh` has automatic fallback to `pimgavir_minimal` if installation fails
  - Uses modern conda activation methods
  - All documentation now references only `setup_conda_env_fast.sh`

### Changed
- **Pipeline scripts updated**: Replaced all `taxonomy-gzip.sh` calls
  - `PIMGAVIR.sh` (line 302): `taxonomy-gzip.sh` → `taxonomy.sh`
  - `PIMGAVIR_ib.sh` (line 303): `taxonomy-gzip.sh` → `taxonomy.sh`
  - `PIMGAVIR_conda.sh` (line 293): `taxonomy-gzip.sh` → `taxonomy_conda.sh`
  - `PIMGAVIR_conda_ib.sh` (line 292): `taxonomy-gzip.sh` → `taxonomy_conda.sh`

### Deprecated
- **environment.yaml**: Marked as DEPRECATED with warning header
  - Uses outdated packages from 2022 (samtools 1.6 → 1.17, blast 2.12 → 2.14, etc.)
  - 253 lines with verbose Perl module specifications
  - Difficult to maintain compared to modern environments
  - **Kept for backward compatibility** with existing `pimgavir_env` installations
  - Users strongly encouraged to migrate to `pimgavir_complete.yaml` or `pimgavir_minimal.yaml`

## Summary of Changes

### Benefits
1. **Better HTML output**: Taxonomy HTML files now have valid extensions and open directly in browsers
2. **Cleaner codebase**: Removed redundant `taxonomy-gzip.sh` script
3. **Improved BLAST output**: Taxdb enables human-readable organism names in results
4. **Better documentation**: Clear instructions for database setup and troubleshooting
5. **Automated setup**: New script simplifies taxdb installation

### Migration Notes
- **No breaking changes**: All modifications are backward-compatible
- **Existing environments**: `pimgavir_env` users can continue using their environment (fallback support maintained)
- **HTML files**: Old HTML files with incorrect extensions need manual renaming to open in browsers
- **BLAST warnings**: Install taxdb to eliminate warnings (optional but recommended)

### Files Modified
- `scripts/taxonomy.sh` (2 changes: HTML naming fixes)
- `scripts/taxonomy_conda.sh` (2 changes: HTML naming fixes)
- `scripts/krona-blast.sh` (2 additions: BLASTDB export, taxdb check)
- `scripts/krona-blast_conda.sh` (2 additions: BLASTDB export, taxdb check)
- `scripts/setup_conda_env_fast.sh` (added integrated taxdb installation prompt)
- `scripts/setup_conda_env.sh` (added integrated taxdb installation prompt)
- `scripts/PIMGAVIR.sh` (1 change: script call)
- `scripts/PIMGAVIR_ib.sh` (1 change: script call)
- `scripts/PIMGAVIR_conda.sh` (1 change: script call)
- `scripts/PIMGAVIR_conda_ib.sh` (1 change: script call)
- `scripts/environment.yaml` (added deprecation warning)
- `CLAUDE.md` (added taxdb documentation, removed obsolete script reference)
- `README.md` (added database setup section with automatic/manual options)

### Files Added
- `scripts/setup_blast_taxdb.sh` (new installation script)
- `CHANGELOG.md` (this file)

### Files Deleted
- `scripts/taxonomy-gzip.sh` (obsolete, replaced by taxonomy.sh)
- `scripts/setup_conda_env.sh` (redundant, replaced by setup_conda_env_fast.sh)
