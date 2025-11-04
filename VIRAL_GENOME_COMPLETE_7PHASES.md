# Complete Viral Genome Analysis - All 7 Phases

**Date:** 2025-11-03
**Version:** PIMGAVir v2.2
**Status:** ✅ FULLY IMPLEMENTED

---

## Overview

Complete viral genome analysis pipeline comprising **7 integrated phases**, from viral discovery to zoonotic risk assessment and publication-ready reporting. This comprehensive workflow enables complete viral metagenomics research from sequence to manuscript.

### Workflow Summary

```
Metagenomic Assembly (MEGAHIT/SPAdes)
          ↓
┌─────────────────────────────────────────────────────────┐
│ PHASE 1: Viral Genome Recovery                          │
│ VirSorter2 → CheckV → vRhyme                            │
│ Output: High-quality viral genomes (≥90% complete)      │
└─────────────────────────────────────────────────────────┘
          ↓
┌─────────────────────────────────────────────────────────┐
│ PHASE 2: Functional Annotation                          │
│ Prodigal-gv → DRAM-v → AMG Detection                    │
│ Output: Metabolic gene catalog, AMG predictions         │
└─────────────────────────────────────────────────────────┘
          ↓
┌─────────────────────────────────────────────────────────┐
│ PHASE 3: Phylogenetic Analysis                          │
│ MAFFT → trimAl → IQ-TREE → MrBayes                      │
│ Output: Maximum likelihood + Bayesian trees             │
└─────────────────────────────────────────────────────────┘
          ↓
┌─────────────────────────────────────────────────────────┐
│ PHASE 4: Comparative Genomics                           │
│ Prodigal-gv → geNomad → MMseqs2 → vConTACT2             │
│ Output: Viral taxonomy networks, protein clusters       │
└─────────────────────────────────────────────────────────┘
          ↓
┌─────────────────────────────────────────────────────────┐
│ PHASE 5: Host Prediction & Ecology                      │
│ CRISPR → tRNA → K-mer → Protein Homology                │
│ Output: Host predictions, diversity metrics             │
└─────────────────────────────────────────────────────────┘
          ↓
┌─────────────────────────────────────────────────────────┐
│ PHASE 6: Zoonotic Risk Assessment (NEW v2.2)            │
│ Furin Sites → RBD Analysis → Risk Scoring               │
│ Output: Risk assessment, safety recommendations         │
└─────────────────────────────────────────────────────────┘
          ↓
┌─────────────────────────────────────────────────────────┐
│ PHASE 7: Publication Reports (NEW v2.2)                 │
│ Figures → Tables → Methods → HTML Dashboard             │
│ Output: Publication-ready materials                     │
└─────────────────────────────────────────────────────────┘
          ↓
    Publication-Ready Results + Safety Assessment
```

---

## Quick Start

### Prerequisites

```bash
# Install conda environment (one-time setup)
cd scripts/
mamba env create -f pimgavir_viralgenomes.yaml
conda activate pimgavir_viralgenomes
```

### Run All 7 Phases

```bash
# Complete analysis (all 7 phases)
sbatch viral-genome-complete-7phases.sh \
    megahit_contigs.fasta \
    viral_analysis_output \
    40 \
    <Sample_Name>

# With host genomes for Phase 5
sbatch viral-genome-complete-7phases.sh \
    megahit_contigs.fasta \
    viral_analysis_output \
    40 \
    <Sample_Name> \
    bacterial_genomes.fasta

# With all optional inputs
sbatch viral-genome-complete-7phases.sh \
    megahit_contigs.fasta \
    viral_analysis_output \
    40 \
    <Sample_Name> \
    bacterial_genomes.fasta \
    reference_viruses.fasta \
    known_zoonotic_viruses.fasta  # For Phase 6 comparison
```

### Run Specific Phases Only

```bash
# Only phases 1, 2, and 4 (skip phylogenetics, host, zoonotic, reports)
sbatch viral-genome-complete-7phases.sh \
    megahit_contigs.fasta \
    viral_analysis_output \
    40 \
    <Sample_Name> \
    "" \
    "" \
    "" \
    --phases 1,2,4

# Skip intensive analyses but include reports
sbatch viral-genome-complete-7phases.sh \
    megahit_contigs.fasta \
    viral_analysis_output \
    40 \
    <Sample_Name> \
    "" \
    "" \
    "" \
    --phases 1,2,6,7  # Recovery, annotation, zoonotic, reports
```

---

## Phase Details

### Phase 1: Viral Genome Recovery

**Script:** `viral-genome-recovery.sh`
**Execution time:** 2-4 hours (depends on contig count)

#### Tools

- **VirSorter2**: Identifies viral sequences
- **CheckV**: Assesses completeness and contamination
- **vRhyme**: Bins viral fragments into complete genomes

#### Key Parameters

```bash
# VirSorter2
--min-length 1500      # Minimum contig length (bp)
--min-score 0.5        # Confidence threshold

# CheckV
--completeness ≥90%    # High-quality threshold
--contamination <5%    # Maximum allowed contamination
```

