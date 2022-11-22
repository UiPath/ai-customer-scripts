# Script for manual backup and restore of skills in OnPrem

With skills being present in more than one cluster in Active-Active setup, there is a need to manually backup and 
restore skills when needed.

## Steps to restore skills on secondary

* Find the skill id to restore. <skill-id>
* Run script skill-backup.sh in the primary and give skill-id as input.
  * 
* This will generate a dir with all the artifacts of that skill.
* Copy the dir in secondary.
* Run script skill-restore.sh and give path of the copied folder as input.
  * 

