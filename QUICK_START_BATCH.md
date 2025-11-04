# PIMGAVir Batch Processing - Quick Start

**Version 2.1** | Simple automated multi-sample processing

## 🚀 Quick Start (3 Steps)

### 1. Place Your Samples

```bash
mkdir -p input/
cp /path/to/your/samples/*.fastq.gz input/
```

**Required naming**: Paired-end files with R1/R2 or 1/2 identifiers
- ✅ `sample_R1.fastq.gz` + `sample_R2.fastq.gz`
- ✅ `sample_1.fq.gz` + `sample_2.fq.gz`
- ✅ `sample.R1.fastq.gz` + `sample.R2.fastq.gz`

### 2. Run Batch Processing

```bash
cd scripts/
sbatch PIMGAVIR_conda.sh 40 ALL
```

**That's it!** The pipeline will:
- ✅ Auto-detect all samples
- ✅ Create SLURM array jobs
- ✅ Process samples in parallel
- ✅ Save results automatically

### 3. Monitor Progress

```bash
# Check job status
squeue -u $USER

# View logs
tail -f logs/pimgavir_*.out
```

---

## 📋 Common Commands

### Standard Scratch

```bash
sbatch PIMGAVIR_conda.sh 40 ALL                # All methods
sbatch PIMGAVIR_conda.sh 40 --read_based       # Read-based only
sbatch PIMGAVIR_conda.sh 40 ALL --filter       # With host filtering
```

### Infiniband Scratch (IRD Cluster - Faster!)

```bash
sbatch PIMGAVIR_conda_ib.sh 40 ALL             # All methods
sbatch PIMGAVIR_conda_ib.sh 40 --read_based    # Read-based only
sbatch PIMGAVIR_conda_ib.sh 40 ALL --filter    # With filtering
```

---

## 🔍 Check Sample Detection

```bash
# Test detection without running pipeline
cd scripts/
./detect_samples.sh ../input test.list
cat test.list
```

---

## 📊 Monitor Jobs

```bash
# View job status
squeue -j JOBID

# View all your jobs
squeue -u $USER

# Detailed job info
sacct -j JOBID --format=JobID,JobName,State,ExitCode,Elapsed

# Watch logs in real-time
tail -f logs/pimgavir_*.out
```

---

## 🔧 Troubleshooting

### No samples found?
```bash
# Check files are in place
ls -lh input/

# Verify naming pattern
# Must be: sample_R1.fastq.gz + sample_R2.fastq.gz (or similar)
```

### Missing R2 warning?
```bash
# Ensure both R1 and R2 exist with same base name
ls -lh input/sample_*
```

### Job won't submit?
```bash
# Check SLURM is available
sinfo

# Ensure script is executable
chmod +x scripts/PIMGAVIR_conda.sh
```

---

## 📖 Analysis Methods

| Method | Description | Runtime |
|--------|-------------|---------|
| `ALL` | All three methods in parallel | 2-4 days |
| `--read_based` | Direct read classification | 4-8 hours |
| `--ass_based` | Assembly + classification | 1-3 days |
| `--clust_based` | OTU clustering + classification | 12-24 hours |

---

## 💾 Where Are Results?

```
/projects/large/PIMGAVIR/results/
└── JOBID_SampleName_METHOD/
    ├── read-based-taxonomy/
    ├── assembly-based/
    ├── clustering-based/
    └── report/
```

---

## 🔄 Legacy Mode (Still Works!)

Old single-sample commands still work:

```bash
sbatch PIMGAVIR_conda.sh sample_R1.fq.gz sample_R2.fq.gz sample1 40 ALL
```

---

## 📚 More Information

- **Full Guide**: [docs/BATCH_PROCESSING_GUIDE.md](docs/BATCH_PROCESSING_GUIDE.md)
- **Setup**: [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md)
- **Infiniband**: [docs/INFINIBAND_SETUP.md](docs/INFINIBAND_SETUP.md)

---

## ✨ Advantages

- ✅ **Simple**: One command processes all samples
- ✅ **Fast**: Parallel processing with SLURM array jobs
- ✅ **Automatic**: No manual job management
- ✅ **Compatible**: Old commands still work
- ✅ **Optimized**: Infiniband support for IRD cluster

---

**Need help?** Open an issue or consult the documentation.
