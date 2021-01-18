# AI-Customer-Scripts

This repository is used to store scripts for performing support operations on AI-Fabric on-premise installations.

## Changeset Procedure 

To raise a PR against this repository, follow below procedures, 

1. Take branch cut from alpha branch with naming convention users/{user-name}/{feature-name}
2. Once changes are done and verified on on-premise setup, raise PR against alpha branch.
3. On being merged to alpha branch, changes will be verified by QA with next on-premise release readiness.
4. With release, these changes will be picked to release branch and subsequently to master branch.

## database

This directory contains the scripts for database related operations 

createDatabases.ps1 is used to create databases for AI-Fabric Metadata Storage & can be used with following options. This script has to be executed through powershell in Administrator mode & before running script set execution policy to RemoteSigned by running "Set-ExecutionPolicy RemoteSigned"
.EXAMPLE 
    If SQL Server can be accessed through Windows Authentication then:
    ./createDatabases.ps1 -sqlinstance "DESKTOP-LOUPTI1\SQLEXPRESS" -windowsAuthentication "Y" 

    If SQL Server has to be accessed through SQL Server Authentication:
    ./createDatabases.ps1 -sqlinstance "DESKTOP-LOUPTI1\SQLEXPRESS" -windowsAuthentication "N" 

    If you wish to change the dbUser Name generated:
    ./createDatabases.ps1 -sqlinstance "DESKTOP-LOUPTI1\SQLEXPRESS" -windowsAuthentication "N" -dbuser "aifadmin"

    If you wish to generate DB Names with suffixes, this is just for testing purpose:
    ./createDatabases.ps1 -sqlinstance "DESKTOP-LOUPTI1\SQLEXPRESS" -windowsAuthentication "N" -dbuser "aifadmin" -dbpass "admin@123" -suffix "_tbd"

    If user supplied password has to be used instead of script autogenerating the same:
    ./createDatabases.ps1 -sqlinstance "DESKTOP-LOUPTI1\SQLEXPRESS" -windowsAuthentication "N" -dbuser "aifadmin" -dbpass "admin@123"

## gpu

install_gpu_driver.sh is used to install GPU drivers, associate gpu drivers with docker runtime and register gpu hardware with kubernetes deployment. Run below command to install drivers 

./install_gpu_driver.sh

## metadata

This directory stores the metadata of Out of box models that can be used with on-premise online & airgap installations.

## orchestrator

This directory stores the script to setup aifabric connection related properties in orchestartor. This script has to be executed throuh powershell in Administrator mode & before running script set execution policy to RemoteSigned by running "Set-ExecutionPolicy RemoteSigned". 

.EXAMPLE 
    If orchestrator is hosted at orchestrator.uipath.com and aifabric is available at ww.xx.yy.zz, command to run would be 
    ./orchestratorAutomation.ps1 -aifip ww.xx.yy.zz -orcname orchestrator.uipath.com

    If ai-app is accessed via domain instead of IP:PORT combo, then enable domainBasedAccess to true
    .\orchestratorAutomation.ps1 -aifip "aif-sahil-aks.westeurope.cloudapp.azure.com" -orcname "aifabricdevorch.northeurope.cloudapp.azure.com" -portlessAccess "true"

    If Orchestrator Installation Path has to be specified,
    ./orchestratorAutomation.ps1 -aifip ww.xx.yy.zz -orcname orchestrator.uipath.com -config "C:\Program Files (x86)\UiPath\Orchestrator"

## platform 

This directory stores platform related scripts to support maintenance operations on supported platforms. 
