# DRAM Troubleshooting Guide - Complete Solutions

**Version:** 2.2.0
**Date:** 2025-11-03
**Cluster:** IRD (Institut de Recherche pour le Développement)

---

## 📋 Table des Matières

1. [Vue d'Ensemble](#vue-densemble)
2. [Problème 1: FTP Bloqué](#problème-1-ftp-bloqué)
3. [Problème 2: VOG HMM Path Bug](#problème-2-vog-hmm-path-bug)
4. [Solution Rapide](#solution-rapide-)
5. [Solutions Alternatives](#solutions-alternatives)
6. [Vérification](#vérification)
7. [Troubleshooting](#troubleshooting-avancé)
8. [Support](#support-et-références)

---

## Vue d'Ensemble

### Problèmes Identifiés

DRAM (Distilled and Refined Annotation of Metabolism) rencontre deux problèmes majeurs sur le cluster IRD:

| Problème | Cause | Impact | Priorité |
|----------|-------|--------|----------|
| **FTP URLs bloquées** | Firewall cluster bloque FTP | Téléchargement bases de données impossible | 🔴 CRITIQUE |
| **VOG HMM path bug** | DRAM cherche fichiers au mauvais endroit | VOG database échec | 🟡 MAJEUR |

**Impact combiné:** Installation DRAM complètement bloquée

### Solutions Disponibles

| Solution | Temps | Difficulté | Taux de Succès |
|----------|-------|------------|----------------|
| **Script automatique** `DRAM_FIX.sh` | 5-10 min | ⭐ Facile | 95% |
| Installation manuelle | 30-45 min | ⭐⭐ Moyen | 90% |
| Alternatives (geNomad) | 0 min | ⭐ Très facile | 100% |

---

## Problème 1: FTP Bloqué

### Description

DRAM télécharge ses bases de données depuis des serveurs FTP, mais le firewall du cluster IRD bloque le protocole FTP. Les serveurs proposent aussi HTTPS, mais DRAM utilise FTP comme URL primaire.

### Erreur Typique

```
urllib.error.URLError: <urlopen error ftp error: TimeoutError(110, 'Connection timed out')>
```

### Bases de Données Affectées

- ✗ **KOfam** (`ftp://ftp.genome.jp/pub/db/kofam/`)
- ✗ **Pfam** (`ftp://ftp.ebi.ac.uk/pub/databases/Pfam/`)
- ✗ **UniProt/UniRef** (`ftp://ftp.uniprot.org/pub/databases/`)
- ✗ **MEROPS** (`ftp://ftp.ebi.ac.uk/pub/databases/merops/`)
- ✗ **VOG** (`ftp://fileshare.csb.univie.ac.at/vog/`)

### Solution

Modifier le code source de DRAM pour utiliser HTTPS comme URL primaire au lieu de FTP.

**Fichier à modifier:** `mag_annotator/database_processing.py`

**Changements requis:**

```python
# AVANT (FTP - bloqué)
url = 'ftp://ftp.genome.jp/pub/db/kofam/profiles.tar.gz'

# APRÈS (HTTPS - fonctionne)
url = 'https://www.genome.jp/ftp/db/kofam/profiles.tar.gz'
```

---

## Problème 2: VOG HMM Path Bug

### Description

Bug documenté dans DRAM: https://github.com/metagenome-atlas/atlas/issues/718

Après téléchargement et extraction de `vog.hmm.tar.gz`, les fichiers VOG HMM sont dans un sous-répertoire `hmm/`, mais DRAM cherche directement dans le répertoire parent.

### Erreur Typique

```
Error: File format problem in trying to open HMM file vog_latest_hmms.txt.
File exists, but appears to be empty?

subprocess.SubprocessError: The subcommand hmmpress -f vog_latest_hmms.txt experienced an error
```

### Structure Réelle des Fichiers

```
vog_download/
├── hmm/                    ← Fichiers VOG ICI
│   ├── VOG00001.hmm
│   ├── VOG00002.hmm
│   ├── VOG00003.hmm
│   └── ... (milliers)
└── vog.annotations.tsv
```

### Code Buggé

```python
# Ligne ~316 dans database_processing.py
merge_files(glob(path.join(hmm_dir, 'VOG*.hmm')), vog_hmms)
# Cherche: hmm_dir/VOG*.hmm
# Trouve: [] (vide - fichiers sont dans hmm/ !)
```

### Solution

Ajouter le sous-répertoire `hmm/` dans le path:

```python
# Ligne ~316 dans database_processing.py - CORRIGÉ
merge_files(glob(path.join(hmm_dir, 'hmm', 'VOG*.hmm')), vog_hmms)
# Cherche: hmm_dir/hmm/VOG*.hmm
# Trouve: [VOG00001.hmm, VOG00002.hmm, ...] ✓
```

---

## Solution Rapide ⭐

### Script Automatique Unifié

Un seul script corrige **les deux problèmes** automatiquement.

#### Utilisation

```bash
# Sur le cluster IRD
conda activate pimgavir_viralgenomes
cd /projects/large/PIMGAVIR/pimgavir_dev/scripts/

# Exécuter le script de correction
bash DRAM_FIX.sh
```

#### Ce Que Fait le Script

Le script `DRAM_FIX.sh` effectue automatiquement:

1. ✅ **Localisation automatique** de l'installation DRAM
2. ✅ **Création de sauvegardes** (avant toute modification)
3. ✅ **Correction FTP → HTTPS** (tous les URLs)
   - KOfam: `ftp://ftp.genome.jp` → `https://www.genome.jp`
   - Pfam: `ftp://ftp.ebi.ac.uk` → `https://ftp.ebi.ac.uk`
   - UniProt: `ftp://ftp.uniprot.org` → `https://ftp.uniprot.org`
   - MEROPS: `ftp://ftp.ebi.ac.uk` → `https://ftp.ebi.ac.uk`
   - VOG: `ftp://fileshare.csb.univie.ac.at` → `https://fileshare.csb.univie.ac.at`
4. ✅ **Correction VOG path bug** (`hmm_dir/VOG*.hmm` → `hmm_dir/hmm/VOG*.hmm`)
5. ✅ **Vérification** des patches appliqués
6. ✅ **Rapport détaillé** des modifications

#### Temps d'Exécution

- **Patch:** 2-3 minutes
- **Total:** 5-10 minutes (inclut vérifications et sauvegardes)

### Après le Patch : Installation DRAM

```bash
cd /projects/large/PIMGAVIR/pimgavir_dev/DBs/ViralGenomes/

# Nettoyer tentatives précédentes (si nécessaire)
rm -rf dram-db/*

# Lancer l'installation
DRAM-setup.py prepare_databases \
    --output_dir ./dram-db \
    --skip_uniref \
    --threads 8 \
    --verbose 2>&1 | tee dram_setup_$(date +%Y%m%d_%H%M%S).log
```

**💡 Conseil:** Utiliser `screen` ou `tmux` pour éviter déconnexion:

```bash
screen -S dram_install
# Commande ci-dessus
# Détacher: Ctrl+A puis D
# Rattacher: screen -r dram_install
```

### Temps d'Installation

Après patches appliqués:

| Étape | Temps Estimé | Taille |
|-------|--------------|--------|
| Téléchargement KOfam | ~1.5 h | ~2 GB |
| Téléchargement Pfam | ~10 min | ~500 MB |
| Traitement Pfam (hmmpress) | ~1 h | - |
| Téléchargement dbCAN | ~5 min | ~100 MB |
| Téléchargement VOG | ~1 min | ~200 MB |
| Traitement VOG | ~5-10 min | - |
| **TOTAL** | **~3-4 heures** | **~3 GB** |

---

## Solutions Alternatives

### Alternative 1: geNomad (RECOMMANDÉ si Urgence)

geNomad est **déjà installé** et fournit annotations virales comparables:

```bash
# Installation (déjà fait dans pimgavir_viralgenomes)
genomad download-database /path/to/genomad_db

# Annotation virale
genomad annotate \
    --cleanup \
    --splits 8 \
    viral_contigs.fasta \
    genomad_output \
    /path/to/genomad_db
```

**Avantages geNomad:**
- ✅ Déjà installé et fonctionnel
- ✅ Plus rapide que DRAM
- ✅ Spécialisé pour les virus
- ✅ Pas de problèmes de téléchargement
- ✅ Utilisé dans Phases 4 de l'analyse virale

**Limitations:**
- ❌ Moins complet que DRAM pour métabolisme
- ❌ Pas d'AMG (Auxiliary Metabolic Genes) distillation
- ❌ Moins de bases de données

**Quand utiliser geNomad:**
- Besoin urgent d'annotations virales
- DRAM échoue après tentatives de fix
- Focus sur génomes viraux (pas microbiens)

### Alternative 2: Fichiers Décompressés

Si le patch ne fonctionne pas, utiliser fichiers extraits:

```bash
cd /path/to/downloads/

# Extraire fichiers
tar -xzf profiles.tar.gz
gunzip -k ko_list.gz
gunzip -k Pfam-A.hmm.gz
tar -xzf vog.hmm.tar.gz

# Traiter HMM
for hmm in profiles/*.hmm; do hmmpress "$hmm"; done
hmmpress Pfam-A.hmm
cat vog/hmm/VOG*.hmm > vog_latest_hmms.txt
hmmpress vog_latest_hmms.txt

# Relancer DRAM avec fichiers EXTRAITS
DRAM-setup.py prepare_databases \
    --output_dir /path/to/dram-db \
    --kofam_hmm_loc $(pwd)/profiles \
    --kofam_ko_list_loc $(pwd)/ko_list \
    --pfam_loc $(pwd)/Pfam-A.hmm \
    --viral_loc $(pwd)/vog_latest_hmms.txt \
    --skip_uniref \
    --threads 8
```

---

## Vérification

### Vérifier que les Patches sont Appliqués

```bash
# Activer environnement
conda activate pimgavir_viralgenomes

# Localiser DRAM
DRAM_DIR=$(python -c "import mag_annotator; import os; print(os.path.dirname(mag_annotator.__file__))")

# Vérifier patch FTP → HTTPS
grep -c "https://" "$DRAM_DIR/database_processing.py"
# Devrait afficher un nombre élevé (>10)

grep -c "ftp://" "$DRAM_DIR/database_processing.py"
# Devrait afficher 0 ou très peu

# Vérifier patch VOG
grep "path.join(hmm_dir, 'hmm', 'VOG\*.hmm')" "$DRAM_DIR/database_processing.py"
# Devrait afficher la ligne corrigée
```

### Vérifier l'Installation DRAM

```bash
# Vérifier configuration
DRAM-setup.py print_config

# Devrait afficher (après installation complète):
# ✓ Kofam HMM: /path/to/dram-db/kofam/profiles
# ✓ Kofam KO list: /path/to/dram-db/kofam/ko_list
# ✓ Pfam HMM: /path/to/dram-db/pfam/Pfam-A.hmm
# ✓ dbCAN HMM: /path/to/dram-db/dbcan/...
# ✓ VOG HMM: /path/to/dram-db/viral/vog_latest_hmms.txt
```

### Tester DRAM

```bash
# Test rapide sur petit génome
cd /path/to/test/

# Créer un petit fichier FASTA de test
# (ou utiliser un vrai génome viral)

# Annoter
DRAM.py annotate \
    -i test_genome.fasta \
    -o dram_test_output \
    --threads 4

# Vérifier sortie
ls dram_test_output/annotations.tsv
```

---

## Troubleshooting Avancé

### Problème: Patch Ne S'Applique Pas

**Symptômes:**
- Script dit "already patched" mais DRAM échoue toujours
- FTP URLs restent présentes après patch

**Solutions:**

```bash
# 1. Vérifier version DRAM
conda list | grep dram
# Version attendue: dram 1.4.x ou 1.5.x

# 2. Réinstaller DRAM si nécessaire
conda remove dram
conda install -c bioconda dram

# 3. Réappliquer patches
bash DRAM_FIX.sh

# 4. Forcer le patch même si "already patched"
# Éditer manuellement database_processing.py
nano ~/miniconda3/envs/pimgavir_viralgenomes/lib/python3.9/site-packages/mag_annotator/database_processing.py
```

### Problème: VOG Toujours Vide

**Symptômes:**
```
vog_latest_hmms.txt exists but appears empty
```

**Diagnostic:**

```bash
cd /path/to/dram-db/

# Chercher fichiers VOG téléchargés
find . -name "VOG*.hmm" | head -5

# Si trouve dans tmp/vog_download_xxx/hmm/VOG*.hmm
# → Bug path pas corrigé

# Si ne trouve rien
# → Téléchargement VOG a échoué
```

**Solutions:**

```bash
# Solution 1: Téléchargement manuel VOG
cd /path/to/dram-db/viral/
wget https://fileshare.csb.univie.ac.at/vog/latest/vog.hmm.tar.gz
tar -xzf vog.hmm.tar.gz
cat hmm/VOG*.hmm > vog_latest_hmms.txt
hmmpress vog_latest_hmms.txt

# Solution 2: Vérifier que patch VOG est appliqué
grep "hmm_dir, 'hmm'" ~/miniconda3/envs/pimgavir_viralgenomes/lib/python3.9/site-packages/mag_annotator/database_processing.py
# Doit afficher la ligne avec 'hmm'
```

### Problème: Timeout Pendant Installation

**Symptômes:**
```
Connection timed out
ReadTimeoutError
```

**Solutions:**

```bash
# 1. Augmenter timeout
export TIMEOUT=300  # 5 minutes

# 2. Relancer installation (reprend où ça s'est arrêté)
DRAM-setup.py prepare_databases \
    --output_dir ./dram-db \
    --skip_uniref \
    --threads 8

# 3. Télécharger manuellement bases problématiques
# Voir Alternative 2 ci-dessus
```

### Problème: Permission Denied

**Symptômes:**
```
PermissionError: [Errno 13] Permission denied
```

**Solutions:**

```bash
# Vérifier permissions répertoire output
ls -ld /path/to/dram-db/
chmod 755 /path/to/dram-db/

# Vérifier permissions installation DRAM
ls -l ~/miniconda3/envs/pimgavir_viralgenomes/lib/python3.9/site-packages/mag_annotator/

# Si lecture seule, réinstaller DRAM
conda remove dram
conda install -c bioconda dram
```

---

## Arbre de Décision

```
Installation DRAM échoue
│
├─ FTP timeout ?
│  ├─ YES → Appliquer DRAM_FIX.sh (patch FTP→HTTPS)
│  │       ├─ Succès ? → Continuer installation ✓
│  │       └─ Échec ? → Fichiers décompressés (Alternative 2)
│  │
│  └─ NO → Continuer diagnostic
│
├─ VOG file empty ?
│  ├─ YES → Appliquer DRAM_FIX.sh (patch VOG path)
│  │       ├─ Succès ? → Continuer installation ✓
│  │       └─ Échec ? → Téléchargement manuel VOG
│  │
│  └─ NO → Continuer diagnostic
│
├─ Autres erreurs ?
│  ├─ Timeout → Augmenter timeout, relancer
│  ├─ Permission → Vérifier chmod, réinstaller
│  ├─ Corruption → Nettoyer dram-db/, recommencer
│  └─ Autre → Voir troubleshooting avancé
│
└─ Tout échoue ?
   └─ Utiliser geNomad (Alternative 1) ✓
```

---

## Support et Références

### Documentation

**Fichiers dans ce projet:**
- `DRAM_TROUBLESHOOTING.md`: Ce guide complet (français)
- `../scripts/DRAM_FIX.sh`: Script de correction unifié
- `../scripts/patch_dram_https.py`: Script Python alternatif (plus d'options)

### Issues GitHub

- **VOG path bug**: https://github.com/metagenome-atlas/atlas/issues/718
- **DRAM GitHub**: https://github.com/WrightonLabCSU/DRAM

### Contact Cluster IRD

- **Support technique**: ndomassi.tando@ird.fr
- **Documentation cluster**: https://bioinfo-dokuwiki.ird.fr/

### Commandes de Diagnostic Utiles

```bash
# Informations système
uname -a
df -h /projects/large/PIMGAVIR/

# Informations conda
conda --version
conda env list
conda list | grep dram

# Test connectivité
curl -I https://www.genome.jp/ftp/db/kofam/profiles.tar.gz
curl -I https://ftp.ebi.ac.uk/pub/databases/Pfam/current_release/Pfam-A.hmm.dat.gz

# Logs DRAM
tail -100 dram_setup_*.log
grep "ERROR" dram_setup_*.log
grep "Warning" dram_setup_*.log
```

---

## Résumé des Temps

| Tâche | Temps Estimé |
|-------|--------------|
| **Appliquer DRAM_FIX.sh** | 5-10 min |
| **Installation DRAM complète** | 3-4 heures |
| **Vérification/test** | 10-15 min |
| **Total (première fois)** | **~4 heures** |
| | |
| **Si problèmes + troubleshooting** | +30 min - 1h |
| **Alternative geNomad** | 0 min (déjà installé) |

---

## Version History

- **v2.2.0** (2025-11-03): Guide unifié complet, script DRAM_FIX.sh fusionné
- **v2.1.0** (2025-11-01): VOG path bug fix ajouté
- **v2.0.0** (2025-10-31): FTP to HTTPS patch initial
- **v1.0.0** (2025-10-30): Documentation initiale

---

**Bon courage avec DRAM ! 🚀**

**Si tout échoue, geNomad fonctionne très bien pour l'analyse virale ! ✨**
