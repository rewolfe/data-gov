# data-gov
Harvesting from Data.gov</p>
This is a development area for a tool that harvests climate data sets from data.gov and adds them 
to USGCRP GCIS.

Notes:

geo-ingest.pl - Reads ckan and iso metadata from data.gov; creates yaml on stdout; remove "errors" at 
of file before using in downstream programs; output example is data/geo_ingest.txt

map-org.pl - Gets the unique organizations and tries to map them to GCIS organizations; 
use data/geo_ingest.txt as stdin; creates yaml on stdout; output example is data/map_org.txt

get-iso.pl - For NASA datasets, reads CMR (ECDO/REVERB) iso metadata and creates GCIS metadata; use data/geo_ingest.txt 
as stdin; creates yaml on stdout; output example is data/get_iso.txt

Iso.pm - Perl library to read iso 19115.2 metadata

check-meta.pl - Checks metadata against GCIS metadata and reports differences; 
use data/geo_ingest.txt as stdin; creates yaml on stdout; output example is data/check_meta.txt

data/* - Example output data

To be done:

Check more fields (e.g. instruments/platforms) against GCIS; populate more GCIS fields; actually update GCIS metadata (new script); add GCIS lexicon for data.gov (for dataset ids); work with other agency data; etc.
