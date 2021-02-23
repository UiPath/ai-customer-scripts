#!/bin/bash

function createNamespace() {
  ns=$1

  # verify that the namespace exists
  ns=`kubectl get namespace $1 --no-headers --output=go-template={{.metadata.name}} 2>/dev/null`
  if [ -z "${ns}" ]; then
    echo "Namespace (${1}) not found, creating namespace"
    kubectl create namespace "${1}"
  else echo "Namespace (${1})" exists, skipping namespace creation
  fi
}

function validate() {
  if [ $? -ne 0 ]; 
  then
      echo "$1 deployment failed in namespace $2. Exiting !!!"
      exit 1
  else
      echo "$1 deployment in namespace $2 successful !!!"    
  fi
}

function validateAndPrint() {
  if [ $? -ne 0 ]; 
  then
      echo "$1 !!! Exiting !!!"
      exit 1   
  fi
}

function validateIPAddressRange() {
  local  ip=$1
  local  stat=1

  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,3}$ ]];
  then
      OIFS=$IFS
      IFS='.'
      ip=($ip)
      IFS=$OIFS
      part3=$(cut -d'/' -f1 <<< ${ip[3]})
      part4=$(cut -d'/' -f2 <<< ${ip[3]})
      [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
          && ${ip[2]} -le 255 && $part3 -le 255 && $part4 -le 255 ]]

      if [ $? = 1 ];
      then
          echo "not valid"
          exit 1
      fi
  else
      echo "$ip is not a valid IP"
      exit 1
  fi
}

function validateCertificateStatus() {
  counter=1
  cert_creation_status="False"

  while [[ $counter -le 20 && "$cert_creation_status" = "False" ]];
  do
    cert_creation_status=$(kubectl -n istio-system get certificate istio-ingressgateway-certs -o jsonpath='{.status.conditions[0].status}')
    if [ "$cert_creation_status" = "True" ]; then
      echo "Certificate is in ready status"
    else
      echo "Certificate not in ready status yet, sleep for 10 more seconds"
      echo "${counter} iteration check for certificate ready status"
      sleep 10
    fi
    counter=$((counter+1))
  done

  if [ $counter -gt 20 ];
  then
    echo "Certification creation failed !! Exiting "
    cert_failure_reason=$(kubectl -n istio-system get certificaterequest -o json | jq -r '.items[0].status.conditions[0].message')
    echo "Cert Creation request failed with error: $cert_failure_reason"
    cert_failure_reason=$(kubectl -n istio-system get order -o json | jq -r '.items[0].status.reason')
    echo "Cert Order request failed with error: $cert_failure_reason"
    exit 1
  fi
}

function validateStorageClass() {
  counter=1
  storage_class_found="False"

  while [[ $counter -le 20 && "$storage_class_found" = "False" ]];
  do
    storage_counter=$(kubectl get storageclass | grep default | wc -l)
    if [ ! $storage_counter -gt 0 ]; then
      echo "Default storageClass not yet created, sleep for 10 more seconds"
      echo "${counter} iteration check for storageClass creation status"
      sleep 10
    else
      storage_class_found="True"
    fi
    counter=$((counter+1))
  done

  if [ $counter -gt 20 ];
  then
    echo "For the KotsAdmin installation to work default storageClass has to be set. Exiting !!"
    exit 1
  fi
}

function validateEmptyParam() {
    if [ ! -z "$1" ]
    then
      echo "$1 is empty..$2 Exiting !!"
      exit 1
    fi
}

#StartTime
start=`date +%s`
echo $@ >> consoleOutput.txt

#download artifacts and unzip
wget https://github.com/UiPath/ai-customer-scripts/raw/database_type_single/platform/aks/aks-arm.zip
unzip aks-arm.zip
cd aks-arm

  #install kubectl  
curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"  
chmod +x ./kubectl  
mv ./kubectl /usr/local/bin/kubectl

vnet_flag=false
orchestrator_rg=false
peering_flag=false
expose_kots=false
zonal_cluster=false
database_type=single

