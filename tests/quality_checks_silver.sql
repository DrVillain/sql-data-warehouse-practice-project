/*
===============================================================================
Quality Checks: Silver Layer
===============================================================================
Purpose:
    This script runs a series of data quality checks against the 'silver'
    schema tables to validate consistency, accuracy, and standardization
    after the bronze-to-silver load.
 
Checks Performed:
    - Duplicate or null primary keys
    - Unwanted leading/trailing whitespace in string fields
    - Standardization of coded values (gender, marital status, country)
    - Null or negative values in numeric fields
    - Invalid or out-of-range dates
    - Invalid date order (e.g., end date before start date, order date
      after ship/due date)
    - Data consistency between related fields (sales = quantity * price)
 
Usage Notes:
    - Run this script after executing silver.load_silver.
    - Any rows returned by these checks indicate data that still needs
      investigation or additional cleansing logic upstream.
===============================================================================
*/

/*
	===============================
	Checking: silver.crm_cust_info 
	===============================
*/

-- duplicate check
SELECT 
	cst_id,
	COUNT(*) cnt
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1;

-- extra space check
SELECT cst_firstname
FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

SELECT cst_lastname
FROM silver.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname);

-- standardization
SELECT DISTINCT cst_gndr
FROM silver.crm_cust_info;

SELECT DISTINCT cst_marital_status
FROM silver.crm_cust_info;


/*
	===============================
	Checking: silver.crm_prd_info 
	===============================
*/

-- duplicate check
SELECT
	prd_id,
	COUNT(*) cnt
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;


-- white space check
SELECT prd_nm
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

-- check for nulls or negative numbers
SELECT prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

-- check for invalid date orders
-- in this case the end date is b4 the start date and has to be fixed
SELECT *
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;


/*
	===============================
	Checking: silver.crm_sales_details 
	===============================
*/

-- invalid date check
SELECT
	NULLIF(sls_due_dt, 0) sls_due_dt -- 0s become nulls
FROM silver.crm_sales_details
WHERE sls_due_dt <= 0 -- checking for nulls
	OR LEN(sls_due_dt) != 8 -- in case the date is longer than 8 digits
	OR sls_due_dt > 20500101 -- comparing to extremes
	OR sls_due_dt < 19000101;


-- invalid date orders check
SELECT 
	*
FROM silver.crm_sales_details
WHERE
	sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt;
	-- checking if an order date is greater than a ship or due date
	-- which should not happen

-- checking data consistency between sales, quantity, and price
-- sales must be sales = quantity * price
-- sales cannot be negative, 0 or null
SELECT DISTINCT
	sls_sales old_sales,
	sls_quantity,
	sls_price old_price,
	CASE 
		WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
			THEN  sls_quantity * ABS(sls_price)
		ELSE sls_sales
	END sls_sales,
	CASE
		WHEN sls_price <= 0 OR sls_price IS NULL
			THEN sls_sales / NULLIF(sls_quantity, 0) --safeguard for div by 0
		ELSE sls_price
	END sls_price
FROM silver.crm_sales_details
WHERE 
	sls_sales <= 0 
	OR sls_quantity <= 0
	OR sls_price <= 0
	OR sls_sales IS NULL
	OR sls_quantity IS NULL
	OR sls_price IS NULL
	OR sls_sales != sls_quantity * sls_price;


/*
	===============================
	Checking: silver.erp_cust_az12 
	===============================
*/

-- normalizing the cid by removing unwanted chars
SELECT
	DISTINCT LEN(cid)
FROM (
	SELECT
		CASE 
			WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
			ELSE cid
		END cid,
		bdate,
		CASE 
			WHEN gen = 'F' THEN 'Female'
			WHEN gen = 'M' THEN 'Male'
			WHEN gen IS NULL THEN 'N/A'
			WHEN gen = ' ' THEN 'N/A'
			ELSE gen
		END gen
	FROM silver.erp_cust_az12
)O;

-- identify out of range dates
SELECT DISTINCT bdate
FROM silver.erp_cust_az12
WHERE bdate < '1924-01-01' OR bdate > GETDATE();


-- standardizing the gender column
SELECT distinct gen
FROM (
	SELECT
		cid,
		bdate,
		CASE 
			WHEN gen = 'F' THEN 'Female'
			WHEN gen = 'M' THEN 'Male'
			WHEN gen IS NULL THEN 'N/A'
			WHEN gen = ' ' THEN 'N/A'
			ELSE gen
		END gen
	FROM silver.erp_cust_az12
)T;


/*
	===============================
	Checking: silver.erp_loc_a101 
	===============================
*/
SELECT DISTINCT LEN(cid2)
FROM (
	SELECT
		cid,
		REPLACE(cid, '-', '') cid2,
		cntry
	FROM silver.erp_loc_a101
)T;


SELECT DISTINCT LEN(cid)
FROM silver.erp_loc_a101;


SELECT DISTINCT cntry2
FROM (
	SELECT
		REPLACE(cid, '-', '') cid,
		cntry,
		CASE 
			WHEN UPPER(TRIM(cntry)) IN ('USA', 'US', 'UNITED STATES') THEN 'United States'
			WHEN UPPER(TRIM(cntry)) IN ('DE', 'GERMANY') THEN 'Germany'
			WHEN UPPER(TRIM(cntry)) IS NULL OR UPPER(TRIM(cntry)) = '' THEN 'n/a'
			ELSE cntry
		END cntry2
	FROM silver.erp_loc_a101
)O;


/*
	===============================
	Checking: silver.erp_px_cat_g1v2 
	===============================
*/


SELECT maintenance
FROM silver.erp_px_cat_g1v2
where LEN(maintenance) != LEN(TRIM(maintenance));


SELECT DISTINCT subcat
FROM silver.erp_px_cat_g1v2;


SELECT DISTINCT id
FROM silver.erp_px_cat_g1v2;


