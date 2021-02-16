#!/bin/bash

: '
This scipt will generate json file for creds to be used with import export
Script will generate file storage-creds.json
Run it from the VM running aifabric.
Use it as it is [insecure] or transfer to some credsManager and then change backup/restore scripts to fetch from credsmanager instead of json file
# $1 - [Optional but recommended] pass private ip of the aif machine on which it is accesible from other vms in the same network
[Script Version -> 21.4]
'

readonly PRIVATE_IP=$1

function initialize_variables() {
	if [ -z "$PRIVATE_IP" ]; then
		# Gets private ip of machine so that it can be connected within the VM
		# Seems to be set as localhost on some customer machines
		#OBJECT_GATEWAY_EXTERNAL_HOST=$(hostname -i)
		PRIVATE_ADDRESS=$(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')
    	#This is needed on k8s 1.18.x as $PRIVATE_ADDRESS is found to have a newline
    	OBJECT_GATEWAY_EXTERNAL_HOST=$(echo "$PRIVATE_ADDRESS" | tr -d '\n')
    else
    	OBJECT_GATEWAY_EXTERNAL_HOST=$PRIVATE_IP
    fi
    echo "$green $(date) Private IP was $PRIVATE_IP and OBJECT_GATEWAY_EXTERNAL_HOST is $OBJECT_GATEWAY_EXTERNAL_HOST"
    
	OBJECT_GATEWAY_EXTERNAL_PORT=31443
	
	STORAGE_ACCESS_KEY=$(kubectl -n aifabric get secret storage-secrets -o json | jq '.data.OBJECT_STORAGE_ACCESSKEY' | sed -e 's/^"//' -e 's/"$//' | base64 -d)
	STORAGE_SECRET_KEY=$(kubectl -n aifabric get secret storage-secrets -o json | jq '.data.OBJECT_STORAGE_SECRETKEY' | sed -e 's/^"//' -e 's/"$//' | base64 -d)
	
	readonly AWS_HOST=$OBJECT_GATEWAY_EXTERNAL_HOST
	readonly AWS_ENDPOINT="https://${OBJECT_GATEWAY_EXTERNAL_HOST}:${OBJECT_GATEWAY_EXTERNAL_PORT}"
	readonly AWS_ACCESS_KEY_ID=$STORAGE_ACCESS_KEY
	readonly AWS_SECRET_ACCESS_KEY=$STORAGE_SECRET_KEY
}

function generate_json() {
	echo '{"AWS_HOST": "'$AWS_HOST'", "AWS_ENDPOINT": "'$AWS_ENDPOINT'", "AWS_ACCESS_KEY_ID": "'$AWS_ACCESS_KEY_ID'", "AWS_SECRET_ACCESS_KEY": "'$AWS_SECRET_ACCESS_KEY'"}' > storage-creds.json
}

initialize_variables
generate_json