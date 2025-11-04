# README.md et CLAUDE.md - Documentation Bases de Données Complétée

**Date**: 2025-11-04
**Version**: PIMGAVir v2.2
**Status**: ✅ COMPLETE

## Problème Résolu

La documentation manquait d'informations cruciales sur :
1. **DRAM_FIX.sh** - spécifique au cluster iTrop/IRD
2. **Setup des bases de données virales** - différences entre mode batch et interactif
3. **Setup de BLAST taxdb** - quand c'est automatique vs manuel
4. **Tableau récapitulatif** - ce qui est installé automatiquement ou pas

## Modifications Apportées

### README.md

#### Section "Database Setup" (lignes 228-345)

**Restructuration complète** avec informations claires et hiérarchisées :

##### 1. BLAST Taxonomy Database (lignes 230-243)

**Ajouts** :
- ✅ Indication claire : "Installed automatically when using SLURM batch mode"
- ✅ Section "Manual installation (if needed)" pour clarté
- ✅ Taille du fichier (~500 MB)

**Avant** :
```markdown
**BLAST Taxonomy Database (Optional but Recommended)**
Enables organism names...
```

**Après** :
```markdown
#### BLAST Taxonomy Database

**What it does:** Enables organism names in BLAST results...
**Installed automatically:** ✅ Yes, when using SLURM batch mode
**Manual installation (if needed):**
```

##### 2. Viral Genome Databases (lignes 247-345)

**Section entièrement réécrite** avec :

**a) En-tête clair** (lignes 247-255) :
- Liste des databases avec tailles
- Total : ~170 GB, 4-8 heures

**b) IMPORTANT - iTrop Cluster Fix** (lignes 257-270) :
```markdown
**IMPORTANT - iTrop Cluster Specific Fix:**

The iTrop/IRD cluster requires a **DRAM HTTPS fix** due to SSL certificate issues.
This must be run **once** before database setup:

```bash
bash DRAM_FIX.sh  # Required on iTrop cluster - fixes DRAM SSL issues
```

This script:
- Patches DRAM to use HTTP instead of HTTPS...
- Only needed on iTrop/IRD cluster (not needed on other clusters)
- Run once per environment installation
- Safe to run multiple times (idempotent)
```

**c) Option A: SLURM Batch Mode** (lignes 274-297) :
- Commande complète avec `--wrap`
- Logs de sortie spécifiés (`--output`, `--error`)
- Commande pour monitorer (`tail -f`)
- Liste des avantages avec checkmarks

**d) Option B: Interactive Mode** (lignes 301-327) :
- Instructions avec `screen`/`tmux`
- Commandes de détachement/réattachement
- Avertissement sur la durée (4-8 heures)

**e) Tableau récapitulatif** (lignes 331-345) :

```markdown
##### What Gets Installed Automatically?

| Database | Size | Installed by setup_conda_env_fast.sh (batch) | Installed by setup_conda_env_fast.sh (interactive) | Needs manual setup |
|----------|------|----------------------------------------------|---------------------------------------------------|-------------------|
| **Krona taxonomy** | ~200 MB | ✅ Auto | ✅ Auto | ❌ No |
| **BLAST taxdb** | ~500 MB | ✅ Auto | ❓ Prompts user | If skipped |
| **VirSorter2** | ~10 GB | ❌ Skipped | ❓ Prompts user | If skipped |
| **CheckV** | ~1.5 GB | ❌ Skipped | ❓ Prompts user | If skipped |
| **DRAM-v** | ~150 GB | ❌ Skipped | ❓ Prompts user | If skipped |
| **RVDB** | ~5 GB | ❌ Skipped | ❓ Prompts user | If skipped |

**Summary:**
- **Batch mode**: Installs BLAST taxdb automatically, skips viral databases (too long)
- **Interactive mode**: Prompts user for each database
- **Viral databases**: Best installed separately via Option A (SLURM batch) or Option B (interactive with screen/tmux)
```

---

### CLAUDE.md

#### Section "Key Databases" (lignes 192-295)

**Restructuration complète** similaire au README mais avec plus de détails techniques :

##### 1. Liste des databases (lignes 194-207)

