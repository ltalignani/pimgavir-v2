# Documentation Cleanup - November 5, 2025

## Overview

This document lists obsolete or redundant documentation files identified after implementing the new launcher scripts (`run_pimgavir.sh` and `run_pimgavir_batch.sh`) in PIMGAVir v2.2+.

---

## 🗑️ Files Recommended for DELETION

### Category 1: Obsolete Batch Processing Documentation

These files document the **old batch system** where `PIMGAVIR_conda.sh` auto-detected samples in `input/`. This system is **replaced** by the new launchers with flexible resource configuration.

#### Files to delete:
- ❌ `QUICK_START_BATCH.md` (root directory)
- ❌ `docs/BATCH_PROCESSING_GUIDE.md`
- ❌ `docs/BATCH_PROCESSING_PLAN.md`
- ❌ `docs/BATCH_PROCESSING_IMPLEMENTATION.md`

**Why delete:**
- Old system: `sbatch PIMGAVIR_conda.sh 40 ALL` (auto-detects input/)
- New system: `bash run_pimgavir_batch.sh /path/to/samples/ ALL` (explicit directory, resource flags)
- These 4 files total ~2,500 lines of now-incorrect documentation
- Users following these guides would use deprecated workflows

**Replacement:**
- `RESOURCE_CONFIGURATION_GUIDE.md` (updated) documents new launchers
- Section in README.md shows current batch usage

---

### Category 2: Obsolete Setup Documentation

#### Files to delete:
- ❌ `docs/SETUP_GUIDE.md`

**Why delete:**
- References deprecated `pimgavir_complete` and `pimgavir_minimal` environments
- Doesn't document SLURM batch mode for setup (now the recommended method)
- Missing information on unified `pimgavir_viralgenomes` environment

**Replacement:**
- `docs/CONDA_ENVIRONMENT_SETUP_BATCH.md` - Complete modern setup guide
- README.md Quick Start section

---

### Category 3: Development Session Summaries (Historical Only)

These files document **development progress** but provide no value to end users. All relevant information is in CHANGELOG.md.

#### Files to delete:
- ⚠️ `updates/SESSION_2025_11_04_FIXES.md`
- ⚠️ `updates/SESSION_SUMMARY_V2.2_FINAL.md`
- ⚠️ `updates/SESSION_SUMMARY_V2.2_IMPLEMENTATION.md`
- ⚠️ `updates/SESSION_SUMMARY.md`
- ⚠️ `updates/IMPLEMENTATION_COMPLETE.md`
- ⚠️ `updates/IMPROVEMENTS_SUMMARY_V2.2.md`
- ⚠️ `updates/IMPROVEMENTS_SUMMARY_V2.md`
- ⚠️ `updates/SETUP_CONDA_ENV_SLURM_SUPPORT.md`
- ⚠️ `updates/YAML_UPDATES_V2.2.md`
- ⚠️ `updates/README_CLAUDE_DATABASE_DOCUMENTATION.md`

**Why delete:**
- Internal development notes
- All changes documented in CHANGELOG.md
- No user-facing value

**Alternative:** Keep in Git history if needed for development archaeology

---

### Category 4: Bugfix Reports (Redundant)

All bugfix information is documented in CHANGELOG.md with proper context.

#### Files to delete:
- ⚠️ `fixes/BUGFIX_V2.2.1_SUMMARY.md`
- ⚠️ `fixes/CONDA_ENVIRONMENT_INHERITANCE_FIX.md`
- ⚠️ `fixes/CRITICAL_FIX_VARIABLE_SCOPING.md`

**Why delete:**
- Duplicates CHANGELOG.md entries
- Technical details better suited for Git commit messages

**Keep:**
- ✅ `fixes/DRAM_TROUBLESHOOTING.md` - User-facing troubleshooting guide

---

### Category 5: Viral Genome Implementation Docs

#### Files to consider deleting:
- 📌 `VIRAL_GENOME_ASSEMBLY_PLAN.md` - Implementation plan (if complete)
- 📌 `VIRAL_GENOME_IMPLEMENTATION_SUMMARY.md` - Redundant with complete guide

