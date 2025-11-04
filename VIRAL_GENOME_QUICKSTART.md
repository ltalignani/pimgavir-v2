# Guide Rapide : Analyse de Génomes Viraux Complets

**Version:** PIMGAVir v2.2
**Date:** 29 octobre 2025

---

## Vue d'ensemble

Ce module permet d'identifier et de caractériser des **génomes viraux complets** (10-40 kb) à partir d'assemblages métagénomiques, au-delà de l'approche par PCR ciblée (fragments de 415-531 bp).

**Capacités clés :**
- 🦠 Identification automatique de virus (VirSorter2)
- ✅ Évaluation de la qualité des génomes (CheckV)
- 🧬 Annotation fonctionnelle (DRAM-v, détection d'AMG)
- 🌳 Analyse phylogénétique (MAFFT, IQ-TREE)

---

## Installation Rapide

### Étape 1 : Créer l'environnement conda

```bash
cd scripts/
conda env create -f pimgavir_viralgenomes.yaml
```

**Durée :** ~30-60 minutes
**Espace disque :** ~10 GB pour l'environnement

### Étape 2 : Activer l'environnement

```bash
conda activate pimgavir_viralgenomes
```

### Étape 3 : Configurer les bases de données

```bash
./setup_viral_databases.sh
```

**Choix recommandés lors de l'installation :**
- ✅ **VirSorter2** (~10 GB) - **OBLIGATOIRE**
- ✅ **CheckV** (~1.5 GB) - **OBLIGATOIRE**
- ⚠️  **DRAM** (~150 GB) - **RECOMMANDÉ** pour l'annotation fonctionnelle
- ❌ **RVDB** (~5 GB) - **OPTIONNEL** pour les comparaisons BLAST

**Minimum requis :** VirSorter2 + CheckV = ~12 GB
**Configuration complète :** ~167 GB

---

## Utilisation

### Mode Automatique (Intégré au pipeline)

L'analyse des génomes viraux s'exécute **automatiquement** lors de l'utilisation du mode assembly :

```bash
# Lancer le pipeline en mode assembly
sbatch PIMGAVIR_conda.sh 40 --ass_based

# Ou en mode ALL (read + assembly + clustering)
sbatch PIMGAVIR_conda.sh 40 ALL

# Version Infiniband (cluster IRD)
sbatch PIMGAVIR_conda_ib.sh 40 ALL
```

L'analyse virale démarre automatiquement après la complétion des assemblages MEGAHIT et SPAdes.

### Mode Standalone (Sur assemblages existants)

Pour analyser un assemblage déjà généré :

```bash
conda activate pimgavir_viralgenomes

bash viral-genome-complete.sh \
    mon_assemblage.fasta \
    resultats_virus \
    40 \
    MonEchantillon \
    MEGAHIT \
    NONE
```

**Arguments :**
1. Fichier d'assemblage (FASTA)
2. Répertoire de sortie
3. Nombre de threads
4. Nom de l'échantillon
5. Assembleur utilisé (MEGAHIT ou SPADES)
6. Protéines de référence (ou "NONE")

---

## Workflow en 3 Phases

### Phase 1 : Récupération des Génomes Viraux

**Outils :** VirSorter2 → CheckV → vRhyme

**Durée :** ~3-5 heures

**Sorties importantes :**
```
phase1_recovery/
├── 04_final_genomes/
│   └── Echantillon_MEGAHIT_viral_genomes_hq.fna  ⭐ Génomes viraux haute qualité
└── 05_statistics/
    └── Echantillon_MEGAHIT_viral_recovery_summary.txt
```

**Critères de qualité :**
- **Complets** : 100% de complétude estimée
- **Haute qualité** : ≥90% de complétude
- **Qualité moyenne** : 50-90% de complétude

### Phase 2 : Annotation Fonctionnelle

**Outils :** Prodigal-gv → DRAM-v → InterProScan (optionnel)

**Durée :** ~6-10 heures

**Sorties importantes :**
```
phase2_annotation/
├── 01_prodigal/
│   └── Echantillon_MEGAHIT_proteins.faa  ⭐ Protéines prédites
├── 02_dramv/
│   ├── annotations.tsv                    ⭐ Annotations fonctionnelles
│   └── distillate/                        ⭐ Résumé des AMG
└── 04_summary/
    └── Echantillon_MEGAHIT_annotation_summary.txt
```

**Informations clés :**
- **AMG (Auxiliary Metabolic Genes)** : Gènes volés à l'hôte
- **Gènes de signature virale** : Protéines structurales, RdRp, etc.
- **Voies métaboliques** : Interactions hôte-virus

### Phase 3 : Analyse Phylogénétique

**Outils :** MAFFT → trimAl → IQ-TREE → MrBayes (optionnel)

**Durée :** ~2-4 heures

**Sorties importantes :**
```
phase3_phylogenetics/
├── 01_alignment/
│   └── Echantillon_all_proteins_aligned_trimmed.faa
└── 02_trees/
    └── Echantillon_all_proteins_iqtree.treefile  ⭐ Arbre phylogénétique
```

**Visualisation :**
- FigTree : https://github.com/rambaut/figtree/releases
- iTOL : https://itol.embl.de/
- R ggtree : Package R pour arbres publication

---

## Fichiers de Sortie Essentiels

### Pour une analyse rapide

1. **Rapport principal :**
   ```
   reports/Echantillon_MEGAHIT_viral_genome_report.txt
   ```
   Résumé complet avec toutes les statistiques

2. **Génomes viraux :**
   ```
   phase1_recovery/04_final_genomes/Echantillon_MEGAHIT_viral_genomes_hq.fna
   ```
   Génomes complets haute qualité (≥90%)

3. **Annotations fonctionnelles :**
   ```
   phase2_annotation/02_dramv/annotations.tsv
   ```
   Tous les gènes avec assignations fonctionnelles

4. **Analyse AMG :**
   ```
   phase2_annotation/02_dramv/distillate/
   ```
   Gènes auxiliaires du métabolisme (interaction hôte)

5. **Arbre phylogénétique :**
   ```
   phase3_phylogenetics/02_trees/Echantillon_iqtree.treefile
   ```
   Arbre ML avec support bootstrap

---

## Questions Fréquentes

### Q1 : Aucun génome viral trouvé

**Raisons possibles :**
- Pas de virus dans l'échantillon
- Assemblage trop fragmenté (profondeur insuffisante)
- Seuils de qualité trop stricts

**Solutions :**
```bash
# Vérifier les résultats de VirSorter2
grep -c "^>" phase1_recovery/01_virsorter/final-viral-combined.fa

# Vérifier la distribution de qualité CheckV
awk -F'\t' 'NR>1 {print $8}' phase1_recovery/02_checkv/quality_summary.tsv | sort | uniq -c

# Abaisser le seuil de complétude manuellement
awk -F'\t' 'NR==1 || $7 >= 50' phase1_recovery/02_checkv/quality_summary.tsv > qualite_moyenne.tsv
```

### Q2 : DRAM-v échoue

**Raisons possibles :**
- Bases de données non installées
- Configuration DRAM incorrecte
- Mémoire insuffisante (nécessite 64 GB+)

**Solutions :**
```bash
# Vérifier l'état des bases DRAM
DRAM-setup.py print_config

# Réinstaller les bases de données
DRAM-setup.py prepare_databases --output_dir DBs/ViralGenomes/dram-db
DRAM-setup.py set_database_locations --config_loc DBs/ViralGenomes/dram-db/CONFIG

# Augmenter la mémoire SLURM
#SBATCH --mem=128GB
```

### Q3 : Le pipeline est trop lent

**Optimisations :**
- Sauter InterProScan (automatique si >10K protéines)
- Sauter MrBayes (automatique si >50 séquences)
- Réduire les threads pour économiser la mémoire
- Analyser MEGAHIT et SPAdes séparément

**Exemple :**
```bash
# Analyser seulement l'assemblage MEGAHIT
bash viral-genome-complete.sh \
    megahit_contigs.fasta \
    virus_megahit \
    40 \
    Echantillon \
    MEGAHIT \
    NONE
```

### Q4 : Combien de temps prend l'analyse ?

**Estimations pour 1M de reads paired-end :**

| Phase | Durée Typique | RAM Pic |
|-------|---------------|---------|
| Phase 1 | 3-5 heures | 32 GB |
| Phase 2 | 6-10 heures | 64 GB |
| Phase 3 | 2-4 heures | 16 GB |
| **Total** | **12-20 heures** | **64 GB** |

### Q5 : Puis-je utiliser mes propres protéines de référence ?

**Oui !** Ajoutez un fichier FASTA de protéines de référence :

```bash
bash viral-genome-complete.sh \
    assemblage.fasta \
    resultats \
    40 \
    Echantillon \
    MEGAHIT \
    mes_references_coronavirus_RdRp.faa  # Au lieu de "NONE"
```

Cela permet de placer vos virus dans le contexte phylogénétique de virus connus.

---

## Exemples d'Utilisation

### Exemple 1 : Surveillance de coronavirus chez les chauves-souris

```bash
# 1. Placer les échantillons dans input/
mkdir -p input/
cp /chemin/vers/echantillons/*_R*.fastq.gz input/

# 2. Lancer le pipeline complet (batch mode)
sbatch PIMGAVIR_conda.sh 40 ALL

# 3. Résultats dans results/JOBID_Echantillon_ALL/
# Rechercher les génomes viraux :
ls -lh results/*/viral-genomes-*/phase1_recovery/04_final_genomes/*_hq.fna

# 4. Vérifier les AMG pour interaction hôte
cat results/*/viral-genomes-*/phase2_annotation/02_dramv/distillate/amg_summary.tsv
```

### Exemple 2 : Analyse d'un assemblage existant

```bash
conda activate pimgavir_viralgenomes

# Télécharger des RdRp de coronavirus de référence
# (depuis NCBI ou base personnelle)
wget https://example.com/coronavirus_RdRp_references.faa

# Analyser l'assemblage avec références
bash viral-genome-complete.sh \
    mon_assemblage_spades.fasta \
    virus_spades \
    40 \
    Echantillon_chauve_souris_01 \
    SPADES \
    coronavirus_RdRp_references.faa

# Visualiser l'arbre phylogénétique
# Ouvrir avec FigTree ou iTOL :
firefox https://itol.embl.de/
# Upload: virus_spades/phase3_phylogenetics/02_trees/*_iqtree.treefile
```

### Exemple 3 : Analyse des eaux usées (viromes multiples)

```bash
# Préparer plusieurs échantillons
for sample in Site1 Site2 Site3 Site4; do
    mkdir -p input/
    cp /data/wastewater/${sample}_R*.fastq.gz input/
done

# Lancer en batch avec Infiniband (cluster IRD)
sbatch PIMGAVIR_conda_ib.sh 40 ALL

# Comparer les génomes viraux entre sites
for dir in results/*/viral-genomes-megahit/; do
    sample=$(basename $(dirname $dir))
    count=$(grep -c "^>" $dir/phase1_recovery/04_final_genomes/*_hq.fna 2>/dev/null || echo 0)
    echo "$sample: $count génomes viraux HQ"
done
```

---

## Prochaines Étapes pour Publication

### 1. Classification Taxonomique

**Actions :**
- Utiliser l'arbre phylogénétique pour placement ICTV
- Calculer l'identité avec génomes de référence NCBI
- Comparer avec RefSeq viral

**Outils :**
```bash
# Classification automatique avec vConTACT2
vcontact2 --raw-proteins proteins.faa \
          --rel-mode Diamond \
          --db ProkaryoticViralRefSeq85-Merged \
          --output-dir vcontact2_out
```

### 2. Caractérisation des Génomes

**Analyses :**
- Organisation génomique (ordre des gènes, synténie)
- Contenu G+C et usage des codons
- Identification des gènes clés (RdRp, capside, spike, etc.)
- Comparaison avec proches parents

**Outils :**
```bash
# Visualisation de synténie avec Clinker
clinker genome1.gbk genome2.gbk -o clinker_output
```

### 3. Évaluation du Potentiel Zoonotique

**Pour coronavirus et apparentés :**
- Détection de sites de clivage furine dans protéines spike
- Analyse du domaine de liaison au récepteur (RBD)
- Comparaison avec virus zoonotiques connus (SARS-CoV-2, MERS-CoV)

**Outils :**
```bash
# Recherche de sites furine
grep -E "R.[KR].R" proteins.faa

# BLAST du RBD contre domaines connus
blastp -query spike_protein.faa \
       -db known_rbds.faa \
       -outfmt 6
```

### 4. Visualisation pour Publication

**Figures de qualité publication :**
- Cartes de génomes avec annotations (genoPlotR, gggenes en R)
- Arbres phylogénétiques avec support bootstrap (ggtree en R)
- Graphiques de génomique comparative (Circos, ggplot2)
- Distribution fonctionnelle des AMG (ggplot2)

**Exemple R (arbre) :**
```R
library(ggtree)
library(ggplot2)

tree <- read.tree("Echantillon_iqtree.treefile")

ggtree(tree, layout="circular") +
  geom_tiplab(size=3, offset=0.01) +
  geom_nodepoint(aes(color=as.numeric(label)), size=3) +
  scale_color_gradient(low="blue", high="red",
                       limits=c(0,100),
                       name="Bootstrap") +
  theme_tree2() +
  ggtitle("Analyse Phylogénétique - Protéines RdRp Virales")

ggsave("arbre_phylogenetique.pdf", width=10, height=10)
```

---

## Performance et Ressources

### Configuration Minimale

```bash
#SBATCH --partition=highmem
#SBATCH --mem=64GB
#SBATCH --cpus-per-task=40
#SBATCH --time=1-12:00:00
```

### Configuration Recommandée

```bash
#SBATCH --partition=highmem
#SBATCH --mem=128GB
#SBATCH --cpus-per-task=40
#SBATCH --time=2-00:00:00
```

### Espace Disque

| Composant | Taille | Requis ? |
|-----------|--------|----------|
| Base VirSorter2 | 10 GB | ✅ Oui |
| Base CheckV | 1.5 GB | ✅ Oui |
| Bases DRAM | 150 GB | ⚠️  Recommandé |
| Base RVDB | 5 GB | ❌ Optionnel |
| Sortie par échantillon | 2-5 GB | - |
| **Total bases** | **~167 GB** | - |

---

## Support et Dépannage

### Logs à Vérifier

1. **Log principal du pipeline :**
   ```
   logs/pimgavir_JOBID_TASKID.out
   logs/pimgavir_JOBID_TASKID.err
   ```

2. **Log de l'analyse virale :**
   ```
   viral-genomes-*/viral_genome_analysis.log
   ```

3. **Logs de chaque phase :**
   ```
   viral-genomes-*/phase1_recovery/viral_recovery.log
   viral-genomes-*/phase2_annotation/viral_annotation.log
   viral-genomes-*/phase3_phylogenetics/phylogenetics.log
   ```

### Obtenir de l'Aide

1. **Consulter la documentation complète :**
   - `VIRAL_GENOME_IMPLEMENTATION_SUMMARY.md` (guide détaillé)
   - `VIRAL_GENOME_ASSEMBLY_PLAN.md` (plan technique)
   - `OUTPUT_FILES.md` (référence des fichiers)

2. **Vérifier les sorties intermédiaires :**
   - Chaque phase crée des résumés et statistiques
   - Consulter les fichiers `*_summary.txt`

3. **GitHub Issues :**
   - https://github.com/ltalignani/PIMGAVIR-v2/issues

---

## Citations

Si vous utilisez ce module d'analyse de génomes viraux, veuillez citer :

**PIMGAVir :**
- [Citation à ajouter]

**Outils principaux :**
- **VirSorter2 :** Guo et al. (2021) *Microbiome* 9:37
- **CheckV :** Nayfach et al. (2021) *Nature Biotechnology* 39:578-585
- **DRAM :** Shaffer et al. (2020) *Nucleic Acids Research* 48:8883-8900
- **IQ-TREE :** Nguyen et al. (2015) *Molecular Biology and Evolution* 32:268-274
- **MAFFT :** Katoh & Standley (2013) *Molecular Biology and Evolution* 30:772-780

---

**Dernière mise à jour :** 29 octobre 2025
**Version :** PIMGAVir v2.2
**Auteurs :** Loïc Talignani

