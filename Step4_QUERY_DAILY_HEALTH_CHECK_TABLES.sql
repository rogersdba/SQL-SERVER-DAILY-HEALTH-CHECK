/*
AUTHOR: SQLDBA ROGERS
SUBJECT: QUERY DAILY HEALTH CHECK TABLES
DATE: 05/05/2020

*/


------------QUERY ALL THE RECORDS IN THE DAILY SQL HEALTH CHECK TABLES
USE dba ----CHANGE TO YOUR DATABASES

SELECT * FROM DBO.sql_services_dailyhealth_check
SELECT * FROM DBO.sql_databaseonline_dailyhealth_check
SELECT * FROM DBO.sql_ag_dailyhealth_check
SELECT * FROM DBO.sql_jobs_dailyhealth_check
SELECT * FROM DBO.sql_backups_dailyhealth_check
SELECT * FROM DBO.sql_logins_dailyhealth_check
SELECT * FROM DBO.sql_lunsfreespace_dailyhealth_check
SELECT * FROM DBO.sql_read_write_dailyhealth_check


------------QUERY THE RECORDS FOR 7 DAYS BACK IN THE DAILY SQL HEALTH CHECK TABLES
USE dba  ----CHANGE TO YOUR DATABASES

SELECT * FROM DBO.sql_services_dailyhealth_check WHERE DATE BETWEEN GETDATE() - 7 AND GETDATE()
SELECT * FROM DBO.sql_databaseonline_dailyhealth_check WHERE DATE BETWEEN GETDATE() - 7 AND GETDATE()
SELECT * FROM DBO.sql_ag_dailyhealth_check WHERE DATE BETWEEN GETDATE() - 7 AND GETDATE()
SELECT * FROM DBO.sql_jobs_dailyhealth_check WHERE DATE BETWEEN GETDATE() - 7 AND GETDATE()
SELECT * FROM DBO.sql_backups_dailyhealth_check WHERE DATE BETWEEN GETDATE() - 7 AND GETDATE()
SELECT * FROM DBO.sql_logins_dailyhealth_check WHERE DATE BETWEEN GETDATE() - 7 AND GETDATE()
SELECT * FROM DBO.sql_lunsfreespace_dailyhealth_check WHERE DATE BETWEEN GETDATE() - 7 AND GETDATE()
SELECT * FROM DBO.sql_read_write_dailyhealth_check WHERE DATE BETWEEN GETDATE() - 7 AND GETDATE()


------------QUERY THE RECORDS FOR 14 DAYS BACK IN THE DAILY SQL HEALTH CHECK TABLES
USE dba  ----CHANGE TO YOUR DATABASES

SELECT * FROM DBO.sql_services_dailyhealth_check WHERE DATE BETWEEN GETDATE() - 14 AND GETDATE()
SELECT * FROM DBO.sql_databaseonline_dailyhealth_check WHERE DATE BETWEEN GETDATE() - 14 AND GETDATE()
SELECT * FROM DBO.sql_ag_dailyhealth_check WHERE DATE BETWEEN GETDATE() - 14 AND GETDATE()
SELECT * FROM DBO.sql_jobs_dailyhealth_check WHERE DATE BETWEEN GETDATE() - 14 AND GETDATE()
SELECT * FROM DBO.sql_backups_dailyhealth_check WHERE DATE BETWEEN GETDATE() - 14 AND GETDATE()
SELECT * FROM DBO.sql_logins_dailyhealth_check WHERE DATE BETWEEN GETDATE() - 14 AND GETDATE()
SELECT * FROM DBO.sql_lunsfreespace_dailyhealth_check WHERE DATE BETWEEN GETDATE() - 14 AND GETDATE()
SELECT * FROM DBO.sql_read_write_dailyhealth_check WHERE DATE BETWEEN GETDATE() - 14 AND GETDATE()