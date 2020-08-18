#Requires -RunAsAdministrator

<#   

.SYNOPSIS   
   Makes aifabric related changes to orchestrator web.config to enable aifabric installation and access.
.DESCRIPTION 
   Add entries in orchestrator web.config(if not exists) for orchestrator internal IDP and aifabric access from robot and orchestrator. 
   Removes cache to allow access to new controllers and resets iis to load new values.
.NOTES   
    Name: ./orchestratorAutomation.ps1
    Author: AIFabric Team
    Pre-Requisites: script has to be executed throuh powershell in Administrator mode & before running script set execution policy to RemoteSigned by running "Set-ExecutionPolicy RemoteSigned"
.EXAMPLE 
    If orchestrator is hosted at orchestrator.uipath.com and aifabric is available at ww.xx.yy.zz, command to run would be 
    ./orchestratorAutomation.ps1 -aifip ww.xx.yy.zz -orcname orchestrator.uipath.com

#>

Param (
   [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName)]
   [string] $orcname,
   [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName)]
   [string] $config,
   [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName)]
   [string] $aifip,
   [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName)]
   [string] $aifport
   [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName)]
   [string] $storageport
)

Import-Module 'WebAdministration'
    if(!$config)
    {   
        $config = "C:\Program Files (x86)\UiPath\Orchestrator\web.config"
    }
    if(!$aifport)
    {   
        $aifport = "31390"
    }
    if(!$storageport)
    {
        $storageport = "31443"
    }

echo "Path to web.config: "$config

Copy-Item $config -Destination ("$config.original."+(Get-Date -Format "MMddyyyy.HH.mm.ss"))

#AiFabric Settings template
$STATIC_NODES_STRING='
<Collection>
    <add key="CertificatesStoreLocation" value="LocalMachine" />
    <add key="AiFabric.Licensing" value="true" />
    <add key="AiFabric.MLSkillsCreate" value="false" />
    <add key="AiFabric.MLSkillsCreateOOB" value="false" />
    <add key="AiFabric.PackagesCreate" value="false" />
    <add key="AiFabric.Packages" value="false" />
    <add key="AiFabric.Logs" value="false" />
    <add key="AiFabric.ModuleEnabled" value="true" />
    <add key="AiFabric.FeatureEnabledByDefault" value="true" />
    <add key="AiFabric.ModelStorageUrl" value="https://{{aifip}}:{{storageport}}" />
    <add key="AiFabric.MLPackagingInstructionsUrl" value="https://docs.uipath.com/ai-fabric/docs/building-ml-packages" />
    <add key="AiFabric.MLServiceUrl" value="https://{{aifip}}:{{aifport}}" />
    <add key="AiFabric.MLSkillUrl" value="https://{{aifip}}:{{aifport}}/ai-deployer" />
    <add key="AiFabric.MLPackageUrl" value="https://{{aifip}}:{{aifport}}/ai-pkgmanager" />
    <add key="AiFabric.MLLogUrl" value="https://{{aifip}}:{{aifport}}/ai-helper" />
    <add key="AiFabric.MLTrainUrl" value="https://{{aifip}}:{{aifport}}/ai-trainer" />
    <add key="AiFabric.AccountId" value="host" />
    <add key="IDP.Scope" value="[&quot;AIFabric&quot;,&quot;Orchestrator&quot;]" />
    <add key="IDP.CurrentTokenThumbprint" value="{{thumbprint}}" />
    <add key="IDP.PreviousTokenThumbprint" value="{{thumbprint}}" />
    <add key="IDP.SigningCertificate" value="{{cert}}" />
    <add key="IDP.Authority" value="https://{{orchestratorhostname}}/api/auth/" />
    <add key="IdentityProviderFeature.Enabled" value="true" />
    <add key="Auth.OAuth.SharedRobotOAuthClientId" value="03FFA863-3C0C-4EEC-BBE5-094D4FCF4F22" />
    <add key="Auth.OAuth.SharedRobotOAuthAuthority" value="https://{{orchestratorhostname}}/api/auth/" />
    <add key="Auth.OAuth.SharedOrchestratorOAuthClientId" value="a42436d5-4cd6-4d6a-9311-51271d9fc217" />
    <add key="Auth.OAuth.SharedOrchestratorOAuthAuthority" value="https://{{orchestratorhostname}}/api/auth/" />
    <add key="Auth.OAuth.OrchestratorOAuthAudience" value="Orchestrator" />
    <add key="Auth.OAuth.RobotAuthenticationEnabled" value="true" />
    <section name="ClientApplications" type="UiPath.Orchestrator.Security.IdentityProvider.Model.ClientApplications, UiPath.Orchestrator.Security.IdentityProvider" />
</Collection>'

#Client App Settings
$CLIENT_APP_NODES_STRING='
<Collection>
    <ClientApplications>
        <add displayName="Robot" clientId="03ffa863-3c0c-4eec-bbe5-094d4fcf4f22" jwtExpirationInSeconds="86400"/>
        <add displayName="Orchestrator" clientId="a42436d5-4cd6-4d6a-9311-51271d9fc217" jwtExpirationInSeconds="86400"/>
    </ClientApplications>
</Collection>'

