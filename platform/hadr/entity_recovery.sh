get_token() {
        curl --location --request POST $1 \
        --silent \
        --header 'Content-Type: application/x-www-form-urlencoded' \
        --data-urlencode "client_id=$2" \
        --data-urlencode "client_secret=$3" \
        --data-urlencode 'grant_type=client_credentials' \
        --data-urlencode 'audience=$4'
}

wait() {
        local count=0
        local total=30
        local pstr="[=======================================================================]"

        while [ $count -lt $total ]; do
          sleep 1
          count=$(( $count + 1 ))
          pd=$(( $count * 73 / $total ))
          printf "\r%3d.%1d%% %.${pd}s" $(( $count * 100 / $total )) $(( ($count * 1000 / $total) % 10 )) $pstr
        done
		echo
}

help() {
   # Display Help
   echo
   echo "Syntax: scriptTemplate [-c|d|i|s|p|h]"
   echo "options:"
   echo "-c --clientId             Client Id of S2S"
   echo "-d --aifDomain            AIF Core services API Endpoint"
   echo "-i --identityServerUrl    S2S Identity server token URL"
   echo "-s --scope                Scope of Client Id"
   echo "-p --clientSecret         Client Secret of S2S"
   echo "-h --help                 Help menu"
   echo
}

null_check() {
        if [ -z "$2" ]
        then
                echo "$1 is empty. Exiting"
                exit 1
        fi
}

is_valid_token() {
        if [ "$2" = "null" ]
        then
                echo "$1 is invalid. Exiting"
                exit 1
        fi
}

post_call() {
        local url="$1"
        shift
        curl --silent  --request POST "$url" "$@"
}

recover_MLSkills() {
        echo
        echo "Start MLSkill recovery"
        local url="http://ai-deployer-deployment-svc.aifabric.svc.cluster.local/ai-deployer/v1/system/mlskills/recover"
        echo `post_call "$url" "$@"`
        wait
        echo "MLSkill recovery complete"
        echo
}

recover_PipelineRuns() {
        echo
        echo "Start Pipeline run recovery"
        local url="http://ai-trainer-deployment-svc.aifabric.svc.cluster.local/ai-trainer/v1/system/pipeline/recover"
        echo `post_call "$url" "$@"`
        wait
        echo "Pipeline run recovery complete"
        echo
}

recover_AppManager_DMSessions() {
        echo
        echo "Start Appmanager sessions recovery"
        local url="http://ai-appmanager-deployment-svc.aifabric.svc.cluster.local/ai-appmanager/v1/system/app/recover"
        echo `post_call "$url" "$@"`
        wait
        echo "Appmanager sessions recovery complete"
        echo
}

recover_Projects() {
        echo
        echo "Start Project recovery"
        local url="http://ai-pkgmanager-deployment-svc.aifabric.svc.cluster.local/ai-pkgmanager/v1/system/project/recover"
        echo `post_call "$url" "$@"`
        wait
        echo "Project recovery complete"
        echo
}

recover_Tenants() {
        echo
        echo "Start Tenant recovery"
        local url="http://ai-deployer-deployment-svc.aifabric.svc.cluster.local/ai-deployer/v1/system/tenant/recover"
        echo `post_call "$url" "$@"`
        wait
        echo "Tenant recovery complete"
        echo
}

recover_MLPackages() {
        echo
        echo "Start MLPackages recovery"
        local url="http://ai-pkgmanager-deployment-svc.aifabric.svc.cluster.local/ai-pkgmanager/v1/system/mlpackage/recover"
        echo `post_call "$url" "$@"`
        wait
        echo "MLPackages recovery complete"
        echo
}

if [ $# -eq 0 ]
  then
    help
    exit 1
fi


# Parse command line arguments
TEMP=`getopt -o c:i:s:p:h --long clientId:,identityServerUrl:,scope:,clientSecret:,help -- "$@"`
eval set -- "$TEMP"

while true ; do
    case "$1" in
        -c|--clientId)
            export CLIENT_ID=$2 ; shift 2 ;;
        -i|--identityServerUrl)
            export AUTHURL=$2 ; shift 2 ;;
        -s|--scope)
            SCOPE=$2 ; shift 2 ;;
        -p|--clientSecret)
            CLIENT_SECRET=$2 ; shift 2 ;;
        -h|--help)
            help ; exit 1 ;;
        --) shift ; break ;;
        *) echo "Invalid option" ; help ; exit 1 ;;
    esac
done

#  Check for null values
null_check 'AuthURL' $AUTHURL
null_check 'ClientId' $CLIENT_ID
null_check 'ClientSecret' $CLIENT_SECRET
null_check 'Scope' $SCOPE

#Get S2S Token
response=`get_token $AUTHURL $CLIENT_ID $CLIENT_SECRET $SCOPE`
token=`echo "$response" | jq -r '.access_token'`
null_check 'S2S Token' $token
is_valid_token 'S2S Token' $token
echo "S2S Token retrieved successfully"

# Start AIF Recovery API calls
echo "********************** Start AIFabric Entities Recovery **********************"

recover_AppManager_DMSessions --header "Authorization: Bearer $token"

recover_MLSkills --header "Authorization: Bearer $token"

recover_PipelineRuns --header "Authorization: Bearer $token"

recover_MLPackages --header "Authorization: Bearer $token"

recover_Projects --header "Authorization: Bearer $token"

recover_Tenants --header "Authorization: Bearer $token"

echo "********************** AIFabric Entities Recovery completed successfully *********************************"