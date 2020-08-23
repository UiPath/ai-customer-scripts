#!/bin/bash

function install_gpu() {
    curl -O https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/cuda-repo-ubuntu1804_10.0.130-1_amd64.deb
    sudo dpkg -i cuda-repo-ubuntu1804_10.0.130-1_amd64.deb
    sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub

        sudo apt update
        sudo apt-get -y install cuda

        echo "################################# Validate NVIDIA-SMI #####################################"
        nvidia-smi
        nvidia_result=$(nvidia-smi | grep "Tesla K80")
        if [[ "$nvidia_result" == *"Tesla K80"* ]]; then
            agree1="Y"
        fi
    if [ "$agree1" == "Y" ]     ; then
        distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
        curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
        curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
        sudo apt-get update && sudo apt-get install -y nvidia-docker2
        # edit json
        edit_daemon_json
        sudo systemctl restart docker
        sleep 2
        validate_kubectl_up
        kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/1.0.0-beta6/nvidia-device-plugin.yml

        validate_gpu_updated
    else
        echo "################ GPU driver installation failed ###################"
        exit
    fi
}

function edit_daemon_json(){
    echo "################## Updating docker configuration ######################"
    sudo bash -c '
echo \
"{
    \"default-runtime\": \"nvidia\",
    \"runtimes\": {
        \"nvidia\": {
            \"path\": \"/usr/bin/nvidia-container-runtime\",
            \"runtimeArgs\": []
        }
    }
}" > /etc/docker/daemon.json'

}

function validate_kubectl_up() {
    count=0
    while [ $count -lt 50 ]; do
        result=$(kubectl get nodes| grep master)
        if [[ "$result" == *"master"* ]]; then
            echo "kubectl up after " $((count * 5)) "seconds"
            break
        else
            echo "kubectl not up, retry : " $count
            count=$(( $count + 1 ))
            sleep 5
        fi
    done

    if [ $count == 50 ]; then
        echo "Kubectl Failed to come up"
        swapoff -a
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


sudo lshw -C display
check_nvidia=$(sudo lshw -C display|grep NVIDIA)
if [[ "$check_nvidia" == *"NVIDIA"* ]]; then
    agree="Y"
fi

if [ "$agree" == "Y" ]
then
    install_gpu
else
    echo "####### GPU not installed in the setup ###########"
    exit
fi