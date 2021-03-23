#!/bin/bash

: '
This script will update in-flight operation to terminal state
[ Structure of Json file with exact key name ]
  - hostOrFQDN:  Public end point from where backend service can be accessible
  - identityServerEndPoint: End point where identity server is hosted
  - hostTenantName: Host Tenant name registered in identity server
  - hostTenantIdOrEmailId: Host tenant id or email Id
  - hostTenantPassword: Host tenant password
[Script Version -> 21.4]'

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)

echo "$green $(date) Process of Updating in flight status to terminal state started $default"
readonly POST_RESTORE_CONFIG_FILE=$1
readonly CORE_SERVICE_NAMESPACE=aifabric
readonly ACCESS_TOKEN_LIFE_TIME=345600

# Fetch admin token from identity server end point using host tenant
function fetch_identity_server_token_to_register_client() {
  echo "$(date) Fetching identity server client registration token"

  # Generate required endpoints
  readonly local antif=https://$IDENTITY_SERVER_ENDPOINT"/identity/api/antiforgery/generate"
  readonly local login=https://$IDENTITY_SERVER_ENDPOINT"/identity/api/Account/Login"
  readonly local tokenUrl=https://$IDENTITY_SERVER_ENDPOINT"/identity/api/Account/ClientAccessToken"

  dataLogin='{
    "tenant": "'$HOST_TENANT_NAME'",
    "usernameOrEmail": "'$HOST_TENANT_USER_ID_OR_EMAIL'",
    "password": "'$HOST_TENANT_PASSWORD'",
    "rememberLogin": true
  }'

  cookie_file="cookfile.txt"
  cookie_file_new="cookfile_new.txt"

  # Get token and construct the cookie, save the returned token.
  curl --silent --fail --show-error -k -c $cookie_file --request GET "$antif"

  # Replace headers
  sed 's/XSRF-TOKEN-IS/XSRF-TOKEN/g' $cookie_file >$cookie_file_new

  token=$(cat $cookie_file_new | grep XSRF-TOKEN | cut -f7 -d$'\t')

  # Authentication -> POST to $login_url with the token in header "X-CSRF-Token: $token".
  curl --silent --fail --show-error -k -H "X-XSRF-TOKEN: $token" -c $cookie_file_new -b $cookie_file_new -d "$dataLogin" --request POST "$login" -H "Content-Type: application/json"

  # Fetch Acces token
  CLIENT_INSTALLTION_TOKEN=$(curl --silent --fail --show-error -k -H "X-XSRF-TOKEN: $token" -b $cookie_file_new "$tokenUrl" -H "Content-Type: application/json")

  if [ -z "$CLIENT_INSTALLTION_TOKEN" ]; then
    echo "$(date) $red Failed to generate token to register client ... Exiting $default"
    exit 1
  fi

  echo "$(date) Successfully fetched client register token"
}

# Fetch access token to call backend server
function fetch_identity_server_access_token() {
  echo "$(date) Getting access token for client $IS_AIFABRIC_CLIENT_NAME from $IDENTITY_SERVER_ENDPOINT"

  readonly local access_token_response=$(
    curl -k --silent --fail --show-error --raw -X --location --request POST "https://${IDENTITY_SERVER_ENDPOINT}/identity/connect/token" \
      -H 'Content-Type: application/x-www-form-urlencoded' \
      --data-urlencode "client_Id=$IS_AIFABRIC_CLIENT_ID" \
      --data-urlencode "client_secret=$IS_AIFABRIC_CLIENT_SECRET" \
      --data-urlencode "grant_type=client_credentials"
  )

  if [ -z "$access_token_response" ]; then
    echo "$(date) $red Failed to generate access token to call backend server ... Exiting $default"
    deregister_client
    exit 1
  fi

  ACCESS_TOKEN=$(echo "$access_token_response" | jq -r 'select(.access_token != null) | .access_token')

  if [ -z "$ACCESS_TOKEN" ]; then
    echo "$(date) $red Failed to extract access token ... Exiting $default"
    deregister_client
    exit 1
  fi

  echo "$(date) Successfully fetched access token to call backend server "
}

