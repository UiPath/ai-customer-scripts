#!/bin/bash

# execute function
execute() {
  bash $1
  if [ $? -ne 0 ];
  then
    echo "[ERROR]: Onebox installation failed. Exiting !!!"
    exit 1
  fi
}

#Check if lvm is installed
execute ../scripts/lvm-checks.sh
#OS Check
execute ../scripts/os-check.sh
#Check if RAW disks are available
execute ../scripts/storage-check.sh
#Install Kubernetes
execute ../scripts/install-curl.sh