#### Outputs

```
phase1_recovery/
├── virsorter2/               # Viral predictions
├── checkv/                   # Quality assessment
├── vrhyme/                   # Binned genomes
├── high_quality_viruses/     # Final HQ genomes (≥90% complete)
└── results/
    └── <Sample_Name>_recovery_summary.txt
```

#### Quality Thresholds

- **Complete**: 100% complete, no contamination
- **High-quality**: ≥90% complete, <5% contamination
- **Medium-quality**: 50-90% complete
- **Low-quality**: <50% complete

---

### Phase 2: Functional Annotation

**Script:** `viral-genome-annotation.sh`
**Execution time:** 3-6 hours (depends on genome count)

#### Tools

- **Prodigal-gv**: Viral gene prediction
- **DRAM-v**: Functional annotation using multiple databases
- **AMG Detection**: Auxiliary metabolic genes

#### Key Features

- Comprehensive functional annotation
- Metabolic pathway prediction
- AMG (Auxiliary Metabolic Gene) detection
- Viral lifestyle prediction (lytic vs lysogenic)

#### Outputs

```
phase2_annotation/
├── prodigal/
│   └── <Sample_Name>_proteins.faa    # All predicted proteins
├── dramv/
│   ├── annotations.tsv               # Complete annotations
│   ├── distill/
│   │   ├── amg_summary.tsv           # AMG predictions ⭐
│   │   ├── genome_stats.tsv          # Genome statistics
│   │   └── product.html              # Interactive visualization
└── results/
    └── <Sample_Name>_annotation_summary.txt
```

#### Key Annotations

- **Viral hallmark genes**: Major capsid, terminase, portal
- **Metabolic genes**: Carbon, nitrogen, sulfur metabolism
- **AMGs**: Photosynthesis, nutrient acquisition
- **Auxiliary functions**: DNA replication, host manipulation

---

### Phase 3: Phylogenetic Analysis

**Script:** `viral-phylogenetics.sh`
**Execution time:** 4-8 hours (depends on sequence count and alignment length)

#### Tools

- **MAFFT**: Multiple sequence alignment
- **trimAl**: Alignment trimming and quality filtering
- **IQ-TREE**: Maximum likelihood tree with ultrafast bootstrap
- **MrBayes**: Bayesian phylogenetic inference

#### Alignment Strategy

1. Align viral genomes with MAFFT (auto mode)
2. Trim poorly aligned regions (trimAl automated1)
3. Build ML tree with model testing (IQ-TREE)
4. Build Bayesian tree (MrBayes, optional if time permits)

#### Outputs

```
phase3_phylogenetics/
├── alignment/
│   ├── <Sample_Name>_viral_aligned.fasta       # Raw alignment
│   └── <Sample_Name>_viral_trimmed.fasta       # Trimmed alignment
├── iqtree/
│   ├── <Sample_Name>_viral.treefile            # Best ML tree ⭐
│   ├── <Sample_Name>_viral.contree             # Consensus tree
│   └── <Sample_Name>_viral.iqtree              # Full report
├── mrbayes/
│   ├── <Sample_Name>_viral.con.tre             # Bayesian consensus ⭐
│   └── <Sample_Name>_viral.run1.p              # MCMC trace
└── results/
    └── <Sample_Name>_phylo_summary.txt
```

#### Tree Visualization

- Import `.treefile` into FigTree or iTOL
- Bootstrap support shown at nodes
- Can root tree on outgroup (if provided)

---

### Phase 4: Comparative Genomics

**Script:** `viral-comparative-genomics.sh`
**Execution time:** 2-4 hours

#### Tools

- **Prodigal-gv**: Gene prediction
- **geNomad**: Viral annotation and taxonomy
- **MMseqs2**: Protein clustering (90% identity)
- **vConTACT2**: Viral taxonomy networks

#### Analysis Steps

1. Predict proteins in viral genomes
2. Annotate with geNomad (viral-specific database)
3. Cluster proteins (identify core/accessory genes)
4. Build protein similarity networks (vConTACT2)
5. Assign taxonomy based on network clustering

#### Outputs

```
phase4_comparative/
├── proteins/
│   ├── <Sample_Name>_proteins.faa              # All proteins
│   └── <Sample_Name>_genes.gff                 # Gene coordinates
├── genomad/
│   └── <Sample_Name>_summary/
│       ├── <Sample_Name>_virus_summary.tsv     # Taxonomy ⭐
│       └── <Sample_Name>_virus_genes.tsv       # Gene annotations
├── clusters/
│   ├── <Sample_Name>_protein_clusters.tsv      # Protein families
│   └── <Sample_Name>_rep_proteins.faa          # Representatives
├── vcontact2/
│   ├── genome_by_genome_overview.csv           # Taxonomy ⭐
│   └── c1.ntw                                  # Network (Cytoscape)
└── results/
    └── <Sample_Name>_comparative_summary.txt
```

#### Network Analysis

