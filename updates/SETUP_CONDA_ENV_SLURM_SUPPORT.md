# Setup Conda Environment - SLURM Support Added

**Date**: 2025-11-04
**Version**: setup_conda_env_fast.sh v2.1
**Issue**: Incomplete conda environment on cluster
**Status**: ✅ FIXED

## Problem

L'environnement `pimgavir_viralgenomes` était créé de manière incomplète sur le cluster IRD, causant des erreurs "commande introuvable" pour les outils essentiels comme TrimGalore.

**Cause probable**:
- Installation interactive interrompue par déconnexion SSH
- Ressources insuffisantes (mémoire, temps) pendant la résolution de packages
- Problèmes réseau pendant le téléchargement de packages (~8-10 GB)

## Solution

Ajout du support SLURM au script `setup_conda_env_fast.sh` pour permettre l'installation via `sbatch` avec des ressources appropriées.

## Modifications

### 1. En-tête SLURM ajouté

```bash
#SBATCH --job-name=setup_pimgavir_env
#SBATCH --partition=short
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32GB
#SBATCH --time=02:00:00
#SBATCH --output=setup_pimgavir_env_%j.out
#SBATCH --error=setup_pimgavir_env_%j.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=your.email@ird.fr
```

### 2. Détection du mode d'exécution

```bash
# Detect if running in SLURM batch mode (non-interactive)
if [ -n "$SLURM_JOB_ID" ]; then
    BATCH_MODE=true
    echo "Running in SLURM batch mode (Job ID: $SLURM_JOB_ID)"
else
    BATCH_MODE=false
    echo "Running in interactive mode"
fi
```

### 3. Comportement adaptatif

**Mode Batch (SLURM):**
- ✅ Supprime et recrée automatiquement l'environnement existant (pas de prompt)
- ✅ Installe automatiquement BLAST taxonomy database
- ✅ Skip viral genome databases (trop long - à faire séparément)
- ✅ Aucune interaction utilisateur requise

**Mode Interactif:**
- ❓ Demande confirmation avant de supprimer l'environnement existant
- ❓ Demande si installer BLAST taxdb
- ❓ Demande si installer viral databases
- 💬 Permet l'interaction utilisateur

## Utilisation

### Création de l'environnement sur le cluster (Recommandé)

```bash
# Se connecter au cluster
ssh bioinfo-master.ird.fr

# Aller au répertoire du projet
cd /projects/large/PIMGAVIR/pimgavir_dev/

# Soumettre le job
sbatch scripts/setup_conda_env_fast.sh

# Monitorer la progression
tail -f setup_pimgavir_env_<JOBID>.out
```

### Vérification après installation

```bash
# Activer l'environnement
conda activate pimgavir_viralgenomes

# Vérifier les outils essentiels
which trim_galore    # Doit retourner un chemin conda
which bbduk.sh       # Doit retourner un chemin conda
which kraken2        # Doit retourner un chemin conda
which megahit        # Doit retourner un chemin conda

# Lister tous les packages installés
conda list | wc -l   # Devrait montrer ~200-300 packages
```

## Avantages du mode SLURM

| Aspect | Mode Interactif | Mode SLURM Batch |
|--------|----------------|------------------|
| **Temps d'installation** | 15-90 min | 15-90 min |
| **Résistant aux déconnexions SSH** | ❌ Non | ✅ Oui |
| **Ressources garanties** | ❌ Partagées | ✅ Dédiées (32GB RAM) |
| **Logs persistants** | ❌ Terminal uniquement | ✅ Fichiers .out/.err |
| **Peut tourner la nuit** | ❌ Non | ✅ Oui |
| **Interaction requise** | ✅ Oui | ❌ Non |

## Temps d'installation estimés

- **Avec mamba**: 15-30 minutes
- **Avec conda**: 45-90 minutes
- **Facteurs**: vitesse réseau, charge du cluster, cache conda

## Que faire si l'installation échoue?

### 1. Vérifier les logs d'erreur

```bash
cat setup_pimgavir_env_<JOBID>.err
```

