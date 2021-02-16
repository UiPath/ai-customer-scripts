#!/bin/bash

: '
This scipt will import all data stored at a path to blob storage in target environments.
# $1 - json file with credentials, change the script to work with own credential manager
# $2 - path to import from
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

  export AWS_HOST=$(cat $CREDENTIALS_FILE | jq -r 'select(.AWS_HOST != null) | .AWS_HOST')
  export AWS_ENDPOINT=$(cat $CREDENTIALS_FILE | jq -r 'select(.AWS_ENDPOINT != null) | .AWS_ENDPOINT')
  export AWS_ACCESS_KEY_ID=$(cat $CREDENTIALS_FILE | jq -r 'select(.AWS_ACCESS_KEY_ID != null) | .AWS_ACCESS_KEY_ID')
  export AWS_SECRET_ACCESS_KEY=$(cat $CREDENTIALS_FILE | jq -r 'select(.AWS_SECRET_ACCESS_KEY != null) | .AWS_SECRET_ACCESS_KEY')
  readonly FOLDER=${BASE_PATH}/ceph/

}

function list_buckets() {
  cd $FOLDER
  dirs=$(find . -maxdepth 1 -mindepth 1 -type d -printf '%f\n')
  readonly DIRS=${dirs}
}

function upload_blob() {
  BUCKET_NAME=${1}
  # create bucket if not exists
  local check_bucket=$(s3cmd info --host=${AWS_ENDPOINT} --host-bucket=  s3://${BUCKET_NAME} --no-check-certificate -q)
  if [ ! -z "$check_bucket" ]; then
    echo "$green $(date) Creating bucket ${BUCKET_NAME} $default"
    s3cmd mb --host=${AWS_ENDPOINT} --host-bucket=  s3://${BUCKET_NAME} --no-check-certificate
  else
    echo "$yellow $(date)  Bucket exists: ${BUCKET_NAME}, skipping $default"
  fi
  # sync folder to bucket
  echo "$green $(date) Starting sync of object storage to local disk for bucket ${BUCKET_NAME} $default"
  aws s3 --endpoint-url ${AWS_ENDPOINT} --no-verify-ssl --only-show-errors sync ${dir}/ s3://${BUCKET_NAME}
  echo "$green $(date) Finsihed sync of object storage to local disk for bucket ${BUCKET_NAME} $default"
}

function update_cors_policy() {
  BUCKET_NAME=${1}
  if [ ! -f "${FOLDER}${BUCKET_NAME}-cors.json" ]; then
    echo "$red $(date) ${FOLDER}${BUCKET_NAME}-cors.json file does not exist, Please check ... Skipping cors creation $default"
    return
  fi
  aws --endpoint-url $AWS_ENDPOINT --no-verify-ssl s3api put-bucket-cors --bucket ${BUCKET_NAME} --cors-configuration file://${FOLDER}${BUCKET_NAME}-cors.json
}

function process_buckets() {
  while read dir;
  do echo "Processing directory: '${dir}'"
    # aws doesn't allow underscores in bucket name
  	bucket=${dir//_/-}
  	# Create and sync bucket contents
    upload_blob ${bucket}
    update_cors_policy ${bucket}
  done <<< "$DIRS";
}


initialize_variables

list_buckets

process_buckets