- Import `c1.ntw` into Cytoscape
- Load `genome_by_genome_overview.csv` as node attributes
- Visualize viral taxonomic relationships
- Identify viral clusters (genera/families)

---

### Phase 5: Host Prediction & Ecology

**Script:** `viral-host-prediction.sh`
**Execution time:** 2-4 hours (with host genomes) or 30 min (ecology only)

#### Host Prediction Methods

##### 1. CRISPR Spacer Matching (Highest Confidence)

- Extract CRISPR spacers from host genomes (MinCED)
- BLAST spacers against viral genomes
- Direct evidence of infection

##### 2. tRNA Matching (Moderate Confidence)

- Predict tRNAs in viruses (tRNAscan-SE)
- Predict tRNAs in hosts
- Match tRNA profiles (integration potential)

##### 3. K-mer Composition (Moderate Confidence)

- Calculate k-mer sketches (Mash, k=16)
- Compare viral vs host composition
- Mash distance < 0.1 = similar composition

##### 4. Protein Homology (Supplementary)

- BLAST viral proteins vs host proteins
- Shared genes suggest relationship
- Lower confidence than other methods

#### Ecology Analysis

- Viral diversity metrics (richness, evenness)
- Genome size distribution
- GC content distribution
- Always performed, even without host genomes

#### Outputs

```
phase5_host_ecology/
├── crispr/
│   ├── <Sample_Name>_host_spacers.fasta        # CRISPR spacers
│   └── <Sample_Name>_crispr_matches.txt        # Virus matches ⭐
├── trna/
│   ├── <Sample_Name>_viral_trnas.txt           # Viral tRNAs
│   ├── <Sample_Name>_host_trnas.txt            # Host tRNAs
│   └── <Sample_Name>_trna_matches.txt          # Matches
├── kmer_analysis/
│   └── <Sample_Name>_kmer_similarity.txt       # Mash distances
├── protein_homology/
│   └── <Sample_Name>_protein_matches.txt       # Shared proteins
├── ecology/
│   └── <Sample_Name>_diversity.txt             # Diversity stats ⭐
└── results/
    ├── <Sample_Name>_host_predictions.tsv      # Integrated predictions ⭐
    ├── <Sample_Name>_virus_host_summary.tsv    # Per-virus summary
    └── <Sample_Name>_host_ecology_summary.txt  # Full report
```

#### Confidence Ranking

1. **CRISPR matches**: Direct evidence (highest confidence)
2. **K-mer similarity**: Compositional similarity (moderate)
3. **tRNA matching**: Integration potential (moderate)
4. **Protein homology**: Shared genes (supplementary)

---

### Phase 6: Zoonotic Risk Assessment (NEW v2.2)

**Script:** `viral-zoonotic-assessment.sh`
**Execution time:** 1-2 hours
**Purpose:** Assess potential zoonotic risk through computational analysis

#### Key Features

1. **Furin Cleavage Site Detection**
   - Searches for R-X-[KR]-R motif (classic furin sites)
   - Identifies multi-basic cleavage sites
   - Extended patterns for comprehensive detection
   - Context analysis (±10 amino acids)
   - Python-based pattern detection with scoring

2. **Receptor Binding Domain (RBD) Analysis**
   - Cysteine content analysis (4-8 cysteines expected)
   - Aromatic residue enrichment (receptor interaction)
   - Charged residue analysis (electrostatic interactions)
   - Size filtering (150-400 AA for RBDs)
   - Feature-based scoring system

3. **Surface Protein Identification**
   - Keyword-based identification (spike, envelope, glycoprotein)
   - Size filtering (>500 AA)
   - Glycosylation site enrichment analysis
   - S+T content assessment

4. **Comparison with Known Zoonotic Viruses** (optional)
   - BLASTP against zoonotic virus database
   - Identity thresholds: High (>80%), Medium (60-80%), Low (<60%)
   - E-value threshold: 1e-5
   - Requires user-provided zoonotic virus database

5. **Automated Risk Scoring System**
   - Furin sites: 0-30 points
   - Surface proteins: 0-20 points
   - RBD candidates: 0-30 points
   - Zoonotic similarity: 0-20 points
   - **Total: 0-100 points**

#### Risk Categories

🔴 **HIGH RISK (70-100 points)**
- Immediate investigation recommended
- Report to institutional biosafety committee
- Report to public health authorities (if appropriate)
- BSL-3 or higher containment required for experimental work
- **STOP experimental work until safety review**

🟡 **MEDIUM RISK (40-69 points)**
- Further characterization warranted
- Monitor for additional samples
- Consider experimental validation
- Standard BSL-2 precautions minimum

🟢 **LOW RISK (0-39 points)**
- Standard surveillance
- Archive for comparative studies
- Routine safety protocols

#### Outputs

