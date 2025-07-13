#!/bin/bash
set -e

export DBNAME="boris_bb"
export DBTABLE="boris_bb"
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

echo "🆕 Füge DB-Schema hinzu..."
psql -f /products/boris_bb/create_boris_table.sql -U "$PGUSER" -d "$DBNAME"

echo "==> Importiere CSV..."
psql -c "\copy $DBTABLE(gesl,gena,gasl,gabe,genu,gema,ortst,wnum,brw,wae,stag,brke,bedw,plz,basbe,basma,xybrw,posb,posa,apma,bezug,epsg,entw,beit,nuta,ergnuta,bauw,gez,gezm,wgfz,wgfzm,grz,grzm,bmz,bmzm,flae,flaem,fmass,gtie,gtiem,gbrei,gbreim,erve,verg,verf,vnum,bod,acza,aczam,grza,grzam,aufw,weer,geom,bem,frei,brzname,umart,lumnum,status,degl) FROM '/data/boris_bb/BRW_2022_Land_BB.csv' DELIMITER '|' CSV HEADER;" -U "$PGUSER" -d "$DBNAME"

echo "==> Ändere Spaltentyp geom und erstelle Index..."
psql -c "ALTER TABLE ${DBTABLE} ALTER COLUMN geom TYPE geometry(Polygon, 25833) USING ST_SetSRID(geom,25833);" -U "$PGUSER" -d "$DBNAME"
psql -c "CREATE INDEX ${DBTABLE}_the_geom_gist ON ${DBTABLE} USING gist (geom);" -U "$PGUSER" -d "$DBNAME"

echo "==> Update brw-Spalte..."
psql -c "
UPDATE ${DBTABLE} SET brw = REPLACE(brw,',','.');
UPDATE ${DBTABLE}
SET brw = ROUND(CAST(brw AS numeric), 0)
WHERE ROUND(CAST(brw AS DOUBLE PRECISION)) >= 0 AND entw != 'LF';" -U "$PGUSER" -d "$DBNAME"

echo "==> Erzeuge Punkt-Geometrie und Index..."

psql -h "$PGHOST" -U "$PGUSER" -d "$DBNAME" -c "ALTER TABLE ${DBTABLE} DROP COLUMN IF EXISTS geom_point;"
psql -h "$PGHOST" -U "$PGUSER" -d "$DBNAME" -c "ALTER TABLE ${DBTABLE} ADD COLUMN geom_point geometry(Point, 25833);"

psql -c "UPDATE ${DBTABLE} SET geom_point = ST_GeomFromText(xybrw, 25833);" -U "$PGUSER" -d "$DBNAME"
psql -c "CREATE INDEX ${DBTABLE}_geom_point_gist ON ${DBTABLE} USING gist (geom_point);" -U "$PGUSER" -d "$DBNAME"

echo "==> Datenbank mit VACUUM optimieren..."
psql -c "VACUUM ANALYZE ${DBTABLE};" -U "$PGUSER" -d "$DBNAME"
