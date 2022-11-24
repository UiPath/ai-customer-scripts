#!/bin/bash


red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)

PORT_FRWD=80

echo "$green Enter backup dir path:"
read backupDir
echo "$green Enter skill id:"
read skillId

uuidArray=(${skillId//-/ })
uuid=${uuidArray[0]}

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
  TENANT_SECRET_EXISTS=$(kubectl -n uipath get secret | grep deployment-storage-credentials)
  if [ -z "$TENANT_SECRET_EXISTS" ]; then
      echo -e "$green Starting port forwarding for ai-deployer to create tenant secret \n"

        IDENTITY_SERVER_ENDPOINT=$(kubectl -n uipath get deployment ai-app-deployment -o json | jq -r '.spec.template.spec.containers[0].env[] | select(.name == "IDENTITY_SERVER_ENDPOINT").value')'/connect/token'
        if [[ -z $IDENTITY_SERVER_ENDPOINT ]]; then
          echo "$red $(date) IDENTITY_SERVER_ENDPOINT is invalid or missing, Please check ... Exiting $default"
          exit 1
        fi

        S2S_CLIENT_ID=$(kubectl -n uipath get secret identity-client-aifabric -o json | jq '.data."Aicenter.Recovery.S2S.ClientId"' | sed -e 's/^"//' -e 's/"$//' | base64 -d)
        S2S_CLIENT_SECRET=$(kubectl -n uipath get secret identity-client-aifabric -o json | jq '.data."Aicenter.Recovery.S2S.ClientSecret"' | sed -e 's/^"//' -e 's/"$//' | base64 -d)
        if [[ -z $S2S_CLIENT_ID || -z $S2S_CLIENT_SECRET ]]; then
          echo "$red $(date) S2S_CLIENT_ID or S2S_CLIENT_SECRET is invalid or missing, Please check ... Exiting $default"
          exit 1
        fi

        ACCESS_TOKEN=$(curl --location --request POST $IDENTITY_SERVER_ENDPOINT \
        --header 'Content-Type: application/x-www-form-urlencoded' \
        --data-urlencode 'client_id='$S2S_CLIENT_ID \
        --data-urlencode 'client_secret='$S2S_CLIENT_SECRET \
        --data-urlencode 'grant_type=client_credentials' \
        --data-urlencode 'audience=AiFabricRecovery' | jq '.access_token' | sed -e 's/^"//' -e 's/"$//')
        if [[ -z $ACCESS_TOKEN ]]; then
          echo "$red $(date) ACCESS_TOKEN is invalid or missing, Please check ... Exiting $default"
          exit 1
        fi

        kubectl -n uipath port-forward service/ai-deployer-svc $PORT_FRWD:80 --address 0.0.0.0 &
        bkg_pid=$!
        sleep 5
        echo -e "$green Calling create tenant secret API \n"
        curl --silent --fail -i -k --show-error -X POST 'http://localhost:'$PORT_FRWD'/ai-deployer/v1/system/namespace/recover' -H 'authorization: Bearer '"$ACCESS_TOKEN"
        echo -e "$yellow Waiting for tenant secret creation to complete  \n"
        sleep 5
        test -f /proc/$bkg_pid/cmdline && kill $bkg_pid

        echo -e "$green Tenant Secret creation complete. Restoring backup dir \n"
        echo $default
  else
            echo -e "$green Tenant Secret already exists. Restoring backup dir \n"
            echo $default
  fi

}

function restore_skill() {

  kubectl apply -f $backupDir/$uuid-secret.yaml
  kubectl apply -f $backupDir/$uuid-configmap.yaml
  kubectl apply -f $backupDir/$uuid-deployment.yaml
  kubectl apply -f $backupDir/$uuid-service.yaml
  if [ -f "$backupDir/$uuid-hpa.yaml" ]; then
  kubectl apply -f $backupDir/$uuid-hpa.yaml
  fi
  if [ -f "$backupDir/$uuid-pdb.yaml" ]; then
  kubectl apply -f $backupDir/$uuid-pdb.yaml
  fi
  kubectl apply -f $backupDir/$uuid-virtual-service.yaml

  echo -e "$green $(date) Backup completed \n"
  echo $default
}

validate_setup

create_tenant_secret

restore_skill
