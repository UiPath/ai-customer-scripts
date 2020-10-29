#!/bin/bash

function install_gpu() {
    #Install CUDA Drivers for Ubuntu18
    os=$(. /etc/os-release;echo $ID)
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    major_version=$(. /etc/os-release;echo $VERSION_ID | cut -d '.' -f1)

    if [[ "${os}" = "ubuntu" && "${major_version}" = "18" ]];
    then
      curl -O https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/cuda-repo-ubuntu1804_10.0.130-1_amd64.deb
      sudo dpkg -i cuda-repo-ubuntu1804_10.0.130-1_amd64.deb
      sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub

      sudo apt update
      sudo apt-get -y install cuda jq

      #Install nvidia-docker for Ubuntu
      distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
      curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
      curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
      sudo apt-get update && sudo apt-get install -y nvidia-docker2
    elif [[ ("${os}" = "centos" || "${os}" = "rhel") && "${major_version}" = "7" ]];
    then
      sudo yum clean all
      sudo yum install -y kernel-devel-$(uname -r) kernel-headers-$(uname -r)
      sudo yum install -y http://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/cuda-repo-rhel7-10.0.130-1.x86_64.rpm
      sudo yum install -y epel-release
      sudo yum clean all
      sudo yum install -y cuda 
      sudo yum install -y jq 

      #Install nvidia toolkit
      sudo yum clean expire-cache
      sudo yum install nvidia-container-toolkit -y

      #Install Nvidia docker2
      distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
        && curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.repo | sudo tee /etc/yum.repos.d/nvidia-docker.repo
      sudo yum install -y dnf
      sudo dnf clean expire-cache --refresh
      sudo dnf install -y nvidia-docker2
    else
      echo "###########################################"
      echo "The script does not support installing GPU drivers for distribution $distribution"
      echo "Step 1: Install CUDA Drivers for target OS: https://docs.nvidia.com/datacenter/tesla/tesla-installation-notes/index.html"
      echo "Step 2: Install nvidia-docker2 package for target OS: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html#setting-up-docker-on-rhel-7"
      echo "Step 3: After installing nvidia-docker2 package, make sure your docker daemon.json looks like the config documented here https://github.com/NVIDIA/k8s-device-plugin"
      echo "Step 4: Edit /etc/docker/daemon.json and append this entry without escape characters \"exec-opts\": [\"native.cgroupdriver=systemd\"]"
      echo "Step 5: Restart docker via 'sudo systemctl restart docker'"
      echo "Step 6: Run command documented under, 'Enabling GPU Support in Kubernetes' section https://github.com/NVIDIA/k8s-device-plugin"
      echo "Step 7: Run 'kubectl describe node' command and verify whether nvidia.com/gpu is visible under Resource section"
      echo "###########################################"
      exit 1
    fi

    # backup json, this will be used for merging with updated json in the later step
    sudo bash -c 'echo "{\"default-runtime\": \"nvidia\", \"exec-opts\": [\"native.cgroupdriver=systemd\"]}" > /etc/docker/daemon_old_bkp.json'
    # if you installed the nvidia-docker2 package, it already registers the runtime within the docker daemon.json
    # https://github.com/NVIDIA/nvidia-container-runtime
    # Before the restart the docker.json will have this entry "exec-opts": ["native.cgroupdriver=systemd"] which gets overridden https://github.com/NVIDIA/nvidia-docker/issues/1346 
    sudo systemctl restart docker
    edit_and_restart_docker_config

    #Verfiy if kubectl commands are all running fine 
    sleep 2
    export KUBECONFIG=/etc/kubernetes/admin.conf
    validate_kubectl_up

    #At this point, a working setup can be tested by running a base CUDA container
    cuda_health_check=$(sudo docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi | grep "NVIDIA-SMI")

    if [[ "$cuda_health_check" == *"NVIDIA-SMI"* ]];
    then
        echo "GPU Health check successful. This doesn't mean Kubernetes is aware of GPU yet !!!!"
    else 
        echo "GPU Health check not successful"
        exit 1
    fi

    echo "Installing Nvidia Daemonset to make Kubernetes aware of GPU attached to machine"
    kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/1.0.0-beta6/nvidia-device-plugin.yml
    #watch till daemonset rollout is complete
    kubectl -n kube-system rollout status daemonset/nvidia-device-plugin-daemonset --watch=true
    #verify if GPU is visible to kubernetes
    export KUBECONFIG=/etc/kubernetes/admin.conf
    validate_gpu_updated

}

function edit_and_restart_docker_config(){
    echo "################## Updating docker configuration ######################"
    sudo cat /etc/docker/daemon.json > /etc/docker/daemon_original_bkp.json
    sudo jq -s '.[0] * .[1]' /etc/docker/daemon.json /etc/docker/daemon_old_bkp.json > /etc/docker/daemon_merged.json
    sudo mv /etc/docker/daemon_merged.json /etc/docker/daemon.json
    sudo systemctl restart docker
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
            cuda_install_path=$(whereis -b cuda | cut -d ":" -f2 | xargs)
            cuda_version=$($cuda_install_path"/bin/nvcc" --version | grep release | cut -d ',' -f2 | cut -d ' ' -f3)
            nvidia_cuda_compatible_version=$(nvidia-smi -q | grep CUDA | cut -d ':' -f2 | xargs)
            echo "Cuda Version Installed: $cuda_version"
            echo "Nvidia CUDA Compatible version: $nvidia_cuda_compatible_version"
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

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

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