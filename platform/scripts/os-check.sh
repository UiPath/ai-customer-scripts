#!/bin/bash

echo "[INFO]: Starting OS validation.."

if [ -f /etc/os-release ];
then
  . /etc/os-release
  OS=$NAME
  VER=$VERSION_ID

elif [ -f /etc/lsb-release ];
then
  . /etc/lsb-release
  OS=$DISTRIB_ID
  VER=$DISTRIB_RELEASE
else
  # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
  OS=$(uname -s)
  VER=$(uname -r)
fi

if [[ ("${OS}" != "Ubuntu") && ("${OS}" != "Red Hat Enterprise Linux Server") ]];
then
  echo "[ERROR]: OS check failed. Only Ubuntu and RHEL is supported. Exiting.. "
  exit 1;
fi

MAJOR_VERSION=${VER%.*}

if [[ ("${OS}" == "Ubuntu") && ($MAJOR_VERSION -lt "16") ]];
then
  echo "[ERROR]: Version check failed. Minimum version supported is 16.0. Exiting.."
  exit 1;
fi

echo "[INFO]: OS validation completed"