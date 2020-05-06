# SQL-SERVER-DAILY-HEALTH-CHECK
Perform a Daily Sql Server Health Check on your Sql Server 2012 version and above
The script will create the following tables and items.

SCRIPT 1:  Step1_Daily_Sql_Health_Check_Create
1. Check Sql Server services and agents
2. Check which Databases are online and offline
3. Check AlwaysOn High Avaliabiliy AG Health
4. Verify current day Database Backups
5. Check Sql Server Jobs
6. Check the current Sql Server Login Count
7. Check the current sql server databases Read & Write 
8. Check Sql Server Luns free space

SCRIPT 2: Step2_Daily_Sql_Health_Check_Insert
1. Insert the current day health check records into the tables. You can run this job manually or add the script to a sql jobs. 
2. The script also delete records that older than 14 days. You can change the days

SCRIPT 3: Step3_Daily_Sql_Health_Check_Job
1. Create a Sql Server job that execute script 2.

SCRIPT 4: Run a select statment to view the daily sql server health check records.
