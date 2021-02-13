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

[ -z "$PARAM_SAPUSERNAME" ] && { PARAM_SAPUSERNAME="$SAPUsername"; } 
[ -z "$PARAM_SAPUSERNAME" ] && fail "Parameter --SAPUsername is mandatory"
[ -z "$PARAM_SAPPASSWORD" ] && { PARAM_SAPPASSWORD="$SAPPassword"; } 
[ -z "$PARAM_SAPPASSWORD" ] && fail "Parameter --SAPPassword is mandatory"
[ -z "$PARAM_PACKAGE" ] && fail "Parameter --Package is mandatory"

readonly DOWNLOAD_ROOT="$DIR/../download" # re-create download root and switch context
rm -rf $DOWNLOAD_ROOT && mkdir -p "$DOWNLOAD_ROOT" && pushd "$DOWNLOAD_ROOT" > /dev/null

# tee output to downloader log 
exec &> >(tee -a downloader.log)

# install a full featured wget
echo -e "\nUpgrading wget ...\n"
apk update && apk add wget

while read LINE; do
	[[ "$LINE" = "https://softwaredownloads.sap.com/file/"* ]] && { URLS+=( "$LINE" ); }
done < <( curl -s "https://raw.githubusercontent.com/lnwsoft/phoenix-repo-downloader/main/packages/$PARAM_PACKAGE.lst" )

for URL in "${URLS[@]}"; do

	echo -e "\nDownloading file $URL into $PWD ...\n"
	
	wget --user="$PARAM_SAPUSERNAME" --password="$PARAM_SAPPASSWORD" \
		--content-disposition --trust-server-names --auth-no-challenge \
		--no-verbose --user-agent="SAP Download Manager" "$URL" &
	
done

echo -e "\nWaiting for downloads to finish ...\n"
wait

if [ "${PARAM_PACKAGE^^}" = "HOSTAGENT" ]; then

	echo -e "\nRenaming hostagent packages ...\n"
	mv SAPCAR*.EXE SAPCAR.EXE > /dev/null 
	mv SAPHOSTAGENT*.SAR SAPHOSTAGENT.SAR > /dev/null

fi

if [ ! -z "$StorageName" ] && [ ! -z "$StorageKey" ]; then

	echo -e "\nUploading packages ...\n"
	az storage blob upload-batch \
		--account-name "$StorageName" --account-key "$StorageKey" \
		--destination "$PARAM_PACKAGE" --source "$PWD" --no-progress -o none

fi

popd > /dev/null
