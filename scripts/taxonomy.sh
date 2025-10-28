##Taxonomy classification
FilteredReads=$1        ##Path to the reads
OutDir=$2	              ##folder to store results
JTrim=$3	              ##Number of threads
Assembler=$4	          ##Assembler name where the contings come from
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
mkdir $OutDir

##Taxonomy classification with KRAKEN and RefSeq viral db
KrakenViralDB="../DBs/KrakenViral"
krakenViralOut=$OutDir"/krakViral.out"$Assembler
krakenViralClassified=$OutDir"/krakViral_class.out"$Assembler
krakenViralUnClassified=$OutDir"/krakViral_unclass.out"$Assembler
krakenViralReport=$OutDir"/krakViral_report.out"$Assembler

# Dynamic Krona tool detection (prevents path-related failures)
if command -v ktImportTaxonomy &> /dev/null; then
    ktImportTaxonomy="ktImportTaxonomy"
    ktImportText="ktImportText"
elif [ -f "${HOME}/miniconda3/envs/pimgavir_complete/bin/ktImportTaxonomy" ]; then
    ktImportTaxonomy="${HOME}/miniconda3/envs/pimgavir_complete/bin/ktImportTaxonomy"
    ktImportText="${HOME}/miniconda3/envs/pimgavir_complete/bin/ktImportText"
elif [ -f "${HOME}/miniconda3/envs/pimgavir/bin/ktImportTaxonomy" ]; then
    ktImportTaxonomy="${HOME}/miniconda3/envs/pimgavir/bin/ktImportTaxonomy"
    ktImportText="${HOME}/miniconda3/envs/pimgavir/bin/ktImportText"
else
    echo "ERROR: ktImportTaxonomy not found in PATH or expected conda environments"
    exit 1
fi

echo -e "$(date) Run taxonomy classification (Kraken/Viral RefSeq) with the following parameters: \n" >> $logfile 2>&1
echo -e "$(date) $KrakenViralDB $FilteredReads $krakenViralOut $krakenViralClassified $krakenViralUnClassified \n" >> $logfile 2>&1

module load kraken2/2.1.1

kraken2 --db $KrakenViralDB $FilteredReads --output $krakenViralOut --classified-out $krakenViralClassified --unclassified-out $krakenViralUnClassified --report $krakenViralReport --threads $JTrim || exit 20

module unload kraken2/2.1.1

echo -e "$(date) Create Krona reports in html format: \n" >> $logfile 2>&1
cat $krakenViralOut | cut -f 2,3 > $OutDir"/krakViral.krona"$Assembler
$ktImportTaxonomy $OutDir"/krakViral.krona"$Assembler -o $OutDir"/krakViral.krona"$Assembler".html" || exit 76

##Taxonomy classification with Kaiju and VIRUSES db
kaijuNodes="../DBs/kaiju/bin/kaijudb/nodes.dmp"
kaijuNames="../DBs/kaiju/bin/kaijudb/names.dmp"
kaijuDB="../DBs/kaiju/bin/kaijudb/viruses/kaiju_db_viruses.fmi"
kaijuOut=$OutDir"/readskaiju.out"$Assembler
kronaOut=$OutDir"/reads_kaiju.krona"$Assembler
kronaHTMLout=$OutDir"/reads_kaiju.krona"$Assembler".html"

echo -e "$(date) Run taxonomy classification (Kaiju/Viruses) with the following parameters: \n" >> $logfile 2>&1
echo -e "$(date) $kaijuNodes $kaijuNames $kaijuDB $FilteredReads $kaijuOut $kronaOut $kronaHTMLout \n" >> $logfile 2>&1

module load kaiju/1.8.0

kaiju -t $kaijuNodes -f $kaijuDB -i $FilteredReads -o $kaijuOut || exit 30

echo -e "$(date) Run KaijuToKrona task \n" >> $logfile 2>&1
kaiju2krona -t $kaijuNodes -n $kaijuNames -i $kaijuOut -o $kronaOut -u -v || exit 40
$ktImportText -o $kronaHTMLout $kronaOut

module unload kaiju/1.8.0

