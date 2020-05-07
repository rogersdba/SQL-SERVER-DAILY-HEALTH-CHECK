/*
AUTHOR: SQLDBA ROBERT ROGERS
DATE: 5/6/2020
TOPIC: CREATE DAILY SQL SERVER HEALTH CHECK JOB

TIPS: 
1. CHANGE THE PARAMETER @owner_login_name=N'sa' TO YOUR PERFER ACCOUNT

*/


/****** Object:  Job [Daily_SQL_SERVER_HEALTH_CHECK]    Script Date: 5/5/2020 12:19:19 PM ******/
USE msdb ;  
GO  
  
EXEC sp_delete_job  
    @job_name = N'DAILY_SQL_SERVER_HEALTH_CHECK', @delete_unused_schedule=1
GO

/****** Object:  Job [DAILY_SQL_SERVER_HEALTH_CHECK]    Script Date: 5/6/2020 10:50:05 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Database Maintenance]    Script Date: 5/6/2020 10:50:05 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DAILY_SQL_SERVER_HEALTH_CHECK', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'Database Maintenance', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [SQL DAILY HEALTH CHECK]    Script Date: 5/6/2020 10:50:05 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'SQL DAILY HEALTH CHECK', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/*
AUTHOR: SQL DBA ROGERS
SUBJ: SQL SERVER DAILY HEALTH CHECK STEP 2

1. The script will delete all records in the daily health check tables older than 14 days. 
You can change the number of delete days via the declare statement.

2. The script will insert the current day records in the daily sql server health check tables.

DATE: 05/5/2020

select DATEADD(DAY, -7, GETDATE())
drop table sql_services_dailyhealth_check
select * from sql_services_dailyhealth_check
update sql_services_dailyhealth_check set date = ''2020-03-24 12:30:35.137''
delete sql_services_dailyhealth_check where date < @date
*/
------Change the use database(dba) statement to your database.
use dba

declare @date datetime
set @date = DATEADD(DAY, -14, GETDATE())


--INSERT AG HEALTHY RECORDS

delete sql_ag_dailyhealth_check where date < @date


USE [dba]

DECLARE @HADRSERVERNAME VARCHAR(25)
SET @HADRSERVERNAME = @@SERVERNAME
SELECT CLUSTERNODES.GROUP_NAME          AS [AVAILABILITY GROUP NAME],
       CLUSTERNODES.REPLICA_SERVER_NAME AS [AVAILABILITY REPLICA NAME],
       CLUSTERNODES.NODE_NAME           AS [AVAILABILITY NODE],
       RS.ROLE_DESC                     AS [ROLE],
       DB_NAME(DRS.DATABASE_ID)         AS [AVAILABILITY DATABASE],
       DRS.SYNCHRONIZATION_STATE_DESC   AS [SYNCHRONIZATION STATUS],
       DRS.SYNCHRONIZATION_HEALTH_DESC  AS [SYNCHRONIZATION HEALTH], GETDATE() as Date

into #ag

FROM   SYS.DM_HADR_AVAILABILITY_REPLICA_CLUSTER_NODES CLUSTERNODES
       JOIN SYS.DM_HADR_AVAILABILITY_REPLICA_CLUSTER_STATES CLUSTERSTATS
         ON CLUSTERNODES.REPLICA_SERVER_NAME = CLUSTERSTATS.REPLICA_SERVER_NAME
       JOIN SYS.DM_HADR_AVAILABILITY_REPLICA_STATES RS
         ON RS.REPLICA_ID = CLUSTERSTATS.REPLICA_ID
       JOIN SYS.DM_HADR_DATABASE_REPLICA_STATES DRS
         ON RS.REPLICA_ID = DRS.REPLICA_ID
WHERE  CLUSTERNODES.REPLICA_SERVER_NAME <> @HADRSERVERNAME



insert into dbo.sql_ag_dailyhealth_check
select * from #ag

drop table #ag


---INSERT SQL DATABASE BACKUP RECORDS
delete sql_backups_dailyhealth_check where date < @date

