FROM postgis/postgis:17-3.5

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gdal-bin \
    postgis \
    wget \
    unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY main.sh /main.sh
RUN chmod +x /main.sh

ENTRYPOINT ["/bin/bash", "/main.sh"]
