#!/bin/bash
set -e

insertFolder="/data/tfis_nrw"
cd "$insertFolder"

rm -f "$insertFolder"/*.json

urls=(
  "https://ogc-api.nrw.de/tfis/v1/collections/aussichtspunkte/items"
  "https://ogc-api.nrw.de/tfis/v1/collections/burgen_denkmaeler_etc/items"
  "https://ogc-api.nrw.de/tfis/v1/collections/infrastruktur_wassersport/items"
  "https://ogc-api.nrw.de/tfis/v1/collections/museen/items"
  "https://ogc-api.nrw.de/tfis/v1/collections/natur/items"
  "https://ogc-api.nrw.de/tfis/v1/collections/schifffahrt/items"
  "https://ogc-api.nrw.de/tfis/v1/collections/schifffahrt_kennzeichnung/items"
  "https://ogc-api.nrw.de/tfis/v1/collections/sport_baden/items"
  "https://ogc-api.nrw.de/tfis/v1/collections/theater_musik/items"
  "https://ogc-api.nrw.de/tfis/v1/collections/touristikinformation/items"
  "https://ogc-api.nrw.de/tfis/v1/collections/unterkunft_rast/items"
  "https://ogc-api.nrw.de/tfis/v1/collections/verkehr/items"
  "https://ogc-api.nrw.de/tfis/v1/collections/wanderwege/items"
  "https://ogc-api.nrw.de/tfis/v1/collections/wanderwege_kennzeichnung/items"
)

for url in "${urls[@]}"; do
  dataset_type=$(echo "$url" | sed -n 's|.*/collections/\([^/]*\)/.*|\1|p')
  output_file="$insertFolder/${dataset_type}.json"
  tmp_features_file="$insertFolder/${dataset_type}_features.tmp.json"
  tmp_response_file="$insertFolder/${dataset_type}_response.tmp.json"

  >"$tmp_features_file"

  for ((offset = 0; offset <= 100000; offset += 2500)); do
    echo "Fetching $dataset_type offset $offset..."
    curl -s "$url?offset=$offset&limit=2500&f=json" -o "$tmp_response_file"

    count=$(jq '.features | length' "$tmp_response_file")
    if [[ "$count" == "0" ]]; then
      break
    fi

    jq -c '.features[]' "$tmp_response_file" >>"$tmp_features_file"
  done

  # Jetzt die Features mit Kommas korrekt verbinden
  echo '{ "type": "FeatureCollection", "features": [' >"$output_file"
  paste -sd, "$tmp_features_file" >>"$output_file"
  echo "] }" >>"$output_file"

  rm -f "$tmp_features_file" "$tmp_response_file"
done
