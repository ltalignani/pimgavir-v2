# Guide des versions de scripts PIMGAVir

## Problèmes identifiés dans la version originale

Le script `pimgavir_dev.sh` (maintenant `PIMGAVIR.sh`) présentait plusieurs problèmes dans sa configuration initiale :

### 1. Mélange incohérent modules système/conda

**Avant** (problématique) :
```bash
module purge
#module load FastQC/0.11.9  # Commentés mais...
#module load cutadapt/3.1
module load seqkit/2.1.0     # ...certains encore actifs
module load python/3.8.12

# Puis activation conda
conda activate pimgavir      # Conflits potentiels
```

### 2. Logique d'environnement confuse

**Avant** :
```bash
if ls ~/miniconda3/etc/profile.d/conda.sh 2> /dev/null
then
    conda activate pimgavir          # Un nom
else
    # Installation automatique miniconda (!!)
    conda activate pimgavir_env      # Autre nom
fi
```

**Problèmes** :
- Installation automatique de miniconda (inapproprié pour HPC)
- Noms d'environnements incohérents
- Pas de gestion d'erreur si l'environnement n'existe pas

### 3. Chemins codés en dur

Dans les scripts appelés, des chemins comme :
```bash
ktImportTaxonomy=${HOME}"/miniconda3/envs/pimgavir/bin/ktImportTaxonomy"
```

## Solutions développées

### Option 1 : PIMGAVIR.sh (version améliorée hybride)

**Amélioration de la logique conda** :
```bash
# Try to find conda installation
if [ -f "${HOME}/miniconda3/etc/profile.d/conda.sh" ]; then
    source "${HOME}/miniconda3/etc/profile.d/conda.sh"
elif [ -f "${HOME}/anaconda3/etc/profile.d/conda.sh" ]; then
    source "${HOME}/anaconda3/etc/profile.d/conda.sh"
elif [ -f "/opt/miniconda3/etc/profile.d/conda.sh" ]; then
    source "/opt/miniconda3/etc/profile.d/conda.sh"
else
    echo "Warning: Conda not found. Using system modules only."
fi

# Try environments in order of preference
if conda env list | grep -q "pimgavir_complete"; then
    conda activate pimgavir_complete    # Recommandé
elif conda env list | grep -q "pimgavir_env"; then
    conda activate pimgavir_env         # Legacy
elif conda env list | grep -q "pimgavir"; then
    conda activate pimgavir             # Legacy
else
    echo "Warning: No conda environment found. Using system tools."
fi
```

**Avantages** :
- Compatibilité ascendante avec les anciens environnements
- Fallback gracieux vers les modules système si conda indisponible
- Gestion d'erreurs améliorée

### Option 2 : PIMGAVIR_conda.sh (version pure conda)

**Configuration entièrement conda** :
```bash
# Purge all system modules to avoid conflicts
module purge

# Activate conda environment - all tools are included
if [ -f "${HOME}/miniconda3/etc/profile.d/conda.sh" ]; then
    source "${HOME}/miniconda3/etc/profile.d/conda.sh"
# ... autres chemins ...
else
    echo "Error: Cannot find conda installation"
    exit 1
fi

# Activate the complete PIMGAVir environment
conda activate pimgavir_complete

# Verify activation
if [ $? -ne 0 ]; then
    echo "Error: Failed to activate pimgavir_complete environment"
    exit 1
fi
```

**Avantages** :
- Aucun conflit entre modules système et conda
- Configuration plus propre et prévisible
- Meilleure reproductibilité

## Scripts conda adaptés créés

### Scripts principaux
1. `pre-process_conda.sh` - Preprocessing sans modules système
2. `taxonomy_conda.sh` - Classification taxonomique avec conda
3. `krona-blast_conda.sh` - Visualisation Krona avec conda

### Différences clés
- Suppression de toutes les commandes `module load/unload`
- Utilisation directe des outils conda (ex: `ktImportTaxonomy` au lieu de chemins absolus)
- Gestion d'erreurs améliorée

## Recommandations d'utilisation

### Pour nouveaux utilisateurs
1. **Installer l'environnement complet** :
   ```bash
   ./setup_conda_env.sh
   ```

2. **Utiliser la version pure conda** :
   ```bash
   sbatch PIMGAVIR_conda.sh R1.fastq.gz R2.fastq.gz sample 40 ALL
   ```

### Pour utilisateurs existants
1. **Migration progressive** :
   - Utiliser `PIMGAVIR.sh` (version améliorée hybride)
   - Installer `pimgavir_complete` quand possible
   - Migrer vers `PIMGAVIR_conda.sh` après tests

2. **Compatibilité** :
   - `PIMGAVIR.sh` détecte automatiquement l'environnement disponible
   - Fallback vers modules système si conda indisponible

## Résumé des améliorations

| Aspect | Version originale | PIMGAVIR.sh | PIMGAVIR_conda.sh |
|--------|-------------------|-------------|-------------------|
| **Modules système** | Mélange incohérent | Fallback intelligent | Aucun (purge) |
| **Environnement conda** | Logique confuse | Détection multiple | Environnement unique |
| **Gestion d'erreurs** | Basique | Améliorée | Robuste |
| **Reproductibilité** | Faible | Moyenne | Élevée |
| **Performance** | Variable | Bonne | Optimale |
| **Maintenance** | Difficile | Moyenne | Facile |

## Prochaines étapes recommandées

1. **Test** : Valider `PIMGAVIR_conda.sh` avec un échantillon
2. **Migration** : Progressivement remplacer les anciens scripts
3. **Documentation** : Mettre à jour la documentation utilisateur
4. **Formation** : Informer les utilisateurs des nouvelles pratiques