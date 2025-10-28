#!/bin/bash

#Usage krona-blast.sh sequence.fasta KBDir NumbOfCores SampleName
#As an example: time ./krona-blast.sh readsNotrRNA_filtered.fq FKDL210225623 24 sample9
merged_seq=$1 		#readsNotrRNA_filtered.fasta
KBDir=$2		      #Krona-Blast folder
JTrim=$3		      #Number of cores to use
SampleName=$4

NumOfArgs=4
logfile=$KBDir"/krona-blast.log"

# NCBI viral RefSeq for blasn:
ref_viruses_rep_genomes="../DBs/NCBIRefSeq/ref_viruses_rep_genomes"

# Set BLASTDB environment variable for taxonomy lookup
# This prevents the warning: "Taxonomy name lookup from taxid requires installation of taxdb database"
export BLASTDB="../DBs/NCBIRefSeq"

blast_out=$KBDir"/"$SampleName"_blastn.out"
krona_tax_list=$KBDir"/"$SampleName"_krona_tax.lst"
krona_out=$KBDir"/"$SampleName"_krona_out.html"
krona_stdout=$KBDir"/"$SampleName"_krona_stdout"
krona_stderr=$KBDir"/"$SampleName"_krona_stderr"

##Checking the number of arguments
if (( $# < $NumOfArgs ))
then
    printf "%b" "Error. Not enough arguments.\n" >&2
    printf "%b" "krona-blast.sh sequences.fasta KBDir NumbOfCores SampleName\n" >&2
    exit 1
elif (( $# > $NumOfArgs ))
then
    printf "%b" "Error. Too many arguments.\n" >&2
    printf "%b" "krona-blast.sh sequences.fasta KBDir NumbOfCores SampleName\n" >&2
    exit 2
else
    printf "%b" "Argument count correct. Continuing processing...\n"
fi

# Check if taxdb is installed
if [ ! -f "$BLASTDB/taxdb.bti" ] || [ ! -f "$BLASTDB/taxdb.btd" ]; then
    echo "WARNING: BLAST taxonomy database (taxdb) not found in $BLASTDB"
    echo "BLAST will not be able to resolve taxonomy names from taxids."
    echo ""
    echo "To install taxdb, run:"
    echo "  cd scripts/"
    echo "  ./setup_blast_taxdb.sh"
    echo ""
    echo "Continuing anyway (taxid numbers will still be available)..."
fi

##Making folder for storing results
mkdir -p $KBDir

echo "Starting Krona-Blast analysis..."
echo -e "$(date) Starting Krona-Blast analysis with conda tools \n" >> $logfile 2>&1

echo "1. RUNNING BLAST against viral RefSeq"
echo -e "$(date) Running BLAST against viral RefSeq with the following arguments: query is $merged_seq, database is $ref_viruses_rep_genomes, output is $blast_out" >> $logfile 2>&1

# Use conda blast (no module loading needed)
blastn -query $merged_seq -db $ref_viruses_rep_genomes -out $blast_out -outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore staxids sscinames" -max_target_seqs 1 -num_threads $JTrim

echo "2. EXTRACT NCBI taxon IDs from BLAST output"
echo -e "$(date) Extract NCBI taxon IDs from BLAST output with the following arguments: blast out file is $blast_out , krona tax list file is $krona_tax_list" >> $logfile 2>&1

# Extract taxonomy information for Krona
awk 'BEGIN{FS=OFS="\t"} {print $1, $13}' $blast_out > ${krona_tax_list}

echo "3. CREATE Krona plot"
echo -e "$(date) Create Krona plot with the following arguments: krona out file is $krona_out" >> $logfile 2>&1

## Create Krona plot using conda-installed ktImportTaxonomy
ktImportTaxonomy -o ${krona_out} ${krona_tax_list} 1> ${krona_stdout} 2> ${krona_stderr}

if [ $? -eq 0 ]; then
    echo "Krona plot created successfully: ${krona_out}"
    echo -e "$(date) Krona plot created successfully: ${krona_out} \n" >> $logfile 2>&1
else
    echo "Error creating Krona plot. Check ${krona_stderr} for details."
    echo -e "$(date) Error creating Krona plot. Check ${krona_stderr} for details. \n" >> $logfile 2>&1
fi

echo "Blastn and Krona plot analysis completed"