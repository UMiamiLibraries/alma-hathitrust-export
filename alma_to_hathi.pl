#!/usr/bin/perl -w
#
#  alma_to_hathi.pl
#
#  This script builds the HathiTrust files from the XML files.  It is based off a script
#  created by Margaret Briand Wolfe from Boston College and modified to meet UT's needs.
#  The parts modified include the filenames, directory paths and names.  I also did heavy
#  editing to the barcode section due to the fact that UTK's barcodes are much different
#  than those at Boston College.  In addition, I added a section for removing the process
#  statuses from the 901z field since we use work order departments, and those statuses
#  were showing up in the final .tsv files.
#
#
#  Mike, 2016/06/23
#

use LWP::UserAgent;
use POSIX;
use XML::XPath;
use XML::XPath::XMLParser;
use XML::Simple;
use Data::Dumper;

($my_day, $my_mon, $my_year) = (localtime) [3,4,5];
$my_year += 1900;
$my_mon += 1;
$my_date = sprintf("%s%02d%02d", $my_year, $my_mon, $my_day);


#Directories for monos and serials
@dir_list = ("out_bks", "out_ser");


$out_mono = sprintf("%s%s%s", "miami.edu_single-part_", $my_date, ".tsv");
$out_multi = sprintf("%s%s%s", "miami.edu_multi-part_", $my_date, ".tsv");
$out_ser = sprintf("%s%s%s", "miami.edu_serials_", $my_date, ".tsv");
$out_log = sprintf("%s%s%s", "miami.edu_log_", $my_date, ".txt");


#Open files. If serials directory open serial file and log
#If not open file for monographs and multi-volume monographs
#Open files in append mode: >>
$ret = $dir_list[0] =~ /_ser/;
print $ret;
if ($ret){
	$ret = open(OUT_SER, ">>$out_ser");
	if ($ret < 1){
		die ("Cannot open file $out_ser");
	}
	$serial_flg = 1;
}else{
	$serial_flg = 0;

	$ret = open(OUT_MONO, ">>$out_mono");
	if ($ret < 1){
		die ("Cannot open file $out_mono");
	}

	$ret = open(OUT_MULTI, ">>$out_multi");
	if ($ret < 1){
		die ("Cannot open file $out_multi");
	}
}


#Open log file to keep count of rejected records (either no OCLC # or no MMS ID)
$ret = open(OUT_LOG, ">>$out_log");
if ($ret < 1){
	die ("Cannot open file $out_log");
}

$rec_out = $rec_rej = 0;

