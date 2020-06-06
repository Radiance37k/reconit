```
 _______  _______  _______  _______  _       __________________
(  ____ )(  ____ \(  ____ \(  ___  )( (    /|\__   __/\__   __/
| (    )|| (    \/| (    \/| (   ) ||  \  ( |   ) (      ) (   
| (____)|| (__    | |      | |   | ||   \ | |   | |      | |   
|     __)|  __)   | |      | |   | || (\ \) |   | |      | |   
| (\ (   | (      | |      | |   | || | \   |   | |      | |   
| ) \ \__| (____/\| (____/\| (___) || )  \  |___) (___   | |   
|/   \__/(_______/(_______/(_______)|/    )_)\_______/   )_(   
                                                               
```

# Usage:
`./reconit.sh somedomain.com`

# About:
You can create a symlink to the script, it handles that in order to find the config and template files.

## Why this script exists:
I was told about a script called Lazyrecon, but I couldn't get it to work. Upon trying to debug it I realized the code was a mess and not very modular, so it was hard for me to debug it. I refurbished it and got to understand it better, but while I was doing that I found another script by The Cyber Mentor which did the same but was much cleaner in my opinion.

So instead I re-did the script again using TCM's script as a base, but made it more modular and intend to expand it even further.

# Installation:
Before running the installrequired script, make sure golang is installed correctly.
Also make sure that `GOPATH=~/go` and `GO111MODULE=on` are set.

```
git clone https://github.com/Radiance37k/reconit.git
cd recon
bash ./installrequired.sh
chmod +x reconit.sh
```

## Requirements
In order to make this script work there are a few programs that you need to have installed.\
Assetfinder\
Amass\
httprobe\
subjack\
nmap\
waybackurls\
gowitness

You can install them all by using the provided `installrequired.sh` script.

# The config file `reconit.conf`
As of now, only one variable is in the conf file. The template to be used.\
Default: `report_template=devhints`

In this case the template file used is `reconit/template/devhints.html`

# Template system
The script uses a template for the report In order to create one, just create a normal HTML file with certain keywords where the script should include info from the scans. All keywords have a leading `__%` and a trailing `__%`

Keywords in template | Description
------------ | -------------
`__%domain%__` | Name of domain
`__%numdomains%__` | Number of scanned subdomains
`__%subdomains%__` | List of all subdomains
`__%screenshots%__` | Table with all screenshots
`__%takeover%__` | List of all subdomin takeover vulnerabilities
`__%dig%__` | DIG info
`__%host%__` | Host info
`__%wayback%__` | Wayback data
`__%ports%__` | List of open ports, nmap

# Thanks
Thanks to:\
nahamsec for creating Lazyrecon\
TCM for being an awesome and a really generous guy and providing the baseline for this script\
Argot for pointing me to Lazyrecon and getting this started

Tomnomnom for writing assetfinder, httprobe and waybackurls\
OWASP for writing amass\
Haccer for writing subjack\
Gordon Lyon for writing nmap\
Sensepost for writing gowitness

You for taking the time to read this and possibly using my script


# TO DO
List empty for now :)