```
phase6_zoonotic/
├── furin_sites/
│   ├── <Sample_Name>_furin_sites.txt               # ⚠️ All detected furin sites
│   └── <Sample_Name>_furin_containing_proteins.faa # Proteins with sites
├── rbd_analysis/
│   ├── <Sample_Name>_spike_proteins.faa            # Surface proteins
│   └── <Sample_Name>_rbd_candidates.faa            # ⚠️ RBD candidates
├── zoonotic_similarity/
│   ├── <Sample_Name>_vs_zoonotic.blastp            # BLAST results
│   └── <Sample_Name>_zoonotic_similarity.txt       # Summary
├── receptor_analysis/
│   └── <Sample_Name>_rbd_patterns.txt              # RBD features
└── results/
    ├── <Sample_Name>_zoonotic_risk_report.txt      # ⭐ Main report
    └── <Sample_Name>_zoonotic_summary.tsv          # Summary table
```

#### Key Interpretation

**Furin Cleavage Sites:**
- Presence indicates potential for enhanced transmissibility
- Found in SARS-CoV-2, HPAI influenza
- Multiple sites = higher concern

**RBD Candidates:**
- Determine host tropism
- Structural features similar to known zoonotic viruses
- Key for cross-species transmission

**High Similarity to Known Pathogens:**
- >80% identity = RED ALERT
- 60-80% identity = Investigation needed
- <60% identity = Monitor

#### Important Disclaimers

⚠️ **This is computational prediction only**
- Requires experimental validation
- High score ≠ confirmed zoonotic capability
- All HIGH RISK findings (≥70 points) MUST be reported to:
  - Institutional biosafety committee
  - Public health authorities (if appropriate)
- BSL-3 or higher containment required for experimental work
- Follow institutional and regulatory biosafety protocols
- Maintain sample security and chain of custody

---

### Phase 7: Publication Report Generation (NEW v2.2)

**Script:** `viral-report-generation.sh`
**Execution time:** 30 minutes - 1 hour
**Purpose:** Generate publication-ready figures, tables, and reports

#### Key Outputs

##### 1. Publication Figures (PDF + PNG, 300 DPI)

**Figure 1: Viral Recovery Flowchart**
- Data prepared for manual figure creation
- Includes all key metrics from Phase 1
- Can be created in BioRender, Draw.io

**Figure 2: AMG Functional Heatmap**
- Presence/absence matrix of auxiliary metabolic genes
- Clustered by similarity
- R-based visualization (pheatmap)
- Color-coded by functional category

**Figure 3: Phylogenetic Tree**
- Maximum likelihood tree from Phase 3
- Bootstrap support values displayed
- ggtree visualization (circular or rectangular)
- Ready for FigTree/iTOL import
- Includes tree file (.nwk format)

**Figure 4: Viral Diversity Plots**
- Genome size distribution
- GC content distribution
- Viral family composition
- Completeness categories
- 4-panel matplotlib visualization

##### 2. Supplementary Tables (TSV format)

**Table S1: High-Quality Viral Genomes**
```
Genome_ID | Length | Completeness | Contamination | Viral_genes | Host_genes
----------|--------|--------------|---------------|-------------|------------
virus_001 | 35,421 | 95.2%        | 0.3%          | 45          | 0
virus_002 | 28,734 | 92.1%        | 1.2%          | 38          | 1
...
```
**Source**: CheckV quality metrics

**Table S2: AMG Predictions**
```
Genome_ID | Gene_ID | Function           | Category        | Confidence
----------|---------|--------------------|-----------------|-----------
virus_001 | gene_12 | Photosystem II D1  | Photosynthesis  | High
virus_002 | gene_05 | Phosphate transport| Nutrient        | Medium
...
```
**Source**: DRAM-v distill output

**Table S3: Host Predictions**
```
Virus     | Host           | Method  | Score | Evidence
----------|----------------|---------|-------|------------------
virus_001 | Bacteria_sp_1  | CRISPR  | 95.2  | Spacer_match
virus_002 | Bacteria_sp_2  | K-mer   | 87.3  | Composition
...
```
**Source**: Phase 5 integrated predictions

**Table S4: Zoonotic Risk Assessment**
```
Genome_ID | Furin_sites | RBD_present | Risk_score | Risk_level
----------|-------------|-------------|------------|------------
virus_001 | 2           | Yes         | 75         | HIGH
virus_002 | 0           | No          | 15         | LOW
...
```
**Source**: Phase 6 risk assessment

##### 3. Methods Section

**Ready-to-use manuscript text** including:
- Complete methods for all 7 phases
- Software versions and citations
- Database versions
- Statistical analyses
- Parameter settings
- Data availability statement template

**Template structure:**
- Sample processing and sequencing
- Assembly and viral recovery (Phase 1)
- Functional annotation (Phase 2)
- Phylogenetic analysis (Phase 3)
- Comparative genomics (Phase 4)
- Host prediction (Phase 5)
- Zoonotic assessment (Phase 6)
- Statistical analysis

##### 4. Interactive HTML Report

**Complete analysis summary** with:
- Executive summary dashboard
- Phase-by-phase results with color coding
- Key findings highlighted
- Links to all output files
- Publication materials checklist
- Next steps for manuscript preparation
- Modern responsive design
- Shareable with collaborators