while getopts ":g:k:d:c:s:p:x:z:m:O:V:P" opt; do  
  case $opt in
    g)
      echo "Worker Resource Group is $OPTARG"
      RESOURCEGROUP=$OPTARG
      ;; 
    k)
      echo "AKS Cluster name is $OPTARG"
      AKSCLUSTERNAME=$OPTARG
      ;;  
    d)  
      echo "DNS Prefix is $OPTARG"  
      DNSNAME=$OPTARG
      ;;
    c)  
      echo "KOTS channel is $OPTARG"  
      KOTS_CHANNEL=$OPTARG
      ;;
    s)  
      #echo "SQL user $OPTARG"  
      SQL_USERNAME=$OPTARG
      ;;
    p)  
      #echo "SQL Password is $OPTARG"  
      SQL_PASSWORD=$OPTARG
      ;;
    x)
      echo "Expose Kots via Public IP/LoadBalancer is $OPTARG" | tee -a consoleOutputs.txt
      if [[ "$OPTARG" == "yes" ]] ;
        then      
      	expose_kots=true;
      fi
      ;;
    z)
      echo "Zonal Cluster $OPTARG"
      zonal_cluster=$OPTARG
      ;;
    m)
      echo "Database type is $OPTARG"
      database_type=$OPTARG
      ;;
    O)  
      echo "VNET Peering Target Resource Group is $OPTARG"  
      ORCH_RG=$OPTARG
      orchestrator_rg=true
      ;; 
    V)  
      echo "VNET Peering target name is $OPTARG"  
      ORCH_VNET=$OPTARG
      vnet_flag=true
      ;;  
    P)  
      echo "VNET Peering is enabled"  
      peering_flag=true
      P_PARAM="peer is enabled"
      ;;   
    \?)  
      echo "Invalid option: -"$OPTARG"" >&2
      echo "Plz remove the options that are not valid"
      exit 1
      ;;     
  esac  
done

#install helm

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 
chmod 700 get_helm.sh 
./get_helm.sh

#Defaulting namespace to aifabric
NAMESPACE="aifabric"

if  ! $orchestrator_rg & ! $vnet_flag && $peering_flag
then
    echo "The -O and -V flags have to be filled in order to configure peering, -O is Orchestrator Resource Group and -V is the Orchestrator Virtual Network to peer aifabric with" >&2
    exit 1
fi

if ((OPTIND == 1))
then
    echo "No options specified"
fi

#Validate Inputs
#Validate Resource Group
if [[ ! -n $RESOURCEGROUP ]]; then echo "ResourceGroup(-g option) cannot be empty. Exiting !!";exit 1;  fi
#Validate Domain Name
if [[ ! -n $DNSNAME ]]; then echo "DNS/Domain Name Prefix(-d option) cannot be empty. Exiting !!";exit 1;  fi
#Validate AKS Cluster Name
if [[ ! -n $AKSCLUSTERNAME ]]; then echo "AKS Cluster Name (-k option) cannot be empty. Exiting !!";exit 1;  fi
#Validate Kots Channel Name
if [[ ! -n $KOTS_CHANNEL ]]; then echo "Kots Channel Name (-c option) cannot be empty. Exiting !!";exit 1;  fi
#Validate kotsAdmin flag
if [[ ! -n $expose_kots ]]; then echo "Expose KotsAdmin flag (-e option) cannot be empty. Exiting !!";exit 1;  fi
#Validate Zonal Cluster
if [[ ! -n $zonal_cluster ]]; then echo "Zonal Cluster (-z option) cannot be empty. Exiting !!";exit 1;  fi

location=$(az group show --name $RESOURCEGROUP | jq -r '.location')


#Fetch AKS Version Dynamically
#current_aks_version=$(az aks get-versions -l westeurope | jq -r '.orchestrators[].orchestratorVersion' | grep 1.16 | tail -1)
#If 1.16 is deprecated then fallback to AKS version which is set as default
#if [ -z "$current_aks_version" ]
#then
#  current_aks_version=$(az aks get-versions -l $location | jq -r '.orchestrators[] | select(.default == true) | .orchestratorVersion')
#fi

#sed "s/AKS_VERSION/$current_aks_version/g" azuredeploy.parameters.json > azuredeploy.parameters-temp.json
#PARAMETERS_FILE="azuredeploy.parameters-temp.json"
#extracted_tags=$(jq -r '.parameters.resourceTags.value' $PARAMETERS_FILE)

#if [[ ! -n $extracted_tags || "$extracted_tags" == "{}" || "$extracted_tags" == "null" ]];
#then
#  echo "Resource tags cant be empty under $PARAMETERS_FILE file. Exiting !!"
#  exit 1
#fi

#Check if tags are valid
#empty_key_vals=$(jq -r '.parameters.resourceTags.value | to_entries[] | select(.value == null or .key == null or .value == "" or .key == "")' $PARAMETERS_FILE)

#If there exists keys/values which are null or empty
#if [ ! -z "$empty_key_vals" ]
#then
#  echo "Tags specified under $PARAMETERS_FILE are not of valid format. Exiting !!"
#  exit 1
#fi

#db_creation_option=$(jq -r '.parameters.sqlNewOrExisting.value' $PARAMETERS_FILE)

#if [ "${db_creation_option}" = "new" ];
#then
#  if [[ ! -n "$SQL_PASSWORD" ]]; then echo "SQL Password(-p option) has to be provided";exit 1; fi
#  if [[ ! -n "$SQL_USERNAME" ]]; then echo "SQL UserName(-s option) has to be provided";exit 1; fi
#fi

