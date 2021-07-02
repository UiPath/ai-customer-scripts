#!/bin/bash

registry_credentials=`kubectl get secret -n default registry-creds -o jsonpath='{.data.\.dockerconfigjson}'`
registry_host=`kubectl get service/registry -n kurl -o jsonpath='{.spec.clusterIP}'`
registry_username=`echo $registry_credentials | base64 -d | jq ".auths[""\"$registry_host\"""].username"`
registry_password=`echo $registry_credentials | base64 -d | jq ".auths[""\"$registry_host\"""].password"`
registry_username=`echo -n $registry_username | tr -d '"'`
registry_password=`echo -n $registry_password | tr -d '"'`

storage_internal_host=`kubectl -n rook-ceph get svc | grep rook-ceph-rgw-rook-ceph-store | awk '{print $3}'`

orchestrator_host="https://$5"
sleep 10
identity_host="$orchestrator_host/identity"

database_name="aifabric_$(echo $3 | sed -nr 's/.*_(.*)_.*/\1/p')"

toolbox_pod=$(kubectl -n rook-ceph get pod -l app=rook-ceph-tools -o jsonpath="{.items[0].metadata.name}")
user_created=$(kubectl -n rook-ceph exec -it $toolbox_pod -- sh -c 'radosgw-admin user create --uid=admin --display-name="admin user" --system')
sleep 30
user_data=$(kubectl -n rook-ceph exec -it $toolbox_pod -- sh -c 'radosgw-admin user info --uid=admin')
storage_access_key=$(eval echo $(echo $user_data | jq '.keys[0].access_key'))
storage_secret_key=$(eval echo $(echo $user_data | jq '.keys[0].secret_key'))

echo "VMip : $1  SQL host : $2  SQL Username : $3  SQL Password : $4  Local Registry host : $registry_host
      Storage Internal Host : $storage_internal_host  Orchestrator Host : $orchestrator_host  Identity Server Host : $identity_host
      Orchestrator cert : $6  Access Token : $7  Database Name : $database_name  Storage Access Key : $storage_access_key  Storage Secret Key : $storage_secret_key"
sleep 60

{
  echo "helm upgrade --force --wait --timeout 300s --install aicenter aicenter --namespace uipath \ "
  echo "        --set global.ingressHost="$1:31390" \                                               "
  echo "        --set global.policyGatewayName="istio-system/aicenter-gateway" \                    "
  echo "        --set global.dataSource.sqlHost="$2" \                                              "
  echo "        --set global.dataSource.databaseName="$database_name" \                             "
  echo "        --set global.dataSource.sqlUsername="$3" \                                          "
  echo "        --set global.dataSource.sqlPassword=`echo -n $4 | base64` \                         "
  echo "        --set global.registry.online="true" \                                               "
  echo "        --set global.registry.imagePullSecrets.name="aicenter-registry-secrets" \           "
  echo "        --set global.registry.repository_url="sfbrdevhelmweacr.azurecr.io" \                "
  echo "        --set global.registry.project_id="aicenter" \                                       "
  echo "        --set local.registry.host="$registry_host" \                                        "
  echo "        --set local.registry.user="$registry_username" \                                    "
  echo "        --set local.registry.password=`echo -n $registry_password | base64` \               "
  echo "        --set global.storage.accessKey=`echo -n $storage_access_key | base64` \             "
  echo "        --set global.storage.secretKey=`echo -n $storage_secret_key | base64` \             "
  echo "        --set global.storage.externalAccessScheme="https" \                                 "
  echo "        --set global.storage.externalHost="$1" \                                            "
  echo "        --set global.storage.externalPort="31443" \                                         "
  echo "        --set global.storage.internalAccessScheme="http" \                                  "
  echo "        --set global.storage.internalHost="$storage_internal_host" \                        "
  echo "        --set global.storage.internalPort="80" \                                            "
  echo "        --set global.orchSelfSignedCerts="true" \                                           "
  echo "        --set global.orchestratorUrl="$orchestrator_host/" \                                "
  echo "        --set global.identityServerUrl="$identity_host" \                                   "
  echo "        --set global.orchCert="$6" \                                                        "
  echo "        --set oobModel.enabled="false" \                                                    "
  echo "        --set provisionCephBucketJob.enabled="true" \                                       "
  echo "        --set registerISClientJob.enabled="true" \                                          "
  echo "        --set global.accessToken="$7" \                                                     "
  echo "        -f aicenter/values-ec.yaml                                                          "
} > helm_command.txt

helm upgrade --force --wait --timeout 300s --install aicenter aicenter --namespace uipath \
        --set global.ingressHost="$1:31390" \
        --set global.policyGatewayName="istio-system/aicenter-gateway" \
        --set global.dataSource.sqlHost="$2" \
        --set global.dataSource.databaseName="$database_name" \
        --set global.dataSource.sqlUsername="$3" \
        --set global.dataSource.sqlPassword=`echo -n $4 | base64` \
        --set global.registry.online="true" \
        --set global.registry.imagePullSecrets.name="aicenter-registry-secrets" \
        --set global.registry.repository_url="sfbrdevhelmweacr.azurecr.io" \
        --set global.registry.project_id="aicenter" \
        --set local.registry.host="$registry_host" \
        --set local.registry.user="$registry_username" \
        --set local.registry.password=`echo -n $registry_password | base64` \
        --set global.storage.accessKey=`echo -n $storage_access_key | base64` \
        --set global.storage.secretKey=`echo -n $storage_secret_key | base64` \
        --set global.storage.externalAccessScheme="https" \
        --set global.storage.externalHost="$1" \
        --set global.storage.externalPort="31443" \
        --set global.storage.internalAccessScheme="http" \
        --set global.storage.internalHost="$storage_internal_host" \
        --set global.storage.internalPort="80" \
        --set global.orchSelfSignedCerts="true" \
        --set global.orchestratorUrl="$orchestrator_host/" \
        --set global.identityServerUrl="$identity_host" \
        --set global.orchCert="$6" \
        --set oobModel.enabled="false" \
        --set provisionCephBucketJob.enabled="true" \
        --set registerISClientJob.enabled="true" \
        --set global.accessToken="$7" \
        -f aicenter/values-ec.yaml