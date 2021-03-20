#!/bin/bash

: '
This script runs on aif machine and creates necessary services for enabling backup/restore of registry
May need registry-np.yaml
It also generates registry-creds.json which can be used as it is with im/export.sh (insecure) or moved to some credentials manager and used from there by modifying script
[Script Version -> 21.4]
'

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)

readonly PRIVATE_IP=$1

# Validate dependecny module
# $1 - Name of the dependecny module
# $2 - Command to validate module
function validate_dependency() {
  list=$($2)
  if [ -z "$list" ]; then
    echo "$red $(date) Please install ******** $1 ***********  ... Exiting $default"
    exit 1
  fi
}

# Validate required modules exits in target setup
function validate_setup() {
  validate_dependency kubectl "kubectl version"
  echo "$(date) Successfully validated required dependencies"
}

function get_db_details() {

  conn=$(kubectl -n aifabric get deployment ai-deployer-deployment -o yaml | grep -A1 'SPRING_DATASOURCE_URL' | grep -v 'SPRING_DATASOURCE_URL')
  line=$(echo $conn | grep -o 'sqlserver://.*;')
  readonly DB_CONN=$(basename ${line//;/})
  line=$(echo $conn | grep -o 'databaseName=[a-zA-Z0-9_-]*')
  readonly DB_NAME=${line##*=}
  user=$(kubectl -n aifabric get deployment ai-deployer-deployment -o yaml | grep -A1 'SPRING_DATASOURCE_USER' | grep -v 'SPRING_DATASOURCE_USER')
  readonly DB_USER=${user##* }
  pass=$(kubectl -n aifabric get secret ai-deployer-secrets -o yaml | grep 'DATASOURCE_PASSWORD' | grep -v ':DATASOURCE_PASSWORD')
  readonly DB_PASSWORD=$(echo ${pass##* } | base64 -d)

	if [[ -z $DB_CONN || -z $DB_USER || -z $DB_PASSWORD || -z $DB_NAME ]]; then
  	echo "$red $(date) Failed to fetch one or more db info, Please check ... Exiting $default"
  	exit 1
  fi
}

function get_registry_details() {
	# get ip
	if [ -z "$PRIVATE_IP" ]; then
		# Gets private ip of machine so that it can be connected within the VM
		# Seems to be set as localhost on some customer machines
		#OBJECT_GATEWAY_EXTERNAL_HOST=$(hostname -i)
		PRIVATE_ADDRESS=$(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')
    	#This is needed on k8s 1.18.x as $PRIVATE_ADDRESS is found to have a newline
    REGISTRY_IP=$(echo "$PRIVATE_ADDRESS" | tr -d '\n')
  else
  	REGISTRY_IP=$PRIVATE_IP
  fi
  echo "$green $(date) Private IP was $PRIVATE_IP and REGISTRY_IP is $REGISTRY_IP"
	# check if nodeport exists for registry
	regnp=$(kubectl -n kurl get svc registry-np)
	if [ -z "$regnp" ]; then
    echo "$yellow $(date) Registry service not exposed as nodeport  ... Creating $default"
    result=kubectl -n kurl apply -f registry_np.yaml
    if [ -z "$result" ]; then
    	echo "$red $(date) Failed to expose Registry service as nodeport  ... Exiting $default"
    	exit 1
    fi
  fi
  port=$(kubectl -n kurl get service/registry-np -o jsonpath='{.spec.ports[0].nodePort}')
  if [ -z "$port" ]; then
  	echo "$red $(date) Failed to fetch nodeport of Registry service  ... Exiting $default"
  	exit 1
  fi
  readonly REGISTRY_CONN=${REGISTRY_IP}:${port}

  # get credentials
  line=$(kubectl -n aifabric get configmap registry-config -o yaml | grep 'REGISTRY_USERNAME' | grep -v 'f:REGISTRY_USERNAME')
	readonly REGISTRY_USER=${line##* }
	line=$(kubectl -n aifabric get configmap registry-config -o yaml | grep 'REGISTRY_PASSWORD' | grep -v 'f:REGISTRY_PASSWORD')
	readonly REGISTRY_PASSWORD=${line##* }

  # get old ip
  old=$(kubectl -n kurl get service/registry -o jsonpath='{.spec.clusterIP}')
  if [ -z "$old" ]; then
  	echo "$red $(date) Failed to fetch clusterip of Registry service  ... Exiting $default"
  	exit 1
  fi
  readonly REGISTRY_OLD=${old}
  if [[ -z $REGISTRY_CONN || -z $REGISTRY_USER || -z $REGISTRY_PASSWORD || -z $REGISTRY_OLD ]]; then
  	echo "$red $(date) Failed to fetch one or more registry info, Please check ... Exiting $default"
  	exit 1
  fi
}

function generate_json() {
	echo '{"dbConnection": "'$DB_CONN'", "dbName": "'$DB_NAME'", "dbUser": "'$DB_USER'", "dbPassword": "'$DB_PASSWORD'", "registryEndpoint": "'$REGISTRY_CONN'", "registryUser": "'$REGISTRY_USER'", "registryPassword": "'$REGISTRY_PASSWORD'", "oldRegistryEndpoint": "'$REGISTRY_OLD'"}' > registry-creds.json
	echo "$green $(date) Successfully generated credentials: registry-creds.json ... Exiting $default"
}


validate_setup

get_db_details
get_registry_details

generate_json
