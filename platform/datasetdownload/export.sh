#!/bin/bash

: '
This scipt will export all data stored in blob storage from target environments.
# $1 - json file with credentials, change the script to work with own credential manager
# $2 - json file with input parameters
# $3 - path to export
Script will generate folders like path/ceph/bucket1 containing data from 1 bucket
[Script Version -> 21.4]
'
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)

echo "$green $(date) Starting sync of object storage to local disk $default"

readonly CREDENTIALS_FILE=$1
readonly INPUT_FILE=$2
readonly BASE_PATH=$3

# Validate required modules exits in target setup
function validate_setup() {
  validate_dependency "aws s3" "aws --version"
  validate_dependency "jq" "jq --version"
  echo "$(date) Successfully validated required dependencies"
}

# Validate file provided by user exists or not, It may be relative path or absolute path
# $1 - File path
function validate_file_path() {
  if [ ! -f "$1" ]; then
    echo "$red $(date) $1 file does not exist, Please check ... Exiting $default"
    exit 1
  fi
}

# Validate dependency module
# $1 - Name of the dependency module
# $2 - Command to validate module
function validate_dependency() {
  eval $2
  # Next statement is checking last command success aws --version has some issue
  if [ $? -ne 0 ]; then
    echo "$red $(date) Please install ******** $1 ***********  ... Exiting $default"
    exit 1
  fi
}

function initialize_variables() {
  # Validate file path
  validate_file_path $CREDENTIALS_FILE
  validate_file_path $INPUT_FILE

  export AWS_HOST=$(cat $CREDENTIALS_FILE | jq -r 'select(.AWS_HOST != null) | .AWS_HOST')
  export AWS_ENDPOINT=$(cat $CREDENTIALS_FILE | jq -r 'select(.AWS_ENDPOINT != null) | .AWS_ENDPOINT')
  export AWS_ACCESS_KEY_ID=$(cat $CREDENTIALS_FILE | jq -r 'select(.AWS_ACCESS_KEY_ID != null) | .AWS_ACCESS_KEY_ID')
  export AWS_SECRET_ACCESS_KEY=$(cat $CREDENTIALS_FILE | jq -r 'select(.AWS_SECRET_ACCESS_KEY != null) | .AWS_SECRET_ACCESS_KEY')
  export TRAINING_BUCKET_NAME=$(cat $INPUT_FILE | jq -r 'select(.TRAINING_BUCKET_NAME != null) | .TRAINING_BUCKET_NAME')
  export TENANT_ID=$(cat $INPUT_FILE | jq -r 'select(.TENANT_ID != null) | .TENANT_ID')
  export PROJECT_ID=$(cat $INPUT_FILE | jq -r 'select(.PROJECT_ID != null) | .PROJECT_ID')
  export DATASET_ID=$(cat $INPUT_FILE | jq -r 'select(.DATASET_ID != null) | .DATASET_ID')
  readonly FOLDER=${BASE_PATH}/ceph/
  mkdir -p ${FOLDER}
}

function list_buckets() {
  temp_buckets=$(aws s3 --endpoint-url $AWS_ENDPOINT --no-verify-ssl ls)
  readonly BUCKETS=${temp_buckets}
}

function get_cors_policy() {
  BUCKET_NAME=${1}
  aws --endpoint-url $AWS_ENDPOINT --no-verify-ssl s3api get-bucket-cors --bucket ${BUCKET_NAME} >${FOLDER}${BUCKET_NAME}-cors.json
}

function download_blob() {
  BUCKET_NAME=${1}
  echo "$green $(date) Starting sync of object storage to local disk for bucket ${BUCKET_NAME} $default"
  mkdir -p ${FOLDER}${BUCKET_NAME}
  aws s3 --endpoint-url $AWS_ENDPOINT --no-verify-ssl sync s3://${BUCKET_NAME} ${FOLDER}${BUCKET_NAME} --delete --exclude '*' --include 'training-'$TENANT_ID'/'$PROJECT_ID'/'$DATASET_ID'/*'
  echo "$green $(date) Finsihed sync of object storage to local disk for bucket ${BUCKET_NAME} $default"
}

function download_blob_old() {
  BUCKET_NAME=${1}
  PREFIX=${2}
  echo "$green $(date) Starting sync of object storage to local disk for bucket ${BUCKET_NAME} and prefix ${PREFIX} $default"
  mkdir -p ${FOLDER}${BUCKET_NAME}/${PREFIX}
  # check if less than 1000 blobs
  blob_count=$(aws s3api --endpoint-url $AWS_ENDPOINT --no-verify-ssl list-objects --bucket ${BUCKET_NAME} --prefix "${PREFIX}" --output json --query "length(Contents[])")
  if [ "$blob_count" -gt 1000 ]
  then
    # sync root level, caveat that it will only sync 100
    aws s3 --endpoint-url $AWS_ENDPOINT --no-verify-ssl sync s3://${BUCKET_NAME}/${PREFIX} ${FOLDER}${BUCKET_NAME}/${PREFIX} --exclude "*/*" --delete
    # get subfolders & call recursively
    folders=($(aws s3api --endpoint-url $AWS_ENDPOINT --no-verify-ssl list-objects --bucket ${BUCKET_NAME}  --delimiter "/" --prefix "${PREFIX}" --output json | jq -r 'select(.CommonPrefixes != null and (.CommonPrefixes |type) == "array") | .CommonPrefixes[] | select(.Prefix != null).Prefix'))
    for subprefix in "${folders[@]}"
    do
       :
       download_blob_old ${BUCKET_NAME} ${subprefix}
    done
  else
    # sync all
    aws s3 --endpoint-url $AWS_ENDPOINT --no-verify-ssl sync s3://${BUCKET_NAME}/${PREFIX} ${FOLDER}${BUCKET_NAME}/${PREFIX} --delete
  fi
  echo "$green $(date) Finsihed sync of object storage to local disk for bucket ${BUCKET_NAME} and prefix ${PREFIX} $default"
}

function sync_buckets() {
  #Ceph issue limits it to 1000 blobs for rook 1.0.6 so find rook first
  old_rook="v1.0."
  toolbox_pod=$(kubectl -n rook-ceph get pod -l app=rook-ceph-tools -o jsonpath="{.items[0].metadata.name}")
  rook_version=$(kubectl -n rook-ceph exec -it $toolbox_pod -- sh -c 'rook version | head -n 1 | cut -d ':' -f2')
  while read line; do
  # if bucket name is train-data then proceed
    echo "Response line: '${line}'"
    bucket=$(echo ${line} | cut -d" " -f3)
    echo "Syncing bucket ---> '${bucket}' "
    if [ "${bucket}" == "${TRAINING_BUCKET_NAME}" ]; then
    # get cors policy on bucket
    get_cors_policy $bucket
    # download bucket contents
    if [[ "$rook_version" =~ "$old_rook".* ]]; then
     echo "download_blob_old"
      download_blob_old $bucket ""
    else
     echo "download_blob'"
      download_blob $bucket
    fi
    fi
  done <<<"$BUCKETS"
}

# Validate Setup
validate_setup

# Update ENV Variables
initialize_variables

# List buckets
list_buckets

# Sync Buckets
sync_buckets