#!/bin/bash
set -e

dbname="boris_bb"
dbtable="boris_bb"

echo "******* $dbname *******"

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

psql -c "TRUNCATE TABLE boris_bb RESTART IDENTITY;" $CON
psql -c "ALTER DATABASE $dbname SET search_path TO public;" $CON

echo "==> Importiere CSV..."
psql -c "\copy boris_bb(gesl,gena,gasl,gabe,genu,gema,ortst,wnum,brw,wae,stag,brke,bedw,plz,basbe,basma,xybrw,posb,posa,apma,bezug,epsg,entw,beit,nuta,ergnuta,bauw,gez,gezm,wgfz,wgfzm,grz,grzm,bmz,bmzm,flae,flaem,fmass,gtie,gtiem,gbrei,gbreim,erve,verg,verf,vnum,bod,acza,aczam,grza,grzam,aufw,weer,geom,bem,frei,brzname,umart,lumnum,status,degl) FROM '/data/boris_bb/BRW_2022_Land_BB.csv' DELIMITER '|' CSV HEADER;" $CON

echo "==> Ändere Spaltentyp geom und erstelle Index..."
psql -c "ALTER TABLE $dbtable ALTER COLUMN geom TYPE geometry(Polygon, 25833) USING ST_SetSRID(geom,25833);" $CON
#psql -c "CREATE INDEX boris_bb_the_geom_gist ON $dbtable USING gist (geom);" $CON

echo "==> Update brw-Spalte..."
psql -c "
UPDATE $dbtable SET brw = REPLACE(brw,',','.');
UPDATE $dbtable
SET brw = ROUND(CAST(brw AS numeric), 0)
WHERE ROUND(CAST(brw AS DOUBLE PRECISION)) >= 0 AND entw != 'LF';" $CON

echo "==> Erzeuge Punkt-Geometrie und Index..."

psql -h "$PGHOST" -U "$PGUSER" -d "$dbname" -c "ALTER TABLE boris_bb DROP COLUMN IF EXISTS geom_point;"
psql -h "$PGHOST" -U "$PGUSER" -d "$dbname" -c "ALTER TABLE boris_bb ADD COLUMN geom_point geometry(Point, 25833);"

psql -c "UPDATE $dbtable SET geom_point = ST_GeomFromText(xybrw, 25833);" $CON
psql -c "CREATE INDEX boris_bb_geom_point_gist ON $dbtable USING gist (geom_point);" $CON

echo "==> Datenbank mit VACUUM optimieren..."
psql -c "VACUUM ANALYZE boris_bb;" $CON
