# Fix Critique: Conflit de Variables dans assembly_conda.sh

**Date**: 2025-11-04
**Version**: 2.2.1
**Gravité**: CRITIQUE - Pipeline s'arrête après annotation
**Symptôme**: Kraken2 rapporte "0 sequences processed", fichiers taxonomie manquants

---

## 🔴 Problème Identifié

### Symptôme
```
Loading database information... done.
0 sequences (0.00 Mbp) processed in 0.003s (0.0 Kseq/m, 0.00 Mbp/m).
  0 sequences classified (-nan%)
  0 sequences unclassified (-nan%)
cat: sample9_assembly-based-taxonomy/krakViral.out_MEGAHIT: Aucun fichier ou dossier de ce type
Error: Could not open file assembly-based/megahit_contigs_improved
```

### Cause Racine

**Conflit de variables dû au `source`**:

1. **Dans `PIMGAVIR_worker.sh` (ligne 217-218)**:
   ```bash
   megahit_contigs_improved="assembly-based/megahit_contigs_improved.fasta"
   spades_contigs_improved="assembly-based/spades_contigs_improved.fasta"
   ```

2. **Dans `assembly_conda.sh` (lignes 33-34 - AVANT correction)**:
   ```bash
   megahit_contigs_improved=$AssDir"/megahit_contigs_improved"  # ❌ SANS .fasta
   spades_contigs_improved=$AssDir"/spades_contigs_improved"    # ❌ SANS .fasta
   ```

3. **Quand le worker exécute**:
   ```bash
   source assembly_conda.sh ...  # Écrase les variables du worker!
   ```

4. **Puis appelle taxonomy**:
   ```bash
   source taxonomy_conda.sh $megahit_contigs_improved ...
   # Passe "assembly-based/megahit_contigs_improved" (SANS .fasta)
   # Mais le fichier créé par Pilon s'appelle "assembly-based/megahit_contigs_improved.fasta"
   ```

### Pourquoi Pilon crée `.fasta`?

Pilon ajoute **automatiquement** l'extension `.fasta` au nom de fichier de sortie:

```bash
pilon --genome input.fa --frags reads.bam --output mycontigs
# Crée: mycontigs.fasta (pas mycontigs)
```

Donc:
- Variable dit: `assembly-based/megahit_contigs_improved` (sans .fasta)
- Fichier réel: `assembly-based/megahit_contigs_improved.fasta` (avec .fasta)
- Kraken2 cherche le fichier sans .fasta → **FICHIER INTROUVABLE** → 0 séquences

---

## ✅ Solution Implémentée

### Changements dans `assembly_conda.sh`

**AVANT (lignes 31-36)**:
```bash
megahit_contigs_sorted_bam=$AssDir"/megahit_contigs.sorted.bam"
spades_contigs_sorted_bam=$AssDir"/spades_contigs.sorted.bam"
megahit_contigs_improved=$AssDir"/megahit_contigs_improved"     # ❌ Problème
spades_contigs_improved=$AssDir"/spades_contigs_improved"       # ❌ Problème
spades_prokka=$AssDir"/spades_prokka"
megahit_prokka=$AssDir"/megahit_prokka"
```

**APRÈS (lignes 31-40)**:
```bash
megahit_contigs_sorted_bam=$AssDir"/megahit_contigs.sorted.bam"
spades_contigs_sorted_bam=$AssDir"/spades_contigs.sorted.bam"
# Pilon adds .fasta automatically, so we use base name for pilon output
megahit_contigs_improved_base=$AssDir"/megahit_contigs_improved"
spades_contigs_improved_base=$AssDir"/spades_contigs_improved"
# Final files will have .fasta extension (added by Pilon)
megahit_contigs_improved=$AssDir"/megahit_contigs_improved.fasta"  # ✅ Correct!
spades_contigs_improved=$AssDir"/spades_contigs_improved.fasta"    # ✅ Correct!
spades_prokka=$AssDir"/spades_prokka"
megahit_prokka=$AssDir"/megahit_prokka"
```

**Modifications des appels Pilon (lignes 134-139)**:

**AVANT**:
```bash
pilon --genome $megahit_out/final.contigs.fa --frags $megahit_contigs_sorted_bam --output $megahit_contigs_improved --threads $JTrim
pilon --genome $spades_out/contigs.fasta --frags $spades_contigs_sorted_bam --output $spades_contigs_improved --threads $JTrim
```

**APRÈS**:
```bash
# Note: Pilon adds .fasta extension automatically to output
pilon --genome $megahit_out/final.contigs.fa --frags $megahit_contigs_sorted_bam --output $megahit_contigs_improved_base --threads $JTrim
pilon --genome $spades_out/contigs.fasta --frags $spades_contigs_sorted_bam --output $spades_contigs_improved_base --threads $JTrim
```

**Modifications QUAST (lignes 143-144)**:

