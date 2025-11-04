#!/bin/bash

###################configuration slurm##############################
# PIMGAVir Worker - Processes individual samples from array job (Infiniband)
#SBATCH --job-name=PIMGAVir-IB
#SBATCH --output=../logs/pimgavir_%A_%a.out
#SBATCH --error=../logs/pimgavir_%A_%a.err
#SBATCH --time=3-23:59:59
#SBATCH --partition=normal
#SBATCH --constraint=infiniband
#SBATCH --nodes=1
#SBATCH --mem=64GB
# Define email for script execution
#SBATCH --mail-user=loic.talignani@ird.fr
# Define type notifications (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-type=ALL
###################################################################

################################################################################
# PIMGAVir Worker Script
#
# This script is called by the launcher for each sample in a SLURM array job.
# It processes one sample at a time using parameters passed from the launcher.
#
# Arguments:
#   $1: R1 file path
#   $2: R2 file path
#   $3: Sample name
#   $4: Number of threads
#   $5: Method (ALL, --read_based, --ass_based, --clust_based)
#   $6: Filter option (optional: --filter)
#
# Environment variables from array job:
#   SLURM_ARRAY_JOB_ID: Main job ID
#   SLURM_ARRAY_TASK_ID: Current sample index
################################################################################

##Versioning
version="PIMGAVir V.2.1 -- 29.10.2025 (Worker - Conda + Infiniband Version)"

echo "=========================================="
echo "PIMGAVir Worker - Processing Sample"
echo "=========================================="
echo "Version: $version"
echo "Array Job ID: ${SLURM_ARRAY_JOB_ID:-N/A}"
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID:-N/A}"
echo "Node: $(hostname)"
echo "Started: $(date)"
echo ""

################################################################################
# Parse Arguments
################################################################################
R1=$1 				#R1.fastq.gz
R2=$2 				#R2.fastq.gz
SampleName=$3		#Name associated to the sample
JTrim=$4			#Number of cores to use
METHOD=$5			#Analysis method

# Filter option is the last argument if present
filter=${@: -1}

# Validate arguments
if [ -z "$R1" ] || [ -z "$R2" ] || [ -z "$SampleName" ] || [ -z "$JTrim" ] || [ -z "$METHOD" ]; then
    echo "ERROR: Missing required arguments"
    echo "Usage: PIMGAVIR_worker.sh R1.fastq.gz R2.fastq.gz SampleName NumbOfCores METHOD [--filter]"
    exit 1
fi

echo "Input Parameters:"
echo "  R1: $(basename $R1)"
echo "  R2: $(basename $R2)"
echo "  Sample: $SampleName"
echo "  Threads: $JTrim"
echo "  Method: $METHOD"
echo "  Filter: $filter"
echo ""

################################################################################
# Setup Scratch Directory (INFINIBAND OPTIMIZED)
################################################################################
# Define and create a unique scratch directory for this job on Infiniband network
SCRATCH_DIRECTORY=/scratch-ib/${USER}_${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}

echo "Creating scratch directory: $SCRATCH_DIRECTORY"
mkdir -p ${SCRATCH_DIRECTORY}/
cd ${SCRATCH_DIRECTORY}/

