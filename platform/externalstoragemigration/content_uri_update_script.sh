#!/bin/bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)

STORAGETYPE=$1
HOST=$2
USERNAME=$3
PASSOWORD=$4
DBNAME=$5

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

# function to validate database connection
function validate_dbconn() {

    echo "$green Validating connection to $HOST $default"

    result=$(sqlcmd -S ${HOST} -U ${USERNAME} -P ${PASSOWORD} -d ${DBNAME} -Q "SELECT DB_NAME()" )

    if [ $? -ne 0 ];
    then
            echo "$red Error while connecting to SQL Server -> $HOST and Database -> $DBNAME . Please check database details provided"
            exit 1;
    else
            echo "Connection to $HOST sql server and $DBNAME database established successfully $default"
    fi
}

function check_input_value() {
  if [ -z "$2" ];
  then
    echo "$red $(date) $1 is blank or not provided $default"
    exit 1;
  elif [ "$1" == "STORAGETYPE" ];
  then
    if [[ "$2" != "azure" && "$2" != "s3" ]];
    then
    echo "$red $(date) $1 allowed values are azure or s3 $default"
    exit 1;
    fi
  else
    echo "$green $(date) $1 is provided $default"
  fi
}


function update_content_uri_azure() {

echo "$green Executing updated content uri in azure in $HOST $default"

STORAGE_HOST=$(kubectl -n uipath get secret aicenter-external-storage-secret -o json | jq '.data.ACCOUNTNAME' | sed -e 's/^"//' -e 's/"$//' | base64 -d)

STORAGE_HOST_SUFFIX=$(kubectl -n uipath get secret aicenter-external-storage-secret -o json | jq '.data.AZURE_FQDN_SUFFIX' | sed -e 's/^"//' -e 's/"$//' | base64 -d)

BUCKET_NAME=$(kubectl -n uipath get secret aicenter-external-storage-secret -o json | jq '.data.BUCKET' | sed -e 's/^"//' -e 's/"$//' | base64 -d)

check_input_value "Secret STORAGE_HOST" $STORAGE_HOST
check_input_value "Secret STORAGE_HOST_SUFFIX" $STORAGE_HOST_SUFFIX
check_input_value "Secret BUCKET_NAME" $BUCKET_NAME


sqlcmd -S ${HOST} -U ${USERNAME} -P ${PASSOWORD} -d ${DBNAME} -Q " UPDATE ai_pkgmanager.ml_package_versions set content_uri = 'https://${STORAGE_HOST}.blob.${STORAGE_HOST_SUFFIX}/${BUCKET_NAME}' + '/' + REPLACE(REPLACE(LEFT(content_uri, CHARINDEX('?generation=', content_uri) - 1), 'https://rook-ceph-rgw-rook-ceph.rook-ceph.svc.cluster.local:80/download/storage/v1/b/ml-model-files/o/', ''), '/', '%2f') WHERE content_uri like '%rook-ceph.svc.cluster.local%'; "

 if [ $? -ne 0 ];
    then
            echo "Error in running query"
            exit 1;
    else
            echo "Query successfully executed"
    fi
}

function update_content_uri_s3(){

echo "$green Executing updated content uri in s3 in $HOST $default"

BUCKET_NAME=$(kubectl -n uipath get secret aicenter-external-storage-secret -o json | jq '.data.BUCKET' | sed -e 's/^"//' -e 's/"$//' | base64 -d)


sqlcmd -S ${HOST} -U ${USERNAME} -P ${PASSOWORD} -d ${DBNAME} -Q " UPDATE ai_pkgmanager.ml_package_versions set content_uri = REPLACE(REPLACE(content_uri,'rook-ceph-rgw-rook-ceph.rook-ceph.svc.cluster.local','127.0.0.1'),'/ml-model-files/','/$BUCKET_NAME/') where content_uri like '%rook-ceph.svc.cluster.local%';"

 if [ $? -ne 0 ];
    then
            echo "Error in running query"
            exit 1;
    else
            echo "Query successfully executed"
    fi

}

check_input_value "STORAGETYPE" $STORAGETYPE
check_input_value "HOST" $HOST
check_input_value "USERNAME" $USERNAME
check_input_value "PASSOWORD" $PASSOWORD
check_input_value "DBNAME" $DBNAME

validate_dependency "sqlcmd utility" "sqlcmd -?"
validate_dependency "jq utility" "jq --version"

validate_dbconn

if [ "${STORAGETYPE}" == "azure" ];
then
update_content_uri_azure
else
update_content_uri_s3
fi