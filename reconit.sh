#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  basedir="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
basedir="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

# Needs a full path to the config file
source $basedir/reconit.conf

# Set SECONDS to 0 to time the duration of the script
SECONDS=0

# Print usage info
_usage() { echo -e "Usage: ./reconit.sh domain.com\n " 1>&2; exit 1; }

# Print a superawesome logo banner
_logo(){
  echo "${red}"
  echo " _______  _______  _______  _______  _       __________________"
  echo "(  ____ )(  ____ \(  ____ \(  ___  )( (    /|\__   __/\__   __/"
  echo "| (    )|| (    \/| (    \/| (   ) ||  \  ( |   ) (      ) (   "
  echo "| (____)|| (__    | |      | |   | ||   \ | |   | |      | |   "
  echo "|     __)|  __)   | |      | |   | || (\ \) |   | |      | |   "
  echo "| (\ (   | (      | |      | |   | || | \   |   | |      | |   "
  echo "| ) \ \__| (____/\| (____/\| (___) || )  \  |___) (___   | |   "
  echo "|/   \__/(_______/(_______/(_______)|/    )_)\_______/   )_(   "
  echo "                                                               "
  echo "${reset}"
}

# Check for number of arguments
if [ "$#" -ne 1 ]; then
    _usage
fi

# Sets the domain variable to argument provided
domain=$1

# In order to not clash with binaries, functions have an _ added in front.

# Runs assetfinder
_assetfinder(){
    echo "${green}[+]${reset} Harvesting subdomains with ${yellow}assetfinder${reset}..."
    assetfinder $domain >> $domain/temp/assetfinder.txt
    cat $domain/temp/assetfinder.txt | grep $domain >> $domain/recon/final.txt
}

# Runs amass
_amass(){
    echo "${green}[+]${reset} Double checking subdomains with ${yellow}amass${reset}..."
    echo "    ${red}Grab some coffee, this might take a while...${reset}"
    amass enum -d $domain -o $domain/temp/amass.txt > /dev/null 2>&1    

    cat $domain/recon/final.txt >> $domain/temp/amass.txt

    sort -u $domain/temp/amass.txt > $domain/recon/final.txt
}

# Runs httprobe and creates two files, one without protocol, one with (May include duplicates HTTP/S)
_httprobe(){
    echo "${green}[+]${reset} Probing for alive domains..."
    cat $domain/recon/final.txt | sort -u | httprobe >> $domain/temp/httprobe.txt
    cat $domain/temp/httprobe.txt | sed 's/https\?:\/\///' | sort -u > $domain/recon/httprobe/alive.txt
    sort -u $domain/temp/httprobe.txt > $domain/recon/httprobe/alive-with-protocol.txt
}

# Runs subjack
_subjack(){
    echo "${green}[+]${reset} Checking for possible subdomain takeovers..."
    sort -u $domain/recon/final.txt >> $domain/temp/takeover.txt
    subjack -w $domain/temp/takeover.txt -t 100 -timeout 30 -ssl -c ~/go/src/github.com/haccer/subjack/fingerprints.json -v 3 -o $domain/recon/potential_takeovers/potential_takeovers.txt > /dev/null 2>&1
}

# Runs nmap on common ports
_nmap(){
    echo "${green}[+]${reset} Scanning for open ports..."
    nmap -iL $domain/recon/httprobe/alive.txt -T4 -oA $domain/recon/scans/scanned.txt > /dev/null
}

