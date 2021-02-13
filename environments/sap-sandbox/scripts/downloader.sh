#!/bin/bash

set -e
trap 'catch $? $LINENO' EXIT

readonly DIR=$(dirname $0)
readonly DOWNLOAD="$DIR/../download"

# re-create download directory and initialize log
rm -rf $DOWNLOAD && mkdir -p "$DOWNLOAD" && cd "$DOWNLOAD"
exec &> >(tee -a "_downloader.$EPOCHSECONDS.log") 

catch() {
  if [ "$1" != "0" ]; then
    # error handling goes here
    echo "Error $1 occurred on $2"
  fi
}

fail () {
    echo >&2 "$@"
    exit 1
}

while [ $# -gt 0 ]; do
  if [[ $1 == *"--"* ]]; then
    param="${1/--/}"
    declare PARAM_${param^^}="$2"
    # echo "PARAM_${param^^}=$2"
  fi
  shift
done

[ -z "$PARAM_SAPUSERNAME" ] && { PARAM_SAPUSERNAME="$SAPUsername"; } 
[ -z "$PARAM_SAPUSERNAME" ] && fail "Parameter --SAPUsername is mandatory"
[ -z "$PARAM_SAPPASSWORD" ] && { PARAM_SAPPASSWORD="$SAPPassword"; } 
[ -z "$PARAM_SAPPASSWORD" ] && fail "Parameter --SAPPassword is mandatory"
[ -z "$PARAM_PACKAGE" ] && fail "Parameter --Package is mandatory"

# install a full featured wget
echo -e "\nUpgrading wget ...\n"
apk update && apk add wget

while read LINE; do
	[[ "$LINE" = "https://softwaredownloads.sap.com/file/"* ]] && { URLS+=( "$LINE" ); }
done < <( curl -s "https://raw.githubusercontent.com/lnwsoft/phoenix-repo-downloader/main/packages/$PARAM_PACKAGE.lst" )

echo -e "\nEnqueueing downloads ...\n"

for URL in "${URLS[@]}"; do

	echo "Downloading $URL ==> $PWD"
	
	wget --user="$PARAM_SAPUSERNAME" --password="$PARAM_SAPPASSWORD" \
		--content-disposition --trust-server-names --auth-no-challenge \
		--no-verbose --user-agent="SAP Download Manager" "$URL" &
	
done

echo -e "\nWaiting for downloads to finish ...\n" && wait

if [ "${PARAM_PACKAGE^^}" = "HOSTAGENT" ]; then

	echo -e "\nRenaming hostagent packages ...\n"

	mv SAPCAR*.EXE SAPCAR.EXE 
	mv SAPHOSTAGENT*.SAR SAPHOSTAGENT.SAR

fi

if [ ! -z "$StorageName" ] && [ ! -z "$StorageKey" ]; then

	echo -e "\nUploading packages ...\n"

	az storage blob upload-batch \
		--account-name "$StorageName" --account-key "$StorageKey" \
		--destination "$PARAM_PACKAGE" --source "$PWD" -o none

	az storage blob upload-batch \
		--account-name "$StorageName" --account-key "$StorageKey" \
		--destination "$PARAM_PACKAGE" --source "$PWD" -o none \
		--pattern "_downloader.*.log" --no-progress
	
fi
