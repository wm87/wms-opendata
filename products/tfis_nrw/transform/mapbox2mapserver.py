import glob
import json
import os

from PIL import Image

safe_snrs = {}

DATA_DIR = "/data/tfis_nrw"
OUTPUT_MAPFILE = "/etc/mapserver/wms_tfis_nrw.map"
SYMBOL_FILE = "/etc/mapserver/symbols.map"
SPRITE_JSON_PATH = "/products/tfis_nrw/build/sprite@2x.json"
SPRITE_IMAGE_PATH = "/products/tfis_nrw/build/sprite@2x.png"
ICON_DIR = "/etc/mapserver/icons"


def sanitize_filename(name):
    name = str(name)  # ← Hier wird der Name sicher in einen String umgewandelt
    replacements = {
        'ä': 'ae', 'Ä': 'Ae',
        'ö': 'oe', 'Ö': 'Oe',
        'ü': 'ue', 'Ü': 'Ue',
        'ß': 'ss'
    }
    for src, tgt in replacements.items():
        name = name.replace(src, tgt)
    return ''.join(c if c.isalnum() or c in '-_' else '_' for c in name)


MAP_HEADER = """
MAP
    NAME "nrw_tfis"
    EXTENT 280375 5573233 531799 5824657
    SIZE 600 600
    IMAGECOLOR 255 255 255
    IMAGETYPE png
    SYMBOLSET "{symbol_file}"
    FONTSET "fonts/fonts.list"
    
    PROJECTION
        'epsg:25832'
    END

    OUTPUTFORMAT
        NAME png
        DRIVER "GD/PNG"
        MIMETYPE "image/png"
        IMAGEMODE PC256
        EXTENSION "png"
        TRANSPARENT ON
    END

    LEGEND
        STATUS ON
        IMAGECOLOR 238 238 238
        KEYSIZE 80 20
        KEYSPACING 5 5
        LABEL
            TYPE TRUETYPE
            FORCE TRUE
            FONT arial
            SIZE 8
            COLOR 0 0 89
        END
    END
    
    DEBUG ON
    WEB
        IMAGEPATH "/tmp/"
        IMAGEURL "/tmp/"
        METADATA
            "WMS_TITLE"                       "Touristik- und Freizeitinformationen NRW (TFIS NRW)"
            "WMS_ABSTRACT"                    "WMS_NW_TFIS"
            "wms_extent"                      "280375 5573233 531799 5824657"
            'wms_srs'                         'EPSG:31466 EPSG:31467 EPSG:25832 EPSG:4326 EPSG:4258 EPSG:3857'
            'ows_keywordlist'                 'Investitionsförderung,finanzschwache Kommunen,kommunale Infrastruktur,kommunales Investitionsprogramm,DAKI,KI 3.0,Rheinland-Pfalz'
            'ows_fees'                        'geldleistungsfrei, Datenlizenz Deutschland - Namensnennung - Version 2.0, URL: https://www.govdata.de/dl-de/by-2-0' #Gebühren
            'ows_accessconstraints'           'Datenlizenz Deutschland - Namensnennung - Version 2.0, URL: https://www.govdata.de/dl-de/by-2-0' #Zugriffsbeschränkungen (falls vorhanden)
            "ows_enable_request" "*"
            "wms_feature_info_mime_type" "text/html"
            "isqueryable" "true"
            "WMS_ENCODING" "UTF-8"
            "gui_wms_featureinfoformat" "text/html"
            "gui_wms_exceptionformat" "text/html"
            # "gml_include_items" "all"
        END
    END #WEB
"""

MAP_FOOTER = "END\n"

LAYER_TEMPLATE = """
LAYER
    NAME "{layername}"
    TYPE POINT
    STATUS ON
    CONNECTIONTYPE POSTGIS
    CONNECTION "dbname='tfis_nrw' host=pg port=5432 user='postgres' password='postgres'"
    DATA "wkb_geometry FROM (select ogc_fid, snr, wkb_geometry from {layername}) AS foo USING UNIQUE ogc_fid USING SRID=25832"
    PROCESSING "CLOSE_CONNECTION=DEFER"
    MAXSCALEDENOM 30000
    SIZEUNITS METERS
    CLASSITEM "snr"
    METADATA
        "wms_title" "{layername}"
        "wms_srs" "EPSG:4326 EPSG:4647 EPSG:31466 EPSG:31467 EPSG:31468 EPSG:25832 EPSG:25833"
        "wms_metadataurl_type" "TC211"
        "wms_bbox_extended" "true"
        "wms_enable_request" "*"
        "wms_format" "image/png"
        "wms_transparent" "true"
        "wms_extent" "280375 5573233 531799 5824657"
        "WMS_FEATURE_INFO_MIME_TYPE" "text/html"
    END
    
    PROJECTION
        "epsg:25832"
    END
    
    {classes}
END
"""

