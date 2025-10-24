#!/bin/bash

###################configuration slurm##############################
# PIMGAVir - Pure Conda + Infiniband Optimized Version
#SBATCH --job-name=PIMGAVir-Conda-IB
#SBATCH --output=pimgavir_conda_ib.%A.out
#SBATCH --error=pimgavir_conda_ib.%A.err
#SBATCH --time=6-23:59:59
#SBATCH --partition=highmem
#SBATCH --constraint=infiniband
#SBATCH --nodes=1
#sbatch --cpus-per-task=40
#SBATCH --mem=256GB
# Define email for script execution
#SBATCH --mail-user=loic.talignani@ird.fr
# Define type notifications (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-type=ALL
###################################################################

#Usage sbatch PIMGAVIR_conda_ib.sh R1.fastq.gz R2.fastq.gz SampleName NumbOfCores ALL|[--read_based --ass_based --clust_based] [--filter]
#As an example: sbatch PIMGAVIR_conda_ib.sh sample9_1.fastq.gz sample9_2.fastq.gz sample9 40 --read_based --filter

# Define and create a unique scratch directory for this job (INFINIBAND OPTIMIZED)
SCRATCH_DIRECTORY=/scratch-ib/${USER}_${SLURM_JOB_ID}

mkdir -p ${SCRATCH_DIRECTORY}/
cd ${SCRATCH_DIRECTORY}/

# Save directory
SampleName=$3
METHOD=$5
OUTPUT_DIR="/projects/large/PIMGAVIR/results/${SLURM_JOB_ID}_${SampleName}_${METHOD#--}"
mkdir -p "$OUTPUT_DIR"
PATH_TO_SAVE="$OUTPUT_DIR"

echo "Copy data to the scratch-ib directory using Infiniband network"
# Copy to the scratch-ib directory using san-ib for optimal transfer speed
scp -r san-ib:/projects/large/PIMGAVIR/pimgavir_dev/ ${SCRATCH_DIRECTORY}

echo "Done"

echo "Setting up conda environment"
# Purge all system modules to avoid conflicts
module purge

# Activate conda environment - all tools are included in conda
echo "Activating conda environment..."

# Initialize conda for this shell session
if [ -f "${HOME}/miniconda3/etc/profile.d/conda.sh" ]; then
    source "${HOME}/miniconda3/etc/profile.d/conda.sh"
elif [ -f "${HOME}/anaconda3/etc/profile.d/conda.sh" ]; then
    source "${HOME}/anaconda3/etc/profile.d/conda.sh"
elif [ -f "/opt/miniconda3/etc/profile.d/conda.sh" ]; then
    source "/opt/miniconda3/etc/profile.d/conda.sh"
else
    echo "Error: Cannot find conda installation"
    echo "Please ensure conda is installed and accessible"
    exit 1
fi

# Try to activate conda environment (complete first, then minimal)
if conda env list | grep -q "pimgavir_complete"; then
    conda activate pimgavir_complete
    echo "Activated pimgavir_complete environment"
elif conda env list | grep -q "pimgavir_minimal"; then
    conda activate pimgavir_minimal
    echo "Activated pimgavir_minimal environment"
else
    echo "Error: No PIMGAVir conda environment found"
    echo "Please create one of the following environments:"
    echo "  mamba env create -f scripts/pimgavir_complete.yaml  (recommended)"
    echo "  mamba env create -f scripts/pimgavir_minimal.yaml   (minimal)"
    echo "OR run: ./scripts/setup_conda_env_fast.sh"
    exit 1
fi

# Verify conda environment activation
if [ $? -ne 0 ]; then
    echo "Error: Failed to activate conda environment"
    exit 1
fi

echo "Conda environment activated successfully"
echo "Available tools:"
which kraken2 kaiju ktImportTaxonomy megahit blastn bbduk.sh

echo "Done"

# Run analysis
cd pimgavir_dev/scripts/

# Clean up any previous BBDuk temporary files
rm -rf *_rRNA_*.fq
rm -rf *_rrna_stats.txt

######################################### ENVIRONMENT SETUP - END ##################################

##Versioning
version="PIMGAVir V.2.0 -- 24.10.2025 (Pure Conda + Infiniband Optimized)"

##Pre-processing parameters
R1=$1 				#R1.fastq.gz
R2=$2 				#R2.fastq.gz
SampleName=$3	#Name associated to the sample
JTrim=$4			#Number of cores to use

##Reads-filtering parameters
filter=${@: -1}	#Filter option (boolean: if specified the filter step will be done, otherwise not)
DiamondDB="../DBs/Diamond-RefSeqProt/refseq_protein_nonredund_diamond.dmnd"
OutDiamondDB="blastx_diamond.m8"
InputDB=$SampleName"_not_rRNA.fq"
PathToRefSeq="../DBs/NCBIRefSeq" # Changed RefSeq in NCBIRefSeq
UnWanted="unwanted.txt"

