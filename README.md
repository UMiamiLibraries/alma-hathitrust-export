# alma-hathitrust-export

scripts to process hathi trust extract files from alma. 
https://knowledge.exlibrisgroup.com/Alma/Training/Extended_Training/Presentations_and_Documents_-_Hathi_Trust

## hathitrust.sh

extract tar.gz files to get xmls. Created by Mike Rogers from UTK, modified by Eduardo Prieto.

## alma_to_hathi.pl

parses the xmls and creates tsv files that we send to hathitrust. Created by Margaret Briand Wolfe from BC, modified by Mike Rogers from UTK, further modified by Eduardo Prieto to fit UM needs.

## dedup.py
reads final output tsv and uses pandas to remove duplicate entires.

## summary.sh

creates a statistics txt file with total records processed. Created by Eduardo Prieto.
