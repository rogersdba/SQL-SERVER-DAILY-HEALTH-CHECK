# SQL-SERVER-DAILY-HEALTH-CHECK
Perform a daily Sql Server Health Check on your Sql Server 2012 version and above
The script will create tables for the following items.
SCRIPT 1:  Step1_Daily_Sql_Health_Check_Create
1. Sql Server services and agents
2. Database online and offline
3. AlwaysOn High Avaliabiliy AG Health
4. Database Backups
5. Sql Server Jobs
6. Current Sql Server Login Count
7. Sql Server Read & Write 
8. Sql Server Luns free space

SCRIPT 2: Step2_Daily_Sql_Health_Check_Insert
1. Insert the current day health check records into the tables. You can run this job manually or add the script a sql jobs.

SCRIPT 3: Step3_Daily_Sql_Health_Check_Job
1. Create a Sql Server job that execute script 2.