**Ajouts** :
- ✅ Tailles précises pour chaque database
- ✅ Séparation "Core Pipeline" vs "Viral Genome Analysis"
- ✅ Total database size : ~170-280 GB

**Avant** :
```markdown
- `SILVA/`: rRNA reference databases
- `KrakenViral/`: Kraken2 viral taxonomy database
```

**Après** :
```markdown
**Core Pipeline Databases:**
- `SILVA/`: rRNA reference databases (SSU/LSU) - ~2 GB
- `KrakenViral/`: Kraken2 viral taxonomy database - ~20 GB

**Viral Genome Analysis Databases (Phase 1-7):**
- `VirSorter2/`: Viral identification databases - ~10 GB
- `CheckV/`: Viral genome quality database - ~1.5 GB
```

##### 2. BLAST Taxonomy Database Setup (lignes 211-225)

**Ajouts** :
- ✅ Section "Automatic installation" avec mode batch vs interactif
- ✅ Clarification : automatique en batch, prompt en interactif

##### 3. Viral Genome Databases Setup (lignes 229-295)

**Section complète** avec :

**a) IMPORTANT - iTrop/IRD Cluster Specific** (lignes 231-244) :
- Explication technique du DRAM_FIX
- Pourquoi c'est nécessaire (SSL certificate issues)
- Quand l'utiliser (iTrop cluster seulement)
- Idempotence

**b) Option 1: SLURM Batch Mode** (lignes 246-263) :
- Commande complète avec tous les paramètres SLURM
- Logs de monitoring

**c) Option 2: Interactive Mode** (lignes 265-278) :
- Instructions screen/tmux
- Étapes numérotées

**d) What gets installed** (lignes 280-284) :
- Liste avec tailles précises
- Indication "optional but recommended" pour DRAM

**e) Database Installation Matrix** (lignes 286-295) :
- Tableau identique au README
- Vue d'ensemble claire de ce qui est automatique vs manuel

---

## Cohérence Entre README et CLAUDE.md

Les deux fichiers sont maintenant **parfaitement cohérents** :

| Aspect | README.md | CLAUDE.md | Cohérence |
|--------|-----------|-----------|-----------|
| **DRAM_FIX mention** | ✅ Présent | ✅ Présent | ✅ Identique |
| **iTrop cluster specificity** | ✅ Expliqué | ✅ Expliqué | ✅ Identique |
| **Batch vs Interactive** | ✅ 2 options | ✅ 2 options | ✅ Identique |
| **Tableau récapitulatif** | ✅ Présent | ✅ Présent | ✅ Identique |
| **Tailles databases** | ✅ Précisées | ✅ Précisées | ✅ Identique |
| **SLURM commands** | ✅ Complètes | ✅ Complètes | ✅ Identique |

## Informations Clés Mises en Avant

### 1. DRAM_FIX.sh - Spécifique iTrop

**Pourquoi** : Le cluster iTrop/IRD a des problèmes de certificats SSL qui empêchent DRAM de télécharger certaines databases.

**Solution** : Le script `DRAM_FIX.sh` patche DRAM pour utiliser HTTP au lieu de HTTPS pour les téléchargements problématiques.

**Quand l'utiliser** :
- ✅ **iTrop/IRD cluster** : Obligatoire avant `setup_viral_databases.sh`
- ❌ **Autres clusters** : Pas nécessaire

**Propriétés** :
- Idempotent (peut être exécuté plusieurs fois sans problème)
- Doit être exécuté **avant** setup_viral_databases.sh
- Run once per environment installation

### 2. Setup Modes Comparaison

| Aspect | SLURM Batch | Interactive |
|--------|-------------|-------------|
| **Duration** | 4-8 hours | 4-8 hours |
| **SSH safe** | ✅ Yes | ❌ No (use screen/tmux) |
| **Automated** | ✅ Yes | ❌ Needs monitoring |
| **Logs** | ✅ Saved to files | ❌ Terminal only |
| **Best for** | Production | Testing |

### 3. Database Installation Matrix

Utilisateurs peuvent maintenant **rapidement voir** :
- Ce qui est installé automatiquement par `setup_conda_env_fast.sh`
- Ce qui nécessite une installation manuelle
- Différences entre mode batch et interactif

### 4. Tailles de Databases

