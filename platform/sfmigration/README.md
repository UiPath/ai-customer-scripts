# Command to execute
Go to the directory where you have downloaded sfmigration directory
Usage ./mastermigrationscriptnew.sh sample_input.json .

# Migration Scripts from Source replicated environment to Destination environment


## Purpose
To provide migration scripts for object storage and database to migrate from replicated environment to sf environment.
This migrates:
* Database
* Datasets
* ML packages


## Requirements
The Machine where migration script runs needs the following:
* Access to Replicated and SF machine (public ip address can be obtained via dig)
* aws s3, s3cmd, jq to be installed, e.g. on Ubuntu ```sudo apt install -y jq awscli s3cmd```
* MSSQL utility can be downloaded from https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-setup-tools?view=sql-server-ver15
 - curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
 - curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list
 - sudo apt-get update 
   sudo apt-get install mssql-tools unixodbc-dev
 - sudo apt-get update 
   sudo apt-get install mssql-tools  
* User logged in with permission to run the script and access to above tools


## Usage
* USE WINSCP or scp to copy sfmigration present in the platform/sfmigration location in ai-customer-script repo to the machine where script are to be executed. 
* Run get-credentials.sh on Replicated machine. It generates a file storage-creds.json. Replace the content in sfmigration/storagemigration/SOURCE_CREDENTIAL_FILE file.
* Run get-credentials-sf.sh on SF machine. It generates a file storage-creds.json. Replace the content in sfmigration/storagemigration/TARGET_CREDENTIAL_FILE file.
* chmod 777 -R sfmigration
* Whitelist Public IP of the machine where scripts are getting executed and add it in the DBs firewall(Both Source and destination DBs) in azure portal.
* Replace database credentials in sample-input.json file.
* Add DNS of object storage in the machine executing script (This can be found from the extension tab of the pipeline from where the SF env was created).
example - sudo bash -c "echo \"20.86.28.123    objectstore.sfdev1968699-2f356c0d-lb.westeurope.cloudapp.azure.com\" >> /etc/hosts"
* execute ./mastermigrationscriptnew.sh sample_input.json .
