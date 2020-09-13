#!/bin/bash
  
avail_device_count=0
#Get all devices
disks=$( lsblk --all --paths --nodeps --pairs --output NAME | grep -v -e "loop" -e "rbd" -e "ceph" )
IFS=$'\n'
set -o noglob  # or more tersely set -f

#Loop through all devices
for disk in $disks; do
  DEVICE=$(echo "$disk" | cut -f2 -d= | tr -d '"')
  FS_KEY_VAL=$(udevadm info --query=property "$DEVICE" | grep "ID_FS_TYPE")
  FILE_SYSTEM=$(echo "$FS_KEY_VAL" | cut -f2 -d= | tr -d '"')
  RO=$(lsblk $DEVICE --nodeps --noheadings --output RO)
  DEVICE_TYPE=$(lsblk $DEVICE --nodeps --noheadings --output TYPE)
  PARTITION_COUNT=$(lsblk $DEVICE --bytes --pairs --output NAME,SIZE,TYPE,PKNAME | grep "part" | wc -l)
  #if partition_count is emtpy initialize it to zero
  if [[ -z $PARTITION_COUNT ]];
  then
    PARTITION_COUNT=0
  fi
  PARENT_DEVICE=$(lsblk $DEVICE --nodeps --noheadings --paths --output PKNAME)
  SIZE=$(lsblk $DEVICE --nodeps --noheadings --paths --output SIZE)

  echo "Device attached to the Machine, Device: $DEVICE FileSystem: $FILE_SYSTEM RO: $RO DeviceType: $DEVICE_TYPE PartitionCount: $PARTITION_COUNT ParentDevice: $PARENT_DEVICE Size: $SIZE"

  # if the device has file system associated with it, then ceph cant use the disk
  if [[ ! -z $FILE_SYSTEM ]];
  then
    echo "Device: $DEVICE cant be used by ceph as it has an FileSystem: $FILE_SYSTEM associated with it"
  fi

  #If the Device has paritions then ceph cant use the device
  if [[ $PARTITION_COUNT -gt 0 ]];
  then
    echo "Device: $DEVICE cant be used by ceph as it has Partitions: $PARTITION_COUNT associated with it"
  fi

  #remove the character G from size
  SIZE=${SIZE::-1}

  if [[ -z $PARENT_DEVICE && -z $FILE_SYSTEM && $PARTITION_COUNT -eq 0 && $RO -eq 0 ]]
  then
    if [[ "$DEVICE_TYPE" == "disk" || "$DEVICE_TYPE" == "ssd" || "$DEVICE_TYPE" == "crypt" || "$DEVICE_TYPE" = "lvm" ]];
    then
      echo "Available Device for CEPH Consumption is $DEVICE Size: $SIZE DeviceType: $DEVICE_TYPE"
      avail_device_count=$((avail_device_count+1))

      if [ $SIZE -lt 500 ];
      then
        echo "Device $DEVICE available for ceph consumption but its size $SIZE GB is less than recommended size i.e 500GB"
      fi
    fi
  fi

done

if [ $avail_device_count -eq 0 ];
then
  echo "Sorry, There arent any devices available for CEPH consumption !!"
  exit 1
fi