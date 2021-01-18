#!/bin/bash

: '
This scipt will download ML package from target environment, expect cloned packages.
# $1 - ML package export json file path

[ Structure of ML Package import file with exact key name ]
  - hostOrFQDN:  Public end point from where backend service can be accessible
  - identityServerEndPoint: End point where identity server is hosted
  - hostTenantName: Host Tenant name registered in identity server
  - hostTenantIdOrEmailId: Host tenant id or usetr Id
  - hostTenantPassword: Host tenant password
  - tenantName:  Name of tenant where ML package import will be carried out
  - projectName: Project Name to which ML package will be imported
  - mlPackageName: Name of ML package to which new version will be uploaded if exits, otherwise new ML package by same name
  - mlPackageVersion: Version number which will be downloaded. It should be in format like 3.2 or 3.1 etc
[Script Version -> 20.10.1.2]
'

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)

echo "$green $(date) Starting export of ML Package $default"

readonly PAGE_SIZE=10000
readonly ACCESS_TOKEN_LIFE_TIME=345600
readonly ML_PACKAGE_EXPORT_INPUT_FILE=$1

# Validate API response
# $1 - Api response code
# $2 - Expected response code
# $3 - Success Message
# $4 - Error message
function validate_response_from_api() {
  if [ $1 = $2 ]; then
    echo "$(date) $3"
  elif [ "$1" = "DEFAULT" ]; then
    echo "$red $(date) Please validate access token or check internet. If fine check curl status code ... Exiting $default"
    deregister_client
    exit 1
  else
    echo "$4 $(date) $default"
    deregister_client
    exit 1
  fi
}

# Download ML package from blob storage using generated signed url
# $1 - Signed Url
# $2 - ML Package name to be saved
function download_ml_package_using_signedUrl() {
  local signed_url=$1
  local ml_package=$2

  echo "$yellow $(date) Downloading ML package ... $default"
  curl --progress-bar -L -k -o $ml_package $signed_url

  if [ $? -ne 0 ]; then
    echo "$red $(date) Failed to download ML package $default"
    remove_directory
    deregister_client
    exit 1
  fi
}

# Get signed for ML package located at blob storage
# $1 - Signing Method Type
# $2 - Encoded URl
function get_signed_url() {
  local signing_method=$1
  local encoded_url=$2
  generated_signed_url=$(curl --silent --fail --show-error -k 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-pkgmanager/v1/signedURL?mlPackageName='"$blob_path"'&signingMethod='"$signing_method"'&encodedUrl='"$encoded_url"'' -H 'tenant-id: '"$TENANT_ID"'' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')

  local resp_code=DEFAULT
  if [ ! -z "$generated_signed_url" ]; then
    resp_code=$(echo "$generated_signed_url" | jq -r 'select(.respCode != null) | .respCode')
  fi

  validate_response_from_api $resp_code "200" "Signed url generated successfully for blob path: $blob_path, signing method: $1, encoded url: $2" "$red Failed to generate signed url for blob path $1, signing method $2 ... Exiting !!!"
}

# Generate ML package blob path
# $1 - ML package Id
# $2 - ML package file name with extention
function generate_ml_package_blobPath() {
  local account_id=$(echo "$ml_package_version" | jq -r 'select(.accountId != null) | .accountId')
  local tenant_id=$(echo "$ml_package_version" | jq -r 'select(.tenantId != null) | .tenantId')
  local project_id=$(echo "$ml_package_version" | jq -r 'select(.projectId != null) | .projectId')
  local ml_package_version_id=$(echo "$ml_package_version" | jq -r 'select(.id != null) | .id')

  blob_path=$account_id/$tenant_id/$project_id/$1/$ml_package_version_id/$2
}

# Fetch List of ML packages version given by ML package id
# $1 - ML Package id
function fetch_ml_package_versions_by_ml_package_id() {
  local ml_package_id=$1
  local project_id=$2
  readonly mlpackage_versions_of_ml_package=$(curl -k --silent --fail --show-error 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-pkgmanager/v1/mlpackages/'"$ml_package_id"'/versions?pageSize='"$PAGE_SIZE"'&sortBy=createdOn&sortOrder=DESC&projectId='"$project_id"'' -H 'tenant-id: '"$TENANT_ID"'' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')

  local resp_code=DEFAULT
  if [ ! -z "$mlpackage_versions_of_ml_package" ]; then
    resp_code=$(echo "$mlpackage_versions_of_ml_package" | jq -r 'select(.respCode != null) | .respCode')
  fi

  validate_response_from_api $resp_code "200" "Successfully fetched ML package versions for ML package $ML_PACKAGE_NAME" "$red Failed to fetch ML package versions for ML package $ML_PACKAGE_NAME ... Exiting"
}