#Current SignIn User
sign_in_user=$(az ad signed-in-user show | jq -r '.mail')
echo "Current signIn user: $sign_in_user" | tee -a consoleOutputs.txt

echo "Permissions that exist on this Resource Group:" | tee -a consoleOutputs.txt
#Console, single command distorts the output
az role assignment list --resource-group $RESOURCEGROUP --out table
#To File
az role assignment list --resource-group $RESOURCEGROUP --out table >> consoleOutputs.txt

#Set Subscription
SUBSCRIPTION_ID=$(az group show --name $RESOURCEGROUP | jq -r '.id' | cut -d'/' -f3)
az account set --subscription $SUBSCRIPTION_ID

#cpu_instance_type=$(jq -r '.parameters.agentPoolProfiles.value[0].nodeVmSize' $PARAMETERS_FILE)
#gpu_instance_type=$(jq -r '.parameters.agentPoolProfiles.value[1].nodeVmSize' $PARAMETERS_FILE)

if [ "${zonal_cluster}" = "true" ];
then
  cpu_node_availability=$(az vm list-skus --location $location  | jq -r --arg cpu_instance_type "$cpu_instance_type" '.[] | select(.name==$cpu_instance_type and .locationInfo[0].zones[0] != null) | .name')
  gpu_node_availability=$(az vm list-skus --location $location  | jq -r --arg gpu_instance_type "$gpu_instance_type" '.[] | select(.name==$gpu_instance_type and .locationInfo[0].zones[0] != null) | .name')
else
  cpu_node_availability=$(az vm list-skus --location $location  | jq -r --arg cpu_instance_type "$cpu_instance_type" '.[] | select(.name==$cpu_instance_type) | .name')
  gpu_node_availability=$(az vm list-skus --location $location  | jq -r --arg gpu_instance_type "$gpu_instance_type" '.[] | select(.name==$gpu_instance_type) | .name')
fi

echo "you can run the below command to fetch list of instance types available in the current location"
echo "az vm list-skus --location $location --output table"
#Check for CPU and GPU Node availability under the location where resource group is created
#if [[ ! -n "$cpu_node_availability" ]]; then echo "CPU Node type: $cpu_instance_type that has been choosen is not enabled for your subscription for location $location";exit 1; fi
#if [[ ! -n "$gpu_node_availability" ]]; then echo "GPU Node type: $gpu_instance_type that has been choosen is not enabled for your subscription for location $location";exit 1; fi


if [ "$peering_flag" = true ] ;
then
#currentVnetAddressSpace - now comes from the maintemplate script as ENVVAR
#  currentVnetAddressSpace=$(jq -r '.parameters.vnetAddressPrefix.value' $PARAMETERS_FILE)
  targetVnetAddressSpace=$(az network vnet show -g $ORCH_RG -n $ORCH_VNET | jq -r '.addressSpace.addressPrefixes[0]')

  validateIPAddressRange $currentVnetAddressSpace
  validateIPAddressRange $targetVnetAddressSpace

#currentSubnetPrefix - now comes from the maintemplate script as ENVVAR
#  currentSubnetPrefix=$(jq -r '.parameters.subnetPrefix.value' $PARAMETERS_FILE)
  targetSubnetPrefix=$(az network vnet show -g $ORCH_RG -n $ORCH_VNET | jq -r '.subnets[0].addressPrefix')

  echo "CurrentVnetAddressSpace: $currentVnetAddressSpace"
  echo "TargetVnetAddressSpace: $targetVnetAddressSpace"
  echo "CurrentSubnetPrefix: $currentSubnetPrefix"
  echo "TargetSubnetPrefix: $targetSubnetPrefix"

  if [ "$currentVnetAddressSpace" = "$targetVnetAddressSpace" ];
  then
    echo "Vnet Peering is not possible, the CurrentVnetAddressSpace $currentVnetAddressSpace overlaps with the targetVnetAddressSpace i.e $targetVnetAddressSpace"
    echo "Please make sure that the AddressSpaces of the vnets are not overlapped, more info: https://docs.microsoft.com/en-us/azure/virtual-network/create-peering-different-subscriptions"
    exit 1
  fi

  vnet_peering_name=orchestrator-aifabric
  echo "-------------------------------------**********************************************************------------------------"
  echo "If you see an message like orchestrator-aifabric vnet not found, ignore this message, its just a check to see if peering already exists"
  echo "-------------------------------------**********************************************************------------------------"
  peering_state=$(az network vnet peering show --name $vnet_peering_name --resource-group $ORCH_RG --vnet-name $ORCH_VNET --query peeringState | sed 's/"//g')

  if [ "$peering_state" = "Disconnected" ]
  then
    echo "Vnet Peering from this resource group already exists and peering is in Disconnected state, this usually happens when source Vnet is deleted"
    echo "Please delete Vnet peering of name $vnet_peering_name from the target Vnet manually TargetResourceGroup->Vnet->VnetPeering->Delete peering with name $vnet_peering_name"
    exit 1
  fi
  
  if [ "$peering_state" = "Connected" ];
  then
    echo "Vnet Peering from this resource group already exists and peering is in Connected state, skipping peering step"
  fi
