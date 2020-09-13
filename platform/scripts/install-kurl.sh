#!/bin/bash

curl -sSL https://k8s.kurl.sh/aif-core-oneboxinstaller | sudo bash
bash -l
sudo chmod +r /etc/kubernetes/admin.conf
kubectl create -n default serviceaccount provision 
kubectl create -n default clusterrolebinding provision-admin --clusterrole=cluster-admin --serviceaccount=default:provision