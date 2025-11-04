# PIMGAVir Batch Processing - Implementation Plan

## Current Situation Analysis

### Current Workflow (Manual)
```bash
# User must manually specify each sample
sbatch PIMGAVIR_conda.sh sample1_R1.fastq.gz sample1_R2.fastq.gz sample1 40 ALL --filter
sbatch PIMGAVIR_conda.sh sample2_R1.fastq.gz sample2_R2.fastq.gz sample2 40 ALL --filter
sbatch PIMGAVIR_conda.sh sample3_R1.fastq.gz sample3_R2.fastq.gz sample3 40 ALL --filter
# ... and so on
```

**Problems**:
- ❌ Files must be in `scripts/` directory
- ❌ One command per sample (tedious for many samples)
- ❌ Must manually determine sample names
- ❌ Easy to make mistakes in file pairing
- ❌ No batch processing capability

---

## Desired Workflow (Automated)

### Target Usage
```bash
# Simple command that processes all samples in input/
sbatch PIMGAVIR_conda.sh 40 ALL [--filter]
```

### Directory Structure
```
pimgavir_dev/
├── input/                          # New directory for raw data
│   ├── sample1_R1.fastq.gz
│   ├── sample1_R2.fastq.gz
│   ├── sample2_R1.fastq.gz
│   ├── sample2_R2.fastq.gz
│   ├── sampleN_R1.fastq.gz
│   └── sampleN_R2.fastq.gz
├── scripts/
│   ├── PIMGAVIR_conda.sh           # Modified launcher script
│   ├── PIMGAVIR_worker.sh          # New worker script (per sample)
│   └── ... (other scripts)
└── results/                        # Output directory
    ├── sample1/
    ├── sample2/
    └── sampleN/
```

---

## Implementation Strategy

### Option 1: Array Job Approach (RECOMMENDED)

**Concept**: Use SLURM array jobs to spawn one job per sample

#### Architecture
```
PIMGAVIR_conda.sh (launcher)
    ├─> Discovers samples in input/
    ├─> Creates sample list file
    └─> Submits array job
         ├─> Job 1: sample1
         ├─> Job 2: sample2
         └─> Job N: sampleN
```

#### Advantages
- ✅ Native SLURM feature
- ✅ Easy to monitor (`squeue`, `sacct`)
- ✅ Built-in job dependency management
- ✅ Automatic parallelization
- ✅ Can set max concurrent jobs

#### Disadvantages
- ⚠️ Requires SLURM array job support (should be available)
- ⚠️ All jobs use same resources (cpus, mem, time)

---

### Option 2: Loop Submission Approach

**Concept**: Loop through samples and submit individual jobs

#### Architecture
```bash
for sample in input/*_R1.fastq.gz; do
    sbatch PIMGAVIR_worker.sh $sample ...
done
```

#### Advantages
- ✅ Simple to implement
- ✅ Each job independent
- ✅ Can customize resources per sample

#### Disadvantages
- ❌ Creates many job files in queue
- ❌ Harder to track as a group
- ❌ No built-in dependency management

---

## Recommended Solution: **Option 1 - Array Jobs**

### Implementation Components

#### 1. Sample Detection Logic

**Function**: `detect_samples()`
```bash
# Scan input/ directory for R1/R2 pairs
# Naming conventions supported:
#   - sample_R1.fastq.gz / sample_R2.fastq.gz
#   - sample_1.fastq.gz / sample_2.fastq.gz
#   - sample.R1.fastq.gz / sample.R2.fastq.gz
```

**Output**: `samples.list` file
```
sample1 sample1_R1.fastq.gz sample1_R2.fastq.gz
sample2 sample2_R1.fastq.gz sample2_R2.fastq.gz
sampleN sampleN_R1.fastq.gz sampleN_R2.fastq.gz
```

#### 2. Modified Launcher Script

**File**: `PIMGAVIR_conda.sh` (modified)

```bash
#!/bin/bash
#SBATCH --job-name=PIMGAVir_launcher
# No array directive here - this is just the launcher

# New usage
#Usage: sbatch PIMGAVIR_conda.sh <NumbOfCores> <Method> [--filter]
#Example: sbatch PIMGAVIR_conda.sh 40 ALL --filter

# 1. Detect samples in input/
# 2. Create samples.list
# 3. Submit array job with PIMGAVIR_worker.sh
```

#### 3. New Worker Script

**File**: `PIMGAVIR_worker.sh` (new)

