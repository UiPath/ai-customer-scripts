# Migration Scripts from Source replicated environment to Destination environment

## Purpose
To provide migration scripts for object storage and database to migrate from replicated environment to sf environment.
This migrates:
* Database
* Datasets
* ML packages

## Requirements
The Machine where migration script runs needs the following:
* Install aws s3, s3cmd, jq, zip to be installed, e.g. on Ubuntu ```sudo apt install -y jq awscli s3cmd zip git```
* Access to Replicated and SF machine (public ip address can be obtained via dig)
* MSSQL utility can be downloaded using the below commands (Reference : https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-setup-tools?view=sql-server-ver15#ubuntu)
 ```
 curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
 curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list
 sudo apt-get update 
 sudo apt-get install mssql-tools unixodbc-dev
 sudo apt-get update 
 sudo apt-get install mssql-tools
 echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile
 echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
 source ~/.bashrc
 ``` 
* User logged in should have permission to run the script and access to above tools
* Access to Replicated (Referred to as Source in the document) and SF machine (Referred to as Destination in the document).
* Access to Replicated and SF machine Database SQL servers.

## Steps to execute script

* Create a tenant with the same name in SF environment manually. Whichever tenant has to be migrated from replicated, corresponding tenant needs to be created in SF as well.
# In Machine executing the script
* Replace the source SRC_TENANT_ID,DESTINATION_TENANT_ID,DESTINATION_ACCOUNT_ID and other input parameters in the sample_input.json file. Please see description of each field below.
``` 
{
SRC_AIC_INSTALLATION_VERSION: "TO-BE-REPLACED", // Values can be : 20.10 OR 21.4
SRC_SERVER: "TO-BE-REPLACED",   // Replicated SQL Server host
SRC_PKGMANAGER_DB_NAME: "TO-BE-REPLACED", // Replicated SQL Server Pkgmanager DB name
SRC_PKGMANAGER_DB_SCHEMA: "ai_pkgmanager", // Replicated SQL Server Pkgmanager DB schema, Note : Please check schema in case of multiple dbs in replicated
SRC_PKGMANAGER_DB_USERNAME: "TO-BE-REPLACED", // Replicated SQL Server Pkgmanager DB Username
SRC_PKGMANAGER_DB_PASSWORD: "TO-BE-REPLACED",  // Replicated SQL Server Pkgmanager DB Password
SRC_TRAINER_DB_NAME: "TO-BE-REPLACED", // Replicated SQL Server AI-Trainer DB Name
SRC_TRAINER_DB_SCHEMA: "ai_trainer", // Replicated SQL Server AI-Trainer DB Schema, Note : Please check schema in case of multiple dbs in replicated
SRC_TRAINER_DB_USERNAME: "TO-BE-REPLACED", // Replicated SQL Server AI-Trainer DB Username
SRC_TRAINER_DB_PASSWORD: "TO-BE-REPLACED",// Replicated SQL Server AI-Trainer DB Password
DESTINATION_SERVER: "TO-BE-REPLACED", // Destination SQL Server host i.e ServiceFabric SQL Server host
DESTINATION_DB_NAME: "TO-BE-REPLACED", // Destination SQL Server DB Name
DESTINATION_PKGMANAGER_DB_SCHEMA: "ai_pkgmanager", 
DESTINATION_TRAINER_DB_SCHEMA: "ai_trainer",
DESTINATION_DB_USERNAME: "TO-BE-REPLACED", // Destination SQL Server Username
DESTINATION_DB_PASSWORD: "TO-BE-REPLACED", // Destination SQL Server Password
TENANT_MAP: [
{
SRC_TENANT_ID: "TO-BE-REPLACED", // Source Tenant Id i.e tenant UUID in replicated environment
DESTINATION_TENANT_ID: "TO-BE-REPLACED", // Destination Tenant Id i.e Tenant UUID in the destination environment
DESTINATION_ACCOUNT_ID: "TO-BE-REPLACED" // Destination Account UUID Id , host if Migrating to ServiceFabric standalone environment otherwise provide the actual Account UUID
}
]
}

```
* Run get-credentials.sh on Replicated machine. It generates a file storage-creds.json. Replace the content in sfmigration/storagemigration/SOURCE_CREDENTIAL_FILE file.
* Run get-credentials-sf.sh on SF machine. It generates a file storage-creds.json. Replace the content in sfmigration/storagemigration/TARGET_CREDENTIAL_FILE file.
* chmod 777 -R sfmigration
* Whitelist Public IP of the machine where scripts are getting executed and add it in the DBs firewall(Both Source and destination DBs).
* Replace details in input.json file.
* Add DNS of object storage in the machine executing script (This can be found from the extension tab of the pipeline from where the SF env was created).
example - sudo bash -c "echo \"20.86.28.123    objectstore.sfdev1968699-2f356c0d-lb.westeurope.cloudapp.azure.com\" >> /etc/hosts"
* execute ./mastermigrationscript.sh input.json

# Command to execute
Go to the directory where you have downloaded sfmigration directory
Usage ./mastermigrationscript.sh input.json
