FROM ubuntu:plucky

RUN apt-get update && apt-get install -y apache2 cgi-mapserver libapache2-mod-fcgid \
    && rm -rf /var/lib/apt/lists/*

# mapserver-error.log anlegen
RUN chmod 777 /var/log
RUN touch /var/log/mapserver.log
RUN chmod 666 /var/log/mapserver.log

# mapserver.conf kopieren
COPY mapserver.conf /etc/mapserver.conf

# restliche Dateien, z.B. fonts, symbols, mapfiles ...
COPY mapfiles/fonts/ /etc/mapserver/fonts/
COPY mapfiles/styles/ /etc/mapserver/styles/
COPY mapfiles/symbols/ /etc/mapserver/symbols/
COPY mapfiles/*.map /etc/mapserver

# Verzeichnisse für FCGI-Links anlegen
RUN mkdir -p /usr/lib/fcgi-bin/wms/bb/ /usr/lib/fcgi-bin/wms/nrw/

# FCGI-Symlinks anlegen
RUN ln -s /usr/lib/cgi-bin/mapserv /usr/lib/fcgi-bin/wms/bb/boris_bb.fcgi \
    && ln -s /usr/lib/cgi-bin/mapserv /usr/lib/fcgi-bin/wms/bb/umgebungslaerm_bb.fcgi \
    && ln -s /usr/lib/cgi-bin/mapserv /usr/lib/fcgi-bin/wms/nrw/boris_nrw.fcgi

# Apache-Konfiguration aktivieren
COPY configs/*.conf /etc/apache2/conf-available
RUN a2enconf bb nrw
RUN a2disconf serve-cgi-bin

CMD ["apache2ctl", "-D", "FOREGROUND"]
