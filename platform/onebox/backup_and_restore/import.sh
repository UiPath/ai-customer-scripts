#!/bin/bash

: '
This scipt will upload ML package to target environment.
# $1 - ML package import json file path

[ Structure of ML Package import json file along with exact key name]
  - hostOrFQDN:  Public end point from where backend service can be accessible
  - identityServerEndPoint: End point where identity server is hosted
  - hostTenantName: Host Tenant name registered in identity server
  - hostTenantIdOrEmailId: Host tenant id or usetr Id
  - hostTenantPassword: Host tenant password
  - tenantName:  Name of tenant where ML package import will be carried out
  - projectName: Project Name to which ML package will be imported
  - mlPackageName: Name of ML package to which new version will be uploaded if exits, otherwise new ML package by same name
  - mlPackageMajorVersionForPrivatePackage: Used to upload new minor version like 3.X. Used for private packages only. Default value should be zero
  - mlPackageZipFilePath: ML package zip file path that will be uploaded to target environment
  - mlPackageMetadataFilePath: ML package import metadata json file path
[Script Version -> 20.10.1.2]
'

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)

# Will be used in public package upload
source_ml_package_owned_by_accountId=""
source_ml_package_owned_by_tenantId=""
source_ml_package_owned_by_projectId=""
source_ml_package_id=""
source_ml_package_version_id=""

readonly ML_PACKAGE_IMPORT_INPUT_FILE=$1
readonly PAGE_SIZE=10000
readonly ACCESS_TOKEN_LIFE_TIME=345600

echo "$green $(date) Starting import of ML Package $default"

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