**Why delete:**
- Implementation is complete
- User documentation in `VIRAL_GENOME_COMPLETE_7PHASES.md` and `VIRAL_GENOME_QUICKSTART.md`
- These are planning/summary docs with no current value

**Keep:**
- ✅ `VIRAL_GENOME_COMPLETE_7PHASES.md` - Complete user guide
- ✅ `VIRAL_GENOME_QUICKSTART.md` - Quick reference

---

## ✅ Files to KEEP (Essential Documentation)

### User-Facing Documentation

#### Main Documentation
- ✅ `README.md` - Main entry point (✅ **UPDATED** 2025-11-05)
- ✅ `CLAUDE.md` - Comprehensive technical documentation
- ✅ `CHANGELOG.md` - Version history
- ✅ `OUTPUT_FILES.md` - File reference guide
- ✅ `DIRECTORY_STRUCTURE.md` - Project structure

#### User Guides
- ✅ `RESOURCE_CONFIGURATION_GUIDE.md` - **NEEDS UPDATE** for new launchers
- ✅ `VIRAL_GENOME_COMPLETE_7PHASES.md` - Complete 7-phase guide
- ✅ `VIRAL_GENOME_QUICKSTART.md` - Quick start viral analysis

### Technical Documentation

#### Installation & Setup
- ✅ `docs/CONDA_ENVIRONMENT_SETUP_BATCH.md` - SLURM batch installation
- ✅ `docs/CONDA_MIGRATION_GUIDE.md` - Migration from modules to conda
- ✅ `docs/INFINIBAND_SETUP.md` - IRD cluster Infiniband
- ✅ `docs/INSTALL_SUMMARY.md` - Installation summary

#### Pipeline Documentation
- ✅ `docs/ASSEMBLY_STRATEGY.md` - Assembly strategy rationale
- ✅ `docs/BLAST_OPTIMIZATION_FIX.md` - BLAST optimization
- ✅ `docs/BLAST_SKIP_SOLUTION.md` - BLAST skip logic
- ✅ `docs/SCRIPT_VERSIONS_GUIDE.md` - Script version guide

#### Troubleshooting
- ✅ `fixes/DRAM_TROUBLESHOOTING.md` - DRAM issues (iTrop)
- ✅ `scripts/deprecated/README.md` - Deprecated environment migration

---

## 📝 Files REQUIRING UPDATES

### High Priority

1. **`RESOURCE_CONFIGURATION_GUIDE.md`** - ⚠️ **CRITICAL UPDATE NEEDED**
   - Current: References old `PIMGAVIR_worker.sh` SBATCH editing
   - Required: Complete rewrite for new launcher system
   - New content:
     * `run_pimgavir.sh` usage examples
     * `run_pimgavir_batch.sh` usage examples
     * All command-line resource options
     * Remove all references to editing SBATCH headers

2. **`CLAUDE.md`** - Minor updates
   - Update "Main Execution" section with new launcher examples
   - Keep backward compatibility notes
   - Add reference to RESOURCE_CONFIGURATION_GUIDE.md

### Medium Priority

3. **`CHANGELOG.md`** - Add v2.2.2 entry
   - Document new launcher scripts
   - Document documentation cleanup
   - Reference deprecated batch processing documentation

---

## 📊 Cleanup Summary

### Totals

| Category | Files | Action |
|----------|-------|--------|
| **Obsolete batch docs** | 4 | 🗑️ DELETE |
| **Obsolete setup docs** | 1 | 🗑️ DELETE |
| **Session summaries** | 10 | ⚠️ DELETE (optional) |
| **Bugfix reports** | 3 | ⚠️ DELETE (optional) |
| **Viral genome plans** | 2 | 📌 CONSIDER DELETE |
| **TOTAL TO DELETE** | **20** | |
| **Essential docs** | 19 | ✅ KEEP |
| **Needs update** | 2 | 📝 UPDATE |

### Storage Saved
- Estimated: ~150-200 KB of markdown
- Reduced user confusion: **PRICELESS**

---

## 🚀 Recommended Action Plan

