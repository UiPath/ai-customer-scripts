#!/bin/bash

echo "Install jq"
sudo apt-get install -y jq
sleep 30

sudo chmod 777 /etc/kubernetes/admin.conf
export KUBECONFIG=/etc/kubernetes/admin.conf
echo "Istio install start"
sleep 60
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.8.5 TARGET_ARCH=x86_64 sh -  && chmod u+x istio-1.8.5 && curl -L https://raw.githubusercontent.com/UiPath/aifabric-packaging/user/irfan/extclustpipeline/.pipelines2/existingCluster/jobs/istio-operator.yaml?token=APUOWXRWXMMH4L7ROJS4SI3A3HNUI --output istio-operator.yaml && ./istio-1.8.5/bin/istioctl install -f istio-operator.yaml --istioNamespace istio-system -y
echo "Istio install done"
sleep 60

echo "Istio secret certs"
openssl req -nodes -new -x509 -keyout aicentercert.key -out aicentercert.crt -subj "/C=IN/ST=Karnataka/L=Bangalore/O=UiPath/CN=abcd@uipath.com"
kubectl -n istio-system create secret tls istio-ingressgateway-certs --cert=aicentercert.crt --key=aicentercert.key
sleep 60

echo "Setup aicenter gateway"
curl -L https://raw.githubusercontent.com/UiPath/aifabric-packaging/user/irfan/extclustpipeline/.pipelines2/existingCluster/jobs/aicenter-gateway.yaml?token=APUOWXT5HRHLP7GEGOH7HODA3HR4S --output aicenter-gateway.yaml && kubectl apply -f aicenter-gateway.yaml
sleep 60

echo "Setup rook ceph gateway"
curl -L https://raw.githubusercontent.com/UiPath/aifabric-packaging/user/irfan/extclustpipeline/.pipelines2/existingCluster/jobs/rook-ceph-gateway.yaml?token=APUOWXQTKQAE5QNJSOHSV5DA3HR6M --output rook-ceph-gateway.yaml && kubectl apply -f rook-ceph-gateway.yaml
sleep 60

echo "Setup rook ceph virtual service"
curl -L https://raw.githubusercontent.com/UiPath/aifabric-packaging/user/irfan/extclustpipeline/.pipelines2/existingCluster/jobs/rook-ceph-virtual-service.yaml?token=APUOWXXXCOZSXGPTMEF2GTDA3HSAA --output rook-ceph-virtual-service.yaml && kubectl apply -f rook-ceph-virtual-service.yaml
sleep 60

echo "Create uipath namespace"
kubectl create namespace uipath
sleep 15

echo "Setup registry secrets"
echo " temporary value $1 $2 $3"
kubectl -n uipath create secret docker-registry aicenter-registry-secrets --docker-server="$1" --docker-username="$2" --docker-password="$3"
sleep 60
