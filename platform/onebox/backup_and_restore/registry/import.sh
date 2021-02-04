#!/bin/bash

: '
This script exports the images corresponding to currently available skills
needs a json for creds and import directory
[Script Version -> 21.4]
'

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)

readonly REGISTRY_IMPORT_FILE=$1
readonly IMPORT_PATH=$2/registry

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
  validate_dependency curl "curl --version"
  validate_dependency jq "jq --version"
  validate_dependency sqlcmd "sqlcmd -?"
  validate_dependency gzip "gzip --version"
  validate_dependency docker "docker --version"
  echo "$(date) Successfully validated required dependecies"
}


function validate_file_path() {
  if [ ! -f "$1" ]; then
    echo "$red $(date) $1 file does not exist, Please check ... Exiting $default"
    exit 1
  fi
}

function validate_input() {

  # Validate file path
  validate_file_path $REGISTRY_IMPORT_FILE

  readonly DB_CONN=$(cat $REGISTRY_IMPORT_FILE | jq -r 'select(.dbConnection != null) | .dbConnection')
  readonly DB_NAME=$(cat $REGISTRY_IMPORT_FILE | jq -r 'select(.dbName != null) | .dbName')
  readonly DB_USER=$(cat $REGISTRY_IMPORT_FILE | jq -r 'select(.dbUser != null) | .dbUser')
  readonly DB_PASSWORD="$(cat $REGISTRY_IMPORT_FILE | jq -r 'select(.dbPassword != null) | .dbPassword')"
  readonly REGISTRY_ENDPOINT=$(cat $REGISTRY_IMPORT_FILE | jq -r 'select(.registryEndpoint != null) | .registryEndpoint')
  readonly REGISTRY_USER=$(cat $REGISTRY_IMPORT_FILE | jq -r 'select(.registryUser != null) | .registryUser')
  readonly REGISTRY_PASSWORD=$(cat $REGISTRY_IMPORT_FILE | jq -r 'select(.registryPassword != null) | .registryPassword')
  readonly OLD_REGISTRY_ENDPOINT=$(cat $REGISTRY_IMPORT_FILE | jq -r 'select(.oldRegistryEndpoint != null) | .oldRegistryEndpoint')
  

  if [[ -z $DB_CONN || -z $DB_NAME || -z $DB_USER || -z $DB_PASSWORD || -z TENANT_NAME || -z REGISTRY_ENDPOINT || -z REGISTRY_USER || -z REGISTRY_PASSWORD || -z EXPORT_PATH || -z OLD_REGISTRY_ENDPOINT ]]; then
    echo "$red $(date) Input is invalid or missing, Please check ... Exiting $default"
    exit 1
  fi

  echo "$green $(date) Successfully validated user input $default"
}

//TODO: use this
formulate_docker_command() {
    docker images registry
    if [[ $? -ne 0 ]]; then
        echo "sudo permission required for docker"
        DOCKER_COMMAND="sudo docker"
    else
        DOCKER_COMMAND="docker"
    fi
}

function docker_setup() {
	# Mark docker registry as unauth => Adapt for other envs
	echo "{\"insecure-registries\": [\"${REGISTRY_ENDPOINT}\"]}" > insecure.json
	sudo touch /etc/docker/daemon.json
	daemondiff=$(sudo jq -s '.[0] as $o1 | .[1] as $o2 | ($o1 + $o2) | ."insecure-registries" = ($o1."insecure-registries" + $o2."insecure-registries" | unique)'  /etc/docker/daemon.json insecure.json)
	sudo echo $daemondiff > /etc/docker/daemon.json
	# Restart docker
	sudo service docker restart
	# Login to docker registry
	sudo docker login ${REGISTRY_ENDPOINT} -u ${REGISTRY_USER} -p ${REGISTRY_PASSWORD}
}

function load_image() {
    LOAD_IMAGE_EXP="Loaded image: "
    ERROR_RESPONSE="Response:Error"
	
	tarfile=$1
	echo "$green $(date) Loading file: ${tarfile} $default"

	LOAD_IMAGE_RESPONSE=$(${DOCKER_COMMAND} load < ${tarfile})
    if [[ "${LOAD_IMAGE_RESPONSE}" == *${ERROR_RESPONSE}* ]]; then
        echo "${LOAD_IMAGE_RESPONSE}"
        echo "Failed to load image: ${file}"
        exit 1
    fi

    if [[ "${LOAD_IMAGE_RESPONSE}" == *${LOAD_IMAGE_EXP}* ]]; then
        IMAGE_NAME=$(echo ${LOAD_IMAGE_RESPONSE}|sed -r "s|${LOAD_IMAGE_EXP}||g")
        echo "Tag ${IMAGE_NAME} image to local registry"
        existing_registry=$(echo ${IMAGE_NAME%%/*})
        LOCAL_IMAGE_NAME=$(echo ${IMAGE_NAME}|sed -r "s|${existing_registry}|${REGISTRY_ENDPOINT}|g")
        echo "Local image name is $LOCAL_IMAGE_NAME"
        # tag failure means an error in our script which will be caught in testing
        ${DOCKER_COMMAND} tag ${IMAGE_NAME} ${LOCAL_IMAGE_NAME}
        PUSH_IMAGE_RESPONSE=$(${DOCKER_COMMAND} push ${LOCAL_IMAGE_NAME})
        if [[ "${PUSH_IMAGE_RESPONSE}" == *${ERROR_RESPONSE}* ]]; then
            echo "${PUSH_IMAGE_RESPONSE}"
            echo "Failed to load image: ${file}"
            exit 1
        fi
    fi
}

function load_images() {
	for file in $(ls ${IMPORT_PATH}); do
		load_image ${IMPORT_PATH}/${file}
		# TODO: Update image ref in db
	done
}


validate_setup

validate_input

docker_setup

## import
load_images