#!/bin/bash

# Migrate database tables from source database to destination database
# $1 - Table Name whose data needs to be migrated
# $2 - Source db server
# $3 - Source db name
# $4 - Source db schema
# $5 - Source db username
# $6 - Source db password
# $7 - Destination db server
# $8 - Destination db name
# $9 - Destination db schema
# $10 - Destination db username
# $11 - Destination db password
# $12 - Tenant id in the source db to be migrated
# $13 - Tenant id in the destination db to be migrated
# $14 - Account id in the destination db to be migrated
function migrate_database_table_data() {
echo "Database table migration started"

  TableName=$1
  SRC_SERVER=$2
  SRC_DB_NAME=$3
  SRC_DB_SCHEMA=$4
  SRC_DB_USERNAME=$5
  SRC_DB_PASSWORD=$6
  DESTINATION_SERVER=$7
  DESTINATION_DB_NAME=$8
  DESTINATION_DB_SCHEMA=$9
  DESTINATION_DB_USERNAME=${10}
  DESTINATION_DB_PASSWORD=${11}
  SRC_TENANT_ID=${12}
  DESTINATION_TENANT_ID=${13}
  DESTINATION_ACCOUNT_ID=${14}
  SRC_AIC_INSTALLATION_VERSION=${15}
  
echo "SRC_SERVER = $SRC_SERVER"
echo "SRC_DB_NAME = $SRC_DB_NAME"
echo "SRC_DB_SCHEMA = $SRC_DB_SCHEMA"
echo "SRC_DB_USERNAME = $SRC_DB_USERNAME"
echo "SRC_DB_PASSWORD = $SRC_DB_PASSWORD"
echo "DESTINATION_SERVER = $DESTINATION_SERVER"
echo "DESTINATION_DB_NAME = $DESTINATION_DB_NAME"
echo "DESTINATION_DB_SCHEMA = $DESTINATION_DB_SCHEMA"
echo "DESTINATION_DB_USERNAME = $DESTINATION_DB_USERNAME"
echo "DESTINATION_DB_PASSWORD = $DESTINATION_DB_PASSWORD"
echo "SRC_TENANT_ID = $SRC_TENANT_ID"
echo "DESTINATION_TENANT_ID = $DESTINATION_TENANT_ID"
echo "DESTINATION_ACCOUNT_ID = $DESTINATION_ACCOUNT_ID"
echo "SRC_AIC_INSTALLATION_VERSION = $SRC_AIC_INSTALLATION_VERSION"
    
echo ""
echo "*************************************************************************"

echo $TableName " Migration started"

#BCP [$SRC_DB_NAME].[$SRC_DB_SCHEMA].[$TableName] format nul -n -S $SRC_SERVER  -U $SRC_DB_USERNAME -P $SRC_DB_PASSWORD -f $TableName.fmt 

if [ "${TableName}" == "ml_package_versions" ];
then
DestTempTableName="${TableName}_temp"
echo "TableName--> " $DestTempTableName
else
DestTempTableName="${TableName}"
echo "TableName--> " $DestTempTableName
fi

bcp "SELECT * FROM ["$SRC_DB_SCHEMA"].["$TableName"] where tenant_id = '"$SRC_TENANT_ID"'" queryout $DestTempTableName.dat -n -S $SRC_SERVER  -U $SRC_DB_USERNAME -P $SRC_DB_PASSWORD -d $SRC_DB_NAME

echo $TableName " Export Done"

bcp [$DESTINATION_DB_NAME].[$DESTINATION_DB_SCHEMA].[$DestTempTableName] in $DestTempTableName.dat -n -S $DESTINATION_SERVER -U $DESTINATION_DB_USERNAME -P $DESTINATION_DB_PASSWORD -f $ABSOLUTE_BASE_PATH/databasemigration/$SRC_AIC_INSTALLATION_VERSION/$DestTempTableName.fmt

echo $TableName " Import Done"

echo "*************************************************************************"


# update tenant id in the destination database

sqlcmd -S $DESTINATION_SERVER -U $DESTINATION_DB_USERNAME -P $DESTINATION_DB_PASSWORD -d $DESTINATION_DB_NAME -Q "update "$DESTINATION_DB_SCHEMA"."$DestTempTableName" set tenant_id = '"$DESTINATION_TENANT_ID"' , account_id = '"$DESTINATION_ACCOUNT_ID"' where tenant_id = '"$SRC_TENANT_ID"';"

echo "Database table migration finished"

}

