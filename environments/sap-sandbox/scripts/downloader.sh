#!/bin/bash

DIR=$(dirname $0)

while [ $# -gt 0 ]; do
  if [[ $1 == *"--"* ]]; then
    param="${1/--/}"
    declare PARAM_${param^^}="$2"
    # echo "PARAM_${param^^}=$2"
  fi
  shift
done

fail () {
    echo >&2 "$@"
    exit 1
}

[ -z "$PARAM_USERNAME" ] && { PARAM_USERNAME="$SAPUSERNAME"; } 
[ -z "$PARAM_USERNAME" ] && fail "Missing username"

[ -z "$PARAM_PASSWORD" ] && { PARAM_PASSWORD="$SAPPASSWORD"; } 
[ -z "$PARAM_PASSWORD" ] && fail "Missing password"

[ -z "$PARAM_PACKAGES" ] && fail "Missing packages"

readonly DOWNLOAD_ROOT="$DIR/downloads"
rm -rf $DOWNLOAD_ROOT > /dev/null

while read TOKEN; do
	[ -z "$TOKEN" ] || { PACKAGES+=( "$TOKEN" ); }
done < <( echo "$PARAM_PACKAGES" | tr ";" "\n" )

for PACKAGE in "${PACKAGES[@]}"; do
	
	mkdir -p "$DOWNLOAD_ROOT/$PACKAGE" && pushd "$DOWNLOAD_ROOT/$PACKAGE" > /dev/null

	while read LINE; do
		[[ "$LINE" = "https://softwaredownloads.sap.com/file/"* ]] && { URLS+=( "$LINE" ); }
	done < <( curl -s "https://raw.githubusercontent.com/lnwsoft/phoenix-repo-downloader/main/packages/$PACKAGE.lst" )

	for URL in "${URLS[@]}"; do

		echo -e "\nDownloading file $URL into $PWD ...\n"
		
		wget --user=$PARAM_USERNAME --password=$PARAM_PASSWORD \
			 --content-disposition --trust-server-names --auth-no-challenge -q --show-progress \
			 --user-agent="SAP Download Manager"  \
			 $URL

	done

	popd > /dev/null

done

