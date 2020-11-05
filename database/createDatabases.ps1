#Requires -RunAsAdministrator

<#   
.SYNOPSIS   
   Create Databases Required for AIFabric
.DESCRIPTION 
   Create Databases required by AIFabric i.e ai_helper, ai_pkgmanager, ai_deployer, ai_trainer & ai_appmanager & the script also creates an user which has db_owner privileges on all these 5 databases 
   and the username and password that are generated are both logged to console as well as stored as an file in the current directory from where the script execution is triggered.
.NOTES   
    Name: ./createDatabases.ps1
    Author: AIFabric Team
    Pre-Requisites: script has to be executed throuh powershell in Administrator mode & before running script set execution policy to RemoteSigned by running "Set-ExecutionPolicy RemoteSigned"
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
#>

Param (
   [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName)]
   [string] $sqlinstance,
   [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName)]
   [string] $windowsAuthentication,
   [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName)]
   [string] $dbuser,
   [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName)]
   [string] $dbpass,
   [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName)]
   [string] $suffix,
   [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName)]
   [string] $singleDatabase
)


if($windowsAuthentication.Length -eq 0){
    write-host "since windowsAuthentication flag is not set, defaulting to SQL server authentication"
    $windowsAuthentication = "N"
}

if($singleDatabase.Length -eq 0){
    write-host "creating multiple databases"
    $singleDatabase = "N"
}

if($windowsAuthentication -eq "Y"){
  echo "Authenticating via Windows Authentication(i.e Using Integrated Auth)"    
} elseif($windowsAuthentication -eq "N"){
    $sqlCredentials = Get-Credential
    #Password Validation
    $username = $sqlCredentials.username
    $password = $sqlCredentials.GetNetworkCredential().password

    if(($username.Length -eq 0) -or ($password.Length -eq 0)){
    write-host "SQL Server Auth Enabled and credentials are not supplied so exiting the program" -ForegroundColor Red
    exit 1
    }
} else{
    echo "Invalid Input, Exiting the program !, windowsAuthentication should be set to either Y or N"
    exit
}

#Validating Input
if($suffix.Length -gt 0){
    $suffix = $suffix.ToString()
}

if($dbuser.Length -gt 0){
    $dbuser = $dbuser.ToString()
} else {
    $dbuser = "aifadmin"
}

#Generate Random Password
function generatePassword(){
    $MinimumPasswordLength = 8
    $MaximumPasswordLength = 12
    $PasswordLength = Get-Random -InputObject ($MinimumPasswordLength..$MaximumPasswordLength)
    $AllowedPasswordCharacters = [char[]]'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!?@#$%^&*'
    $Regex = "(?=.*\d)(?=.*[a-z])(?=.*[A-Z])(?=.*\W)"

    do {
            $Password = ([string]($AllowedPasswordCharacters |
            Get-Random -Count $PasswordLength) -replace ' ')
       }    until ($Password -cmatch $Regex)

    $Password
}

#Execute query on target database
function executeQuery($database, $query){
   try{
       if ($windowsAuthentication -eq "Y"){
        Invoke-Sqlcmd -ServerInstance $sqlinstance -Database $database -Query $query -ErrorAction Stop -Verbose
        write-host $query "Succeded" -ForegroundColor Yellow
        } else{
        Invoke-Sqlcmd -ServerInstance $sqlinstance -Database $database -Credential $sqlCredentials -Query $query -ErrorAction Stop -Verbose
        write-host $query "Succeded" -ForegroundColor Yellow
        }
     } catch {
        write-host "Exception type:  $_.Exception.GetType().FullName" -ForegroundColor Red
        return "Failed"
   }
}

#Install modules required
$installed = Test-Path -Path 'C:\Program Files\WindowsPowerShell\Modules\SqlServer'
if(!$installed){
    echo "Installing required module..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	Install-Module -Name SqlServer -AllowClobber -Confirm:$False -Force
}

Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Wow6432Node\\Microsoft\\.NetFramework\\v4.0.30319' -Name 'SchUseStrongCrypto' -Value '1' -Type DWord -Force
Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\.NetFramework\\v4.0.30319' -Name 'SchUseStrongCrypto' -Value '1' -Type DWord -Force

#formulate logins for single Database
$helper_login_user=$dbuser+"_helper"
$pkgmanager_login_user=$dbuser+"_pkgmanager"
$deployer_login_user=$dbuser+"_deployer"
$trainer_login_user=$dbuser+"_trainer"
$appmanager_login_user=$dbuser+"_appmanager"


