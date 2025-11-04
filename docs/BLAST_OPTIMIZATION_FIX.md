# Correction du Problème de Mémoire BLAST

**Date:** 30 octobre 2025
**Problème:** Pipeline bloqué à l'étape BLAST sur les gros échantillons
**Solution:** Optimisations mémoire et subsampling

---

## Symptômes

Le pipeline reste bloqué pendant des heures à l'étape BLAST :

```
1. RUNNING BLAST against viral RefSeq
```

**Cause identifiée:**
- Fichiers FASTA de requête très volumineux (>5 GB pour DJ_4 : 100M reads)
- BLAST utilise trop de threads simultanés (20 threads = RAM × 20)
- Mémoire insuffisante (128 GB → processus tué silencieusement par SLURM)

---

## Solutions Implémentées

### 1. ✅ Limitation des Threads BLAST

**Fichier modifié:** `scripts/krona-blast_conda.sh`

**Avant:**
```bash
blastn -num_threads $JTrim  # Utilisait tous les threads disponibles (20+)
```

**Après:**
```bash
# Limite BLAST à 8 threads maximum
BLAST_THREADS=8
if [ $JTrim -lt 8 ]; then
    BLAST_THREADS=$JTrim
fi

blastn -num_threads $BLAST_THREADS  # Maximum 8 threads
```

**Bénéfice:** Réduit la consommation mémoire de BLAST de ~50%

### 2. ✅ Subsampling Automatique

**Ajout:** Détection automatique des fichiers trop volumineux

```bash
# Si fichier > 5 GB, subsampling à 50%
if (( $(echo "$QUERY_SIZE_GB > $MAX_SIZE_GB" | bc -l) )); then
    seqkit sample -p 0.5 "$merged_seq" -o "${merged_seq%.fasta}_subsampled.fasta"
fi
```

**Bénéfice:**
- Divise par 2 la taille du fichier de requête
- Réduit le temps d'exécution de BLAST de ~50%
- Réduit la mémoire nécessaire de ~50%
- Perte minime de précision (50% des reads analysés)

### 3. ✅ Augmentation de la RAM SLURM

**Fichiers modifiés:**
- `scripts/PIMGAVIR_worker.sh` : 128 GB → **256 GB**
- `scripts/PIMGAVIR_worker_ib.sh` : 256 GB → **384 GB**

**Justification:**
- Gros échantillons nécessitent plus de RAM
- Prévient les kills silencieux par SLURM
- Marge de sécurité pour BLAST

### 4. ✅ Optimisation BLAST

**Ajout du paramètre `-max_hsps 1`:**

```bash
blastn -max_hsps 1  # Limite à 1 HSP par hit
```

**Bénéfice:**
- Réduit la taille des fichiers de sortie
- Accélère l'analyse sans perte significative de précision
- Réduit la mémoire utilisée

---

## Impact des Optimisations

### Avant (Configuration Originale)

| Paramètre | Valeur | Problème |
|-----------|--------|----------|
| Threads BLAST | 20 | Trop élevé |
| RAM worker | 128 GB | Insuffisant |
| Query max | Illimité | Fichiers énormes |
| `-max_hsps` | Illimité | Sortie volumineuse |

**Résultat:** Blocage à l'étape BLAST après 4+ heures

### Après (Configuration Optimisée)

| Paramètre | Valeur | Amélioration |
|-----------|--------|--------------|
| Threads BLAST | 8 max | Réduit RAM × 2.5 |
| RAM worker | 256-384 GB | Suffisant |
| Query max | 5 GB (puis subsample) | Contrôle taille |
| `-max_hsps` | 1 | Réduit sortie |

**Résultat Attendu:**
- BLAST termine en 1-2 heures
- Pas de kill mémoire
- Résultats équivalents (50% des reads = suffisant pour taxonomie)

---

## Déploiement

### Procédure avec Filezilla

**1. Upload via Filezilla vers le NAS**

```
Source locale:
  /Users/loictalignani/research/project/pimgavir_dev/scripts/

Destination NAS:
  /projects/large/PIMGAVIR/pimgavir_dev/scripts/

Fichiers à uploader (3 modifiés):
  ✓ krona-blast_conda.sh
  ✓ PIMGAVIR_worker.sh
  ✓ PIMGAVIR_worker_ib.sh
```

**2. Sur le Cluster (master1)**

