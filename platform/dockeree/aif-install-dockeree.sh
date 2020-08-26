#!/bin/bash
#
#

# execute function
execute() {
  bash $1
  if [ $? -ne 0 ];
  then
    echo "[ERROR]: Bootstrap installation failed. Exiting !!!"
    exit 1
  fi
}

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

export UCP_HOST=$ucphost;
export UCP_USERNAME=$ucpuser;
export UCP_PASSWORD=$ucppassword;

}

docker create -ti --name aifabric_installer uipath/docker-installation:latest bash

docker cp aifabric_installer:/ /tmp/aifabric_installation

docker rm -f aifabric_installer

#Remove the image
docker rmi -f uipath/docker-installation:latest

cd /tmp/aifabric_installation

# Total steps
total_steps=9
current_step=1

echo "<----------- Total steps: ${total_steps} Current step: ${current_step}  Estimated time: 2s ----------->"

#os_validation
execute os-check.sh
current_step=$(( current_step + 1 ))

echo "<----------- Total steps: ${total_steps} Current step: ${current_step}  Estimated time: 2s ----------->"

#lvm validation
execute lvm-check.sh
current_step=$(( current_step + 1 ))

#storage validation
#bash storage-check.sh

echo "<----------- Total steps: ${total_steps} Current step: ${current_step}  Estimated time: 2s ----------->"

#kubectl installed or not
execute kubectl-install.sh
current_step=$(( current_step + 1 ))

echo "<----------- Total steps: ${total_steps} Current step: ${current_step}  Estimated time: 2s ----------->"

get_ucp_input;
current_step=$(( current_step + 1 ))

echo "<----------- Total steps: ${total_steps} Current step: ${current_step}  Estimated time: 5s ----------->"

# download ucp_bundle
execute docker-ucp-client-bundle-download.sh
current_step=$(( current_step + 1 ))

echo "<----------- Total steps: ${total_steps} Current step: ${current_step}  Estimated time: 2s ----------->"

load_env;
current_step=$(( current_step + 1 ))

echo "<----------- Total steps: ${total_steps} Current step: ${current_step}  Estimated time: 2s ----------->"

#kubernetes node validation
execute kubernetes-node-check-dockeree.sh
current_step=$(( current_step + 1 ))

cd rook

echo "<----------- Total steps: ${total_steps} Current step: ${current_step}  Estimated time: 5m ----------->"

# install ceph
execute rook_ceph_installer.sh
current_step=$(( current_step + 1 ))

cd ..

echo "<----------- Total steps: ${total_steps} Current step: ${current_step}  Estimated time: 5m ----------->"

#install kotsadmin
execute kotsadmin-ui-embedded-install.sh