#!/bin/bash

: '
This scipt provides methods to fetch access token and register and de-register clients from identity server
The following arguments are to be set by calling script so that they are available to is.sh
# $1 - identityServerEndPoint: End point where identity server is hosted
# $2 - hostTenantName: Host Tenant name registered in identity server
# $3 - hostTenantIdOrEmailId: Host tenant id or email Id
# $4 - hostTenantPassword: Host tenant password
[Script Version -> 21.4]
'

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
default=$(tput sgr0)

# Fetch admin token from identity server end point using host tenant
function internal_fetch_identity_server_token_to_register_client() {
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
    echo "$(date) $red Failed to generate token to register client ... Exiting $default"
    exit 1
  fi
}

# Fetch access token to call backens server
function internal_fetch_identity_server_access_token() {
  echo "$(date) Getting access token for client $IS_AIFABRIC_CLIENT_NAME from $IDENTITY_SERVER_ENDPOINT"

  readonly access_token_response=$(
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

  export ACCESS_TOKEN=$(echo "$access_token_response" | jq -r 'select(.access_token != null) | .access_token')

  if [ -z "$ACCESS_TOKEN" ]; then
    echo "$(date) $red Failed to extract access token ... Exiting $default"
    deregister_client
    exit 1
  fi

  echo "$(date) Successfully fetched access token to call backend server "
}

# De-register clients, all values needed for it to work would be set already by calling register_client_and_fetch_access_token
function deregister_client() {
  echo "$default $(date) Deregistering client from $IDENTITY_SERVER_ENDPOINT with name $IS_AIFABRIC_CLIENT_NAME"
  curl -k -i --silent --fail --show-error -X DELETE "https://${IDENTITY_SERVER_ENDPOINT}/identity/api/Client/$IS_AIFABRIC_CLIENT_ID" -H "Authorization: Bearer ${CLIENT_INSTALLTION_TOKEN}"
}

# Register client and fetch Access token
function register_client_and_fetch_access_token() {

  export IS_AIFABRIC_CLIENT_ID="aifabric-"$(openssl rand -hex 10)
  export IS_AIFABRIC_CLIENT_SECRET=$(openssl rand -hex 32)
  export IS_AIFABRIC_CLIENT_NAME="aifabric-"$(openssl rand -hex 10)

  # Fetch admin token
  internal_fetch_identity_server_token_to_register_client

  # Register client
  echo "$(date) Registering client by name $IS_AIFABRIC_CLIENT_NAME with client id $IS_AIFABRIC_CLIENT_ID"

  client_creation_response=$(curl -k --silent --fail --show-error --raw -X POST "https://${IDENTITY_SERVER_ENDPOINT}/identity/api/Client" -H "Connection: keep-alive" -H "accept: text/plain" -H "Authorization: Bearer ${CLIENT_INSTALLTION_TOKEN}" -H "Content-Type: application/json-patch+json" -H "Accept-Encoding: gzip, deflate, br" -H "Accept-Language: en-US,en;q=0.9" -d "{\"clientId\":\"${IS_AIFABRIC_CLIENT_ID}\",\"clientName\":\"${IS_AIFABRIC_CLIENT_NAME}\",\"clientSecrets\":[\"${IS_AIFABRIC_CLIENT_SECRET}\"],\"requireConsent\":false,\"requireClientSecret\": true,\"allowOfflineAccess\":true,\"alwaysSendClientClaims\":true,\"allowAccessTokensViaBrowser\":true,\"allowOfflineAccess\":true,\"alwaysIncludeUserClaimsInIdToken\":true,\"accessTokenLifetime\":${ACCESS_TOKEN_LIFE_TIME},\"identityTokenLifetime\":${ACCESS_TOKEN_LIFE_TIME},\"authorizationCodeLifetime\":${ACCESS_TOKEN_LIFE_TIME},\"absoluteRefreshTokenLifetime\":${ACCESS_TOKEN_LIFE_TIME},\"slidingRefreshTokenLifetime\":${ACCESS_TOKEN_LIFE_TIME},\"RequireRequestObject\":true,\"Claims\":true,\"AlwaysIncludeUserClaimsInIdToken\":true,\"allowedGrantTypes\":[\"client_credentials\",\"authorization_code\"],\"allowedResponseTypes\":[\"id_token\"],\"allowedScopes\":[\"openid\",\"profile\",\"email\",\"AiFabric\",\"IdentityServerApi\",\"Orchestrator\",\"OrchestratorApiUserAccess\"]}")

  if [ -z "$client_creation_response" ]; then
    echo "$(date) $red Failed to register client $IS_AIFABRIC_CLIENT_NAME with identity server $IDENTITY_SERVER_ENDPOINT ... Exiting $default"
    exit 1
  fi

  # Fetch access token authorize backend server call
  internal_fetch_identity_server_access_token
}

echo "$red Please source the script & call individual methods instead of calling the script directly $default"