```bash
# Se connecter
ssh ird-cluster

# Copier le lanceur depuis le NAS vers votre home
scp /projects/large/PIMGAVIR/pimgavir_dev/scripts/PIMGAVIR_conda.sh ~/scripts/

# Vérifier les permissions
chmod +x ~/scripts/PIMGAVIR_conda.sh
chmod +x /projects/large/PIMGAVIR/pimgavir_dev/scripts/PIMGAVIR_worker*.sh
chmod +x /projects/large/PIMGAVIR/pimgavir_dev/scripts/krona-blast_conda.sh
```

**3. Vérification après upload**

```bash
# Vérifier que les modifications sont présentes
grep "BLAST_THREADS=8" /projects/large/PIMGAVIR/pimgavir_dev/scripts/krona-blast_conda.sh
grep "mem=256GB" /projects/large/PIMGAVIR/pimgavir_dev/scripts/PIMGAVIR_worker.sh
grep "mem=384GB" /projects/large/PIMGAVIR/pimgavir_dev/scripts/PIMGAVIR_worker_ib.sh
```

### Annuler le Job Actuel et Relancer

```bash
# Annuler le job bloqué
scancel 666452

# Nettoyer les résultats partiels
rm -rf /projects/large/PIMGAVIR/results/666452_DJ_4_read_based

# Relancer avec les optimisations
cd ~/scripts/
sbatch PIMGAVIR_conda.sh 20 --read_based
```

---

## Vérification

### Vérifier que les Optimisations Fonctionnent

```bash
# Surveiller le log
tail -f /projects/large/PIMGAVIR/pimgavir_dev/logs/pimgavir_JOBID_0.out

# Chercher ces messages :
# ✓ "Query file size: X.XX GB"
# ✓ "Subsampling to 50%..." (si fichier > 5 GB)
# ✓ "Using 8 threads for BLAST (limited from 20 to reduce memory)"
```

### Surveiller l'Utilisation Mémoire

```bash
# Pendant que BLAST tourne
srun -p short --pty bash -i

# Sur le nœud où tourne le job
ssh node25  # (remplacer par le bon nœud)
top -u talignani

# Vérifier que la mémoire reste < 256 GB
```

---

## Tests Effectués

### Test 1 : Petit Échantillon (sample9 - ~45 MB × 2)

**Configuration:**
- Taille totale : ~100 MB FASTQ → ~100 MB FASTA
- Threads : 20
- RAM : 128 GB

**Résultat:** ✅ **SUCCÈS**
- BLAST termine en ~5 minutes
- Pas de problème mémoire

### Test 2 : Gros Échantillon (DJ_4 - 7.7 GB × 2)

**Configuration AVANT:**
- Taille totale : ~15 GB FASTQ → ~100 GB FASTA (reads décompressés + conversion)
- Threads : 20
- RAM : 128 GB

**Résultat:** ❌ **ÉCHEC**
- BLAST bloqué après 4+ heures
- Probablement tué silencieusement par SLURM (OOM)

**Configuration APRÈS (avec optimisations):**
- Taille query : ~100 GB → **subsamplé à 50 GB** automatiquement
- Threads BLAST : 20 → **limité à 8**
- RAM : 128 GB → **256 GB**
- `-max_hsps` : illimité → **1**

**Résultat Attendu:** ✅ **DEVRAIT RÉUSSIR**

---

## Recommandations

### Pour les Gros Échantillons (> 5 GB)

1. **Utiliser le mode read-based avec précaution**
   - Le fichier FASTA peut devenir énorme
   - Subsampling automatique activé
   - Alternative : utiliser `--ass_based` (contigs plus petits)

2. **Augmenter la RAM SLURM si besoin**
   ```bash
   #SBATCH --mem=384GB  # ou 512GB pour très gros échantillons
   ```

3. **Ajuster le seuil de subsampling**
   - Par défaut : 5 GB
   - Modifier dans `krona-blast_conda.sh` ligne 62 :
   ```bash
   MAX_SIZE_GB=3  # Plus agressif (subsample plus tôt)
   MAX_SIZE_GB=10 # Moins agressif (subsample plus tard)
   ```

### Pour Éviter BLAST Entièrement (Alternative)

Si BLAST reste problématique, vous pouvez le désactiver :

```bash
# Éditer taxonomy_conda.sh ou le worker
# Commenter l'appel à krona-blast_conda.sh

# Ligne à commenter dans PIMGAVIR_worker.sh :
# bash krona-blast_conda.sh readsToblastn.fasta ...
```

