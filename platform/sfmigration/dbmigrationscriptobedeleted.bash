# Sample command to run script
echo "Sample execution sh dbmigrationscript.bash SRC_SERVER=sf-migration-onlinesqlserver.database.windows.net SRC_PKGMANAGER_DB_NAME=aifabric_sfmigrationonline SRC_PKGMANAGER_DB_SCHEMA=ai_pkgmanager SRC_PKGMANAGER_DB_USERNAME=aifadmin SRC_PKGMANAGER_DB_PASSWORD=admin@12 SRC_TRAINER_DB_NAME=aifabric_sfmigrationonline SRC_TRAINER_DB_SCHEMA=ai_trainer SRC_TRAINER_DB_USERNAME=aifadmin SRC_TRAINER_DB_PASSWORD=admin@12 DESTINATION_SERVER=localhost DESTINATION_DB_NAME=ai_model_management DESTINATION_PKGMANAGER_DB_SCHEMA=dbo DESTINATION_TRAINER_DB_SCHEMA=dbo DESTINATION_DB_USERNAME=aifabricuser DESTINATION_DB_PASSWORD=aifabric@123"

echo "sqlcmd -v SourceDBSchema =ai_pkgmanager DestinationDBSchema=dbo -S sf-migration-onlinesqlserver.database.windows.net -U aifadmin -P admin@12 -d aifabric_sfmigrationonline -i ml_package_versions-in.sql -o ml_package_versions-out.sql"


for ARGUMENT in "$@"
do

    KEY=$(echo $ARGUMENT | cut -f1 -d=)
    VALUE=$(echo $ARGUMENT | cut -f2 -d=)   

    case "$KEY" in
         	SRC_SERVER)                         SRC_SERVER=${VALUE} ;;
            SRC_PKGMANAGER_DB_NAME)             SRC_PKGMANAGER_DB_NAME=${VALUE} ;;
            SRC_PKGMANAGER_DB_SCHEMA)           SRC_PKGMANAGER_DB_SCHEMA=${VALUE} ;;     
			SRC_PKGMANAGER_DB_USERNAME)         SRC_PKGMANAGER_DB_USERNAME=${VALUE} ;;     
			SRC_PKGMANAGER_DB_PASSWORD)         SRC_PKGMANAGER_DB_PASSWORD=${VALUE} ;;     
			SRC_TRAINER_DB_NAME)                SRC_TRAINER_DB_NAME=${VALUE} ;;
            SRC_TRAINER_DB_SCHEMA)              SRC_TRAINER_DB_SCHEMA=${VALUE} ;;     
			SRC_TRAINER_DB_USERNAME)            SRC_TRAINER_DB_USERNAME=${VALUE} ;;     
			SRC_TRAINER_DB_PASSWORD)            SRC_TRAINER_DB_PASSWORD=${VALUE} ;;     
			DESTINATION_SERVER)                 DESTINATION_SERVER=${VALUE} ;;
			DESTINATION_DB_NAME)                DESTINATION_DB_NAME=${VALUE} ;;
			DESTINATION_PKGMANAGER_DB_SCHEMA)   DESTINATION_PKGMANAGER_DB_SCHEMA=${VALUE} ;;
			DESTINATION_TRAINER_DB_SCHEMA)      DESTINATION_TRAINER_DB_SCHEMA=${VALUE} ;;
			DESTINATION_DB_USERNAME)            DESTINATION_DB_USERNAME=${VALUE} ;;
			DESTINATION_DB_PASSWORD)            DESTINATION_DB_PASSWORD=${VALUE} ;;		
            *)   
    esac    

done

echo "SRC_PKGMANAGER_DB_NAME = $SRC_PKGMANAGER_DB_NAME"
echo "SRC_PKGMANAGER_DB_SCHEMA = $SRC_PKGMANAGER_DB_SCHEMA"
echo "SRC_PKGMANAGER_DB_USERNAME = $SRC_PKGMANAGER_DB_USERNAME"
echo "SRC_PKGMANAGER_DB_PASSWORD = $SRC_PKGMANAGER_DB_PASSWORD"
echo "DESTINATION_DB_NAME = $DESTINATION_DB_NAME"
echo "DESTINATION_DB_SCHEMA = $DESTINATION_DB_SCHEMA"
echo "DESTINATION_DB_USERNAME = $DESTINATION_DB_USERNAME"
echo "DESTINATION_DB_PASSWORD = $DESTINATION_DB_PASSWORD"


update_database_table(){

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
    
echo ""
echo "*************************************************************************"

echo $TableName " Migration started"

#BCP [$SRC_DB_NAME].[$SRC_DB_SCHEMA].[$TableName] out $TableName.dat -n -S $SRC_SERVER  -U $SRC_DB_USERNAME -P $SRC_DB_PASSWORD

sqlcmd -v SourceDBSchema =$SRC_DB_SCHEMA DestinationDBSchema=$DESTINATION_DB_SCHEMA -S $SRC_SERVER -U $SRC_DB_USERNAME -P $SRC_DB_PASSWORD -d $SRC_DB_NAME -i $TableName-in.sql -o $TableName-out.sql

sed -i '$ d' $TableName-out.sql
sed -i "s/'#NULL#'/NULL/g" $TableName-out.sql
echo $TableName " Export Done"
#BCP [$DESTINATION_DB_NAME].[$DESTINATION_DB_SCHEMA].[$TableName] in $TableName.dat -n -S $DESTINATION_SERVER -U $DESTINATION_DB_USERNAME -P $DESTINATION_DB_PASSWORD

sqlcmd -S $DESTINATION_SERVER -U $DESTINATION_DB_USERNAME -P $DESTINATION_DB_PASSWORD -d $DESTINATION_DB_NAME -i $TableName-out.sql

echo $TableName " Import Done"

echo "*************************************************************************"


# Running update tenant id in the destination database

sqlcmd -S $DESTINATION_SERVER -U $DESTINATION_DB_USERNAME -P $DESTINATION_DB_PASSWORD -d $DESTINATION_DB_NAME -Q "update "$DESTINATION_DB_NAME"."$DESTINATION_DB_SCHEMA"."$TableName" set account_id = 'host';"


}

# Table names to be migrated
#PkgManagerDBTableNames=( ml_package_versions)
PkgManagerDBTableNames=( projects ml_packages ml_package_versions)
TrainerDBTableNames=( datasets)


# Updating all the table for ai_pkgmanager db
for TableName in ${PkgManagerDBTableNames[*]} 
do
update_database_table  $TableName $SRC_SERVER $SRC_PKGMANAGER_DB_NAME $SRC_PKGMANAGER_DB_SCHEMA $SRC_PKGMANAGER_DB_USERNAME $SRC_PKGMANAGER_DB_PASSWORD $DESTINATION_SERVER $DESTINATION_DB_NAME $DESTINATION_PKGMANAGER_DB_SCHEMA $DESTINATION_DB_USERNAME $DESTINATION_DB_PASSWORD
done

# Updating all the table for ai_trainer db
for TableName in ${TrainerDBTableNames[*]} 
do
update_database_table  $TableName $SRC_SERVER $SRC_TRAINER_DB_NAME $SRC_TRAINER_DB_SCHEMA $SRC_TRAINER_DB_USERNAME $SRC_TRAINER_DB_PASSWORD $DESTINATION_SERVER ai_trainer $DESTINATION_TRAINER_DB_SCHEMA $DESTINATION_DB_USERNAME $DESTINATION_DB_PASSWORD
done
