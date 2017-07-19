#!/bin/sh
#
#  hathitrust.sh
#
#  This shell script extracts the HathiTrust XML files from the tar.gz file.  The
#  files are changed to be readable as well.  Once the XML files have been extracted,
#  a Perl script runs over the files to get them into the HathiTrust file format.
#
#   mike, 2016/06/06
#

HATHITRUST_DIR=/home/eprieto/hathitrust_xml

# Make sure we are in the right directory

   cd $HATHITRUST_DIR 

# Unzip the tar.gz files

   gzip -d *.tar.gz

# Extract the XML files from the tar files

   for file in $HATHITRUST_DIR/*.tar
   do
    tar -xvf $file
   done

# Change the output file(s) to be readable

   chmod +r *.xml

# Move all the *.xml files to the proper XML directories for processing

   mv um_monos*.xml $HATHITRUST_DIR/out_bks/xml
   mv um_serials*.xml $HATHITRUST_DIR/out_ser/xml


echo
echo "finished"
   
