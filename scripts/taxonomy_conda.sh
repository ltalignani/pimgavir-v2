##Taxonomy classification - Conda version
FilteredReads=$1        ##Path to the reads
OutDir=$2	              ##folder to store results
JTrim=$3	              ##Number of threads
Assembler=$4	          ##Assembler name where the contings come from

# Create report directory if it doesn't exist
mkdir -p report

logfile="report/taxonomy.log"

NumOfArgs=4

##Checking the number of arguments
if (( $# < $NumOfArgs ))
then
    printf "%b" "Error. Not enough arguments.\n" >&2
    printf "%b" "Usage taxonomy.sh reads_to_classify.fasta Out_Folder NumbOfCores assembler_name \n" >&2
    exit 1
elif (( $# > $NumOfArgs ))
then
    printf "%b" "Error. Too many arguments.\n" >&2
    printf "%b" "Usage taxonomy.sh reads_to_classify.fasta Out_Folder NumbOfCores assembler_name \n" >&2
    exit 2
else
    printf "%b" "Argument count correct. Continuing processing...\n"
fi

##Making folder "reads-based-taxonomy" for storing results
mkdir -p $OutDir

# Use databases from NAS if PIMGAVIR_DBS_DIR is set, otherwise use relative path (backward compatible)
PIMGAVIR_DBS_DIR="${PIMGAVIR_DBS_DIR:-../DBs}"

##Taxonomy classification with KRAKEN and RefSeq viral db
KrakenViralDB="${PIMGAVIR_DBS_DIR}/KrakenViral"
krakenViralOut=$OutDir"/krakViral.out"$Assembler
krakenViralClassified=$OutDir"/krakViral_class.out"$Assembler
krakenViralUnClassified=$OutDir"/krakViral_unclass.out"$Assembler
krakenViralReport=$OutDir"/krakViral_report.out"$Assembler

# Use conda-installed Krona tools (no hardcoded paths needed)
ktImportTaxonomy="ktImportTaxonomy"
ktImportText="ktImportText"

echo -e "$(date) Run taxonomy classification (Kraken/Viral RefSeq) with the following parameters: \n" >> $logfile 2>&1
echo -e "$(date) $KrakenViralDB $FilteredReads $krakenViralOut $krakenViralClassified $krakenViralUnClassified \n" >> $logfile 2>&1

# Use conda kraken2 (no module loading needed)
kraken2 --db $KrakenViralDB $FilteredReads --output $krakenViralOut --classified-out $krakenViralClassified --unclassified-out $krakenViralUnClassified --report $krakenViralReport --threads $JTrim || exit 20

echo -e "$(date) Create Krona reports in html format: \n" >> $logfile 2>&1
cat $krakenViralOut | cut -f 2,3 > $OutDir"/krakViral.krona"$Assembler
$ktImportTaxonomy $OutDir"/krakViral.krona"$Assembler -o $OutDir"/krakViral.krona"$Assembler".html" || exit 76

##Taxonomy classification with Kaiju and VIRUSES db
kaijuNodes="${PIMGAVIR_DBS_DIR}/kaiju/bin/kaijudb/nodes.dmp"
kaijuNames="${PIMGAVIR_DBS_DIR}/kaiju/bin/kaijudb/names.dmp"
kaijuDB="${PIMGAVIR_DBS_DIR}/kaiju/bin/kaijudb/viruses/kaiju_db_viruses.fmi"
kaijuOut=$OutDir"/reads_kaiju.out"$Assembler
kronaOut=$OutDir"/reads_kaiju.krona"$Assembler
kronaHTMLout=$OutDir"/reads_kaiju.krona"$Assembler".html"

echo -e "$(date) Run taxonomy classification (Kaiju/Viral RefSeq) with the following parameters: \n" >> $logfile 2>&1
echo -e "$(date) $kaijuNodes $kaijuNames $kaijuDB $FilteredReads $kaijuOut $kronaOut $kronaHTMLout \n" >> $logfile 2>&1

# Use conda kaiju (no module loading needed)
kaiju -t $kaijuNodes -f $kaijuDB -i $FilteredReads -o $kaijuOut -z $JTrim || exit 39

echo -e "$(date) Run KaijuToKrona task \n" >> $logfile 2>&1
kaiju2krona -t $kaijuNodes -n $kaijuNames -i $kaijuOut -o $kronaOut -u -v || exit 40
$ktImportText -o $kronaHTMLout $kronaOut

echo -e "$(date) Taxonomy classification completed \n" >> $logfile 2>&1