/*
AUTHOR: SQL DBA ROGERS
SUBJ: SQL DAILY HEALTH CHECKS STEP 1
THE SCRIPT WILL CREATE 8 TABLES IN THE DBA DATABASE

DATE: 05/05/2020

select DATEADD(DAY, -14, GETDATE())
drop table sql_services_dailyhealth_check
select * from sql_services_dailyhealth_check
update sql_services_dailyhealth_check set date = '2020-03-24 12:30:35.137'
delete sql_services_dailyhealth_check where date < @date

declare @date datetime
set @date = DATEADD(DAY, -7, GETDATE())

*/


-----CHANGE THE USE STATEMENT TO THE DATABASE YOU WOULD LIKE TO CREATE THE SQL DAILY HEALTH CHECK TABLE
use dba

---Verify all sql server services and agents are running

if EXISTS (SELECT * from sys.objects WHERE name = 'sql_services_dailyhealth_check' and type = 'u')
    DROP TABLE sql_services_dailyhealth_check;

select a.*, getdate() as Date, @@SERVERNAME as 'Database Instance Name' 
into sql_services_dailyhealth_check
from sys.dm_server_services a


---Verify all databases are online
if EXISTS (SELECT * from sys.objects WHERE name = 'sql_databaseonline_dailyhealth_check' and type = 'u')
    DROP TABLE sql_databaseonline_dailyhealth_check;

SELECT @@SERVERNAME as servername, name as Database_Name, state_desc as Database_Status, getdate() as date
into sql_databaseonline_dailyhealth_check
FROM sys.databases

go

---Create Sql Jobs table. The script work for version Sql Server 2016 and above.
use dba

if EXISTS (SELECT * from sys.objects WHERE name = 'sql_jobs_dailyhealth_check' and type = 'u')
    DROP TABLE sql_jobs_dailyhealth_check;

use msdb

SELECT @@servername as servername, name AS [Job Name], GETDATE() as date
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

into dba.dbo.sql_jobs_dailyhealth_check

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

go

----Create sql server database backup table.

use dba

if EXISTS (SELECT * from sys.objects WHERE name = 'sql_backups_dailyhealth_check' and type = 'u')
    DROP TABLE sql_backups_dailyhealth_check;



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

into dba.dbo.sql_backups_dailyhealth_check

FROM        sys.databases D

LEFT JOIN   CTE_Backup CTE
ON          D.name = CTE.database_name
AND         RowNum = 1
ORDER BY    D.name,type



----Create Sql Server Login table

use dba

if EXISTS (SELECT * from sys.objects WHERE name = 'sql_logins_dailyhealth_check' and type = 'u')
    DROP TABLE sql_logins_dailyhealth_check;

SELECT @@servername as servername,
    DB_NAME(dbid) as DBName,
    COUNT(dbid) as NumberOfConnections,
    loginame as LoginName, GETDATE() as date

into dba.dbo.sql_logins_dailyhealth_check

FROM
    sys.sysprocesses
WHERE
    dbid > 0
GROUP BY
    dbid, loginame


---Create Sql Server High avalaibility AG Groups

use dba 

if EXISTS (SELECT * from sys.objects WHERE name = 'sql_ag_dailyhealth_check' and type = 'u')
    DROP TABLE sql_ag_dailyhealth_check;

DECLARE @HADRSERVERNAME VARCHAR(25)
SET @HADRSERVERNAME = @@SERVERNAME
SELECT CLUSTERNODES.GROUP_NAME          AS [AVAILABILITY GROUP NAME],
       CLUSTERNODES.REPLICA_SERVER_NAME AS [AVAILABILITY REPLICA NAME],
       CLUSTERNODES.NODE_NAME           AS [AVAILABILITY NODE],
       RS.ROLE_DESC                     AS [ROLE],
       DB_NAME(DRS.DATABASE_ID)         AS [AVAILABILITY DATABASE],
       DRS.SYNCHRONIZATION_STATE_DESC   AS [SYNCHRONIZATION STATUS],
       DRS.SYNCHRONIZATION_HEALTH_DESC  AS [SYNCHRONIZATION HEALTH], GETDATE() as Date

	   into dba.dbo.sql_ag_dailyhealth_check

FROM   SYS.DM_HADR_AVAILABILITY_REPLICA_CLUSTER_NODES CLUSTERNODES
       JOIN SYS.DM_HADR_AVAILABILITY_REPLICA_CLUSTER_STATES CLUSTERSTATS
         ON CLUSTERNODES.REPLICA_SERVER_NAME = CLUSTERSTATS.REPLICA_SERVER_NAME
       JOIN SYS.DM_HADR_AVAILABILITY_REPLICA_STATES RS
         ON RS.REPLICA_ID = CLUSTERSTATS.REPLICA_ID
       JOIN SYS.DM_HADR_DATABASE_REPLICA_STATES DRS
         ON RS.REPLICA_ID = DRS.REPLICA_ID
WHERE  CLUSTERNODES.REPLICA_SERVER_NAME <> @HADRSERVERNAME

/*
-- Create LUNS free space table
-- Check free space on all LUNS that have database files on the current instance (Query 26) (Volume Info)
-- Shows you the total and free space on the LUNs where you have database files

*/

use dba 

if EXISTS (SELECT * from sys.objects WHERE name = 'sql_lunsfreespace_dailyhealth_check' and type = 'u')
    DROP TABLE sql_lunsfreespace_dailyhealth_check;


SELECT DISTINCT @@servername as name, vs.volume_mount_point, vs.file_system_type, vs.logical_volume_name,
CONVERT(DECIMAL(18,2), vs.total_bytes/1073741824.0) AS [Total Size (GB)],
CONVERT(DECIMAL(18,2), vs.available_bytes/1073741824.0) AS [Available Size (GB)],  
CONVERT(DECIMAL(18,2), vs.available_bytes * 1. / vs.total_bytes * 100.) AS [Space Free %],
vs.supports_compression, vs.is_compressed,
vs.supports_sparse_files, vs.supports_alternate_streams, getdate() as Date

into dba.dbo.sql_lunsfreespace_dailyhealth_check

FROM sys.master_files AS f WITH (NOLOCK)
CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.[file_id]) AS vs
ORDER BY vs.volume_mount_point OPTION (RECOMPILE);
------


/*
-- Create Read and Write lateancy table
-- Latency above 30-40 ms is usually a problem
-- The database files on each drive show numbers since SQL Server was last started
*/

go

use dba 

if EXISTS (SELECT * from sys.objects WHERE name = 'sql_read_write_dailyhealth_check' and type = 'u')
    DROP TABLE sql_read_write_dailyhealth_check;


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

	into dba.dbo.sql_read_write_dailyhealth_check
	
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
------

