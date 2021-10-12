#!/bin/bash

# function to validate database connection
validate_storage_conn() {
  CREDENTIALS_FILE=$1
  export AWS_HOST=$(cat $CREDENTIALS_FILE | jq -r 'select(.AWS_HOST != null) | .AWS_HOST')
  export AWS_ENDPOINT=$(cat $CREDENTIALS_FILE | jq -r 'select(.AWS_ENDPOINT != null) | .AWS_ENDPOINT')
  export AWS_ACCESS_KEY_ID=$(cat $CREDENTIALS_FILE | jq -r 'select(.AWS_ACCESS_KEY_ID != null) | .AWS_ACCESS_KEY_ID')
  export AWS_SECRET_ACCESS_KEY=$(cat $CREDENTIALS_FILE | jq -r 'select(.AWS_SECRET_ACCESS_KEY != null) | .AWS_SECRET_ACCESS_KEY')

    echo "$green Validating connection to $1 $default"

    result=$(aws s3 --endpoint-url $AWS_ENDPOINT --no-verify-ssl ls)

    if [ $? -ne 0 ];
    then
            echo "$red Error while connecting to $1 server. Please check $default"
            ERROR="${ERROR} \n Storage Check Failed: Error while connecting to $1."
            exit 1;
    else
            echo "$green Connection to $1 endpoint established successfully $default"
    fi
}

  echo "Validating Storage connections"

  validate_storage_conn $1

  validate_storage_conn $1

  echo "Storage connections validation completed"

