#!/bin/bash

: '
This script will export user oriented cluster resources from one enviornmnet to another envrionment
[Script Version -> 21.4]'

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)

echo "$green $(date) Starting export of user namespaces and pipeline cron jobs $default"

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

# Validate required modules exits in target setup
function validate_setup() {
  validate_dependency velero "velero version"
  echo "$(date) Successfully validated required dependencies"
}

# Backup all UUID namespace using velero
function backup_namespace() {
  echo "$(date) Process of user namespaces backup started"
  declare -a NAMESPACES=()

  echo "$(date) Fetching list of all UUID namespaces"
  readonly NAMESPACES=$(kubectl get ns -A | awk '/[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}/ {print $1}')
  local namespaces_list=$(echo "$NAMESPACES" | paste -s -d, /dev/stdin)

  backup_name="ai-center-onpremise-backup"-$(date +%s)
  velero backup create $backup_name --include-namespaces $namespaces_list

  echo "$(date) Successfully backup all user namespaces with name $backup_name"
}

# Backup all cron jobs using velero
function backup_cronjobs() {
  echo "$(date) Process of cronjobs backup started"

  readonly local backup_name="ai-center-cronjobs-onpremise-backup"-$(date +%s)
  readonly local backup_cronjobs_ns="aifabric"

  #backup pipeline cron jobs
  velero backup create $backup_name --include-resources cronjobs --include-namespaces $backup_cronjobs_ns

  echo "$(date) Successfully backup all cron jobs in namespace $backup_cronjobs_ns with name $backup_name"
}

# Validate setup
validate_setup

# Backup namespaces
backup_namespace

# Backup cron jobs
backup_cronjobs