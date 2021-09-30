[cmdletBinding()]
param(
    [Parameter(Mandatory=$true,HelpMessage="BizTalk360 EnvironmentId. See Settings -> API Documentation.")]
    [string]$BizTalk360EnvironmentId,

    [Parameter(Mandatory=$true,HelpMessage="Url of the server where BizTalk360 is installed, e.g. http://localhost.")]
    [string]$BizTalk360ServerUrl,

    [Parameter(Mandatory=$true,HelpMessage="Path of the PortBindings file.")]
    [string]$ApplicationPath,

    [Parameter(Mandatory=$true,HelpMessage="Path of the exported settings file.")]
    [string]$SettingsFile
)

$BindingsFile = Get-ChildItem -Path $ApplicationPath -Filter 'PortBindings.xml' -Recurse | Select-Object -ExpandProperty FullName -First 1
$SettingsPath = Get-ChildItem -Path $ApplicationPath -Filter $SettingsFile -Recurse | Select-Object -ExpandProperty FullName -First 1

## Check if the alarm in specified in the settings. Skip the update if it is not specified.
[xml]$XmlDocument = Get-Content $SettingsPath
$alarmName = $XmlDocument.SelectNodes("/settings/property[@name='BizTalk360_alertName']").'#text'

If (-not $alarmName)
{
    Write-Host "Setting BizTalk360_alertName not found in settings file. Skipping BizTalk360 alarm mappings update." 
    return
}

## Fetch the AlarmId of the Alarm.
Write-Host "$BizTalk360ServerUrl/BizTalk360/Services.REST/AlertService.svc/GetUserAlarms?environmentId=$BizTalk360EnvironmentId"
$response = Invoke-RestMethod "$BizTalk360ServerUrl/BizTalk360/Services.REST/AlertService.svc/GetUserAlarms?environmentId=$BizTalk360EnvironmentId" -Method "GET" -UseDefaultCredentials
$response | out-string
$alarm = $response.userAlarms | Where-Object name -eq $alarmName
$alarmId = $alarm.alarmId

If (-Not $alarmId)
{
    Write-Host "Alarm $alarmName not found in BizTalk360. Skipping BizTalk360 alarm mappings update." 
    return
}

Write-Host "Remove mappings for alarm $alarmName"

## Use the bindingsfile to find the application name and the settings.
[xml]$XmlDocument = Get-Content $BindingsFile
$applicationRefs = $XmlDocument.GetElementsByTagName("ApplicationName")

If ($applicationRefs.Count -eq 0)
{
    Write-Host "ApplicationName element not found in PortBindings file." 
    return
}

$applicationName = $applicationRefs[0].'#text'
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/json")

## Remove the existing mappings. This avoids orphaned artifacts.
$body = @"
{
    "context": {
        "callerReference": "Azure DevOps",
        "environmentSettings": {
            "id": "$BizTalk360EnvironmentId"
        }
    },
    "applicationNames": [
        "$applicationName"
    ]
}
"@
$response = Invoke-RestMethod "$BizTalk360ServerUrl/BizTalk360/Services.REST/AlertService.svc/RemoveOrphanedApplication" -Method "POST" -Headers $headers -Body $body -UseDefaultCredentials
$response | ConvertTo-Json

Write-Host "Update mappings for orchestrations"
$orchestrations = $XmlDocument.SelectNodes("/BindingInfo/ModuleRefCollection/ModuleRef[substring(@Name, string-length(@Name) - string-length('.Orchestrations') + 1) = '.Orchestrations']")
$assemblyName = $orchestrations.FullName