CLASS_TEMPLATE = """
CLASS
    EXPRESSION "{snr}"
    STYLE
      SIZE 100
      MAXSIZE 150
      SYMBOL "{snr}"
    END
END
"""

SYMBOL_TEMPLATE = """
SYMBOL
  NAME "{snr}"
  TYPE PIXMAP
  IMAGE "icons/{snr}.png"
END
"""

import shutil  # oben im Skript, falls noch nicht vorhanden


def extract_icons_from_sprite(sprite_json_path, sprite_image_path, output_dir):
    import unicodedata
    import re

    def sanitize_filename(name):
        name = str(name)
        replacements = {
            'ä': 'ae', 'Ä': 'Ae',
            'ö': 'oe', 'Ö': 'Oe',
            'ü': 'ue', 'Ü': 'Ue',
            'ß': 'ss'
        }
        for src, tgt in replacements.items():
            name = name.replace(src, tgt)
        name = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode("ascii")
        name = re.sub(r"[^a-zA-Z0-9_-]", "_", name)
        return name

    # 🔥 Ordner löschen, wenn vorhanden
    if os.path.exists(output_dir):
        shutil.rmtree(output_dir)
    os.makedirs(output_dir, exist_ok=True)

    with open(sprite_json_path, 'r', encoding='utf-8') as f:
        sprites = json.load(f)

    image = Image.open(sprite_image_path)

    for original_name, data in sprites.items():
        if not data.get("visible", True):
            continue

        x, y = data["x"], data["y"]
        w, h = data["width"], data["height"]

        cropped = image.crop((x, y, x + w, y + h))

        safe_name = sanitize_filename(original_name)
        cropped.save(os.path.join(output_dir, f"{safe_name}.png"))

        safe_snrs[original_name] = safe_name


def load_sprite_styles(sprite_json_path):
    with open(sprite_json_path, 'r', encoding='utf-8') as f:
        return json.load(f)


def extract_property_values(filepath, property_name):
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    return sorted({feature["properties"].get(property_name) for feature in data["features"] if
                   property_name in feature["properties"]})


