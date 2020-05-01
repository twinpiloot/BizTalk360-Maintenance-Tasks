[cmdletBinding()]
param(
    [Parameter(Mandatory=$true,HelpMessage="BizTalk360 EnvironmentId. See Settings -> API Documentation.")]
    [string]$BizTalk360EnvironmentId,

    [Parameter(Mandatory=$true,HelpMessage="Hostname of the server where BizTalk360 is installed.")]
    [string]$BizTalk360ServerName
)

$DateTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.000"

$Request = '{
  "context": {
    "callerReference": "AzureDevOps",
    "environmentSettings": {
      "id": "' + $BizTalk360EnvironmentId + '"
    }
  },
  "alertMaintenance": {
    "comment": "BizTalk Deploy",
    "maintenanceStartTime": "' + $DateTime + '",
    "maintenanceTimeUnit": 0,
    "maintenanceTimeLength": 60,
    "isActive": true,
    "expiryDateTime": ""
  }
}'

Write-Host $Request
$ResponseSet = Invoke-RestMethod -Uri "http://$BizTalk360ServerName/biztalk360/Services.REST/AlertService.svc/SetAlertMaintenance" -Method Post -ContentType "application/json" -Body $Request -UseDefaultCredentials
$ResponseSet

If ($ResponseSet.success)
{
    $maintenanceId = $ResponseSet.alertMaintenance.maintenanceId
    Write-Host "BizTalk360 maintenance mode successfully enabled, maintenanceId = $maintenanceId"
    Write-Host "##vso[task.setvariable variable=MaintenanceId;isOutput=true]$maintenanceId"
}