```bash
#!/bin/bash
#SBATCH --job-name=PIMGAVir
#SBATCH --array=0-N%5              # N samples, max 5 concurrent
#SBATCH --output=logs/sample_%A_%a.out
#SBATCH --error=logs/sample_%A_%a.err
#SBATCH --time=6-23:59:59
#SBATCH --partition=highmem
#SBATCH --cpus-per-task=40
#SBATCH --mem=256GB

# Read sample info from array index
SAMPLE_LINE=$((SLURM_ARRAY_TASK_ID + 1))
SAMPLE_INFO=$(sed -n "${SAMPLE_LINE}p" samples.list)
SAMPLE_NAME=$(echo $SAMPLE_INFO | awk '{print $1}')
R1_FILE=$(echo $SAMPLE_INFO | awk '{print $2}')
R2_FILE=$(echo $SAMPLE_INFO | awk '{print $3}')

# Process this sample
# ... existing pipeline code ...
```

---

## Detailed Implementation Plan

### Phase 1: Directory Structure Setup

**Task 1.1**: Create `input/` directory
```bash
mkdir -p input/
mkdir -p logs/
```

**Task 1.2**: Create `.gitignore` entries
```
input/*.fastq.gz
input/*.fq.gz
logs/*.out
logs/*.err
```

---

### Phase 2: Sample Detection Module

**Task 2.1**: Create `detect_samples.sh` utility script

```bash
#!/bin/bash
# detect_samples.sh
# Scans input/ and creates samples.list

INPUT_DIR="input"
OUTPUT_FILE="samples.list"

# Clear existing file
> $OUTPUT_FILE

# Find all R1 files
for R1 in ${INPUT_DIR}/*_R1.fastq.gz ${INPUT_DIR}/*_1.fastq.gz ${INPUT_DIR}/*.R1.fastq.gz; do
    [ ! -f "$R1" ] && continue

    # Derive sample name
    SAMPLE_NAME=$(basename $R1 | sed -E 's/(_R1|_1|\.R1)\.fastq\.gz$//')

    # Find corresponding R2
    R2=""
    for suffix in "_R2" "_2" ".R2"; do
        CANDIDATE="${INPUT_DIR}/${SAMPLE_NAME}${suffix}.fastq.gz"
        if [ -f "$CANDIDATE" ]; then
            R2="$CANDIDATE"
            break
        fi
    done

    # Verify pair exists
    if [ -z "$R2" ]; then
        echo "Warning: No R2 found for $R1" >&2
        continue
    fi

    # Add to list
    echo "$SAMPLE_NAME $R1 $R2" >> $OUTPUT_FILE
done

# Report
NUM_SAMPLES=$(wc -l < $OUTPUT_FILE)
echo "Detected $NUM_SAMPLES sample(s)" >&2
```

**Task 2.2**: Add validation
- Check for duplicate sample names
- Verify file readability
- Check minimum file sizes

---

### Phase 3: Modify Launcher Script

**Task 3.1**: Update `PIMGAVIR_conda.sh` argument parsing

**Before**:
```bash
R1=$1
R2=$2
SampleName=$3
JTrim=$4
METHOD=$5
filter=$6
```

**After**:
```bash
# New argument structure
JTrim=$1          # Number of cores
METHOD=$2         # ALL, --read_based, --ass_based, --clust_based
filter=$3         # --filter or empty
```

**Task 3.2**: Add sample detection call
```bash
# Detect samples
echo "Detecting samples in input/ directory..."
./detect_samples.sh

# Check if any samples found
NUM_SAMPLES=$(wc -l < samples.list)
if [ $NUM_SAMPLES -eq 0 ]; then
    echo "Error: No samples found in input/"
    echo "Please place paired FASTQ files in input/"
    echo "Expected naming: sample_R1.fastq.gz and sample_R2.fastq.gz"
    exit 1
fi

echo "Found $NUM_SAMPLES sample(s) to process"
cat samples.list
```

**Task 3.3**: Submit array job
```bash
# Calculate array range
MAX_INDEX=$((NUM_SAMPLES - 1))

# Submit worker array job
WORKER_JOB=$(sbatch \
    --array=0-${MAX_INDEX}%5 \
    --cpus-per-task=${JTrim} \
    --export=ALL,METHOD=${METHOD},FILTER=${filter} \
    PIMGAVIR_worker.sh)

echo "Submitted array job: $WORKER_JOB"
echo "Monitor with: squeue -u $USER"
echo "View logs in: logs/"
```

---

### Phase 4: Create Worker Script

**Task 4.1**: Create `PIMGAVIR_worker.sh`

