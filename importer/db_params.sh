#!/bin/bash
dbname=$1

export CON="-h ${PGHOST:-localhost} -U ${PGUSER:-postgres} -d $dbname"
export dbport=${PGPORT:-5432}
export dbuser=${PGUSER:-postgres}
export dbtablespace="pg_default"