fi

# Not required right now, as we are assuming that a resource group should already exist befor kickstarting the Infra provisioning job
#az group create -n $RESOURCEGROUP -l $LOCATION --tags "Project=Ai Fabric" "Owner=rajiv.chodisetti@uipath.com"
#validateAndPrint "Resource Group creation failed"

export WORKER_RESOURECEGROUP="${AKSCLUSTERNAME}-worker"

#using # instead of / , comma is also part of placeholder

if [ "${zonal_cluster}" = "true" ];
then
  sed "s#,AVAIL_ZONES_PLACEHOLDER#,\"availabilityZones\": \"[parameters\('agentPoolProfiles'\)[copyIndex\('agentPoolProfiles'\)].availabilityZones]\"#g" azuredeploy.json > azuredeploy-temp.json
else
  sed "s#,AVAIL_ZONES_PLACEHOLDER##g" azuredeploy.json > azuredeploy-temp.json
fi

#create gpu node pool and apply taints on resource group
#commented code as we are not creating taints & GPU Node pool using arm
if [ ]; then ##
az aks nodepool add --name gpunodepool \
    --enable-cluster-autoscaler \
    --resource-group ${RESOURCEGROUP} \
    --cluster-name ${AKSCLUSTERNAME} \
    --node-vm-size Standard_NC6s_v2 \
    --node-taints nvidia.com/gpu=present:NoSchedule \
    --labels accelerator=nvidia \
    --node-count 1 \
    --min-count 1 \
    --max-count 5
    --zones {1,2,3}
fi; ##

case $peering_flag in
    true )
        # AiFabric VNET ID
        vNet1Id=$(az network vnet show \
          --resource-group $RESOURCEGROUP \
          --name $vnetname \
          --query id --out tsv)

        # Orchestrator VNET ID
        vNet2Id=$(az network vnet show \
          --resource-group $ORCH_RG \
          --name $ORCH_VNET \
          --query id \
          --out tsv)

        az network vnet peering create \
          --name aifabric-orchestrator \
          --resource-group $RESOURCEGROUP \
          --vnet-name $vnetname \
          --remote-vnet $vNet2Id \
          --allow-vnet-access

        az network vnet peering create \
          --name orchestrator-aifabric \
          --resource-group $ORCH_RG \
          --vnet-name $ORCH_VNET \
          --remote-vnet $vNet1Id \
          --allow-vnet-access

        az network vnet peering show \
          --name aifabric-orchestrator \
          --resource-group $RESOURCEGROUP \
          --vnet-name $vnetname \
          --query peeringState
        ;;
    false )
        echo "Non-Peering deployment" ;;
esac

#get credentials aks

az aks get-credentials -g $RESOURCEGROUP -n $AKSCLUSTERNAME
validateAndPrint "Unable to fetch credentials"

#create necessary namespace/project
createNamespace "aifabric"
validateAndPrint "aifabric namespace creation failed"
createNamespace "istio-system"
validateAndPrint "istio-system namespace creation failed"
createNamespace "cert-manager"
validateAndPrint "cert-manager namespace creation failed"

if [ "${db_creation_option}" = "new" ];
then
  if [ "${database_type}" = "single" ];
  then
    kubectl delete job create-db-schemas
    echo "helm upgrade --force --wait --install mssql-db-tools mssql-db-tools --set dataSource.url.host=${sqlhost} --set dataSource.username=${SQL_USERNAME} --set dataSource.password=${SQL_PASSWORD} -f mssql-db-tools/values.yaml"
    helm upgrade --debug --force --wait --install mssql-db-tools mssql-db-tools --set dataSource.url.host=${sqlhost} --set dataSource.username=${SQL_USERNAME} --set dataSource.password=${SQL_PASSWORD} -f mssql-db-tools/values.yaml
    sleep 10
    kubectl logs $(kubectl get pods | grep create-db-schemas-nwpxg | cut -d ' ' -f1)
  fi
fi

#taint
#Tolerations has to be added to gpu deployments explicitly https://github.com/Azure/AKS/issues/1449
#kubectl taint nodes -l accelerator=nvidia nvidia.com/gpu=present:NoSchedule --overwrite

#Check for the Existence of default storageClass. For the KotsAdmin install to work, default storageClass has to be set to some valid storage provider
storage_class=$(kubectl get storageclass | grep default)
if [ ! -z "$storage_class" ]
then
  kubectl delete storageclass default
fi
#create topology aware default storageClass
kubectl apply -f default-storageclass.yaml
#validating Existence of default storageClass
validateStorageClass


