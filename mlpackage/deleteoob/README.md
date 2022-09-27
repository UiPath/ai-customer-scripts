# Delete OOB Pacckage Version 


## Purpose
To remove an OOB package version
...


## Requirements
The Machine where delete script runs needs the following:
* Access to AIF machine (public ip address can be obtained via dig)
* aws s3, sqlcmd, jq to be installed, e.g. on Ubuntu ```sudo apt install -y jq awscli sqlcmd```
* User logged in with permission to run the script and access to above tools


## Usage
* Provide details for database and OOB package to delete in input.json file
* Run deleteoobpackageversion.sh file.
* This will delete OOB package from DB






