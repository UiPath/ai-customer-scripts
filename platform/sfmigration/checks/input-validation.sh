#!/bin/bash

check_input_value(){
  if [ -z "$2" ];
  then
    echo "$red $(date) $1 in $CREDENTIALS_FILE is blank or not provided $default"
    exit 1;
  elif [ "$1" == "SRC_AIC_INSTALLATION_VERSION" ];
  then
    if [[ "$2" != "20.10" && "$2" != "21.4" ]];
    then
    echo "$red $(date) $1 allowed values are 20.10 or 21.4 $default"
    exit 1;
    fi
  else
    echo "$green $(date) $1 is provided $default"
  fi
}

function validate_and_parse_creds_file_data() {
echo "validate_and_parse_creds_file_data started"
echo "Parsing input file : " $CREDENTIALS_FILE

export SRC_AIC_INSTALLATION_VERSION=$(cat $CREDENTIALS_FILE | jq -r 'select(.SRC_AIC_INSTALLATION_VERSION != null) | .SRC_AIC_INSTALLATION_VERSION')

export SRC_SERVER=$(cat $CREDENTIALS_FILE | jq -r 'select(.SRC_SERVER != null) | .SRC_SERVER')

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

echo "$green $(date) Successfully parsed $CREDENTIALS_FILE file $default"
}

validate_and_parse_creds_file_data

check_input_value "SRC_AIC_INSTALLATION_VERSION" $SRC_AIC_INSTALLATION_VERSION
check_input_value "SRC_SERVER" $SRC_SERVER
check_input_value "Sql Source Pkg manager DB name" $SRC_PKGMANAGER_DB_NAME
check_input_value "Sql Source Pkg manager DB schema" $SRC_PKGMANAGER_DB_SCHEMA
check_input_value "Sql Source Pkg manager DB username" $SRC_PKGMANAGER_DB_USERNAME
check_input_value "Sql Source Pkg manager DB password" $SRC_PKGMANAGER_DB_PASSWORD
check_input_value "Sql Source trainer DB name" $SRC_TRAINER_DB_NAME
check_input_value "Sql Source trainer DB schema" $SRC_TRAINER_DB_SCHEMA
check_input_value "Sql Source trainer DB username" $SRC_TRAINER_DB_USERNAME
check_input_value "Sql Source trainer DB password" $SRC_TRAINER_DB_PASSWORD
check_input_value "Sql destination DB server" $DESTINATION_SERVER
check_input_value "Sql destination DB name" $DESTINATION_DB_NAME
check_input_value "Sql destination pkg manager DB schema" $DESTINATION_PKGMANAGER_DB_SCHEMA
check_input_value "Sql destination trainer DB schema" $DESTINATION_TRAINER_DB_SCHEMA
check_input_value "Sql destination DB username" $DESTINATION_DB_USERNAME
check_input_value "Sql destination DB password" $DESTINATION_DB_PASSWORD

