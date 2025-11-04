#!/bin/bash

#Usage krona-blast.sh sequence.fasta KBDir NumbOfCores SampleName
#As an example: time ./krona-blast.sh readsNotrRNA_filtered.fq FKDL210225623 24 sample9
merged_seq=$1 		#readsNotrRNA_filtered.fasta
KBDir=$2		      #Krona-Blast folder
JTrim=$3		      #Number of cores to use
SampleName=$4

NumOfArgs=4
logfile=$KBDir"/krona-blast.log"

# Use databases from NAS if PIMGAVIR_DBS_DIR is set, otherwise use relative path (backward compatible)
PIMGAVIR_DBS_DIR="${PIMGAVIR_DBS_DIR:-../DBs}"

# NCBI viral RefSeq for blasn:
ref_viruses_rep_genomes="${PIMGAVIR_DBS_DIR}/NCBIRefSeq/ref_viruses_rep_genomes"

# Set BLASTDB environment variable for taxonomy lookup
# This prevents the warning: "Taxonomy name lookup from taxid requires installation of taxdb database"
export BLASTDB="${PIMGAVIR_DBS_DIR}/NCBIRefSeq"

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

# Check size of query file and skip BLAST if too large (reads are already analyzed by Kraken2/Kaiju)
QUERY_SIZE=$(stat -f%z "$merged_seq" 2>/dev/null || stat -c%s "$merged_seq" 2>/dev/null || echo 0)
QUERY_SIZE_GB=$(echo "scale=2; $QUERY_SIZE / 1024 / 1024 / 1024" | bc)
MAX_SIZE_GB=5  # Maximum query file size in GB before skipping BLAST

echo "Query file size: ${QUERY_SIZE_GB} GB"

if (( $(echo "$QUERY_SIZE_GB > $MAX_SIZE_GB" | bc -l) )); then
    echo "=========================================="
    echo "WARNING: Query file is very large (${QUERY_SIZE_GB} GB > ${MAX_SIZE_GB} GB)"
    echo "BLAST analysis will be SKIPPED for performance reasons"
    echo "=========================================="
    echo ""
    echo "Note: This is normal for large metagenomic datasets."
    echo "You still have complete taxonomic analysis from:"
    echo "  - Kraken2 (all reads analyzed)"
    echo "  - Kaiju (all reads analyzed)"
    echo "  - Krona visualizations from Kraken2/Kaiju"
    echo ""
    echo "BLAST is mainly useful for:"
    echo "  - Small datasets (< 5 GB)"
    echo "  - Assembled contigs (use --ass_based mode)"
    echo "  - Detailed species-level identification"
    echo ""
    echo "To force BLAST on large files (NOT recommended):"
    echo "  - Edit krona-blast_conda.sh"
    echo "  - Change MAX_SIZE_GB=5 to a higher value"
    echo "  - Ensure sufficient RAM (may require 512+ GB)"
    echo "=========================================="

    echo -e "$(date) BLAST SKIPPED: Query file too large (${QUERY_SIZE_GB} GB > ${MAX_SIZE_GB} GB)\n" >> $logfile 2>&1
    echo -e "$(date) Taxonomic analysis already complete via Kraken2/Kaiju\n" >> $logfile 2>&1

    # Create a summary file instead of running BLAST
    echo "BLAST analysis skipped due to large file size (${QUERY_SIZE_GB} GB)" > ${blast_out}
    echo "Complete taxonomic analysis available from Kraken2 and Kaiju results" >> ${blast_out}
    echo "For BLAST analysis, use assembly-based mode (--ass_based) which generates smaller contig files" >> ${blast_out}

    # Exit successfully without running BLAST
    echo "Krona-Blast analysis completed (BLAST skipped, Kraken2/Kaiju data available)"
    echo -e "$(date) Krona-Blast script completed (BLAST skipped)\n" >> $logfile 2>&1
    exit 0
fi

echo "1. RUNNING BLAST against viral RefSeq"
echo -e "$(date) Running BLAST against viral RefSeq with the following arguments: query is $merged_seq, database is $ref_viruses_rep_genomes, output is $blast_out" >> $logfile 2>&1

# Limit BLAST to 8 threads to reduce memory usage (regardless of available cores)
# BLAST memory usage scales with threads, especially on large query files
BLAST_THREADS=8
if [ $JTrim -lt 8 ]; then
    BLAST_THREADS=$JTrim
fi

echo "Using $BLAST_THREADS threads for BLAST (limited to reduce memory usage)"
echo -e "$(date) BLAST threads: $BLAST_THREADS (limited from $JTrim to reduce memory)\n" >> $logfile 2>&1

# Use conda blast (no module loading needed)
# Added -max_hsps 1 to reduce output size and memory usage
blastn -query $merged_seq -db $ref_viruses_rep_genomes -out $blast_out \
    -outfmt "6 qseqid sseqid pident length mismatch gapopen qstart qend sstart send evalue bitscore staxids sscinames" \
    -max_target_seqs 1 \
    -max_hsps 1 \
    -num_threads $BLAST_THREADS

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