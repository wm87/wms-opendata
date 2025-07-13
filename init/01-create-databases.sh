#!/bin/bash
set -euo pipefail

databases=(
  boris_bb
  boris_nrw
  tfis_nrw
  umgebungslaerm_bb
)

for db in "${databases[@]}"; do
  echo "🔍 Prüfe, ob Datenbank '$db' existiert..."

  if psql -v ON_ERROR_STOP=1 --username="$POSTGRES_USER" -tAc "SELECT 1 FROM pg_database WHERE datname = '$db'" | grep -q 1; then
    echo "✅ Datenbank '$db' existiert bereits."
  else
    echo "🆕 Erstelle Datenbank '$db'..."
    psql -v ON_ERROR_STOP=1 --username="$POSTGRES_USER" -c "CREATE DATABASE \"$db\";"
  fi

  echo
done
