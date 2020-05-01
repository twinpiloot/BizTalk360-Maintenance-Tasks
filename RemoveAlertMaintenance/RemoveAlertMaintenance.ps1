[cmdletBinding()]
param(
    [Parameter(Mandatory=$true,HelpMessage="BizTalk360 EnvironmentId. See Settings -> API Documentation.")]
    [string]$BizTalk360EnvironmentId,

    [Parameter(Mandatory=$true,HelpMessage="Hostname of the server where BizTalk360 is installed.")]
    [string]$BizTalk360ServerName,

    [Parameter(Mandatory=$false,HelpMessage="This is the identifier from the SetAlertMaintenance task.")]
    [string]$MaintenanceId = ""
)

If ($MaintenanceId -eq "")
{
	Write-Host "MaintenanceId not specified. Trying to fetch latest from BizTalk360"
	$ResponseSet = Invoke-RestMethod -Uri "http://$BizTalk360ServerName/biztalk360/Services.REST/AlertService.svc/GetAlertMaintenance?environmentId=$BizTalk360EnvironmentId" -Method Get -UseDefaultCredentials

	$maintenance = $ResponseSet.alertMaintenances | where { $_.comment -eq "BizTalk Deploy" } 

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
  "maintenanceId": "' + $MaintenanceId + '"
}'

Write-Host $Request

$ResponseSet = Invoke-RestMethod -Uri "http://$BizTalk360ServerName/biztalk360/Services.REST/AlertService.svc/RemoveAlertMaintenance" -Method Post -ContentType "application/json" -Body $Request -UseDefaultCredentials

If ($ResponseSet.success)
{
	Write-Host "BizTalk360 maintenance mode successfully disabled."
}