if($singleDatabase -eq "N"){
    $sqlcommand = "
    GO
    CREATE LOGIN $dbuser WITH PASSWORD=N'{{pwd}}'
    GO
    "
}
else {
$sqlcommand = "
    GO
    CREATE LOGIN $helper_login_user WITH PASSWORD=N'{{pwd}}'
    CREATE LOGIN $pkgmanager_login_user WITH PASSWORD=N'{{pwd}}'
    CREATE LOGIN $deployer_login_user WITH PASSWORD=N'{{pwd}}'
    CREATE LOGIN $trainer_login_user WITH PASSWORD=N'{{pwd}}'
    CREATE LOGIN $appmanager_login_user WITH PASSWORD=N'{{pwd}}'
    GO
    "
}


$addUserToMasterQuery = "
GO
CREATE USER $dbuser FOR LOGIN $dbuser
GO
"

$createDatabaseQuery = "CREATE DATABASE {{DB}}"


if($singleDatabase -eq "N"){
    $grantcommand = "
    GO
    CREATE USER $dbuser FOR LOGIN $dbuser
    GO
    ALTER ROLE [db_owner] ADD MEMBER $dbuser
    GO
    "
} else {
    $grantcommand = "
    GO
    CREATE USER {{USER_NAME}} FOR LOGIN {{USER_NAME}} WITH DEFAULT_SCHEMA = {{SCHEMA_NAME}}
    GO
    CREATE SCHEMA {{SCHEMA_NAME}} AUTHORIZATION {{USER_NAME}}
    GO
    EXEC sp_addrolemember 'db_ddladmin', '{{USER_NAME}}';
    GO
    "
}


#If user supplied the pass use it, otherwise auto generate the pass
if($dbpass.Length -gt 0){
    $unsecurepassword = $dbpass.ToString()
} else {
    $unsecurepassword = generatePassword
}

$sqlcommand = $sqlcommand.Replace("{{pwd}}",$unsecurepassword)

write-host $sqlcommand


#Create Login
$exitStatus = executeQuery master $sqlcommand

if ( $exitStatus -eq "Failed" ) {
    $msg = $Error[0].Exception.Message
    write-host "Encountered error while creating login. Error Message is $msg." -ForegroundColor Red
    write-host "If the login already exists and if the login is generated via this script the same can be found under the file name $dbuser located in the current directory" -ForegroundColor Red
    write-host "If you are using WindowsAuthentication mode, make sure that you are using ServerName instead of IP" -ForegroundColor Red
    exit 1
} else {
    echo "the PASSWORD for $dbuser user is : $unsecurepassword "
    New-Item -ItemType File -Force -Path ".\$dbuser" -Value $unsecurepassword
}

#Add login to Master

if($singleDatabase -eq "N"){
    $exitStatus = executeQuery master $addUserToMasterQuery

    if ( $exitStatus -eq "Failed" ) {
        write-host "The target database does not support adding user to master anyhow this wont affect user from logging into DB with the generated credentials" -ForegroundColor Yellow
    }
}


if($singleDatabase -eq "N"){
    #Create DB's
    executeQuery master $createDatabaseQuery.Replace("{{DB}}", "ai_helper$suffix")
    executeQuery master $createDatabaseQuery.Replace("{{DB}}", "ai_deployer$suffix")
    executeQuery master $createDatabaseQuery.Replace("{{DB}}", "ai_pkgmanager$suffix")
    executeQuery master $createDatabaseQuery.Replace("{{DB}}", "ai_trainer$suffix")
    executeQuery master $createDatabaseQuery.Replace("{{DB}}", "ai_appmanager$suffix")
} else{
    executeQuery master $createDatabaseQuery.Replace("{{DB}}", "aifabric$suffix")
}


if($singleDatabase -eq "N"){
    #Execute Grants
    executeQuery "ai_helper$suffix" $grantcommand
    executeQuery "ai_deployer$suffix" $grantcommand
    executeQuery "ai_pkgmanager$suffix" $grantcommand
    executeQuery "ai_trainer$suffix" $grantcommand
    executeQuery "ai_appmanager$suffix" $grantcommand
} else{
    executeQuery "aifabric$suffix" $grantcommand.Replace("{{USER_NAME}}", $helper_login_user).Replace("{{SCHEMA_NAME}}", "ai_helper")
    executeQuery "aifabric$suffix" $grantcommand.Replace("{{USER_NAME}}", $pkgmanager_login_user).Replace("{{SCHEMA_NAME}}", "ai_pkgmanager")
    executeQuery "aifabric$suffix" $grantcommand.Replace("{{USER_NAME}}", $deployer_login_user).Replace("{{SCHEMA_NAME}}", "ai_deployer")
    executeQuery "aifabric$suffix" $grantcommand.Replace("{{USER_NAME}}", $trainer_login_user).Replace("{{SCHEMA_NAME}}", "ai_trainer")
    executeQuery "aifabric$suffix" $grantcommand.Replace("{{USER_NAME}}", $appmanager_login_user).Replace("{{SCHEMA_NAME}}", "ai_appmanager")
}