function deregister_client() {
  echo "$(date) De-registering client from $IDENTITY_SERVER_ENDPOINT with name $IS_AIFABRIC_CLIENT_NAME"
  curl -k -i --silent --fail --show-error -X DELETE "https://${IDENTITY_SERVER_ENDPOINT}/identity/api/Client/$IS_AIFABRIC_CLIENT_ID" -H "Authorization: Bearer ${CLIENT_INSTALLTION_TOKEN}"
}

# Register client and fetch Access token
function register_client_and_fetch_access_token() {

  readonly IS_AIFABRIC_CLIENT_ID="aifabric-"$(openssl rand -hex 10)
  readonly IS_AIFABRIC_CLIENT_SECRET=$(openssl rand -hex 32)
  readonly IS_AIFABRIC_CLIENT_NAME="aifabric-"$(openssl rand -hex 10)

  # Fetch admin token
  fetch_identity_server_token_to_register_client

  # Register client
  echo "$(date) Registering client by name $IS_AIFABRIC_CLIENT_NAME with client id $IS_AIFABRIC_CLIENT_ID"

  local client_creation_response=$(curl -k --silent --fail --show-error --raw -X POST "https://${IDENTITY_SERVER_ENDPOINT}/identity/api/Client" -H "Connection: keep-alive" -H "accept: text/plain" -H "Authorization: Bearer ${CLIENT_INSTALLTION_TOKEN}" -H "Content-Type: application/json-patch+json" -H "Accept-Encoding: gzip, deflate, br" -H "Accept-Language: en-US,en;q=0.9" -d "{\"clientId\":\"${IS_AIFABRIC_CLIENT_ID}\",\"clientName\":\"${IS_AIFABRIC_CLIENT_NAME}\",\"clientSecrets\":[\"${IS_AIFABRIC_CLIENT_SECRET}\"],\"requireConsent\":false,\"requireClientSecret\": true,\"allowOfflineAccess\":true,\"alwaysSendClientClaims\":true,\"allowAccessTokensViaBrowser\":true,\"allowOfflineAccess\":true,\"alwaysIncludeUserClaimsInIdToken\":true,\"accessTokenLifetime\":${ACCESS_TOKEN_LIFE_TIME},\"identityTokenLifetime\":${ACCESS_TOKEN_LIFE_TIME},\"authorizationCodeLifetime\":${ACCESS_TOKEN_LIFE_TIME},\"absoluteRefreshTokenLifetime\":${ACCESS_TOKEN_LIFE_TIME},\"slidingRefreshTokenLifetime\":${ACCESS_TOKEN_LIFE_TIME},\"RequireRequestObject\":true,\"Claims\":true,\"AlwaysIncludeUserClaimsInIdToken\":true,\"allowedGrantTypes\":[\"client_credentials\",\"authorization_code\"],\"allowedResponseTypes\":[\"id_token\"],\"allowedScopes\":[\"openid\",\"profile\",\"email\",\"AiFabric\",\"IdentityServerApi\",\"Orchestrator\",\"OrchestratorApiUserAccess\"]}")

  if [ -z "$client_creation_response" ]; then
    echo "$(date) $red Failed to register client $IS_AIFABRIC_CLIENT_NAME with identity server $IDENTITY_SERVER_ENDPOINT ... Exiting $default"
    exit 1
  fi

  # Fetch access token authorize backend server call
  fetch_identity_server_access_token
}

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
    deregister_client
    exit 1
  else
    echo "$(date) $4 $default"
    deregister_client
    exit 1
  fi
}

# Wait for core service pods to come up
# $1 - Service label
function wait_for_service_pods_liveness() {
  echo "$(date) Waiting for core service $1 pod to come up"
  local wait_cmd="kubectl -n $CORE_SERVICE_NAMESPACE wait --field-selector status.phase=Running  --for=condition=ready  --timeout=60s  pod -l app=$1"
  local sleep_int=10
  local start_time
  local pod_ready_timeout=300
  local current_time
  local elapsed_time

  # Initial sleep is required
  start_time=$(date +"%s")
  sleep $sleep_int
  eval "$wait_cmd"
  while [[ $? -ne 0 ]]
  do
    sleep $sleep_int
    current_time=$(date +"%s")
    elapsed_time=$(( current_time - start_time ))
    if [[ $elapsed_time -gt $pod_ready_timeout ]]
    then
      echo "$(date) Timeout waiting for core service: $1 pods/pods to come alive in namespace: $CORE_SERVICE_NAMESPACE"
      deregister_client
      exit 1
    fi
    eval "$wait_cmd"
  done
}

