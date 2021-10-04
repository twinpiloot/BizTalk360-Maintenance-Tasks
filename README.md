# BizTalk360-Maintenance-Tasks

These tasks can be used in Azure DevOps release pipelines to set BizTalk360 in maintenance mode.
You can only use these tasks if you have a license to use the BizTalk360 APIs.

A typical scenario for using these tasks is to define a release where you set BizTalk360
in maintenance mode at the beginning and unset it at the end of the release.

![](https://github.com/twinpiloot/BizTalk360-Maintenance-Tasks/blob/master/taskgroup.PNG?raw=true)

In a multi server environment you need multiple jobs, so it is difficult to pass the maintenanceId
as a variable from one job to another (it is possible with YAML pipelines).
If you do not specify a MaintenanceId, the task will query BizTalk360 for the latest maintenance.

There is also a new task called UpdateBizTalk360Mappings. In BizTalk360 you need to define mappings for your alarms.
Using this task, these mappings will be created automatically when you specify which alarm must be used.
This alarm must exist and can be specified with the "BizTalk360_alertName" parameter in the BTDF settings file.

The following snippet is part of a YAML pipeline which uses all tasks in a typical scenario:
```
- stage: Prod
  condition: and(not(failed()), eq(variables['Build.SourceBranch'], 'refs/heads/master'))
  variables:
    BizTalk360EnvironmentId: ''
    BizTalk360ServerUrl: ''
  jobs:
  - deployment: DeployJobNonMgmtDB
    pool:
      name: BizTalk Deploy Prod Non-Mgmt
      demands: msbuild
    environment: 'Prod'
    strategy:
      runOnce:
        deploy:
          steps:
          - task: SetAlertMaintenance@2
            name: SetAlertMaintenance
            inputs:
              BizTalk360EnvironmentId: $(BizTalk360EnvironmentId)
              BizTalk360ServerUrl: $(BizTalk360ServerUrl)
          - template: biztalk.steps.yml
            parameters:
              environment: 'Prod'
              deployMgmtDB: false
  - deployment: DeployJobMgmtDB
    pool:
      name: BizTalk Deploy Prod Mgmt
      demands: msbuild
    environment: 'Prod'
    dependsOn: DeployJobNonMgmtDB
    variables:
      MaintenanceId: $[ dependencies.DeployJobNonMgmtDB.outputs['DeployJobNonMgmtDB.SetAlertMaintenance.MaintenanceId'] ]
    strategy:
      runOnce:
        deploy:
          steps:
          - template: biztalk.steps.yml
            parameters:
              environment: 'Prod'
              deployMgmtDB: true
          - task: UpdateBizTalk360Mappings@1
            continueOnError: true
            inputs:
              BizTalk360EnvironmentId: '$(BizTalk360EnvironmentId)'
              BizTalk360ServerUrl: '$(BizTalk360ServerUrl)'
              ApplicationPath: 'E:\Program Files (x86)\$(Build.DefinitionName) for BizTalk $(Build.BuildNumber)'
              SettingsFile: 'Exported_ProdSettings.xml'
          - task: RemoveAlertMaintenance@2
            inputs:
              BizTalk360EnvironmentId: $(BizTalk360EnvironmentId)
              BizTalk360ServerUrl: $(BizTalk360ServerUrl)
              MaintenanceId: $(MaintenanceId)
```
