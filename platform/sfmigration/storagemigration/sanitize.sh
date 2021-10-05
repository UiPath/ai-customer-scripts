#!/bin/bash

: '
This scipt will import all data stored at a path to blob storage in target environments.
# $1 - ml-package-folder to scan and update in place
[Script Version -> 21.10]
'

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)

readonly BASE_PATH=$1

echo "$green $(date) Starting mlpackage zip updates... $default"

if [ ! -d "$1" ]; then
    echo "$red $(date) $1 dir does not exist, Please check ... Exiting $default"
    exit 1
fi


# Validate dependency module
# $1 - Name of the dependency module
# $2 - Command to validate module
function validate_dependency() {
  eval $2
  # Next statement is checking last command success aws --version has some issue
  if [ $? -ne 0 ]; then
    echo "$red $(date) Please install ******** $1 ***********  ... Exiting $default"
    exit 1
  fi
}


function process_file() {
	echo "$green $(date) Processing file $1... $default"
	fullFileName=${1##*/}
	onlyFileName=${fullFileName%.*}
	zip -d $1 "$onlyFileName/uipath_wrapper_config.json" || true
	zip -d $1 "$onlyFileName/uipath_core.tar.gz" || true
}

function process_files() {
  cd $BASE_PATH
  while read file; do
    process_file ${file}
  done <<<"$FILES"
  cd -
}

function list_files() {
  cd $BASE_PATH
  files=$(find . -type f)
  readonly FILES=${files}
  cd -
}


# List Buckets
list_files

# Process data inside buckets
process_files