# Grabs info from the wayback machine
_wayback(){
    echo "${green}[+]${reset} Scraping wayback data..."

    cat $domain/recon/final.txt | waybackurls > $domain/temp/wayback_output.txt

    sort -u $domain/temp/wayback_output.txt > $domain/recon/wayback/wayback_output.txt

    echo "${green}[+]${reset} Pulling and compiling all possible params found in wayback data..."
    cat $domain/recon/wayback/wayback_output.txt | grep '?*=' | cut -d '=' -f 1 | sort -u >> $domain/recon/wayback/params/wayback_params.txt

    echo "${green}[+]${reset} Pulling and compiling js/php/aspx/jsp/json files from wayback output..."
    for line in $(cat $domain/recon/wayback/wayback_output.txt);do
        ext="${line##*.}"
        if [[ "$ext" == "js" ]]; then
            echo $line >> $domain/temp/js.txt
            sort -u $domain/temp/js.txt >> $domain/recon/wayback/extensions/js.txt
        fi
        if [[ "$ext" == "html" ]];then
            echo $line >> $domain/temp/jsp.txt
            sort -u $domain//temp/jsp.txt >> $domain/recon/wayback/extensions/jsp.txt
        fi
        if [[ "$ext" == "json" ]];then
            echo $line >> $domain//temp/json.txt
            sort -u $domain/temp/json.txt >> $domain/recon/wayback/extensions/json.txt
        fi
        if [[ "$ext" == "php" ]];then
            echo $line >> $domain/temp/php.txt
            sort -u $domain/temp/php.txt >> $domain/recon/wayback/extensions/php.txt
        fi
        if [[ "$ext" == "aspx" ]];then
            echo $line >> $domain/temp/aspx.txt
            sort -u $domain/temp/aspx.txt >> $domain/recon/wayback/extensions/aspx.txt
        fi
    done
}

_gowitness(){
    echo "${green}[+]${reset} Using ${yellow}gowitness${reset} to grab screenshots..."
    gowitness file -s $domain/recon/httprobe/alive-with-protocol.txt -d $domain/recon/screenshots > /dev/null 2>&1
}

_generate_report(){
    echo "${red}[-]${reset} Report generation not done yet"
    # TODO:
    # Read the file from $basedir/template/$report_template line by line
    # check if one of the keywords are hit
    # Echo out relevant info to report file
    # else echo the line to report file

    # TODO devhints.html
    # Add screenshots as modal

}

# Check for required programs
command -v assetfinder >/dev/null 2>&1 || { echo >&2 "assetfinder required, program not found.  Aborting."; exit 1; }
command -v amass >/dev/null 2>&1 || { echo >&2 "amass required, program not found.  Aborting."; exit 1; }
command -v httprobe >/dev/null 2>&1 || { echo >&2 "httprobe required, program not found.  Aborting."; exit 1; }
command -v subjack >/dev/null 2>&1 || { echo >&2 "subjack required, program not found.  Aborting."; exit 1; }
command -v nmap >/dev/null 2>&1 || { echo >&2 "nmap required, program not found.  Aborting."; exit 1; }
command -v gowitness >/dev/null 2>&1 || { echo >&2 "gowitness required, program not found.  Aborting."; exit 1; }

# Create folders for the scan if they do not exist
[ ! -d "$domain" ] && mkdir $domain
[ ! -d "$domain/temp" ] && mkdir $domain/temp
[ ! -d "$domain/recon" ] && mkdir $domain/recon
[ ! -d "$domain/recon/scans" ] && mkdir $domain/recon/scans
[ ! -d "$domain/recon/httprobe" ] && mkdir $domain/recon/httprobe
[ ! -d "$domain/recon/potential_takeovers" ] && mkdir $domain/recon/potential_takeovers
[ ! -d "$domain/recon/wayback" ] && mkdir $domain/recon/wayback
[ ! -d "$domain/recon/wayback/params" ] && mkdir $domain/recon/wayback/params
[ ! -d "$domain/recon/wayback/extensions" ] && mkdir $domain/recon/wayback/extensions
[ ! -d "$domain/recon/screenshots" ] && mkdir $domain/recon/screenshots

clear
_logo

echo "${green}Recon initiated."
echo "Target: ${yellow}$domain ${reset}"

if [ "$run_assetfinder" = true ] ; then
    _assetfinder
fi
if [ "$run_amass" = true ] ; then
    _amass
fi
if [ "$run_httprobe" = true ] ; then
    _httprobe
fi
if [ "$run_subjack" = true ] ; then
    _subjack
fi
if [ "$run_nmap" = true ] ; then
    _nmap
fi
if [ "$run_wayback" = true ] ; then
    _wayback
fi
if [ "$run_gowitness" = true ] ; then
    _gowitness
fi
# Add more "apps" from lazyrecon later

rm -r $domain/temp

echo "${green}Scan for ${yellow}$domain${green} finished${reset}"
duration=$SECONDS
echo "Scan completed in : $(($duration / 60)) minutes and $(($duration % 60)) seconds."

#today=$(date +"%Y-%m-%d")

_generate_report