#!/bin/bash

install_gpu() {

    # Set cuda nvidia repository
    curl -O https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/cuda-repo-ubuntu1804_10.0.130-1_amd64.deb
    sudo dpkg -i cuda-repo-ubuntu1804_10.0.130-1_amd64.deb
    sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub

    # install cuda
    sudo apt update
    sudo apt-get -y install cuda

    echo "################################# Validate NVIDIA-SMI #####################################"
    nvidia-smi
    nvidia_version=$(nvidia-smi | grep NVIDIA-SMI | grep CUDA)

    if [[ "${nvidia_version}" == *"CUDA Version"* && "${nvidia_version}" == *"Driver Version"* ]]; then

        # install nvidia-docker based on distribution
        distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
        curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
        curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
        sudo apt-get update && sudo apt-get install -y nvidia-docker2

        # update docker daemon json with nvidia runtime
        set_daemon_json
        sudo systemctl restart docker

        sleep 4

        # Add kubernetes daemon to add connectivity to nvidia 
        validate_kubectl_command
        kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/1.0.0-beta6/nvidia-device-plugin.yml

        # Validate that gpu driver installation & integration is successful
        validate_gpu_updated
        echo "################################# Nvidia integration succeeded #####################################"
    else
        echo "################ GPU driver installation failed ###################"
        exit
    fi
}

set_daemon_json(){
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

validate_kubectl_command() {
    count=0
    while [ $count -lt 50 ]; do
        result=$(kubectl get nodes| grep master)
        if [[ "$result" == *"master"* ]]; then
            echo "kubectl command ran successfully in " $((count * 5)) "seconds"
            break
        else
            echo "Not able to run kubectl command, retry : " $count
            count=$(( $count + 1 ))
            sleep 5
        fi
    done

    if [ $count == 50 ]; then
        echo "Failed to run kubectl command. Please check if kubernetes context is properly set and available to logged in user."
        swapoff -a
        exit
    fi
}

validate_gpu_updated() {
    count=0
    while [ $count -lt 50 ]; do
        result=$(kubectl describe nodes| grep nvidia.com/gpu)
        if [[ "$result" == *"nvidia.com/gpu"* ]]; then
            echo $result
            echo "Node gpu info updated after " $((count * 5)) "seconds"
            echo "##################### Successfully integrated GPU with kubernetes #########################"
            break
        else
            echo "kubectl gpu info not updated, retry : " $count
            count=$(( $count + 1 ))
            sleep 5
        fi
    done

    if [ $count == 50 ]; then
        echo "################## Failed to integrate with gpu ####################"
        swapoff -a
        exit
    fi
}

main() {

    # check if GPU is attached to disk
    check_nvidia=$(sudo lshw -C display|grep NVIDIA)

    if [[ "$check_nvidia" == *"NVIDIA"* ]]; then
        install_gpu
    else
        echo "####### GPU not installed in the setup ###########"
        exit
    fi
}

main