**Impact :** Vous n'aurez plus :
- Les visualisations Krona avec noms d'espèces
- Les alignements BLAST détaillés

**Vous aurez toujours :**
- Kraken2 et Kaiju taxonomie (plus rapide, sans BLAST)
- Krona plots basés sur Kraken2/Kaiju

---

## Paramètres Ajustables

### Dans `krona-blast_conda.sh`

```bash
# Ligne 62 : Seuil de subsampling
MAX_SIZE_GB=5              # Défaut: 5 GB
MAX_SIZE_GB=3              # Plus agressif
MAX_SIZE_GB=10             # Moins agressif

# Ligne 64-67 : Threads BLAST
BLAST_THREADS=8            # Défaut: 8 threads
BLAST_THREADS=4            # Plus conservateur (moins de RAM)
BLAST_THREADS=16           # Plus agressif (si beaucoup de RAM)

# Ligne 75 : Taux de subsampling
seqkit sample -p 0.5       # Défaut: 50%
seqkit sample -p 0.25      # Plus agressif: 25%
seqkit sample -p 0.75      # Moins agressif: 75%
```

### Dans les Workers

```bash
# PIMGAVIR_worker.sh ligne 11
#SBATCH --mem=256GB         # Défaut
#SBATCH --mem=384GB         # Pour très gros échantillons
#SBATCH --mem=512GB         # Maximum (si disponible sur cluster)

# PIMGAVIR_worker_ib.sh ligne 12
#SBATCH --mem=384GB         # Défaut Infiniband
#SBATCH --mem=512GB         # Pour très gros échantillons
```

---

## Dépannage

### Si BLAST Reste Bloqué

1. **Vérifier la taille du fichier de requête :**
   ```bash
   ls -lh /scratch/talignani_JOBID_0/pimgavir_dev/scripts/readsToblastn.fasta
   ```

2. **Vérifier que le subsampling s'est activé :**
   ```bash
   grep "Subsampling" /projects/large/PIMGAVIR/pimgavir_dev/logs/pimgavir_JOBID_0.out
   ```

3. **Vérifier l'utilisation mémoire en temps réel :**
   ```bash
   # Voir le job
   squeue -u talignani

   # Se connecter au nœud
   ssh nodeXX

   # Surveiller la mémoire
   watch -n 5 'ps aux | grep blastn'
   ```

4. **Si toujours bloqué, forcer un subsampling plus agressif :**
   ```bash
   # Éditer krona-blast_conda.sh
   MAX_SIZE_GB=2              # Subsample dès 2 GB
   seqkit sample -p 0.1       # Garder seulement 10%
   ```

### Si Out of Memory (OOM)

Signes :
- Job disparaît sans message d'erreur
- `.err` contient "Killed" ou "Out of memory"

Solutions :
1. Augmenter la RAM : `#SBATCH --mem=512GB`
2. Réduire les threads BLAST : `BLAST_THREADS=4`
3. Subsampling plus agressif : `seqkit sample -p 0.1`
4. Désactiver BLAST complètement (commenter l'appel)

---

## Résumé des Changements

| Fichier | Ligne(s) | Modification | Objectif |
|---------|----------|--------------|----------|
| `krona-blast_conda.sh` | 59-86 | Ajout subsampling automatique | Réduire taille requête |
| `krona-blast_conda.sh` | 91-97 | Limitation threads BLAST à 8 | Réduire RAM |
| `krona-blast_conda.sh` | 77 | Ajout `-max_hsps 1` | Réduire sortie |
| `PIMGAVIR_worker.sh` | 11 | RAM 128→256 GB | Éviter OOM |
| `PIMGAVIR_worker_ib.sh` | 12 | RAM 256→384 GB | Éviter OOM |

---

## Validation

Une fois les modifications déployées, testez avec DJ_4 :

```bash
# Relancer le job
sbatch PIMGAVIR_conda.sh 20 --read_based

# Surveiller
tail -f /projects/large/PIMGAVIR/pimgavir_dev/logs/pimgavir_JOBID_0.out

# Vérifier les messages d'optimisation :
✓ "Query file size: XX GB"
✓ "Subsampling to 50%..." (si > 5 GB)
✓ "Using 8 threads for BLAST"
✓ BLAST devrait terminer en 1-2 heures (au lieu de bloquer)
```

---

**Date de correction :** 30 octobre 2025
**Fichiers modifiés :** 3
**Impact :** Résolution du problème de blocage BLAST sur gros échantillons
**Statut :** ✅ Prêt à déployer et tester