##Assembly parameters
megahit_contigs_improved="assembly-based/megahit_contigs_improved.fasta"
spades_contigs_improved="assembly-based/spades_contigs_improved.fasta"

##Clustering parameters
OTUDB="clustering-based/otus.fasta"

PassedArgs=$#   							#Number of passed arguments
NumOfArgs=4										#At least 4 parameters are needed
Trimgalore="trim-galore.log"
logfile="pimgavir.log"

#echo "Number of passed args is " $PassedArgs

##Checking for Version option
if (($# == 1))
then
	if [ "$1" == "--version" ]
	then
		echo $version
	else
		echo "Option not valid"
	fi
	exit
fi

##Checking the number of arguments
if (( $# < $NumOfArgs ))
then
    printf "%b" "Error. Not enough arguments.\n" >&2
    printf "%b" "Usage PIMGAVIR_conda_ib.sh R1.fastq.gz R2.fastq.gz SampleName NumbOfCores ALL|[--read_based --ass_based --clust_based] [--filter] \n" >&2
    exit 1
elif (( $# > $NumOfArgs+4 ))
then
    printf "%b" "Error. Too many arguments.\n" >&2
    printf "%b" "Usage PIMGAVIR_conda_ib.sh R1.fastq.gz R2.fastq.gz SampleName NumbOfCores ALL|[--read_based --ass_based --clust_based] [--filter] \n" >&2
    exit 2
else
    if [ -n "$JTrim" ] && [ "$JTrim" -eq "$JTrim" ] 2>/dev/null; then
  	echo "Going to use $JTrim threads"
    	printf "%b" "Argument count correct. Continuing processing..."
    	case $filter in
  		("--filter")    echo "Filtering activated ";;
  		(*) echo "Filtering not activated ";;
  	esac
    else
  	echo "$JTrim is not a valid number of threads. Please insert an integer value"
  	exit 2
    fi
fi

##Checking validity of arguments
#1. Check that input files exist
if [ ! -f "$R1" ] || [ ! -f "$R2" ]; then
	echo "$R1 or $R2 don't exist. Exiting"
	echo -e "$(date) $R1 or $R2 don't exist. Exiting \n" >> $logfile 2>&1
	exit
fi

#2. Check the NumberOfCores is a valid number
if [[ ! $JTrim -gt 00 ]]; then
        echo "Invalid number of cores. Exiting"
	echo -e "$(date) Invalid number of cores. Exiting \n" >> $logfile 2>&1
	exit
fi

#3. Check the methods are valid
args=("$@")

if [ ${args[4]} != "ALL" ];
then
	if [ ${args[$PassedArgs-1]} = "--filter" ];
	then
		count=$((PassedArgs-1))
		#echo "filter yes --> " $count
	else
		count=$PassedArgs
		#echo "filter not --> " $count
	fi
	for ((j=4; j<count; j++))
		do
			case ${args[$j]} in
			("--read_based")
		   		printf "Read-based, valid method found \n"
		   		echo -e "$(date) Read-based, valid method found \n" >> $logfile 2>&1 ;;
		   	("--ass_based")
		   		printf "Assembly-based, valid method found \n"
		   		echo -e "$(date) Assembly-based, valid method found \n" >> $logfile 2>&1 ;;
		   	("--clust_based")
		   		printf "Clustering-based, valid method found \n"
		    		echo -e "$(date) Clustering-based, valid method found \n" >> $logfile 2>&1 ;;
		   	(*)
		   		printf "One of the methods is not valid, please check the correct spelling \n"
		   		echo "One of the following option must be specified: ALL|[--read_based --ass_based --clust_based] "
		   		exit;;
	   		esac
	   	done
else
	printf "ALL option, valid method found \n"
	echo -e "$(date) ALL option, valid method found \n" >> $logfile 2>&1
fi

assembly_func(){
	printf "Calling Assembly-based taxonomy task\n and using $JTrim threads"
	echo -e "$(date) Calling Assembly-based taxonomy task\n" >> $logfile 2>&1
		./assembly.sh $sequence_data assembly-based $JTrim &&
		{
			./taxonomy_conda.sh $megahit_contigs_improved $SampleName"_assembly-based-taxonomy" $JTrim _MEGAHIT &&
	   		./krona-blast_conda.sh $spades_contigs_improved $SampleName"_assembly-based-SPADES-KRONA-BLAST" $JTrim $SampleName
	   		./taxonomy_conda.sh $spades_contigs_improved $SampleName"_assembly-based-taxonomy" $JTrim  _SPADES &&
	   		./krona-blast_conda.sh $megahit_contigs_improved $SampleName"_assembly-based-MEGAHIT-KRONA-BLAST" $JTrim $SampleName
	   	}
}

clustering_func(){
	printf "Calling Clustering-based taxonomy task\n and using $JTrim threads"
	echo -e "$(date) Calling Clustering-based taxonomy task\n" >> $logfile 2>&1
		./clustering.sh $sequence_data $SampleName"_clustering-based" $JTrim $SampleName &&
		./taxonomy_conda.sh $OTUDB $SampleName"_clustering-based-taxonomy" $JTrim _OTU &&
		./krona-blast_conda.sh $OTUDB $SampleName"_clustering-based-KRONA-BLAST" $JTrim $SampleName
}

echo "Starting process..."

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
		./pre-process_conda.sh $R1 $R2 $SampleName $JTrim $METHOD
fi

##Check for reads-filtering task
case $filter in
  	("--filter")
  			if [ -f "$UnWanted" ]; then
				echo -e "$UnWanted file found, moving ahead \n" >> $logfile 2>&1
				echo -e "$UnWanted file found, moving ahead \n"
	  			max=$(($#-1)) ##Setting the current number of arguments
	  			sequence_data="readsNotrRNA_filtered.fq.gz" ##Setting the sequence name to be analyzed ---added .gz
	  			if [ ! -f "$sequence_data" ]; then
		  			echo "Calling reads-filtering task"
					echo -e "$(date) Calling reads-filtering task\n" >> $logfile 2>&1 ##;; ##add or remove ;; when when re-activate or deactivate the filtering step
					./reads-filtering.sh $DiamondDB $JTrim $InputDB $OutDiamondDB $PathToRefSeq $UnWanted
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
  			max=$# ##Setting the current number of arguments
  			sequence_data=$SampleName"_not_rRNA.fq.gz" # ---added .gz
  			echo "Filtering not activated, moving to next task";;
esac

##Start read-based taxonomy
##Statement of arguments
if [ $5 == 'ALL' ];
	then
		JTrim=$((JTrim/3))
		printf "Executing ALL (read-based, assembly-based and clustering-based) taxonomy processes \n"
		echo -e "$(date) Calling ALL (read-based, assembly-based and clustering-based) taxonomy tasks \n" >> $logfile #2>&

		##Call read-based taxonomy classification
		printf "Calling Read-based taxonomy task and using $JTrim threads"
		echo -e "$(date) Calling Read-based taxonomy task \n" >> $logfile 2>&1
		./taxonomy-gzip.sh $sequence_data $SampleName"_read-based-taxonomy" $JTrim _READ &
		PID_READ=$!

		##Call assembly-based taxonomy classification
		assembly_func &
		PID_ASS=$!

		##Call clustering-based taxonomy classification
		clustering_func &
		PID_CLUST=$!

		# Wait for all background jobs with error handling
		echo "Waiting for all three taxonomy methods to complete..."
		wait $PID_READ || { echo "ERROR: Read-based taxonomy failed"; exit 1; }
		echo "Read-based taxonomy completed successfully"
		wait $PID_ASS || { echo "ERROR: Assembly-based taxonomy failed"; exit 1; }
		echo "Assembly-based taxonomy completed successfully"
		wait $PID_CLUST || { echo "ERROR: Clustering-based taxonomy failed"; exit 1; }
		echo "Clustering-based taxonomy completed successfully"

	else
		i=1
		while (( $i < $max-3 ))
		do
			case $5 in
		  	("--read_based")
		    		printf "Executing Read-based taxonomy process \n"
		    		echo -e "$(date) Calling Read-based taxonomy task\n" >> $logfile 2>&1
		    		./taxonomy_conda.sh $sequence_data read-based-taxonomy $JTrim _READ
		    		seqkit fq2fa $sequence_data > readsToblastn.fasta
		    		./krona-blast_conda.sh readsToblastn.fasta $SampleName"_read-based-KRONA-BLAST" $JTrim $SampleName
		    		i=$((i + 1 ))
		    		shift 1;;
		    	("--ass_based")
		    		printf "Calling the Assembly-based function \n"
		    		echo -e "$(date) Calling the Assembly-based function \n" >> $logfile 2>&1
		    		assembly_func
		    		i=$((i + 1 ))
		    		shift 1;;
		    	("--clust_based")
		    		printf "Calling the Clustering-based function \n"
		    		echo -e "$(date) Calling the Clustering-based function \n" >> $logfile 2>&1
		    		clustering_func
		    		i=$((i + 1 ))
		    		shift 1;;
		    	(*)
		    		echo "One of the following option must be specified: ALL|[--read_based --ass_based --clust_based] "
		    		i=$((i + 1 ))
		    		shift 1;;
		    	esac
		done
fi

# Delete input files and save work

echo "Data transfer from scratch-ib to permanent storage using Infiniband"
rm -rf $R1
rm -rf $R2
rm *.sh
rm taxonomy.tab
rm concatenate_reads.py
# Note: BBDuk doesn't create persistent working directories like SortMeRNA

cd ..

# Transfer results back using san-ib for optimal performance
scp -r scripts/ san-ib:$PATH_TO_SAVE

# Delete scratch-ib
echo "Delete Scratch-IB"
rm -rf ${SCRATCH_DIRECTORY}
