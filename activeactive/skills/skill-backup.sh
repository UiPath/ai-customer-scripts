#!/bin/bash

echo "Enter skill id:"
read skillId
#echo "Skill Id is: $skillId"

echo "Taking backup of deployment, service and virtual service for Skill Id: $skillId"

uuidArray=(${skillId//-/ })
uuid=${uuidArray[0]}
#echo "uuid: $uuid"
mkdir $uuid-skill-backup

getDeployment=`kubectl get deployment -n uipath | grep $skillId`
#echo "deploy output: $getDeployment"
deploymentArray=(${getDeployment// / })
deployFile=${deploymentArray[0]}
#echo "deploy file name: $deployFile"
kubectl get deployment -n uipath $deployFile -o yaml > $uuid-skill-backup/$uuid-deployment.yaml

getService=`kubectl get svc -n uipath | grep $skillId`
#echo "service output: $getService"
serviceArray=(${getService// / })
serviceFile=${serviceArray[0]}
#echo "service file name: $serviceFile"
kubectl get svc -n uipath $serviceFile -o yaml > $uuid-skill-backup/$uuid-service.yaml

getVirtualService=`kubectl get virtualservices -n uipath | grep $skillId`
#echo "virtual service output: $getVirtualService"
virtualServiceArray=(${getVirtualService// / })
virtualServiceFile=${virtualServiceArray[0]}
#echo "virtual service file name: $virtualServiceFile"
kubectl get virtualservices -n uipath $virtualServiceFile -o yaml > $uuid-skill-backup/$uuid-virtual-service.yaml
#echo "virtual service output: $getVirtualService"

echo "Skill backup complete in dir: $uuid-skill-backup"
