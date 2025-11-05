# Session 2025-11-04 - Correctifs et Améliorations

## Résumé des Changements

Cette session a apporté des correctifs critiques au pipeline d'analyse virale (Phase 1-7) et introduit un système de configuration flexible des ressources SLURM.

---

## 🔧 Correctif 1 : Variable ASSEMBLER Manquante

### Problème
Le script `viral-genome-recovery.sh` attendait 5 arguments incluant le nom de l'assembleur (MEGAHIT, SPADES), mais ce paramètre n'était pas transmis par la chaîne d'appels :
```
PIMGAVIR_worker.sh → viral-genome-complete-7phases.sh → viral-genome-recovery.sh
```

**Erreur observée :**
```
ERROR: Missing required arguments
Usage: viral-genome-recovery.sh <contigs.fasta> <output_dir> <threads> <sample_name> <assembler>
```

### Solution
**Fichiers modifiés :**
1. `scripts/viral-genome-complete-7phases.sh` (lignes 82, 99, 152, 189-194)
   - Ajout du paramètre `ASSEMBLER` en position 8
   - Transmission à `viral-genome-recovery.sh`

2. `scripts/PIMGAVIR_worker.sh` (lignes 287, 303)
   - Passage de `"MEGAHIT"` pour assemblage MEGAHIT
   - Passage de `"SPADES"` pour assemblage SPAdes

3. `scripts/PIMGAVIR_worker_ib.sh` (lignes 290, 306)
   - Même correction pour version Infiniband

**Impact :** Phase 1-7 du workflow viral peut maintenant s'exécuter correctement.

---

## 🔧 Correctif 2 : Bases de Données VirSorter2/CheckV Manquantes

### Problème
VirSorter2 et CheckV n'indiquaient pas les chemins vers leurs bases de données.

**Erreur observée :**
```
[CRITICAL] --db-dir must be provided since "template-config.yaml" has not been initialized
```

### Solution
**Fichier modifié :** `scripts/viral-genome-recovery.sh`

**Changements :**
1. Détection automatique du répertoire des bases de données (lignes 69-96)
   - Utilise `PIMGAVIR_DBS_DIR` si défini (v2.2)
   - Sinon utilise chemin relatif `../DBs`
   - Valide l'existence des bases

2. Ajout du paramètre `--db-dir` à VirSorter2 (ligne 137)
   ```bash
   virsorter run --db-dir "$VIRSORTER_DB" ...
   ```

3. Ajout du paramètre `-d` à CheckV (ligne 178)
   ```bash
   checkv end_to_end -d "$CHECKV_DB" ...
   ```

**Impact :** VirSorter2 et CheckV trouvent maintenant automatiquement leurs bases de données.

---

## 🔧 Correctif 3 : Incompatibilité de Chemins de Fichiers

### Problème
`viral-genome-complete-7phases.sh` cherchait les génomes viraux à un emplacement différent de celui où `viral-genome-recovery.sh` les créait.

**Attendu :** `phase1_recovery/high_quality_viruses/sample_hq_viruses.fasta`
**Créé :** `phase1_recovery/04_final_genomes/sample_ASSEMBLER_viral_genomes_hq.fna`

### Solution
**Fichier modifié :** `scripts/viral-genome-recovery.sh` (lignes 107, 258-266)

**Changements :**
1. Création du répertoire `high_quality_viruses/` attendu
2. Double enregistrement des génomes :
   - Format avec assembleur : `${SAMPLE}_${ASSEMBLER}_viral_genomes_hq.fna`
   - Format pipeline : `${SAMPLE}_hq_viruses.fasta`

**Impact :** Les phases 2-7 peuvent maintenant accéder aux génomes de Phase 1.

---

## 🔧 Correctif 4 : Détection Incorrecte du Nombre d'Échantillons

### Problème
`run_pimgavir_batch.sh` comptait des lignes vides comme échantillons et affichait des noms vides.

**Erreur observée :**
```
Number of samples: 31
Samples to process:
  -
  -
  ...
```
(Alors qu'il n'y avait que 2 échantillons réels)

### Solution
**Fichier modifié :** `scripts/run_pimgavir_batch.sh`

**Changements :**
1. Suppression de la sortie standard de `detect_samples.sh` (ligne 212)
   ```bash
   bash detect_samples.sh "$INPUT_DIR" "$SAMPLES_FILE" > /dev/null 2>&1
   ```

2. Comptage robuste des lignes non-vides (ligne 223)
   ```bash
   N_SAMPLES=$(grep -c -v '^[[:space:]]*$' "$SAMPLES_FILE" 2>/dev/null || echo 0)
   ```

3. Affichage sécurisé des échantillons (lignes 278-285)
   - Ignore les lignes vides
   - Limite à 5 échantillons affichés

**Impact :** Le nombre d'échantillons détectés est maintenant correct.

---

