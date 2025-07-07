#!/bin/bash

dbname="boris_nrw"
dbtable="boris_nrw"
cores=6

insertdatum=$(date +%Y-%m-%d)
boris_nrwShpFile="/data/boris_nrw/BRW_*_Polygon.shp"

echo "******* $dbname *******"

bash /products/boris_nrw/load_data_boris_nrw.sh

# Lade DB-Verbindungsparameter
source /importer/db_params.sh $dbname

echo "==> Warte auf PostgreSQL-Port..."
until pg_isready -h "$PGHOST" -U "$PGUSER" -d "$dbname"; do
    echo "Postgres noch nicht bereit - warte..."
    sleep 2
done

psql -c "ALTER DATABASE $dbname SET search_path TO public;" $CON

if [ -f $boris_nrwShpFile ]; then

    psql -c "DROP TABLE IF EXISTS $dbtable" --quiet $CON
    shp2pgsql -D -c -W LATIN1 -s 25832 -I $boris_nrwShpFile $dbtable | psql --quiet $CON
    psql -c "CREATE INDEX $dbtable_geom_gist ON $dbtable USING gist (geom);" --quiet $CON

    # Point Geometry erzeugen #

    psql -c "ALTER TABLE $dbtable ADD COLUMN geom_point geometry; ALTER TABLE $dbtable ALTER COLUMN geom_point TYPE geometry(Point, 25832) USING ST_SetSRID(geom_point,25832); CREATE INDEX boris_nrw_geom_point_gist ON $dbtable USING gist (geom_point);" $CON

    #SUBSTR 32 bei ywert entfernen!!!
    psql -c "
        UPDATE boris_nrw SET ywert = REPLACE(ywert,',','');
        
        UPDATE boris_nrw SET 
        geom_point = ST_GeomFromText('POINT(' || ywert || ' ' || xwert || ')',25832) 
        where length(xwert) = 7 AND length(ywert) = 6;

        UPDATE boris_nrw SET 
        geom_point = ST_GeomFromText('POINT(' || SUBSTR (ywert,3) || ' ' || xwert || ')',25832) 
        where length(xwert) = 7 AND length(ywert) = 8;" $CON

    psql -c "COMMENT ON TABLE $dbtable IS 'IMPORT: "$insertdatum"';" $CON
fi

bash /products/boris_nrw/modification.sh

echo "==> Datenbank mit VACUUM optimieren..."
psql -c "VACUUM ANALYZE boris_nrw;" $CON
