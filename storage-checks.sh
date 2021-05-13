#!/bin/bash

: '
This scipt will validate blob storage from AIC perspective.
# $1 - json file with credentials
[Script Version -> 21.4]
Credentials file structure
{"AWS_HOST": <AWS_HOST>, "AWS_ENDPOINT": <AWS_ENDPOINT>, "AWS_ACCESS_KEY_ID": <AWS_ACCESS_KEY_ID>, "AWS_SECRET_ACCESS_KEY": <AWS_SECRET_ACCESS_KEY>, "BUCKET_1": <BUCKET_1>, "BUCKET_2": <BUCKET_2>}
where the access_key and secret correspond to aws crednetials which has access to the two buckets (customer creates buckets with appropriate policies) 
Requirements: aws s3, jq
'

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)

declare -A etags
declare -A errors

echo "$green $(date) Starting validation of object storage $default"

readonly CREDENTIALS_FILE=$1

function echoinfo() {
	echo "$yellow $(date) $1 $default"
}

function errecho() {
  echo "$red $(date) $1 $default"
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

# Validate required modules exits in target setup
function validate_setup() {
  validate_dependency "aws s3" "aws --version"
  validate_dependency "jq" "jq --version"
  #validate_dependency "fallocate" "fallocate -V"
  validate_dependency "yes" "yes --version"
  echo "$(date) Successfully validated required dependencies"
}

function initialize_variables() {
  # Validate file path
  validate_file_path $CREDENTIALS_FILE

  export AWS_HOST=$(cat $CREDENTIALS_FILE | jq -r 'select(.AWS_HOST != null) | .AWS_HOST')
  export AWS_ENDPOINT=$(cat $CREDENTIALS_FILE | jq -r 'select(.AWS_ENDPOINT != null) | .AWS_ENDPOINT')
  export AWS_ACCESS_KEY_ID=$(cat $CREDENTIALS_FILE | jq -r 'select(.AWS_ACCESS_KEY_ID != null) | .AWS_ACCESS_KEY_ID')
  export AWS_SECRET_ACCESS_KEY=$(cat $CREDENTIALS_FILE | jq -r 'select(.AWS_SECRET_ACCESS_KEY != null) | .AWS_SECRET_ACCESS_KEY')
  export BUCKET_1=$(cat $CREDENTIALS_FILE | jq -r 'select(.BUCKET_1 != null) | .BUCKET_1')
  export BUCKET_2=$(cat $CREDENTIALS_FILE | jq -r 'select(.BUCKET_2 != null) | .BUCKET_2')
  echoinfo "bucket1: $BUCKET_1, and bucket2: $BUCKET_2"
  echoinfo "AWS_HOST: $AWS_HOST, and AWS_ENDPOINT: $AWS_ENDPOINT"
  echoinfo "Please ensure that AWS_ACCESS_KEY_ID & AWS_SECRET_ACCESS_KEY are correct in the credentials file"
}

function bucket_exists {
    be_bucketname=$1

    aws s3api --endpoint-url $AWS_ENDPOINT --no-verify-ssl head-bucket \
        --bucket $be_bucketname \
        >/dev/null 2>&1

    if [[ ${?} -eq 0 ]]; then
        return 0
    else
    	errecho "ERROR: Bucket doesn't exist: $be_bucketname"
    	errors['bucket_exists']="Missing bucket $be_bucketname"
        return 1
    fi
}

function copy_local_file_to_bucket {
    cftb_bucketname=$1
    cftb_sourcefile=$2
    cftb_destfilename=$3
    local RESPONSE
    
    RESPONSE=$(aws s3api --endpoint-url $AWS_ENDPOINT --no-verify-ssl put-object \
                --bucket $cftb_bucketname \
                --body $cftb_sourcefile \
                --key $cftb_destfilename)

    if [[ ${?} -ne 0 ]]; then
        errecho "ERROR: AWS reports put-object operation failed.\n$RESPONSE"
        errors['copy_local_file_to_bucket']="Failed with RESPONSE: \n$RESPONSE"
        return 1
    fi
}

function copy_item_in_bucket {
    ciib_bucketname=$1
    ciib_sourcefile=$2
    ciib_destfile=$3
    local RESPONSE
    
    RESPONSE=$(aws s3api --endpoint-url $AWS_ENDPOINT --no-verify-ssl copy-object \
                --bucket $ciib_bucketname \
                --copy-source $ciib_bucketname/$ciib_sourcefile \
                --key $ciib_destfile)

    if [[ $? -ne 0 ]]; then
        errecho "ERROR:  AWS reports s3api copy-object operation failed.\n$RESPONSE"
        errors['copy_item_in_bucket']="Failed with RESPONSE: \n$RESPONSE"
        return 1
    fi
}

function copy_items_across_buckets {
	local RESPONSE
    RESPONSE=$(aws s3 --endpoint-url $AWS_ENDPOINT --no-verify-ssl cp s3://$1/$3 s3://$2/$3)
    if [[ $? -ne 0 ]]; then
        errecho "ERROR:  AWS reports s3api cp operation failed (across buckets).\n$RESPONSE"
        errors['copy_items_across_buckets']="Failed with RESPONSE: \n$RESPONSE"
        return 1
    fi
}

function list_items_in_bucket {
    liib_bucketname=$1
    local RESPONSE

    RESPONSE=$(aws s3api --endpoint-url $AWS_ENDPOINT --no-verify-ssl list-objects \
                --bucket $liib_bucketname \
                --output text \
                --query 'Contents[].{Key: Key, Size: Size}' )

    if [[ ${?} -eq 0 ]]; then
        echo "$RESPONSE"
    else
        errecho "ERROR: AWS reports s3api list-objects operation failed.\n$RESPONSE"
        errors['list_items_in_bucket']="Failed with RESPONSE: \n$RESPONSE"
        return 1
    fi
}

function list_items_in_bucket_paginated {
    liib_bucketname=$1
    local RESPONSE

    RESPONSE=$(aws s3api --endpoint-url $AWS_ENDPOINT --no-verify-ssl list-objects \
                --bucket $liib_bucketname \
                --max-items=2 )

    if [[ ${?} -eq 0 ]]; then
        TOKEN=$(echo $RESPONSE | jq -r 'select(.NextToken != null) | .NextToken')
        echoinfo "Paginated fetch gave nextToken as $TOKEN, should be non empty"
    else
        errecho "ERROR: AWS reports s3api list-objects operation failed.\n$RESPONSE"
        errors['list_items_in_bucket_paginated']="Failed with RESPONSE: \n$RESPONSE"
        return 1
    fi
}

function delete_item_in_bucket {
    diib_bucketname=$1
    diib_key=$2
    local RESPONSE
    
    RESPONSE=$(aws s3api --endpoint-url $AWS_ENDPOINT --no-verify-ssl delete-object \
                --bucket $diib_bucketname \
                --key $diib_key)

    if [[ $? -ne 0 ]]; then
        errecho "ERROR:  AWS reports s3api delete-object operation failed.\n$RESPONSE"
        errors['delete_item_in_bucket']="Failed with RESPONSE: \n$RESPONSE"
        return 1
    fi
}

function delete_multiple {
	#Objects=[{Key=string,VersionId=string},{Key=string,VersionId=string}],Quiet=boolean
	local RESPONSE
    RESPONSE=$(aws s3api --endpoint-url $AWS_ENDPOINT --no-verify-ssl delete-objects --bucket $1 --delete $2)

    if [[ $? -ne 0 ]]; then
        errecho "ERROR:  AWS reports s3api delete-objects operation failed.\n$RESPONSE"
        errors['delete_multiple']="Failed with RESPONSE: \n$RESPONSE"
        return 1
    fi
}

function download_file {
	local RESPONSE
    RESPONSE=$(aws s3api --endpoint-url $AWS_ENDPOINT --no-verify-ssl get-object --bucket $1 --key $2 $2)
    if [[ $? -ne 0 ]]; then
        errecho "ERROR:  AWS reports s3api get-object operation failed.\n$RESPONSE"
        errors['download_file']="Failed with RESPONSE: \n$RESPONSE"
        return 1
    fi
}


function validate_bucket_counts() {
  blobs1=$(aws s3api --endpoint-url $AWS_ENDPOINT --no-verify-ssl list-objects --bucket ${BUCKET_1} --output json --query "length(Contents[])")
  echo "$green $(date) $blobs1 objects in bucket: $BUCKET_1 $default"
  blobs2=$(aws s3api --endpoint-url $AWS_ENDPOINT --no-verify-ssl list-objects --bucket ${BUCKET_2} --output json --query "length(Contents[])")
  echo "$green $(date) $blobs2 objects in bucket: $BUCKET_2 $default"
  # Policy???
}

# KEY MAY NEED SINGLE QUTOES AND UPLOAD_ID AND ETAG AS DOUBLEQUOTES
function create_multipart() {
	local RESPONSE
	RESPONSE=$(aws s3api --endpoint-url $AWS_ENDPOINT --no-verify-ssl create-multipart-upload --bucket $1 --key $2)
	# Key, UploadId
	if [[ $? -ne 0 ]]; then
        errecho "ERROR:  AWS reports s3api create-multipart-upload operation failed.\n$RESPONSE"
        errors['multipart-upload']="Failed in create_multipart with RESPONSE: \n$RESPONSE"
        return 1
    fi
    export UPLOAD_ID=$(echo $RESPONSE | jq -r 'select(.UploadId != null) | .UploadId')
}

function upload_part() {
	local RESPONSE
	RESPONSE=$(aws s3api --endpoint-url $AWS_ENDPOINT --no-verify-ssl upload-part --bucket $1 --key $2 --part-number $4 --body $5 --upload-id  $3)
	#Etag
	if [[ $? -ne 0 ]]; then
        errecho "ERROR:  AWS reports s3api upload-part operation failed.\n$RESPONSE"
        errors['multipart-upload']="Failed in upload_part with RESPONSE: \n$RESPONSE"
        return 1
    fi

    local etag=$(echo $RESPONSE | jq -r 'select(.ETag != null) | .ETag')
    etag="${etag%\"}"
    etag="${etag#\"}"
    etags[$4]=$etag
}

function upload_part_copy() {
	local RESPONSE
	RESPONSE=$(aws s3api --endpoint-url $AWS_ENDPOINT --no-verify-ssl upload-part-copy --bucket $1 --key $2 --part-number $4 --upload-id  $3  --copy-source "$1/$5")
	#CopyPartResult.Etag
	if [[ $? -ne 0 ]]; then
        errecho "ERROR:  AWS reports s3api upload-part-copy operation failed.\n$RESPONSE"
        errors['multipart-upload']="Failed in upload_part_copy with RESPONSE: \n$RESPONSE"
        return 1
    fi

    local etag=$(echo $RESPONSE | jq -r 'select(.CopyPartResult != null) | .CopyPartResult.ETag')
    etag="${etag%\"}"
    etag="${etag#\"}"
    etags[$4]=$etag
}

function complete_multipart() {
	local RESPONSE
	# file contains json {"Parts": [{"ETag":<tag in quotes>, "PartNumber":<ints>}]}
	RESPONSE=$(aws s3api --endpoint-url $AWS_ENDPOINT --no-verify-ssl complete-multipart-upload --multipart-upload file://$4 --bucket $1 --key $2 --upload-id $3)
	if [[ $? -ne 0 ]]; then
        errecho "ERROR:  AWS reports s3api complete-multipart-upload operation failed.\n$RESPONSE"
        errors['multipart-upload']="Failed in complete_multipart with RESPONSE: \n$RESPONSE"
        return 1
    fi
}

function create_file() {
  # pass desired size in mb and filename
  let size_in_bytes=$1*1024*1024
  file_name=$2
  #fallocate -l ${size_in_bytes} ${file_name}
  # head -c 5MB /dev/zero > ostechnix.txt
  yes "file: $file_name" | head -c $1MB > $file_name
}


function storage_validations() {
  # Create files for upload
  create_file 6 1.txt
  create_file 7 2.txt
  create_file 9 3.txt
  create_file 1 4.txt
  # check both buckets exist
  bucket_exists $BUCKET_1
  bucket_exists $BUCKET_2
  # upload files to one bucket
  copy_local_file_to_bucket $BUCKET_1 1.txt 1.txt
  copy_local_file_to_bucket $BUCKET_1 2.txt 2.txt

  copy_local_file_to_bucket $BUCKET_1 3.txt 3.txt
  copy_local_file_to_bucket $BUCKET_1 4.txt 4.txt

  list_items_in_bucket_paginated $BUCKET_1
  
  # validate list works, todo: pagination
  echoinfo "verify 1/2/3/4.txt is present"
  list_items_in_bucket $BUCKET_1

  # delete multiple
  delete_query='Objects=[{Key="3.txt"},{Key="4.txt"}]'
  delete_multiple $BUCKET_1 $delete_query
  echoinfo "verify 1/2.txt is present & 3/4.txt are no more"
  list_items_in_bucket $BUCKET_1

  # validate copy works within bucket
  copy_item_in_bucket $BUCKET_1 1.txt 1-copy.txt
  # validate copy to second bucket
  copy_items_across_buckets $BUCKET_1 $BUCKET_2 1.txt
  echoinfo "verify 1.txt is present"
  list_items_in_bucket $BUCKET_2
  # validate counts
  validate_bucket_counts
  # validate delete & count post delete
  delete_item_in_bucket $BUCKET_2 1.txt
  # validate_bucket_counts

  # validate multipart upload
  local key="combined.txt"
  create_multipart $BUCKET_1 $key
  upload_part_copy $BUCKET_1 $key $UPLOAD_ID 1 1.txt
  upload_part $BUCKET_1 $key $UPLOAD_ID 2 3.txt
  # last part < 5MB
  upload_part $BUCKET_1 $key $UPLOAD_ID 3 4.txt
  # write json of parts to parts.json
  # for part in "${!etags[@]}"; do echo "$part - ${etags[$part]}"; done
  myjson='{"Parts": []}'
  for part in "${!etags[@]}"
  do 
    myjson=$(echo -n "$myjson" | jq --arg pn $part --arg etag "${etags[$part]}" '.Parts += [{"PartNumber": ($pn | tonumber), "ETag": $etag}]')
  done
  echo $myjson > parts.json

  complete_multipart $BUCKET_1 $key $UPLOAD_ID parts.json

  # download full file
  download_file $BUCKET_1 $key
  echoinfo "verify that file size is about 15MB"
  ls -lh $key

  len=${#errors[@]}
  if [[ $len -ne 0 ]]; then
    echoinfo "All tests passed successfully, please check individual logs above for any discrepancy"
  else
  	errecho "The following tests failed. Please check individual log statements above"
  	for part in "${!errors[@]}"; do errecho "Failed $part with error - ${errors[$part]}"; done
  fi



  # Get signedurl from bucket 1
  # upload using signedurl
  # Check CORS???
}


# Validate Setup
validate_setup

# Update ENV Variables
initialize_variables

storage_validations