#!/bin/bash

: '
This scipt will import all data stored at a path to blob storage in target environments.
# $1 - path to export
Script will look for folders like path/ceph/bucket1 path/ceph/bucket2 each containing data from 1 bucket and create bucket and upload
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

  readonly AWS_HOST=$(cat $CREDENTIALS_FILE | jq -r 'select(.AWS_HOST != null) | .AWS_HOST')
  readonly AWS_ENDPOINT=$(cat $CREDENTIALS_FILE | jq -r 'select(.AWS_ENDPOINT != null) | .AWS_ENDPOINT')
  readonly AWS_ACCESS_KEY_ID=$(cat $CREDENTIALS_FILE | jq -r 'select(.AWS_ACCESS_KEY_ID != null) | .AWS_ACCESS_KEY_ID')
  readonly AWS_SECRET_ACCESS_KEY=$(cat $CREDENTIALS_FILE | jq -r 'select(.AWS_SECRET_ACCESS_KEY != null) | .AWS_SECRET_ACCESS_KEY')
  readonly FOLDER=${BASE_PATH}/ceph/
}

function list_buckets() {
  cd $FOLDER
  dirs=$(find . -maxdepth 1 -mindepth 1 -type d -printf '%f\n')
  readonly DIRS=${dirs}
}

function upload_blobs() {
  while read line;
  do echo "Response line: '${line}'"
  	BUCKET_NAME=${line}
  	# create bucket
  	echo "$green $(date) Creating bucket ${BUCKET_NAME} $default"
  	s3cmd mb --host=${AWS_HOST} --host-bucket=  s3://${BUCKET_NAME} --no-ssl
  	# sync folder to bucket
  	echo "$green $(date) Starting sync of object storage to local disk for bucket ${BUCKET_NAME} $default"
  	aws s3 --endpoint-url http://${AWS_ENDPOINT} --no-verify-ssl sync ${BUCKET_NAME}/ s3://${BUCKET_NAME}
  	echo "$green $(date) Finsihed sync of object storage to local disk for bucket ${BUCKET_NAME} $default"
  done <<< "$DIRS";
}


initialize_variables

list_buckets

upload_blobs

