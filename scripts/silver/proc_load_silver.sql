/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process
    to populate the 'silver' schema tables from the 'bronze' schema.
	Actions Performed:
		- Truncates the silver tables before loading data.
		- Inserts transformed and cleansed data from bronze into silver tables.
 
Transformations Applied:
    - Removing duplicates (crm_cust_info via ROW_NUMBER)
    - Trimming extra whitespace from string fields
    - Standardizing coded values into readable labels (marital status,
      gender, product line, country)
    - Deriving product end dates from the next start date (crm_prd_info)
    - Validating and parsing date fields, nulling out invalid values
    - Recalculating sales and price where source values are missing,
      zero, negative, or inconsistent with quantity
 
Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.
 
Usage Example:
    EXEC silver.load_silver;
===============================================================================
*/


CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
	PRINT '>> Truncating Table: crm_cust_info';
	TRUNCATE TABLE silver.crm_cust_info;
	PRINT '>> Inserting Data Into Table: crm_cust_info';
	-- removing duplicates, removing extra spaces, standardizing columns
	INSERT INTO silver.crm_cust_info(
		cst_id,
		cst_key,
		cst_firstname,
		cst_lastname,
		cst_marital_status,
		cst_gndr,
		cst_create_date
	)
	SELECT 
		cst_id,
		cst_key,
		-- removing extra white spaces
		TRIM(cst_firstname) cst_firstname,
		TRIM(cst_lastname) cst_lastname,
		-- normalization / standardization
		CASE
			WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
			WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
			ELSE 'N/A' -- handling missing values
		END cst_marital_status,
		CASE 
			WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
			WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
			ELSE 'N/A'-- handling missing values
		END cst_gndr,
		cst_create_date
	FROM (
		-- removing duplicates
		SELECT 
			*,
			ROW_NUMBER()OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) flag
		FROM bronze.crm_cust_info
	) T
	WHERE flag = 1;


	PRINT '>> Truncating Table: crm_prd_info';
	TRUNCATE TABLE silver.crm_prd_info;
	PRINT '>> Inserting Data Into Table: crm_prd_info';
	INSERT INTO silver.crm_prd_info (
		prd_id,
		cat_id,
		prd_key,
		prd_nm,
		prd_cost,
		prd_line,
		prd_start_dt,
		prd_end_dt
	)
	SELECT
		prd_id,
		REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') cat_id, --extract cat id
		SUBSTRING(prd_key, 7, LEN(prd_key)) prd_key, -- extract prd key
		prd_nm,
		COALESCE(prd_cost, 0) prd_cost,
		CASE UPPER(TRIM(prd_line))
			WHEN 'M' THEN 'Mountain'
			WHEN 'R' THEN 'Road'
			WHEN 'S' THEN 'Other Sales'
			WHEN 'T' THEN 'Touring'
			ELSE 'NA'
		END prd_line,
		CAST(prd_start_dt AS DATE) prd_start_dt,
		CAST(LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt) - 1 AS DATE) prd_end_dt
	FROM bronze.crm_prd_info;


	PRINT '>> Truncating Table: crm_sales_details';
	TRUNCATE TABLE silver.crm_sales_details;
	PRINT '>> Inserting Data Into Table: crm_sales_details';
	INSERT INTO silver.crm_sales_details(
		sls_ord_num,
		sls_prd_key,
		sls_cust_id,
		sls_order_dt,
		sls_ship_dt,
		sls_due_dt,
		sls_sales,
		sls_quantity,
		sls_price

	)
	SELECT 
	   sls_ord_num,
	   sls_prd_key,
	   sls_cust_id,
	   CASE
			WHEN sls_order_dt =  0 OR LEN(sls_order_dt) != 8 THEN NULL
			ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
		END sls_order_dt,
		 CASE
			WHEN sls_ship_dt =  0 OR LEN(sls_ship_dt) != 8 THEN NULL
			ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
		END sls_ship_dt,
		CASE
			WHEN sls_due_dt =  0 OR LEN(sls_due_dt) != 8 THEN NULL
			ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
		END sls_due_dt,
		CASE 
			WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
				THEN  sls_quantity * ABS(sls_price)
			ELSE sls_sales
		END sls_sales,
		sls_quantity,
		CASE
			WHEN sls_price <= 0 OR sls_price IS NULL
				THEN sls_sales / NULLIF(sls_quantity, 0) --safeguard for div by 0
			ELSE sls_price
		END sls_price
	FROM bronze.crm_sales_details;


	PRINT '>> Truncating Table: erp_cust_az12';
	TRUNCATE TABLE silver.erp_cust_az12;
	PRINT '>> Inserting Data Into Table: erp_cust_az12';
	INSERT INTO silver.erp_cust_az12(
		cid,
		bdate,
		gen

	)
	SELECT
		CASE 
			WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
			ELSE cid
		END cid,
		CASE
			WHEN 
				bdate > GETDATE() THEN NULL
			ELSE bdate
		END bdate,
		CASE 
			WHEN UPPER(TRIM (gen)) IN ('F', 'FEMALE') THEN 'Female'
			WHEN UPPER(TRIM (gen)) IN ('M', 'MALE') THEN 'Male'
			ELSE 'n/a'
		END gen
	FROM bronze.erp_cust_az12;


	PRINT '>> Truncating Table: erp_loc_a10 ';
	TRUNCATE TABLE silver.erp_loc_a101;
	PRINT '>> Inserting Data Into Table: erp_loc_a10 ';
	INSERT INTO silver.erp_loc_a101(
		cid,
		cntry
	)
	SELECT
		REPLACE(cid, '-', '') cid,
		CASE 
			WHEN UPPER(TRIM(cntry)) IN ('USA', 'US', 'UNITED STATES') THEN 'United States'
			WHEN UPPER(TRIM(cntry)) IN ('DE', 'GERMANY') THEN 'Germany'
			WHEN cntry IS NULL OR UPPER(TRIM(cntry)) = '' THEN 'n/a'
			ELSE TRIM(cntry)
		END cntry
	FROM bronze.erp_loc_a101;


	PRINT '>> Truncating Table: erp_px_cat_g1v2';
	TRUNCATE TABLE silver.erp_px_cat_g1v2;
	PRINT '>> Inserting Data Into Table: erp_px_cat_g1v2';
	INSERT INTO silver.erp_px_cat_g1v2(
		id,
		cat,
		subcat,
		maintenance
	)
	SELECT
		id,
		cat,
		subcat,
		maintenance
	FROM bronze.erp_px_cat_g1v2
END

EXEC silver.load_silver
