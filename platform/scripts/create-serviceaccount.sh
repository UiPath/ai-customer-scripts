#!/bin/bash

echo "Creating provision service account"
chmod +r /etc/kubernetes/admin.conf
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl create -n default serviceaccount provision
kubectl create -n default clusterrolebinding provision-admin --clusterrole=cluster-admin --serviceaccount=default:provision