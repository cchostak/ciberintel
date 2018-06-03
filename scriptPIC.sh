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

sufix="PIC"
filename=$filename$sufix

#MySQL variables
DB_USER=root
DB_PASS=

#Alter to geoiplookup path, generaly /usr/local/share/GeoIP
GEOIP=./geo.dat

#Creates database
mysql --user=$DB_USER --password=$DB_PASS<<EOF
CREATE DATABASE $filename;
USE $filename;
CREATE TABLE $filename (ID int NOT NULL AUTO_INCREMENT, DOMAIN varchar(255), DATE TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, LOOKUP_1 varchar(255), LOOKUP_2 varchar(255), LOOKUP_3 varchar(255), DOMAINNAME varchar(255), UPDATEDDATE varchar(255), CREATIONDATE varchar(255), COUNTRY varchar(255), STATE varchar(255), STATE_DESC varchar(255), CITY varchar(255), LAT varchar(255), LON varchar(255), PORT80STATUS varchar(255), PORT443STATUS varchar(255), PRIMARY KEY(ID));
EOF

#Create a directory to store the files that will be generate below
mkdir $filename

while IFS='' read -r line || [[ -n "$line" ]]; do
        sleep 0.1
        nsl1="$(nslookup $line | grep Address | awk  '/Address/ {print $2}' | awk 'NR==1')"

        sleep 0.1
        nsl2="$(nslookup $line | grep Address | awk  '/Address/ {print $2}' | awk 'NR==1')"

        sleep 0.1
        nsl3="$(nslookup $line | grep Address | awk  '/Address/ {print $2}' | awk 'NR==1')"

        sleep 0.1
        whsdn="$(whois $line | grep "Domain Name" | awk  '{print $3}' | tr -cd 'A-Za-z0-9_.-')"

        sleep 0.1
        whsud="$(whois $line | grep "Updated Date" | awk  '{print $3}' | tr -cd 'A-Za-z0-9_.-')"

        sleep 0.1
        whscd="$(whois $line | grep "Creation Date" | awk  '{print $3}' | tr -cd 'A-Za-z0-9_.-')"

        sleep 0.1
        gilCountry="$(geoiplookup -f $GEOIP $line | awk -F',' '{print $2}' | sed -e 's/Rev 1://g' | tr -cd 'A-Za-z0-9_.-' )"

        sleep 0.1
		gilState="$(geoiplookup -f $GEOIP $line | awk -F',' '{print $3}' | sed -e 's/Rev 1://g' | tr -cd 'A-Za-z0-9_.-' )"

        sleep 0.1
		gilStateDesc="$(geoiplookup -f $GEOIP $line | awk -F',' '{print $4}' | sed -e 's/Rev 1://g' | tr -cd 'A-Za-z0-9_.-' )"

        sleep 0.1
		gilCity="$(geoiplookup -f $GEOIP $line | awk -F',' '{print $5}' | sed -e 's/Rev 1://g' | tr -cd 'A-Za-z0-9_.-' )"

        sleep 0.1
		gilLat="$(geoiplookup -f $GEOIP $line | awk -F',' '{print $7}' | sed -e 's/Rev 1://g' | tr -cd 'A-Za-z0-9_.-' )"

        sleep 0.1
		gilLon="$(geoiplookup -f $GEOIP $line | awk -F',' '{print $8}' | sed -e 's/Rev 1://g' | tr -cd 'A-Za-z0-9_.-' )"

        sleep 0.1
        sleep 0.1
        nmap80="$(nmap $line | grep 80 | awk  '{print $2}' | tr -cd 'A-Za-z0-9_.-')"

        sleep 0.1
        nmap443="$(nmap $line | grep 443 | awk  '{print $2}' | tr -cd 'A-Za-z0-9_.-')"

		webkit-image-gtk http://$line > ./$filename/$line.png

	    mysql --user=$DB_USER --password=$DB_PASS $filename -e 'INSERT INTO '$filename' (DOMAIN, LOOKUP_1, LOOKUP_2, LOOKUP_3, DOMAINNAME, UPDATEDDATE, CREATIONDATE, COUNTRY, STATE, STATE_DESC, CITY, LAT, LON, PORT80STATUS, PORT443STATUS) VALUES ("'$line'", "'$nsl1'", "'$nsl2'", "'$nsl3'", "'$whsdn'", "'$whsud'", "'$whscd'", "'$gilCountry'", "'$gilState'", "'$gilStateDesc'", "'$gilCity'", "'$gilLat'", "'$gilLon'", "'$nmap80'", "'$nmap443'");'

done < "$filepath"

#Removes unwanted files
rm -rf /$filename/$filename-GEOIP.txt /$filename/$filename-WHOIS.txt