for ($d = 0; $d <= $#dir_list; $d++){

	$path_xml = sprintf("%s%s%s", "/home/eprieto/hathitrust_xml/", $dir_list[$d], "/xml");

	undef @file_list;

	#Open the directory where the xml files are and put them into a sorted array
	opendir(DIR_HATHI, "$path_xml");
	while ($filenm = readdir(DIR_HATHI)){
		push (@file_list, $filenm);
	}

	@file_list = sort {lc($a) cmp lc ($b)} @file_list;
	foreach $filenm (@file_list){
	
		@is_xml = split(/\./, $filenm);
		$no_parts = @is_xml;
		if ($is_xml[$no_parts - 1] eq 'xml'){
		
			$xfile = sprintf("%s%s%s", $path_xml, "/", $filenm);

			#Open XPATH to data
			$xp = XML::XPath->new(filename=>$xfile);

			if ($xp){
			
				$line_out = sprintf("%s%s", "Processing file: ", $xfile);
				print OUT_LOG ("$line_out\n");

				$nodeset = $xp->find('/collection/record');
				foreach my $node ($nodeset->get_nodelist){
				
					$mms_id = "";
					$i = $no_items = $lost = $missing = 0;
					undef @addl_tags;
					undef @addl_data;
					undef @addl_codes;
					undef @itm_cond;
					undef @itm_desc;

					#Grab all controlfields
					foreach my $ctlfld ($node->findnodes('./controlfield')){
					
						$ctl_data = $ctlfld->string_value;
						$ctl_tag = $ctlfld->findvalue('./@tag');

						#If tag is 001 grab MMS ID
						if ($ctl_tag eq '001'){
							$mms_id = $ctl_data;
						}
					}
					$i = $oclc_len = $issn_len = $gov_doc = 0;
					$oclc_no = $issn = "";

					#Grab all of the additional tags and corresponding data for this control field
					foreach my $datafld ($node->findnodes('./datafield')){
					
						$addl_tags[$i] = $datafld->findvalue('./@tag');
						$addl_codes[$i] = $datafld->findvalue('./subfield/@code');
						$addl_data[$i] = $datafld->findvalue('./subfield');

						if ($addl_tags[$i] eq '901'){ #Grab necessary item info
						
							$itm_cond[$no_items] = 'CH'; #Assume item is not lost or missing

							if ($addl_codes[$i] =~ /y/){ #Item description from 901$y
								#Try to split the item description from the rest of the subfield data. Not really sure how to do this since there is no way
								#of knowing what the item description contains but try to break on the barcode prefix (14 digits starting with 3)
								$found_barcode = 0;
								$ret = $addl_data[$i] =~ /3[0-9]{13}/; #Look for a 14 digit barcode beginning with the number 3

								if ($ret){
								
									$ret = $addl_data[$i] =~ /3505/; #Look for the 3502 prefix. This is the most common UM barcode prefix.
									
									if ($ret){
										@subdata = split(/3505/, $addl_data[$i]);
										$itm_desc[$no_items] = $subdata[0];
										$found_barcode++;
									}
								}
							}

							if ($addl_codes[$i] =~ 'z'){ #Process status from 901$z
							
								$found_status = 0;
								$lost = $addl_data[$i] =~ /LOST/;
								$missing = $addl_data[$i] =~ /MISSING/;


								if ($lost || $missing){
									$itm_cond[$no_items] = 'LM'; #Set condition to Lost Missing
								}

								if (!$found_status){
									$ret = $addl_data[$i] =~ /LOST_LOAN/;
									if ($ret){
										@subdata = split(/LOST_LOAN/, $addl_data[$i]);
										$itm_desc[$no_items] = $subdata[0];
										$found_status++;
									}
								}

								if (!$found_status){
									$ret = $addl_data[$i] =~ /CLAIM_RETURNED_/;
									if ($ret){
										@subdata = split(/CLAIM_RETURNED_/, $addl_data[$i]);
										$itm_desc[$no_items] = $subdata[0];
										$found_status++;
									}
								}

								if (!$found_status){
									$ret = $addl_data[$i] =~ /LOAN/;
									if ($ret){
										@subdata = split(/LOAN/, $addl_data[$i]);
										$itm_desc[$no_items] = $subdata[0];
										$found_status++;
									}
								}

								if (!$found_status){
									$ret = $addl_data[$i] =~ /TECHNICAL/;
									if ($ret){
										@subdata = split(/TECHNICAL/, $addl_data[$i]);
										$itm_desc[$no_items] = $subdata[0];
										$found_status++;
									}
								}

								if (!$found_status){
									$ret = $addl_data[$i] =~ /TRANSIT/;
									if ($ret){
										@subdata = split(/TRANSIT/, $addl_data[$i]);
										$itm_desc[$no_items] = $subdata[0];
										$found_status++;
									}
								}

								if (!$found_status){
									$ret = $addl_data[$i] =~ /WORK_ORDER_DEPARTMENT/;
									if ($ret){
										@subdata = split(/WORK_ORDER_DEPARTMENT/, $addl_data[$i]);
										$itm_desc[$no_items] = $subdata[0];
										$found_status++;
									}
								}
							}

							#Don't really need to do anything if addl_code is a x - this is a barcode. It just contributes to the item count as do item desc & process status
							$no_items++;
						}

						$i++;
					}

					#Loop through the tags and grab the OCLC number, ISSN's and check to see if government document
					for ($j = 0; $j < $i; $j++){
						#Get OCLC number
						if ($addl_tags[$j] eq '035'){
							$ret = $addl_data[$j] =~ /OCoLC/;
							if ($ret){
								$oclc_no = $addl_data[$j];
								$oclc_len = length($oclc_no);
							}
						}

						#Is this a journal/issue/serials?
						if ($addl_tags[$j] eq '022'){
							$issn = $addl_data[$j];
							$issn_len = length($issn);
							if ($issn_len >= 9){
								$no_issns = $issn_len / 9;

								if ($no_issns >= 2){ #More than 1 issn in the list?
									for ($k = 0, $l = 0; $k < $no_issns; $k++){
										$issns[$k] = substr($issn, $l, 9);
										$l += 9;
									}

									$no_issns = @issns;

									for ($k = 0; $k < $no_issns; $k++){
										if ($k == 0){
											$issn = $issns[$k];
										}else{ 
											#Put a comma between each issn in the list
											$issn_len = length($issns[$k]);
											#Make sure issn has a length of 9 before using it
											if ($issn_len == 9){
												$issn = sprintf("%s%s%s", $issn, "\,", $issns[$k]);
											}
										}
									}

									$issn_len = length($issn);
								}
							}
						}

						#Check for government document by presence of 074 tag
						if ($addl_tags[$j] eq '074'){
							$gov_doc = 1;
						}

					}

					if ($oclc_len && $mms_id){ #Both are required fields. If either one is missing skip this entry.
						#If here have an MMS ID and OCLC # and no items then just have a bib and holding record in Alma. Still want to send it.
						#This is always the case for serials since we only count them at the title level.
						if (!$no_items){
							$itm_cond[0] = 'CH';
							$itm_desc[0] = "";
							$no_items++;
						}

						#Print a record for each item
						for ($k = 0; $k < $no_items; $k++){

							#Fields Hathi Trust is looking for (tab separated):
							#OCLC No, MMS ID, Holding Status (current holding, withdrawn, lost or missing), Condition, Enumeration (in our desc field), ISSN, Gov Doc #
							#The only fields of the above that are required are OCLC # and MMS #/System #. We also provide enumeration since that's the only way I know if this is a multi-volume set and gov doc indicator.
							#The rest is too complicated to send. Since it's not required we are not sending it. Maybe when Alma gets easier to pull the information out.
							if ($serial_flg){ #Journal/Issue/Serial
								$line_out = sprintf("%s%s%s%s%s%s%s%s%s%s%s", $oclc_no, "\t", $mms_id, "\t", $itm_cond[$k], "\t", "\t", "\t", $issn, "\t", $gov_doc);
								print OUT_SER ("$line_out\n");
								$rec_out++;
							}elsif ($itm_desc[$k]){ #multi-part monograph
								$line_out = sprintf("%s%s%s%s%s%s%s%s%s%s%s", $oclc_no, "\t", $mms_id, "\t", $itm_cond[$k], "\t", "\t", $itm_desc[$k], "\t", "\t", $gov_doc);
								print OUT_MULTI ("$line_out\n");
								$rec_out++;
							}else{ #Single monograph
								$line_out = sprintf("%s%s%s%s%s%s%s%s%s%s", $oclc_no, "\t", $mms_id, "\t", $itm_cond[$k], "\t", "\t", "\t", "\t", $gov_doc);
								print OUT_MONO ("$line_out\n");
								$rec_out++;
							}
						}
					}else{ #Record rejected
						$line_out = sprintf("%s%s%s%s%s%s%s%s%s", $oclc_no, "\t", $mms_id, "\t", "\t", "\t", "\t", "\t", $gov_doc);
						print OUT_LOG ("$line_out\n");
						$rec_rej++;
					}
				}
			}
		}
	}

	closedir (DIR_HATHI);

}

$line_out = sprintf("%s%s%s%s", "Records output: ", $rec_out, " Records rejected: ", $rec_rej);
print OUT_LOG ("$line_out\n");

close (OUT_MONO);
close (OUT_MULTI);
close (OUT_SER);
close (OUT_LOG);

exit;