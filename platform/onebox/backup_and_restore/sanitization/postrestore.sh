#!/bin/bash

: '
This script will update inflight operation to terminal state
[Script Version -> 21.4]'

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)

echo "$green $(date) Process of Updating in flight status to terminal state started $default"
readonly POST_RESTORE_CONFIG_FILE=$1

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

# Validate API response
# $1 - Api response code
# $2 - Expected response code
# $3 - Success Message
# $4 - Error message
function validate_response_from_api() {
  if [ $1 = $2 ]; then
    echo "$(date) $3"
  elif [ "$1" = "DEFAULT" ]; then
    echo "$red $(date) Please validate access token or internet. If fine check returned curl status code ... Exiting $default"
    exit 1
  else
    echo "$(date) $4 $default"
    exit 1
  fi
}

# Sanitize in flight ML packages
function sanitize_inflight_ml_packages() {
  readonly local ml_packages_sanitize_resp_code=$(curl -k --silent --fail --show-error -X POST 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-pkgmanager/v1/system/mlpackage/recover' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')

  local resp_code=DEFAULT
  if [ ! -z "$ml_packages_sanitize_resp_code" ]; then
    resp_code=$(echo "$ml_packages_sanitize_resp_code" | jq -r 'select(.respCode != null) | .respCode')
  fi

  validate_response_from_api $resp_code "200" "Successfully sanitized inflight ML Packages" "$red Failed to sanitized inflight ML Packages ... Exiting"
}

# Sanitize in flight projects
function sanitize_inflight_projects() {
  readonly local projects_sanitize_resp_code=$(curl -k --silent --fail --show-error -X POST 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-pkgmanager/v1/system/project/recover' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')

  local resp_code=DEFAULT
  if [ ! -z "$projects_sanitize_resp_code" ]; then
    resp_code=$(echo "$projects_sanitize_resp_code" | jq -r 'select(.respCode != null) | .respCode')
  fi

  validate_response_from_api $resp_code "202" "Successfully sanitized inflight projects" "$red Failed to sanitized inflight projects ... Exiting"
}

# Sanitize in flight ML Skills
function sanitize_inflight_ml_skills() {
  readonly local skills_sanitize_resp_code=$(curl -k --silent --fail --show-error -X POST 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-deployer/v1/system/mlskills/recover' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')

  local resp_code=DEFAULT
  if [ ! -z "$skills_sanitize_resp_code" ]; then
    resp_code=$(echo "$skills_sanitize_resp_code" | jq -r 'select(.respCode != null) | .respCode')
  fi

  validate_response_from_api $resp_code "200" "Successfully sanitized inflight ML Skills" "$red Failed to sanitized inflight ML Skills ... Exiting"
}

# Sanitize in flight namespaces
function sanitize_inflight_namespaces() {
 readonly local sanitize_inflight_ns_resp_code=$(curl -k --silent --fail --show-error -X POST 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-trainer/v1/system/namespace/recover' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')

  local resp_code=DEFAULT
  if [ ! -z "$sanitize_inflight_ns_resp_code" ]; then
    resp_code=$(echo "$sanitize_inflight_ns_resp_code" | jq -r 'select(.respCode != null) | .respCode')
  fi

  validate_response_from_api $resp_code "200" "Successfully sanitized inflight namespaces" "$red Failed to sanitized inflight namespaces ... Exiting"
}

# Sanitize in flight ML Pipelines
function sanitize_inflight_pipelines() {
  readonly local pipeline_sanitize_resp_code=$(curl -k --silent --fail --show-error -X POST 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-trainer/v1/system/pipeline/recover' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')

  local resp_code=DEFAULT
  if [ ! -z "$pipeline_sanitize_resp_code" ]; then
    resp_code=$(echo "$pipeline_sanitize_resp_code" | jq -r 'select(.respCode != null) | .respCode')
  fi

  validate_response_from_api $resp_code "200" "Successfully sanitized inflight pipeline" "$red Failed to sanitized inflight pipeline ... Exiting"
}

# Sanitize in flight Tenants
function sanitize_inflight_tenants() {
  readonly local tenants_sanitize_resp_code=$(curl -k --silent --fail --show-error -X POST 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-deployer/v1/system/tenant/recover' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')

  local resp_code=DEFAULT
  if [ ! -z "$tenants_sanitize_resp_code" ]; then
    resp_code=$(echo "$tenants_sanitize_resp_code" | jq -r 'select(.respCode != null) | .respCode')
  fi

  validate_response_from_api $resp_code "200" "Successfully sanitized inflight tenants" "$red Failed to sanitized inflight tenants ... Exiting"
}

# Sanitize in flight data manager apps
function sanitize_inflight_data_manager_apps() {
  readonly local app_manager_sanitize_resp_code=$(curl -k --silent --fail --show-error -X POST 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-appmanager/v1/system/app/recover' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')

  local resp_code=DEFAULT
  if [ ! -z "$tenants_sanitize_resp_code" ]; then
    resp_code=$(echo "$tenants_sanitize_resp_code" | jq -r 'select(.respCode != null) | .respCode')
  fi

  validate_response_from_api $resp_code "202" "Successfully sanitized inflight tenants" "$red Failed to sanitized inflight tenants ... Exiting"
}

function sanitize_core_services_inflight_opeartions() {
  echo "$(date) Sanitizing core services in flight opeation"
  sanitize_inflight_ml_packages
  sanitize_inflight_projects
  sanitize_inflight_namespaces
  sanitize_inflight_ml_skills
  sanitize_inflight_tenants
  sanitize_inflight_pipelines
  #sanitize_inflight_data_manager_apps
  echo "$(date) Successfully sanitized inflight core services opeations"
}

# Validate required modules exits in target setup
function validate_setup() {
  validate_dependency curl "curl --version"
  validate_dependency jq "jq --version"
  echo "$(date) Successfully validated required dependecies"
}

# Validate input provided by end user
function validate_input() {

  # Validate file path
  #validate_file_path $POST_RESTORE_CONFIG_FILE

  echo "$green $(date) Successfully validated user input $default"
}

# Validate setup
validate_setup

# Validate input
validate_input

# Sanitize core services in flight opeartions
sanitize_core_services_inflight_opeartions