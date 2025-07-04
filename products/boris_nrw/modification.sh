#!/bin/bash

dbname="boris_nrw"

source /importer/db_params.sh $dbname

# Processing

psql -c "DROP TABLE IF EXISTS vboris_nrw;" $CON
psql -c "DROP INDEX IF EXISTS vboris_nrw_geom_idx;" $CON
psql -c "DROP INDEX IF EXISTS vboris_nrw_zonennummer_btree;" $CON

psql -c "ALTER TABLE boris_nrw ADD COLUMN label_bf varchar(150); ALTER TABLE boris_nrw ADD COLUMN label_lf varchar(150);" $CON

psql -c "UPDATE boris_nrw SET label_bf = 
  (SELECT concat_ws (' ', entw, beit, nuta, bauw, gez, gfz, grz, gtie, flae, verf,':',acza, grzA, weer, lurt));" $CON

psql -c "UPDATE boris_nrw SET label_lf = 
  (SELECT concat_ws(' ', entw, nuta, flae, acza, grzA, weer, lurt, verf)) WHERE ergnuta is null;" $CON

psql -c "SELECT gid, to_char(cast(GENU as integer),'FM0000') || to_char(cast(brwznr as integer),'FM0000') as zonennummer,'3' as prioritaet , '9' as zoomlevel, '2500' as scale , st_centroid(geom) as geom_point , geom  INTO vboris_nrw FROM boris_nrw where ST_isvalid(geom) = true;" $CON

psql -c "CREATE INDEX vboris_nrw_geom_idx  ON vboris_nrw  USING gist  (geom);" $CON

psql -c "CREATE INDEX vboris_nrw_zonennummer_btree  ON vboris_nrw  USING btree  (zonennummer COLLATE pg_catalog.default);" $CON

psql -c "INSERT INTO geometry_columns(f_table_catalog, f_table_schema, f_table_name, f_geometry_column, coord_dimension, srid, type) 
  VALUES ('', 'public', 'vboris_nrw', 'geom_point', 2, 25832, 'POINT');" $CON

psql -c "INSERT INTO geometry_columns(f_table_catalog, f_table_schema, f_table_name, f_geometry_column, coord_dimension, srid, type) 
  VALUES ('', 'public', 'vboris_nrw', 'geom', 2, 25832, 'MULTIPOLYGON');" $CON
