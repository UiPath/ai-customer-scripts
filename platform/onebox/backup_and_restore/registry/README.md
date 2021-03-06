# Registry Backup-Restore


## Purpose
To provide backup and restore scripts for registry to handle DR scenarios.
This backs up only the images currently used by any skills
...


## Requirements
The Machine where backup/restore runs needs the following:
* Access to AIF machine (public ip address can be obtained via dig)
* jq, sqlcmd to be installed, e.g. on Ubuntu ```sudo apt install -y jq```
* User logged in with permission to run the script and access to above tools
* AIF machines need registry accessible via nodeport. It can be done via ```kubectl -n kurl apply -f registry-np.yaml```


## Usage
* Run get-credentials.sh on AIF machines. It generates a file registry-creds.json. Copy it over to the backup/restore VM.
* [Optionally] Move the credentials to some cluster manager and make changes to the scripts to read from there
# Registry Backup-Restore
* Make sure to use absolute path as basepath in below scripts

### For Backup
```
./backup.sh <path to creds file> <basePath to download assets/blobs>
```
It creates a folder <basePath>/registry which contains 1 tar file for every image

### For Restore
```
./restore.sh <path to creds file> <basePath to upload assets/blobs from>
```
This looks for a folder registry inside basePath, loads image from tar and pushes to local registry
