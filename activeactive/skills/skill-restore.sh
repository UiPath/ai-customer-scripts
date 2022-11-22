#!/bin/bash


red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)

echo "$green Enter backup dir path:"
read backupDir

echo -e "$green $(date) Backup started \n"

# Validate dependency module
# $1 - Name of the dependency module
# $2 - Command to validate module
function validate_dependency() {
  eval $2
  # Next statement is checking last command success
  if [ $? -ne 0 ]; then
    echo -e "$red $(date) Please install ******** $1 ***********  ... Exiting $default"
    exit 1
  fi
}

# Validate required modules exits in target setup
function validate_setup() {
  validate_dependency jq "jq --version"
  echo -e "$(date) Successfully validated required dependencies"
}


function create_tenant_secret() {

  echo -e "$green Starting port forwarding for ai-deployer to create tenant secret \n"

  IDENTITY_SERVER_ENDPOINT=$(kubectl -n uipath get deployment ai-app-deployment -o json | jq -r '.spec.template.spec.containers[0].env[] | select(.name == "IDENTITY_SERVER_ENDPOINT").value')'/connect/token'
  S2S_CLIENT_ID=$(kubectl -n uipath get secret identity-client-aifabric -o json | jq '.data."Aicenter.Recovery.S2S.ClientId"' | sed -e 's/^"//' -e 's/"$//' | base64 -d)
  S2S_CLIENT_SECRET=$(kubectl -n uipath get secret identity-client-aifabric -o json | jq '.data."Aicenter.Recovery.S2S.ClientSecret"' | sed -e 's/^"//' -e 's/"$//' | base64 -d)

  ACCESS_TOKEN=$(curl --location --request POST $IDENTITY_SERVER_ENDPOINT \
  --header 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'client_id='$S2S_CLIENT_ID \
  --data-urlencode 'client_secret='$S2S_CLIENT_SECRET \
  --data-urlencode 'grant_type=client_credentials' \
  --data-urlencode 'audience=AiFabricRecovery' | jq '.access_token' | sed -e 's/^"//' -e 's/"$//')

  kubectl -n uipath port-forward service/ai-deployer-svc 80:80 --address 0.0.0.0 &
  sleep 5
  echo -e "$green Calling create tenant secret API \n"
  curl --silent --fail -i -k --show-error -X POST 'http://localhost:80/ai-deployer/v1/system/namespace/recover' -H 'authorization: Bearer '"$ACCESS_TOKEN"

  PORT_FWS_PROCESS_ID=$(netstat -tulpn | grep 80 | grep kubectl | awk -F "[ /]+" '{print $7}')
  kill -9 $PORT_FWS_PROCESS_ID

  echo -e "$green Tenant Secret creation complete. Restoring backup dir \n"
}

function restore_skill() {

  kubectl apply -f $backupDir

  echo -e "$green $(date) Backup completed \n"
}

validate_setup

create_tenant_secret

restore_skill
