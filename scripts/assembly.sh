#!/bin/env bash

#Usage clustering.sh merged_sequences.fastq SampleName NumbOfCores
#As an example: time ./assembly.sh readsNotrRNA_filtered.fq FKDL210225623 24

merged_seq=$1 		#readsNotrRNA_filtered.fq.gz
AssDir=$2					#Assembly folder
JTrim=$3					#Number of cores to use
ConcScript="/usr/share/NGS-PKGs/Concatenate/concatenate_reads.py" # This variable is not used

## Load Blast 2.8.1+
echo "Load Blast 2.8.1"
module load blast/2.8.1+

##Versioning
version="PIMGAVir V.1.1 -- 07.03.2022"

NumOfArgs=3
logfile="report/assembly-based.log"
wd=$merged_seq".split"
megahit_out=$AssDir"/megahit_data"
megahit_quast=$AssDir"/megahit_quast"
spades_out=$AssDir"/spades_data"
spades_quast=$AssDir"/spades_quast"

idx_bowtie=$AssDir"/IDXs"
megahit_contigs_idx="megahit_contigs_idx"
megahit_contigs_bam=$AssDir"/megahit_contigs.bam"
spades_contigs_idx="spades_contigs_idx"
spades_contigs_bam=$AssDir"/spades_contigs.bam"
megahit_contigs_sorted_bam=$AssDir"/megahit_contigs.sorted.bam"
spades_contigs_sorted_bam=$AssDir"/spades_contigs.sorted.bam"
megahit_contigs_improved=$AssDir"/megahit_contigs_improved"
spades_contigs_improved=$AssDir"/spades_contigs_improved"
spades_prokka=$AssDir"/spades_prokka"
megahit_prokka=$AssDir"/megahit_prokka"


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

#Build assembly-dir
mkdir $AssDir

