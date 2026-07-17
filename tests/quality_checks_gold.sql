/*
===============================================================================
Quality Checks: Gold Layer
===============================================================================
Purpose:
    This script runs a series of data quality checks against the 'gold'
    schema views to validate the integrity of the star schema after joining
    and integrating data from the Silver layer.

Checks Performed:
    - Duplicate records after joining source tables (dim_customers, dim_products)
    - Consistency of integrated columns sourced from multiple systems (gender)
    - Foreign key integrity between fact_sales and its related dimensions

Usage Notes:
    - Run this script after creating the gold layer views.
    - Any rows returned by these checks indicate data that still needs
      investigation or additional cleansing logic upstream.
===============================================================================
*/

-- ===============================================================================
-- Checking: gold.dim_customers
-- ===============================================================================

-- duplicate record check after joining the tables
SELECT 
	cst_id,
	COUNT(*)
FROM 
(
	SELECT 
		ci.cst_id,
		ci.cst_key,
		ci.cst_firstname,
		ci.cst_lastname,
		ci.cst_marital_status,
		ci.cst_gndr,
		ci.cst_create_date,
		ca.bdate,
		ca.gen,
		loc.cntry
	FROM silver.crm_cust_info ci
	LEFT JOIN silver.erp_cust_az12 ca
		ON ci.cst_key = ca.cid
	LEFT JOIN silver.erp_loc_a101 loc
		ON ci.cst_key = loc.cid
)t
GROUP BY cst_id
HAVING COUNT(*) > 1;


-- repeated column check
SELECT DISTINCT 
	ci.cst_gndr,
	ca.gen,
	CASE --integration: integrating 2 source systems in one
		-- in this case the gender columns are derived from 2 tables
		WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr  --CRM is the master for gender info
		ELSE COALESCE(ca.gen, 'n/a')
	END new_gen
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
	ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 loc
	ON ci.cst_key = loc.cid
ORDER BY 1,2;

-- ===============================================================================
-- Checking: gold.dim_products
-- ===============================================================================

-- duplicate check
SELECT 
	prd_id, 
	COUNT(*)
FROM (
	SELECT 
		pn.prd_id,
		pn.cat_id,
		pn.prd_key,
		pn.prd_nm,
		pn.prd_cost,
		pn.prd_line,
		pn.prd_start_dt,
		pc.cat,
		pc.subcat,
		pc.maintenance
	FROM silver.crm_prd_info pn
	LEFT JOIN silver.erp_px_cat_g1v2 pc
		ON pn.cat_id = pc.id
	WHERE prd_end_dt IS NULL -- filter out all historical data
)t
GROUP BY prd_id
HAVING COUNT(*) > 1;

-- ===============================================================================
-- Checking: gold.fact_sales
-- ===============================================================================

-- foreign key integration check
SELECT *
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
	ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products p
	ON p.product_key = f.product_key
WHERE p.product_key IS NULL;
