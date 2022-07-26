#!/bin/bash

echo "Enter backup dir path:"
read backupDir

echo "Backup started"

kubectl apply -f $backupDir

echo "Backup completed"
