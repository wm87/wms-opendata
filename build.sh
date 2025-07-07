#!/bin/bash

set -e

docker-compose down
docker system prune -a --volumes --force
docker-compose up --build -d

# Warten, bis der Container "pg" gesund ist
echo "Warte auf Healthcheck..."
for i in {1..20}; do
    STATUS=$(docker inspect --format='{{.State.Health.Status}}' pg)
    if [ "$STATUS" = "healthy" ]; then
        echo "Postgres Container ist healthy."
        break
    fi
    echo "Status: $STATUS. Warte..."
    sleep 3
done

# Sicherstellen, dass die DB's exisieren
echo "Warte auf Datenbank boris_bb..."
check_db_exists() {
    local dbname=$1
    echo "Warte auf Datenbank $dbname..."
    for i in {1..20}; do
        DB_EXISTS=$(docker exec pg psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${dbname}'")
        if [ "$DB_EXISTS" = "1" ]; then
            echo "Datenbank $dbname existiert."
            return 0
        fi
        echo "Noch nicht da, warte..."
        sleep 2
    done
}

check_db_exists "boris_bb"
check_db_exists "boris_nrw"


# Test
docker exec -it pg psql -U postgres -d boris_bb -c "\dt"

docker exec -it pg psql -U postgres -d boris_bb \
    -c "SELECT COUNT(*) FROM boris_bb;"

docker exec -it pg psql -U postgres -d boris_nrw -c "\dt"

docker exec -it pg psql -U postgres -d boris_nrw \
    -c "SELECT COUNT(*) FROM boris_nrw;"

docker exec -it mapserver mapserv -v