Foreach ($orchestration in $orchestrations.Services.Service)
{
    $orchestrationName = $orchestration.Name

    $body = @"
    {
        "context": {
            "callerReference": "Azure DevOps",
            "environmentSettings": {
                "id": "$BizTalk360EnvironmentId"
            }
        },
        "operation": 0,
        "monitorGroupName": "$applicationName",
        "monitorGroupType": "Application",
        "monitorName": "Orchestrations",
        "alarmId": "$alarmId",
        "comment": "BTDF Deployment",
        "serializedJsonMonitorConfig": "[{\"expectedState\":2,\"name\":\"$orchestrationName\",\"status\":1,\"applicationName\":\"$applicationName\",\"assemblyQualifiedName\":\"$orchestrationName,$assemblyName\"}]"
    }
"@
    $response = Invoke-RestMethod "$BizTalk360ServerUrl/BizTalk360/Services.REST/AlertService.svc/ManageAlertMonitorConfig" -Method "POST" -Headers $headers -Body $body -UseDefaultCredentials
    $response | ConvertTo-Json
}

Write-Host "Update mappings for receive locations"
## Add mapping for the receive locations. Note that the BizTalk360 API requires more parameters than the name only.
## Therefore the parameters are taken from the Bindings file.
Foreach ($receivePort in $XmlDocument.BindingInfo.ReceivePortCollection.ReceivePort)
{
    $receivePortName = $receivePort.Name

    Foreach ($receiveLocation in $receivePort.ReceiveLocations.ReceiveLocation)
    {
        $receiveLocationName = $receiveLocation.Name
        $address = $receiveLocation.Address.Replace('\', '\\\\')
        $isPrimary = $receiveLocation.Primary
        $isEnabled = $receiveLocation.Enable
        $isTwoWay = $receivePort.IsTwoWay
        $receiveHandlerName = $receiveLocation.ReceiveHandler.Name
        $transportTypeName = $receiveLocation.ReceiveHandler.TransportType.Name

        $body = @"
        {
          "context": {
            "callerReference": "Azure DevOps",
            "environmentSettings": {
              "id": "$BizTalk360EnvironmentId"
            }
          },
          "operation": 0,
          "monitorGroupName": "$applicationName",
          "monitorGroupType": "Application",
          "monitorName": "ReceiveLocations",
          "alarmId": "$alarmId",
          "comment": "BTDF Deployment",
          "serializedJsonMonitorConfig": "[{\"name\":\"$receiveLocationName\",\"receivePortName\":\"$receivePortName\",\"expectedState\":\"Enabled\",\"applicationName\":\"$applicationName\",\"address\":\"$address\",\"isPrimary\":$isPrimary,\"isEnabled\":$isEnabled,\"isTwoWay\":$isTwoWay,\"receiveHandler\":{\"hostName\":\"$receiveHandlerName\",\"transportType\":{\"name\":\"$transportTypeName\"}}}]"
        }
"@
        $response = Invoke-RestMethod "$BizTalk360ServerUrl/BizTalk360/Services.REST/AlertService.svc/ManageAlertMonitorConfig" -Method "POST" -Headers $headers -Body $body -UseDefaultCredentials
        $response | ConvertTo-Json
    }
}

Write-Host "Update mappings for send ports"
Foreach ($sendPort in $XmlDocument.BindingInfo.SendPortCollection.SendPort)
{
    $sendPortName = $sendPort.Name

    $body = @"
    {
        "context": {
            "callerReference": "Azure DevOps",
            "environmentSettings": {
                "id": "$BizTalk360EnvironmentId"
            }
        },
        "operation": 0,
        "monitorGroupName": "$applicationName",
        "monitorGroupType": "Application",
        "monitorName": "SendPorts",
        "alarmId": "$alarmId",
        "comment": "BTDF Deployment",
        "serializedJsonMonitorConfig": "[{\"name\":\"$sendPortName\",\"expectedState\":\"Started\",\"applicationName\":\"$applicationName\"}]"
    }
"@
    $response = Invoke-RestMethod "$BizTalk360ServerUrl/BizTalk360/Services.REST/AlertService.svc/ManageAlertMonitorConfig" -Method "POST" -Headers $headers -Body $body -UseDefaultCredentials
    $response | ConvertTo-Json
}