# Validate if data manager is enabled, returns 0 for true, 1 for false
function isDataManagerEnabled() {
  local feature_flag_name=data-labeling-enabled
  local isDataManagerEnabled=$(kubectl -n $CORE_SERVICE_NAMESPACE get deployment ai-app-deployment -o yaml | grep FEATURE_FLAGS -A 1 | grep $feature_flag_name)
  if [ -z "$isDataManagerEnabled" ];
  then
    echo "$(date) Data manager is not enabled in this platform"
    return 1;
  fi
  return 0;
}

# Update core service specific env variables
function update_core_service_env_variables_for_recovery() {
  kubectl -n $CORE_SERVICE_NAMESPACE set env deployment/ai-pkgmanager-deployment S2S_RECOVERY_CLIENT_ID=$IS_AIFABRIC_CLIENT_ID S2S_RECOVERY_AUDIENCE=AiFabric
  kubectl -n $CORE_SERVICE_NAMESPACE set env deployment/ai-deployer-deployment S2S_RECOVERY_CLIENT_ID=$IS_AIFABRIC_CLIENT_ID S2S_RECOVERY_AUDIENCE=AiFabric
  kubectl -n $CORE_SERVICE_NAMESPACE set env deployment/ai-trainer-deployment S2S_RECOVERY_CLIENT_ID=$IS_AIFABRIC_CLIENT_ID S2S_RECOVERY_AUDIENCE=AiFabric
  

  # Sleep is needed for pods status to be updated
  sleep 2

  # Update pkg-manager service
  wait_for_service_pods_liveness "ai-pkgmanager-deployment"

  # Update deployer service
  wait_for_service_pods_liveness "ai-deployer-deployment"

  # Update trainer service
  wait_for_service_pods_liveness "ai-trainer-deployment"

  sleep 2

  if isDataManagerEnabled;
  then
  # Update data manager service
    kubectl -n $CORE_SERVICE_NAMESPACE set env deployment/ai-appmanager-deployment S2S_RECOVERY_CLIENT_ID=$IS_AIFABRIC_CLIENT_NAME S2S_RECOVERY_AUDIENCE=AiFabric
    wait_for_service_pods_liveness "ai-appmanager-deployment"
  fi
}

function parse_sanitize_response() {
  if [ -z "$1" ];
  then
    echo "$red $(date) No response received from server for sanitizing $2, retry may fix it ... Exiting !!! $default"
    exit 1
  fi

  resp_code=$(echo "$1" | grep -v '100 Continue' | grep HTTP | awk '{print $2}')

  if [ "${resp_code}" = "200" ];
  then
    echo "$green $(date) $2 sanitized Successfully $default"
  else
    echo "$red $(date) Sanitization failed for $2 with message: $1 $default"
    exit 1
  fi  
}

# Sanitize in flight ML packages
function sanitize_in_flight_ml_packages() {
  response=$(curl -i -k --silent --fail --show-error -X POST 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-pkgmanager/v1/system/mlpackage/recover' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')
  parse_sanitize_response $response "MLPackages"
}

# Sanitize in flight projects
function sanitize_in_flight_projects() {
  response=$(curl -i -k --silent --fail --show-error -X POST 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-pkgmanager/v1/system/project/recover' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')
  parse_sanitize_response $response "Projects"
}

# Sanitize in flight ML Skills
function sanitize_in_flight_ml_skills() {
  response=$(curl -i -k --silent --fail --show-error -X POST 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-deployer/v1/system/mlskills/recover' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')
  parse_sanitize_response $response "MLSkills"
}

# Sanitize in flight trainer namespaces
function sanitize_in_flight_namespaces() {
 response=$(curl -i -k --silent --fail --show-error -X POST 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-trainer/v1/system/namespace/recover' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')
 parse_sanitize_response $response "TrainerNamespaces"
}