# get orchestrator cert values
$thumbrint = $null
$RawBase64 = $null
$orchestratorhostname = $null
Get-ChildItem -Path IIS:SSLBindings | ForEach-Object -Process `
{
    if ($_.Sites)
    {
        $_.Sites
        $sname = $_.Sites.Value
        if($config.Trim().ToLower().Equals((Get-WebFilePath "IIS:\Sites\$sname\web.config").ToString().Trim().ToLower()))
        {
            $certificate = Get-ChildItem -Path CERT:LocalMachine/My |
                Where-Object -Property Thumbprint -EQ -Value $_.Thumbprint
            $thumbprint = $certificate.Thumbprint.ToLower()
            $RawBase64 = [System.Convert]::ToBase64String($certificate.GetRawCertData())
            $orchestratorhostname = ((Get-WebBinding -Name $sname) | where{$_.protocol -eq "https"}).bindingInformation.Split(":")[-1]
        }
    }
}

# validations of input
if($orcname)
{
    if ($orcname.StartsWith("http://") -or $orcname.StartsWith("https://"))
    {
        echo "orcname should not start with http or https"
        throw "Invalid orcname input provided: $orcname"
    }
    $orchestratorhostname = $orcname
}

if($aifip.StartsWith("http://") -or $aifip.StartsWith("https://"))
{
    echo "aifip should not start with http or https"
    throw "Invalid aifip input provided: $aifip"   
}

# set nodes value
$STATIC_NODES_STRING = $STATIC_NODES_STRING.Replace("{{aifip}}",$aifip);
$STATIC_NODES_STRING = $STATIC_NODES_STRING.Replace("{{thumbprint}}",$thumbprint);
$STATIC_NODES_STRING = $STATIC_NODES_STRING.Replace("{{cert}}",$RawBase64);
$STATIC_NODES_STRING = $STATIC_NODES_STRING.Replace("{{orchestratorhostname}}",$orchestratorhostname);
$STATIC_NODES_STRING = $STATIC_NODES_STRING.Replace("{{aifport}}",$aifport);
$STATIC_NODES_STRING = $STATIC_NODES_STRING.Replace("{{storageport}}",$storageport);
$STATIC_NODES = [xml]$STATIC_NODES_STRING
$CLIENT_APP_NODES = [xml]$CLIENT_APP_NODES_STRING

# edit web config
function AifabricFixedConfig
{
    $nodes = Select-Xml -XPath '//add' -Xml $STATIC_NODES
    $additionalSection = Select-Xml -XPath '//section' -Xml $STATIC_NODES
    $ClientApplicationsSection = Select-Xml -XPath '//ClientApplications' -Xml $CLIENT_APP_NODES
    
    $file = gi $config
    $xml = [xml](gc $file)
    foreach($node in $nodes)
    {
        #remove existing nodes if they exist. They should not. 
        $key = $node.Node.key
        $xml.SelectNodes("configuration/appSettings/add[@key='$key']") | %{$xml.configuration.appSettings.RemoveChild($_)}
        $xml.configuration.appSettings.AppendChild($xml.ImportNode($node.Node,1))
    }
    if($xml.SelectNodes("configuration/configSections/section[@name='ClientApplications']").Count -eq 0)# | %{$xml.configuration.configSections.RemoveChild($xml.ImportNode($additionalSection.Node,1))}
    {
        $xml.configuration.configSections.AppendChild($xml.ImportNode($additionalSection.Node,1))
    }
    if($xml.SelectNodes("configuration/ClientApplications").Count -eq 0)
    {
        $xml.configuration.AppendChild($xml.ImportNode($ClientApplicationsSection.Node,1))
    }
    $xml.Save($file.FullName)
}

# Reset IIS to reload values
function Retry-IISRESET
{
    param (
    [Parameter(Mandatory=$false)][int]$retries = 5, 
    [Parameter(Mandatory=$false)][int]$secondsDelay = 2
    )
        
    $retrycount = 0
    $completed = $false

    while (-not $completed) {
        try {
            iisreset | Tee-Object -Variable statusiisreset
			if("$statusiisreset".Contains("failed"))
			{
				throw
			}
            Write-Verbose ("reset succeded")
            $completed = $true
        } catch {
            if ($retrycount -ge $retries) {
                throw
            } else {
                Start-Sleep $secondsDelay
                $retrycount++
            }
        }
    }
}

# remove cache
function EmptyAspNetCache
{
    $Framework32bitFolder = "\Framework\"
    $Framework64bitFolder = "\Framework64\"
    $temporaryAspNetFolder = "Temporary ASP.NET Files\root"
    $ControllerCacheFileName = "MS-ApiControllerTypeCache.xml"
    $aspNetCacheFolder = [System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()+$temporaryAspNetFolder
    if ([Environment]::Is64BitOperatingSystem)
    {
        $aspNetCacheFolder = $aspNetCacheFolder.Replace($Framework32bitFolder, $Framework64bitFolder);
    }
    if (!(Test-Path $aspNetCacheFolder))
    {
        echo $"Folder $aspNetCacheFolder not found for removing $ControllerCacheFileName"
        return
    }
    echo $"Removing $ControllerCacheFileName files from ASP.NET cache folder $aspNetCacheFolder"
    Get-Childitem –Path $aspNetCacheFolder -Include $ControllerCacheFileName -Recurse | ForEach {
        $retrycount = 0
        $retries = 3
        $completed = $false

        while (-not $completed) {
            try {
                Remove-Item $_.FullName
                $completed = $true
            } catch {
                if ($retrycount -ge $retries) {
                    throw
                } else {
                    Start-Sleep 2
                    $retrycount++
                }
            }
        }
       
        echo $"Removed $ControllerCacheFileName"
    }
}

#create the proper web.config with configuration
AifabricFixedConfig
EmptyAspNetCache
Retry-IISRESET 3 2
Sleep 2
echo "Orchestrator configured successfully"