#### Output Structure

```
phase7_publication_report/
├── figures/
│   ├── Figure2_AMG_Heatmap.pdf                   # Publication figure
│   ├── Figure2_AMG_Heatmap.png                   # High-res version
│   ├── Figure3_Phylogenetic_Tree.pdf             # ML tree
│   ├── Figure3_Phylogenetic_Tree.png
│   ├── Figure3_Tree_File.nwk                     # For FigTree/iTOL
│   ├── Figure4_Diversity.pdf                     # Diversity plots
│   ├── Figure4_Diversity.png
│   ├── generate_figures.R                        # R script for customization
│   └── generate_diversity_plots.py               # Python script
├── tables/
│   ├── TableS1_Viral_Genomes.tsv                 # Supplementary data
│   ├── TableS2_AMG_Predictions.tsv
│   ├── TableS3_Host_Predictions.tsv
│   └── TableS4_Zoonotic_Risk.tsv
├── methods/
│   └── methods_section.txt                       # ⭐ Complete methods text
├── html_report/
│   └── interactive_report.html                   # ⭐ Open in browser
└── <Sample_Name>_publication_report_summary.txt  # Quick reference
```

#### Tools Used

**R packages (automatic installation):**
- ggplot2, pheatmap, ggtree, treeio
- RColorBrewer, reshape2, ape
- BiocManager for Bioconductor packages

**Python libraries:**
- matplotlib, seaborn
- BioPython (already in environment)
- numpy, pandas

#### Customization

All generated figures can be customized:
- Colors, labels, fonts
- Figure dimensions
- Export formats
- Journal-specific requirements

R and Python scripts are included in the output directory for easy modification.

---

## Output Structure

```
viral_analysis_output/
├── phase1_recovery/              # Viral genome recovery
├── phase2_annotation/            # Functional annotation
├── phase3_phylogenetics/         # Phylogenetic trees
├── phase4_comparative/           # Comparative genomics
├── phase5_host_ecology/          # Host prediction + ecology
├── phase6_zoonotic/              # Zoonotic risk assessment (NEW v2.2)
│   ├── furin_sites/
│   ├── rbd_analysis/
│   ├── zoonotic_similarity/
│   └── results/
├── phase7_publication_report/    # Publication materials (NEW v2.2)
│   ├── figures/
│   ├── tables/
│   ├── methods/
│   └── html_report/
├── final_results/                # Key files (easy access)
│   ├── <Sample_Name>_hq_viruses.fasta                    # HQ viral genomes
│   ├── amg_summary.tsv                                   # AMG predictions
│   ├── <Sample_Name>_viral.treefile                      # Phylogenetic tree
│   ├── genome_by_genome_overview.csv                     # Taxonomy
│   ├── <Sample_Name>_host_predictions.tsv                # Host predictions
│   ├── <Sample_Name>_zoonotic_risk_report.txt            # Risk assessment
│   ├── interactive_report.html                           # HTML dashboard
│   └── <Sample_Name>_complete_analysis_summary.txt       # Master report ⭐
└── <Sample_Name>_complete_analysis.log    # Complete log
```

---

## Methods Section Template

Use this template for your manuscript methods section:

### Viral Metagenome Assembly and Recovery

> Metagenomic reads were assembled using MEGAHIT v1.2.9 (Li et al., 2015) and SPAdes v3.15.5 (Bankevich et al., 2012). Viral sequences were identified from assembled contigs using VirSorter2 v2.2.4 (Guo et al., 2021) with a minimum length threshold of 1,500 bp and confidence score ≥0.5. Viral genome quality was assessed using CheckV v1.0.1 (Nayfach et al., 2021), and high-quality viral genomes (≥90% complete, <5% contamination) were selected for downstream analysis. Viral genome binning was performed using vRhyme v1.0.0 (Kieft et al., 2022) to reconstruct complete genomes from viral fragments.

### Functional Annotation

> Viral genes were predicted using Prodigal-gv v2.11.0 (Camargo et al., 2023) in metagenomic mode. Functional annotation was performed using DRAM-v v1.4.6 (Shaffer et al., 2020), which annotates viral genes against multiple databases including KEGG, Pfam, and VOG. Auxiliary metabolic genes (AMGs) were identified using DRAM-v distill with default thresholds.

### Phylogenetic Analysis

> Viral genomes were aligned using MAFFT v7.520 (Katoh & Standley, 2013) with the auto alignment strategy. Poorly aligned regions were trimmed using trimAl v1.4.1 (Capella-Gutiérrez et al., 2009) with the automated1 heuristic. Maximum likelihood phylogenetic trees were inferred using IQ-TREE v2.2.2.6 (Nguyen et al., 2015) with automatic model selection (ModelFinder) and 1,000 ultrafast bootstrap replicates. Bayesian phylogenetic inference was performed using MrBayes v3.2.7 (Ronquist et al., 2012) with two independent runs of 1,000,000 generations.

