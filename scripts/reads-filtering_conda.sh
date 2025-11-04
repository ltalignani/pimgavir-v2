#!/bin/bash

##Reads Filtering - Conda version (no module loads, uses conda tools only)
#Usage reads-filtering_conda.sh DiamondDB NumbOfCores InputDB OutputDB PathToRefSeq UnwantedTaxa
#As an example: time ./reads-filtering_conda.sh /path/to/diamond.dmnd 24 notrRNA.fq blastx.m8 /path/to/refseq unwanted.txt

DiamondDB=$1 		   #Path to diamond DB
JTrim=$2 		       #Number of threads
InputDB=$3		     #fastq file containing notrRNA reads
OutDiamondDB=$4		 #fastq file output from blasting diamond
PathToRefSeq=$5		 #Path to RefSeq DB
UnWanted=$6		     #Name of text file containing UNWANTED kingdom

##Versioning
version="PIMGAVir V.2.2 -- 04.11.2025 (Reads Filtering - Conda Version)"

# Create report directory if it doesn't exist
mkdir -p report

logfile="report/reads-filtering.log"

echo "Starting reads filtering process using conda tools..."
echo -e "$(date) Starting reads filtering (conda version)\n" > $logfile 2>&1

################################################################################
# 1. Run Diamond BLASTX against RefSeq protein DB
################################################################################
echo "Running Diamond BLASTX against RefSeq protein database"
echo -e "$(date) Run Diamond blastx for the fastq files against the RefSeq protein DB with the following parameters: $DiamondDB $JTrim $InputDB $OutDiamondDB $PathToRefSeq $UnWanted\n" >> $logfile 2>&1
echo -e "$(date) Run Diamond blastx for the fastq files against the RefSeq protein DB \n" >> $logfile 2>&1

# Use conda diamond (no module loading needed)
TMPDIR="/tmp"
diamond blastx \
                    -d $DiamondDB \
                    -p $JTrim \
                    -q $InputDB \
   		              -f 6 qseqid staxids bitscore sseqid pident length mismatch gapopen qstart qend sstart send evalue \
                    -o $OutDiamondDB \
                    -t $TMPDIR \
                    -c 4 \
		                -b 0.77 \
                    -k 1 \
                    -v \
                    --log || exit 10

################################################################################
# 2. Filter unwanted reads based on taxonomy
################################################################################
echo "Filtering unwanted reads based on taxonomy"
echo -e "$(date) Run Misaele_Filter_Param.sh with the following parameters: \n" >> $logfile 2>&1
echo -e "$(date) $OutDiamondDB $PathToRefSeq $UnWanted $InputDB \n" >> $logfile 2>&1

# Run filtering script
./Misaele_Filter_Param.sh $OutDiamondDB $PathToRefSeq $UnWanted $InputDB

echo "Reads filtering completed successfully!"
echo -e "$(date) Reads filtering completed successfully\n" >> $logfile 2>&1
