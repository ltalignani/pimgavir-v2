# Structure des Répertoires PIMGAVir

## Organisation Requise

Le dossier `input/` et `logs/` doivent être **à la racine du projet**, au même niveau que le dossier `scripts/`.

### Structure Correcte

```
/projects/large/PIMGAVIR/pimgavir_dev/
│
├── input/                          ← Placez vos échantillons ICI
│   ├── sample1_R1.fastq.gz
│   ├── sample1_R2.fastq.gz
│   ├── sample2_R1.fastq.gz
│   ├── sample2_R2.fastq.gz
│   └── ...
│
├── logs/                           ← Logs SLURM (créé automatiquement)
│   ├── pimgavir_12345_0.out
│   ├── pimgavir_12345_0.err
│   ├── pimgavir_12345_1.out
│   └── pimgavir_12345_1.err
│
├── scripts/                        ← Scripts du pipeline
│   ├── PIMGAVIR_conda.sh
│   ├── PIMGAVIR_conda_ib.sh
│   ├── PIMGAVIR_worker.sh
│   ├── PIMGAVIR_worker_ib.sh
│   ├── detect_samples.sh
│   ├── pre-process_conda.sh
│   ├── taxonomy_conda.sh
│   └── ...
│
├── DBs/                            ← Bases de données
│   ├── SILVA/
│   ├── KrakenViral/
│   ├── Diamond-RefSeqProt/
│   └── ...
│
├── samples.list                    ← Généré automatiquement
├── run_worker_*.sh                 ← Scripts temporaires générés
├── README.md
└── ...
```

## Commandes d'Installation

### 1. Créer le Dossier Input (si nécessaire)

```bash
cd /projects/large/PIMGAVIR/pimgavir_dev/
mkdir -p input/
mkdir -p logs/
```

### 2. Copier vos Échantillons

```bash
# Depuis votre emplacement de données
cp /chemin/vers/vos/echantillons/*_R1.fastq.gz input/
cp /chemin/vers/vos/echantillons/*_R2.fastq.gz input/

# OU copier tout le contenu
cp /chemin/vers/vos/echantillons/*.fastq.gz input/
```

### 3. Vérifier la Structure

```bash
ls -lh input/
# Doit afficher vos fichiers FASTQ.gz pairés (R1/R2)
```

## Lancement du Pipeline

### Depuis le Répertoire du Projet

```bash
cd /projects/large/PIMGAVIR/pimgavir_dev/
sbatch scripts/PIMGAVIR_conda.sh 20 --read_based
```

### OU Depuis le Répertoire scripts/

```bash
cd /projects/large/PIMGAVIR/pimgavir_dev/scripts/
sbatch PIMGAVIR_conda.sh 20 --read_based
```

**Important**: Le script utilise `$SLURM_SUBMIT_DIR` pour déterminer le répertoire du projet, donc **vous devez soumettre le job depuis le répertoire du projet** (ou le sous-répertoire scripts/).

## Conventions de Nommage des Échantillons

Le script de détection supporte ces formats :

### Format 1 : Séparateur underscore
```
echantillon_R1.fastq.gz  ←→  echantillon_R2.fastq.gz
echantillon_1.fastq.gz   ←→  echantillon_2.fastq.gz
```

### Format 2 : Séparateur point
```
echantillon.R1.fastq.gz  ←→  echantillon.R2.fastq.gz
echantillon.1.fastq.gz   ←→  echantillon.2.fastq.gz
```

### Format 3 : Extension alternative
```
echantillon_R1.fq.gz     ←→  echantillon_R2.fq.gz
echantillon.R1.fq.gz     ←→  echantillon.R2.fq.gz
```

## Résultats

Les résultats sont sauvegardés dans :

```
/projects/large/PIMGAVIR/results/
└── JOBID_NomEchantillon_METHODE/
    ├── read-based-taxonomy/
    ├── assembly-based/
    │   ├── megahit_final_contigs.fa
    │   ├── spades_contigs.fasta
    │   └── ... (autres fichiers d'assemblage)
    ├── clustering-based/
    ├── report/
    │
    └── scripts/                           ← Scripts copiés depuis scratch
        └── assembly-based/
            ├── viral-genomes-megahit/    🆕 Analyse virale MEGAHIT (7 phases)
            └── viral-genomes-spades/     🆕 Analyse virale SPAdes (7 phases)
```

Où :
- `JOBID` = Numéro du job SLURM
- `NomEchantillon` = Nom extrait du fichier (sans _R1/_R2)
- `METHODE` = read_based, ass_based, clust_based, ou ALL

### 🆕 Structure Détaillée de l'Analyse Virale (7 Phases)

