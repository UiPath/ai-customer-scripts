#!/bin/bash
#
#

# Function to load env.sh
load_env() {
  
  if [ -d ucp_bundle ];
  then
    cd ucp_bundle
    source env.sh
    cd ..
  else
    echo "[ERROR]: UCP bundle does not exist. Exiting"
	exit 1
  fi
  
  echo "[INFO]: Loaded env successfully"
}

get_ucp_input() {

#Ask for UCP URL
read -p 'UCP Host (IP or FQDN) : ' ucphost

#Ask for UCP username
read -p 'UCP username : ' ucpuser

#Ask for UCP password
read -sp 'UCP password : ' ucppassword

export UCP_HOST=$(echo -e "${ucphost}" | tr -d '[:space:]' | tr -d 'https://' | tr -d 'http://');
export UCP_USERNAME=$ucpuser;
export UCP_PASSWORD=$ucppassword;

}

docker create -ti --name aifabric_installer uipath/docker-installation:latest bash

docker cp aifabric_installer:/ /tmp/aifabric_installation

docker rm -f aifabric_installer

#Remove the image
docker rmi -f uipath/docker-installation:latest

cd /tmp/aifabric_installation

#os_validation
bash os-check.sh

#lvm validation
bash lvm-check.sh

#storage validation
#bash storage-check.sh

#kubectl installed or not
bash kubectl-install.sh

get_ucp_input;

# download ucp_bundle
bash docker-ucp-client-bundle-download.sh

load_env;

cd rook

# install ceph
bash rook_ceph_installer.sh

cd ..

#install kotsadmin
bash kotsadmin-ui-embedded-install.sh