#https://kubernetes.io/blog/2018/10/11/topology-aware-volume-provisioning-in-kubernetes/ 
kubectl apply -f topology-aware-volumes.yaml
validateAndPrint "storage class creation failed"


#install nvidia daemonset for GPU
createNamespace "gpu-resources"
kubectl apply -f nvidia-device-plugin-ds.yaml

# generate token for oob-installer
kubectl create -n $NAMESPACE serviceaccount post-provision
kubectl create -n $NAMESPACE clusterrolebinding post-provision-admin --clusterrole=cluster-admin --serviceaccount=$NAMESPACE:post-provision

sleep 2
SECRET_NAME=$(kubectl get -n default secret | grep post-provision-token | cut -d' ' -f1 | head -n 1)
echo "OOB installer token name is ${SECRET_NAME}"

# generate token for ai-deployer
kubectl -n kube-system create serviceaccount deployer
kubectl -n kube-system create clusterrolebinding deployer-admin --clusterrole=cluster-admin --serviceaccount=kube-system:deployer
sleep 2
SECRET_NAME=$(kubectl get -n kube-system secret | grep deployer-token | cut -d' ' -f1 | head -n 1)
echo "Deployer secret name is ${SECRET_NAME}"


# generate token for ai-deployer
kubectl -n $NAMESPACE create serviceaccount provision
kubectl -n $NAMESPACE create clusterrolebinding provision --clusterrole=cluster-admin --serviceaccount=$NAMESPACE:provision

#add base64 -w option by installing coreutils 
apk add --update coreutils
# instantiate Secrets
#AIBASE64=$(echo -n $applicationInsightsKey | base64 -w 0)
storageAccountConnectionString1="DefaultEndpointsProtocol=https;AccountName=${storageAccountName1};AccountKey=${storageAccountKey1};EndpointSuffix=core.windows.net"
storageAccountConnectionString2="DefaultEndpointsProtocol=https;AccountName=${storageAccountName2};AccountKey=${storageAccountKey2};EndpointSuffix=core.windows.net"
storageAccountConnectionString3="DefaultEndpointsProtocol=https;AccountName=${storageAccountName3};AccountKey=${storageAccountKey3};EndpointSuffix=core.windows.net"
SABASE64_KEY1=$(echo -n $storageAccountConnectionString1 | base64 -w 0 )
SABASE64_KEY2=$(echo -n $storageAccountConnectionString2 | base64 -w 0 )
SABASE64_KEY3=$(echo -n $storageAccountConnectionString3 | base64 -w 0 )

CLUSTER_CREDENTIALS="$(kubectl get -n kube-system secret $SECRET_NAME -o jsonpath='{.data.token}')"
SQLPWBASE64=$(echo -n $SQL_PASSWORD| base64)
SQLUSRBASE64=$(echo -n $SQL_USERNAME| base64)

REGISTRY_JSON_PAYLOAD='{"username": "'$acrName'","password": "'$acrLoginKey'","registryUrl": "'$acrLoginServer'","email": "aifabric@uipath.com"}'
REGISTRYBASE64=$(echo -n $REGISTRY_JSON_PAYLOAD | base64 -w0)
REGISTRY_PASSWORD=$acrLoginKey

# instantiate the secrets in the aifabric namespace
if [ ! -z "$applicationInsightsKey" ]
then
  kubectl --namespace $NAMESPACE create secret generic insights-credentials --from-literal=APP_INSIGHTS_CREDENTIALS=$applicationInsightsKey
else
  echo "Not able to fetch appInsights Credentials. Exiting !!"
  exit 1
fi

if [ ! -z "$SABASE64_KEY1" ]
then
  kubectl --namespace $NAMESPACE create secret generic storage-credentials --from-literal=STORAGE_CREDENTIALS="$SABASE64_KEY1" --from-literal=STORAGE_TRAINING_CREDENTIALS="$SABASE64_KEY2" --from-literal=STORAGE_TRAINING_ARTIFACTS_CREDENTIALS="$SABASE64_KEY3"
else
  echo "Not able to fetch storage Credentials. Exiting !!"
  exit 1
fi

if [ ! -z "$CLUSTER_CREDENTIALS" ]
then
  kubectl --namespace $NAMESPACE create secret generic cluster-credentials --from-literal=CLUSTER_CREDENTIALS=$CLUSTER_CREDENTIALS --from-literal=KUBE_API_SERVER_ADDRESS="$controlPlaneFQDN"
else
  echo "Not able to fetch cluster-credentials. Exiting !!"
  exit 1
fi

if [ "${db_creation_option}" = "new" ];
then
  if [ ! -z "$SQL_PASSWORD" ]
  then
    kubectl --namespace $NAMESPACE create secret generic db-credentials --from-literal=DATASOURCE_PASSWORD=$SQL_PASSWORD --from-literal=DATABASE_USER=$SQL_USERNAME --from-literal=DATABASE_HOST=$sqlhost
  else
    echo "Not able to fetch db-credentials. Exiting !!"
    exit 1
  fi
