<#
This script is used to launch a custom certificate retrieval tool when the endpoint connects to the corporate network.
It can be run as a scheduled task that launches on login.
It will investigate whether or not the tool needs to be run by checking to see whether the certificate exists.
#>

function Get-CorporateIpAddress
{
Get-NetIPAddress | Where-Object {$_.AddressFamily -eq "IPv4"} | Where-Object {Check-IpRange $_.IPv4Address "10.0.0.0" "10.220.0.0"}
}

function Check-IpRange {
param(
        [string] $ipAddress,
        [string] $fromAddress,
        [string] $toAddress
    )

    $ip = [system.net.ipaddress]::Parse($ipAddress).GetAddressBytes()
    [array]::Reverse($ip)
    $ip = [system.BitConverter]::ToUInt32($ip, 0)

    $from = [system.net.ipaddress]::Parse($fromAddress).GetAddressBytes()
    [array]::Reverse($from)
    $from = [system.BitConverter]::ToUInt32($from, 0)

    $to = [system.net.ipaddress]::Parse($toAddress).GetAddressBytes()
    [array]::Reverse($to)
    $to = [system.BitConverter]::ToUInt32($to, 0)

    $from -le $ip -and $ip -le $to
}

function Get-WifiScheduledTask
{
Get-ScheduledTask -TaskName WiFiCert
}

function Validate-Certificate {
$date = Get-Date
set-location Cert:\CurrentUser\My
$wificert = get-childitem | where-object {$_.Issuer -like '*CN=Corporate CA, O=Corporation*' -and $_.NotAfter -gt $date}
if ($wificert -ne $null)
	{return $true}
else
	{return $false}
}

function Call-WiFiCertTool
{
$ibmWiFiFolder = "${Env:ProgramFiles(x86)}\IBM WiFi"
$ibmWiFiExe = "$ibmWiFiFolder\CreateCertUtil_0.70.exe"

if ($ibmIpAddress -ne $null)
	{
  Write-Host "Starting WiFi Cert Tool"
	[System.Diagnostics.Process]::Start($ibmWiFiExe).WaitForExit(300000)
	$certInstalled = Validate-Certificate #Change to specify success in boolean terms
  Write-Host "Wifi Certificate Installed: $certInstalled"
        Write-Host "Deleting Scheduled TaskTask"
		Get-WifiScheduledTask | Unregister-ScheduledTask -Confirm:$false  -ErrorAction SilentlyContinue
		if (Get-WifiScheduledTask -ne $null)
			{
            Write-Host "Task Not Deleted, attempting to disable"
			Get-WifiScheduledTask | Disable-ScheduledTask -ErrorAction SilentlyContinue
			}
    }
else 
    {
    exit
    }
}

$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference="Continue"
Start-Transcript -path .\wifitask-output.log -append

$ibmIpAddress = $null
while ($ibmIpAddress -eq $null)
	{
	Write-Host "DISCONNECTED"
	start-sleep -seconds 5
    $Locked = Get-Process logonui -ErrorAction SilentlyContinue
    $ibmIpAddress = Get-CorporateIpAddress
	}
Write-Host "ENDPOINT IS CONNECTED TO CORPORATE NETWORK"

Call-WiFiCertTool 

Stop-Transcript