# Fetch list of all ML packages
# $1 - Project Id under which ML packages is present
function fetch_ml_packages() {
  local project_id=$1
  ml_packages=$(curl -k --silent --fail --show-error 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-pkgmanager/v1/mlpackages?pageSize='"$PAGE_SIZE"'&sortBy=createdOn&sortOrder=DESC&projectId='"$project_id"'' -H 'tenant-id: '"$TENANT_ID"'' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')

  local resp_code=DEFAULT
  if [ ! -z "$ml_packages" ]; then
    resp_code=$(echo "$ml_packages" | jq -r 'select(.respCode != null) | .respCode')
  fi

  validate_response_from_api $resp_code "200" "Successfully fetched ML packages" "$red 1 Failed to fetch ML packages ... Exiting"
}

# Find all projects
function fetch_projects() {
  projects=$(curl -k --silent --fail --show-error 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-pkgmanager/v1/projects?pageSize='"$PAGE_SIZE"'' -H 'tenant-id: '"$TENANT_ID"'' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')

  local resp_code=DEFAULT
  if [ ! -z "$projects" ]; then
    resp_code=$(echo "$projects" | jq -r 'select(.respCode != null) | .respCode')
  fi

  validate_response_from_api $resp_code "200" "Successfully fetched projects" "$red Failed to fetch projects ... Exiting"
}