# Save directory
PATH_TO_SAVE="/projects/large/PIMGAVIR/results/"${SLURM_ARRAY_JOB_ID}"_"${SampleName}"_"${METHOD#--}
mkdir -p "$PATH_TO_SAVE"

echo "Results will be saved to: $PATH_TO_SAVE"
echo ""

################################################################################
# Copy Pipeline and Data (using Infiniband network)
################################################################################
echo "=========================================="
echo "Copying pipeline to scratch-ib (excluding databases)"
echo "Using Infiniband network for optimal performance"
echo "=========================================="
echo ""

# Copy only scripts and config files, NOT the large databases
# This saves ~170 GB and ~25-55 minutes of transfer time per job
# Using rsync over ssh with Infiniband network (san-ib)
echo "Using rsync to copy pipeline files via Infiniband..."
rsync -av --exclude='DBs/' \
          --exclude='input/' \
          --exclude='results/' \
          --exclude='.git/' \
          --exclude='*.md' \
          --exclude='docs/' \
          --exclude='archive/' \
          --exclude='fixes/' \
          --exclude='updates/' \
          -e ssh \
          san-ib:/projects/large/PIMGAVIR/pimgavir_dev/ \
          ${SCRATCH_DIRECTORY}/pimgavir_dev/

echo "Done"
echo ""

# Define absolute path to databases on NAS (read-only access via Infiniband)
export PIMGAVIR_DBS_DIR="/projects/large/PIMGAVIR/pimgavir_dev/DBs"
echo "Database Configuration:"
echo "  Using databases from NAS: $PIMGAVIR_DBS_DIR"
echo "  Access: Infiniband network (high-performance)"
echo "  This avoids copying ~170 GB of databases to scratch-ib"
echo "  Databases accessed directly from NAS (read-only)"
echo ""

echo "Copying sample data to scratch-ib directory using Infiniband network..."
scp "san-ib:$R1" ${SCRATCH_DIRECTORY}/pimgavir_dev/scripts/
scp "san-ib:$R2" ${SCRATCH_DIRECTORY}/pimgavir_dev/scripts/
echo "Done"
echo ""

################################################################################
# Setup Conda Environment
################################################################################
echo "Setting up conda environment..."
# Purge all system modules to avoid conflicts
module purge

echo "Activating conda environment..."

# Initialize conda for this shell session
if [ -f "${HOME}/miniconda3/etc/profile.d/conda.sh" ]; then
    source "${HOME}/miniconda3/etc/profile.d/conda.sh"
elif [ -f "${HOME}/anaconda3/etc/profile.d/conda.sh" ]; then
    source "${HOME}/anaconda3/etc/profile.d/conda.sh"
elif [ -f "/opt/miniconda3/etc/profile.d/conda.sh" ]; then
    source "/opt/miniconda3/etc/profile.d/conda.sh"
else
    echo "ERROR: Cannot find conda installation"
    exit 1
fi

# Try to activate conda environment
# Priority: viralgenomes (v2.2+) → complete (deprecated) → minimal (deprecated)
if conda env list | grep -q "pimgavir_viralgenomes"; then
    conda activate pimgavir_viralgenomes
    echo "Activated pimgavir_viralgenomes environment (unified, v2.2+)"
elif conda env list | grep -q "pimgavir_complete"; then
    conda activate pimgavir_complete
    echo "WARNING: Using deprecated pimgavir_complete environment"
    echo "Please migrate to pimgavir_viralgenomes: ./scripts/setup_conda_env_fast.sh"
elif conda env list | grep -q "pimgavir_minimal"; then
    conda activate pimgavir_minimal
    echo "WARNING: Using deprecated pimgavir_minimal environment"
    echo "Please migrate to pimgavir_viralgenomes: ./scripts/setup_conda_env_fast.sh"
else
    echo "ERROR: No PIMGAVir conda environment found"
    echo "Please run: ./scripts/setup_conda_env_fast.sh"
    echo "This creates the unified pimgavir_viralgenomes environment"
    exit 1
fi

# Verify conda environment activation
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to activate conda environment"
    exit 1
fi

echo "Conda environment activated successfully"
echo ""

################################################################################
# Navigate to Scripts Directory
################################################################################
cd pimgavir_dev/scripts/

# Use basename for R1/R2 since we copied them here
R1=$(basename "$R1")
R2=$(basename "$R2")

echo "Working directory: $(pwd)"
echo "Files in directory:"
ls -lh *.fastq.gz 2>/dev/null || echo "No fastq.gz files found"
echo ""

# Clean up any previous BBDuk temporary files
rm -rf *_rRNA_*.fq
rm -rf *_rrna_stats.txt

################################################################################
# Pipeline Parameters
################################################################################
# Use PIMGAVIR_DBS_DIR if set (from worker script), otherwise use relative path
PIMGAVIR_DBS_DIR="${PIMGAVIR_DBS_DIR:-../DBs}"

##Reads-filtering parameters
DiamondDB="${PIMGAVIR_DBS_DIR}/Diamond-RefSeqProt/refseq_protein_nonredund_diamond.dmnd"
OutDiamondDB="blastx_diamond.m8"
InputDB=$SampleName"_not_rRNA.fq"
PathToRefSeq="${PIMGAVIR_DBS_DIR}/NCBIRefSeq"
UnWanted="unwanted.txt"

##Assembly parameters
megahit_contigs_improved="assembly-based/megahit_contigs_improved.fasta"
spades_contigs_improved="assembly-based/spades_contigs_improved.fasta"

##Clustering parameters
OTUDB="clustering-based/otus.fasta"

logfile="pimgavir.log"

################################################################################
# Validation
################################################################################
#1. Check that input files exist
if [ ! -f "$R1" ] || [ ! -f "$R2" ]; then
	echo "ERROR: $R1 or $R2 don't exist. Exiting"
	echo -e "$(date) ERROR: $R1 or $R2 don't exist. Exiting \n" >> $logfile 2>&1
	exit 1
fi

#2. Check the NumberOfCores is a valid number
if [[ ! $JTrim -gt 0 ]]; then
    echo "ERROR: Invalid number of cores. Exiting"
	echo -e "$(date) ERROR: Invalid number of cores. Exiting \n" >> $logfile 2>&1
	exit 1
fi

#3. Validate method
case $METHOD in
    "ALL"|"--read_based"|"--ass_based"|"--clust_based")
        echo "Method validation: OK"
        echo -e "$(date) Method $METHOD validated \n" >> $logfile 2>&1
        ;;
    *)
        echo "ERROR: Invalid method: $METHOD"
        echo "Valid methods: ALL, --read_based, --ass_based, --clust_based"
        exit 1
        ;;