**Structure**:
```bash
#!/bin/bash
#SBATCH directives...

# Get sample info from array index
SAMPLE_LINE=$((SLURM_ARRAY_TASK_ID + 1))
read SAMPLE_NAME R1_FILE R2_FILE < <(sed -n "${SAMPLE_LINE}p" samples.list)

echo "Processing sample: $SAMPLE_NAME"
echo "R1: $R1_FILE"
echo "R2: $R2_FILE"

# Setup scratch directory (per sample)
SCRATCH_DIRECTORY=/scratch/${USER}_${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}
mkdir -p ${SCRATCH_DIRECTORY}
cd ${SCRATCH_DIRECTORY}

# Copy pipeline and data
scp -r /projects/large/PIMGAVIR/pimgavir_dev/ ${SCRATCH_DIRECTORY}
cp ${R1_FILE} ${SCRATCH_DIRECTORY}/pimgavir_dev/scripts/
cp ${R2_FILE} ${SCRATCH_DIRECTORY}/pimgavir_dev/scripts/

# Run pipeline (existing code)
cd pimgavir_dev/scripts/
# ... existing pipeline logic ...

# Copy results back
mkdir -p "/projects/large/PIMGAVIR/results/${SAMPLE_NAME}_${SLURM_JOB_ID}_${METHOD#--}"
scp -r * "/projects/large/PIMGAVIR/results/${SAMPLE_NAME}_${SLURM_JOB_ID}_${METHOD#--}/"

# Cleanup scratch
rm -rf ${SCRATCH_DIRECTORY}
```

---

### Phase 5: Enhanced Features (Optional)

**Task 5.1**: Progress tracking
```bash
# Create progress file
echo "0/$NUM_SAMPLES" > progress.txt

# Worker updates on completion
COMPLETED=$(ls logs/*.done 2>/dev/null | wc -l)
echo "$COMPLETED/$NUM_SAMPLES" > progress.txt
```

**Task 5.2**: Email notification summary
```bash
# After all jobs complete
# Send summary email with:
# - Number of samples processed
# - Success/failure counts
# - Location of results
```

**Task 5.3**: Automatic report generation
```bash
# Generate HTML summary report
# - List of samples
# - Processing status
# - Links to results
```

---

## File Modifications Required

### New Files (3)

1. **`scripts/detect_samples.sh`**
   - Sample detection logic
   - ~100 lines

2. **`scripts/PIMGAVIR_worker.sh`**
   - Per-sample worker script
   - Based on existing PIMGAVIR_conda.sh
   - ~400 lines

3. **`docs/BATCH_PROCESSING.md`**
   - User guide for batch processing
   - ~200 lines

### Modified Files (2)

1. **`scripts/PIMGAVIR_conda.sh`**
   - Transform into launcher
   - ~200 lines modified

2. **`README.md`**
   - Update usage examples
   - Add batch processing section

---

## Usage Examples (After Implementation)

### Example 1: Process All Samples with All Methods
```bash
# Place samples in input/
cp /path/to/samples/*.fastq.gz input/

# Launch pipeline
sbatch PIMGAVIR_conda.sh 40 ALL

# Monitor
squeue -u $USER
tail -f logs/sample_*.out
```

### Example 2: Process with Filtering
```bash
sbatch PIMGAVIR_conda.sh 40 ALL --filter
```

### Example 3: Only Read-Based Taxonomy
```bash
sbatch PIMGAVIR_conda.sh 40 --read_based
```

### Example 4: Custom Resources
```bash
# Edit PIMGAVIR_worker.sh SBATCH directives first
sbatch PIMGAVIR_conda.sh 20 --ass_based
```

---

## Migration Strategy

### For Existing Users

**Backward Compatibility**: Keep old interface temporarily

```bash
# Old way (still works)
sbatch PIMGAVIR_conda_single.sh sample_R1.fq.gz sample_R2.fq.gz sample 40 ALL

# New way
# Place files in input/ and run:
sbatch PIMGAVIR_conda.sh 40 ALL
```

**Transition Period**: 3-6 months
- Document both methods
- Mark old method as deprecated
- Eventually rename scripts:
  - `PIMGAVIR_conda.sh` → `PIMGAVIR_batch.sh`
  - `PIMGAVIR_conda_single.sh` → `PIMGAVIR_conda.sh`

---

## Testing Plan

### Test Case 1: Single Sample
```bash
input/
├── test1_R1.fastq.gz
└── test1_R2.fastq.gz

Expected: 1 job submitted
```

### Test Case 2: Multiple Samples
```bash
input/
├── sample1_R1.fastq.gz
├── sample1_R2.fastq.gz
├── sample2_R1.fastq.gz
├── sample2_R2.fastq.gz
├── sample3_R1.fastq.gz
└── sample3_R2.fastq.gz

Expected: 3 jobs submitted (array 0-2)
```

