#!/bin/bash
set -e

export DBNAME="boris_nrw"
export DBTABLE="boris_nrw"
export PGUSER="postgres"
export PGPORT=5432

insertdatum=$(date +%Y-%m-%d)
boris_nrwShpFile="/data/boris_nrw/BRW_*_Polygon.shp"

echo "******* $DBNAME *******"

bash /products/boris_nrw/load_data_boris_nrw.sh

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

if [ -f $boris_nrwShpFile ]; then

    psql -c "DROP TABLE IF EXISTS $DBTABLE" --quiet -U "$PGUSER" -d "$DBNAME"
    shp2pgsql -D -c -W LATIN1 -s 25832 -I $boris_nrwShpFile $DBTABLE | psql --quiet -U "$PGUSER" -d "$DBNAME"
    psql -c "CREATE INDEX $DBTABLE_geom_gist ON $DBTABLE USING gist (geom);" --quiet -U "$PGUSER" -d "$DBNAME"

    # Point Geometry erzeugen #

    psql -c "ALTER TABLE $DBTABLE ADD COLUMN geom_point geometry; ALTER TABLE $DBTABLE ALTER COLUMN geom_point TYPE geometry(Point, 25832) USING ST_SetSRID(geom_point,25832); CREATE INDEX boris_nrw_geom_point_gist ON $DBTABLE USING gist (geom_point);" -U "$PGUSER" -d "$DBNAME"

    #SUBSTR 32 bei ywert entfernen!!!
    psql -c "
        UPDATE $DBTABLE SET ywert = REPLACE(ywert,',','');
        
        UPDATE $DBTABLE SET 
        geom_point = ST_GeomFromText('POINT(' || ywert || ' ' || xwert || ')',25832) 
        where length(xwert) = 7 AND length(ywert) = 6;

        UPDATE $DBTABLE SET 
        geom_point = ST_GeomFromText('POINT(' || SUBSTR (ywert,3) || ' ' || xwert || ')',25832) 
        where length(xwert) = 7 AND length(ywert) = 8;" -U "$PGUSER" -d "$DBNAME"

    psql -c "COMMENT ON TABLE $DBTABLE IS 'IMPORT: "$insertdatum"';" -U "$PGUSER" -d "$DBNAME"
fi

bash /products/boris_nrw/modification.sh

echo "==> Datenbank mit VACUUM optimieren..."
psql -c "VACUUM ANALYZE $DBTABLE;" -U "$PGUSER" -d "$DBNAME"
