#!/bin/bash

echo "[INFO]: Starting LVM check.."

LVM_VERSION=$( lvm version | grep "LVM version" )

if [ "${LVM_VERSION}" != "" ];
then
  echo "[INFO]: LVM check - lvm is installed."
else
  echo "[ERROR]: lvm is not installed. Exiting.."
  exit 1;
fi