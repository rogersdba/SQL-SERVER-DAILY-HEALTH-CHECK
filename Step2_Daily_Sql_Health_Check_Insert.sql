/*
AUTHOR: SQL DBA ROGERS
SUBJ: SQL SERVER DAILY HEALTH CHECK STEP 2

1. The script will delete all records in the daily health check tables older than 14 days. 
You can change the number of delete days via the declare statement.

2. The script will insert the current day records in the daily sql server health check tables.

DATE: 05/5/2020

select DATEADD(DAY, -7, GETDATE())
drop table sql_services_dailyhealth_check
select * from sql_services_dailyhealth_check
update sql_services_dailyhealth_check set date = '2020-03-24 12:30:35.137'
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
           ,ISNULL(CONVERT(VARCHAR,backup_start_date),'No backups') AS last_backup_time
           ,D.recovery_model_desc
           ,state_desc, GETDATE() as date,
            CASE WHEN type ='D' THEN 'Full database'
            WHEN type ='I' THEN 'Differential database'
            WHEN type ='L' THEN 'Log'
            WHEN type ='F' THEN 'File or filegroup'
            WHEN type ='G' THEN 'Differential file'
            WHEN type ='P' THEN 'Partial'
            WHEN type ='Q' THEN 'Differential partial'
            ELSE 'Unknown' END AS backup_type
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
         ,CASE WHEN enabled=1 THEN 'Enabled'
               ELSE 'Disabled'
          END [Job Status]
         ,CASE WHEN SJH.run_status=0 THEN 'Failed'
                     WHEN SJH.run_status=1 THEN 'Succeeded'
                     WHEN SJH.run_status=2 THEN 'Retry'
                     WHEN SJH.run_status=3 THEN 'Cancelled'
               ELSE 'Unknown'
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
select a.*, getdate() as Date, @@SERVERNAME as 'Database Instance Name'
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
*/