esac

################################################################################
# Analysis Functions
################################################################################
assembly_func(){
	printf "Calling Assembly-based taxonomy task\n and using $JTrim threads"
	echo -e "$(date) Calling Assembly-based taxonomy task\n" >> $logfile 2>&1
		source assembly_conda.sh $sequence_data assembly-based $JTrim &&
		{
			# Process MEGAHIT assembly: taxonomy first, then krona-blast
			source taxonomy_conda.sh $megahit_contigs_improved $SampleName"_assembly-based-taxonomy" $JTrim _MEGAHIT &&
			source krona-blast_conda.sh $megahit_contigs_improved $SampleName"_assembly-based-MEGAHIT-KRONA-BLAST" $JTrim $SampleName

			# Process SPAdes assembly: taxonomy first, then krona-blast
			source taxonomy_conda.sh $spades_contigs_improved $SampleName"_assembly-based-taxonomy" $JTrim _SPADES &&
			source krona-blast_conda.sh $spades_contigs_improved $SampleName"_assembly-based-SPADES-KRONA-BLAST" $JTrim $SampleName
	   	}

	# NEW: Viral genome recovery and analysis - All 7 phases (if assemblies exist)
	if [ -f "$megahit_contigs_improved" ]; then
		echo "Running complete viral genome analysis (7 phases) on MEGAHIT assembly..."
		mkdir -p viral-genomes-megahit
		echo -e "$(date) Running complete viral genome analysis (7 phases) on MEGAHIT assembly\n" >> $logfile 2>&1
		source viral-genome-complete-7phases.sh \
			"$megahit_contigs_improved" \
			"viral-genomes-megahit" \
			"$JTrim" \
			"${SampleName}_MEGAHIT" \
			"" \
			"" \
			"" \
			"MEGAHIT" \
			2>&1 | tee -a $logfile || echo "WARNING: Viral genome analysis failed for MEGAHIT"
	fi

	if [ -f "$spades_contigs_improved" ]; then
		echo "Running complete viral genome analysis (7 phases) on SPAdes assembly..."
		mkdir -p viral-genomes-spades
		echo -e "$(date) Running complete viral genome analysis (7 phases) on SPAdes assembly\n" >> $logfile 2>&1
		source viral-genome-complete-7phases.sh \
			"$spades_contigs_improved" \
			"viral-genomes-spades" \
			"$JTrim" \
			"${SampleName}_SPADES" \
			"" \
			"" \
			"" \
			"SPADES" \
			2>&1 | tee -a $logfile || echo "WARNING: Viral genome analysis failed for SPAdes"
	fi
}

clustering_func(){
	printf "Calling Clustering-based taxonomy task\n and using $JTrim threads"
	echo -e "$(date) Calling Clustering-based taxonomy task\n" >> $logfile 2>&1
		source clustering_conda.sh $sequence_data $SampleName"_clustering-based" $JTrim $SampleName &&
		source taxonomy_conda.sh $OTUDB $SampleName"_clustering-based-taxonomy" $JTrim _OTU &&
		source krona-blast_conda.sh $OTUDB $SampleName"_clustering-based-KRONA-BLAST" $JTrim $SampleName
}

################################################################################
# Start Processing
################################################################################
echo "=========================================="
echo "Starting Pipeline Processing"
echo "=========================================="
echo ""

##Calling pre-process task
NotrRNAReads=$SampleName"_not_rRNA.fq.gz"
#If a not_rRNA.fq.gz file exists from the same sample name, the pre-process task is skipped
if [ -f "$NotrRNAReads" ];
	then
	    printf 'File %s already exists, skipping pre-process step \n' "$NotrRNAReads"
	    printf 'File %s already exists, skipping pre-process step \n' "$NotrRNAReads" >> $logfile 2>&1
    else
	  	echo "Calling pre-process task (conda version)"
		echo -e "$(date) Calling pre-process task (conda version)\n" >> $logfile 2>&1

		# Call pre-process and show output in real-time
		echo "===================="
		echo "Running pre-process_conda.sh with arguments:"
		echo "  R1: $R1"
		echo "  R2: $R2"
		echo "  Sample: $SampleName"
		echo "  Threads: $JTrim"
		echo "  Method: $METHOD"
		echo "===================="

		source pre-process_conda.sh $R1 $R2 $SampleName $JTrim $METHOD 2>&1 | tee -a $logfile

		# Check if pre-process succeeded
		if [ ${PIPESTATUS[0]} -ne 0 ]; then
			echo "ERROR: pre-process_conda.sh failed!"
			exit 1
		fi

		# Verify output file was created
		if [ ! -f "$NotrRNAReads" ]; then
			echo "ERROR: Expected output file not found: $NotrRNAReads"
			echo "Listing current directory:"
			ls -lh
			exit 1
		fi

		echo "Pre-process completed successfully"
