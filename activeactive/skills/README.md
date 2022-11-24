# Script for manual backup and restore of skills in OnPrem

## Purpose
With skills being present in more than one cluster in Active-Active setup, there is a need to manually backup and 
restore skills when needed.

## Requirements
The Machine where script runs needs the following:
* Minimum AIC version 22.10
* jq, curl to be installed.
* User logged in with permission to run the script and access to above tools

### NOTE
* Please note port forwarding will be done by the script to create tenant secret on secondary cluster

## Steps to restore skills on secondary

* Find the skill id to restore. <skill-id>
* Run script skill-backup.sh in the primary and give skill-id as input.
  * Example:
            [root@server0 testadmin]# sh skill-backup.sh
            Enter skill id:
             083a05ac-1c1e-4db5-850b-ca1d9d4e56cd
* This will generate a dir with all the artifacts of that skill.
* Copy the dir in secondary.
* Run script skill-restore.sh and give path of the copied folder as input.
  * Example: 
             [root@server0 testadmin]# sh skill-restore.sh
             Enter backup dir path:
              083a05ac-skill-backup