### Comparative Genomics and Taxonomy

> Viral proteins were clustered using MMseqs2 v14.7e284 (Steinegger & Söding, 2017) at 90% sequence identity and 80% coverage to identify protein families. Viral taxonomy was assigned using vConTACT2 v0.11.3 (Jang et al., 2019), which builds protein-sharing networks and compares them to the NCBI Viral RefSeq database. Additional viral annotations were obtained using geNomad v1.5.2 (Camargo et al., 2023).

### Host Prediction

> Viral hosts were predicted using four complementary approaches: (1) CRISPR spacer matching using MinCED v0.4.2 and BLAST v2.14.1, (2) tRNA matching using tRNAscan-SE v2.0.12 (Chan et al., 2021), (3) k-mer composition similarity using Mash v2.3 (Ondov et al., 2016) with k=16 and sketch size 10,000, and (4) protein homology using Diamond v2.1.8 (Buchfink et al., 2015). Predictions from multiple methods were integrated, with CRISPR matches assigned highest confidence.

### Zoonotic Risk Assessment

> Computational zoonotic risk assessment was performed on all recovered viral genomes. Furin cleavage sites were identified using pattern matching (R-X-[KR]-R motif and variants). Receptor binding domain (RBD) candidates were identified based on cysteine content (4-8 residues), aromatic and charged residue enrichment, and size filtering (150-400 AA). Surface proteins were identified using keyword-based searches and glycosylation site analysis. Risk scores (0-100 points) were calculated based on the presence of furin sites (30 points), surface proteins (20 points), RBD candidates (30 points), and similarity to known zoonotic viruses via BLASTP (20 points, E-value < 1e-5). **Note: These are computational predictions requiring experimental validation.**

### Statistical Analysis

> Viral diversity was assessed using genome count, size distribution, and GC content distribution. [Add additional statistics as appropriate for your study.]

---

## Timing Estimates

Based on a typical metagenomic sample with ~1,000 contigs:

| Phase | Description | Time | Memory | Notes |
|-------|-------------|------|--------|-------|
| **Phase 1** | Viral Recovery | 2-4h | 64 GB | VirSorter2 is rate-limiting |
| **Phase 2** | Annotation | 3-6h | 128 GB | DRAM-v database searches |
| **Phase 3** | Phylogenetics | 4-8h | 64 GB | Depends on genome count |
| **Phase 4** | Comparative | 2-4h | 128 GB | vConTACT2 network building |
| **Phase 5** | Host/Ecology | 2-4h | 64 GB | With host genomes |
| **Phase 6** | Zoonotic | 1-2h | 64 GB | Furin + RBD analysis |
| **Phase 7** | Reports | 0.5-1h | 32 GB | Figure generation |
| **Total** | All Phases | **15-29h** | **256 GB** | Phases run sequentially |

**Optimization Tips:**

- Run Phase 3 only on representative genomes (cluster at 95% ANI first)
- Skip Phase 3 entirely if phylogenetics not needed
- Run Phase 5 without host genomes (ecology only) = much faster
- Skip Phase 6 if zoonotic assessment not relevant
- Always run Phase 7 for publication-ready outputs
- Use `--phases` to run only essential phases

---

## Troubleshooting

### Common Issues

#### 1. No viral genomes recovered (Phase 1)

**Symptom**: VirSorter2 finds no viruses

**Causes**:
- Contigs too short (< 1,500 bp)
- Not a viral-enriched sample
- Low viral abundance

**Solutions**:

```bash
# Lower minimum length
# Edit viral-genome-recovery.sh line ~115
--min-length 1000  # Instead of 1500

# Lower confidence threshold
--min-score 0.3    # Instead of 0.5

# Check VirSorter2 output
cat phase1_recovery/virsorter2/final-viral-score.tsv
```

#### 2. DRAM-v fails (Phase 2)

**Symptom**: DRAM-v crashes or produces no output

**Causes**:
- Database not downloaded
- Insufficient memory
- Corrupted database
- FTP connection issues (VOG database)

**Solutions**:

```bash
# Download/update DRAM databases
DRAM-setup.py prepare_databases --output_dir ~/DRAM_databases

# Increase memory in SLURM header
#SBATCH --mem=256GB

# Check DRAM configuration
DRAM-setup.py print_config

# Fix DRAM VOG database issues (if encountered)
# See fixes/DRAM_TROUBLESHOOTING.md for complete guide
bash scripts/DRAM_FIX.sh
```

#### 3. IQ-TREE runs forever (Phase 3)

**Symptom**: Phase 3 takes > 24 hours

**Causes**:
- Too many sequences
- Very divergent sequences
- Large alignment

**Solutions**:

```bash
# Pre-cluster genomes at 95% ANI
# Use only cluster representatives
dRep dereplicate \
    --genomes viral_genomes/*.fasta \
    --S_algorithm ANImf \
    --P_ani 0.95

# Or use FastTree instead of IQ-TREE
# Edit viral-phylogenetics.sh to use FastTree
```

