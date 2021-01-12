#!/bin/bash

: '
This scipt will download ML package from target environment expect cloned Packages. User format
for script is described as
# $1 - ML package export json file path

[ Structure of ML Package import file]
  - hostOrFQDN:  Public end point from where backend service can be accessible
  - projectName: Project Name to which ML package will be imported
  - mlPackageName: Name of ML package to which new version will be uploaded if exits, otherwise new ML package by same name
  - mlPackageVersion: Version number which will be downloaded. It should be in format like 3.2 or 3.1 etc
  - accessToken: Access token to authorize server calls
[Script Version -> 20.10.1.2]
'

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)

echo "$green $(date) Starting exporting of ML Package: $2 for version: $3 under project $1 $default"

readonly PAGE_SIZE=10000
readonly ML_PACKAGE_EXPORT_INPUT_FILE=$1

# Validate API response
# $1 - Api response code
# $2 - Expected response code
# $3 - Success Message
# $4 - Error message
function validate_response_from_api() {
if [ $1 = $2 ];
then
  echo "$(date) $3"
elif [ "$1" = "DEFAULT" ];
then
  echo "$red $(date) Please validate access token or check internet. If fine check curl status code ... Exiting"
  exit 1
else
  echo "$4 $(date)"
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

if [ $? -ne 0 ];
then
  echo "$red $(date) Failed to download ML package"
  remove_directory
  exit 1
fi
}

# Get signed for ML package located at blob storage
# $1 - Signing Method Type
# $2 - Encoded URl
function get_signed_url() {
local signing_method=$1
local encoded_url=$2
generated_signed_url=$(curl --silent --fail --show-error -k 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-pkgmanager/v1/signedURL?contentType=application/x-zip-compressed&mlPackageName='"$blob_path"'&signingMethod='"$signing_method"'&encodedUrl='"$encoded_url"'' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')

local resp_code=DEFAULT
if [ ! -z "$generated_signed_url" ];
then
  resp_code=$(echo "$generated_signed_url" | jq -r 'select(.respCode != null) | .respCode')
fi

validate_response_from_api $resp_code "200" "Signed Url generated successfully for blob path: $blob_path, signing method: $1, encoded url: $2" "$red Failed to generate signed url for blob path $1, signing method $2 ... Exiting !!!"
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
readonly mlpackage_versions_of_ml_package=$(curl -k --silent --fail --show-error 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-pkgmanager/v1/mlpackages/'"$ml_package_id"'/versions?pageSize='"$PAGE_SIZE"'&sortBy=createdOn&sortOrder=DESC&projectId='"$project_id"'' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')

local resp_code=DEFAULT
if [ ! -z "$mlpackage_versions_of_ml_package" ];
then
  resp_code=$(echo "$mlpackage_versions_of_ml_package" | jq -r 'select(.respCode != null) | .respCode')
fi

validate_response_from_api $resp_code "200" "Successfully fetched ML package versions for ML package $ML_PACKAGE_NAME" "$red Failed to fetch ML package versions for ML package with id $ml_package_id ... Exiting"
}

# Fetch list of all ML packages
# S1 - Project Id under which ML packages is present
function fetch_ml_packages() {
local project_id=$1
ml_packages=$(curl -k --silent --fail --show-error 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-pkgmanager/v1/mlpackages?pageSize='"$PAGE_SIZE"'&sortBy=createdOn&sortOrder=DESC&project_id='"$project_id"'' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')

local resp_code=DEFAULT
if [ ! -z "$ml_packages" ];
then
  resp_code=$(echo "$ml_packages" | jq -r 'select(.respCode != null) | .respCode')
fi

validate_response_from_api $resp_code "200" "Successfully fetched ML packages" "$red 1 Failed to fetch ML packages ... Exiting"
}

# Find all projects
function fetch_projects() {
projects=$(curl -k --silent --fail --show-error 'https://'"$INGRESS_HOST_OR_FQDN"'/ai-pkgmanager/v1/projects?pageSize='"$PAGE_SIZE"'' -H 'authorization: Bearer '"$ACCESS_TOKEN"'')

local resp_code=DEFAULT
if [ ! -z "$projects" ];
then
  resp_code=$(echo "$projects" | jq -r 'select(.respCode != null) | .respCode')
fi

validate_response_from_api $resp_code "200" "Successfully fetched projects" "$red Failed to fetch projects ... Exiting"
}

