#!/bin/bash

: '
This is the master script which will migrate db entities , datasets , ML Packages from source AIC environment to target AIC environment
# $1 - input json file with db credentials and details of tenant to be migrated from src to destination

[Script Version -> 21.10]
'
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)

## TODO: should we use absolute path at every location.
readonly CREDENTIALS_FILE=$1
export BASE_PATH=$2
readonly ABSOLUTE_BASE_PATH=$(pwd)

# Validate file provided by user exists or not, It may be relative path or absolute path
# $1 - File path

# TODO: Add more file paths to be validated.
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
  # Next statement is checking last command success
  if [ $? -ne 0 ]; then
    echo "$red $(date) Please install ******** $1 ***********  ... Exiting $default"
    exit 1
  fi
}

# Validate required modules exits in target setup
function validate_setup() {
  validate_dependency "bcp utility" "BCP -v"
  validate_dependency "sqlcmd utility" "sqlcmd -?"
  validate_dependency "jq utility" "jq --version"

  echo "$(date) Successfully validated required dependencies"
}

# Database migration for a tenant from src to destination environment
# $1 - Credentials file
# $2 - SRC_TENANT_ID
# $3 - DESTINATION_TENANT_ID
# $4 - DESTINATION_ACCOUNT_ID
function db_migration(){
 sh ./databasemigration/dbmigration.bash $1 $2 $3 $4
}

function dataset_and_mlpackages_migration(){
  # TODO: Do we need to change the extension from sh to bash?
  ## run export script
  sh ./storagemigration/export.sh ./storagemigration/SOURCE_CREDENTIAL_FILE $ABSOLUTE_BASE_PATH/storagemigration/storageData

  ## Run sanitize script.
  sh ./storagemigration/sanitize.sh $ABSOLUTE_BASE_PATH/storagemigration/storageData/ceph/ml-model-files

  ## Run import script.
  sh ./storagemigration/import.sh ./storagemigration/TARGET_CREDENTIALS_FILE $ABSOLUTE_BASE_PATH/storagemigration/storageData $1 $2 $3
}

# Function to validate credential file and perform database migration for each tenant
# $1 - Credentials file
function parse_input_and_migrate() {

jq -c '.TENANT_MAP[]' $CREDENTIALS_FILE | while read tenantEntry; do
    # Loop through each element of array
  # TODO: why we are exporting the variables when we are passing them as an argument.
	export SRC_TENANT_ID=$(echo $tenantEntry | jq -r '.SRC_TENANT_ID')
	export DESTINATION_TENANT_ID=$(echo $tenantEntry | jq -r '.DESTINATION_TENANT_ID')
	export DESTINATION_ACCOUNT_ID=$(echo $tenantEntry | jq -r '.DESTINATION_ACCOUNT_ID')
	BUCKET_NAME="train-data"
	db_migration $CREDENTIALS_FILE $SRC_TENANT_ID $DESTINATION_TENANT_ID $DESTINATION_ACCOUNT_ID
	echo "$(date) Successfully parsed input file and db migration completed."
	dataset_and_mlpackages_migration $SRC_TENANT_ID $DESTINATION_TENANT_ID $BUCKET_NAME
	echo "$(date) Successfully migrated datasets and mlpackages."
done
}

# Validate Credential file
validate_file_path $CREDENTIALS_FILE

# Validate Credential file input and export data
# ./databasemigration/input-validation.sh

# Validate Setup
validate_setup

# Trigger DB migration script
parse_input_and_migrate
