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
        if [[ "$ext" == "jsp" ]];then
            echo $line >> $domain/temp/jsp.txt
            sort -u $domain//temp/jsp.txt >> $domain/recon/wayback/extensions/jsp.txt
        fi
        if [[ "$ext" == "html" ]];then
            echo $line >> $domain/temp/html.txt
            sort -u $domain//temp/html.txt >> $domain/recon/wayback/extensions/jsp.txt
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
    gowitness file --disable-db -s $domain/recon/httprobe/alive-with-protocol.txt -d $domain/recon/screenshots > /dev/null 2>&1
}

_generate_report(){
    echo "${green}[+]${reset} Generating report for ${yellow}$domain${reset}"

    # Create the report file if it doesn't exist, clear it if it does exist
    echo "" > $domain/report.html

    while IFS= read -r line
    do
        if [[ $line =~ "__%" ]]
        then
            keyword=$(echo $line | sed -e 's/.*__%\(.*\)%__.*/\1/')

            # This works weirdly, sed command cuts the word itself without the __% and %__, but it's still in $line
            case "$keyword" in
                "domain")
                    line=${line/__%domain%__/$domain}
                    ;;
                "numdomains")
                    line=${line/__%numdomains%__/$( wc -l $domain/recon/httprobe/alive.txt | cut -d ' ' -f 1)}
                    ;;
                "subdomains")
                    line=${line/__%subdomains%__/$( cat $domain/recon/httprobe/alive.txt )}
                    ;;
                "screenshots")
                    imgcount=0
                    for entry in "$domain/recon/screenshots/"*
                    do
                        if [[ imgcount -le 3 ]]; then
                            printf "<img class='myImg' src='recon/screenshots/%s' alt='%s' width='300' height='200'>" $(basename $entry) $(basename ${entry%.png})>> $domain/report.html
                            ((imgcount++))
                        else
                            printf "<br>" >> $domain/report.html
                            imgcount=0
                        fi
                    done
                    line=""
                    ;;
                "takeover")
                    line=${line/__%takeover%__/$( [ -s $domain/recon/potential_takeovers/potential_takeovers.txt ] && cat $domain/recon/potential_takeovers/potential_takeovers.txt )}
                    ;;
                "dig")
                    line=${line/__%dig%__/$( dig $domain )}
                    ;;
                "host")
                    line=${line/__%host%__/$( host $domain )}
                    ;;
                "wayback")
                    line=''
                    echo "<ul>" >> $domain/report.html
                        echo "<li>Extensions</li>" >> $domain/report.html
                            echo "<ul>" >> $domain/report.html
                                for entry in "$domain/recon/wayback/extensions/"*
                                do
                                    echo "<li><a href='recon/wayback/extensions/$(basename $entry)'>"$(basename $entry)"</a></li>" >> $domain/report.html
                                done
                            echo "</ul>" >> $domain/report.html
                        echo "<li>Params</li>" >> $domain/report.html
                        echo "<ul>" >> $domain/report.html
                                for entry in "$domain/recon/wayback/params/"*
                                do
                                    echo "<li><a href='recon/wayback/params/$(basename $entry)'>"$(basename $entry)"</a></li>" >> $domain/report.html
                                done
                            echo "</ul>" >> $domain/report.html
                    echo "</ul>" >> $domain/report.html
                    ;;
                "ports")
                    line=${line/__%ports%__/$( cat $domain/recon/scans/scanned.txt.nmap )}
                    ;;
            esac
        fi
        echo "$line" >> $domain/report.html
    done < $basedir/template/$report_template.html


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

# Run the scan programs
#_assetfinder
#_amass
#_httprobe
#_subjack
#_nmap
#_wayback
#_gowitness
# Maybe add more "apps" later

rm -r $domain/temp

echo "${green}Scan for ${yellow}$domain${green} finished${reset}"
duration=$SECONDS
echo "Scan completed in : $(($duration / 60)) minutes and $(($duration % 60)) seconds."

_generate_report