#### Here is the usage doc:
#### PS D:\GitHub> .\DownloadAndInstallGatewayOnLocalMachine.ps1 <key>
####

param([string]$authKey)

function Download-LatestGateway()
{
    $latestGateway = Get-RedirectedUrl "https://go.microsoft.com/fwlink/?linkid=839822"
    if (!$?)
    {
        throw "Can't get latest gateway info"
    }

    $msg = "Latest gateway: $latestGateway"
    Write-Host $msg
    
    Write-Host "Start to download MSI"
    $uri = $latestGateway
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


function New-TempDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    New-Item -ItemType Directory -Path (Join-Path $parent $name)
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
