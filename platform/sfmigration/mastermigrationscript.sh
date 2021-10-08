#!/bin/bash

: '
This is the master script which will migrate db entities , datasets , ML Packages from source AIC environment to target AIC environment
# $1 - input json file with db credentials and details of tenant to be migrated from src to destination

[Script Version -> 21.10]
'

ERROR=""
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)

readonly CREDENTIALS_FILE=$1
export ABSOLUTE_BASE_PATH=$(pwd)

# Validate file provided by user exists or not, It may be relative path or absolute path
# $1 - File path

# TODO: Add more file paths to be validated.
function validate_file_path() {
  if [ ! -f "$1" ]; then
    echo "$red $(date) $1 file does not exist, Please check ... Exiting $default"
    exit 1
  fi
}

# Database migration for a tenant from src to destination environment
# $1 - Credentials file
# $2 - SRC_TENANT_ID
# $3 - DESTINATION_TENANT_ID
# $4 - DESTINATION_ACCOUNT_ID
function db_migration(){
 . ${ABSOLUTE_BASE_PATH}/databasemigration/dbmigration.sh $1 $2 $3 $4
}

function dataset_and_mlpackages_migration(){
  ## run export script
  ./storagemigration/export.sh ./storagemigration/SOURCE_CREDENTIAL_FILE $ABSOLUTE_BASE_PATH/storagemigration/storageData

  ## Run sanitize script.
  ./storagemigration/sanitize.sh $ABSOLUTE_BASE_PATH/storagemigration/storageData/ceph/ml-model-files

  ## Run import script.
  ./storagemigration/import.sh ./storagemigration/TARGET_CREDENTIAL_FILE $ABSOLUTE_BASE_PATH/storagemigration/storageData $1 $2 $3
}

# Function to validate credential file and perform database migration for each tenant
# $1 - Credentials file
function parse_input_and_migrate() {

jq -c '.TENANT_MAP[]' $CREDENTIALS_FILE | while read tenantEntry; do
    # Loop through each element of array
  # TODO: why we are exporting the variables when we are passing them as an argument.
	SRC_TENANT_ID=$(echo $tenantEntry | jq -r '.SRC_TENANT_ID')
	DESTINATION_TENANT_ID=$(echo $tenantEntry | jq -r '.DESTINATION_TENANT_ID')
	DESTINATION_ACCOUNT_ID=$(echo $tenantEntry | jq -r '.DESTINATION_ACCOUNT_ID')
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
. ${ABSOLUTE_BASE_PATH}/checks/input-validation.sh

# Validate Setup dependency
. ${ABSOLUTE_BASE_PATH}/checks/dependency-validation.sh

# Database connection validation
. ${ABSOLUTE_BASE_PATH}/checks/database-connections.sh

# Validate tenant provided tenant and account ids
. ${ABSOLUTE_BASE_PATH}/checks/tenant-ids-validation.sh $CREDENTIALS_FILE

# Trigger DB migration script
parse_input_and_migrate
