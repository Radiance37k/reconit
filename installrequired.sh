#!/bin/bash

echo "This script does NOT install and/or set up golang."

command -v assetfinder >/dev/null 2>&1 || {
	echo "assetfinder not found, installing...";
	go get -u github.com/tomnomnom/assetfinder
}
command -v httprobe >/dev/null 2>&1 || {
	echo "httprobe not found, installing...";
	go get -u github.com/tomnomnom/httprobe
}
command -v waybackurls >/dev/null 2>&1 || {
	echo "waybackurls not found, installing...";
	go get github.com/tomnomnom/waybackurls
}

command -v amass >/dev/null 2>&1 || {
	echo "amass not found, installing...";
	apt-get update
	apt-get install -y amass
}

command -v subjack >/dev/null 2>&1 || {
	echo "subjack not found, installing...";
	go get github.com/haccer/subjack
}

command -v nmap >/dev/null 2>&1 || {
	echo "nmap not found, installing...";
	apt-get update
	apt-get install -y nmap
}

command -v gowitness >/dev/null 2>&1 || {
	echo "gowitness not found, installing...";
	go get -u github.com/sensepost/gowitness
}

echo "All done."