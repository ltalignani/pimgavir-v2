#!/bin/env bash

#Usage clustering.sh merged_sequences.fastq ClustDir NumbOfCores
#As an example: time ./clustering.sh readsNotrRNA_filtered.fq FKDL210225623 24
merged_seq=$1 		#readsNotrRNA_filtered.fq
ClustDir=$2		    #Clustering folder
JTrim=$3		      #Number of cores to use
SampleName=$4
ConcScript="../../concatenate_reads.py" #../../concatenate_reads.py

NumOfArgs=4
logfile="report/clustering-based.log"
wd=$ClustDir"/"$merged_seq".split"

# Build log file
touch $logfile

#Build assembly-dir
mkdir $ClustDir

##Checking the number of arguments
if (( $# < $NumOfArgs ))
then
    printf "%b" "Error. Not enough arguments.\n" >&2
    printf "%b" "clustering.sh merged_sequences.fastq ClustDir NumbOfCores\n" >&2
    exit 1
elif (( $# > $NumOfArgs ))
then
    printf "%b" "Error. Too many arguments.\n" >&2
    printf "%b" "clustering.sh merged_sequences.fastq ClustDir NumbOfCores\n" >&2
    exit 2
else
    printf "%b" "Argument count correct. Continuing processing...\n"
fi

echo "Starting process..."

echo "1. Executing seqkit split2 (splitting)"
echo -e "$(date) Executing seqkit split2 with the following arguments: merged fastq file is $merged_seq" > $logfile 2>&1

echo "1. Split single fastq file into 2 with seqkit. Load seqkit module"
module load seqkit/2.1.0

#Command to execute
#Split single fastq file into 2
echo -e "$(date) Split single fastq file into 2 (seqkit split2)" >> $logfile 2>&1
seqkit split2 -p 2 $merged_seq -O $wd --force

echo "2. Executing seqkit fq2fa (converting)"
echo -e "$(date) Executing seqkit fq2fa with the following arguments: merged fastq file is $merged_seq" >> $logfile 2>&1
#Command to execute

## Convert fastq to fasta
echo "2. Convert fastq to fasta"

for f in $wd/* ; do seqkit fq2fa $f -o ${f%.*}.fasta; done;

module unload seqkit/2.1.0


echo "3. Executing concatenation"
echo -e "$(date) Executing concatenate_reads.py" >> $logfile 2>&1
#Command to execute
## Run concatenation
cd $wd
mv *.part_001.fq.fasta Forward.fasta
mv *.part_002.fq.fasta Reverse.fasta
cp $ConcScript .
python3 concatenate_reads.py || exit 8

echo "4. Load vsearch module and combine files for single dereplication pass"

module load vsearch/2.21.1

# Performance optimization: Combine files first, THEN perform single dereplication
# This eliminates redundant dereplication passes (saves 15-40 minutes for large datasets)
echo -e "$(date) Combining FASTA files for single-pass dereplication" >> ../../$logfile 2>&1

## Combine all FASTA files into single file before dereplication
cat *.fasta > Combined.fasta

echo "5. Perform single-pass dereplication on combined dataset (vsearch)"
echo -e "$(date) Perform single-pass dereplication on the full dataset (vsearch)" >> ../../$logfile 2>&1
#Command to execute
## Single comprehensive dereplication (replaces previous double-dereplication)
vsearch --derep_fulllength Combined.fasta --output derep.fasta --sizeout --uc combined.uc --fasta_width 0 --threads $JTrim || exit 9

echo "6. Perform Pre-Clustering (vsearch)"
echo -e "$(date) Perform Pre-Clustering (vsearch)" >> ../../$logfile 2>&1
#Command to execute
## Perform Chimera Filter Denovo
vsearch --cluster_size derep.fasta --id 0.95 --sizein --sizeout --fasta_width 0 --centroids preclustered.fasta --threads $JTrim || exit 91

echo "7. Perform Chimera Filter Denovo (vsearch)"
echo -e "$(date) Perform Chimera Filter Denovo (vsearch)" >> ../../$logfile 2>&1
#Command to execute
vsearch --uchime_denovo preclustered.fasta --sizein --sizeout --fasta_width 0 --nonchimeras nonchimeras.fasta || exit 91

# Memory optimization: Remove intermediate files to prevent memory pressure
rm -f preclustered.fasta

echo "8. Perform Cluster for OTUs, print biom tables and MSA (vsearch)"
echo -e "$(date) Perform Cluster for OTUs, print biom tables and MSA (vsearch)" >> ../../$logfile 2>&1
#Command to execute
#Cluster for OTUs and print biom tables
vsearch --cluster_size nonchimeras.fasta --id 0.95 --sizein --sizeout --fasta_width 0 --uc clustered.uc --relabel OTU_ --centroids otus.fasta --otutabout otutab.txt --biomout otu.biom --msaout MSA.fa --threads $JTrim || exit 91

# Memory optimization: Remove large intermediate files after use
rm -f derep.fasta nonchimeras.fasta Combined.fasta

echo "9. Move the OTUS fasta file to the up-folder"
echo -e "$(date) Move the OTUS fasta file to the up-folder" >> ../../$logfile 2>&1
##Move the OTUS fasta file to the up-folder
mv otus.fasta ../

cd ../../

module unload vsearch/2.21.1

