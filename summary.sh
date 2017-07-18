#!/bin/sh
#
# Create summary file with number of records processed and rejected
#
# Created by Eddie Prieto 7/17/2017
#

DIR=final_extracts_2017
FILE=$DIR/summary.txt
DATE=20170717

touch $FILE

echo "Writing to $FILE" 

echo "Monos" >> $FILE
echo "" >> $FILE
tail -n1 $DIR/um_monos_log_$DATE.txt | awk '{print "Total Monographs Processed: ", $3+$6}' >> $FILE
tail -n1 $DIR/um_monos_log_$DATE.txt >> $FILE
wc -l $DIR/um_spm_$DATE.tsv | awk '{print "Single Part Monographs: ", $1}' >> $FILE
wc -l $DIR/um_mpm_$DATE.tsv | awk '{print "Multi Part Monographs: ", $1 }' >> $FILE
echo ""
echo "Serials" >> $FILE
echo "" >> $FILE
tail -n1 $DIR/um_serials_log_$DATE.txt | awk '{print "Total Serials Processed: ", $3+$6}' >> $FILE
tail -n1 $DIR/um_serials_log_$DATE.txt >> $FILE
wc -l $DIR/um_serials_$DATE.tsv | awk '{print "Serials: ", $1 }'>> $FILE