# Sanitize in flight trainer namespaces
function sanitize_in_flight_deployer_namespaces() {
 response=$(curl -i -k --silent --fail --show-error -X POST 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-deployer/v1/system/namespace/recover' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')
 parse_sanitize_response $response "DeployerNamespaces"
}


# Sanitize in flight ML Pipelines
function sanitize_in_flight_pipelines() {
  response=$(curl -i -k --silent --fail --show-error -X POST 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-trainer/v1/system/pipeline/recover' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')
  parse_sanitize_response $response "Pipelines"
}

# Sanitize in flight Tenants
function sanitize_in_flight_tenants() {
  response=$(curl -i -k --silent --fail --show-error -X POST 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-deployer/v1/system/tenant/recover' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')
  parse_sanitize_response $response "Tenants"
}

# Sanitize in flight data manager apps
function sanitize_in_flight_data_manager_apps() {
  response=$(curl -i -k --silent --fail --show-error -X POST 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-appmanager/v1/system/app/recover' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')
  parse_sanitize_response $response "DataManager"
}

function sanitize_core_services_in_flight_operation() {
  echo "$(date) Sanitizing core services in flight operations"
  sanitize_in_flight_ml_packages
  sleep 5
  sanitize_in_flight_pipelines
  sleep 5
  sanitize_in_flight_namespaces
  sleep 5
  sanitize_in_flight_deployer_namespaces
  sleep 5
  sanitize_in_flight_ml_skills
  sleep 5
  sanitize_in_flight_projects
  sleep 5
  sanitize_in_flight_tenants

  if isDataManagerEnabled;
  then
  # Update data manager service
  sanitize_in_flight_data_manager_apps
  fi
  echo "$(date) Successfully sanitized in-flight core services operations"
}

# Validate file provided by user exists or not, It may be relative path or absolute path
# $1 - File path
function validate_file_path() {
  if [ ! -f "$1" ]; then
    echo "$red $(date) $1 file does not exist, Please check ... Exiting $default"
    exit 1
  fi
}

# Validate required modules exits in target setup
function validate_setup() {
  validate_dependency curl "curl --version"
  validate_dependency jq "jq --version"
  echo "$(date) Successfully validated required dependencies"
}

# Validate input provided by end user
function validate_input() {

  # Validate file path
  validate_file_path $POST_RESTORE_CONFIG_FILE

  readonly INGRESS_HOST_OR_FQDN=$(cat $POST_RESTORE_CONFIG_FILE | jq -r 'select(.hostOrFQDN != null) | .hostOrFQDN')
  readonly IDENTITY_SERVER_ENDPOINT=$(cat $POST_RESTORE_CONFIG_FILE | jq -r 'select(.identityServerEndPoint != null) | .identityServerEndPoint')
  readonly HOST_TENANT_NAME=$(cat $POST_RESTORE_CONFIG_FILE | jq -r 'select(.hostTenantName != null) | .hostTenantName')
  readonly HOST_TENANT_USER_ID_OR_EMAIL=$(cat $POST_RESTORE_CONFIG_FILE | jq -r 'select(.hostTenantIdOrEmailId != null) | .hostTenantIdOrEmailId')
  readonly HOST_TENANT_PASSWORD=$(cat $POST_RESTORE_CONFIG_FILE | jq -r 'select(.hostTenantPassword != null) | .hostTenantPassword')

  if [[ -z $INGRESS_HOST_OR_FQDN || -z $IDENTITY_SERVER_ENDPOINT || -z $HOST_TENANT_NAME || -z $HOST_TENANT_USER_ID_OR_EMAIL || -z $HOST_TENANT_PASSWORD ]]; then
    echo "$red $(date) Input is invalid or missing, Please check ... Exiting $default"
    exit 1
  fi

  echo "$green $(date) Successfully validated user input $default"
}

# Validate setup
validate_setup

# Validate input
validate_input

# Register Client and fetch access token
register_client_and_fetch_access_token

# Update core service env variables
update_core_service_env_variables_for_recovery

# Sanitize core services in flight operations
sanitize_core_services_in_flight_operation

echo "$green $(date) Successfully updated in flight user operations to end state"