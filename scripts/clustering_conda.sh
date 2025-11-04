#!/bin/env bash

##Clustering - Conda version (no module loads, uses conda tools only)
#Usage clustering_conda.sh merged_sequences.fastq ClustDir NumbOfCores SampleName
#As an example: time ./clustering_conda.sh readsNotrRNA_filtered.fq clustering-based 24 sample9

merged_seq=$1 		#readsNotrRNA_filtered.fq
ClustDir=$2		    #Clustering folder
JTrim=$3		      #Number of cores to use
SampleName=$4
ConcScript="../../concatenate_reads.py"

##Versioning
version="PIMGAVir V.2.2 -- 04.11.2025 (Clustering - Conda Version)"

NumOfArgs=4

# Create report directory if it doesn't exist
mkdir -p report

logfile="report/clustering-based.log"
wd=$ClustDir"/"$merged_seq".split"

# Build log file
touch $logfile

#Build clustering directory
mkdir -p $ClustDir

##Checking the number of arguments
if (( $# < $NumOfArgs ))
then
    printf "%b" "Error. Not enough arguments.\n" >&2
    printf "%b" "clustering_conda.sh merged_sequences.fastq ClustDir NumbOfCores SampleName\n" >&2
    exit 1
elif (( $# > $NumOfArgs ))
then
    printf "%b" "Error. Too many arguments.\n" >&2
    printf "%b" "clustering_conda.sh merged_sequences.fastq ClustDir NumbOfCores SampleName\n" >&2
    exit 2
else
    printf "%b" "Argument count correct. Continuing processing...\n"
fi

echo "Starting clustering process using conda tools..."
echo -e "$(date) Starting clustering process (conda version)\n" > $logfile 2>&1

################################################################################
# 1. Split FASTQ into paired reads
################################################################################
echo "1. Splitting single FASTQ file into paired reads (seqkit)"
echo -e "$(date) Executing seqkit split2 with the following arguments: merged fastq file is $merged_seq" >> $logfile 2>&1

# Use conda seqkit (no module loading needed)
echo -e "$(date) Split single fastq file into 2 (seqkit split2)" >> $logfile 2>&1
seqkit split2 -p 2 $merged_seq -O $wd --force

################################################################################
# 2. Convert FASTQ to FASTA
################################################################################
echo "2. Converting FASTQ to FASTA (seqkit fq2fa)"
echo -e "$(date) Executing seqkit fq2fa with the following arguments: merged fastq file is $merged_seq" >> $logfile 2>&1

# Use conda seqkit (no module loading needed)
for f in $wd/* ; do seqkit fq2fa $f -o ${f%.*}.fasta; done;

################################################################################
# 3. Concatenate paired reads
################################################################################
echo "3. Concatenating paired reads (Python)"
echo -e "$(date) Executing concatenate_reads.py" >> $logfile 2>&1

cd $wd
mv *.part_001.fq.fasta Forward.fasta
mv *.part_002.fq.fasta Reverse.fasta
cp $ConcScript .
python3 concatenate_reads.py || exit 8

################################################################################
# 4. Combine files for single dereplication pass
################################################################################
echo "4. Combining FASTA files for single-pass dereplication"
echo -e "$(date) Combining FASTA files for single-pass dereplication" >> ../../$logfile 2>&1

# Performance optimization: Combine files first, THEN perform single dereplication
# This eliminates redundant dereplication passes (saves 15-40 minutes for large datasets)
cat *.fasta > Combined.fasta

################################################################################
# 5. Dereplication (VSEARCH)
################################################################################
echo "5. Performing single-pass dereplication on combined dataset (vsearch)"
echo -e "$(date) Perform single-pass dereplication on the full dataset (vsearch)" >> ../../$logfile 2>&1

# Use conda vsearch (no module loading needed)
# Single comprehensive dereplication (replaces previous double-dereplication)
vsearch --derep_fulllength Combined.fasta --output derep.fasta --sizeout --uc combined.uc --fasta_width 0 --threads $JTrim || exit 9

################################################################################
# 6. Pre-clustering (VSEARCH)
################################################################################
echo "6. Performing pre-clustering (vsearch)"
echo -e "$(date) Perform Pre-Clustering (vsearch)" >> ../../$logfile 2>&1

# Use conda vsearch (no module loading needed)
vsearch --cluster_size derep.fasta --id 0.95 --sizein --sizeout --fasta_width 0 --centroids preclustered.fasta --threads $JTrim || exit 91

################################################################################
# 7. Chimera filtering (VSEARCH)
################################################################################
echo "7. Performing chimera filter de novo (vsearch)"
echo -e "$(date) Perform Chimera Filter Denovo (vsearch)" >> ../../$logfile 2>&1

# Use conda vsearch (no module loading needed)
vsearch --uchime_denovo preclustered.fasta --sizein --sizeout --fasta_width 0 --nonchimeras nonchimeras.fasta || exit 91

# Memory optimization: Remove intermediate files to prevent memory pressure
rm -f preclustered.fasta

################################################################################
# 8. OTU clustering (VSEARCH)
################################################################################
echo "8. Performing OTU clustering and generating tables (vsearch)"
echo -e "$(date) Perform Cluster for OTUs, print biom tables and MSA (vsearch)" >> ../../$logfile 2>&1

# Use conda vsearch (no module loading needed)
# Cluster for OTUs and print biom tables
vsearch --cluster_size nonchimeras.fasta --id 0.95 --sizein --sizeout --fasta_width 0 --uc clustered.uc --relabel OTU_ --centroids otus.fasta --otutabout otutab.txt --biomout otu.biom --msaout MSA.fa --threads $JTrim || exit 91

# Memory optimization: Remove large intermediate files after use
rm -f derep.fasta nonchimeras.fasta Combined.fasta

################################################################################
# 9. Move output files
################################################################################
echo "9. Moving OTU FASTA file to parent folder"
echo -e "$(date) Move the OTUs fasta file to the up-folder" >> ../../$logfile 2>&1

# Move the OTUs FASTA file to the parent folder
mv otus.fasta ../

cd ../../

echo "Clustering process completed successfully!"
echo -e "$(date) Clustering process completed successfully\n" >> $logfile 2>&1
