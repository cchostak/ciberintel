#!/bin/bash
#Created by Christian Chostak

#Receive the argument passed when calling the script. Tipically you can run by typing: ./script.sh PATH_TO_PCAP NAME_OF_THE_SEARCH
#e.g. ./script.sh /home/usr/file.pcap testPcap
#path will receive the path to pcap
#filename will receive the name of the search
path=$1
filename=$2

#Test if the path was informed, if not, ask to type in where the pcap can be found
if [ -z "$path" ]
then
	echo Inform the path to pcap file, you are here:
	read path
fi

#Test if the filename was informed, if not, ask to type in the name of this particular search
if [ -z "$filename" ]
then
	echo Inform how would you like to save your search:
	read filename
fi

#Create directories to host data
mkdir ./$filename
mkdir ./$filename/whitelist
mkdir ./$filename/blacklist
mkdir ./$filename/greylist
mkdir ./$filename/alexa

#Download from Amazon file used to create whitelist, and MalwareDomains to create Malware list
wget -P ./$filename/alexa/ http://s3.amazonaws.com/alexa-static/top-1m.csv.zip
wget -P ./$filename/blacklist http://mirror1.malwaredomains.com/files/immortal_domains.txt

#Unzip file downloaded
unzip ./$filename/alexa/top-1m.csv.zip -d ./$filename/alexa/

#Read file downloaded from Alexa, and generates the column that provides Name Servers
cat ./$filename/alexa/top-1m.csv | awk -F',' '{print $2}' >> ./$filename/alexa/verified.txt

#Read the PCAP file, print only wanted information, removes unwanted characters, removes known local ip addresses
tcpdump -qns 0 -X -r./$path | awk '/IP / {print $3}' | awk -F'.' '{print $1 , $2 , $3 , $4}' | sed -e 's/ /./g' -e '/10./d' -e '/172.16.?/d' -e '/192.168./d' -e '/172.31.?/d' | awk '!seen[$0]++' >> ./$filename/$filename.txt

#Iterates through file from PCAP discovering the DNS from each IP
while IFS='' read -r line || [[ -n "$line" ]]; do
	nslookup $line >> ./$filename/$filename.dns1			
done < "./$filename/$filename.txt"

#Filter file above, taking only the name server and removing unwanted marks
cat ./$filename/$filename.dns1 | awk '/name =/ {print $4}' | sed -e 's/.$//g' >> ./$filename/$filename.dns

#Match file downloaded from Alexa, and DNS retrieved from PCAP
awk 'FNR==NR{a[$1];next}($1 in a){print}' ./$filename/alexa/verified.txt ./$filename/$filename.dns >> ./$filename/whitelist/white.domains

#Match file downloaded from MalWareDomains and DNS retrieved from PCAP
awk 'FNR==NR{a[$1];next}($1 in a){print}' ./$filename/blacklist/immortal_domains.txt ./$filename/$filename.dns >> ./$filename/blacklist/black.domains

#Create algorithm to score domain name
while IFS='' read -r line || [[ -n "$line" ]]; do
#       year="$(whois $line | awk '/Creation Date:/ {print $3}' | awk '{print substr($1,1,4)}')"
#       if [ "$year" > 0 ]
#       then
        bytes="$(echo $line | ent -t | awk -F',' 'FNR==2{print $2}')"
        chiScore="$(echo $line | ent -t | awk -F',' 'FNR==2{print $4}')"
#       score="$(echo $line | ent -t | awk -F',' '{print $3}' | sed -e '/Entropy/d')"
        score="$(echo "scale=2;($bytes * $chiScore)/1000" | bc -l)"
        echo  DOMAIN ANALIZED:  $line, SCORE GIVEN:      $score, A VALUE GREATER THAN 15 IS HIGHLY RISKY $'\r'  >> ./$filename/greylist/grey.domains
#       else
#               echo $line SCORE 5
#       fi
done < "./$filename/$filename.dns"

rm -rf ./$filename/$filename.dns1

