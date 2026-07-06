/*
=============================================================
Create Database and Schemas
=============================================================
Script Purpose:
    Creates a new database named 'data_warehouse' after checking 
    if it already exists. If the database exists, it is dropped 
    and recreated. The script also sets up three schemas within 
    the database: 'bronze', 'silver', and 'gold', following the 
    medallion architecture pattern.

WARNING:
    Running this script will drop the entire 'data_warehouse' 
    database if it exists. All data in the database will be 
    permanently deleted. 
=============================================================
*/

-- Dropping and recreating the 'data_warehouse' db
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'data_warehouse')
BEGIN
	ALTER DATABASE data_warehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DROP DATABASE data_warehouse
END;
GO

-- Creating the 'data_warehouse' db
CREATE DATABASE data_warehouse;
GO

USE data_warehouse;
GO
  
-- Creating schemas
CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO
