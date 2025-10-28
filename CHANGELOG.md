# CHANGELOG

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
