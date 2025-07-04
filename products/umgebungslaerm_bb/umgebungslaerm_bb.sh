#!/bin/bash

dbname="umgebungslaerm_bb"
export EPSG="-a_srs EPSG:25833"

# Lade DB-Verbindungsparameter
source /importer/db_params.sh $dbname

echo "==> Warte auf PostgreSQL-Port..."
until pg_isready -h "$PGHOST" -U "$PGUSER" -d "$dbname"; do
    echo "Postgres noch nicht bereit - warte..."
    sleep 2
done

echo "==> Warte auf Tabelle $dbtable..."
until psql -h "$PGHOST" -U "$PGUSER" -d "$dbname" -c "\dt $dbtable" | grep -q "$dbtable"; do
    echo "Tabelle $dbtable noch nicht da, warte 2 Sekunden..."
    sleep 2
done

tables=(
    flug_lden2022
    pdm_strasse_lden2022
    bb_strasse_lden2017
    pdm_schiene_lden2022
    pdm_industrie_lden2022
)

for tbl in "${tables[@]}"; do
    if psql -U postgres -d umgebungslaerm_bb -tAc "SELECT to_regclass('public.$tbl')" | grep -q $tbl; then
        echo "TRUNCATE $tbl"
        psql -U postgres -d umgebungslaerm_bb -c "TRUNCATE TABLE $tbl RESTART IDENTITY;"
    else
        echo "Tabelle $tbl existiert noch nicht, überspringe TRUNCATE."
    fi
done

psql -c "ALTER DATABASE $dbname SET search_path TO public;" $CON

#https://inspire.brandenburg.de/services/laerm_wfs?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetCapabilities

ogr2ogr -makevalid -skipfailures --config PG_USE_COPY NO -nlt CONVERT_TO_LINEAR -ds_transaction -lco GEOMETRY_NAME=wkb_geometry \
    -f "PostgreSQL" -nln "flug_lden2022" \
    PG:" dbname=$dbname user=$dbuser port=$dbport " $EPSG \
    WFS:"https://inspire.brandenburg.de/services/laerm_wfs?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetCapabilities" flug_lden2022

ogr2ogr -makevalid -skipfailures --config PG_USE_COPY NO -nlt CONVERT_TO_LINEAR -ds_transaction -lco GEOMETRY_NAME=wkb_geometry \
    -f "PostgreSQL" -nln "pdm_strasse_lden2022" \
    PG:" dbname=$dbname user=$dbuser port=$dbport " $EPSG \
    WFS:"https://inspire.brandenburg.de/services/laerm_wfs?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetCapabilities" pdm_strasse_lden2022

ogr2ogr -makevalid -append -update -skipfailures --config PG_USE_COPY NO -nlt CONVERT_TO_LINEAR -ds_transaction -lco GEOMETRY_NAME=wkb_geometry \
    -f "PostgreSQL" -nln "bb_strasse_lden2017" \
    PG:" dbname=$dbname user=$dbuser port=$dbport " $EPSG \
    WFS:"https://inspire.brandenburg.de/services/laerm_wfs?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetCapabilities" bb_strasse_lden2017

ogr2ogr -makevalid -skipfailures --config PG_USE_COPY NO -nlt CONVERT_TO_LINEAR -ds_transaction -lco GEOMETRY_NAME=wkb_geometry \
    -f "PostgreSQL" -nln "pdm_schiene_lden2022" \
    PG:" dbname=$dbname user=$dbuser port=$dbport " $EPSG \
    WFS:"https://inspire.brandenburg.de/services/laerm_wfs?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetCapabilities" pdm_schiene_lden2022

ogr2ogr -makevalid -skipfailures --config PG_USE_COPY NO -nlt CONVERT_TO_LINEAR -ds_transaction -lco GEOMETRY_NAME=wkb_geometry \
    -f "PostgreSQL" -nln "pdm_industrie_lden2022" \
    PG:" dbname=$dbname user=$dbuser port=$dbport " $EPSG \
    WFS:"https://inspire.brandenburg.de/services/laerm_wfs?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetCapabilities" pdm_industrie_lden2022

for tbl in "${tables[@]}"; do
    psql -U postgres -d umgebungslaerm_bb -c "CREATE INDEX IF NOT EXISTS ${tbl}_geom_gist ON $tbl USING gist (wkb_geometry);"
done

# DB mit INDEX säubern #
psql -c "VACUUM FULL" $CON