Utilisateurs peuvent **planifier l'espace disque** :
- Core pipeline : ~117 GB
- Viral analysis : ~166.5 GB
- Total max : ~283.5 GB

## Guide Rapide pour Utilisateurs

### Scénario 1 : Installation Complète (Batch Mode)

```bash
# 1. Setup environment (15-90 min, automated)
sbatch scripts/setup_conda_env_fast.sh

# 2. Setup viral databases (4-8h, automated)
sbatch --partition=long --time=12:00:00 --mem=16GB \
       --wrap="source ~/miniconda3/etc/profile.d/conda.sh && \
               conda activate pimgavir_viralgenomes && \
               cd /projects/large/PIMGAVIR/pimgavir_dev/scripts && \
               bash DRAM_FIX.sh && \
               bash setup_viral_databases.sh"

# 3. Verify
conda activate pimgavir_viralgenomes
which virsorter checkv DRAM-setup.py
```

### Scénario 2 : Installation Interactive

```bash
# 1. Setup environment (15-90 min, with prompts)
cd scripts/
bash setup_conda_env_fast.sh
# Answer prompts as desired

# 2. Setup viral databases (if skipped above)
screen -S viral_db
conda activate pimgavir_viralgenomes
cd scripts/
bash DRAM_FIX.sh
bash setup_viral_databases.sh
# Ctrl+A, D to detach
```

### Scénario 3 : Seulement BLAST taxdb (rapide)

```bash
# Si skipped during environment setup
cd scripts/
bash setup_blast_taxdb.sh  # ~5 min, 500 MB
```

## Fichiers Modifiés

1. **README.md** (lignes 228-345) :
   - Section "Database Setup" complètement réécrite
   - 117 lignes au total
   - 3 sous-sections : BLAST taxdb, Viral DBs, Tableau récapitulatif

2. **CLAUDE.md** (lignes 192-295) :
   - Section "Key Databases" complètement réécrite
   - 103 lignes au total
   - 5 sous-sections : Liste DBs, BLAST setup, Viral DBs setup (2 options), Matrix

3. **updates/README_CLAUDE_DATABASE_DOCUMENTATION.md** (ce fichier) :
   - Documentation complète des changements

## Impact Utilisateur

### Avant ces modifications

❌ Confusion sur DRAM_FIX.sh (pourquoi ? quand ?)
❌ Incertitude sur ce qui est installé automatiquement
❌ Pas de différenciation batch vs interactif pour databases
❌ Tailles des databases non documentées

### Après ces modifications

✅ **DRAM_FIX.sh** clairement expliqué (iTrop specific)
✅ **Tableau récapitulatif** montre ce qui est auto vs manuel
✅ **Deux options** (batch/interactive) clairement documentées
✅ **Tailles précises** pour planifier l'espace disque
✅ **Commandes SLURM complètes** pour copy-paste
✅ **Cohérence parfaite** entre README et CLAUDE.md

## Documentation Associée

- `docs/CONDA_ENVIRONMENT_SETUP_BATCH.md` : Guide détaillé mode batch
- `updates/SETUP_CONDA_ENV_SLURM_SUPPORT.md` : Résumé support SLURM
- `scripts/DRAM_FIX.sh` : Script de fix iTrop
- `scripts/setup_blast_taxdb.sh` : Setup BLAST taxonomy
- `scripts/setup_viral_databases.sh` : Setup databases virales

## Prochaines Étapes pour Utilisateurs

1. **Lire le README.md section "Installation Options"** (lignes 164-213)
2. **Lancer environment setup** : `sbatch scripts/setup_conda_env_fast.sh`
3. **Lire le README.md section "Database Setup"** (lignes 228-345)
4. **Choisir option batch ou interactive** pour viral databases
5. **Vérifier installations** : `conda list | wc -l` (devrait montrer ~200-300 packages)

## Support

Si questions sur :
- **DRAM_FIX.sh** : Voir section "IMPORTANT - iTrop Cluster Specific Fix" dans README/CLAUDE
- **Databases automatiques** : Voir tableau récapitulatif ligne 333 (README) ou 288 (CLAUDE)
- **Mode batch** : Voir `docs/CONDA_ENVIRONMENT_SETUP_BATCH.md`
- **Problèmes d'installation** : Vérifier logs `.out/.err` des jobs SLURM
