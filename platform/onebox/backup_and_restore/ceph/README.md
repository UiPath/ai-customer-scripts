# Ceph Backup-Restore


## Purpose
To provide backup and restore scripts for object storage in ceph to handle DR scenarios.
This backs up:
* Packages (zips)
* Datasets
* Pipeline Artifacts/Logs
...


## Requirements
The Machine where backup/restore runs needs the following:
* Access to AIF machine 
* aws s3, s3cmd, jq to be installed
* User logged in with permission to run the script and access to above tools


## Usage
* Run get-credentials.sh on AIF machine. It generates a file storage-creds.json. Copy it over to the backup/restore VM.
* [Optionally] Move the credentials to some cluster manager and make changes to the scripts to read from there

### For Backup
```
./backup.sh <path to creds file> <basePath to download assets/blobs>
```
It creates a folder <basePath>/ceph which contains 1 folder per bucket containing all the blobs of that bucket

### For Restore
```
./restore.sh <path to creds file> <basePath to upload assets/blobs from>
```
This looks for a folder ceph inside basePath, creates a bucket per folder inside ceph and then uploads all blobs
