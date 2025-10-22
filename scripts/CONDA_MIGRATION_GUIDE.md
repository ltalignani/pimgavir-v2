# PIMGAVir Conda Migration Guide

## Problèmes identifiés avec la configuration actuelle

1. **Mélange système modules/conda** : Le pipeline utilise actuellement un mélange de modules système (`module load`) et d'outils conda

2. **Configuration Krona déficiente** : Krona nécessite une configuration post-installation qui n'était pas automatisée

3. **Dépendances manquantes** : Plusieurs outils étaient absents des environnements conda existants

4. **Chemins codés en dur** : Les scripts utilisaient des chemins absolus vers les outils conda

## Nouvelle approche : Configuration conda complète

### 1. Nouvel environnement conda complet

**Fichier** : `pimgavir_complete.yaml`

- Inclut tous les outils nécessaires au pipeline
- Versions récentes et compatibles
- Configuration cohérente

### 2. Script de configuration automatique

**Fichier** : `setup_conda_env.sh`

- Crée l'environnement conda automatiquement
- Configure Krona avec la base de données taxonomique
- Teste tous les outils après installation
- Fournit des chemins et informations de diagnostic

### 3. Scripts adaptés pour conda

**Nouveaux fichiers créés** :

- `pre-process_conda.sh` : Version sans module loading
- `taxonomy_conda.sh` : Utilise les outils conda directement
- `krona-blast_conda.sh` : Configuration Krona corrigée

## Instructions d'installation

### Étape 1 : Configuration de l'environnement

```bash
cd scripts/
./setup_conda_env.sh
```

### Étape 2 : Activation de l'environnement

```bash
conda activate pimgavir_complete
```

### Étape 3 : Vérification de Krona

```bash
# Test de la configuration Krona
ktImportTaxonomy -h
ktUpdateTaxonomy.sh --only-build  # Si pas fait automatiquement
```

## Avantages de cette approche

1. **Reproductibilité** : Tous les outils sont versionnés dans conda

2. **Portabilité** : Fonctionne sur différents clusters sans dépendance aux modules système

3. **Maintenance** : Plus facile de mettre à jour les versions

4. **Krona configuré** : Base de données taxonomique installée automatiquement

5. **Pas de conflits** : Évite les conflits entre versions système et conda

## Migration des scripts existants

### Option 1 : Remplacement progressif

1. Utilisez les nouveaux scripts `*_conda.sh`
2. Testez avec un échantillon
3. Remplacez progressivement les anciens scripts

### Option 2 : Modification des scripts existants

1. Supprimez les commandes `module load/unload`
2. Remplacez les chemins codés en dur par les noms d'outils
3. Assurez-vous que l'environnement conda est activé

## Outils inclus dans l'environnement complet

- **Préprocessing** : fastqc, cutadapt, trim-galore, bbmap
- **Taxonomie** : kraken2, kaiju, krona (avec configuration automatique)
- **Assembly** : megahit, spades, quast, bowtie2, samtools, pilon
- **Analyse** : blast, diamond, prokka, vsearch, seqkit, seqtk
- **Utilitaires** : taxonkit, parallel, rsync, wget, pigz
- **Bio-Python** : biopython, numpy, pandas

## Dépannage

### Problème Krona

Si Krona ne fonctionne pas :

```bash
conda activate pimgavir_complete
ktUpdateTaxonomy.sh
```

### Vérification des outils

```bash
conda activate pimgavir_complete
which kraken2 kaiju ktImportTaxonomy megahit blastn
```

### Problèmes de permissions

```bash
chmod +x scripts/setup_conda_env.sh
chmod +x scripts/*_conda.sh
```

## Exemple d'utilisation

```bash
# Configuration initiale (une seule fois)
./scripts/setup_conda_env.sh

# Pour chaque utilisation
conda activate pimgavir_complete
sbatch PIMGAVIR.sh R1.fastq.gz R2.fastq.gz sample 40 ALL
```