#!/bin/bash

: '
This script exports the images corresponding to currently available skills
needs a json for creds and export directory
[Script Version -> 21.4]
'

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)

readonly REGISTRY_EXPORT_FILE=$1
readonly EXPORT_PATH=$2/registry

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
  validate_file_path $REGISTRY_EXPORT_FILE

  readonly DB_CONN=$(cat $REGISTRY_EXPORT_FILE | jq -r 'select(.dbConnection != null) | .dbConnection')
  readonly DB_NAME=$(cat $REGISTRY_EXPORT_FILE | jq -r 'select(.dbName != null) | .dbName')
  readonly DB_USER=$(cat $REGISTRY_EXPORT_FILE | jq -r 'select(.dbUser != null) | .dbUser')
  readonly DB_PASSWORD="$(cat $REGISTRY_EXPORT_FILE | jq -r 'select(.dbPassword != null) | .dbPassword')"
  readonly REGISTRY_ENDPOINT=$(cat $REGISTRY_EXPORT_FILE | jq -r 'select(.registryEndpoint != null) | .registryEndpoint')
  readonly REGISTRY_USER=$(cat $REGISTRY_EXPORT_FILE | jq -r 'select(.registryUser != null) | .registryUser')
  readonly REGISTRY_PASSWORD=$(cat $REGISTRY_EXPORT_FILE | jq -r 'select(.registryPassword != null) | .registryPassword')
  readonly OLD_REGISTRY_ENDPOINT=$(cat $REGISTRY_EXPORT_FILE | jq -r 'select(.oldRegistryEndpoint != null) | .oldRegistryEndpoint')
  

  if [[ -z $DB_CONN || -z $DB_NAME || -z $DB_USER || -z $DB_PASSWORD || -z TENANT_NAME || -z REGISTRY_ENDPOINT || -z REGISTRY_USER || -z REGISTRY_PASSWORD || -z EXPORT_PATH || -z OLD_REGISTRY_ENDPOINT ]]; then
    echo "$red $(date) Input is invalid or missing, Please check ... Exiting $default"
    exit 1
  fi

  echo "$green $(date) Successfully validated user input $default"
}

function get_image_list() {
	# sqlcmd -S tcp:${DB_CONN} -d ${DB_NAME} -U ${DB_USER} -P ${DB_PASSWORD} -i getimages.sql -o images.txt -h -1 -W
	sqlcmd -S tcp:${DB_CONN} -d ${DB_NAME} -U ${DB_USER} -P ${DB_PASSWORD} -o images.txt -h -1 -W -Q "set nocount on; select distinct mpi.image_uri from ml_package_images mpi inner join ml_skill_versions msv on msv.ml_package_version_id = mpi.version_id and  msv.processor = mpi.processor where msv.status in ('UPDATING', 'COMPLETED', 'VALIDATING_DEPLOYMENT') and mpi.status = 'ACTIVE'"
}

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
	${DOCKER_COMMAND} login ${REGISTRY_ENDPOINT} -u ${REGISTRY_USER} -p ${REGISTRY_PASSWORD}
}

function save_image() {
	${DOCKER_COMMAND} pull $1
	if [ $? -ne 0 ];
	then
		echo "$red $(date) Not able to pull image for $1 $default"
		exit 1
	fi
	set -o pipefail
	${DOCKER_COMMAND} save $1 | gzip > $2
	if [ $? -ne 0 ];
	then
		echo "$red $(date) Not able to save image for $1 in $2 $default"
		rm -rf $2
		exit 1
	fi
}

function save_images() {
	mkdir -p ${EXPORT_PATH}
    # loop over images, replace existing registry tag with the one from nodeport and generate tars if they don't exist in destination
    # Pass full image and a file name to save_image
    while read img; do
  		# each line will be json
  		echo "$img"
  		
  		registry=$(echo $img | jq -r 'select(.repository != null) | .repository')
  		image=$(echo $img | jq -r 'select(.imageName != null) | .imageName')
  		tag=$(echo $img | jq -r 'select(.imageTag != null) | .imageTag')

  		if [[ $registry == ${OLD_REGISTRY_ENDPOINT}* ]]; then
  			newimg=${REGISTRY_ENDPOINT}/${image}:${tag}
  			imgName=$(echo ${newimg##*/})
  			if [ ! -f "${EXPORT_PATH}/$imgName.tar.gz" ]; then
    			echo "$green $(date) ${EXPORT_PATH}/$imgName file does not exist, Generating image tar $default"
    			save_image $newimg ${EXPORT_PATH}/${imgName}.tar.gz
    		else
    			echo "$green $(date) ${EXPORT_PATH}/$imgName file exists, Skipping $default"
  			fi
  		fi
	done <images.txt
}

validate_setup

validate_input

docker_setup

#validate_file_path "./is.sh"
#source ./is.sh
#
## register
#register_client_and_fetch_access_token
#
## export
get_image_list

save_images
#
#
## deregister
#deregister_client
