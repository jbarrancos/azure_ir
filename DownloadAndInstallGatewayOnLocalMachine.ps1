#### Here is the usage doc:
#### PS D:\GitHub> .\DownloadAndInstallGatewayOnLocalMachine.ps1 <key>
####

param([string]$authKey)

function Download-LatestGateway()
{
    $latestGateway = Get-RedirectedUrl "https://go.microsoft.com/fwlink/?linkid=839822"
    $item = $latestGateway.split("/") | Select-Object -Last 1
    if ($item -eq $null -or $item -notlike "IntegrationRuntime*")
    {
        throw "Can't get latest gateway info"
    }

    $regexp = '^IntegrationRuntime_(\d+\.\d+\.\d+\.\d+)((?:\w|%20)+)\(64-bit\)\.msi$'

    $version = [regex]::Match($item, $regexp).Groups[1].Value
    if ($version -eq $null)
    {
        throw "Can't get version from gateway download uri"
    }

    $msg = "Latest gateway: " + $version
    Write-Host $msg
    
    Write-Host "Start to download MSI"
    $uri = Populate-Url $version
    $folder = New-TempDirectory
    $output = Join-Path $folder "IntegrationRuntime.msi"
    (New-Object System.Net.WebClient).DownloadFile($uri, $output)

    $exist = Test-Path($output)
    if ( $exist -eq $false)
    {
        throw "Cannot download specified MSI"
    }

    $msg = "New gateway MSI has been downloaded to " + $output
    Write-Host $msg
    return $output
    
}

function Get-RedirectedUrl 
{
    $URL = "https://go.microsoft.com/fwlink/?linkid=839822"
 
    $request = [System.Net.WebRequest]::Create($url)
    $request.AllowAutoRedirect=$false
    $response=$request.GetResponse()
 
    If ($response.StatusCode -eq "Found")
    {
        $response.GetResponseHeader("Location")
    }
}


function Populate-Url
{
    Param (
        [Parameter(Mandatory=$true)]
        [String]$version
    )
    
    $uri = Get-RedirectedUrl
    $uri = $uri.Substring(0, $uri.LastIndexOf('/') + 1)
    $uri += "IntegrationRuntime_$version ("
    
    $is64Bits = Is-64BitSystem
    if ($is64Bits)
    {
        $uri += "64-bit"
    }
    else
    {
        $uri += "32-bit"
    }
    $uri += ").msi"

    return $uri
}

function Install-Gateway([string] $gwPath)
{
    # uninstall any existing gateway
    UnInstall-Gateway

    Write-Host "Start Gateway installation"
    
    Start-Process "msiexec.exe" "/i $path /quiet /passive" -Wait
    Start-Sleep -Seconds 30	

    Write-Host "Succeed to install gateway"
}

function Register-Gateway([string] $key)
{
    Write-Host "Start to register gateway with key: $key"
    $cmd = Get-CmdFilePath
    Start-Process $cmd "-k $key" -Wait
    Write-Host "Succeed to register gateway"

}

function Check-WhetherGatewayInstalled([string]$name)
{
    $installedSoftwares = Get-ChildItem "hklm:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    foreach ($installedSoftware in $installedSoftwares)
    {
        $displayName = $installedSoftware.GetValue("DisplayName")
        if($DisplayName -eq "$name Preview" -or  $DisplayName -eq "$name")
        {
            return $true
        }
    }

    return $false
}


function UnInstall-Gateway()
{
    $installed = $false
    if (Check-WhetherGatewayInstalled("Microsoft Integration Runtime"))
    {
        [void](Get-WmiObject -Class Win32_Product -Filter "Name='Microsoft Integration Runtime Preview' or Name='Microsoft Integration Runtime'" -ComputerName $env:COMPUTERNAME).Uninstall()
        $installed = $true
    }

    if (Check-WhetherGatewayInstalled("Microsoft Integration Runtime"))
    {
        [void](Get-WmiObject -Class Win32_Product -Filter "Name='Microsoft Integration Runtime Preview' or Name='Microsoft Integration Runtime'" -ComputerName $env:COMPUTERNAME).Uninstall()
        $installed = $true
    }

    if ($installed -eq $false)
    {
        Write-Host "Microsoft Integration Runtime Preview is not installed."
        return
    }

    Write-Host "Microsoft Integration Runtime has been uninstalled from this machine."
}

function Get-CmdFilePath()
{
    $filePath = Get-ItemPropertyValue "hklm:\Software\Microsoft\DataTransfer\DataManagementGateway\ConfigurationManager" "DiacmdPath"
    if ([string]::IsNullOrEmpty($filePath))
    {
        throw "Get-InstalledFilePath: Cannot find installed File Path"
    }

    return $filePath
}

function Validate-Input([string]$key)
{
    if ([string]::IsNullOrEmpty($key))
    {
        throw "Gateway Auth key is empty"
    }
}

If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    Break
}

Validate-Input $authKey
$path=Download-LatestGateway
Install-Gateway $path
Register-Gateway $authKey
