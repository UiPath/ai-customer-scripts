#!/bin/bash

: '
This scipt will export all data stored in blob storage from target environments.
# $1 - json file with credentials
# $2 - path to export
Script will generate folders like path/ceph/bucket1 path/ceph/bucket2 each containing data from 1 bucket
[Script Version -> 21.4]
'
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)

echo "$green $(date) Starting sync of object storage to local disk $default"

readonly CREDENTIALS_FILE=$1
readonly BASE_PATH=$2

# Validate file provided by user exists or not, It may be relative path or absolute path
# $1 - File path
function validate_file_path() {
  if [ ! -f "$1" ]; then
    echo "$red $(date) $1 file does not exist, Please check ... Exiting $default"
    exit 1
  fi
}

function initialize_variables() {
  # Validate file path
  validate_file_path $CREDENTIALS_FILE

  export AWS_HOST=$(cat $CREDENTIALS_FILE | jq -r 'select(.AWS_HOST != null) | .AWS_HOST')
  export AWS_ENDPOINT=$(cat $CREDENTIALS_FILE | jq -r 'select(.AWS_ENDPOINT != null) | .AWS_ENDPOINT')
  export AWS_ACCESS_KEY_ID=$(cat $CREDENTIALS_FILE | jq -r 'select(.AWS_ACCESS_KEY_ID != null) | .AWS_ACCESS_KEY_ID')
  export AWS_SECRET_ACCESS_KEY=$(cat $CREDENTIALS_FILE | jq -r 'select(.AWS_SECRET_ACCESS_KEY != null) | .AWS_SECRET_ACCESS_KEY')
  readonly FOLDER=${BASE_PATH}/ceph/
}

function list_buckets() {
  temp_buckets=$(aws s3 --endpoint-url $AWS_ENDPOINT --no-verify-ssl ls)
  readonly BUCKETS=${temp_buckets}
}

function download_blobs() {
  while read line; 
  do 
    echo "Response line: '${line}'"
    BUCKET_NAME=$(echo ${line}| cut -d" " -f3)
    echo "$green $(date) Starting sync of object storage to local disk for bucket ${BUCKET_NAME} $default"
    mkdir -p ${FOLDER}${BUCKET_NAME}
    aws s3 --endpoint-url $AWS_ENDPOINT --no-verify-ssl sync s3://${BUCKET_NAME} ${FOLDER}${BUCKET_NAME} --delete
    echo "$green $(date) Finsihed sync of object storage to local disk for bucket ${BUCKET_NAME} $default"
  done <<< "$BUCKETS"
}


initialize_variables

list_buckets

download_blobs
