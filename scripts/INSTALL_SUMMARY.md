# PIMGAVir Installation - Résumé

## Problème résolu
Le package `parallel=20230422` n'était pas disponible dans les canaux conda. La version a été corrigée à `parallel=20230522`.

## Installation réussie
L'environnement minimal `pimgavir_minimal` a été créé avec succès et testé. Tous les outils principaux sont fonctionnels:

### ✅ Outils testés et fonctionnels
- ✓ kraken2 (version 2.1.6)
- ✓ kaiju (version 1.10.1)
- ✓ megahit
- ✓ diamond
- ✓ bbduk.sh
- ✓ blastn
- ✓ krona (avec base de données taxonomique configurée)

## Instructions pour le cluster

### 1. Installation rapide (recommandée)
```bash
cd scripts/
./setup_conda_env_fast.sh
```

### 2. Activation pour utilisation
```bash
conda activate pimgavir_minimal
# ou si l'environnement complet est installé:
# conda activate pimgavir_complete
```

### 3. Utilisation sur cluster SLURM
Le script `PIMGAVIR.sh` a déjà été adapté pour détecter et utiliser l'environnement conda automatiquement. Il cherche en priorité:
1. `pimgavir_complete`
2. `pimgavir_env`
3. `pimgavir`

### 4. Pour l'installation sur cluster
Copiez ces fichiers sur le cluster:
- `scripts/pimgavir_minimal.yaml` (ou `pimgavir_complete.yaml`)
- `scripts/setup_conda_env_fast.sh`

Puis exécutez:
```bash
./setup_conda_env_fast.sh
```

## Avantages de cette solution
1. **Installation rapide**: mamba utilisé automatiquement si disponible
2. **Krona configuré**: Base de données taxonomique installée automatiquement
3. **Compatibilité**: Le script principal `PIMGAVIR.sh` detecte l'environnement conda automatiquement
4. **Fallback**: Si l'environnement complet échoue, installation automatique de l'environnement minimal

## Environnements disponibles
- **pimgavir_minimal**: Environnement testé et fonctionnel avec outils essentiels
- **pimgavir_complete**: Environnement avec tous les outils (en cours de création)

## Points d'attention pour le cluster
1. Assurez-vous que conda/mamba est disponible sur les nœuds de calcul
2. Copiez l'environnement conda vers le scratch si nécessaire
3. Le script principal copie déjà les données vers `/scratch/${USER}_${SLURM_JOB_ID}`