fi


# instantiate registry configmap
echo "create Registry confimap"

if [ ! -z "$REGISTRYBASE64" ]
then
cat << EOF | kubectl apply -f -
apiVersion: v1
data:
  REGISTRY_CREDENTIALS: $REGISTRYBASE64
  REGISTRY_PASSWORD: $REGISTRY_PASSWORD
  REGISTRY_HOST: $acrLoginServer
  REGISTRY_USERNAME: $acrName
kind: ConfigMap
metadata:
  name: registry-config
  namespace: $NAMESPACE
EOF
else
  echo "Not able to fetch registry-credentials. Exiting !!"
  exit 1
fi

# install istio

echo "Create Grafana secret"

GRAFANA_USERNAME="$(echo -n "grafana" | base64)"
GRAFANA_PASSPHRASE="$(openssl rand -base64 10)"

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: grafana
  namespace: istio-system
  labels:
    app: grafana
type: Opaque
data:
  username: $GRAFANA_USERNAME
  passphrase: $GRAFANA_PASSPHRASE
EOF

echo "Starting istio setup"

#download istio
ISTIO_VERSION=1.5.8
curl -sL "https://github.com/istio/istio/releases/download/$ISTIO_VERSION/istio-$ISTIO_VERSION-linux.tar.gz" | tar xz
cd istio-$ISTIO_VERSION
chmod +x ./bin/istioctl


bin/istioctl manifest apply -f ../istio.aifabric.aks.yaml --logtostderr \
--set values.gateways.istio-ingressgateway.sds.enabled=true \
--set values.gateways.istio-ingressgateway.externalTrafficPolicy=Local \
--set values.global.k8sIngress.enabled=true \
--set values.global.k8sIngress.enableHttps=true \
--set values.global.k8sIngress.gatewayName=ingressgateway \
--set values.global.proxy.resources.limits.cpu=100m \
--set values.global.proxy.resources.limits.memory=128Mi \
--set values.sidecarInjectorWebhook.rewriteAppHTTPProbe=true \
--set meshConfig.accessLogFile="/dev/stdout" \
--set values.prometheus.retention=30d

cd .. 
echo "Istio installation successfully completed"

echo "Starting Istio setup process"

#wait for deployment to be complete
#kubectl -n istio-system wait --for=condition=available deployment --all --timeout=600s

#Wait for all istio components to get ready
kubectl -n istio-system rollout status deployment/istiod --watch=true
validate istiod istio-system

#Patch auto generated gateway
echo "Patch Istio Gateway"
kubectl -n istio-system \
  patch gateway istio-autogenerated-k8s-ingress --type=json \
  -p='[{"op": "replace", "path": "/spec/servers/1/tls", "value": {"credentialName": "istio-ingressgateway-certs", "mode": "SIMPLE", "privateKey": "sds", "serverCertificate": "sds"}}]'

#wait for istio-ingressgateway pods to come up
kubectl -n istio-system rollout status deployment/istio-ingressgateway --watch=true
validate istio-ingressgateway istio-system

#wait for prometheus to come up
kubectl -n istio-system rollout status deployment/prometheus --watch=true
validate prometheus istio-system

#wait for grafana to come up
kubectl -n istio-system rollout status deployment/grafana --watch=true
validate grafana istio-system

#Wait for the LB IP Allocation by underlying cloud provider
sleep 45
INGRESS_HOST=$(kubectl -n istio-system get svc istio-ingressgateway -o json | jq -r ".status.loadBalancer.ingress[0].ip")

#echo "http://$(kubectl describe service kotsadm --namespace $NAMESPACE | grep 'LoadBalancer Ingress' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'):3000"

echo "Start assigning domain name to IP $INGRESS_HOST..."

IP_NAME="$(az network public-ip list --query "[?ipAddress=='$INGRESS_HOST']|[0].name" | sed 's/"//g')"

az network public-ip update --resource-group $WORKER_RESOURECEGROUP --name $IP_NAME --dns-name $DNSNAME >/dev/null

INGRESS_DOMAIN="$(az network public-ip list --query "[?ipAddress=='$INGRESS_HOST']|[0].dnsSettings.fqdn" | sed 's/"//g')"
validateAndPrint "Not able to fetch ingress domain"

if [[ ! -n $INGRESS_DOMAIN ]]; then echo "Error while fetching domain name, it might be a timing issue, Re-running the script should fix the same. Exiting !!";exit 1;  fi

echo "Istio Setup successfully completed"

# install Cert-Manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --version v0.15.1 --set installCRDs=true

