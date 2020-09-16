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
    kubectl -n $NAMESPACE logs ${latest_run} | sed -ne '/-Analysis Start-/,/-Analysis End-/p'
    # Dumping the logs to a file
    kubectl -n $NAMESPACE logs ${latest_run} > aifabric-diagnostics-latest.log
    exit 0
  fi
  counter=$((counter+1))
  WAIT_MESSAGE="${WAIT_MESSAGE}.."
done