Quand vous utilisez `--ass_based` ou `ALL`, le pipeline exécute automatiquement une analyse virale complète en 7 phases :

```
viral-genomes-megahit/                    # Analyse pour assemblage MEGAHIT
│
├── phase1_recovery/                      # Phase 1 : Récupération des génomes viraux
│   ├── virsorter2/                       # Identification des virus (VirSorter2)
│   ├── checkv/                           # Évaluation de qualité (CheckV)
│   │   └── Sample_checkv_summary.tsv    # ⭐ Métriques de qualité
│   ├── vrhyme/                           # Binning des génomes (vRhyme)
│   ├── high_quality_viruses/             # Génomes haute qualité (≥90% complets)
│   │   └── Sample_hq_viruses.fasta      # ⭐ Génomes viraux HQ
│   └── results/
│       └── Sample_recovery_summary.txt   # Résumé de la récupération
│
├── phase2_annotation/                    # Phase 2 : Annotation fonctionnelle
│   ├── prodigal/
│   │   └── Sample_proteins.faa          # ⭐ Protéines prédites
│   ├── dramv/                            # Annotation DRAM-v
│   │   ├── annotations.tsv              # ⭐ Annotations complètes
│   │   └── distill/
│   │       └── amg_summary.tsv          # ⭐ Gènes métaboliques auxiliaires (AMG)
│   └── results/
│       └── Sample_annotation_summary.txt
│
├── phase3_phylogenetics/                 # Phase 3 : Analyse phylogénétique
│   ├── alignment/
│   │   └── Sample_trimmed.fasta         # Alignement nettoyé
│   ├── iqtree/
│   │   └── Sample_viral.treefile        # ⭐ Arbre phylogénétique ML
│   ├── mrbayes/                          # Inférence Bayésienne (optionnel)
│   │   └── Sample_viral.con.tre         # Arbre consensus Bayésien
│   └── results/
│       └── Sample_phylo_summary.txt
│
├── phase4_comparative/                   # Phase 4 : Génomique comparative
│   ├── proteins/
│   │   └── Sample_proteins.faa          # Toutes les protéines
│   ├── genomad/                          # Annotations geNomad
│   │   └── Sample_virus_summary.tsv     # ⭐ Taxonomie
│   ├── clusters/
│   │   └── Sample_protein_clusters.tsv  # Familles de protéines
│   ├── vcontact2/                        # Réseaux taxonomiques
│   │   ├── genome_by_genome_overview.csv # ⭐ Taxonomie vConTACT2
│   │   └── c1.ntw                        # Réseau (Cytoscape)
│   └── results/
│       └── Sample_comparative_summary.txt
│
├── phase5_host_ecology/                  # Phase 5 : Prédiction d'hôtes & écologie
│   ├── crispr/                           # Correspondances CRISPR
│   │   └── Sample_crispr_matches.txt    # ⭐ Preuves d'infection
│   ├── trna/                             # Analyse des tRNA
│   ├── kmer_analysis/                    # Similarité k-mer
│   ├── protein_homology/                 # Homologie des protéines
│   ├── ecology/
│   │   └── Sample_diversity.txt         # ⭐ Métriques de diversité
│   └── results/
│       └── Sample_host_predictions.tsv  # ⭐ Prédictions d'hôtes
│
├── phase6_zoonotic/                      # 🆕 Phase 6 : Évaluation du risque zoonotique
│   ├── furin_sites/
│   │   ├── Sample_furin_sites.txt       # ⚠️ Sites de clivage furine détectés
│   │   └── Sample_furin_proteins.faa    # Protéines avec sites furine
│   ├── rbd_analysis/
│   │   ├── Sample_spike_proteins.txt    # Protéines de surface
│   │   └── Sample_rbd_candidates.faa    # ⚠️ Candidats RBD
│   ├── zoonotic_similarity/              # Comparaison avec pathogènes connus
│   │   └── Sample_vs_zoonotic.blastp    # BLAST vs virus zoonotiques
│   ├── receptor_analysis/
│   │   └── Sample_rbd_patterns.txt      # Caractéristiques des RBD
│   └── results/
│       ├── Sample_zoonotic_risk_report.txt  # ⭐ Rapport de risque complet
│       └── Sample_zoonotic_summary.tsv      # Scores de risque par génome
│
├── phase7_publication_report/            # 🆕 Phase 7 : Matériel de publication
│   ├── figures/                          # Figures publication-ready
│   │   ├── Figure2_AMG_Heatmap.pdf      # 📊 Heatmap des AMG
│   │   ├── Figure3_Phylogenetic_Tree.pdf # 🌳 Arbre phylogénétique
│   │   ├── Figure4_Diversity.pdf         # 📈 Plots de diversité
│   │   └── *.png                         # Versions haute résolution
│   ├── tables/                           # Tableaux supplémentaires
│   │   ├── TableS1_Viral_Genomes.tsv    # 📋 Génomes HQ
│   │   ├── TableS2_AMG_Predictions.tsv  # 📋 Prédictions AMG
│   │   ├── TableS3_Host_Predictions.tsv # 📋 Prédictions d'hôtes
│   │   └── TableS4_Zoonotic_Risk.tsv    # 📋 Évaluation zoonotique
│   ├── methods/
│   │   └── methods_section.txt          # ⭐ Section méthodes (prête à l'emploi)
│   └── html_report/
│       └── interactive_report.html      # 🌐 Rapport HTML interactif
│
├── final_results/                        # Fichiers clés copiés ici
│   ├── Sample_hq_viruses.fasta
│   ├── amg_summary.tsv
│   ├── Sample_viral.treefile
│   ├── genome_by_genome_overview.csv
│   ├── Sample_host_predictions.tsv
│   ├── Sample_zoonotic_risk_report.txt  # 🆕
│   └── interactive_report.html          # 🆕
│
└── Sample_complete_analysis.log          # Log complet de toutes les phases

viral-genomes-spades/                     # Structure identique pour SPAdes
└── [même structure que ci-dessus]
```

