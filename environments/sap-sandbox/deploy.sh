#!/bin/bash

DIR=$(dirname $0)

if [ $# -eq 0 ]; then
  echo "Usage:"
  echo "================================================================"
  exit 0
fi

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


readonly TEMPLATE="$( find $DIR -maxdepth 1 -iname "azuredeploy.json" )"
[ -f "$TEMPLATE" ] || fail "Missing deployment template 'azuredeploy.json' in $DIR"

[ -z "$PARAM_SUBSCRIPTION" ] && { PARAM_SUBSCRIPTION="$(az account show --query 'id' -o tsv)"; } 
az account set -s "$PARAM_SUBSCRIPTION" || fail "Failed to set/identify subscription context"

[ -z "$PARAM_RESOURCEGROUP" ] && fail "ResourceGroup name must not be empty" 
[ "$(az group exists -n $PARAM_RESOURCEGROUP)" == "true" ] || fail "ResourceGroup could not be found" 

[ -z "$PARAM_RESET" ] && { PARAM_RESET="false"; } 
[[ "TRUE|FALSE" == *"${PARAM_RESET^^}"* ]] || fail "Reset must be 'true' or 'false'" 

if [ "${PARAM_RESET^^}" == "TRUE" ]; then
  echo -e "\nDeleting resources ..."
  TEMPLATE_RESULT=$( az deployment group create \
    --subscription "$PARAM_SUBSCRIPTION" \
    --resource-group "$PARAM_RESOURCEGROUP" \
    --name "$( uuidgen )" \
    --no-prompt true --mode Complete \
    --template-uri "https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/100-blank-template/azuredeploy.json" )
  echo -e "\nDeallocating resources ..."
  sleep 1m
fi

echo -e "\nDeploying resources ..."
TEMPLATE_RESULT=$( az deployment group create \
  --subscription "$PARAM_SUBSCRIPTION" \
  --resource-group "$PARAM_RESOURCEGROUP" \
  --name "$( uuidgen )" \
  --no-prompt true --mode Incremental \
  --template-file "$TEMPLATE" \
  "${TEMPLATE_PARAMS[@]}" )