## 🔧 Correctif 5 : Compatibilité macOS (grep -P)

### Problème
L'option `-P` (Perl regex) de `grep` n'est pas supportée sur macOS.

**Erreur observée :**
```
grep: invalid option -- P
```

### Solution
**Fichiers modifiés :**
- `scripts/run_pimgavir.sh` (ligne 317)
- `scripts/run_pimgavir_batch.sh` (ligne 352)

**Changement :**
```bash
# Avant
JOB_ID=$(eval $SBATCH_CMD | grep -oP '\d+')

# Après (compatible POSIX)
JOB_ID=$(eval $SBATCH_CMD | grep -oE '[0-9]+')
```

**Impact :** Scripts fonctionnent maintenant sur macOS et Linux.

---

## ✨ Nouvelle Fonctionnalité : Configuration Flexible des Ressources

### Motivation
Les utilisateurs devaient modifier manuellement les directives `#SBATCH` dans les scripts pour changer mémoire/CPU/temps.

### Solution : Scripts Lanceurs Intelligents

#### 1. `run_pimgavir.sh` - Échantillon Unique

**Usage :**
```bash
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
    --threads 64 \
    --mem 256GB \
    --time 5-00:00:00 \
    --partition highmem \
    --filter \
    --email user@ird.fr
```

**Options disponibles :**
- `--threads N` - Nombre de threads CPU
- `--mem N[G|M]` - Mémoire (ex: 128GB, 512GB, 1TB)
- `--time D-HH:MM:SS` - Limite de temps
- `--partition NAME` - Partition SLURM
- `--filter` - Activer filtrage host/contaminant
- `--infiniband` - Utiliser scratch Infiniband
- `--email EMAIL` - Email pour notifications
- `--mail-type TYPE` - Type de notifications

#### 2. `run_pimgavir_batch.sh` - Traitement en Lot

**Usage :**
```bash
bash scripts/run_pimgavir_batch.sh /data/fastq/ ALL \
    --mem 256GB \
    --threads 60 \
    --array-limit 3 \
    --filter
```

**Option supplémentaire :**
- `--array-limit N` - Nombre max de jobs concurrents

#### 3. `test_viral_databases.sh` - Vérification des Bases

**Usage :**
```bash
bash scripts/test_viral_databases.sh
```

Vérifie que VirSorter2, CheckV, DRAM, et RVDB sont correctement installés.

### Documentation

**Nouveau fichier :** `RESOURCE_CONFIGURATION_GUIDE.md`

Contenu :
- Recommandations de ressources par type d'analyse
- Tableaux selon taille des données
- Exemples pour tous les cas d'usage
- Guide de dépannage
- Meilleures pratiques

**Recommandations de Ressources :**

| Type | Threads | Mémoire | Temps |
|------|---------|---------|-------|
| Read-based | 16-24 | 32-64 GB | 6-12h |
| Assembly | 40-64 | 128-256 GB | 2-4 jours |
| Clustering | 24-48 | 64-128 GB | 1-2 jours |
| ALL methods | 60-90 | 256-512 GB | 3-5 jours |

---

## 📊 Avantages des Changements

### Avant (v2.1)
```bash
# Édition manuelle des #SBATCH dans scripts
sbatch PIMGAVIR_worker.sh R1.fq.gz R2.fq.gz sample1 40 ALL
```

**Problèmes :**
- ❌ Édition manuelle requise
- ❌ Difficile de tracer ressources utilisées
- ❌ Pas de customisation par échantillon
- ❌ Erreurs fréquentes

### Après (v2.2+)
```bash
# Tout en ligne de commande
bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
    --threads 64 --mem 256GB --time 5-00:00:00
```

**Bénéfices :**
- ✅ Aucune édition de script
- ✅ Ressources documentées
- ✅ Customisation facile
- ✅ Historique reproductible
- ✅ Rétrocompatible

---

## 🧪 Tests Effectués

### 1. Détection d'échantillons
```bash
bash scripts/detect_samples.sh input/
# ✅ Détecte correctement sample9
# ✅ Génère fichier TSV propre
```

### 2. Workflow viral (dry run)
```bash
DRY_RUN=true bash scripts/run_pimgavir.sh R1.fq.gz R2.fq.gz sample1 ALL \
    --mem 256GB --threads 64
# ✅ Génère commande sbatch correcte
# ✅ Affiche configuration
```

### 3. Batch processing (dry run)
```bash
bash scripts/run_pimgavir_batch.sh input/ --read_based --mem 32GB
# ✅ Compte échantillons correctement
# ✅ Affiche noms d'échantillons
# ✅ Génère wrapper script
```

---

## 📁 Fichiers Créés

### Scripts
1. `scripts/run_pimgavir.sh` - Lanceur échantillon unique
2. `scripts/run_pimgavir_batch.sh` - Lanceur batch
3. `scripts/test_viral_databases.sh` - Vérification bases de données

