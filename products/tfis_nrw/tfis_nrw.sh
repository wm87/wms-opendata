#!/bin/bash
set -e

export DBNAME="tfis_nrw"
export PGUSER="postgres"
export PGPORT=5432

insertdatum=$(date +%Y-%m-%d)
cores=6

echo "******* $DBNAME *******"

bash /products/tfis_nrw/load_tfis_nrw.sh

echo "==> Warte auf PostgreSQL-Port..."
until pg_isready -h "$PGHOST" -U "$PGUSER" -d "$DBNAME"; do
  echo "Postgres noch nicht bereit - warte..."
  sleep 2
done

export insert_folder="/data/tfis_nrw"
if [ ! -d "$insert_folder/logs" ]; then
  mkdir $insert_folder/logs
fi
postnas_logfile="$insert_folder/logs/"$insertdatum"-postnas_import_single.log"

##################################################################################################
export GML_FIELDTYPES=ALWAYS_STRING
export OGR_SETFIELD_NUMERIC_WARSLNG=ON
export OGR_ARC_MINLENGTH=0.1
export NAS_NO_RELATION_LAYER=NO
#export LC_CTYPE=de_DE.UTF-8
export OGR="ogr2ogr"
################################################################################################

echo "🧨 Beende aktive Verbindungen zur Datenbank '$DBNAME'..."
psql -U "$PGUSER" -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DBNAME}';"
psql -U "$PGUSER" -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DBNAME}';"

echo "🗑️ Lösche Datenbank '$DBNAME' (falls vorhanden)..."
psql -U "$PGUSER" -d postgres -c "DROP DATABASE IF EXISTS ${DBNAME};"

echo "🆕 Lege Datenbank '$DBNAME' neu an..."
psql -U "$PGUSER" -d postgres -c "CREATE DATABASE ${DBNAME};"

echo "➕ Füge Erweiterung 'postgis' hinzu..."
psql -U "$PGUSER" -d "$DBNAME" -c "CREATE EXTENSION postgis;"

processJSON() {
  file="$1"
  echo "📥 Importiere Datei: $file"
  $OGR -append -update -lco GEOMETRY_NAME=wkb_geometry -skipfailures \
    -f "PostgreSQL" \
    --config PG_USE_COPY NO \
    -nlt CONVERT_TO_LINEAR \
    -ds_transaction \
    PG:"dbname="$DBNAME" user="$PGUSER" port="$PGPORT" " \
    -t_srs EPSG:25832 "$file"
}
export -f processJSON

cd "$insert_folder"

echo "📂 Starte Import aus Ordner: $insert_folder"
find . -type f -name "*.json" | xargs -P $cores -I {} bash -c 'processJSON "$0"' {}

echo "==> Datenbank mit VACUUM optimieren..."
psql -c "VACUUM ANALYZE ${DBTABLE};" -U "$PGUSER" -d "$DBNAME"

# Mapfile, Icon's updaten
/usr/bin/python3 /products/tfis_nrw/transform/mapbox2mapserver.py

echo "✅ Fertig."
