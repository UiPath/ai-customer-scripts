#!/bin/bash

: '
This script will export user oriented cluster resources from one enviornmnet to another envrionment
[Script Version -> 21.4]'

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)

echo "$green $(date) Starting export of user namespaces and pipeline cron jobs $default"

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

# Validate required modules exits in target setup
function validate_setup() {
  validate_dependency velero "velero version"
  echo "$(date) Successfully validated required dependecies"
}

# Backup all UUID namespace using velero
function backup_namespace() {
  echo "$(date) Process of user namespaces backup started"
  declare -a NAMESPACES=()

  echo "$(date) Fetching list of all UUID namespaces"
  NAMESPACES=($(kubectl get ns -A | awk '/[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}/ {print $1}'))

  local namespaces_list=$(IFS=,echo "${NAMESPACES[*]}")

  backup_name="ai-center-onpremise-backup"-$(date +%s)
  velero backup create $backup_name --include-namespaces $namespaces_list

  echo "$(date) Successfully backup all user namespaces with name $backup_name"
}

# Backup all cron jobs using velero
function backup_cronjobs() {
  echo "$(date) Process of cronjobs backup started"

  local backup_name="ai-center-cronjobs-onpremise-backup"-$(date +%s)
  local backup_cronjobs_ns="aifabric"

  #backup pipeline crons jobs
  velero backup create $backup_name --include-resources cronjobs --include-namespaces $backup_cronjobs_ns

  echo "$(date) Successfully backup all cronjobs in namespace $backup_cronjobs_ns with name $backup_name"
}

# Validate setup
validate_setup

# Restore namespaces
restore_namespace

# Restore cron jobs
restore_cronjobs

# Update secrets in namespaces
update_secret_in_namespaces
