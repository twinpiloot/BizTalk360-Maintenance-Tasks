[cmdletBinding()]
param(
    [Parameter(Mandatory=$true,HelpMessage="BizTalk360 EnvironmentId. See Settings -> API Documentation.")]
    [string]$BizTalk360EnvironmentId,

    [Parameter(Mandatory=$true,HelpMessage="Url of the server where BizTalk360 is installed, e.g. http://localhost.")]
    [string]$BizTalk360ServerUrl,

    [Parameter(Mandatory=$false,HelpMessage="This is the identifier from the SetAlertMaintenance task.")]
    [string]$MaintenanceId = ""
)

$ResponseSet = Invoke-RestMethod -Uri "$BizTalk360ServerUrl/BizTalk360/Services.REST/AdminService.svc/GetBizTalk360Info" -Method Get -UseDefaultCredentials
$ResponseSet | out-string
$BizTalk360Version = $ResponseSet.bizTalk360Info.biztalk360Version

## Between BizTalk360 9.0 and 9.1 a breaking change was done in the API
if ($BizTalk360Version -ge '9.1')
{
    $StopOperation = 'StopAlertMaintenance'
}
else
{
    $StopOperation = 'RemoveAlertMaintenance'
}

If ($MaintenanceId -eq "")
{
       Write-Host "MaintenanceId not specified. Trying to fetch latest from BizTalk360"
       $ResponseSet = Invoke-RestMethod -Uri "$BizTalk360ServerUrl/biztalk360/Services.REST/AlertService.svc/GetAlertMaintenance?environmentId=$BizTalk360EnvironmentId" -Method Get -UseDefaultCredentials
	   $ResponseSet | out-string

       $maintenance = @($ResponseSet.alertMaintenances | where { $_.comment -eq "BizTalk Deploy" })

       If ($maintenance.Count -gt 0)
       {
             $MaintenanceId = $maintenance[$maintenance.Count - 1].maintenanceId 
       }
}

$Request = '{
  "context": {
       "callerReference": "AzureDevOps",
       "environmentSettings": {
         "id": "' + $BizTalk360EnvironmentId + '"
       }
  },
  "maintenanceId": "' + $MaintenanceId + '",
  "comment": "BizTalk Deploy"
}'

Write-Host $Request

$ResponseSet = Invoke-RestMethod -Uri "$BizTalk360ServerUrl/biztalk360/Services.REST/AlertService.svc/$StopOperation" -Method Post -ContentType "application/json" -Body $Request -UseDefaultCredentials
$ResponseSet | out-string

If ($ResponseSet.success)
{
       Write-Host "BizTalk360 maintenance mode successfully disabled."
} 
