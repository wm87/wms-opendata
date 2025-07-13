#!/bin/bash

# Liste der zu prüfenden Datenbanken
DATABASES=("boris_bb" "boris_nrw" "tfis_nrw" "umgebungslaerm_bb")

if ! pg_isready -U postgres >/dev/null 2>&1; then
    echo "PostgreSQL ist nicht bereit."
    exit 1
fi

for DB in "${DATABASES[@]}"; do
    EXISTS=$(psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${DB}'")
    if [[ "$EXISTS" != "1" ]]; then
        echo "Fehlende Datenbank: $DB"
        exit 1
    fi
done

echo "Alle Datenbanken vorhanden."
exit 0
