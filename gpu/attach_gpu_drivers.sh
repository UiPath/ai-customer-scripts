#!/bin/bash

function edit_daemon_json(){
    echo "################## Updating docker configuration ######################"
    sudo bash -c '
echo \
"{
    \"default-runtime\": \"nvidia\",
    \"exec-opts\": [\"native.cgroupdriver=systemd\"],
    \"runtimes\": {
        \"nvidia\": {
            \"path\": \"/usr/bin/nvidia-container-runtime\",
            \"runtimeArgs\": []
        }
    }
}" > /etc/docker/daemon.json'

}

function kubernetes_cluster_up() {
    count=0
    swapoff -a
    while [ $count -lt 50 ]; do
        sudo chmod +r /etc/kubernetes/admin.conf
        export KUBECONFIG=/etc/kubernetes/admin.conf
        result=$(kubectl get nodes| grep master)
        if [[ "$result" == *"master"* ]]; then
            echo "Kubernetes up after " $((count * 5)) "seconds"
            break
        else
            echo "Kubernetes not up, retry : " $count
            count=$(( $count + 1 ))
            sleep 5
        fi
    done

    if [ $count == 50 ]; then
        echo "Kubernetes Failed to come up"
        exit
    fi
}

function validate_gpu_updated() {
    count=0
    while [ $count -lt 50 ]; do
        result=$(kubectl describe nodes| grep nvidia.com/gpu)
        if [[ "$result" == *"nvidia.com/gpu"* ]]; then
            echo $result
            echo "Node gpu info updated after " $((count * 5)) "seconds"
            echo "##################### Successfully installed GPU #########################"
            break
        else
            echo "kubectl gpu info not updated, retry : " $count
            count=$(( $count + 1 ))
            sleep 5
        fi
    done

    if [ $count == 50 ]; then
        echo "################## Failed to install gpu ####################"
        swapoff -a
        exit
    fi
}

function restart_docker() {
    sudo pkill -SIGHUP dockerd
    sudo systemctl restart docker
    count=0
    while [ $count -lt 50 ]; do
        result=$(sudo systemctl status docker| grep running)
        if [[ "$result" == *"running"* ]]; then
            echo "docker is up " $((count * 5)) "seconds"
            break
        else
            echo "docker is not up, retry : " $count
            count=$(( $count + 1 ))
            sleep 5
        fi
    done

    if [ $count == 50 ]; then
        echo "Docker Failed to come up"
        swapoff -a
        exit
    fi
}
echo "#################################### Ecko Shutdown #######################################"
sudo /opt/ekco/shutdown.sh

echo "################################# Attach GPU Driver #####################################"
# edit json
edit_daemon_json
echo "################################# Restarting docker #####################################"
restart_docker
sleep 2
# This is required because when kubeadm init start kubelet, its check docker cgroup driver and uses cgroupfs
# in case of discrepancy. So we have to change this driver and restart kubelet again
echo "################################# Restarting kubelet #####################################"
sudo sed -i 's/cgroup-driver=cgroupfs/cgroup-driver=systemd/' /var/lib/kubelet/kubeadm-flags.env
sudo systemctl restart kubelet
sleep 10
kubernetes_cluster_up
kubectl apply -f nvidia-device-plugin.yaml
validate_gpu_updated

echo "########################## Uncordon Node #######################################"
kubectl uncordon $(hostname | tr '[:upper:]' '[:lower:]')

echo "################ GPU driver installation successful ###################"