fi

##Check for reads-filtering task
case $filter in
  	("--filter")
  			if [ -f "$UnWanted" ]; then
				echo -e "$UnWanted file found, moving ahead \n" >> $logfile 2>&1
				echo -e "$UnWanted file found, moving ahead \n"
	  			sequence_data="readsNotrRNA_filtered.fq.gz"
	  			if [ ! -f "$sequence_data" ]; then
		  			echo "Calling reads-filtering task"
					echo -e "$(date) Calling reads-filtering task\n" >> $logfile 2>&1
					source reads-filtering_conda.sh $DiamondDB $JTrim $InputDB $OutDiamondDB $PathToRefSeq $UnWanted
				else
					printf 'File %s already exists, skipping reads-filtering step \n' "$sequence_data"
    				printf 'File %s already exists, skipping reads-filtering step \n' "$sequence_data" >> $logfile 2>&1
    			fi
			else
    			echo -e "$UnWanted file does not exist...terminated \n" >> $logfile 2>&1
    			echo -e "$UnWanted file does not exist...terminated \n"
    			exit 1
 			fi
 			;;
  	(*)
  			sequence_data=$SampleName"_not_rRNA.fq.gz"
  			echo "Filtering not activated, moving to next task";;
esac

##Start taxonomy analysis based on method
if [ $METHOD == 'ALL' ];
	then
		JTrim=$((JTrim/3))
		printf "Executing ALL (read-based, assembly-based and clustering-based) taxonomy processes \n"
		echo -e "$(date) Calling ALL (read-based, assembly-based and clustering-based) taxonomy tasks \n" >> $logfile

		##Call read-based taxonomy classification
		printf "Calling Read-based taxonomy task and using $JTrim threads"
		echo -e "$(date) Calling Read-based taxonomy task \n" >> $logfile 2>&1
		source taxonomy_conda.sh $sequence_data $SampleName"_read-based-taxonomy" $JTrim _READ & ##It will run in bg mode

		##Call assembly-based taxonomy classification
		assembly_func & ##It will run in bg mode

		##Call clustering-based taxonomy classification
		clustering_func & ##It will run in bg mode

		# Wait for all background jobs to complete
		wait
	else
		case $METHOD in
		  	("--read_based")
		    	printf "Executing Read-based taxonomy process \n"
		    	echo -e "$(date) Calling Read-based taxonomy task\n" >> $logfile 2>&1
		    	source taxonomy_conda.sh $sequence_data read-based-taxonomy $JTrim _READ
		    	seqkit fq2fa $sequence_data > readsToblastn.fasta
		    	source krona-blast_conda.sh readsToblastn.fasta $SampleName"_read-based-KRONA-BLAST" $JTrim $SampleName
		    	;;
		    ("--ass_based")
		    	printf "Calling the Assembly-based function \n"
		    	echo -e "$(date) Calling the Assembly-based function \n" >> $logfile 2>&1
		    	assembly_func
		    	;;
		    ("--clust_based")
		    	printf "Calling the Clustering-based function \n"
		    	echo -e "$(date) Calling the Clustering-based function \n" >> $logfile 2>&1
		    	clustering_func
		    	;;
		    (*)
		    	echo "ERROR: Invalid method specified"
		    	exit 1
		    	;;
		esac
fi

################################################################################
# Cleanup and Transfer Results
################################################################################
echo ""
echo "=========================================="
echo "Processing Complete - Transferring Results"
echo "=========================================="
echo ""

echo "Data transfer: scratch -> permanent storage"
echo "Target: $PATH_TO_SAVE"

# Delete input files
rm -rf $R1
rm -rf $R2
rm -f *.sh
rm -f concatenate_reads.py

# Move up to copy entire scripts directory
cd ..

# Transfer results
echo "Copying results..."
scp -r scripts/ $PATH_TO_SAVE

# Delete scratch directory
echo "Cleaning up scratch directory: ${SCRATCH_DIRECTORY}"
rm -rf ${SCRATCH_DIRECTORY}

echo ""
echo "=========================================="
echo "Sample Processing Complete"
echo "=========================================="
echo "Sample: $SampleName"
echo "Results saved to: $PATH_TO_SAVE"
echo "Completed: $(date)"
echo "=========================================="
