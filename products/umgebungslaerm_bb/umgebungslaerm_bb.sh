#!/bin/bash
set -e

export DBNAME="umgebungslaerm_bb"
export EPSG="-a_srs EPSG:25833"
export PGUSER="postgres"
export PGPORT=5432

echo "******* $DBNAME *******"

echo "==> Warte auf PostgreSQL-Port..."
until pg_isready -h "$PGHOST" -U "$PGUSER" -d "$DBNAME"; do
    echo "Postgres noch nicht bereit - warte..."
    sleep 2
done

echo "🧨 Beende aktive Verbindungen zur Datenbank '$DBNAME'..."
psql -U "$PGUSER" -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DBNAME}';"
psql -U "$PGUSER" -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DBNAME}';"

echo "🗑️ Lösche Datenbank '$DBNAME' (falls vorhanden)..."
psql -U "$PGUSER" -d postgres -c "DROP DATABASE IF EXISTS ${DBNAME};"

echo "🆕 Lege Datenbank '$DBNAME' neu an..."
psql -U "$PGUSER" -d postgres -c "CREATE DATABASE ${DBNAME};"

echo "➕ Füge Erweiterung 'postgis' hinzu..."
psql -U "$PGUSER" -d "$DBNAME" -c "CREATE EXTENSION postgis;"

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

#https://inspire.brandenburg.de/services/laerm_wfs?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetCapabilities

ogr2ogr -makevalid -skipfailures --config PG_USE_COPY NO -nlt CONVERT_TO_LINEAR -ds_transaction -lco GEOMETRY_NAME=wkb_geometry \
    -f "PostgreSQL" -nln "flug_lden2022" \
    PG:"dbname="$DBNAME" user="$PGUSER" port="$PGPORT" " $EPSG \
    WFS:"https://inspire.brandenburg.de/services/laerm_wfs?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetCapabilities" flug_lden2022

ogr2ogr -makevalid -skipfailures --config PG_USE_COPY NO -nlt CONVERT_TO_LINEAR -ds_transaction -lco GEOMETRY_NAME=wkb_geometry \
    -f "PostgreSQL" -nln "pdm_strasse_lden2022" \
    PG:"dbname="$DBNAME" user="$PGUSER" port="$PGPORT" " $EPSG \
    WFS:"https://inspire.brandenburg.de/services/laerm_wfs?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetCapabilities" pdm_strasse_lden2022

ogr2ogr -makevalid -append -update -skipfailures --config PG_USE_COPY NO -nlt CONVERT_TO_LINEAR -ds_transaction -lco GEOMETRY_NAME=wkb_geometry \
    -f "PostgreSQL" -nln "bb_strasse_lden2017" \
    PG:"dbname="$DBNAME" user="$PGUSER" port="$PGPORT" " $EPSG \
    WFS:"https://inspire.brandenburg.de/services/laerm_wfs?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetCapabilities" bb_strasse_lden2017

ogr2ogr -makevalid -skipfailures --config PG_USE_COPY NO -nlt CONVERT_TO_LINEAR -ds_transaction -lco GEOMETRY_NAME=wkb_geometry \
    -f "PostgreSQL" -nln "pdm_schiene_lden2022" \
    PG:"dbname="$DBNAME" user="$PGUSER" port="$PGPORT" " $EPSG \
    WFS:"https://inspire.brandenburg.de/services/laerm_wfs?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetCapabilities" pdm_schiene_lden2022

ogr2ogr -makevalid -skipfailures --config PG_USE_COPY NO -nlt CONVERT_TO_LINEAR -ds_transaction -lco GEOMETRY_NAME=wkb_geometry \
    -f "PostgreSQL" -nln "pdm_industrie_lden2022" \
    PG:"dbname="$DBNAME" user="$PGUSER" port="$PGPORT" " $EPSG \
    WFS:"https://inspire.brandenburg.de/services/laerm_wfs?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetCapabilities" pdm_industrie_lden2022

for tbl in "${tables[@]}"; do
    psql -U postgres -d $DBNAME -c "CREATE INDEX IF NOT EXISTS ${tbl}_geom_gist ON $tbl USING gist (wkb_geometry);"
done

echo "==> Datenbank mit VACUUM optimieren..."
psql -c "VACUUM ANALYZE ${DBTABLE};" -U "$PGUSER" -d "$DBNAME"
