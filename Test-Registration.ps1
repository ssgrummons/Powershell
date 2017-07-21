<#
This script can be used on BigFix Authenticating Relays to test registration and send a report to NewRelic Insights via API.
Run it as a scheduled task in Windows to get regular reports in NewRelic.
The script will also attempt self-remediation by restarting the BES Relay Service.
#>
Function Send-RelayReport{
param(
     [Parameter(  
            Position = 0,  
            Mandatory = $True,  
            ParameterSetName = '')]  
            [string]$Component,
       [Parameter(  
            Position = 1,  
            Mandatory = $True,  
            ParameterSetName = '')]  
            [int]$ErrorState,
     [Parameter(  
            Position = 2,  
            Mandatory = $True,  
            ParameterSetName = '')]  
            [string]$HTTPStatus,
     [Parameter(  
            Position = 3,  
            Mandatory = $True,  
            ParameterSetName = '')]  
            [string]$HTTPResponse

)

$hostname = $env:computername
$apiKEY = "<INSERT NewRelic API Key>"
$uri = "https://insights-collector.newrelic.com/v1/accounts/<ACCOUNT>/events"

# Prepare JSON file to upload to New Relic Insight API
$body = @{

    eventType = "BigFixRelay"
    Server = "$hostname"
    Component = "$Component"
    ErrorState = $ErrorState
    HTTPStatus = "$HTTPStatus"
    HTTPResponse = "$HTTPResponse"

}

Write-Host "JSON file submitted to New Relic"
Write-Host (ConvertTo-Json $body)

# Post the event to the New Relic Insight API
Invoke-RestMethod -Method Post -Uri $uri -Body (ConvertTo-Json $body) -Header @{"X-Insert-Key"=$apiKey}
}

Function Test-RelayRegistration() 
{
$url = "https://127.0.0.1:52311/cgi-bin/bfenterprise/clientregister.exe?RequestType=RegisterMe60"
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
# First we create the request.
$HTTP_Request = [System.Net.WebRequest]::Create($url)
#Write-Host $HTTP_Request
# We then get a response from the site.
$HTTP_Response = $HTTP_Request.GetResponse()

# We then get the HTTP code as an integer.
$Script:HTTP_Status = [int]$HTTP_Response.StatusCode
Write-Host "Function returns the status from the relay"
write-host $HTTP_Status

If ($HTTP_Status -ne 0) {

    # Capture the data the server sends
    $HTTP_Stream = $HTTP_Response.GetResponseStream()
    $SR = new-object System.IO.StreamReader $HTTP_Stream
    $Script:Result = $SR.ReadToEnd()
    }
    Else{
    $Script:Result = "Relay Service Down"
    }
Write-Host "Function returns the response from the relay"
write-host $Result

# Finally, we clean up the http request by closing it.
$HTTP_Response.Close()

}

Test-RelayRegistration

# Capture error state output based on the HTTP Status Code.
If ($HTTP_Status -eq 200) { 
	$errorvalue = 0
    Send-RelayReport -Component "Registration" -ErrorState $errorvalue -HTTPStatus $HTTP_Status -HTTPResponse $Result
    Write-Host "Registration is functioning." 
    Write-Host $errorvalue
    Write-Host $HTTP_Status
    Write-Host $Result
}
Else {
	$errorvalue = 1
    Write-Host "Registration is down, please check!"
    Send-RelayReport "Registration" $errorvalue $HTTP_Status $Result
    Write-Host $errorvalue
    Write-Host $HTTP_Status
    Write-Host $Result
    Write-Host "Restarting BES Relay"
    Restart-Service besrelay
    Write-Host "Sleep for 1 minute"
    Start-Sleep -Seconds 60
    Test-RelayRegistration
    If ($HTTP_Status -eq 200) {
        $errorvalue = 0
        }
    Else {
        $errorvalue = 1
        }
    Send-RelayReport "Registration" $errorvalue $HTTP_Status $Result
}