### Légende des Symboles

- ⭐ = Fichiers clés pour l'analyse
- 🆕 = Nouvelles phases (6 & 7)
- ⚠️ = Résultats nécessitant une attention particulière (risque zoonotique)
- 📊 = Figures publication-ready
- 📋 = Tableaux supplémentaires
- 🌐 = Rapport interactif
- 🌳 = Arbres phylogénétiques

## Exemple Complet

```bash
# 1. Aller dans le répertoire du projet
cd /projects/large/PIMGAVIR/pimgavir_dev/

# 2. Créer input/ si nécessaire
mkdir -p input/

# 3. Copier les échantillons
cp /data/sequencing/batch01/*.fastq.gz input/

# 4. Vérifier les fichiers
ls -lh input/
# Output attendu :
# sample1_R1.fastq.gz
# sample1_R2.fastq.gz
# sample2_R1.fastq.gz
# sample2_R2.fastq.gz

# 5. Lancer le pipeline
cd scripts/
sbatch PIMGAVIR_conda.sh 20 --read_based

# 6. Vérifier la soumission
squeue -u $USER

# 7. Surveiller les logs
tail -f ../logs/pimgavir_*.out
```

## Dépannage

### Erreur : "Input directory does not exist"

**Solution** : Créez le dossier `input/` à la racine du projet

```bash
cd /projects/large/PIMGAVIR/pimgavir_dev/
mkdir -p input/
```

### Erreur : "No paired samples found"

**Causes possibles** :
1. Les fichiers ne sont pas dans `input/`
2. Les noms de fichiers ne respectent pas le format R1/R2
3. Les fichiers R1 et R2 n'ont pas le même nom de base

**Solution** :
```bash
# Vérifier le contenu
ls -lh input/

# Tester la détection manuellement
cd scripts/
./detect_samples.sh ../input test.list
cat test.list
```

### Le script ne trouve pas les fichiers

**Vérifiez depuis où vous soumettez** :

```bash
# Bon emplacement
cd /projects/large/PIMGAVIR/pimgavir_dev/
sbatch scripts/PIMGAVIR_conda.sh 20 ALL

# OU
cd /projects/large/PIMGAVIR/pimgavir_dev/scripts/
sbatch PIMGAVIR_conda.sh 20 ALL

# Mauvais emplacement (ne marchera pas)
cd /home/user/
sbatch /projects/large/PIMGAVIR/pimgavir_dev/scripts/PIMGAVIR_conda.sh 20 ALL
```

## Notes Importantes

1. **Ne pas déplacer** le dossier `input/` dans `scripts/`
2. **Soumettre le job** depuis le répertoire du projet ou scripts/
3. **Les logs** sont automatiquement créés dans `logs/` à la racine
4. **Les résultats** vont dans `/projects/large/PIMGAVIR/results/`
5. **Les fichiers temporaires** (`samples.list`, `run_worker_*.sh`) sont créés à la racine du projet

## Support

Si vous rencontrez des problèmes :

1. Vérifiez la structure des répertoires avec `tree -L 2` ou `ls -R`
2. Testez la détection manuelle : `./scripts/detect_samples.sh input test.list`
3. Consultez les logs : `cat logs/pimgavir_*.err`
4. Contactez le support ou ouvrez une issue GitHub