**AVANT**:
```bash
quast.py -o $megahit_quast $megahit_contigs_improved".fasta" || exit 84
quast.py -o $spades_quast $spades_contigs_improved".fasta" || exit 85
```

**APRÈS**:
```bash
quast.py -o $megahit_quast $megahit_contigs_improved || exit 84
quast.py -o $spades_quast $spades_contigs_improved || exit 85
```

**Modifications Prokka (lignes 159, 163)**:

**AVANT**:
```bash
prokka $spades_contigs_improved".fasta" --usegenus Viruses ...
prokka $megahit_contigs_improved".fasta" --usegenus Viruses ...
```

**APRÈS**:
```bash
prokka $spades_contigs_improved --usegenus Viruses ...
prokka $megahit_contigs_improved --usegenus Viruses ...
```

---

## 🎯 Résultat Attendu

### Avant le Fix

```
Pilon crée: assembly-based/megahit_contigs_improved.fasta
Variable $megahit_contigs_improved = "assembly-based/megahit_contigs_improved" (SANS .fasta)
taxonomy_conda.sh reçoit: "assembly-based/megahit_contigs_improved"
Kraken2 cherche: assembly-based/megahit_contigs_improved
Résultat: FILE NOT FOUND → 0 sequences processed ❌
```

### Après le Fix

```
Pilon crée: assembly-based/megahit_contigs_improved.fasta
Variable $megahit_contigs_improved = "assembly-based/megahit_contigs_improved.fasta" (AVEC .fasta)
taxonomy_conda.sh reçoit: "assembly-based/megahit_contigs_improved.fasta"
Kraken2 cherche: assembly-based/megahit_contigs_improved.fasta
Résultat: FILE FOUND → 139 contigs processed ✅
```

---

## 🧪 Test de Validation

Pour vérifier que le fix fonctionne:

```bash
# Relancer le pipeline
cd /projects/large/PIMGAVIR/pimgavir_dev
sbatch scripts/PIMGAVIR_conda.sh 40 --ass_based

# Vérifier dans les logs (.out) que Kraken2 traite des séquences:
# Devrait afficher quelque chose comme:
# "139 sequences (1.80 Mbp) processed in X.XXs"
# Au lieu de:
# "0 sequences (0.00 Mbp) processed in 0.003s"

# Vérifier que les fichiers taxonomie sont créés:
ls -lh /scratch/*/pimgavir_dev/scripts/sample9_assembly-based-taxonomy/krakViral.out_MEGAHIT
ls -lh /scratch/*/pimgavir_dev/scripts/sample9_assembly-based-taxonomy/krakViral.out_SPADES

# Ces fichiers devraient maintenant exister et ne pas être vides
```

---

## 📝 Leçons Apprises

### Problème du `source`

Quand on utilise `source script.sh` au lieu de `bash script.sh`:
- Le script s'exécute dans le **même shell**
- Les variables définies dans le script **écrasent** les variables du shell parent
- Les variables du script **restent** dans l'environnement après l'exécution

### Solutions Possibles

1. **✅ Solution choisie**: Assurer la cohérence des noms de variables entre worker et subscripts
2. **Alternative 1**: Utiliser `bash` au lieu de `source` (mais perd l'environnement conda)
3. **Alternative 2**: Utiliser des noms de variables locales différents dans assembly_conda.sh
4. **Alternative 3**: Ne pas redéfinir ces variables dans assembly_conda.sh

### Meilleure Pratique

Quand un script est appelé via `source`:
- **Documenter** quelles variables sont exportées/modifiées
- **Éviter** de redéfinir des variables qui seront utilisées par le script appelant
- **Préfixer** les variables internes avec un underscore (`_megahit_improved_base`)

---

## 🔗 Fichiers Modifiés

- ✅ `scripts/assembly_conda.sh` (lignes 33-40, 137-139, 143-144, 159, 163)
- ✅ `CHANGELOG.md` (ajout section "Variable Scoping Fix")
- ✅ `fixes/CRITICAL_FIX_VARIABLE_SCOPING.md` (ce document)

---

## 📊 Impact

### Avant
- ❌ Pipeline s'arrête après Prokka
- ❌ Pas de classification taxonomique
- ❌ Pas de visualisations Krona
- ❌ Pas d'analyse virale 7 phases
- ❌ Dossier `sample9_assembly-based-taxonomy/` vide ou absent

### Après
- ✅ Pipeline continue après Prokka
- ✅ Classification Kraken2/Kaiju sur MEGAHIT et SPAdes
- ✅ Visualisations Krona générées
- ✅ Analyse virale 7 phases exécutée
- ✅ Résultats complets dans `sample9_assembly-based-taxonomy/`

---

**Auteur**: Claude Code (Anthropic)
**Date**: 2025-11-04
**Testé**: En attente de validation utilisateur