# Download ML package
function download_ml_package() {

  # Fetch tenant details
  get_tenant_details

  # Fetch Projects
  fetch_projects

  # Fetch project by name
  local project=$(echo "$projects" | jq ".data.dataList[] | select(.name != null) | select(.name==\"$PROJECT_NAME\")")

  if [ ! -z "$project" ]; then
    echo "$(date) Project by name $PROJECT_NAME fetched successfully"
  else
    echo "$red $(date) Failed to find project by name $PROJECT_NAME, Please check Project Name ... Exiting $default"
    deregister_client
    exit 1
  fi

  local project_id=$(echo "$project" | jq -r 'select(.id != null) | .id')

  if [ -z "$project_id" ]; then
    echo "$red $(date) Failed to extract project id from list of projects ... Exiting $default"
    deregister_client
    exit 1
  fi

  # Fetch list of all ML packages from target environment
  fetch_ml_packages $project_id

  # Fetch ML Package by name from list of Packages
  local ml_package=$(echo "$ml_packages" | jq ".data.dataList[] | select(.name != null) | select(.name==\"$ML_PACKAGE_NAME\")")

  if [ ! -z "$ml_package" ]; then
    echo "$(date) ML package by name $ML_PACKAGE_NAME fetched successfully"
  else
    echo "$red $(date) Failed to find ML Package by name $ML_PACKAGE_NAME, Please check ML Package name ... Exiting $default"
    deregister_client
    exit 1
  fi

  # Extract ML package Id
  ml_package_id=$(echo "$ml_package" | jq -r 'select(.id != null) | .id')

  if [ -z "$ml_package_id" ]; then
    echo "$red $(date) Failed to extract ML package id from list of ML Packages ... Exiting $default"
    deregister_client
    exit 1
  fi

  # Extract ML package major and minor version from input
  local minor_ml_package_version=${ML_PACKAGE_VERSION##*.}
  local major_ml_package_version=${ML_PACKAGE_VERSION%.*}

  # Fetch list of ML Packages versions by ML Package Id
  fetch_ml_package_versions_by_ml_package_id $ml_package_id $project_id

  # Fetch ML package version fron list of versions
  ml_package_version=$(echo "$mlpackage_versions_of_ml_package" | jq '.data.dataList[] | select((.version != null) and (.trainingVersion != null) and (.version=='$major_ml_package_version' and .trainingVersion=='$minor_ml_package_version')) | select(.status == ("UNDEPLOYED", "DEPLOYED", "DEPLOYING"))')

  if [ ! -z "$ml_package_version" ]; then
    echo "$(date) ML package verison $ML_PACKAGE_VERSION fetched successfully"
  else
    echo "$red $(date) Failed to fetch ML Package version $ML_PACKAGE_VERSION for ML package $ML_PACKAGE_NAME in status [UNDEPLOYED, DEPLOYED, DEPLOYING] in project $PROJECT_NAME... Exiting $default"
    deregister_client
    exit 1
  fi

  # Extract content uri
  local ml_package_version_content_uri=$(echo "$ml_package_version" | jq 'select(.contentUri != null) | .contentUri')

  if [ -z "$ml_package_version_content_uri" ]; then
    echo "$red $(date) We can only download version and trained packages, not cloned version, please verify ML package version ... Exiting $default"
    deregister_client
    exit 1
  fi

  # Extract zip file name
  zip_path="${ml_package_version_content_uri##*/}"
  ml_package_zip_file_name=${zip_path%.*}.zip

  metadata_file_name=${zip_path%.*}_v${ML_PACKAGE_VERSION}_metadata

  # Generate ML package blob path
  generate_ml_package_blobPath $ml_package_id $ml_package_zip_file_name

  # Get Signed url
  get_signed_url GET false

  signed_url=$(echo "$generated_signed_url" | jq -r 'select(.data != null) | .data' | jq -r 'select(.url != null) | .url')

  if [ -z "$signed_url" ]; then
    echo "$red $(date) Failed to extract signed url ... Exiting $default"
    deregister_client
    exit 1
  fi

  # create new directory
  create_directory

  echo $ml_package_version >$metadata_file_name.json
  echo "$yellow Successfully saved ML package version $ML_PACKAGE_VERSION metadata json file with name $metadata_file_name in [$(pwd)] directory $default"

  # Download ML package using genearted signed url
  download_ml_package_using_signedUrl $signed_url $ml_package_zip_file_name
}

# Get details of tenant by name
function get_tenant_details() {
  echo "Fetching Tenant details for tenant $TENANT_NAME"
  local aif_tenant_details=$(curl -k --silent --fail --show-error 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-deployer/v1/tenant/tenantdetails?tenantName='"$TENANT_NAME"'' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')

  local resp_code=DEFAULT
  if [ ! -z "$aif_tenant_details" ]; then
    resp_code=$(echo "$aif_tenant_details" | jq -r 'select(.respCode != null) | .respCode')
  fi
  validate_response_from_api $resp_code "200" "Successfully fetched tenant details for tenant $TENANT_NAME" "$red Failed to fetch tenant details for tenant $TENANT_NAME ... Exiting"

  # Extract tenant Id
  TENANT_ID=$(echo "$aif_tenant_details" | jq -r 'select(.data.provisionedTenantId != null) | .data.provisionedTenantId')

  if [ -z "$TENANT_ID" ]; then
    echo "$red $(date) Failed to extract tenant id... Exiting $default"
    deregister_client
    exit 1
  fi
}

# Fetch admin token from identity server end point using host tenant
function fetch_identity_server_token_to_register_client() {
  echo "$(date) Fetching identity server client registeration token"

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
    echo "$(date) $red Failed to generate token to register client ... Existing $default"
    exit 1
  fi
}

# Fetch access token to call backens server
function fetch_identity_server_access_token() {
  echo "$(date) Getting access token for client $IS_AIFABRIC_CLIENT_NAME from $IDENTITY_SERVER_ENDPOINT"

  readonly access_token_response=$(
    curl -k --silent --fail --show-error --raw -X --location --request POST "https://${IDENTITY_SERVER_ENDPOINT}/identity/connect/token" \
      -H 'Content-Type: application/x-www-form-urlencoded' \
      --data-urlencode "client_Id=$IS_AIFABRIC_CLIENT_ID" \
      --data-urlencode "client_secret=$IS_AIFABRIC_CLIENT_SECRET" \
      --data-urlencode "grant_type=client_credentials"
  )

  if [ -z "$access_token_response" ]; then
    echo "$(date) $red Failed to generate access token to call backend server ... Existing $default"
    deregister_client
    exit 1
  fi

  ACCESS_TOKEN=$(echo "$access_token_response" | jq -r 'select(.access_token != null) | .access_token')

  if [ -z "$ACCESS_TOKEN" ]; then
    echo "$(date) $red Failed to extract access token ... Existing $default"
    deregister_client
    exit 1
  fi

  echo "$(date) Successfully fetched access token to call backend server ... Existing "
}

function deregister_client() {
  echo "$default $(date) Deregistering client from $IDENTITY_SERVER_ENDPOINT with name $IS_AIFABRIC_CLIENT_NAME"
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

  client_creation_response=$(curl -k --silent --fail --show-error --raw -X POST "https://${IDENTITY_SERVER_ENDPOINT}/identity/api/Client" -H "Connection: keep-alive" -H "accept: text/plain" -H "Authorization: Bearer ${CLIENT_INSTALLTION_TOKEN}" -H "Content-Type: application/json-patch+json" -H "Accept-Encoding: gzip, deflate, br" -H "Accept-Language: en-US,en;q=0.9" -d "{\"clientId\":\"${IS_AIFABRIC_CLIENT_ID}\",\"clientName\":\"${IS_AIFABRIC_CLIENT_NAME}\",\"clientSecrets\":[\"${IS_AIFABRIC_CLIENT_SECRET}\"],\"requireConsent\":false,\"requireClientSecret\": true,\"allowOfflineAccess\":true,\"alwaysSendClientClaims\":true,\"allowAccessTokensViaBrowser\":true,\"allowOfflineAccess\":true,\"alwaysIncludeUserClaimsInIdToken\":true,\"accessTokenLifetime\":${ACCESS_TOKEN_LIFE_TIME},\"identityTokenLifetime\":${ACCESS_TOKEN_LIFE_TIME},\"authorizationCodeLifetime\":${ACCESS_TOKEN_LIFE_TIME},\"absoluteRefreshTokenLifetime\":${ACCESS_TOKEN_LIFE_TIME},\"slidingRefreshTokenLifetime\":${ACCESS_TOKEN_LIFE_TIME},\"RequireRequestObject\":true,\"Claims\":true,\"AlwaysIncludeUserClaimsInIdToken\":true,\"allowedGrantTypes\":[\"client_credentials\",\"authorization_code\"],\"allowedResponseTypes\":[\"id_token\"],\"allowedScopes\":[\"openid\",\"profile\",\"email\",\"AiFabric\",\"IdentityServerApi\",\"Orchestrator\",\"OrchestratorApiUserAccess\"]}")

  if [ -z "$client_creation_response" ]; then
    echo "$(date) $red Failed to register client $IS_AIFABRIC_CLIENT_NAME with identity server $IDENTITY_SERVER_ENDPOINT ... Exiting $default"
    exit 1
  fi

  # Fetch access token authorize backend server call
  fetch_identity_server_access_token
}

# Validate file provided by user exists or not, It may be relative path or absolute path
# $1 - File path
function validate_file_path() {
  if [ ! -f "$1" ]; then
    echo "$red $(date) $1 file does not exist, Please check ... Exiting $default"
    exit 1
  fi
}

# Validate input provided by end user
function validate_input() {

  # Validate file path
  validate_file_path $ML_PACKAGE_EXPORT_INPUT_FILE

  readonly INGRESS_HOST_OR_FQDN=$(cat $ML_PACKAGE_EXPORT_INPUT_FILE | jq -r 'select(.hostOrFQDN != null) | .hostOrFQDN')
  readonly TENANT_NAME=$(cat $ML_PACKAGE_EXPORT_INPUT_FILE | jq -r 'select(.tenantName != null) | .tenantName')
  readonly PROJECT_NAME=$(cat $ML_PACKAGE_EXPORT_INPUT_FILE | jq -r 'select(.projectName != null) | .projectName')
  readonly ML_PACKAGE_NAME=$(cat $ML_PACKAGE_EXPORT_INPUT_FILE | jq -r 'select(.mlPackageName != null) | .mlPackageName')
  readonly ML_PACKAGE_VERSION=$(cat $ML_PACKAGE_EXPORT_INPUT_FILE | jq -r 'select(.mlPackageVersion != null) | .mlPackageVersion')
  readonly IDENTITY_SERVER_ENDPOINT=$(cat $ML_PACKAGE_EXPORT_INPUT_FILE | jq -r 'select(.identityServerEndPoint != null) | .identityServerEndPoint')
  readonly HOST_TENANT_NAME=$(cat $ML_PACKAGE_EXPORT_INPUT_FILE | jq -r 'select(.hostTenantName != null) | .hostTenantName')
  readonly HOST_TENANT_USER_ID_OR_EMAIL=$(cat $ML_PACKAGE_EXPORT_INPUT_FILE | jq -r 'select(.hostTenantIdOrEmailId != null) | .hostTenantIdOrEmailId')
  readonly HOST_TENANT_PASSWORD=$(cat $ML_PACKAGE_EXPORT_INPUT_FILE | jq -r 'select(.hostTenantPassword != null) | .hostTenantPassword')

  if [[ -z $INGRESS_HOST_OR_FQDN || -z $PROJECT_NAME || -z $ML_PACKAGE_NAME || -z $ML_PACKAGE_VERSION || -z TENANT_NAME || -z IDENTITY_SERVER_ENDPOINT || -z HOST_TENANT_NAME || -z HOST_TENANT_USER_ID_OR_EMAIL || -z HOST_TENANT_PASSWORD ]]; then
    echo "$red $(date) Input is invalid or missing, Please check ... Exiting $default"
    exit 1
  fi

  echo "$(date) Successfully validated user input"
}

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
  validate_dependency curl "curl --version"
  validate_dependency jq "jq --version"
  echo "$(date) Successfully validated required dependecies"
}

# Create directory
function create_directory() {
  dir_name=${ML_PACKAGE_NAME}_v${ML_PACKAGE_VERSION}_$(date +%s)
  mkdir -p $dir_name
  cd $dir_name
}

# Remove directory
function remove_directory() {
  rm -rf $dir_name
}

# Validate Setup
validate_setup

# Validate Input
validate_input

# Register Client and fetch access token
register_client_and_fetch_access_token

# Download requested ML package
download_ml_package

# Register client
deregister_client

echo "$green $(date) Successfully downloaded $ML_PACKAGE_NAME V$ML_PACKAGE_VERSION in [$(pwd)] directory $default"
