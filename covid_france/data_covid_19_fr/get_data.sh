## RAW DATA
## Source https://github.com/opencovid19-fr/
## Source https://www.data.gouv.fr/fr/datasets/donnees-hospitalieres-relatives-a-lepidemie-de-covid-19/

# Get Source CSV file
mkdir -p csv
cd csv
rm france*.csv*
wget https://www.data.gouv.fr/fr/datasets/r/63352e38-d353-4b54-bfd1-f1b3ee1cabd7 -O france.csv

# Replace column name
sed -i 's/"dep";"sexe";"jour";"hosp";"rea";"rad";"dc"/"maille_code";"sexe";"date";"hospitalises";"reanimation";"gueris";"deces"/' france.csv

# Get first line
HEADER=$(head -n 1 france.csv)

# Data type
CSVT="String,Integer,Date,Integer,Integer,Integer,Integer"
echo $CSVT > "france.csvt"

# Keep only data for male and female
sed -i '/;1;"202[01]/d' france.csv
sed -i '/;2;"202[01]/d' france.csv
sed -i '/;"1";"202[01]/d' france.csv
sed -i '/;"2";"202[01]/d' france.csv

# Remove data before march
# sed -i -E "/2020-0[12]-.+/d" france.csv

# Get last available date
LASTLINE=$(grep "." france.csv | tail -1)
LASTDATE=${LASTLINE:11:10}
echo "Last date: $LASTDATE"

# Add header
#sed -i "1s/^/$HEADER\n/" "france_$SUF.csv"

# last data
if true;
then
        echo "Get data only for $LASTDATE"
        echo "france_last.csv"
        grep $LASTDATE "france.csv" > "france_last.csv"

        # Add header
        sed -i "1s/^/$HEADER\n/" "france_last.csv"
        echo $CSVT > "france_last.csvt"
fi

## SPATIAL DATA
## Source https://github.com/gregoiredavid/france-geojson
# Do it once only
if false; then
        cd ..
        mkdir -p geojson
        cd geojson
        rm *.geojson
        wget "https://github.com/gregoiredavid/france-geojson/raw/master/departements-avec-outre-mer.geojson" -O departements.geojson
        wget "https://github.com/gregoiredavid/france-geojson/raw/master/regions-avec-outre-mer.geojson" -O regions.geojson
fi

## Create GPKG
cd ..
rm -f france.gpkg
ogr2ogr -f GPKG france.gpkg csv/
ogr2ogr -append -f GPKG france.gpkg geojson/regions.geojson
ogr2ogr -append -f GPKG france.gpkg geojson/departements.geojson