### Documentation
1. `RESOURCE_CONFIGURATION_GUIDE.md` - Guide complet des ressources
2. `updates/SESSION_2025_11_04_FIXES.md` - Ce document

---

## 📁 Fichiers Modifiés

### Scripts Pipeline
1. `scripts/viral-genome-recovery.sh`
   - Détection auto des bases de données
   - Paramètres `--db-dir` et `-d`
   - Double sortie des génomes HQ

2. `scripts/viral-genome-complete-7phases.sh`
   - Ajout paramètre ASSEMBLER
   - Transmission à Phase 1

3. `scripts/PIMGAVIR_worker.sh`
   - Transmission ASSEMBLER="MEGAHIT"/"SPADES"

4. `scripts/PIMGAVIR_worker_ib.sh`
   - Transmission ASSEMBLER="MEGAHIT"/"SPADES"

---

## 🚀 Migration pour Utilisateurs Actuels

**Aucune action requise !** Les anciens workflows continuent de fonctionner.

**Pour profiter des nouvelles fonctionnalités :**

```bash
# Ancienne méthode (toujours fonctionnelle)
sbatch --mem=256GB --cpus-per-task=64 PIMGAVIR_worker.sh R1.fq R2.fq sample 64 ALL

# Nouvelle méthode (recommandée)
bash scripts/run_pimgavir.sh R1.fq R2.fq sample ALL --mem 256GB --threads 64
```

---

## 🎯 Commandes Utiles

### Aide
```bash
bash scripts/run_pimgavir.sh --help
bash scripts/run_pimgavir_batch.sh --help
```

### Vérification bases de données
```bash
bash scripts/test_viral_databases.sh
```

### Test sans soumettre (dry run)
```bash
DRY_RUN=true bash scripts/run_pimgavir.sh R1.fq R2.fq sample1 ALL \
    --mem 256GB --threads 64
```

### Monitoring
```bash
# Statut job
squeue -j JOB_ID

# Utilisation ressources
sstat -j JOB_ID --format=JobID,MaxRSS,AveCPU

# Logs en temps réel
tail -f logs/pimgavir_sample1_JOB_ID.out
```

---

## 🐛 Problèmes Connus et Solutions

### 1. "No paired samples found"
**Cause :** Fichiers non nommés correctement
**Solution :**
```bash
# Renommer selon convention
mv sample_forward.fq.gz sample_R1.fastq.gz
mv sample_reverse.fq.gz sample_R2.fastq.gz
```

### 2. "VirSorter2 database not found"
**Cause :** Bases de données non installées
**Solution :**
```bash
cd scripts/
bash DRAM_FIX.sh  # iTrop cluster seulement
bash setup_viral_databases.sh
```

### 3. Job killed (OOM)
**Cause :** Mémoire insuffisante
**Solution :**
```bash
# Augmenter mémoire de 50-100%
bash scripts/run_pimgavir.sh R1.fq R2.fq sample1 ALL --mem 256GB
```

### 4. Job timeout
**Cause :** Temps insuffisant
**Solution :**
```bash
# Doubler limite de temps
bash scripts/run_pimgavir.sh R1.fq R2.fq sample1 ALL --time 7-00:00:00
```

---

## 📝 Notes pour Développeurs

### Ajouter une Nouvelle Option
1. Ajouter au parsing des arguments dans `run_pimgavir.sh`
2. Ajouter à la commande sbatch dans section "Build SLURM Command"
3. Documenter dans `--help` et `RESOURCE_CONFIGURATION_GUIDE.md`

### Tester les Changements
```bash
# Test local (sans SLURM)
DRY_RUN=true bash scripts/run_pimgavir.sh ...

# Test sur cluster
bash scripts/run_pimgavir.sh ... --time 1:00:00  # Court test
```

---

## 📚 Références

- Guide complet : `RESOURCE_CONFIGURATION_GUIDE.md`
- Documentation principale : `README.md` et `CLAUDE.md`
- Workflow viral : `VIRAL_GENOME_COMPLETE_7PHASES.md`
- Guide batch : `docs/BATCH_PROCESSING_GUIDE.md`

---

## ✅ Checklist de Vérification Post-Session

- [x] Variable ASSEMBLER transmise correctement
- [x] Bases de données VirSorter2/CheckV configurées
- [x] Chemins de fichiers cohérents entre scripts
- [x] Détection d'échantillons robuste
- [x] Compatibilité macOS (grep -E)
- [x] Scripts lanceurs créés et testés
- [x] Documentation complète
- [x] Tests dry-run réussis
- [x] Rétrocompatibilité préservée

---

**Session complétée le :** 2025-11-04
**Version PIMGAVir :** 2.2.1
**Correctifs critiques :** 5
**Nouvelles fonctionnalités :** 3 scripts lanceurs + 1 guide