;WITH CTE_Backup AS
(
SELECT  @@servername as servername, database_name,backup_start_date,type,physical_device_name
       ,Row_Number() OVER(PARTITION BY database_name,BS.type
        ORDER BY backup_start_date DESC) AS RowNum
FROM    msdb..backupset BS
JOIN    msdb.dbo.backupmediafamily BMF
ON      BS.media_set_id=BMF.media_set_id
)
SELECT      servername, D.name
           ,ISNULL(CONVERT(VARCHAR,backup_start_date),''No backups'') AS last_backup_time
           ,D.recovery_model_desc
           ,state_desc, GETDATE() as date,
            CASE WHEN type =''D'' THEN ''Full database''
            WHEN type =''I'' THEN ''Differential database''
            WHEN type =''L'' THEN ''Log''
            WHEN type =''F'' THEN ''File or filegroup''
            WHEN type =''G'' THEN ''Differential file''
            WHEN type =''P'' THEN ''Partial''
            WHEN type =''Q'' THEN ''Differential partial''
            ELSE ''Unknown'' END AS backup_type
           ,physical_device_name

into #backups

FROM        sys.databases D

LEFT JOIN   CTE_Backup CTE
ON          D.name = CTE.database_name
AND         RowNum = 1
ORDER BY    D.name,type


insert into sql_backups_dailyhealth_check
select * from #backups

drop table #backups

----------INSERT DATABASE ONLINE RECORDS 

delete sql_databaseonline_dailyhealth_check where date < @date

INSERT INTO sql_databaseonline_dailyhealth_check
SELECT @@SERVERNAME as servername, name as Database_Name, state_desc as Database_Status, getdate() as date

FROM sys.databases


----------INSERT THE SQL JOBS RECORDS

delete sql_jobs_dailyhealth_check where date < @date

use msdb
SELECT 
@@servername as servername, name AS [Job Name], GETDATE() as date
         ,CONVERT(VARCHAR,DATEADD(S,(run_time/10000)*60*60 /* hours */
          +((run_time - (run_time/10000) * 10000)/100) * 60 /* mins */
          + (run_time - (run_time/100) * 100)  /* secs */
           ,CONVERT(DATETIME,RTRIM(run_date),113)),100) AS [Time Run]
         ,CASE WHEN enabled=1 THEN ''Enabled''
               ELSE ''Disabled''
          END [Job Status]
         ,CASE WHEN SJH.run_status=0 THEN ''Failed''
                     WHEN SJH.run_status=1 THEN ''Succeeded''
                     WHEN SJH.run_status=2 THEN ''Retry''
                     WHEN SJH.run_status=3 THEN ''Cancelled''
               ELSE ''Unknown''
          END [Job Outcome]

into #sqljobs

FROM   sysjobhistory SJH
JOIN   sysjobs SJ
ON     SJH.job_id=sj.job_id
WHERE  step_id=0
AND    DATEADD(S,
  (run_time/10000)*60*60 /* hours */
  +((run_time - (run_time/10000) * 10000)/100) * 60 /* mins */
  + (run_time - (run_time/100) * 100)  /* secs */,
  CONVERT(DATETIME,RTRIM(run_date),113)) >= DATEADD(d,-1,GetDate())
ORDER BY name,run_date,run_time

insert into DBA.DBO.sql_jobs_dailyhealth_check
select * from #sqljobs

drop table #sqljobs


-----------------------INSERT SQL LOGINS RECORDS
use dba

delete sql_logins_dailyhealth_check where date < @date

use dba

INSERT INTO sql_logins_dailyhealth_check

SELECT
@@servername as servername,
    DB_NAME(dbid) as DBName,
    COUNT(dbid) as NumberOfConnections,
    loginame as LoginName, GETDATE() as date

FROM
    sys.sysprocesses
WHERE
    dbid > 0
GROUP BY
    dbid, loginame


-----------------------INSERT SQL LUNS FREE SPACE RECORDS

delete sql_lunsfreespace_dailyhealth_check where date < @date
use dba 

INSERT INTO sql_lunsfreespace_dailyhealth_check

