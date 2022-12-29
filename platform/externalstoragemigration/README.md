# Script for updating content uri after upgrading to external storage environments

## Purpose
To update the content uri in AI Center pkgmanager database after upgrading to external storage environments (azure/s3)
## Requirements
The Machine where script runs needs the following:
* Install sqlcmd, jq (Reference link : https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-setup-tools?view=sql-server-ver16)

## Command to execute
* chmod 777 content_uri_update_script.sh
* For Azure -> sh content_uri_update_script.sh "azure" "test-sql.database.windows.net" "testadmin" 'password' "testdb"

* For s3 -> sh content_uri_update_script.sh "s3" "test-sql.database.windows.net" "testadmin" 'password' "testdb"
