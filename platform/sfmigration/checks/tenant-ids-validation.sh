#!/bin/bash

# function to validate source and destination account and tenant ids
validate_tenant_and_account_ids() {
    host=$1
    user=$2
    pass=$3
    database=$4
    dbschema=$5
    accountId=$6
    tenantId=$7

    SAMPLE_QUERY="set nocount on;SELECT count(*) from ${dbschema}.public_tenants where tenant_id='$tenantId' and account_id='$accountId' "

    result=$(sqlcmd -S ${host} -U ${user} -P ${pass} -d $database -h -1 -Q "${SAMPLE_QUERY}" )

    if [ $result != 1 ];
    then
            echo "$red Error while checking for tenant id $tenantId and $accountId , Please ensure the account and tenant ids exist in the database $default"
            ERROR="${ERROR} \n Error while checking for tenant id $tenantId and $accountId"
            exit 1;
    else
            echo "$green Successfully checked for tenant id $tenantId and $accountId $default"
    fi
}

  echo "Started Source and destination tenant ids"


jq -c '.TENANT_MAP[]' $1 | while read tenantEntry; do
    # Loop through each element of array
  # TODO: why we are exporting the variables when we are passing them as an argument.
	SRC_TENANT_ID=$(echo $tenantEntry | jq -r '.SRC_TENANT_ID')
	DESTINATION_TENANT_ID=$(echo $tenantEntry | jq -r '.DESTINATION_TENANT_ID')
	DESTINATION_ACCOUNT_ID=$(echo $tenantEntry | jq -r '.DESTINATION_ACCOUNT_ID')

	validate_tenant_and_account_ids $SRC_SERVER $SRC_PKGMANAGER_DB_USERNAME $SRC_PKGMANAGER_DB_PASSWORD $SRC_PKGMANAGER_DB_NAME $SRC_PKGMANAGER_DB_SCHEMA "host" $SRC_TENANT_ID
	echo "$(date) Successfully validated source tenant id $default"
	validate_tenant_and_account_ids $DESTINATION_SERVER $DESTINATION_DB_USERNAME $DESTINATION_DB_PASSWORD $DESTINATION_DB_NAME $DESTINATION_PKGMANAGER_DB_SCHEMA $DESTINATION_ACCOUNT_ID $DESTINATION_TENANT_ID
	echo "$green $(date) Successfully validated destination tenant id $default"

done