#kubectl wait pod -l app=webhook -n cert-manager --for=condition=Ready --timeout=120s
# Check if all cert-manager components are up
kubectl -n cert-manager rollout status deployment/cert-manager-webhook --watch=true
validate cert-manager-webhook cert-manager
kubectl -n cert-manager rollout status deployment/cert-manager-cainjector --watch=true
validate cert-manager-cainjector cert-manager
kubectl -n cert-manager rollout status deployment/cert-manager --watch=true
validate cert-manager cert-manager

#Substitute domain name for the cert creation request
sed "s/{{INGRESS_DOMAIN}}/${INGRESS_DOMAIN}/g" cert-manager-crd/letsencrypt-istiocert.yaml > cert-manager-crd/letsencrypt-istiocert-temp.yaml

kubectl apply -f cert-manager-crd/letsencrypt-clusterissuer.yaml
validateAndPrint "Error creating clusterIssuer"
sleep 30
kubectl apply -f cert-manager-crd/letsencrypt-istiocert-temp.yaml
validateAndPrint "Error creating certificate"
sleep 10
#Validate Cert Creation Status
validateCertificateStatus

####--------------------------------------------- Start KOTS Installation ---------------------------------------------------#####
# install kots admin
KOTS_VERSION=v1.19.4
KOTSPW=$kotsAdminPassword   
if [ -z "$KOTSPW" ] 
  then  
    KOTSPW=$(openssl rand -hex 10)  
fi

curl -L -o kots_linux_amd64.tar.gz https://github.com/replicatedhq/kots/releases/download/$KOTS_VERSION/kots_linux_amd64.tar.gz
tar xzf kots_linux_amd64.tar.gz

#wget -O AzureUnstable.yaml ${URL}
echo $licenseField >> licenseFileEncoded.file
base64 -d licenseFileEncoded.file >> licenseFile.yaml
wget -O config.yaml https://raw.githubusercontent.com/UiPath/ai-customer-scripts/master/platform/aks-arm/config.yaml

#First time write to new file just to ensure source of truth is not being change
sed "s/JWT_TOKEN_VAR/${jwtToken}/g" config.yaml > config-temp.yaml
#Second edit onwards in-place edit 
sed -i "s/IDENTITY_ENDPOINT_VAR/${identityEndpoint}/g" config-temp.yaml
sed -i "s/ORCH_ENDPOINT_VAR/${orchestratorEndpoint}/g" config-temp.yaml
sed -i "s/INGRESS_ENDPOINT_VAR/${INGRESS_DOMAIN}/g" config-temp.yaml
sed -i "s/SQL_HOST_VAR/${sqlhost}/g" config-temp.yaml
sed -i "s/SQL_USER_VAR/${SQL_USERNAME}/g" config-temp.yaml
#Using # as separator for sed, so passwords cant have hash, we have to sacrifice one character, i have chosen hash 
sed -i "s#SQL_PASS_VAR#${SQL_PASSWORD}#g" config-temp.yaml
sed -i "s#DATABASE_TYPE#${database_type}#g" config-temp.yaml

./kots install app "$KOTS_CHANNEL" --license-file ./licenseFile.yaml --config-values ./config-temp.yaml --shared-password $KOTSPW --namespace $NAMESPACE --port-forward=false

#reset kots password
echo $KOTSPW | ./kots reset-password -n $NAMESPACE

#Check kotsAdmin Deploy Status
kubectl -n $NAMESPACE rollout status deployment/kotsadm --watch=true
validate kotsadm aifabric

kubectl -n $NAMESPACE rollout status deployment/kotsadm-operator --watch=true
validate kotsadm-operator aifabric

if [ "${expose_kots}" = true ];
then
  #patch kots to be a loadbalancer service
  echo "Exposing KOTS via PublicIP/LoadBalancer (-E switch) is Enabled"
  kubectl patch service kotsadm -p '{"spec":{"type":"LoadBalancer"}}' --namespace $NAMESPACE
fi
####--------------------------------------------- End KOTS Installation ---------------------------------------------------#####

########-------------------------------------------------- Start Install Velero -----------------------------------------########
#Download Velero 
wget https://github.com/vmware-tanzu/velero/releases/download/v1.4.2/velero-v1.4.2-linux-amd64.tar.gz
tar -xvf velero-v1.4.2-linux-amd64.tar.gz
cd velero-v1.4.2-linux-amd64/

#Prepare Variables
AZURE_STORAGE_ACCOUNT_ID=${storageAccountName1}
AZURE_STORAGE_ACCOUNT_ACCESS_KEY=${storageAccountKey1}
AZURE_BACKUP_RESOURCE_GROUP=$RESOURCEGROUP
BLOB_CONTAINER=velero
az storage container create -n $BLOB_CONTAINER --public-access off --account-name $AZURE_STORAGE_ACCOUNT_ID

