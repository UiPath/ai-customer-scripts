#!/bin/bash

: '
This scipt will export all data stored in blob storage from target environments.
# $1 - input json file with credentials

[Script Version -> 21.10]
'
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)


readonly CREDENTIALS_FILE=$1

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
  validate_dependency "bcp utility" "BCP -v"
  validate_dependency "sqlcmd utility" "sqlcmd -?"
  validate_dependency "jq utility" "jq --version"
  echo "$(date) Successfully validated required dependencies"
}

# Validate dependency module
# $1 - Credentials file
# $2 - SRC_TENANT_ID
# $3 - DESTINATION_TENANT_ID
function db_migration(){
 sh ./dbmigrationbcp.bash $1 $2 $3 $4
}

function parse_input_and_migrate_db() {
  # Validate file path
  validate_file_path $CREDENTIALS_FILE

jq -c '.TENANT_MAP[]' $CREDENTIALS_FILE | while read tenantEntry; do
    # Loop through each element of array
	export SRC_TENANT_ID=$(echo $tenantEntry | jq -r '.SRC_TENANT_ID')
	export DESTINATION_TENANT_ID=$(echo $tenantEntry | jq -r '.DESTINATION_TENANT_ID')
	export DESTINATION_ACCOUNT_ID=$(echo $tenantEntry | jq -r '.DESTINATION_ACCOUNT_ID')
	db_migration $CREDENTIALS_FILE $SRC_TENANT_ID $DESTINATION_TENANT_ID $DESTINATION_ACCOUNT_ID
	echo "$(date) Successfully parsed input file and db migration completed"
done
}

# Validate Setup
validate_setup

# Update ENV Variables
parse_input_and_migrate_db