### Test Case 3: Mixed Naming Conventions
```bash
input/
├── sample1_R1.fastq.gz     # _R1/_R2 style
├── sample1_R2.fastq.gz
├── sample2_1.fastq.gz      # _1/_2 style
├── sample2_2.fastq.gz
├── sample3.R1.fastq.gz     # .R1/.R2 style
└── sample3.R2.fastq.gz

Expected: 3 jobs, all detected correctly
```

### Test Case 4: Error Handling
```bash
input/
├── orphan_R1.fastq.gz      # No R2
└── sample1_R1.fastq.gz
    # sample1_R2.fastq.gz missing

Expected: Warnings, skip orphans, continue with valid pairs
```

---

## Implementation Timeline

### Phase 1: Core Functionality (Week 1)
- [ ] Create `input/` directory structure
- [ ] Implement `detect_samples.sh`
- [ ] Test sample detection with various naming schemes

### Phase 2: Worker Script (Week 1-2)
- [ ] Create `PIMGAVIR_worker.sh` from existing code
- [ ] Test with single sample
- [ ] Test with multiple samples

### Phase 3: Launcher Integration (Week 2)
- [ ] Modify `PIMGAVIR_conda.sh` to launcher
- [ ] Integrate sample detection
- [ ] Implement array job submission

### Phase 4: Testing & Refinement (Week 2-3)
- [ ] Test all use cases
- [ ] Handle edge cases
- [ ] Optimize performance

### Phase 5: Documentation (Week 3)
- [ ] Write user guide
- [ ] Update README
- [ ] Create examples

---

## Risk Assessment

### Potential Issues

1. **SLURM Array Job Limits**
   - **Risk**: Cluster may have max array size limit
   - **Mitigation**: Use `%N` to limit concurrent jobs
   - **Example**: `--array=0-99%10` (100 samples, max 10 concurrent)

2. **Scratch Space Contention**
   - **Risk**: Multiple jobs filling /scratch simultaneously
   - **Mitigation**: Unique scratch dirs per job
   - **Monitor**: Disk usage in worker script

3. **File Locking**
   - **Risk**: Race conditions in shared files (samples.list)
   - **Mitigation**: Read-only access in workers

4. **Incomplete Pairs**
   - **Risk**: User places only R1 or R2 file
   - **Mitigation**: Strict validation in detect_samples.sh

---

## Success Criteria

### Must Have
- ✅ Detect samples automatically from `input/`
- ✅ Submit one job per sample
- ✅ Simplified command line (no file names needed)
- ✅ Works with all existing methods (ALL, --read_based, etc.)
- ✅ Proper error handling

### Should Have
- ✅ Support multiple naming conventions
- ✅ Progress tracking
- ✅ Centralized logging
- ✅ Backward compatibility option

### Nice to Have
- ⭐ Email summary reports
- ⭐ HTML progress dashboard
- ⭐ Automatic result aggregation
- ⭐ Failed job retry mechanism

---

## Questions to Resolve

1. **Maximum concurrent jobs**: How many samples should run simultaneously?
   - Recommendation: 5-10 (configurable with `--array=0-N%5`)

2. **Default method**: Should there be a default if not specified?
   - Recommendation: No default, require explicit choice

3. **Input directory location**: `input/` at root or `scripts/input/`?
   - Recommendation: Root level (`pimgavir_dev/input/`)

4. **Result organization**: Flat or hierarchical?
   ```
   Option A (flat):
   results/
   ├── sample1_12345_ALL/
   ├── sample2_12346_ALL/

   Option B (hierarchical):
   results/
   └── batch_20251028/
       ├── sample1/
       ├── sample2/
   ```
   - Recommendation: Option B with date-stamped batches

5. **Cleanup policy**: Keep or delete scratch automatically?
   - Recommendation: Delete after successful copy to results

---

## Next Steps

**Decision Point**: Which option do you prefer?

1. **Full implementation** as described above
2. **Simplified version** (no array jobs, simple loop)
3. **Hybrid approach** (optional array jobs)

**Questions for You**:
- Do you prefer SLURM array jobs or simple loop submission?
- What's the typical number of samples you process at once?
- Any specific naming conventions you use that we should support?
- Should we maintain backward compatibility with old command format?

---

## Recommendation

**Proceed with**: Array Job Approach (Option 1)

**Rationale**:
- More elegant and manageable
- Better integration with SLURM
- Easier to monitor and control
- Scalable to hundreds of samples

**Implementation Order**:
1. ✅ Create `detect_samples.sh` (standalone, testable)
2. ✅ Create `PIMGAVIR_worker.sh` (test manually first)
3. ✅ Modify `PIMGAVIR_conda.sh` (integrate pieces)
4. ✅ Test end-to-end
5. ✅ Document and deploy

Would you like me to proceed with implementation?
