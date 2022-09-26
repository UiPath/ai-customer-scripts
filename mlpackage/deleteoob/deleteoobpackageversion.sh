#!/bin/bash

: '
This scipt will delete OOB package version.
# $1 - json file with database credentials, OOB package name and version
'
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)

echo "$green $(date) Deleting OOB package version $default"
readonly INPUT_FILE=$1

# Validate dependency module
# $1 - Name of the dependency module
# $2 - Command to validate module
function validate_dependency() {
  eval $2
  # Next statement is checking last command success
  if [ $? -ne 0 ]; then
    echo "$red $(date) Please install ******** $1 ***********  ... Exiting $default"
    exit 1
  fi
}

# Validate required modules exits in target setup
function validate_setup() {
  validate_dependency "aws s3" "aws --version"
  validate_dependency jq "jq --version"
  validate_dependency sqlcmd "sqlcmd -?"
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

function validate_input() {

  # Validate file path
  validate_file_path $INPUT_FILE

  readonly OOB_PACKAGE_NAME=$(cat $INPUT_FILE | jq -r 'select(.oobPackageName != null) | .oobPackageName')
  readonly OOB_PACKAGE_VERSION=$(cat $INPUT_FILE | jq -r 'select(.oobPackageVersion != null) | .oobPackageVersion')
  readonly DB_CONN=$(cat $INPUT_FILE | jq -r 'select(.dbConnection != null) | .dbConnection')
  readonly DB_NAME=$(cat $INPUT_FILE | jq -r 'select(.dbName != null) | .dbName')
  readonly DB_USER=$(cat $INPUT_FILE | jq -r 'select(.dbUser != null) | .dbUser')
  readonly DB_PASSWORD="$(cat $INPUT_FILE | jq -r 'select(.dbPassword != null) | .dbPassword')"


  if [[ -z $DB_CONN || -z $DB_NAME || -z $DB_USER || -z $DB_PASSWORD || -z OOB_PACKAGE_NAME || -z OOB_PACKAGE_VERSION ]]; then
    echo "$red $(date) Input is invalid or missing, Please check ... Exiting $default"
    exit 1
  fi

  echo "$green $(date) Successfully validated user input $default"
}

function initialize_object_store_variables() {

	STORAGE_ACCESS_KEY=$(kubectl -n uipath get secret ceph-object-store-secret -o json | jq '.data.OBJECT_STORAGE_ACCESSKEY' | sed -e 's/^"//' -e 's/"$//' | base64 -d)
	OBJECT_GATEWAY_EXTERNAL_HOST=$(kubectl -n uipath get secret ceph-object-store-secret -o json | jq '.data.OBJECT_STORAGE_EXTERNAL_HOST' | sed -e 's/^"//' -e 's/"$//' | base64 -d)
	OBJECT_GATEWAY_EXTERNAL_PORT=$(kubectl -n uipath get secret ceph-object-store-secret -o json | jq '.data.OBJECT_STORAGE_EXTERNAL_PORT' | sed -e 's/^"//' -e 's/"$//' | base64 -d)
	STORAGE_SECRET_KEY=$(kubectl -n uipath get secret ceph-object-store-secret -o json | jq '.data.OBJECT_STORAGE_SECRETKEY' | sed -e 's/^"//' -e 's/"$//' | base64 -d)

	readonly AWS_HOST=$OBJECT_GATEWAY_EXTERNAL_HOST
	readonly AWS_ENDPOINT="https://${OBJECT_GATEWAY_EXTERNAL_HOST}:${OBJECT_GATEWAY_EXTERNAL_PORT}"
	readonly AWS_ACCESS_KEY_ID=$STORAGE_ACCESS_KEY
	readonly AWS_SECRET_ACCESS_KEY=$STORAGE_SECRET_KEY

}

function configure_aws() {
    aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
    aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
    aws configure set region test1
    aws configure set output json
}

function delete_ml_package_version() {

  readonly ML_PACKAGE_ID=$(sqlcmd -S tcp:$DB_CONN -d $DB_NAME -U $DB_USER -P $DB_PASSWORD  -h -1 -W -Q  "set nocount on; select id from ai_pkgmanager.ml_packages where name = '$OOB_PACKAGE_NAME'")

  ML_PACKAGE_VERSION_DETAILS=$(sqlcmd -S tcp:$DB_CONN -d $DB_NAME -U $DB_USER -P $DB_PASSWORD  -h -1 -W -Q  "set nocount on; select id, account_id, tenant_id, project_id, content_uri from ai_pkgmanager.ml_package_versions where ml_package_id = '$ML_PACKAGE_ID' and version = $OOB_PACKAGE_VERSION")
  ml_package_version_details=(${ML_PACKAGE_VERSION_DETAILS// / })
  ml_package_version_id=${ml_package_version_details[0]}
  echo ml_package_version_id
  account_id=${ml_package_version_details[1]}
  echo $account_id
  tenantId=${ml_package_version_details[2]}
  echo $tenantId
  projectId=${ml_package_version_details[3]}
  echo $projectId
  contentUri=${ml_package_version_details[4]}
  echo $contentUri
  zipFileDetailArr=(${contentUri//"/"/ })
  len=${#zipFileDetailArr[@]}
  zipFile=${zipFileDetailArr[len-1]}
  echo $zipFile

  sqlcmd -S tcp:$DB_CONN -d $DB_NAME -U $DB_USER -P $DB_PASSWORD  -h -1 -W -Q  "set nocount on; delete from ai_pkgmanager.ml_package_versions where id = $ml_package_version_id"

}

function delete_version_zip_file() {

  aws --endpoint-url $AWS_ENDPOINT --no-verify-ssl s3api delete-object --bucket my-bucket --key test.txt
}


validate_setup

validate_input

initialize_object_store_variables

configure_aws

delete_ml_package_version

delete_version_zip_file
