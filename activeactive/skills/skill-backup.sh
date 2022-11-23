#!/bin/bash

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)


echo "$green Enter skill id:"
read skillId
#echo "Skill Id is: $skillId"

echo "$green $(date) Taking backup of Skill with Id: $skillId"

uuidArray=(${skillId//-/ })
uuid=${uuidArray[0]}
#echo "uuid: $uuid"
mkdir $uuid-skill-backup

function backup_deployment() {

  getDeployment=`kubectl get deployment -n uipath | grep $skillId`
    if [ -z "$getDeployment" ]; then
        echo "$red $(date) Skill id is invalid, Please check ... Exiting $default"
        exit 1
     else
       deploymentArray=(${getDeployment// / })
       deployFile=${deploymentArray[0]}
       #echo "deploy file name: $deployFile"
       kubectl get deployment -n uipath $deployFile -o yaml > $uuid-skill-backup/$uuid-deployment.yaml
       echo "$green $(date) Backup of deployment is success for Skill with Id: $skillId"
     fi
}

function backup_service() {

  getService=`kubectl get svc -n uipath | grep $skillId`
  if [ -z "$getService" ]; then
     echo "$red $(date) No SVC found for Skill id : $skillId"
  else
    serviceArray=(${getService// / })
    serviceFile=${serviceArray[0]}
    #echo "service file name: $serviceFile"
    kubectl get svc -n uipath $serviceFile -o yaml > $uuid-skill-backup/$uuid-service.yaml
    echo "$green $(date) Backup of service is success for Skill with Id: $skillId"
  fi
}

function backup_virtual_service() {

  getVirtualService=`kubectl get virtualservices -n uipath | grep $skillId`
  if [ -z "$getVirtualService" ]; then
     echo "$red $(date) No Virtual Service found for Skill id : $skillId"
  else
    virtualServiceArray=(${getVirtualService// / })
    virtualServiceFile=${virtualServiceArray[0]}
    kubectl get virtualservices -n uipath $virtualServiceFile -o yaml > $uuid-skill-backup/$uuid-virtual-service.yaml
    echo "$green $(date) Backup of virtual service is success for Skill with Id: $skillId"
  fi
}

function backup_skill_secret() {

  getSkillSecret=`kubectl get secret -n uipath | grep $skillId`
  if [ -z "$getSkillSecret" ]; then
     echo "$red $(date) No Secret found for Skill id : $skillId"
  else
    secretArray=(${getSkillSecret// / })
    secretFile=${secretArray[0]}
    #echo "secretFile file name: $secretFile"
    kubectl get secret -n uipath $secretFile -o yaml > $uuid-skill-backup/$uuid-secret.yaml
    echo "$green $(date) Backup of Secret is success for Skill with Id: $skillId"
  fi
}

function backup_configmap() {

  getConfigmap=`kubectl get configmap -n uipath | grep $skillId`
  if [ -z "$getConfigmap" ]; then
     echo "$red $(date) No Configmap found for Skill id : $skillId"
  else
    configmapArray=(${getConfigmap// / })
    configmapFile=${configmapArray[0]}
    kubectl get configmap -n uipath $configmapFile -o yaml > $uuid-skill-backup/$uuid-configmap.yaml
    echo "$green $(date) Backup of Configmap is success for Skill with Id: $skillId"
  fi
}

function backup_hpa() {

  getHpa=`kubectl get hpa -n uipath | grep $skillId`
  if [ -z "$getHpa" ]; then
     echo "$yellow $(date) No HPA found for Skill id : $skillId"
  else
    hpaArray=(${getHpa// / })
    hpaFile=${hpaArray[0]}
    kubectl get hpa -n uipath $hpaFile -o yaml > $uuid-skill-backup/$uuid-hpa.yaml
    echo "$green $(date) Backup of HPA is success for Skill with Id: $skillId"
  fi
}

function backup_pdb() {

  getPdb=`kubectl get pdb -n uipath | grep $skillId`
  if [ -z "$getPdb" ]; then
     echo "$yellow $(date) No PDB found for Skill id : $skillId"
  else
    pdbArray=(${getPdb// / })
    pdbFile=${pdbArray[0]}
    kubectl get pdb -n uipath $pdbFile -o yaml > $uuid-skill-backup/$uuid-pdb.yaml
    echo "$green $(date) Backup of PDB is success for Skill with Id: $skillId"
  fi

}

backup_deployment

backup_service

backup_virtual_service

backup_skill_secret

backup_configmap

backup_hpa

backup_pdb

echo "$green $(date) Skill backup complete in dir: $uuid-skill-backup"


