#!/bin/bash

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
  validate_dependency "bcp utility" "bcp -v"
  validate_dependency "sqlcmd utility" "sqlcmd -?"
  validate_dependency "jq utility" "jq --version"
  validate_dependency "aws s3" "aws --version"
  validate_dependency "s3cmd" "s3cmd --version"
  validate_dependency "zip" "zip -v"

  echo " $green $(date) Successfully validated required dependencies $default"
}

# Validate Setup dependency
validate_setup