SELECT DISTINCT @@servername as name, vs.volume_mount_point, vs.file_system_type, vs.logical_volume_name,
CONVERT(DECIMAL(18,2), vs.total_bytes/1073741824.0) AS [Total Size (GB)],
CONVERT(DECIMAL(18,2), vs.available_bytes/1073741824.0) AS [Available Size (GB)],  
CONVERT(DECIMAL(18,2), vs.available_bytes * 1. / vs.total_bytes * 100.) AS [Space Free %],
vs.supports_compression, vs.is_compressed,
vs.supports_sparse_files, vs.supports_alternate_streams, getdate() as Date

FROM sys.master_files AS f WITH (NOLOCK)
CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.[file_id]) AS vs
ORDER BY vs.volume_mount_point OPTION (RECOMPILE);





-----------------------INSERT SQL READ AND WRITE RECORDS

delete sql_read_write_dailyhealth_check where date < @date

use dba 
INSERT INTO sql_read_write_dailyhealth_check


SELECT 
@@servername as name,
tab.[Drive], tab.volume_mount_point AS [Volume Mount Point],
    CASE
        WHEN num_of_reads = 0 THEN 0
        ELSE (io_stall_read_ms/num_of_reads)
    END AS [Read Latency],
    CASE
        WHEN num_of_writes = 0 THEN 0
        ELSE (io_stall_write_ms/num_of_writes)
    END AS [Write Latency],
    CASE
        WHEN (num_of_reads = 0 AND num_of_writes = 0) THEN 0
        ELSE (io_stall/(num_of_reads + num_of_writes))
    END AS [Overall Latency],
    CASE
        WHEN num_of_reads = 0 THEN 0
        ELSE (num_of_bytes_read/num_of_reads)
    END AS [Avg Bytes/Read],
    CASE
        WHEN num_of_writes = 0 THEN 0
        ELSE (num_of_bytes_written/num_of_writes)
    END AS [Avg Bytes/Write],
    CASE
        WHEN (num_of_reads = 0 AND num_of_writes = 0) THEN 0
        ELSE ((num_of_bytes_read + num_of_bytes_written)/(num_of_reads + num_of_writes))
    END AS [Avg Bytes/Transfer], getdate() as Date

	
	FROM (SELECT LEFT(UPPER(mf.physical_name), 2) AS Drive, SUM(num_of_reads) AS num_of_reads,
             SUM(io_stall_read_ms) AS io_stall_read_ms, SUM(num_of_writes) AS num_of_writes,
             SUM(io_stall_write_ms) AS io_stall_write_ms, SUM(num_of_bytes_read) AS num_of_bytes_read,
             SUM(num_of_bytes_written) AS num_of_bytes_written, SUM(io_stall) AS io_stall, vs.volume_mount_point
      FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
      INNER JOIN sys.master_files AS mf WITH (NOLOCK)
      ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id
      CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.[file_id]) AS vs
      GROUP BY LEFT(UPPER(mf.physical_name), 2), vs.volume_mount_point) AS tab
ORDER BY [Overall Latency] OPTION (RECOMPILE);





-----------------------INSERT SQL SERVICES AND AGENT RECORDS

delete sql_services_dailyhealth_check where date < @date

INSERT INTO sql_services_dailyhealth_check
select a.*, getdate() as Date, @@SERVERNAME as ''Database Instance Name''
from sys.dm_server_services a


/*
SELECT * FROM DBO.sql_ag_dailyhealth_check
SELECT * FROM DBO.sql_backups_dailyhealth_check
SELECT * FROM DBO.sql_databaseonline_dailyhealth_check
SELECT * FROM DBO.sql_jobs_dailyhealth_check
SELECT * FROM DBO.sql_logins_dailyhealth_check
SELECT * FROM DBO.sql_lunsfreespace_dailyhealth_check
SELECT * FROM DBO.sql_read_write_dailyhealth_check
SELECT * FROM DBO.sql_services_dailyhealth_check
*/', 
		@database_name=N'dba', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'DAILY_SQL_SERVER_HEALTH_CHECK', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20200505, 
		@active_end_date=99991231, 
		@active_start_time=60000, 
		@active_end_time=235959, 
		@schedule_uid=N'bc3d797c-e1da-4ca0-8db7-ee53d8c7bc07'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


