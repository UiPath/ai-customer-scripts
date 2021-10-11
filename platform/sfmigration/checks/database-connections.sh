#!/bin/bash

# Sample query
SAMPLE_QUERY="SELECT DB_NAME()"

# function to validate database connection
validate_dbconn() {
    host=$1
    user=$2
    pass=$3
    database=$4

    echo "$green Validating connection to $1 $default"

    result=$(sqlcmd -S ${host} -U ${user} -P ${pass} -d $database -Q "${SAMPLE_QUERY}" )

    if [ $? -ne 0 ];
    then
            echo "$red Error while connecting to $1 server and $4 database Please check $default"
            ERROR="${ERROR} \n Database Check Failed: Error while connecting to $1."
            exit 1;
    else
            echo "$green Connection to $1 sql server and $4 database established successfully $default"
    fi
}

  echo "Validating Database connections"

  validate_dbconn $SRC_SERVER $SRC_PKGMANAGER_DB_USERNAME $SRC_PKGMANAGER_DB_PASSWORD $SRC_PKGMANAGER_DB_NAME

    validate_dbconn $SRC_SERVER $SRC_TRAINER_DB_USERNAME $SRC_TRAINER_DB_PASSWORD $SRC_TRAINER_DB_NAME

  validate_dbconn $DESTINATION_SERVER $DESTINATION_DB_USERNAME $DESTINATION_DB_PASSWORD $DESTINATION_DB_NAME

  echo "Database connections validation completed"