##Checking the number of arguments
if (( $# < $NumOfArgs ))
then
    printf "%b" "Error. Not enough arguments.\n" >&2
    printf "%b" "assembly.sh merged_sequences.fastq SampleName NumbOfCores\n" >&2
    exit 1
elif (( $# > $NumOfArgs ))
then
    printf "%b" "Error. Too many arguments.\n" >&2
    printf "%b" "assembly.sh merged_sequences.fastq SampleName NumbOfCores c\n" >&2
    exit 2
else
    printf "%b" "Argument count correct. Continuing processing...\n"
fi

echo "Starting process..."

echo "1. Load MEGAHIT de-novo assembly program"
module load MEGAHIT/1.2.9

echo "2. Executing de-novo Assembly (megahit)"
echo -e "$(date) Executing de-novo assembly by megahit with the following arguments: merged fastq file is $merged_seq" > $logfile 2>&1

#Command to execute
#Assembly using Megahit
megahit -t $JTrim --read $merged_seq --k-list 21,41,61,81,99 --no-mercy --min-count 2 --out-dir $megahit_out || exit 50

module unload MEGAHIT/1.2.9

echo "3. Load SPADES de-novo Assembly program"
module load seqkit/2.1.0
module load SPAdes/3.15.3

echo "4. Executing de-novo Assembly (spades)"
echo -e "$(date) Executing de-novo assembly by spades with the following arguments: merged fastq file is $merged_seq" >> $logfile 2>&1
#Command to execute
#Assembly using Spades
seqkit split2 -p2 $merged_seq --force || exit 55
cd $wd
mv *.part_001.* Forward.fq.gz
mv *.part_002.* Reverse.fq.gz

metaspades.py -t $JTrim -1 Forward.fq.gz -2 Reverse.fq.gz  -o ../$spades_out || exit 59
cd ..

module unload seqkit/2.1.0
module unload SPAdes/3.15.3

echo "5. Fixing misassemblies (bowtie/samtools/pilon)"
echo "Parameters: $megahit_out/final.contigs.fa $idx_bowtie/$megahit_contigs_idx"
echo -e "$(date) Fixing misassemblies (bowtie/samtools/pilon)" >> $logfile 2>&1
#Command to execute

echo "5.1. Load bowtie2, samtools and pilon"

module load bowtie2/2.3.4.1
module load samtools/1.10
#module load pilon/1.23

#Create index files from contigs
mkdir $idx_bowtie
echo -e "$(date) Create index files from contigs [bowtie2-build] from megahit assembly" >> $logfile 2>&1
bowtie2-build $megahit_out/final.contigs.fa $idx_bowtie/$megahit_contigs_idx || exit 61
echo -e "$(date) Create index files from contigs [bowtie2-build] from spades assembly" >> $logfile 2>&1
bowtie2-build $spades_out/contigs.fasta $idx_bowtie/$spades_contigs_idx || exit 61

#Create BAM file
echo -e "$(date) Create bam file [bowtie2 -x] from megahit assembly" >> $logfile 2>&1
bowtie2 -x $idx_bowtie/$megahit_contigs_idx -1 $wd/Forward.fq.gz -2 $wd/Reverse.fq.gz -p $JTrim | samtools view -bS -o $megahit_contigs_bam -@ $JTrim || exit 65
echo -e "$(date) Create bam file [bowtie2 -x] from spades assembly" >> $logfile 2>&1
bowtie2 -x $idx_bowtie/$spades_contigs_idx -1 $wd/Forward.fq.gz -2 $wd/Reverse.fq.gz -p $JTrim | samtools view -bS -o $spades_contigs_bam -@ $JTrim || exit 65

#Sort bam files
echo -e "$(date) Sort bam file [samtools sort] from megahit assembly" >> $logfile 2>&1
samtools sort $megahit_contigs_bam -o $megahit_contigs_sorted_bam -@ $JTrim || exit 66
echo -e "$(date) Sort bam file [samtools sort] from spades assembly" >> $logfile 2>&1
samtools sort $spades_contigs_bam -o $spades_contigs_sorted_bam -@ $JTrim || exit 66

#Index bam files
#NB: in case of ERROR --> maybe files created with $JTrim cause troubles
echo -e "$(date) Indexing bam file [samtools index] from megahit assembly" >> $logfile 2>&1
samtools index $megahit_contigs_sorted_bam -@ $JTrim || exit 66
echo -e "$(date) Indexing bam file [samtools index] from spades assembly" >> $logfile 2>&1
samtools index $spades_contigs_sorted_bam -@ $JTrim || exit 66

#Improve contigs.fasta
echo -e "$(date) Improve contigs file [pilon] from megahit contigs" >> $logfile 2>&1
pilon --genome $megahit_out/final.contigs.fa --frags $megahit_contigs_sorted_bam --output $megahit_contigs_improved --threads $JTrim || exit 78
echo -e "$(date) Improve contigs file [pilon] from spades contigs" >> $logfile 2>&1
pilon --genome $spades_out/contigs.fasta --frags $spades_contigs_sorted_bam --output $spades_contigs_improved --threads $JTrim || exit 79

module unload bowtie2/2.3.4.1
module unload samtools/1.10
#module unload pilon/1.23

echo "6. Executing contigs analysis (quast)"
echo "6.1. Load Quast module"
module load quast/5.2.0

echo -e "$(date) Executing de-novo assembly by spades with the following arguments: merged fastq file is $merged_seq" >> $logfile 2>&1
#Command to execute
#Using QUAST
quast.py -o $megahit_quast $megahit_contigs_improved".fasta" || exit 84
quast.py -o $spades_quast $spades_contigs_improved".fasta" || exit 85

module unload quast/5.2.0

echo "7. Gene annotation using PROKKA"
echo -e "$(date) Gene annotation using PROKKA" >> $logfile 2>&1

echo "which perl version is currently running?"
which perl
perl --version

##  Load Perl 5.24 module
#echo "load Perl 5.24 module"
#module unload perl/5.16.3
#module load perl/5.24.0
## Unload Python 3.8.12 module
echo "unload python 3.8.12"
module unload python/3.8.12
echo "Done."

## Unload Wrong prokka module
#echo "Unload Prokka 1.14.6 - use 1.13 instead"
#module unload prokka/1.14.6
echo "Load prokka 1.14.6"
module load prokka/1.14.6

#Gene annotation
#Using PROKKA, Viruses genus on Contigs from spades
echo -e "$(date) Gene annotation: Using PROKKA, Viruses genus on Contigs from spades" >> $logfile 2>&1
prokka $spades_contigs_improved".fasta" --usegenus Viruses --out $spades_prokka --centre X --compliant --prefix spades_prokka --force --cpus $JTrim || exit 91

#Using PROKKA, Viruses genus on Contigs from megahit
echo -e "$(date) Gene annotation: Using PROKKA, Viruses genus on Contigs from megahit" >> $logfile 2>&1
prokka $megahit_contigs_improved".fasta" --usegenus Viruses --out $megahit_prokka --prefix megahit_prokka --force --cpus $JTrim || exit 92

echo "Use artemis to visualize the Gene annotation. For example art $megahit_prokka.gbk"

module unload prokka/1.14.6
module unload blast/2.8.1+