# Download ML package
function download_ml_package() {

# Fetch Projects
fetch_projects

# Fetch project by name
local project=$(echo "$projects" | jq ".data.dataList[] | select(.name != null) | select(.name==\"$PROJECT_NAME\")")

if [ ! -z "$project" ];
then
  echo "$(date) Project by name $PROJECT_NAME fetched successfully"
else
  echo "$red $(date) Failed to project by name $PROJECT_NAME, Please check Project Name ... Exiting"
  exit 1
fi

local project_id=$(echo "$project" | jq -r 'select(.id != null) | .id')

if [ -z "$project_id" ];
then
  echo "$red $(date) Failed to extract Project id from list of projects ... Exiting"
  exit 1
fi

# Fetch list of all ML packages from target environment
fetch_ml_packages $project_id

# Fetch ML Package by name from list of Packages
local ml_package=$(echo "$ml_packages" | jq ".data.dataList[] | select(.name != null) | select(.name==\"$ML_PACKAGE_NAME\")")

if [ ! -z "$ml_package" ];
then
  echo "$(date) ML package by name $ML_PACKAGE_NAME fetched successfully"
else
  echo "$red $(date) Failed to find ML Package by name $ML_PACKAGE_NAME, Please check ML Package Name ... Exiting"
  exit 1
fi

# Extract ML package Id
ml_package_id=$(echo "$ml_package" | jq -r 'select(.id != null) | .id')

if [ -z "$ml_package_id" ];
then
  echo "$red $(date) Failed to extract ML package id from list of ML Packages ... Exiting"
  exit 1
fi

# Extract ML package major and minor version from input
local minor_ml_package_version=${ML_PACKAGE_VERSION##*.}
local major_ml_package_version=${ML_PACKAGE_VERSION%.*}

# Fetch list of ML Packages versions by ML Package Id
fetch_ml_package_versions_by_ml_package_id $ml_package_id $project_id

# Fetch ML package version fron list of versions
ml_package_version=$(echo "$mlpackage_versions_of_ml_package" | jq '.data.dataList[] | select((.version != null) and (.trainingVersion != null) and (.version=='$major_ml_package_version' and .trainingVersion=='$minor_ml_package_version')) | select(.status == ("UNDEPLOYED", "DEPLOYED", "DEPLOYING"))')

if [ ! -z "$ml_package_version" ];
then
  echo "$(date) ML package verison $ML_PACKAGE_VERSION fetched successfully"
else
  echo "$red $(date) Failed to fetch ML Package version $ML_PACKAGE_VERSION for ML package $ML_PACKAGE_NAME in status [UNDEPLOYED, DEPLOYED, DEPLOYING] ... Exiting"
  exit 1
fi

# Extract content uri
local ml_package_version_content_uri=$(echo "$ml_package_version" | jq 'select(.contentUri != null) | .contentUri')

if [ -z "$ml_package_version_content_uri" ];
then
echo "$red $(date) We can only download versions and trained versions, not cloned version, please verify ML package version ... Exiting !!!"
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

if [ -z "$signed_url" ];
then
  echo "$red $(date) Failed to extract signed url ... Exiting"
  exit 1
fi

# create new directory
create_directory

echo $ml_package_version > $metadata_file_name.json
echo "$yellow Successfully saved ML package version $ML_PACKAGE_VERSION metadata json file with name $metadata_file_name in [$(pwd)] directory $default"

# Download ML package using genearted signed url
download_ml_package_using_signedUrl $signed_url $ml_package_zip_file_name
}

# Validate file provided by user exists or not, It may be relative path or absolute path
# $1 - File path
function validate_file_path() {
if [ ! -f "$1" ];
then
  echo "$red $(date) $1 file does not exist, Please check ... Exiting"
  exit 1
fi
}

# Validate input provided by end user
function validate_input() {

# Validate file path
validate_file_path $ML_PACKAGE_EXPORT_INPUT_FILE

readonly INGRESS_HOST_OR_FQDN=$(cat $ML_PACKAGE_EXPORT_INPUT_FILE | jq -r 'select(.hostOrFQDN != null) | .hostOrFQDN')
readonly PROJECT_NAME=$(cat $ML_PACKAGE_EXPORT_INPUT_FILE | jq -r 'select(.projectName != null) | .projectName')
readonly ML_PACKAGE_NAME=$(cat $ML_PACKAGE_EXPORT_INPUT_FILE | jq -r 'select(.mlPackageName != null) | .mlPackageName')
readonly ML_PACKAGE_VERSION=$(cat $ML_PACKAGE_EXPORT_INPUT_FILE | jq -r 'select(.mlPackageVersion != null) | .mlPackageVersion')
readonly ACCESS_TOKEN=$(cat $ML_PACKAGE_EXPORT_INPUT_FILE | jq -r 'select(.accessToken != null) | .accessToken')

if [[ -z $INGRESS_HOST_OR_FQDN || -z $PROJECT_NAME || -z $ML_PACKAGE_NAME || -z $ML_PACKAGE_VERSION || -z $ACCESS_TOKEN ]];
then
  echo "$red $(date) Input is invalid or missing, Please check ... Exiting"
  exit 1
fi

echo "$(date) Successfully validated user input"
}

# Validate dependecny module
# $1 - Name of the dependecny module
# $2 - Command to validate module
function validate_dependency() {
list=$($2)
if [ -z "$list" ];
  then
  	echo "$red $(date) Please install ******** $1 ***********  ... Exiting"
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
dir_name=$(date +%Y-%m-%d:%H:%M:%S:%3N)
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

# Download requested ML package
download_ml_package

echo "$green $(date) Successfully downloaded $ML_PACKAGE_NAME V$ML_PACKAGE_VERSION in [$(pwd)] directory"