cat << EOF  > ./credentials-velero
AZURE_STORAGE_ACCOUNT_ACCESS_KEY=${AZURE_STORAGE_ACCOUNT_ACCESS_KEY}
AZURE_CLOUD_NAME=AzurePublicCloud
EOF

#Install Velero
./velero install \
    --provider azure \
    --plugins velero/velero-plugin-for-microsoft-azure:v1.1.0 \
    --bucket $BLOB_CONTAINER \
    --secret-file ./credentials-velero \
    --backup-location-config resourceGroup=$AZURE_BACKUP_RESOURCE_GROUP,storageAccount=$AZURE_STORAGE_ACCOUNT_ID,storageAccountKeyEnvVar=AZURE_STORAGE_ACCOUNT_ACCESS_KEY \
    --use-volume-snapshots=false
	
#Velero Create First Backup	
./velero backup create firstbackup
	
#Velero Schedule Backups 	
./velero create schedule aifabricvelerobackupschedule --schedule="@every 24h"

#Cleanup credentials
rm ./credentials-velero

######## -------------------------------------------------- End Install Velero -------------------------------------------########

echo "Preparing outputs for upload in blob storage account $storageAccountName1 / deploymentlogs"

echo "----ARM Outputs----" >> consoleOutputs.txt
  
for key in ${constants}; do
 echo $key >> consoleOutputs.txt
done

echo $OUTPUT | jq '.properties.outputs' >> outputs.json

echo "----Console Outputs----" >> consoleOutputs.txt


#DB Details
if [ "${db_creation_option}" = "new" ];
then
  echo "DATABASE_HOST is: $sqlhost" | tee -a consoleOutputs.txt
  echo "DATABASE_USER is: $SQL_USERNAME" | tee -a consoleOutputs.txt
  echo "DATABASE_PASSWORD is: $SQL_PASSWORD" | tee -a consoleOutputs.txt
else
  echo "DB Creation is Disabled"  | tee -a consoleOutputs.txt
fi

#Ingress Details
echo "INGRESS_HOST is: $INGRESS_HOST" | tee -a consoleOutputs.txt
echo "INGRESS_DOMAIN is: $INGRESS_DOMAIN" | tee -a consoleOutputs.txt


#extract kotsAdmin LB IP
if [ "${expose_kots}" = true ];
then
  #patch kots to be a loadbalancer service
  KOTS_HOST=$(kubectl -n aifabric get svc kotsadm -o json | jq -r ".status.loadBalancer.ingress[0].ip")
  echo "Kotsadmin Portal IP is: http://${KOTS_HOST}:3000" | tee -a consoleOutputs.txt
else
  echo "Exposing KOTS via PublicIP/LoadBalancer is disabled (i.e -e option set to false)" | tee -a consoleOutputs.txt
  echo "To enable JIT access to access KOTSAdmin console, set the appropriate kubernetes context on your local machine, how to set context: portal.azure -> your_aks_cluster -> Connect -> first 2 commands" | tee -a consoleOutputs.txt
  echo "To access the KOTSAdmin Console via JIT, run: kubectl -n aifabric port-forward service/kotsadm 8800:3000" | tee -a consoleOutputs.txt
fi

echo "Kotsadmin portal password is: $KOTSPW" | tee -a consoleOutputs.txt
echo "To reset kots password run this command by setting appropriate kubernetes context, kubectl kots reset-password -n aifabric"

echo "Uploading data to $storageAccountName1 / deploymentlogs"
expiry=`date -u -d "30 minutes" '+%Y-%m-%dT%H:%MZ'`
run_date=`date '+%Y-%m-%d-%H-%M'`

#Target FileNames
targetFileNameConsoleOutput=consoleOutputs_$run_date.txt
targetFileNameJsonOutput=outputs_$run_date.json

#Upload console logs to azure cloud storage
sastoken=`az storage container generate-sas --account-key $storageAccountKey1 --account-name $storageAccountName1 -n deploymentlogs --https-only --permissions dlrw --expiry $expiry -o tsv`
az storage blob upload -n $targetFileNameConsoleOutput -c deploymentlogs -f consoleOutputs.txt --sas-token $sastoken --account-name $storageAccountName1
az storage blob upload -n $targetFileNameJsonOutput -c deploymentlogs -f outputs.json --sas-token $sastoken --account-name $storageAccountName1


#deleting this https gw as the kots admin provisioning job will add an other customer https gateway
#and having 2 https gateways will result in 404
kubectl -n istio-system delete gateway istio-autogenerated-k8s-ingress

echo "Infrastructure Installation finished"

#RunStats
end=`date +%s`
runtime=$((end-start))
hours=$((runtime / 3600)); minutes=$(( (runtime % 3600) / 60 )); seconds=$(( (runtime % 3600) % 60 )); 
echo "Infrastructure Provisioning Runtime: $hours:$minutes:$seconds (hh:mm:ss)" 