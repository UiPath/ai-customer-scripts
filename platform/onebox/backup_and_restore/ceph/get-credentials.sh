#!/bin/bash

: '
This scipt will generate json file for creds to be used with import export
Script will generate file storage-creds.json
Run it from the VM running aifabric.
Use it as it is [insecure] or transfer to some credsManager and then change backup/restore scripts to fetch from credsmanager instead of json file
[Script Version -> 21.4]
'
function initialize_variables() {
	OBJECT_GATEWAY_INTERNAL_HOST=$(kubectl -n istio-system get svc istio-ingressgateway -o jsonpath="{.spec.clusterIP}")
	OBJECT_GATEWAY_INTERNAL_PORT=31443
	
	STORAGE_ACCESS_KEY=$(kubectl -n aifabric get secret storage-secrets -o json | jq '.data.OBJECT_STORAGE_ACCESSKEY' | sed -e 's/^"//' -e 's/"$//' | base64 -d)
	STORAGE_SECRET_KEY=$(kubectl -n aifabric get secret storage-secrets -o json | jq '.data.OBJECT_STORAGE_SECRETKEY' | sed -e 's/^"//' -e 's/"$//' | base64 -d)
	
	readonly AWS_HOST=$OBJECT_GATEWAY_INTERNAL_HOST
	readonly AWS_ENDPOINT="https://${OBJECT_GATEWAY_INTERNAL_HOST}:${OBJECT_GATEWAY_INTERNAL_PORT}"
	readonly AWS_ACCESS_KEY_ID=$STORAGE_ACCESS_KEY
	readonly AWS_SECRET_ACCESS_KEY=$STORAGE_SECRET_KEY
}

function generate_json() {
	echo '{"AWS_HOST": "'$AWS_HOST'", "AWS_ENDPOINT": "'$AWS_ENDPOINT'", "AWS_ACCESS_KEY_ID": "'$AWS_ACCESS_KEY_ID'", "AWS_SECRET_ACCESS_KEY": "'$AWS_SECRET_ACCESS_KEY'"}' > storage-creds.json
}

initialize_variables
generate_json