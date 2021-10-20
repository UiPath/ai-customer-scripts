# Migration Scripts from Source replicated environment to Destination environment

## Purpose
To provide migration scripts for object storage and database to migrate from replicated environment to sf environment.
This migrates:
* Database
* Datasets
* ML packages

# Command to execute
Go to the directory where you have downloaded sfmigration directory
Usage ./mastermigrationscript.sh input.json .

## Requirements
The Machine where migration script runs needs the following:
* Install aws s3, s3cmd, jq, zip to be installed, e.g. on Ubuntu ```sudo apt install -y jq awscli s3cmd zip git```
* Access to Replicated and SF machine (public ip address can be obtained via dig)
* MSSQL utility can be downloaded using the below commands (Reference : Install SQL Server command-line tools on Linux - SQL Server)
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
* Replace the source SRC_TENANT_ID,DESTINATION_TENANT_ID,DESTINATION_ACCOUNT_ID in the sample_input.json file.
* Run get-credentials.sh on Replicated machine. It generates a file storage-creds.json. Replace the content in sfmigration/storagemigration/SOURCE_CREDENTIAL_FILE file.
* Run get-credentials-sf.sh on SF machine. It generates a file storage-creds.json. Replace the content in sfmigration/storagemigration/TARGET_CREDENTIAL_FILE file.
* chmod 777 -R sfmigration
* Whitelist Public IP of the machine where scripts are getting executed and add it in the DBs firewall(Both Source and destination DBs) in azure portal.
* Replace details in input.json file.
* Add DNS of object storage in the machine executing script (This can be found from the extension tab of the pipeline from where the SF env was created).
example - sudo bash -c "echo \"20.86.28.123    objectstore.sfdev1968699-2f356c0d-lb.westeurope.cloudapp.azure.com\" >> /etc/hosts"
* execute ./mastermigrationscriptnew.sh input.json
