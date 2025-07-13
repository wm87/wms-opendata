#!/bin/bash
set -euo pipefail

docker-compose down
docker system prune -a --volumes --force
docker-compose up --build -d

# Warte auf Container
echo "⏳ Warte auf PostgreSQL-Container 'pg'..."
until docker exec pg pg_isready -U postgres >/dev/null 2>&1; do
    sleep 1
done
echo "✅ Container 'pg' ist bereit."

# Funktion
check_db_exists() {
    local dbname="$1"
    echo "🔍 Prüfe Datenbank: $dbname"

    if docker exec -i pg psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${dbname}'" | grep -q 1; then
        echo "✅ Datenbank $dbname existiert."
    else
        echo "❌ Datenbank $dbname existiert nicht."
        exit 1
    fi

    echo "📦 Tabellen in $dbname:"
    docker exec -i pg psql -U postgres -d "$dbname" -c "\dt" || echo "(keine Tabellen oder kein Zugriff)"
    echo
}

# Test, ob DB ansprechbar
check_db_exists "boris_bb"
check_db_exists "boris_nrw"
check_db_exists "tfis_nrw"
check_db_exists "umgebungslaerm_bb"

docker exec -i mapserver mapserv -v

docker logs -f importer