### Step 1: Create Backup (Optional)
```bash
mkdir -p archived_docs/
mv QUICK_START_BATCH.md archived_docs/
mv docs/BATCH_PROCESSING_*.md archived_docs/
mv docs/SETUP_GUIDE.md archived_docs/
# ... etc
```

### Step 2: Delete Obsolete Files
```bash
# Obsolete batch processing docs
rm QUICK_START_BATCH.md
rm docs/BATCH_PROCESSING_GUIDE.md
rm docs/BATCH_PROCESSING_PLAN.md
rm docs/BATCH_PROCESSING_IMPLEMENTATION.md

# Obsolete setup guide
rm docs/SETUP_GUIDE.md

# Optional: Session summaries
rm updates/SESSION_*.md
rm updates/IMPLEMENTATION_COMPLETE.md
rm updates/IMPROVEMENTS_SUMMARY_*.md
rm updates/SETUP_CONDA_ENV_SLURM_SUPPORT.md
rm updates/YAML_UPDATES_V2.2.md
rm updates/README_CLAUDE_DATABASE_DOCUMENTATION.md

# Optional: Bugfix reports
rm fixes/BUGFIX_V2.2.1_SUMMARY.md
rm fixes/CONDA_ENVIRONMENT_INHERITANCE_FIX.md
rm fixes/CRITICAL_FIX_VARIABLE_SCOPING.md

# Optional: Viral genome planning docs
rm VIRAL_GENOME_ASSEMBLY_PLAN.md
rm VIRAL_GENOME_IMPLEMENTATION_SUMMARY.md
```

### Step 3: Update Remaining Documentation

1. **Update `RESOURCE_CONFIGURATION_GUIDE.md`**
   - Complete rewrite for new launchers
   - Priority: HIGH
   - Estimated time: 2-3 hours

2. **Update `CLAUDE.md`**
   - Update main execution examples
   - Add deprecation notes for old batch system
   - Priority: MEDIUM
   - Estimated time: 30 minutes

3. **Update `CHANGELOG.md`**
   - Add v2.2.2 entry
   - Document launcher system
   - Document cleanup
   - Priority: MEDIUM
   - Estimated time: 15 minutes

### Step 4: Commit Changes
```bash
git add -u  # Stage deletions
git add RESOURCE_CONFIGURATION_GUIDE.md CLAUDE.md CHANGELOG.md  # Updates
git commit -m "docs: cleanup obsolete documentation and update for launcher system

- Remove obsolete batch processing documentation (4 files)
- Remove obsolete setup guide (replaced by CONDA_ENVIRONMENT_SETUP_BATCH.md)
- Remove development session summaries (10 files)
- Remove redundant bugfix reports (3 files)
- Remove viral genome planning docs (2 files)
- Update README.md for new launcher scripts
- Update RESOURCE_CONFIGURATION_GUIDE.md for new system
- Update CHANGELOG.md with v2.2.2 changes

Total: 20 files deleted, documentation streamlined for clarity"
```

---

## 📋 Checklist

Before deleting files, verify:

- [ ] README.md updated with new launcher examples ✅ DONE (2025-11-05)
- [ ] RESOURCE_CONFIGURATION_GUIDE.md rewritten for launchers ⏳ TODO
- [ ] CLAUDE.md updated with launcher references ⏳ TODO
- [ ] CHANGELOG.md includes cleanup notes ⏳ TODO
- [ ] No active references to deleted files in remaining docs
- [ ] Git backup/branch created (optional)
- [ ] Team notified of documentation changes

---

## 🎯 Impact Assessment

### For Users
- ✅ **Clearer documentation** - No conflicting guides
- ✅ **Current examples** - All commands use new launchers
- ✅ **Less confusion** - One clear path forward
- ✅ **Better organization** - Essential docs easy to find

### For Maintainers
- ✅ **Easier updates** - Fewer files to maintain
- ✅ **Single source of truth** - No duplicate information
- ✅ **Better quality** - Focus on essential documentation
- ✅ **Reduced technical debt** - Remove obsolete content

---

**Document created:** 2025-11-05
**PIMGAVir version:** v2.2.2
**Author:** Loïc Talignani
**Status:** Pending approval