# Create public ML package
function create_public_ml_package_metadata() {
  echo "$(date) Creating public ML package metadata for ML package $ML_PACKAGE_NAME in project $PROJECT_NAME"
  local create_public_ml_package=$(curl -k --silent --fail --show-error 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-pkgmanager/v1/mlpackages/clone' -H 'tenant-id: '"$TENANT_ID"'' -H 'accept: application/json, text/plain, */*' -H 'authorization: Bearer '"$ACCESS_TOKEN"'' -H 'content-type: application/json;charset=UTF-8' --data-binary ''"$extractedMetadata"'')

  local resp_code=DEFAULT
  if [ ! -z "$create_public_ml_package" ]; then
    resp_code=$(echo "$create_public_ml_package" | jq -r 'select(.respCode != null) | .respCode')
  fi

  validate_response_from_api $resp_code "201" "$green Successfully created ML package $ML_PACKAGE_NAME  $default" "$red Failed to create ML package ... Exiting !!!"
}

# Create public ML package version
# $1 - ML package id
function create_public_ml_package_version_metadata() {
  local ml_package_id=$1
  echo "$(date) Creating public ML package version metadata for ML package $ML_PACKAGE_NAME in project $PROJECT_NAME"
  local create_public_ml_package_version=$(curl -k --silent --fail --show-error 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-pkgmanager/v1/mlpackages/'"$ml_package_id"'/versions/clone' -H 'tenant-id: '"$TENANT_ID"'' -H 'accept: application/json, text/plain, */*' -H 'authorization: Bearer '"$ACCESS_TOKEN"'' \
    -H 'content-type: application/json;charset=UTF-8' --data-binary ''"$extractedMetadata"'')

  local resp_code=DEFAULT
  if [ ! -z "$create_public_ml_package_version" ]; then
    resp_code=$(echo "$create_public_ml_package_version" | jq -r 'select(.respCode != null) | .respCode')
    local major_package_version=$(echo "$create_public_ml_package_version" | jq '.data | select(.version != null) | .version')
    local minor_package_version=$(echo "$create_public_ml_package_version" | jq '.data | select(.trainingVersion != null) | .trainingVersion')
  fi

  validate_response_from_api $resp_code "201" "$green Successfully created ML package version v$major_package_version.$minor_package_version for ML package $ML_PACKAGE_NAME $default" "$red Failed to create ML package version ... Exiting !!!"
}

# Create ML package version metadata
# $1 - ML Package Id
function create_ml_package_version_metadata() {
  echo "$(date) Creating new ML package version for ML package $ML_PACKAGE_NAME in project $PROJECT_NAME"
  local ml_package_id=$1
  local ml_package_version_creation=$(curl --silent --fail --show-error -k 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-pkgmanager/v1/mlpackages/'"$ml_package_id"'/versions' -H 'tenant-id: '"$TENANT_ID"'' -H 'authorization: Bearer '"$ACCESS_TOKEN"'' -H 'content-type: application/json;charset=UTF-8' --data-binary ''"$extractedMetadata"'')

  local resp_code=DEFAULT
  if [ ! -z "$ml_package_version_creation" ]; then
    resp_code=$(echo "$ml_package_version_creation" | jq -r 'select(.respCode != null) | .respCode')
    local major_package_version=$(echo "$ml_package_version_creation" | jq '.data | select(.version != null) | .version')
    local minor_package_version=$(echo "$ml_package_version_creation" | jq '.data | select(.trainingVersion != null) | .trainingVersion')
  fi

  validate_response_from_api $resp_code "201" "$green Successfully created ML package version v$major_package_version.$minor_package_version for ML package $ML_PACKAGE_NAME $default" "$red Failed to create ML package version ... Exiting !!!"
}

# Create ML package metadata
function create_ml_package_metadata() {
  echo "$(date) Creating new ML package $ML_PACKAGE_NAME in project $PROJECT_NAME"
  local ml_package_creation=$(curl --silent --fail --show-error -k 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-pkgmanager/v1/mlpackages' -H 'tenant-id: '"$TENANT_ID"'' -H 'content-type: application/json;charset=UTF-8' -H 'authorization: Bearer '"$ACCESS_TOKEN"'' --data-binary ''"$extractedMetadata"'')

  local resp_code=DEFAULT
  if [ ! -z "$ml_package_creation" ]; then
    resp_code=$(echo "$ml_package_creation" | jq -r 'select(.respCode != null) | .respCode')
  fi

  validate_response_from_api $resp_code "201" "$green Successfully created ML package" "$red Failed to create ML package version ... Exiting !!!"
}

# Validate if last command executed successfully
# $1- Error message
function validate_last_command_executed_succesfully() {
  if [ $? -ne 0 ]; then
    echo "$red $(date) $1 $default"
    deregister_client
    exit 1
  fi
}

# Create package upload metadata
# $1 - Project id
# $2 - Flag to validate if public package
# $3 - Is Private package version upload
function create_package_upload_payload() {
  local project_id=$1
  local is_public_package=$2
  local is_private_package_version_upload=$2

  if [ "$is_public_package" = true ]; then
    extractedMetadata=$(cat $ML_PACKAGE_METADATA_FILE_PATH | jq '{description,displayName,inputDescription,mlPackageOwnedByAccountId,mlPackageOwnedByTenantId,mlPackageOwnedByProjectId,sourcePackageId,sourcePackageVersionId,name,outputDescription,settings,projectId,stagingUri}' | jq -M ". + {name:\"$ML_PACKAGE_NAME\",displayName:\"$ML_PACKAGE_NAME\",projectId:\"$project_id\",stagingUri:\"$signed_url\",mlPackageOwnedByAccountId:\"$source_ml_package_owned_by_accountId\",mlPackageOwnedByTenantId:\"$source_ml_package_owned_by_tenantId\",mlPackageOwnedByProjectId:\"$source_ml_package_owned_by_projectId\",sourcePackageId:\"$source_ml_package_id\",sourcePackageVersionId:\"$source_ml_package_version_id\"}")
  else
    if [ "$is_public_package" = true ]; then
      extractedMetadata=$(cat $ML_PACKAGE_METADATA_FILE_PATH | jq '{gpu,displayName,name,description,inputDescription,outputDescription,mlPackageLanguage,inputType,retrainable,changeLog,projectId,stagingUri}' | jq -M ". + {name:\"$ML_PACKAGE_NAME\", displayName:\"$ML_PACKAGE_NAME\",projectId:\"$project_id\",stagingUri:\"$signed_url\"}")
    else
      extractedMetadata=$(cat $ML_PACKAGE_METADATA_FILE_PATH | jq '{gpu,displayName,name,description,inputDescription,outputDescription,mlPackageLanguage,inputType,retrainable,changeLog,projectId,stagingUri}' | jq -M ". + {name:\"$ML_PACKAGE_NAME\", displayName:\"$ML_PACKAGE_NAME\",projectId:\"$project_id\",stagingUri:\"$signed_url\",version:\"$ML_PACKAGE_MAJOR_VERSION_FOR_PRIVATE_PACKAGE\"}")
    fi
  fi

  validate_last_command_executed_succesfully "$red Failed to extract ML package metadata from $ML_PACKAGE_METADATA_FILE_PATH"
}

# Upload ML package to blob storage for target environment
function upload_ml_package_using_signed_url() {

  # Get Signed url
  get_signed_url PUT false $ML_PACKAGE_ZIP_FILE_PATH

  # Global signed url will be used in payload creation
  signed_url=$(echo "$generated_signed_url" | jq -r 'select(.data != null) | .data' | jq -r 'select(.url != null) | .url')

  if [ -z "$signed_url" ]; then
    echo "$red $(date) Failed to extract signed url ... Exiting $default"
    deregister_client
    exit 1
  fi

  echo "$yellow $(date) Uploading ML package $default"

  curl -k -L $signed_url -X 'PUT' -H 'content-type: application/x-zip-compressed' --data-binary @$ML_PACKAGE_ZIP_FILE_PATH

  validate_last_command_executed_succesfully "$red Failed to upload ML package"

  echo "$(date) Successfully uploaded ML package zip file"
}

# Get signed for ML package located at blob storage
# $1 - Signing Method Type
# $2 - Encoded URl
# $3 - Zip file
function get_signed_url() {
  local signing_method=$1
  local encoded_url=$2
  local ml_package_file=$3

  # Change forward to backslash if any for compatibiity
  local ml_package_zip_path=$(echo $ml_package_file | sed 's/\\/\//g')
  local blob_name=${ml_package_zip_path##*/}

  generated_signed_url=$(curl -k --silent --fail --show-error 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-pkgmanager/v1/signedURL?contentType=application/x-zip-compressed&mlPackageName='"$blob_name"'&signingMethod='"$signing_method"'&encodedUrl='"$encoded_url"'' -H 'tenant-id: '"$TENANT_ID"'' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')

  local resp_code=DEFAULT
  if [ ! -z "$generated_signed_url" ]; then
    resp_code=$(echo "$generated_signed_url" | jq -r 'select(.respCode != null) | .respCode')
  fi

  validate_response_from_api $resp_code "200" "Signed Url generated successfully for ML Package: $ml_package_zip_path, signing method: $signing_method, encoded url: $encoded_url" "$red Failed to generate signed url for blob $ml_package_zip_path, signing method $signing_method ... Exiting !!!"
}

# Fetch list of all ML packages
# $1 - Project Id under which ML packages are present
function fetch_ml_packages() {
  local project_id=$1
  ml_packages=$(curl -k --silent --fail --show-error 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-pkgmanager/v1/mlpackages?pageSize='"$PAGE_SIZE"'&sortBy=createdOn&sortOrder=DESC&projectId='"$project_id"'' -H 'tenant-id: '"$TENANT_ID"'' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')

  local resp_code=DEFAULT
  if [ ! -z "$ml_packages" ]; then
    resp_code=$(echo "$ml_packages" | jq -r 'select(.respCode != null) | .respCode')
  fi

  validate_response_from_api $resp_code "200" "Successfully fetched ML packages" "$red Failed to fetch ML packages ... Exiting"
}

# Find all projects
function fetch_projects() {
  projects=$(curl -k --silent --fail --show-error 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-pkgmanager/v1/projects?pageSize='"$PAGE_SIZE"'' -H 'tenant-id: '"$TENANT_ID"'' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')

  local resp_code=DEFAULT
  if [ ! -z "$projects" ]; then
    resp_code=$(echo "$projects" | jq -r 'select(.respCode != null) | .respCode')
  fi

  validate_response_from_api $resp_code "200" "Successfully fetched projects" "$red Failed to fetch projects  ... Exiting"
}

# Extract destination public ML package metadata
# $1 - Existing public ML package name in target environment
# $2 - Public ML package major version in target environment
function extract_public_package_additional_metadata_from_target_environment() {

  local public_ml_package_name=$1
  local major_ml_package_version=$2
  local minor_ml_package_version=0

  echo "$(date) Extracting additional metadata for public package $public_ml_package_name with version $major_ml_package_version.$minor_ml_package_version from target environment"

  local public_projects=$(curl -k --silent --fail --show-error 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-pkgmanager/v1/projects/public?pageSize='"$PAGE_SIZE"'' -H 'tenant-id: '"$TENANT_ID"'' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')

  local resp_code=DEFAULT
  if [ ! -z "$public_projects" ]; then
    resp_code=$(echo "$public_projects" | jq -r 'select(.respCode != null) | .respCode')
  fi

  validate_response_from_api $resp_code "200" "Successfully fetched public project" "$red Failed to fetch public project ... Exiting"

  for ((i = 0; i < $(echo "$public_projects" | jq -r ".data | length"); i = i + 1)); do
    local public_project=$(echo "$public_projects" | jq -r ".data[$i]")
    local mlPackage_owned_by_accountId=$(echo "$public_project" | jq -r 'select(.accountId != null) | .accountId')
    local mlPackage_owned_by_tenantId=$(echo "$public_project" | jq -r 'select(.tenantId != null)  | .tenantId')
    local mlPackage_owned_by_projectId=$(echo "$public_project" | jq -r 'select(.id != null) | .id')
    local project_name=$(echo "$public_project" | jq -r 'select(.name != null) | .name')

    local public_ml_packages_under_public_project=$(curl -k --silent --fail --show-error 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-pkgmanager/v1/mlpackages?pageSize='"$PAGE_SIZE"'&status=DEPLOYING,DEPLOYED,UNDEPLOYED&mlPackageOwnedByAccountId='"$mlPackage_owned_by_accountId"'&mlPackageOwnedByTenantId='"$mlPackage_owned_by_tenantId"'&mlPackageOwnedByProjectId='"$mlPackage_owned_by_projectId"'' -H 'tenant-id: '"$TENANT_ID"'' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')

    local resp_code=DEFAULT
    if [ ! -z "$public_ml_packages_under_public_project" ]; then
      resp_code=$(echo "$public_projects" | jq -r 'select(.respCode != null) | .respCode')
    fi

    validate_response_from_api $resp_code "200" "Successfully fetched ML packages under project $project_name" "$red Failed to fetch ml packages under project $project_name ... Exiting"

    local public_ml_package=$(echo "$public_ml_packages_under_public_project" | jq ".data.dataList[] | select(.name != null) | select(.name==\"$public_ml_package_name\")")

    if [ ! -z "$public_ml_package" ]; then
      echo "$(date) ML Package with name $public_ml_package_name found"
      local public_ml_package_id=$(echo "$public_ml_package" | jq -r 'select(.id != null) | .id')

      local public_ml_package_version_under_public_project=$(curl -k --silent --fail --show-error 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-pkgmanager/v1/mlpackages/'"$public_ml_package_id"'??pageSize='"$PAGE_SIZE"'&status=PURGED,VALIDATION_FAILED,VALIDATING,THREAT_DETECTED&mlPackageOwnedByAccountId='"$mlPackage_owned_by_accountId"'&mlPackageOwnedByTenantId='"$mlPackage_owned_by_tenantId"'&mlPackageOwnedByProjectId='"$mlPackage_owned_by_projectId"'' -H 'tenant-id: '"$TENANT_ID"'' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')

      local resp_code=DEFAULT
      if [ ! -z "$public_ml_package_version_under_public_project" ]; then
        resp_code=$(echo "$public_ml_package_version_under_public_project" | jq -r 'select(.respCode != null) | .respCode')
      fi

      validate_response_from_api $resp_code "200" "Successfully fetched ML package versions for ML package $public_ml_package_name" "$red Failed to fetch ML package versions for ml package $public_ml_package_name ... Exiting"

      local public_ml_package_version=$(echo "$public_ml_package_version_under_public_project" | jq '.data.mlPackageVersions[] | select((.version != null) and (.trainingVersion != null) and (.version=='$major_ml_package_version' and .trainingVersion=='$minor_ml_package_version')) | select(.status == ("UNDEPLOYED", "DEPLOYED", "DEPLOYING"))')

      if [ ! -z "$public_ml_package_version" ]; then
        echo "$(date) ML package version $major_ml_package_version.$minor_ml_package_version found for ML package $public_ml_package_name"

        # update all required properties for public model
        source_ml_package_owned_by_accountId=$mlPackage_owned_by_accountId
        source_ml_package_owned_by_tenantId=$mlPackage_owned_by_tenantId
        source_ml_package_owned_by_projectId=$mlPackage_owned_by_projectId
        source_ml_package_id=$public_ml_package_id
        source_ml_package_version_id=$(echo "$public_ml_package_version" | jq -r 'select(.id != null) | .id')

        # Return, we have found required ML package version in target environment
        return
      fi
    fi
  done
}

function upload_ml_package() {

  # Fetch tenant details
  get_tenant_details

  # Fetch Projects
  fetch_projects

  # Fetch project by name
  local project=$(echo "$projects" | jq -r ".data.dataList[] | select(.name != null) | select(.name==\"$PROJECT_NAME\")")

  if [ ! -z "$project" ]; then
    echo "$(date) Project by name $PROJECT_NAME fetched successfully"
  else
    echo "$red $(date) Failed to project by name $PROJECT_NAME, Please check Project Name ... Exiting $default"
    deregister_client
    exit 1
  fi

  local project_id=$(echo "$project" | jq -r 'select(.id != null) | .id')

  if [ -z "$project_id" ]; then
    echo "$red $(date) Failed to extract Project id from list of projects ... Exiting $default"
    deregister_client
    exit 1
  fi

  # Fetch list of all ML packages from target environment
  fetch_ml_packages $project_id

  # Fetch ML Package by name from list of Packages
  local ml_package=$(echo "$ml_packages" | jq ".data.dataList[] | select(.name != null) | select(.name==\"$ML_PACKAGE_NAME\")")

  if [ ! -z "$ml_package" ]; then
    echo "$yellow $(date) ML package by name $ML_PACKAGE_NAME fetched successfully, New ML version will be uploaded $default"

    # Extract ML package Id
    ml_package_id=$(echo "$ml_package" | jq -r 'select(.id != null) | .id')

    if [ -z "$ml_package_id" ]; then
      echo "$red $(date) Failed to extract ML package id from list of ML Packages ... Exiting $default"
      deregister_client
      exit 1
    fi

    # Upload ML package
    upload_ml_package_using_signed_url

    # Validate if ML package metadata is for public package or not
    local is_public_package=$(cat $ML_PACKAGE_METADATA_FILE_PATH | jq -r -e '.sourcePackageName?')

    if [ "$is_public_package" != null ]; then
      echo "$(date) ML package metadata belong to public package"

      local is_ml_package_also_public=$(echo $ml_package | jq -r -e '.sourcePackageName?')

      if [ "$is_ml_package_also_public" = null ]; then
        echo "$red $(date) ML package should also be public for public packge metadata, please check metadata file ... Exiting $default"
        deregister_client
        exit 1
      fi

      local sourcePackageVersion=$(cat $ML_PACKAGE_METADATA_FILE_PATH | jq -r '.sourcePackageVersion')
      extract_public_package_additional_metadata_from_target_environment $is_public_package $sourcePackageVersion

      # Validate public ML package metadata extracted successfully
      validate_extracted_public_ml_package_metadata

      # create payload for ML package
      create_package_upload_payload $project_id "true" "false"

      # Create public ML package
      create_public_ml_package_version_metadata $ml_package_id
    else
      echo "$(date) ML package metadata belong to private package"

      local is_ml_package_not_public=$(echo $ml_package | jq -r -e '.sourcePackageName?')

      if [ "$is_ml_package_not_public" != null ]; then
        echo "$red $(date) ML package metadata should also be public for public package, please check metadata file ... Exiting $default"
        deregister_client
        exit 1
      fi

      # create payload for package upload
      create_package_upload_payload $project_id "false" "false"

      # Crate ML Package version package
      create_ml_package_version_metadata $ml_package_id
    fi
  else
    echo "$yellow $(date) Failed to find ML Package by name $ML_PACKAGE_NAME, new ML package will be uploaded $default"

    # validate unique name for ML package
    validate_unique_ml_package_name $ML_PACKAGE_NAME

    # Upload ML package
    upload_ml_package_using_signed_url

    # Validate if ML package metadata is for public package or not
    local is_public_package=$(cat $ML_PACKAGE_METADATA_FILE_PATH | jq -r -e '.sourcePackageName?')

    if [ "$is_public_package" != null ]; then
      echo "$(date) ML package version metadata belong to public package"
      local sourcePackageVersion=$(cat $ML_PACKAGE_METADATA_FILE_PATH | jq -r '.sourcePackageVersion')
      extract_public_package_additional_metadata_from_target_environment $is_public_package $sourcePackageVersion

      # Validate public ML package metadata extracted successfully
      validate_extracted_public_ml_package_metadata

      # Create payload for ML package
      create_package_upload_payload $project_id "true" "false"

      # Create public ML package version
      create_public_ml_package_metadata
    else
      echo "$(date) ML package metadata belong to private package"

      # Create payload for ML package
      create_package_upload_payload $project_id "false" "true"

      # Create ML package version metadata
      create_ml_package_metadata
    fi
  fi
}

# Get details of tenant by name
function get_tenant_details() {
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

  echo "$(date) Successfully fetched client register token"
}

# Fetch access token to call backens server
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
  echo "$(date) Deregistering client from $IDENTITY_SERVER_ENDPOINT with name $IS_AIFABRIC_CLIENT_NAME"
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

# Valiate if ML package name is unique acros all projects in target environment
# $1 - ML package name
function validate_unique_ml_package_name() {

  echo "$(date) Validating uniqueness of ML package name"
  local ml_package_name=$1
  local is_unique_ml_package=$(curl -k --silent --fail --show-error 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-pkgmanager/v1/mlpackages/search?name='"$ml_package_name"'' -H 'tenant-id: '"$TENANT_ID"'' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')

  if [ -z "$is_unique_ml_package" ]; then
    echo "$red $(date) ML package with name $1 alreday exits in target enviornment, can't create new ML package ... Exiting $default"
    deregister_client
    exit 1
  fi
}

function validate_extracted_public_ml_package_metadata() {

  if [[ -z $source_ml_package_owned_by_accountId || -z $source_ml_package_owned_by_tenantId || -z $source_ml_package_owned_by_projectId || -z $source_ml_package_id || -z $source_ml_package_version_id ]]; then
    echo "$red $(date) Some of ML package metadata is still empty after extration ... Exiting $default"
    deregister_client
    exit 1
  fi
}

# Validate file provided by user exists or not, It may be relative path or absolute path
# $1 - File path
function validate_file_path() {
  if [ ! -f "$1" ]; then
    echo "$red $(date) $1 file does not exist, Please check ... Exiting $default"
    exit 1
  fi
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

# Validate input provided by end user
function validate_input() {

  # Validate file path
  validate_file_path $ML_PACKAGE_IMPORT_INPUT_FILE

  readonly INGRESS_HOST_OR_FQDN=$(cat $ML_PACKAGE_IMPORT_INPUT_FILE | jq -r 'select(.hostOrFQDN != null) | .hostOrFQDN')
  readonly TENANT_NAME=$(cat $ML_PACKAGE_IMPORT_INPUT_FILE | jq -r 'select(.tenantName != null) | .tenantName')
  readonly PROJECT_NAME=$(cat $ML_PACKAGE_IMPORT_INPUT_FILE | jq -r 'select(.projectName != null) | .projectName')
  readonly ML_PACKAGE_NAME=$(cat $ML_PACKAGE_IMPORT_INPUT_FILE | jq -r 'select(.mlPackageName != null) | .mlPackageName')
  readonly IDENTITY_SERVER_ENDPOINT=$(cat $ML_PACKAGE_IMPORT_INPUT_FILE | jq -r 'select(.identityServerEndPoint != null) | .identityServerEndPoint')
  readonly HOST_TENANT_NAME=$(cat $ML_PACKAGE_IMPORT_INPUT_FILE | jq -r 'select(.hostTenantName != null) | .hostTenantName')
  readonly HOST_TENANT_USER_ID_OR_EMAIL=$(cat $ML_PACKAGE_IMPORT_INPUT_FILE | jq -r 'select(.hostTenantIdOrEmailId != null) | .hostTenantIdOrEmailId')
  readonly HOST_TENANT_PASSWORD=$(cat $ML_PACKAGE_IMPORT_INPUT_FILE | jq -r 'select(.hostTenantPassword != null) | .hostTenantPassword')
  readonly ML_PACKAGE_MAJOR_VERSION_FOR_PRIVATE_PACKAGE=$(cat $ML_PACKAGE_IMPORT_INPUT_FILE | jq -r 'select(.mlPackageMajorVersionForPrivatePackage != null) | .mlPackageMajorVersionForPrivatePackage')
  readonly ML_PACKAGE_ZIP_FILE_PATH=$(cat $ML_PACKAGE_IMPORT_INPUT_FILE | jq -r 'select(.mlPackageZipFilePath != null) | .mlPackageZipFilePath')
  readonly ML_PACKAGE_METADATA_FILE_PATH=$(cat $ML_PACKAGE_IMPORT_INPUT_FILE | jq -r 'select(.mlPackageMetadataFilePath != null) | .mlPackageMetadataFilePath')

  if [[ -z $INGRESS_HOST_OR_FQDN || -z $PROJECT_NAME || -z $ML_PACKAGE_NAME || -z $ML_PACKAGE_MAJOR_VERSION_FOR_PRIVATE_PACKAGE || -z $ML_PACKAGE_ZIP_FILE_PATH || -z $ML_PACKAGE_METADATA_FILE_PATH || -z TENANT_NAME || -z IDENTITY_SERVER_ENDPOINT || -z HOST_TENANT_NAME || -z HOST_TENANT_USER_ID_OR_EMAIL || -z HOST_TENANT_PASSWORD ]]; then
    echo "$red $(date) Input is invalid or missing, Please check ... Exiting $default"
    exit 1
  fi

  validate_file_path $ML_PACKAGE_ZIP_FILE_PATH
  validate_file_path $ML_PACKAGE_METADATA_FILE_PATH

  echo "$(date) Successfully validated user input"
}

# Validate required modules exits in target setup
function validate_setup() {
  validate_dependency curl "curl --version"
  validate_dependency jq "jq --version"
  echo "$(date) Successfully validated required dependecies"
}

# Validate Setup
validate_setup

# Validate Input
validate_input

# Register Client and fetch access token
register_client_and_fetch_access_token

# Upload requested ML package
upload_ml_package

# Register client
deregister_client

echo "$green $(date) Successfully uploaded ML Package under project $PROJECT_NAME in target environment $default"
