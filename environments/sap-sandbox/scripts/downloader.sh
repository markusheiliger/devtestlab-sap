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

[ -z "$PARAM_PACKAGES" ] && fail "Parameter --Packages is mandatory"

readonly DOWNLOAD_ROOT="$DIR/downloads"
rm -rf $DOWNLOAD_ROOT > /dev/null

while read TOKEN; do
	[ -z "$TOKEN" ] || { PACKAGES+=( "$TOKEN" ); }
done < <( echo "$PARAM_PACKAGES" | tr ";" "\n" )

if [ "${#array[@]}" -gt "1"]; then

	for PACKAGE in "${PACKAGES[@]}"; do
		echo "Enqueueing package '$PACKAGE' ..."
	done

elif [ ! -z "${PACKAGES[0]}" ]; then

	PACKAGE="${PACKAGES[0]}"
	echo "Enqueueing package '$PACKAGE' ..."

else

	echo "How did we get here ???"
fi

for PACKAGE in "${PACKAGES[@]}"; do
	
	mkdir -p "$DOWNLOAD_ROOT/$PACKAGE" && pushd "$DOWNLOAD_ROOT/$PACKAGE" > /dev/null

	while read LINE; do
		[[ "$LINE" = "https://softwaredownloads.sap.com/file/"* ]] && { URLS+=( "$LINE" ); }
	done < <( curl -s "https://raw.githubusercontent.com/lnwsoft/phoenix-repo-downloader/main/packages/$PACKAGE.lst" )

	for URL in "${URLS[@]}"; do

		echo -e "\n\nDownloading file $URL into $PWD ...\n"
		
		wget --user="$PARAM_SAPUSERNAME" --password="$PARAM_SAPPASSWORD" \
			--content-disposition --trust-server-names --auth-no-challenge -q --show-progress \
			--user-agent="SAP Download Manager" $URL
		
	done

	if [ "${PACKAGE^^}" = "HOSTAGENT" ]; then

		mv SAPCAR*.exe SAPCAR.exe
		mv SAPHOSTAGENT*.SAR SAPHOSTAGENT.SAR

	fi

	popd > /dev/null

done
