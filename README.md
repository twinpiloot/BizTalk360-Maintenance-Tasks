# BizTalk360-Maintenance-Tasks

These tasks can be used in Azure DevOps release pipelines to set BizTalk360 in maintenance mode.
You can only use these tasks if you have a license to use the BizTalk360 APIs.

A typical scenario for using these tasks is to define a release where you set BizTalk360
in maintenance mode at the beginning and unset it at the end of the release.

![](https://github.com/twinpiloot/BizTalk360-Maintenance-Tasks/blob/master/taskgroup.PNG)

In a multi server environment you need multiple jobs, so it is difficult to pass the maintenanceId
as a variable from one job to another (it is possible with YAML pipelines).
If you do not specify a MaintenanceId, the task will query BizTalk360 for the latest maintenance.