# Table names to be migrated

export CREDENTIALS_FILE=$1

export SRC_TENANT_ID=$2

export DESTINATION_TENANT_ID=$3

export DESTINATION_ACCOUNT_ID=$4

# Table names in ai-pkgmanager db to be migrated
PkgManagerDBTableNames=( projects ml_packages ml_package_versions)

# Table names in ai-trainer db to be migrated
TrainerDBTableNames=( datasets)

sqlcmd -v DestinationDBSchema=$DESTINATION_PKGMANAGER_DB_SCHEMA -S $DESTINATION_SERVER -U $DESTINATION_DB_USERNAME -P $DESTINATION_DB_PASSWORD -d $DESTINATION_DB_NAME -i $ABSOLUTE_BASE_PATH/databasemigration/$SRC_AIC_INSTALLATION_VERSION/create_temp_table.sql

# Updating all the table for ai_pkgmanager db
for TableName in ${PkgManagerDBTableNames[*]} 
do
if [ "${TableName}" == "ml_package_versions" ];
then
migrate_database_table_data  $TableName $SRC_SERVER $SRC_PKGMANAGER_DB_NAME $SRC_PKGMANAGER_DB_SCHEMA $SRC_PKGMANAGER_DB_USERNAME $SRC_PKGMANAGER_DB_PASSWORD $DESTINATION_SERVER $DESTINATION_DB_NAME $DESTINATION_PKGMANAGER_DB_SCHEMA $DESTINATION_DB_USERNAME $DESTINATION_DB_PASSWORD $SRC_TENANT_ID $DESTINATION_TENANT_ID $DESTINATION_ACCOUNT_ID $SRC_AIC_INSTALLATION_VERSION

sqlcmd -v DestinationDBSchema=$DESTINATION_PKGMANAGER_DB_SCHEMA DestinationTenantId=$DESTINATION_TENANT_ID -S $DESTINATION_SERVER -U $DESTINATION_DB_USERNAME -P $DESTINATION_DB_PASSWORD -d $DESTINATION_DB_NAME -i $ABSOLUTE_BASE_PATH/databasemigration/$SRC_AIC_INSTALLATION_VERSION/import_script_temp_to_ml_package_versions.sql

else
migrate_database_table_data  $TableName $SRC_SERVER $SRC_PKGMANAGER_DB_NAME $SRC_PKGMANAGER_DB_SCHEMA $SRC_PKGMANAGER_DB_USERNAME $SRC_PKGMANAGER_DB_PASSWORD $DESTINATION_SERVER $DESTINATION_DB_NAME $DESTINATION_PKGMANAGER_DB_SCHEMA $DESTINATION_DB_USERNAME $DESTINATION_DB_PASSWORD $SRC_TENANT_ID $DESTINATION_TENANT_ID $DESTINATION_ACCOUNT_ID $SRC_AIC_INSTALLATION_VERSION
fi
done

# Updating all the table for ai_trainer db
for TableName in ${TrainerDBTableNames[*]} 
do
migrate_database_table_data  $TableName $SRC_SERVER $SRC_TRAINER_DB_NAME $SRC_TRAINER_DB_SCHEMA $SRC_TRAINER_DB_USERNAME $SRC_TRAINER_DB_PASSWORD $DESTINATION_SERVER $DESTINATION_DB_NAME $DESTINATION_TRAINER_DB_SCHEMA $DESTINATION_DB_USERNAME $DESTINATION_DB_PASSWORD $SRC_TENANT_ID $DESTINATION_TENANT_ID $DESTINATION_ACCOUNT_ID $SRC_AIC_INSTALLATION_VERSION
done


# update cloned packages source package id , source package version ids
sqlcmd -v DestinationDBSchema=$DESTINATION_PKGMANAGER_DB_SCHEMA DestinationTenantId=$DESTINATION_TENANT_ID -S $DESTINATION_SERVER -U $DESTINATION_DB_USERNAME -P $DESTINATION_DB_PASSWORD -d $DESTINATION_DB_NAME -i $ABSOLUTE_BASE_PATH/databasemigration/UpdateClonedPackageReferences.sql