#### 4. vConTACT2 fails (Phase 4)

**Symptom**: No network generated

**Causes**:
- Too few viral genomes (< 10)
- No matches to reference database
- MCL clustering fails

**Solutions**:

```bash
# Check number of genomes
grep -c "^>" phase1_recovery/high_quality_viruses/*.fasta

# If < 10 genomes, vConTACT2 may not work well
# Use geNomad results instead
cat phase4_comparative/genomad/*/virus_summary.tsv

# Increase verbosity to debug
vcontact2 --verbose
```

#### 5. No host predictions (Phase 5)

**Symptom**: All prediction files empty

**Causes**:
- No CRISPR arrays in hosts
- Viral-host mismatch (viruses don't infect provided hosts)
- Host genomes incomplete

**Solutions**:

```bash
# Check CRISPR spacer count
grep -c "^>" phase5_host_ecology/crispr/*_spacers.fasta

# If 0, no CRISPR arrays found (common)
# Rely on k-mer and protein methods

# Check k-mer similarity
awk '$3 < 0.2' phase5_host_ecology/kmer_analysis/*_similarity.txt

# Lower Mash distance threshold for more predictions
```

#### 6. Phase 6 - No furin sites detected

**Symptom**: Phase 6 reports zero furin sites

**Causes**:
- Expected for many viral families
- Not all viruses have furin sites
- Phase 2 proteins not available

**Solutions**:

```bash
# This is often NORMAL - most viruses don't have furin sites
# Check that Phase 2 completed successfully
ls -lh phase2_annotation/prodigal/*_proteins.faa

# Verify protein file is not empty
grep -c "^>" phase2_annotation/prodigal/*_proteins.faa

# Review risk report anyway (other features assessed)
cat phase6_zoonotic/results/*_zoonotic_risk_report.txt
```

#### 7. Phase 7 - Missing R packages

**Symptom**: Figure generation fails

**Causes**:
- R packages not installed
- BiocManager packages missing
- Permission errors

**Solutions**:

```bash
# Script attempts automatic installation, but if it fails:
R
> install.packages(c("ggplot2", "pheatmap", "RColorBrewer", "reshape2"))
> if (!requireNamespace("BiocManager", quietly = TRUE))
>     install.packages("BiocManager")
> BiocManager::install("ggtree")
> BiocManager::install("treeio")

# Or manually install in conda environment
conda activate pimgavir_viralgenomes
conda install -c bioconda r-ggplot2 r-pheatmap bioconductor-ggtree
```

---

## Advanced Usage

### Running Individual Phases

Sometimes you want to re-run a single phase with different parameters:

#### Re-run Phase 1 with Lower Thresholds

```bash
# Edit viral-genome-recovery.sh
# Change line ~115: --min-length 1000
# Change line ~116: --min-score 0.3

sbatch viral-genome-recovery.sh \
    megahit_contigs.fasta \
    phase1_redo \
    40 \
    <Sample_Name> \
    MEGAHIT
```

#### Re-run Phase 6 with Zoonotic Database

```bash
# First time without database, now add it
sbatch viral-zoonotic-assessment.sh \
    phase1_recovery/high_quality_viruses/<Sample_Name>_hq_viruses.fasta \
    phase2_annotation/prodigal/<Sample_Name>_proteins.faa \
    phase6_redo \
    40 \
    <Sample_Name> \
    /path/to/known_zoonotic_viruses.fasta
```

### Integrating with Main PIMGAVir Pipeline

The 7-phase workflow is automatically integrated when using `--ass_based`:

```bash
# Step 1: Run main PIMGAVir pipeline
sbatch PIMGAVIR_conda.sh \
    <Sample_Name>_R1.fastq.gz \
    <Sample_Name>_R2.fastq.gz \
    <Sample_Name> \
    40 \
    --ass_based

# This now automatically runs all 7 phases on both assemblies!
# Results in:
# - viral-genomes-megahit/ (7 phases)
# - viral-genomes-spades/ (7 phases)
```

---

## Performance Optimization

### For Large Datasets (>10,000 contigs)

1. **Pre-filter contigs**:

```bash
# Keep only contigs > 5 kb (likely to contain complete genes)
seqkit seq -m 5000 megahit_contigs.fasta > megahit_filtered.fasta
```

2. **Use selective phases**:

```bash
sbatch viral-genome-complete-7phases.sh \
    megahit_filtered.fasta \
    output \
    40 \
    sample \
    "" \
    "" \
    "" \
    --phases 1,2,6,7  # Skip time-consuming phylogenetics and comparative
```

3. **Dereplicate before phylogenetics**:

```bash
# After Phase 1, cluster at 95% ANI
# Only run Phase 3 on cluster representatives
```

### For Multiple Samples

Use GNU Parallel or array jobs:

```bash
# Create sample list
ls assemblies/*.fasta > sample_list.txt

# Run in parallel (adjust -j for available resources)
cat sample_list.txt | parallel -j 4 \
    "sbatch viral-genome-complete-7phases.sh {} viral_output/{/.} 40 {/.}"
```

---

## Publication Checklist

### Using All 7 Phases for Manuscript

#### Main Text Figures
- ✅ Figure 1: Viral recovery flowchart (Phase 1 data, create manually)
- ✅ Figure 2: AMG heatmap (Phase 7 auto-generated)
- ✅ Figure 3: Phylogenetic tree (Phase 7 auto-generated)
- ✅ Figure 4: Diversity plots (Phase 7 auto-generated)

#### Supplementary Materials
- ✅ Table S1: Viral genomes (Phase 7 auto-generated)
- ✅ Table S2: AMG predictions (Phase 7 auto-generated)
- ✅ Table S3: Host predictions (Phase 7 auto-generated)
- ✅ Table S4: Zoonotic assessment (Phase 7 auto-generated)

#### Methods Section
- ✅ Copy from Phase 7: `methods/methods_section.txt`
- ✅ Adapt to specific study design
- ✅ Add sample collection details
- ✅ Include statistical tests used

#### Data Availability
- ✅ Deposit viral genomes to NCBI GenBank
- ✅ Upload assemblies to NCBI SRA
- ✅ Share analysis scripts (GitHub/Zenodo)
- ✅ Include database versions in methods

#### Safety and Ethics
- ✅ For manuscripts reporting viral discovery:
  - Include zoonotic assessment in Results
  - Use risk scores as screening criteria
  - Cite computational prediction limitations
  - Recommend experimental validation for high-risk viruses

- ✅ For public health reports:
  - Highlight any HIGH RISK findings immediately
  - Provide detailed furin site sequences
  - Include RBD characteristics
  - Suggest containment level for follow-up
  - Report to appropriate authorities

---

## References

### Software Citations

1. **VirSorter2**: Guo, J., Bolduc, B., Zayed, A.A. et al. VirSorter2: a multi-classifier, expert-guided approach to detect diverse DNA and RNA viruses. *Microbiome* 9, 37 (2021).

2. **CheckV**: Nayfach, S., Camargo, A.P., Schulz, F. et al. CheckV assesses the quality and completeness of metagenome-assembled viral genomes. *Nat Biotechnol* 39, 578–585 (2021).

3. **vRhyme**: Kieft, K., Adams, A., Salamzade, R. et al. vRhyme enables binning of viral genomes from metagenomes. *Nucleic Acids Research* 50, e83 (2022).

4. **DRAM**: Shaffer, M., Borton, M.A., McGivern, B.B. et al. DRAM for distilling microbial metabolism to automate the curation of microbiome function. *Nucleic Acids Research* 48, 8883–8900 (2020).

5. **IQ-TREE**: Nguyen, L.T., Schmidt, H.A., von Haeseler, A., Minh, B.Q. IQ-TREE: a fast and effective stochastic algorithm for estimating maximum-likelihood phylogenies. *Mol Biol Evol* 32, 268-274 (2015).

6. **vConTACT2**: Jang, H.B., Bolduc, B., Zablocki, O. et al. Taxonomic assignment of uncultivated prokaryotic virus genomes is enabled by gene-sharing networks. *Nat Biotechnol* 37, 632–639 (2019).

7. **geNomad**: Camargo, A.P., Nayfach, S., Chen, I.M.A. et al. Identification of mobile genetic elements with geNomad. *Nat Biotechnol* (2023).

### Database Citations

- **NCBI RefSeq Viral**: Brister, J.R., et al. NCBI viral genomes resource. *Nucleic Acids Res* 43, D571-D577 (2015).
- **KEGG**: Kanehisa, M., Goto, S. KEGG: Kyoto Encyclopedia of Genes and Genomes. *Nucleic Acids Res* 28, 27-30 (2000).
- **Pfam**: Mistry, J., et al. Pfam: The protein families database in 2021. *Nucleic Acids Res* 49, D412-D419 (2021).
- **VOG**: Grazziotin, A.L., Koonin, E.V., Kristensen, D.M. Prokaryotic Virus Orthologous Groups (pVOGs). *Nucleic Acids Res* 45, D491-D498 (2017).

---

## Support and Contact

**Documentation**:
- Complete guide: This file (`VIRAL_GENOME_COMPLETE_7PHASES.md`)
- Quick start: `VIRAL_GENOME_QUICKSTART.md`
- Implementation summary: `VIRAL_GENOME_IMPLEMENTATION_SUMMARY.md`

**Troubleshooting**:
- DRAM issues: `fixes/DRAM_TROUBLESHOOTING.md`
- General issues: This file, Troubleshooting section

**Issues**: Report bugs or request features via GitHub issues

**Questions**: Contact the PIMGAVir development team

**Safety**: For HIGH RISK zoonotic findings, report immediately to:
- Institutional biosafety committee
- Public health authorities (if appropriate)
- Follow institutional and regulatory protocols

---

**Version:** 2.2.0
**Last Updated:** 2025-11-03
**Status:** Production-ready ✅
