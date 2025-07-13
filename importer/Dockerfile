FROM postgis/postgis:17-3.5

# Systempakete + Python und pip installieren
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gdal-bin \
    postgis \
    wget \
    curl \
    jq \
    unzip \
    python3 \
    python3-pip \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Python-Pakete installieren
RUN pip3 install --no-cache-dir Pillow

COPY main.sh /main.sh
RUN chmod +x /main.sh

ENTRYPOINT ["/bin/bash", "/main.sh"]
