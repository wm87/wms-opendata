#!/bin/bash

cd /data/boris_nrw

rm /data/boris_nrw/*
wget -O /data/boris_nrw/boris_nrw.zip "https://www.opengeodata.nrw.de/produkte/infrastruktur_bauen_wohnen/boris/BRW/BRW_EPSG25832_Shape.zip"
unzip boris_nrw.zip -x "*.pdf*" "*.xls*"
rm /data/boris_nrw/*.zip
