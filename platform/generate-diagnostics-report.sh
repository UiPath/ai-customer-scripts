RED='\033[0;31m' # Red
NC='\033[0m' # No Color
GREEN='\033[0;32m' # Green
YELLOW='\033[1;33m' # Yellow
BOLD='\033[1m'

print_directory_size() {
  if [[ "${2}" -gt "90" ]];
  then
    echo -e "${RED}[ERROR]${NC} The device for the directory $1 is $2% full"
  elif [[ "${2}" -gt "75" ]];
  then
    echo -e "${YELLOW}[WARNING]${NC} The device for the directory $1 is $2% full"
  else
    echo -e "${GREEN}[INFO]${NC} The device for the directory $1 is $2% full"
  fi
}

IS_DOCKER_ACTIVE=$(systemctl is-active docker)

if [[ "${IS_DOCKER_ACTIVE}" != "active" ]];
then
  echo -e "${RED}[ERROR]${NC} Docker service is not running. Please start the docker service using command : sudo systemctl restart docker"
  exit 1
else
  echo -e "${GREEN}[INFO]${NC} Docker is running."
fi

IS_DOCKER_ACTIVE=$(systemctl is-active kubelet)

if [[ "${IS_DOCKER_ACTIVE}" != "active" ]];
then
  echo -e "${RED}[ERROR]${NC} Kubelet is not running. Please start the kubelet service using command : sudo systemctl restart kubelet"
  exit 1
else
  echo -e "${GREEN}[INFO]${NC} Kubelet is running."
fi

KUBELET_CGROUP=$(sudo cat /var/lib/kubelet/config.yaml | grep cgroupDriver | cut -d ':' -f 2 | xargs)
DOCKER_CGROUP=$(sudo docker info 2> /dev/null | grep -i cgroup | cut -d ":" -f 2 | xargs)

if [[ "${KUBELET_CGROUP}" != "${DOCKER_CGROUP}" ]];
then
  echo -e "${RED}[ERROR]${NC} Docker and kubelet are running under different cgroups. Please correct it."
  exit 1
else
  echo -e "${GREEN}[INFO]${NC} Docker and kubelet are running under the same cgroup."
fi

DOCKER_STORAGE_DRIVER=$(sudo docker info 2> /dev/null | grep "Storage Driver" | cut -d ':' -f 2 | xargs)

if [[ "${DOCKER_STORAGE_DRIVER}" == "devicemapper" ]];
then
  echo -e "${RED}[ERROR]${NC} Current docker storage driver is devicemapper, which will cause issues in AI Center, please consider changing to overlay or overlay2"
  exit 1
else
  echo -e "${GREEN}[INFO]${NC} Docker is using ${DOCKER_STORAGE_DRIVER} storage driver."
fi

if [[ -d "/var/lib/docker" ]];
then
  DEVICE_NAME_DOCKER=$(df /var/lib/docker | sed -n '2 p' | cut -d' ' -f1)
else
  DEVICE_NAME_DOCKER=$(df /var/lib/ | sed -n '2 p' | cut -d' ' -f1)
fi

# Check if /var/lib/kubelet is mount with a separate device or check for /var/lib
if [[ -d "/var/lib/kubelet" ]];
then
  DEVICE_NAME_KUBELET=$(df /var/lib/kubelet | sed -n '2 p' | cut -d' ' -f1)
else
  DEVICE_NAME_KUBELET=$(df /var/lib/ | sed -n '2 p' | cut -d' ' -f1)
fi

# If both folders are under same device, check the size to be 200GB or check for the size to be 125GB and 100GB for docker and kubelet
if [[ "${DEVICE_NAME_DOCKER}" == "${DEVICE_NAME_KUBELET}" ]];
then
  COMMON_SIZE=$(df -hl | grep $DEVICE_NAME_DOCKER | awk 'BEGIN{} {percent+=$5;} END{print percent}')
  print_directory_size "/var/lib/" $COMMON_SIZE
else
  DOCKER_SIZE=$(df -hl | grep $DEVICE_NAME_DOCKER | awk 'BEGIN{} {percent+=$5;} END{print percent}')
  print_directory_size "/var/lib/docker" $DOCKER_SIZE
  KUBELET_SIZE=$(df -hl | grep $DEVICE_NAME_KUBELET | awk 'BEGIN{} {percent+=$5;} END{print percent}')
  print_directory_size "/var/lib/kubelet" $KUBELET_SIZE
fi


kubectl -n aifabric delete job diagnostics-job
kubectl -n aifabric create job diagnostics-job --from cronjob/ai-diagnostics-tool

counter=0;
NAMESPACE=aifabric

WAIT_MESSAGE="Diagnostics Check In Progress...."
while [ $counter -le 50 ];
do
  echo -ne "${WAIT_MESSAGE}"\\r && sleep 5;
  status=$(kubectl -n $NAMESPACE get pods --sort-by=.metadata.creationTimestamp | grep diagnostics-job | tail -n -1 | awk '{print $3}')
  latest_run=$(kubectl -n $NAMESPACE get pods --sort-by=.metadata.creationTimestamp | grep diagnostics-job | cut -d ' ' -f 1 | tail -n -1)
  if [ "${status}" = "Error" ];
  then
    logs=$(kubectl -n $NAMESPACE logs ${latest_run})
    echo $logs
    echo "Failed to generate Diagnostics Report. Exiting !!!"
    exit 1
  fi
  if [ "${status}" = "Completed" ];
  then
    echo "Successfully Generated Diagnostics Report"
    printf "Report Generated on %s\n" "$(date)"
    kubectl -n $NAMESPACE logs ${latest_run} | sed -ne '/-Analysis Start-/,/-Analysis End-/p'
    # Dumping the logs to a file
    kubectl -n $NAMESPACE logs ${latest_run} > aifabric-diagnostics-latest.log
    # Append time of report generation as well.
    printf "**Report Generated on %s\n" "$(date)" >> aifabric-diagnostics-latest.log
    exit 0
  fi
  counter=$((counter+1))
  WAIT_MESSAGE="${WAIT_MESSAGE}.."
done