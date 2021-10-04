#!/bin/bash

check_input_value(){
  if [ -z "$1" ];
  then
    echo "$2 is blank or not provided"
    ERROR="${ERROR} \n $2 is blank or not provided"
  else
    echo "$2 is provided"
  fi
}

function validate_and_parse_creds_file_data(){
echo "validate_and_parse_creds_file_data started"
echo cat $CREDENTIALS_FILE
export SRC_SERVER=$(cat $CREDENTIALS_FILE | jq -r 'select(.SRC_SERVER != null) | .SRC_SERVER')

echo "Validation started 1"
export SRC_PKGMANAGER_DB_NAME=$(cat $CREDENTIALS_FILE | jq -r 'select(.SRC_PKGMANAGER_DB_NAME != null) | .SRC_PKGMANAGER_DB_NAME')

export SRC_PKGMANAGER_DB_SCHEMA=$(cat $CREDENTIALS_FILE | jq -r 'select(.SRC_PKGMANAGER_DB_SCHEMA != null) | .SRC_PKGMANAGER_DB_SCHEMA')

export SRC_PKGMANAGER_DB_USERNAME=$(cat $CREDENTIALS_FILE | jq -r 'select(.SRC_PKGMANAGER_DB_USERNAME != null) | .SRC_PKGMANAGER_DB_USERNAME')

export SRC_PKGMANAGER_DB_PASSWORD=$(cat $CREDENTIALS_FILE | jq -r 'select(.SRC_PKGMANAGER_DB_PASSWORD != null) | .SRC_PKGMANAGER_DB_PASSWORD')

export SRC_TRAINER_DB_NAME=$(cat $CREDENTIALS_FILE | jq -r 'select(.SRC_TRAINER_DB_NAME != null) | .SRC_TRAINER_DB_NAME')

export SRC_TRAINER_DB_SCHEMA=$(cat $CREDENTIALS_FILE | jq -r 'select(.SRC_TRAINER_DB_SCHEMA != null) | .SRC_TRAINER_DB_SCHEMA')

export SRC_TRAINER_DB_USERNAME=$(cat $CREDENTIALS_FILE | jq -r 'select(.SRC_TRAINER_DB_USERNAME != null) | .SRC_TRAINER_DB_USERNAME')

export SRC_TRAINER_DB_PASSWORD=$(cat $CREDENTIALS_FILE | jq -r 'select(.SRC_TRAINER_DB_PASSWORD != null) | .SRC_TRAINER_DB_PASSWORD')

export DESTINATION_SERVER=$(cat $CREDENTIALS_FILE | jq -r 'select(.DESTINATION_SERVER != null) | .DESTINATION_SERVER')

export DESTINATION_DB_NAME=$(cat $CREDENTIALS_FILE | jq -r 'select(.DESTINATION_DB_NAME != null) | .DESTINATION_DB_NAME')

export DESTINATION_PKGMANAGER_DB_SCHEMA=$(cat $CREDENTIALS_FILE | jq -r 'select(.DESTINATION_PKGMANAGER_DB_SCHEMA != null) | .DESTINATION_PKGMANAGER_DB_SCHEMA')

export DESTINATION_TRAINER_DB_SCHEMA=$(cat $CREDENTIALS_FILE | jq -r 'select(.DESTINATION_TRAINER_DB_SCHEMA != null) | .DESTINATION_TRAINER_DB_SCHEMA')

export DESTINATION_DB_USERNAME=$(cat $CREDENTIALS_FILE | jq -r 'select(.DESTINATION_DB_USERNAME != null) | .DESTINATION_DB_USERNAME')

export DESTINATION_DB_PASSWORD=$(cat $CREDENTIALS_FILE | jq -r 'select(.DESTINATION_DB_PASSWORD != null) | .DESTINATION_DB_PASSWORD')

echo "validate_and_parse_creds_file_data ended"
}

validate_and_parse_creds_file_data

check_input_value $SRC_SERVER "SRC_SERVER"
check_input_value $SRC_PKGMANAGER_DB_NAME "Sql Source Pkg manager DB name"
check_input_value $SRC_PKGMANAGER_DB_SCHEMA "Sql Source Pkg manager DB schema"
check_input_value $SRC_PKGMANAGER_DB_USERNAME "Sql Source Pkg manager DB username"
check_input_value $SRC_PKGMANAGER_DB_PASSWORD "Sql Source Pkg manager DB password"
check_input_value $SRC_TRAINER_DB_NAME "Sql Source trainer DB name"
check_input_value $SRC_TRAINER_DB_SCHEMA "Sql Source trainer DB schema"
check_input_value $SRC_TRAINER_DB_USERNAME "Sql Source trainer DB username"
check_input_value $SRC_TRAINER_DB_PASSWORD "Sql Source trainer DB password"
check_input_value $DESTINATION_SERVER "Sql destination DB server"
check_input_value $DESTINATION_DB_NAME "Sql destination DB name"
check_input_value $DESTINATION_PKGMANAGER_DB_SCHEMA "Sql destination pkg manager DB schema"
check_input_value $DESTINATION_TRAINER_DB_SCHEMA "Sql destination trainer DB schema"
check_input_value $DESTINATION_DB_USERNAME "Sql destination DB username"
check_input_value $DESTINATION_DB_PASSWORD "Sql destination DB password"

