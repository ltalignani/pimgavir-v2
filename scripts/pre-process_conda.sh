#!/bin/bash

#Usage pre-process.sh R1.fastq.gz R2.fastq.gz SampleName NumbOfCores
#As an example: time ./pre-process.sh sample9_1.fastq.gz sample9_2.fastq.gz sample9 24 --read_based
R1=$1 		      #R1.fastq.gz
R2=$2 		      #R2.fastq.gz
SampleName=$3	  #Name associated to the sample
JTrim=$4	      #Number of cores to use
METHOD=$5

NumOfArgs=5	#At least 5 parameters are needed
Trimgalore="report/trim-galore.log"
logfile="report/pre-process.log"
refSLR138="../DBs/SILVA/SILVA.138.1.LSU.fasta" # slr138.fasta
refSSR138="../DBs/SILVA/SILVA.138.1.SSU.fasta" #ssr138.fasta

echo "Starting the pre-process task with the following arguments: $R1 $R2 $SampleName $JTrim"

# No need to load modules - using conda environment
echo "Using conda environment tools (no module loading required)"

echo "1. Executing Trimgalore"
##Remove adapters using TrimGalore
echo -e "$(date) Executing pimgavir with the following arguments: R1 is $R1, R2 is $R2" > $logfile 2>&1
echo -e "$(date) Removing adapters using Trim Galore using 8 cores\n" >> $logfile 2>&1

#Command to execute
trim_galore -j 8 --length 80 --paired $R1 $R2 -q 30 --fastqc > $Trimgalore 2>&1
echo -e "$(date) Trim Galore session finished \n" >> $logfile 2>&1

scp -r *val_*fq.gz "/projects/large/PIMGAVIR/"${SLURM_JOB_ID}"_"${SampleName}"_"${METHOD#--}
scp -r *_trimming_report.txt  "/projects/large/PIMGAVIR/"${SLURM_JOB_ID}"_"${SampleName}"_"${METHOD#--}
scp -r *.html "/projects/large/PIMGAVIR/"${SLURM_JOB_ID}"_"${SampleName}"_"${METHOD#--}
scp -r *.zip "/projects/large/PIMGAVIR/"${SLURM_JOB_ID}"_"${SampleName}"_"${METHOD#--}

##Rename files
echo -e "$(date) Remaming files \n" >> $logfile 2>&1
trimmedR1=$SampleName"_R1_trimmed.fq.gz"
trimmedR2=$SampleName"_R2_trimmed.fq.gz"

#Command to execute:
if [[ "$R1" == "*.fq.gz" ]]; then
	mv `basename $R1 .fq.gz`_val_1.fq.gz $trimmedR1
	mv `basename $R2 .fq.gz`_val_2.fq.gz $trimmedR2
else
	mv `basename $R1 .fastq.gz`_val_1.fq.gz $trimmedR1
	mv `basename $R2 .fastq.gz`_val_2.fq.gz $trimmedR2
fi

echo "2. Executing BBDuk for rRNA removal"

##Remove ribosomal RNA using BBDuk -- faster and more efficient than SortMeRNA
echo -e "$(date) Remove ribosomal RNA using BBDuk \n" >> $logfile 2>&1
NotrRNAReads1=$SampleName"_not_rRNA_1.fq"
NotrRNAReads2=$SampleName"_not_rRNA_2.fq"
rRNAReads1=$SampleName"_rRNA_1.fq"
rRNAReads2=$SampleName"_rRNA_2.fq"
statsFile=$SampleName"_rrna_stats.txt"

#Command to execute
echo -e "$(date) Running BBDuk \n" >> $logfile 2>&1
echo "Removing ribosomal RNA using bbduk with the following parameters: bbduk.sh in=$trimmedR1 in2=$trimmedR2 ref=$refSLR138,$refSSR138 out=$NotrRNAReads1 out2=$NotrRNAReads2 outm=$rRNAReads1 outm2=$rRNAReads2 stats=$statsFile threads=$JTrim k=43"

bbduk.sh in=$trimmedR1 in2=$trimmedR2 ref=$refSLR138,$refSSR138 out=$NotrRNAReads1 out2=$NotrRNAReads2 outm=$rRNAReads1 outm2=$rRNAReads2 stats=$statsFile threads=$JTrim k=43 >> $logfile 2>&1

echo -e "$(date) Concatenating non-rRNA reads \n" >> $logfile 2>&1

##Concatenate paired reads into single file for downstream processing (maintaining compatibility)
NotrRNAReads=$SampleName"_not_rRNA.fq"
cat $NotrRNAReads1 $NotrRNAReads2 > $NotrRNAReads

##Compress the concatenated file to maintain compatibility with rest of pipeline
gzip $NotrRNAReads