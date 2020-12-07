echo "Starting AIFabric De-Provisioning... Please ignore some of the 'No Resources found' errors, as they are harmless."

echo "Instlling Helm on the machine"
curl -L https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash -s -- --version v3.1.3

echo "Uninstalling AIFabric Services"
helm delete oob-scheduler-crd

helm delete docker-image-deletion-scheduler-crd

helm delete oob-installer-crd

helm -n aifabric delete cronjob

helm -n aifabric delete ai-app

helm -n aifabric delete ai-appmanager

helm -n aifabric delete ai-trainer

helm -n aifabric delete ai-deployer

helm -n aifabric delete ai-pkgmanager

helm -n aifabric delete ai-helper

helm -n aifabric delete rabbitmq
kubectl -n aifabric patch pvc data-rabbitmq-0 -p '{"metadata":{"finalizers":null}}'
kubectl -n aifabric delete pvc data-rabbitmq-0
kubectl -n aifabric patch pvc data-rabbitmq-1 -p '{"metadata":{"finalizers":null}}'
kubectl -n aifabric delete pvc data-rabbitmq-1
kubectl -n aifabric patch pvc data-rabbitmq-2 -p '{"metadata":{"finalizers":null}}'
kubectl -n aifabric delete pvc data-rabbitmq-2

helm -n aifabric delete jwksproxy

# configmaps and secrets will be deleted with delete namespace
echo "Deleting AIFabric Namespace"
kubectl delete ns aifabric

# EFK Uninstall
echo "Uninstalling EFK Stack"
helm delete efk-stack-crd

# Istio uninstall
echo "Uninstalling Istio from Cluster"
curl -sL "https://github.com/istio/istio/releases/download/1.5.6/istio-1.5.6-linux.tar.gz" | tar xz
cd istio-1.5.6
chmod +x ./bin/istioctl
./bin/istioctl manifest generate | kubectl delete --ignore-not-found=true -f -
kubectl delete namespace istio-system

# Kots-Admin Uninstall
echo "Unistalling Kots-Admin from the Cluster"
kubectl delete ns aif-core

# Ceph uninstall
echo "Uninstalling Ceph from Cluster"
kubectl delete -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/object.yaml

kubectl delete -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/cluster-test.yaml

kubectl delete -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/operator.yaml

kubectl delete -n rook-ceph clusterrolebinding rook-ceph-system-admin

kubectl delete -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/common.yaml

kubectl delete ns rook-ceph

echo "Deleting tenant related namespaces"
NAMESPACES=$(kubectl get ns --no-headers -o custom-columns=NAME:.metadata.name)

for namespace in $NAMESPACES; do
    if [[ $namespace =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]]; then # MLSkills Namespace
        echo "$namespace true"
        kubectl delete ns $namespace
    else
        if [[ $namespace =~ training-\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]]; # Training Namespace
        then
            echo "$namespace true"
            kubectl delete ns $namespace
        fi
    fi
done

# https://rook.io/docs/rook/v1.4/ceph-teardown.html
echo "AIFabric Deprovisioning Completed. Please refer <docs-link> to perform some manual steps to clean everything."

echo "################################################################################################"

echo "Please perform following steps to clean up everything -
1. Run this command on all nodes

rm -rf /var/lib/rook

2. On all nodes run following commands for every disk used by rook. You can check the disks used by running 'lsblk' and checking if there is 'lvm ceph-*****' written with that disk.
Do this for all disks, by changing name of the disk on first line, (/dev/sdc, /dev/sdb etc..)

DISK="/dev/sdc"
sgdisk --zap-all \$DISK
dd if=/dev/zero of="\$DISK" bs=1M count=100 oflag=direct,dsync
blkdiscard \$DISK

3. After above is done for all disks on all nodes.
Run following command on each node where ceph devices(disks) were created.

ls /dev/mapper/ceph-* | xargs -I% -- dmsetup remove %
rm -rf /dev/ceph-*"