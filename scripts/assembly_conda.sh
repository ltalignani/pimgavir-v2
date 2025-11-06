#!/bin/env bash

##Assembly - Conda version (no module loads, uses conda tools only)
#Usage assembly_conda.sh merged_sequences.fastq SampleName NumbOfCores
#As an example: time ./assembly_conda.sh readsNotrRNA_filtered.fq assembly-based 24

merged_seq=$1 		#readsNotrRNA_filtered.fq.gz
AssDir=$2			#Assembly folder
JTrim=$3			#Number of cores to use

##Versioning
version="PIMGAVir V.2.2 -- 04.11.2025 (Assembly - Conda Version)"

NumOfArgs=3

# Create report directory if it doesn't exist
mkdir -p report

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
# Pilon adds .fasta automatically, so we use base name for pilon output
megahit_contigs_improved_base=$AssDir"/megahit_contigs_improved"
spades_contigs_improved_base=$AssDir"/spades_contigs_improved"
# Final files will have .fasta extension (added by Pilon)
megahit_contigs_improved=$AssDir"/megahit_contigs_improved.fasta"
spades_contigs_improved=$AssDir"/spades_contigs_improved.fasta"
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
mkdir -p $AssDir

##Checking the number of arguments
if (( $# < $NumOfArgs ))
then
    printf "%b" "Error. Not enough arguments.\n" >&2
    printf "%b" "assembly_conda.sh merged_sequences.fastq SampleName NumbOfCores\n" >&2
    exit 1
elif (( $# > $NumOfArgs ))
then
    printf "%b" "Error. Too many arguments.\n" >&2
    printf "%b" "assembly_conda.sh merged_sequences.fastq SampleName NumbOfCores\n" >&2
    exit 2
else
    printf "%b" "Argument count correct. Continuing processing...\n"
fi

echo "Starting assembly process using conda tools..."
echo -e "$(date) Starting assembly process (conda version)\n" > $logfile 2>&1

################################################################################
# 1. MEGAHIT Assembly
################################################################################
echo "1. Executing de-novo Assembly (MEGAHIT)"
echo -e "$(date) Executing de-novo assembly by MEGAHIT with the following arguments: merged fastq file is $merged_seq" >> $logfile 2>&1

# Use conda megahit (no module loading needed)
megahit -t $JTrim --read $merged_seq --k-list 21,41,61,81,99 --no-mercy --min-count 2 --out-dir $megahit_out || exit 50

################################################################################
# 2. SPAdes Assembly
################################################################################
echo "2. Executing de-novo Assembly (SPAdes)"
echo -e "$(date) Executing de-novo assembly by SPAdes with the following arguments: merged fastq file is $merged_seq" >> $logfile 2>&1

# Use conda seqkit (no module loading needed)
seqkit split2 -p2 $merged_seq --force || exit 55
cd $wd
mv *.part_001.* Forward.fq.gz
mv *.part_002.* Reverse.fq.gz

# Use conda metaspades (no module loading needed)
metaspades.py -t $JTrim -1 Forward.fq.gz -2 Reverse.fq.gz -o ../$spades_out || exit 59
cd ..

################################################################################
# 3. Assembly Polishing with Bowtie2, SAMtools, Pilon
################################################################################
echo "3. Fixing misassemblies (bowtie2/samtools/pilon)"
echo "Parameters: $megahit_out/final.contigs.fa $idx_bowtie/$megahit_contigs_idx"
echo -e "$(date) Fixing misassemblies (bowtie2/samtools/pilon)" >> $logfile 2>&1

# Use conda tools (no module loading needed)
# Create index files from contigs
mkdir -p $idx_bowtie
echo -e "$(date) Create index files from contigs [bowtie2-build] from MEGAHIT assembly" >> $logfile 2>&1
bowtie2-build $megahit_out/final.contigs.fa $idx_bowtie/$megahit_contigs_idx || exit 61
echo -e "$(date) Create index files from contigs [bowtie2-build] from SPAdes assembly" >> $logfile 2>&1
bowtie2-build $spades_out/contigs.fasta $idx_bowtie/$spades_contigs_idx || exit 61

# Create BAM file
echo -e "$(date) Create BAM file [bowtie2 -x] from MEGAHIT assembly" >> $logfile 2>&1
bowtie2 -x $idx_bowtie/$megahit_contigs_idx -1 $wd/Forward.fq.gz -2 $wd/Reverse.fq.gz -p $JTrim | samtools view -bS -o $megahit_contigs_bam -@ $JTrim || exit 65
echo -e "$(date) Create BAM file [bowtie2 -x] from SPAdes assembly" >> $logfile 2>&1
bowtie2 -x $idx_bowtie/$spades_contigs_idx -1 $wd/Forward.fq.gz -2 $wd/Reverse.fq.gz -p $JTrim | samtools view -bS -o $spades_contigs_bam -@ $JTrim || exit 65

# Sort BAM files
echo -e "$(date) Sort BAM file [samtools sort] from MEGAHIT assembly" >> $logfile 2>&1
samtools sort $megahit_contigs_bam -o $megahit_contigs_sorted_bam -@ $JTrim || exit 66
echo -e "$(date) Sort BAM file [samtools sort] from SPAdes assembly" >> $logfile 2>&1
samtools sort $spades_contigs_bam -o $spades_contigs_sorted_bam -@ $JTrim || exit 66

# Index BAM files
echo -e "$(date) Indexing BAM file [samtools index] from MEGAHIT assembly" >> $logfile 2>&1
samtools index $megahit_contigs_sorted_bam -@ $JTrim || exit 66
echo -e "$(date) Indexing BAM file [samtools index] from SPAdes assembly" >> $logfile 2>&1
samtools index $spades_contigs_sorted_bam -@ $JTrim || exit 66

# Improve contigs with Pilo-$:
# Note: Pilon adds .fasta extension automatically to output
echo -e "$(date) Improve contigs file [pilon] from MEGAHIT contigs" >> $logfile 2>&1
# Allocate more memory to Java for Pilon (50% of available memory, min 8GB, max 64GB)
export _JAVA_OPTIONS="-Xmx128g"
pilon --genome $megahit_out/final.contigs.fa --frags $megahit_contigs_sorted_bam --output $megahit_contigs_improved_base --threads $JTrim || exit 78
echo -e "$(date) Improve contigs file [pilon] from SPAdes contigs" >> $logfile 2>&1
pilon --genome $spades_out/contigs.fasta --frags $spades_contigs_sorted_bam --output $spades_contigs_improved_base --threads $JTrim || exit 79
unset _JAVA_OPTIONS

################################################################################
# 4. Assembly Quality Assessment with QUAST
################################################################################
echo "4. Executing contigs analysis (QUAST)"
echo -e "$(date) Running QUAST quality assessment on assemblies" >> $logfile 2>&1

# Use conda quast (no module loading needed)
quast.py -o $megahit_quast $megahit_contigs_improved || exit 84
quast.py -o $spades_quast $spades_contigs_improved || exit 85

################################################################################
# 5. Gene Annotation with Prokka
################################################################################
echo "5. Gene annotation using Prokka"
echo -e "$(date) Gene annotation using Prokka" >> $logfile 2>&1

echo "Which perl version is currently running?"
which perl
perl --version

# Use conda prokka (no module loading needed)
# Gene annotation on SPAdes contigs
echo -e "$(date) Gene annotation: Using Prokka, Viruses genus on Contigs from SPAdes" >> $logfile 2>&1
prokka $spades_contigs_improved --usegenus Viruses --out $spades_prokka --centre X --compliant --prefix spades_prokka --force --cpus $JTrim || exit 91

# Gene annotation on MEGAHIT contigs
echo -e "$(date) Gene annotation: Using Prokka, Viruses genus on Contigs from MEGAHIT" >> $logfile 2>&1
prokka $megahit_contigs_improved --usegenus Viruses --out $megahit_prokka --prefix megahit_prokka --force --cpus $JTrim || exit 92

echo "Assembly and annotation completed successfully!"
echo "Use artemis to visualize the gene annotation. For example: art $megahit_prokka/$megahit_prokka.gbk"
echo -e "$(date) Assembly and annotation completed successfully\n" >> $logfile 2>&1
