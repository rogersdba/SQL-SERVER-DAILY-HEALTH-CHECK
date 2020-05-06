# SQL-SERVER-DAILY-HEALTH-CHECK
Are you a Senior Sql Server DBA or novice looking for a simple Daily Sql Server Health Check?   As a Senior dba for over 15 years the scripts below check some of items I check on a daily basis. 

Perform a Daily Sql Server Health Check on your Sql Server 2012 version and above.
The scripts will create the following tables and items.

SCRIPT 1: Step1_Daily_Sql_Health_Check_Create
1.	Verify your Sql Server services and agents are running
2.	Check which Databases are online and offline
3.	Check Always-on High Availability AG Health
4.	Verify the current day Database Backups
5.	Check Sql Server Jobs
6.	Check the current Sql Server Login Count
7.	Check the current Sql server databases Read & Write
8.	Check the Sql Server Luns free space

SCRIPT 2: Step2_Daily_Sql_Health_Check_Insert
1.	Insert the current day health check records into the health check tables. You can run this job manually or add the script to a Sql jobs.
2.	The script also deletes records that are older than 14 days. You can change the delete records date.

SCRIPT 3: Step3_Daily_Sql_Health_Check_Job (Optional)
1.	Create a Sql Server job that execute script 2.

SCRIPT 4: Step4_QUERY_DAILY_HEALTH_CHECK_TABLES
       1. Run select statements to view the daily Sql server health check records.

