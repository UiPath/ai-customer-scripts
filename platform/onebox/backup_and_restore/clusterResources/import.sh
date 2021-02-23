#!/bin/bash

: '
This script will import user oriented cluster resources from one enviornmnet to another envrionment
[Script Version -> 21.4]'

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)

echo "$green $(date) Starting export of user namespaces and pipeline related cron jobs $default"

readonly CLUSTER_RESOURCES_EXPORT_FILE=$1

# Validate dependecny module
# $1 - Name of the dependecny module
# $2 - Command to validate module
function validate_dependency() {
  list=$($2)
  if [ -z "$list" ]; then
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
  echo "$(date) Successfully validated required dependecies"
}

# Validate input provided by end user
function validate_input() {

  # Validate file path
  validate_file_path $CLUSTER_RESOURCES_EXPORT_FILE

  readonly NAMESPACES_BACKUP_NAME=$(cat $ML_PACKAGE_EXPORT_INPUT_FILE | jq -r 'select(.namespaceBackupName != null) | .namespaceBackupName')
  readonly CRONJOBS_BACKUP_NAME=$(cat $ML_PACKAGE_EXPORT_INPUT_FILE | jq -r 'select(.cronjobsBackupName != null) | .cronjobsBackupName')

  if [[ -z $NAMESPACES_BACKUP_NAME || -z $CRONJOBS_BACKUP_NAME ]]; then
    echo "$red $(date) Input is invalid or missing, Please check ... Exiting $default"
    exit 1
  fi

  echo "$green $(date) Successfully validated user input $default"
  }

# Restore all user orinated namespaces
function restore_namespace() {
  echo "$(date) Process of namespace restoration started"
  readonly restore_namespace_backup_name=$1

  # Restore namespaces
  velero restore create --from-backup $restore_namespace_backup_name

  echo "$(date) Successfully restore all user namespaces from backup $restore_namespace_backup_name"
}

# Restore cronjobs
function restore_cronjobs() {
  echo "$(date) Process of cronjobs restoration started"
  readonly restore_cronjobs_backup_name=$2

  # Restore namespaces
  velero restore create --from-backup $restore_cronjobs_backup_name
  echo "$(date) Successfully restore all cronjobs from backup $restore_cronjobs_backup_name"
}

# Patch secrets in namespaces
function update_secrets_in_namespaces() {

  # Get docker config secrets
  readonly registryCredentials=$(kubectl -n aifabric get configmap registry-config -o jsonpath="{.data.REGISTRY_CREDENTIALS_PULL}")
  local registryInternalIp=$(kubectl get svc registry -n kurl -o jsonpath={.spec.clusterIP})
  NAMESPACES=($(kubectl get ns -A | awk '/[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}/ {print $1}'))

  for ((ns = 0; ns < ${#NAMESPACES[@]}; ns = ns + 1)); do
    local defaultTokenSecrets=$(kubectl get secrets -n ${NAMESPACES[ns]} --no-headers -o custom-columns=":metadata.name" | grep default-token)

    echo "$(date) Deleting $defaultTokenSecrets in namespace ${NAMESPACES[ns]}"
    kubectl -n ${NAMESPACES[ns]} delete secrets $defaultTokenSecrets

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
update_secret_in_namespaces

}