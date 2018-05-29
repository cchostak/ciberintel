#!/bin/bash
#Created by Christian Chostak

#Receive the argument passed when calling the script. Tipically you can run by typing: ./script.sh PATH_TO_PCAP NAME_OF_THE_SEARCH
#e.g. ./script.sh /home/usr/file.pcap testPcap
#path will receive the path to pcap
#filename will receive the name of the search
filepath=$1
filename=$2

#Test if the path was informed, if not, ask to type in where the pcap can be found
if [ -z "$filepath" ]
then
	echo Inform the path, you are here:
	read filepath
fi

#Test if the filename was informed, if not, ask to type in the name of this particular search
if [ -z "$filename" ]
then
	echo Inform how would you like to save your search:
	read filename
fi

#MySQL variables
DB_USER=
DB_PASS=

#Alter to geoiplookup path, generaly /usr/local/share/GeoIP
GEOIP=/usr/local/share/GeoIP/geo.dat;

#Create database and tables
mysql --user=$DB_USER --password=$DB_PASS<<EOF
CREATE DATABASE $filename;
EOF

#Create a directory to store the files that will be generate below
mkdir $filename

#Iterates through the file created above, reading line by line, and doing at each step the geoiplookup, whois and nslookup programs
while IFS='' read -r line || [[ -n "$line" ]]; do
	nmap -p 80,443 $line | awk '/tcp/ {print $1, $2, $3}' >> "./$filename/$filename-NMAP.txt"
done < "$filepath"

while IFS='' read -r line || [[ -n "$line" ]]; do
	whois $line >> ./$filename/$filename-WHOIS.txt
done < "$filepath"

while IFS='' read -r line || [[ -n "$line" ]]; do
	nslookup $line | awk 'BEGIN {ORS=" |Answer from, "}, /Address/ {print $1, $2}' >> ./$filename/$filename-NSLOOKUP.txt
done < "$filepath"

while IFS='' read -r line || [[ -n "$line" ]]; do
	geoiplookup -f $GEOIP $line >> ./$filename/$filename-GEOIP.txt
done < "$filepath"

while IFS='' read -r line || [[ -n "$line" ]]; do
	webkit-image-gtk http://$line > ./$filename/$line.png
done < "$filepath"

#Reads the GeoIP generated file and filters only the columns that provide useful data
cat ./$filename/$filename-GEOIP.txt | awk -F',' '{print $2, $3, $4, $5, $7, $8}' | sed -e 's/Rev 1://g' >> ./$filename/$filename-GEO-IP.txt

#Reads the WhoIS generated file and filters only the columns that provide useful data
cat ./$filename/$filename-WHOIS.txt | awk '/Name Server:/ {print $1, $2, $3}; /Domain Name:/ {print $1, $2, $3}; /Creation Date:/ {print $1, $2, $3}; /Updated Date:/ {print $1, $2, $3}; /Registry Expiry Date:/ {print $1, $2, $3, $4}; /Admin Email:/ {print $1, $2, $3}' >> ./$filename/$filename-WHO-IS.txt

#Removes unwanted files
rm -rf /$filename/$filename-GEOIP.txt /$filename/$filename-WHOIS.txt
