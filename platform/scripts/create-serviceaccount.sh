#!/bin/bash

echo "Creating provision service account"
bash -l
chmod +r /etc/kubernetes/admin.conf
kubectl create -n default serviceaccount provision 
kubectl create -n default clusterrolebinding provision-admin --clusterrole=cluster-admin --serviceaccount=default:provision