def generate_files():
    print("🔧 Extrahiere Icons aus sprite.png...")
    extract_icons_from_sprite(SPRITE_JSON_PATH, SPRITE_IMAGE_PATH, ICON_DIR)

    sprite_styles = load_sprite_styles(SPRITE_JSON_PATH)
    all_snrs = set()
    symbol_defs = ""

    # Getrennte Layer-Definitionen zur Steuerung der Reihenfolge
    layer_defs_wander = ""      # Wanderwege ganz vorn
    layer_defs_schiff = ""      # Schifffahrt ganz vorn
    layer_defs_main = ""        # Alle übrigen Punktlayer

    for filepath in glob.glob(os.path.join(DATA_DIR, "*.json")):
        filename = os.path.basename(filepath)
        basename = os.path.splitext(filename)[0]

        # === WANDERWEGE ===
        if basename == "wanderwege":
            style_map = {
                "Fernwanderweg":    {"COLOR": "245 199 16",   "LINECAP": "butt", "LINEJOIN": "miter", "PATTERN": None},
                "Hauptwanderweg":   {"COLOR": "0 158 115",    "LINECAP": "butt", "LINEJOIN": "miter", "PATTERN": "10 20 END"},
                "Regionaler Wanderweg": {"COLOR": "213 94 0", "LINECAP": "butt", "LINEJOIN": "miter", "PATTERN": "30 35 END"},
                "Örtlicher Wanderweg":  {"COLOR": "204 121 167", "LINECAP": "butt", "LINEJOIN": "miter", "PATTERN": "20 58 END"},
                "Rundwanderweg":    {"COLOR": "86 180 233",   "LINECAP": "butt", "LINEJOIN": "miter", "PATTERN": "30 50 END"},
                "Themenwanderweg":  {"COLOR": "230 159 0",    "LINECAP": "butt", "LINEJOIN": "miter", "PATTERN": "70 40 END"}
            }

            kat_values = extract_property_values(filepath, "kat")
            classes = ""
            for kat in kat_values:
                style = style_map.get(kat, {
                    "COLOR": "255 0 0",
                    "LINECAP": "butt",
                    "LINEJOIN": "miter",
                    "PATTERN": "50 20 END"
                })
                pattern_str = f"\n                        PATTERN {style['PATTERN']}" if style["PATTERN"] else ""
                classes += f"""
                CLASS
                    NAME "{kat}"
                    EXPRESSION "{kat}"
                    STYLE
                        COLOR {style["COLOR"]}
                        WIDTH 20
                        MAXWIDTH 60
                        LINECAP {style["LINECAP"]}
                        LINEJOIN {style["LINEJOIN"]}{pattern_str}
                    END
                END
                """
            layer_defs_wander = f"""
            LAYER
                NAME "wanderwege"
                TYPE LINE
                UNITS METERS
                CLASSITEM "kat"
                CONNECTION "dbname='tfis_nrw' host=pg port=5432 user='postgres' password='postgres'"
                CONNECTIONTYPE POSTGIS
                DATA "wkb_geometry FROM (SELECT ogc_fid, kat, wkb_geometry FROM wanderwege) AS foo USING UNIQUE ogc_fid USING SRID=25832"
                PROCESSING "CLOSE_CONNECTION=DEFER"
                MAXSCALEDENOM 75001
                METADATA
                    "wms_title" "Wanderwege_LINE"
                    "wms_srs" "EPSG:4326 EPSG:4647 EPSG:31466 EPSG:31467 EPSG:31468 EPSG:25832 EPSG:25833"
                    "wms_metadataurl_type" "TC211"
                    "wms_bbox_extended" "true"
                    "wms_enable_request" "*"
                    "wms_format" "image/png"
                    "wms_transparent" "true"
                    "wms_extent" "280375.039 5573233.639 531799.013 5824657.613"
                    "WMS_FEATURE_INFO_MIME_TYPE" "text/html"
                END
                PROJECTION
                    "epsg:25832"
                END
                SIZEUNITS METERS
                STATUS ON
                SYMBOLSCALEDENOM 1000
                {classes}
            END
            """
            continue

        # === SCHIFFFAHRT ===
        elif basename == "schifffahrt":
            fkt_values = extract_property_values(filepath, "fkt")
            classes = ""
            for fkt in fkt_values:
                classes += f"""
                CLASS
                    NAME "Schifffahrt_{fkt}"
                    EXPRESSION "{fkt}"
                    STYLE
                        COLOR 0 114 178
                        WIDTH 15
                        LINECAP BUTT
                        LINEJOIN MITER
                        PATTERN 70 30 END
                    END
                END
                """
            layer_defs_schiff = f"""
            LAYER
                NAME "Schifffahrtslinien"
                GROUP "schifffahrt"
                TYPE LINE
                UNITS METERS
                CLASSITEM "fkt"
                CONNECTION "dbname='tfis_nrw' host=pg port=5432 user='postgres' password='postgres'"
                CONNECTIONTYPE POSTGIS
                DATA "wkb_geometry FROM (SELECT ogc_fid, fkt, wkb_geometry FROM schifffahrt) AS foo USING UNIQUE ogc_fid USING SRID=25832"
                PROCESSING "CLOSE_CONNECTION=DEFER"
                MAXSCALEDENOM 75001
                METADATA
                    "wms_title" "Schifffahrtslinien"
                    "wms_srs" "EPSG:4326 EPSG:4647 EPSG:31466 EPSG:31467 EPSG:31468 EPSG:25832 EPSG:25833"
                    "wms_metadataurl_type" "TC211"
                    "wms_bbox_extended" "true"
                    "wms_enable_request" "*"
                    "wms_format" "image/png"
                    "wms_transparent" "true"
                    "wms_extent" "280375.039 5573233.639 531799.013 5824657.613"
                    "WMS_FEATURE_INFO_MIME_TYPE" "text/html"
                END
                PROJECTION
                    "epsg:25832"
                END
                SIZEUNITS METERS
                STATUS ON
                {classes}
            END
            """
            continue

        # === ANDERE: Punktlayer ===
        snr_values = extract_property_values(filepath, "snr")
        if not snr_values:
            continue

        classes = ""
        for snr in snr_values:
            snr_str = str(snr)
            if snr_str in sprite_styles:
                style = sprite_styles[snr_str]
                if not style.get("visible", True):
                    continue
                width = style.get("width", 20)
                height = style.get("height", width)
                size = max(width, height)
            else:
                continue

            safe_snr = sanitize_filename(snr_str)
            classes += CLASS_TEMPLATE.format(snr=safe_snr, size=size)

            if safe_snr not in all_snrs:
                symbol_defs += SYMBOL_TEMPLATE.format(snr=safe_snr)
                all_snrs.add(safe_snr)

        layer_defs_main += LAYER_TEMPLATE.format(
            layername=basename,
            filepath=filepath.replace("\\", "/"),
            classes=classes
        )

    # === SYMBOL-Datei schreiben ===
    with open(SYMBOL_FILE, 'w', encoding='utf-8') as f:
        f.write("SYMBOLSET\n")
        f.write(symbol_defs)
        f.write("END\n")

    # === MAPFILE schreiben: zuerst wanderwege/schifffahrt, dann alle anderen ===
    full_layer_defs = layer_defs_wander + layer_defs_schiff + layer_defs_main

    with open(OUTPUT_MAPFILE, 'w', encoding='utf-8') as f:
        f.write(MAP_HEADER.format(symbol_file=SYMBOL_FILE))
        f.write(full_layer_defs)
        f.write(MAP_FOOTER)

    print(f"✔ Mapfile erstellt:      {OUTPUT_MAPFILE}")
    print(f"✔ Symbol-Datei erstellt: {SYMBOL_FILE}")
    print(f"✔ Icons gespeichert in:  {ICON_DIR}/")


if __name__ == "__main__":
    generate_files()
