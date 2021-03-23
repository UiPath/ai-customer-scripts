#!/bin/bash

: '
This script will import user triggered cluster resources from one environment to another environment
[Script Version -> 21.4]'

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)

echo "$green $(date) Starting export of user namespaces and pipeline related cron jobs $default"

readonly CLUSTER_RESOURCES_EXPORT_FILE=$1
readonly CORE_SERVICE_NAMESPACE=aifabric
readonly KOTS_REGISTRY_SECRET=kotsadm-replicated-registry

# Validate dependency module
# $1 - Name of the dependency module
# $2 - Command to validate module
function validate_dependency() {
  eval $2
  # Next statement is checking last command success
  if [ $? -ne 0 ]; then
    echo "$red $(date) Please install ******** $1 ***********  ... Exiting $default"
    exit 1
  fi
}

function validate_file_path() {
  if [ ! -f "$1" ]; then
    echo "$red $(date) $1 file does not exist, Please check ... Exiting $default"
    exit 1
  fi
}

# Validate required modules exits in target setup
function validate_setup() {
  validate_dependency velero "velero version"
  echo "$(date) Successfully validated required dependencies"
}

# Validate input provided by end user
function validate_input() {

  # Validate file path
  validate_file_path $CLUSTER_RESOURCES_EXPORT_FILE

  readonly NAMESPACES_BACKUP_NAME=$(cat $CLUSTER_RESOURCES_EXPORT_FILE | jq -r 'select(.namespaceBackupName != null) | .namespaceBackupName')
  readonly CRONJOBS_BACKUP_NAME=$(cat $CLUSTER_RESOURCES_EXPORT_FILE | jq -r 'select(.cronjobsBackupName != null) | .cronjobsBackupName')

  if [[ -z $NAMESPACES_BACKUP_NAME || -z $CRONJOBS_BACKUP_NAME ]]; then
    echo "$red $(date) Input is invalid or missing, Please check ... Exiting $default"
    exit 1
  fi

  echo "$green $(date) Successfully validated user input $default"
  }

# Restore all user related namespaces
function restore_namespace() {
  echo "$(date) Process of namespace restoration started"

  # Restore namespaces
  velero restore create --from-backup $NAMESPACES_BACKUP_NAME

  echo "$(date) Successfully restore all user namespaces from backup $NAMESPACES_BACKUP_NAME"
}

# Restore cronjobs
function restore_cronjobs() {
  echo "$(date) Process of cronjob restoration started"

  # Restore namespaces
  velero restore create --from-backup $CRONJOBS_BACKUP_NAME
  echo "$(date) Successfully restore all cronjob from backup $CRONJOBS_BACKUP_NAME"
}

# Patch secrets in namespaces
function update_secrets_in_namespaces() {

  echo "$(date) Updating secrets"

  # Sleep is required for namespaces to be created
  sleep 30

  # Get docker config secrets
  readonly registryCredentials=$(kubectl -n $CORE_SERVICE_NAMESPACE get configmap registry-config -o jsonpath="{.data.REGISTRY_CREDENTIALS_PULL}")
  local registryInternalIp=$(kubectl get svc registry -n kurl -o jsonpath={.spec.clusterIP})

  NAMESPACES=($(kubectl get ns -A | awk '/[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}/ {print $1}'))

  for ((ns = 0; ns < ${#NAMESPACES[@]}; ns = ns + 1)); do
    local defaultTokenSecrets=$(kubectl get secrets -n ${NAMESPACES[ns]} --no-headers -o custom-columns=":metadata.name" | grep default-token)

    echo "$(date) Deleting $defaultTokenSecrets in namespace ${NAMESPACES[ns]}"
    kubectl -n ${NAMESPACES[ns]} delete secrets $defaultTokenSecrets

    # Deleting storage credentials, will be updated from post resource
    if (echo ${NAMESPACES[ns]} | grep "training-");
    then
      local trainingStorageSecrets=$(kubectl get secrets -n ${NAMESPACES[ns]} --no-headers -o custom-columns=":metadata.name" | grep training-storage-credentials)
      echo "$(date) Deleting $trainingStorageSecrets in namespace ${NAMESPACES[ns]}"
      kubectl -n ${NAMESPACES[ns]} delete secrets $trainingStorageSecrets
    fi

    # Deleting storage credentials, will be updated from post resource
    if (echo ${NAMESPACES[ns]} | grep "data-manager-");
    then
       local dataManagerNewSecrets=$(kubectl -n $CORE_SERVICE_NAMESPACE get secrets $KOTS_REGISTRY_SECRET -o jsonpath='{.data.\.dockerconfigjson}')
       local appHelperDataManager=$(kubectl get secrets -n ${NAMESPACES[ns]} --no-headers -o custom-columns=":metadata.name" | grep app-data-manager)
       local appDataHelperManager=$(kubectl get secrets -n ${NAMESPACES[ns]} --no-headers -o custom-columns=":metadata.name" | grep app-helper-data-manager)
       kubectl patch secret $appHelperDataManager -n ${NAMESPACES[ns]} --type='json' -p="[{'op' : 'replace' ,'path' : '/data/.dockerconfigjson' ,'value' : '$dataManagerNewSecrets'}]"
       kubectl patch secret $appDataHelperManager -n ${NAMESPACES[ns]} --type='json' -p="[{'op' : 'replace' ,'path' : '/data/.dockerconfigjson' ,'value' : '$dataManagerNewSecrets'}]"
       kubectl delete --all deployments --namespace=${NAMESPACES[ns]}
       kubectl delete --all svc --namespace=${NAMESPACES[ns]}
    fi

    echo "$(date) Updating registry credentials in namespace ${NAMESPACES[ns]}"
    kubectl patch secret kurl-registry -n ${NAMESPACES[ns]} --type='json' -p="[{'op' : 'replace' ,'path' : '/data/.dockerconfigjson' ,'value' : '$registryCredentials'}]"

    if [ ${#NAMESPACES[ns]} == 36 ]; then
      declare -a DEPLOYMENTS=()
      echo "$(date) Fetching list of deployments in skill namespace ${NAMESPACES[ns]}"
      DEPLOYMENTS=($(kubectl get deployments --no-headers -o custom-columns=":metadata.name" -n ${NAMESPACES[ns]}))
      echo "$(date) Total deployments in namespace ${NAMESPACES[ns]} is ${#DEPLOYMENTS[@]}"
      for ((dp = 0; dp < ${#DEPLOYMENTS[@]}; dp = dp + 1)); do
        echo "$(date) Patching deployments ${DEPLOYMENTS[dp]} in namespace ${NAMESPACES[ns]}"
        imageName=$(kubectl get deployment ${DEPLOYMENTS[dp]} -n ${NAMESPACES[ns]} -o=jsonpath="{..image}")
        newImage=$(echo $imageName | sed -r 's/(\b[0-9]{1,3}\.){3}[0-9]{1,3}\b'/"$registryInternalIp"/)
        echo "$(date) Old image path: $imageName, new image path: $newImage"
        kubectl patch deployment ${DEPLOYMENTS[dp]} -n ${NAMESPACES[ns]} --type json -p="[{'op': 'replace', 'path': '/spec/template/spec/containers/0/image', 'value': '$newImage'}]"
      done
    fi
  done

  echo "$(date) Restore process is completed successfully"
}

# Validate setup
validate_setup

# Validate input
validate_input

# Restore namespaces
restore_namespace

# Restore cron jobs
restore_cronjobs

# Update secrets in namespaces
update_secrets_in_namespaces