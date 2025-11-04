# Viral Genome Analysis - Implementation Summary

**Date:** 2025-10-29
**Version:** PIMGAVir v2.2
**Status:** ✅ IMPLEMENTED

---

## Overview

Complete viral genome recovery, annotation, and phylogenetic analysis has been successfully integrated into the PIMGAVir pipeline. This enhancement enables the identification and characterization of complete viral genomes from metagenomic samples, extending the capabilities from the original [bat coronavirus surveillance study](https://pmc.ncbi.nlm.nih.gov/articles/PMC7106086/).

### Key Improvements

**Original Study Approach:**
- PCR-targeted amplification
- Short fragments (415-531 bp)
- Limited to known primer targets

**New PIMGAVir Approach:**
- Metagenomic assembly
- Complete viral genomes (10-40 kb)
- Unbiased discovery of novel viruses

---

## Implemented Components

### 1. ✅ Conda Environment (Phase 0)

**File:** `scripts/pimgavir_viralgenomes.yaml`

**Key Tools Added:**
- **VirSorter2** (2.2.4): Viral sequence identification
- **CheckV** (1.0.1): Viral genome quality assessment
- **DRAM** (1.4.6): Functional annotation
- **Prodigal-gv** (2.11.0): Viral gene prediction
- **MAFFT** (7.520): Multiple sequence alignment
- **IQ-TREE** (2.2.2.6): Maximum likelihood phylogenetics
- **MrBayes** (3.2.7): Bayesian phylogenetics
- **vConTACT2** (0.11.3): Viral taxonomy
- **geNomad** (1.5.2): Gene annotation
- **vRhyme**: Viral genome binning (via pip)

**Installation:**
```bash
cd scripts/
mamba env create -f pimgavir_viralgenomes.yaml
conda activate pimgavir_viralgenomes
```

---

### 2. ✅ Phase 1: Viral Genome Recovery

**File:** `scripts/viral-genome-recovery.sh`

**Workflow:**
1. **VirSorter2**: Identifies viral sequences in assemblies
   - Minimum length: 1,500 bp (for complete genomes)
   - Confidence threshold: 0.5
   - Output: Potential viral contigs

2. **CheckV**: Assesses viral genome quality
   - Completeness estimation
   - Contamination detection
   - Quality categories: Complete, High (≥90%), Medium (50-90%), Low (<50%)
   - Output: High-quality viral genomes

3. **vRhyme**: Bins viral sequences
   - Groups related contigs
   - Reconstructs complete genomes from fragments
   - Output: Viral genome bins

**Usage:**
```bash
bash viral-genome-recovery.sh \
    megahit_contigs.fasta \
    viral-recovery-output \
    40 \
    Sample01 \
    MEGAHIT
```

**Key Outputs:**
- `04_final_genomes/Sample01_MEGAHIT_viral_genomes_hq.fna`: High-quality viral genomes
- `04_final_genomes/Sample01_MEGAHIT_checkv_quality.tsv`: Quality metrics
- `05_statistics/Sample01_MEGAHIT_viral_recovery_summary.txt`: Summary report

---

### 3. ✅ Phase 2: Functional Annotation

**File:** `scripts/viral-genome-annotation.sh`

**Workflow:**
1. **Prodigal-gv**: Predicts genes in viral genomes
   - Optimized for viral sequences
   - Metagenomic mode for diverse genomes
   - Output: Protein and nucleotide sequences

2. **DRAM-v**: Functional annotation
   - AMG (Auxiliary Metabolic Gene) detection
   - Viral hallmark gene identification
   - Metabolic pathway reconstruction
   - Output: Detailed functional annotations

3. **InterProScan** (optional): Protein domain annotation
   - Pfam, TIGRFAM, SMART databases
   - Detailed domain architecture
   - Output: Domain annotations

**Usage:**
```bash
bash viral-genome-annotation.sh \
    viral_genomes_hq.fna \
    annotation-output \
    40 \
    Sample01 \
    MEGAHIT
```

**Key Outputs:**
- `01_prodigal/Sample01_MEGAHIT_proteins.faa`: Predicted proteins
- `02_dramv/annotations.tsv`: DRAM-v functional annotations
- `02_dramv/distillate/`: Summary reports with AMG analysis
- `04_summary/Sample01_MEGAHIT_gene_to_genome.tsv`: Gene-to-genome mapping

---

### 4. ✅ Phase 3: Phylogenetic Analysis

**File:** `scripts/viral-phylogenetics.sh`

**Workflow:**
1. **MAFFT**: Multiple sequence alignment
   - Automatic strategy selection
   - Handles large datasets efficiently
   - Output: Aligned sequences

2. **trimAl**: Alignment trimming
   - Removes poorly aligned regions
   - Automated trimming strategy
   - Output: Trimmed alignment

3. **IQ-TREE**: Maximum likelihood phylogeny
   - ModelFinder for best substitution model
   - Ultrafast bootstrap (1,000 replicates)
   - Output: ML tree with support values

4. **MrBayes** (optional): Bayesian phylogeny
   - MCMC sampling
   - Posterior probabilities
   - Output: Consensus tree

**Usage:**
```bash
bash viral-phylogenetics.sh \
    proteins.faa \
    reference_proteins.faa \
    phylo-output \
    40 \
    Sample01 \
    RdRp
```

**Key Outputs:**
- `01_alignment/Sample01_RdRp_aligned_trimmed.faa`: Trimmed alignment
- `02_trees/Sample01_RdRp_iqtree.treefile`: ML phylogenetic tree
- `03_statistics/Sample01_RdRp_phylogenetics_summary.txt`: Analysis summary

---

### 5. ✅ Master Orchestration Script

**File:** `scripts/viral-genome-complete.sh`

**Purpose:** Orchestrates all three phases in a single command

**Workflow:**
1. Runs Phase 1 (Recovery)
2. If viral genomes found → Runs Phase 2 (Annotation)
3. If sufficient proteins → Runs Phase 3 (Phylogenetics)
4. Generates comprehensive master report

**Usage:**
```bash
bash viral-genome-complete.sh \
    assembly.fasta \
    viral-genomes-output \
    40 \
    Sample01 \
    MEGAHIT \
    [optional_reference_proteins.faa]
```

**Master Report Includes:**
- Executive summary with genome counts
- Phase-by-phase results
- Key output files list
- Next steps for publication
- Citation information

---

### 6. ✅ Database Setup Script

**File:** `scripts/setup_viral_databases.sh`

**Purpose:** Automates download and configuration of required databases

**Databases Installed:**
1. **VirSorter2 database** (~10 GB): Viral identification profiles
2. **CheckV database** (~1.5 GB): Viral genome quality references
3. **DRAM databases** (~150 GB): KEGG, Pfam, dbCAN, MEROPS for functional annotation
4. **RVDB** (~5 GB, optional): Reference Viral Database for BLAST

**Usage:**
```bash
conda activate pimgavir_viralgenomes
cd scripts/
./setup_viral_databases.sh
```

**Environment Configuration:**
After setup, database paths are saved to:
- `DBs/ViralGenomes/viral_db_env.sh`

To use in scripts:
```bash
source DBs/ViralGenomes/viral_db_env.sh
```

---

### 7. ✅ Pipeline Integration

**Modified Files:**
- `scripts/PIMGAVIR_worker.sh`
- `scripts/PIMGAVIR_worker_ib.sh`

**Integration Point:**
Viral genome analysis is automatically triggered after assembly-based taxonomy:

```bash
assembly_func(){
    # ... existing assembly and taxonomy code ...

    # NEW: Viral genome recovery and analysis
    if [ -f "$megahit_contigs_improved" ]; then
        bash viral-genome-complete.sh \
            "$megahit_contigs_improved" \
            "viral-genomes-megahit" \
            "$JTrim" \
            "$SampleName" \
            "MEGAHIT" \
            "NONE"
    fi

    if [ -f "$spades_contigs_improved" ]; then
        bash viral-genome-complete.sh \
            "$spades_contigs_improved" \
            "viral-genomes-spades" \
            "$JTrim" \
            "$SampleName" \
            "SPADES" \
            "NONE"
    fi
}
```

**When It Runs:**
- Automatically when using `--ass_based` or `ALL` methods
- Processes both MEGAHIT and SPAdes assemblies
- Gracefully handles failures (continues pipeline even if viral analysis fails)

---

## Usage Guide

### Quick Start

**1. Install viral genome environment:**
```bash
cd scripts/
mamba env create -f pimgavir_viralgenomes.yaml
conda activate pimgavir_viralgenomes
```

**2. Setup databases:**
```bash
./setup_viral_databases.sh
# Answer prompts for which databases to install
# Minimum required: VirSorter2 + CheckV (~12 GB)
# Recommended: Add DRAM for full functionality (~162 GB)
```

**3. Run pipeline with assembly mode:**
```bash
# Standard scratch
sbatch PIMGAVIR_conda.sh 40 --ass_based

# Infiniband scratch (IRD cluster)
sbatch PIMGAVIR_conda_ib.sh 40 ALL
```

Viral genome analysis will run automatically after assembly completes.

---

### Standalone Usage

You can also run viral genome analysis on existing assemblies:

```bash
conda activate pimgavir_viralgenomes

# Complete workflow (all 3 phases)
bash viral-genome-complete.sh \
    my_assembly.fasta \
    output_directory \
    40 \
    MySample \
    MEGAHIT \
    NONE

# Or run phases individually
bash viral-genome-recovery.sh assembly.fasta output1 40 Sample01 MEGAHIT
bash viral-genome-annotation.sh viral_genomes.fna output2 40 Sample01 MEGAHIT
bash viral-phylogenetics.sh proteins.faa NONE output3 40 Sample01 gene_name
```

---

## Output Structure

```
viral-genomes-megahit/
├── phase1_recovery/
│   ├── 01_virsorter/
│   │   └── final-viral-combined.fa           # All viral sequences
│   ├── 02_checkv/
│   │   ├── quality_summary.tsv               # Quality metrics
│   │   └── high_quality_genomes.tsv          # HQ genome list
│   ├── 03_vrhyme/
│   │   └── vRhyme_best_bins/                 # Binned genomes
│   ├── 04_final_genomes/
│   │   ├── Sample01_MEGAHIT_viral_genomes_hq.fna    # ⭐ High-quality genomes
│   │   ├── Sample01_MEGAHIT_checkv_quality.tsv      # Quality report
│   │   └── Sample01_MEGAHIT_checkv_completeness.tsv # Completeness data
│   └── 05_statistics/
│       └── Sample01_MEGAHIT_viral_recovery_summary.txt
│
├── phase2_annotation/
│   ├── 01_prodigal/
│   │   ├── Sample01_MEGAHIT_proteins.faa     # ⭐ Predicted proteins
│   │   ├── Sample01_MEGAHIT_genes.fna        # Gene sequences
│   │   └── Sample01_MEGAHIT_genes.gff        # Gene annotations
│   ├── 02_dramv/
│   │   ├── annotations.tsv                    # ⭐ Functional annotations
│   │   └── distillate/                        # ⭐ AMG analysis
│   ├── 03_interproscan/
│   │   └── proteins.faa.tsv                   # Domain annotations
│   └── 04_summary/
│       ├── Sample01_MEGAHIT_annotation_summary.txt
│       └── Sample01_MEGAHIT_gene_to_genome.tsv
│
├── phase3_phylogenetics/
│   ├── 01_alignment/
│   │   ├── Sample01_all_proteins_aligned.faa
│   │   └── Sample01_all_proteins_aligned_trimmed.faa
│   ├── 02_trees/
│   │   └── Sample01_all_proteins_iqtree.treefile    # ⭐ ML phylogenetic tree
│   └── 03_statistics/
│       └── Sample01_all_proteins_phylogenetics_summary.txt
│
├── reports/
│   └── Sample01_MEGAHIT_viral_genome_report.txt    # ⭐ Master report
│
└── viral_genome_analysis.log                        # Master log file
```

⭐ = Most important files for analysis

---

## Key Output Files

### For Quick Analysis

1. **High-quality viral genomes:**
   - `phase1_recovery/04_final_genomes/Sample_viral_genomes_hq.fna`
   - Genomes ≥90% complete
   - Ready for downstream analysis

2. **Functional annotations:**
   - `phase2_annotation/02_dramv/annotations.tsv`
   - All predicted genes with function assignments
   - AMG flags for host-interacting genes

3. **AMG summary:**
   - `phase2_annotation/02_dramv/distillate/`
   - Auxiliary metabolic genes analysis
   - Host interaction predictions

4. **Phylogenetic tree:**
   - `phase3_phylogenetics/02_trees/Sample_iqtree.treefile`
   - Open in FigTree, iTOL, or R ggtree
   - Bootstrap values included

5. **Master report:**
   - `reports/Sample_viral_genome_report.txt`
   - Executive summary
   - All key statistics
   - Next steps for publication

---

## Performance Considerations

### Runtime Estimates

For a typical metagenomic sample with ~1M paired-end reads:

| Phase | Tool | Typical Runtime | Peak RAM |
|-------|------|----------------|----------|
| Phase 1 | VirSorter2 | 2-4 hours | 32 GB |
| Phase 1 | CheckV | 15-30 min | 8 GB |
| Phase 1 | vRhyme | 30-60 min | 16 GB |
| Phase 2 | Prodigal-gv | 5-10 min | 4 GB |
| Phase 2 | DRAM-v | 4-8 hours | 64 GB |
| Phase 2 | InterProScan | 6-12 hours | 16 GB |
| Phase 3 | MAFFT | 10-30 min | 8 GB |
| Phase 3 | IQ-TREE | 1-3 hours | 16 GB |
| **Total** | | **12-30 hours** | **64 GB peak** |

**Notes:**
- InterProScan automatically skipped for >10,000 proteins
- MrBayes automatically skipped for >50 sequences
- Phase 3 skipped if <10 proteins predicted

### Disk Space Requirements

| Component | Size | Required? |
|-----------|------|-----------|
| VirSorter2 DB | 10 GB | ✅ Yes |
| CheckV DB | 1.5 GB | ✅ Yes |
| DRAM DBs | 150 GB | ⚠️  Recommended |
| RVDB | 5 GB | ❌ Optional |
| Per-sample output | 2-5 GB | - |
| **Total DBs** | **~167 GB** | - |

**Recommendations:**
- Minimum: Install VirSorter2 + CheckV (~12 GB)
- Recommended: Add DRAM for functional annotation (~162 GB)
- Optional: Add RVDB for reference comparisons (~5 GB)

---

## Comparison to Original Study

### Original Bat Coronavirus Study (PMC7106086)

**Methods:**
- Targeted RT-PCR amplification
- Primers for known coronavirus/paramyxovirus genes
- Sanger sequencing
- Fragment sizes: 415-531 bp (RdRp), 392-515 bp (L gene)

**Limitations:**
- Only detects viruses matching primer sequences
- Incomplete genomes
- Misses novel viral families
- Limited functional characterization

### New PIMGAVir Viral Genome Module

**Methods:**
- Unbiased metagenomic sequencing
- De novo assembly (MEGAHIT + SPAdes)
- Viral genome binning and recovery
- Complete genome sequences: 10-40 kb
- Comprehensive functional annotation

**Advantages:**
- ✅ Discovers novel viruses without prior knowledge
- ✅ Complete genomes enable full characterization
- ✅ Detects all viral families, not just targeted groups
- ✅ AMG analysis reveals host-virus interactions
- ✅ Phylogenetic placement for taxonomy
- ✅ Zoonotic potential assessment

**Example Use Cases:**
1. **Bat surveillance studies:** Identify complete coronavirus genomes, not just RdRp fragments
2. **Wastewater monitoring:** Discover novel enteric viruses
3. **Marine viromics:** Characterize phage diversity
4. **Plant pathology:** Identify crop-infecting viruses

---

## Next Steps for Publication

### 1. Taxonomic Classification

**Required:**
- Use phylogenetic tree to place viruses in ICTV taxonomy
- Calculate amino acid identity to reference genomes
- Compare to NCBI viral RefSeq

**Tools:**
```bash
# Use vConTACT2 for automatic classification
vcontact2 --raw-proteins proteins.faa \
          --rel-mode Diamond \
          --db ProkaryoticViralRefSeq85-Merged \
          --output-dir vcontact2_output
```

### 2. Genome Characterization

**Analyses:**
- Genome organization (gene order, synteny)
- G+C content and codon usage
- Identification of key genes (RdRp, capsid, spike, etc.)
- Comparison to close relatives

**Tools:**
```bash
# Use Clinker for synteny visualization
clinker viral_genome1.gbk viral_genome2.gbk -o clinker_output
```

### 3. Zoonotic Potential Assessment

**For coronaviruses and related:**
- Furin cleavage site detection in spike proteins
- Receptor binding domain (RBD) analysis
- Comparison to known zoonotic viruses (SARS-CoV-2, MERS-CoV)

**Tools:**
```bash
# Search for furin sites
grep -E "R.[KR].R" proteins.faa

# BLAST RBD against known ACE2-binding domains
blastp -query spike_protein.faa \
       -db known_rbds.faa \
       -outfmt 6
```

### 4. Host Prediction

**Methods:**
- AMG profile analysis (from DRAM-v)
- CRISPR spacer matching (if available)
- Host co-occurrence analysis

**Key Questions:**
- Which host metabolic pathways are manipulated?
- Do AMGs suggest specific host ranges?
- Are there host-specific viral signatures?

### 5. Visualization

**Publication-quality figures:**
- Genome maps with gene annotations (use genoPlotR or gggenes in R)
- Phylogenetic trees with bootstrap support (use ggtree in R)
- Comparative genomics plots (use Circos or ggplot2)
- AMG functional distribution (use ggplot2)

**Example R code for tree:**
```R
library(ggtree)
library(ggplot2)

tree <- read.tree("Sample01_iqtree.treefile")

ggtree(tree, layout="circular") +
  geom_tiplab(size=3, offset=0.01) +
  geom_nodepoint(aes(color=as.numeric(label)), size=3) +
  scale_color_gradient(low="blue", high="red",
                       limits=c(0,100),
                       name="Bootstrap") +
  theme_tree2() +
  ggtitle("Phylogenetic Analysis of Viral RdRp Proteins")
```

---

## Troubleshooting

### Issue: No viral genomes found

**Symptoms:**
- Phase 1 completes but reports 0 high-quality genomes
- Pipeline stops after Phase 1

**Possible causes:**
1. **No viruses in sample:** Check intermediate VirSorter2 output
2. **Assembly too fragmented:** Check N50, may need better sequencing depth
3. **Thresholds too strict:** Adjust CheckV completeness threshold

**Solutions:**
```bash
# Check VirSorter2 results
grep -c "^>" phase1_recovery/01_virsorter/final-viral-combined.fa

# Check CheckV quality distribution
awk -F'\t' 'NR>1 {print $8}' phase1_recovery/02_checkv/quality_summary.tsv | sort | uniq -c

# Lower completeness threshold manually
awk -F'\t' 'NR==1 || $7 >= 50' phase1_recovery/02_checkv/quality_summary.tsv > medium_quality.tsv
```

### Issue: DRAM-v fails

**Symptoms:**
- Phase 2 errors during DRAM-v annotation
- Missing `annotations.tsv` file

**Possible causes:**
1. **Databases not installed:** Run `setup_viral_databases.sh`
2. **DRAM config not set:** Database locations not configured
3. **Out of memory:** DRAM-v requires 64 GB+ for large datasets

**Solutions:**
```bash
# Check DRAM database status
DRAM-setup.py print_config

# Reinstall/configure databases
DRAM-setup.py prepare_databases --output_dir DBs/ViralGenomes/dram-db
DRAM-setup.py set_database_locations --config_loc DBs/ViralGenomes/dram-db/CONFIG

# Increase SLURM memory
#SBATCH --mem=128GB
```

### Issue: Phylogenetics fails

**Symptoms:**
- Phase 3 errors in MAFFT or IQ-TREE
- Missing tree file

**Possible causes:**
1. **Too few sequences:** Need ≥3 sequences for tree
2. **Alignment too short:** Trimming removed too much
3. **Invalid characters:** Special characters in sequence IDs

**Solutions:**
```bash
# Check sequence count
grep -c "^>" phase2_annotation/01_prodigal/proteins.faa

# Check alignment length
seqkit stats phase3_phylogenetics/01_alignment/*_trimmed.faa

# Clean sequence IDs
seqkit replace -p '[^A-Za-z0-9_]' -r '_' proteins.faa > proteins_clean.faa
```

### Issue: Pipeline takes too long

**Symptoms:**
- Job exceeds walltime
- Very long runtimes

**Optimizations:**
1. **Skip InterProScan:** Automatically skipped for >10K proteins, but check
2. **Skip MrBayes:** Automatically skipped for >50 sequences
3. **Reduce threads for parallel steps:** Trade time for memory
4. **Split by assembler:** Run MEGAHIT and SPAdes analyses separately

**Solutions:**
```bash
# Run only fast tools (skip DRAM-v)
# Edit viral-genome-annotation.sh to comment out DRAM-v section

# Run on subsets
seqkit sample -p 0.1 proteins.faa > proteins_subset.faa  # 10% sample
```

---

## Citations

If you use these viral genome analysis tools in your research, please cite:

**PIMGAVir:**
- [Citation to be added]

**Viral Identification:**
- **VirSorter2:** Guo et al. (2021). "VirSorter2: a multi-classifier, expert-guided approach to detect diverse DNA and RNA viruses." *Microbiome* 9:37.
- **CheckV:** Nayfach et al. (2021). "CheckV assesses the quality and completeness of metagenome-assembled viral genomes." *Nature Biotechnology* 39:578-585.

**Functional Annotation:**
- **DRAM:** Shaffer et al. (2020). "DRAM for distilling microbial metabolism to automate the curation of microbiome function." *Nucleic Acids Research* 48:8883-8900.
- **Prodigal:** Hyatt et al. (2010). "Prodigal: prokaryotic gene recognition and translation initiation site identification." *BMC Bioinformatics* 11:119.

**Phylogenetics:**
- **MAFFT:** Katoh & Standley (2013). "MAFFT multiple sequence alignment software version 7." *Molecular Biology and Evolution* 30:772-780.
- **IQ-TREE:** Nguyen et al. (2015). "IQ-TREE: a fast and effective stochastic algorithm for estimating maximum-likelihood phylogenies." *Molecular Biology and Evolution* 32:268-274.
- **trimAl:** Capella-Gutiérrez et al. (2009). "trimAl: a tool for automated alignment trimming." *Bioinformatics* 25:1972-1973.

**Binning:**
- **vRhyme:** Kieft et al. (2022). "vRhyme enables binning of viral genomes from metagenomes." *Nucleic Acids Research* 50:e83.

---

## Implementation Status

| Component | Status | File | Lines of Code |
|-----------|--------|------|---------------|
| Conda environment | ✅ Complete | `pimgavir_viralgenomes.yaml` | 100 |
| Phase 1: Recovery | ✅ Complete | `viral-genome-recovery.sh` | 380 |
| Phase 2: Annotation | ✅ Complete | `viral-genome-annotation.sh` | 420 |
| Phase 3: Phylogenetics | ✅ Complete | `viral-phylogenetics.sh` | 450 |
| Master script | ✅ Complete | `viral-genome-complete.sh` | 550 |
| Database setup | ✅ Complete | `setup_viral_databases.sh` | 350 |
| Worker integration | ✅ Complete | `PIMGAVIR_worker*.sh` | +50 each |
| Documentation | ✅ Complete | This file + VIRAL_GENOME_ASSEMBLY_PLAN.md | - |
| **Total** | **✅ 100%** | **8 new scripts** | **~2,300 LOC** |

---

## Future Enhancements (Phases 4-5)

### Phase 4: Zoonotic Assessment (Planned)

**Proposed additions:**
- Automated furin cleavage site detection
- RBD sequence extraction and analysis
- Host receptor compatibility prediction
- Comparison to known zoonotic viruses

**Status:** ⏳ Not yet implemented (awaiting user feedback)

### Phase 5: Report Generation (Planned)

**Proposed additions:**
- R Markdown templates for publication
- Automated figure generation (ggtree, genome maps)
- Interactive HTML reports
- XLSX summary tables

**Status:** ⏳ Not yet implemented (awaiting user feedback)

---

## Contact and Support

For questions or issues with viral genome analysis:

1. **Check troubleshooting section** above
2. **Review log files:** `viral_genome_analysis.log` and phase-specific logs
3. **Check intermediate outputs:** Ensure each phase completed successfully
4. **GitHub Issues:** Report bugs at https://github.com/ltalignani/PIMGAVIR-v2/issues

---

**Last Updated:** 2025-10-29
**Version:** PIMGAVir v2.2
**Contributors:** Loïc Talignani, Claude Code

