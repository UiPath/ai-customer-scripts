#!/bin/bash

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
            echo "$red Error while connecting to SQL Server -> $1 and Database -> $4 . Please check database details provided in input file $default"
            ERROR="${ERROR} \n Database Check Failed: Error while connecting to $1."
            exit 1;
    else
            echo "$green Connection to $1 sql server and $4 database established successfully $default"
    fi
}



# function to validate database schemas
validate_dbconn_schema() {
    host=$1
    user=$2
    pass=$3
    database=$4
    dbschema=$5

    # Sample query
    SAMPLE_QUERY_SCHEMA="set nocount on;SELECT count(*) FROM sys.schemas where name = '${dbschema}'"


    result=$(sqlcmd -S ${host} -U ${user} -P ${pass} -d $database -h -1 -Q "${SAMPLE_QUERY_SCHEMA}" )

    if [ $result != 1 ];
    then
            echo "$red Error while connecting to SQl Server -> $1 , Database -> $4 ,  Schema-> $5 . Please check Schema details provided in input file $default"
            ERROR="${ERROR} \n Database Check Failed: Error while connecting to Server -> $1 ,  Database -> $4 and Schema -> $5"
            exit 1;
    else
            echo "$green Connection to $1 sql server and $4 database established successfully $default"
    fi
}

  echo "Validating Database schema "

  validate_dbconn $SRC_SERVER $SRC_PKGMANAGER_DB_USERNAME $SRC_PKGMANAGER_DB_PASSWORD $SRC_PKGMANAGER_DB_NAME

  validate_dbconn $SRC_SERVER $SRC_TRAINER_DB_USERNAME $SRC_TRAINER_DB_PASSWORD $SRC_TRAINER_DB_NAME

  validate_dbconn $DESTINATION_SERVER $DESTINATION_DB_USERNAME $DESTINATION_DB_PASSWORD $DESTINATION_DB_NAME

  validate_dbconn_schema $SRC_SERVER $SRC_PKGMANAGER_DB_USERNAME $SRC_PKGMANAGER_DB_PASSWORD $SRC_PKGMANAGER_DB_NAME $SRC_PKGMANAGER_DB_SCHEMA

    validate_dbconn_schema $SRC_SERVER $SRC_TRAINER_DB_USERNAME $SRC_TRAINER_DB_PASSWORD $SRC_TRAINER_DB_NAME $SRC_TRAINER_DB_SCHEMA

  validate_dbconn_schema $DESTINATION_SERVER $DESTINATION_DB_USERNAME $DESTINATION_DB_PASSWORD $DESTINATION_DB_NAME $DESTINATION_PKGMANAGER_DB_SCHEMA

  validate_dbconn_schema $DESTINATION_SERVER $DESTINATION_DB_USERNAME $DESTINATION_DB_PASSWORD $DESTINATION_DB_NAME $DESTINATION_TRAINER_DB_SCHEMA

  echo "Database connections validation completed"