Erreurs communes:
- `MemoryError`: Augmenter `--mem=64GB`
- `TimeoutError`: Augmenter `--time=03:00:00`
- `CondaHTTPError`: Problème réseau temporaire - relancer

### 2. Nettoyer le cache conda

```bash
conda clean --all
```

### 3. Vérifier l'espace disque

```bash
df -h $HOME
conda info
```

### 4. Relancer l'installation

```bash
sbatch scripts/setup_conda_env_fast.sh
```

Le script supprimera automatiquement l'environnement incomplet et recommencera.

## Bases de données virales (optionnel)

L'installation en mode batch **skip** les bases de données virales (trop long, 4-8 heures).

Pour installer les bases de données séparément:

```bash
# Option A: Mode interactif (sur un nœud interactif)
srun -p short --pty bash
conda activate pimgavir_viralgenomes
cd /projects/large/PIMGAVIR/pimgavir_dev/scripts/
bash DRAM_FIX.sh
bash setup_viral_databases.sh

# Option B: Mode batch (recommandé pour longues installations)
sbatch --partition=long --time=12:00:00 --mem=16GB \
       --wrap="source ~/miniconda3/etc/profile.d/conda.sh && \
               conda activate pimgavir_viralgenomes && \
               cd /projects/large/PIMGAVIR/pimgavir_dev/scripts && \
               bash DRAM_FIX.sh && \
               bash setup_viral_databases.sh"
```

## Fichiers modifiés

### `scripts/setup_conda_env_fast.sh`

**Version**: 2.0 → 2.1

**Changements**:
- Ajout en-tête SLURM (lignes 3-13)
- Détection mode batch vs interactif (lignes 40-47)
- Logique conditionnelle pour prompts (lignes 82-97, 214-243, 266-324)
- Documentation mise à jour

**Lignes ajoutées**: ~50 lignes
**Compatibilité**: Rétrocompatible - peut toujours être exécuté en mode interactif

## Documentation créée

### `docs/CONDA_ENVIRONMENT_SETUP_BATCH.md`

Guide complet couvrant:
- Comparaison mode interactif vs batch
- Instructions d'utilisation détaillées
- Configuration SLURM
- Troubleshooting
- Vérification post-installation
- Installation séparée des bases de données virales

## Prochaines étapes

1. **Mettre à jour l'email dans le script**:
   ```bash
   # Éditer scripts/setup_conda_env_fast.sh ligne 13
   #SBATCH --mail-user=votre.email@ird.fr
   ```

2. **Lancer l'installation sur le cluster**:
   ```bash
   cd /projects/large/PIMGAVIR/pimgavir_dev/
   sbatch scripts/setup_conda_env_fast.sh
   ```

3. **Vérifier l'environnement créé**:
   ```bash
   conda activate pimgavir_viralgenomes
   which trim_galore bbduk.sh kraken2 megahit virsorter
   ```

4. **Tester le pipeline**:
   ```bash
   sbatch scripts/PIMGAVIR_conda.sh \
          input/sample_R1.fastq.gz \
          input/sample_R2.fastq.gz \
          TestSample 40 --read_based
   ```

## Relation avec les autres fixes

Ce fix fait partie d'une série de corrections:

1. **BUGFIX_REPORT_DIRECTORY.md**: Ajout `mkdir -p report` dans les scripts
2. **DATABASE_OPTIMIZATION.md**: Accès direct aux DBs sur NAS (pas de copie)
3. **CONDA_ENVIRONMENT_INHERITANCE_FIX.md**: Utilisation de `source` au lieu de `bash`
4. **SETUP_CONDA_ENV_SLURM_SUPPORT.md**: Ce fix - installation SLURM batch

Tous ces fixes ensemble assurent une installation et exécution robuste du pipeline sur le cluster.

## Références

- Script modifié: `scripts/setup_conda_env_fast.sh`
- Documentation: `docs/CONDA_ENVIRONMENT_SETUP_BATCH.md`
- Fichier YAML: `scripts/pimgavir_viralgenomes.yaml`
- Guide migration: `scripts/CONDA_MIGRATION_GUIDE.md`
