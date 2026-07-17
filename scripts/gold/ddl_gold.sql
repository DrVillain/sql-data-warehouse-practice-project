/*
===============================================================================
DDL Script: Create Gold Layer Views
===============================================================================
Purpose:
    This script creates views in the 'gold' schema, dropping existing views
    if they already exist. The Gold layer represents the final, business-ready
    data model built on top of the Silver layer, structured as a star schema
    with dimension and fact views.
 
Views Created:
    - gold.dim_customers  (Dimension)
    - gold.dim_products   (Dimension)
    - gold.fact_sales     (Fact)
 
Notes:
    - These are views, not physical tables; they always reflect the current
      state of the underlying Silver tables.
    - dim_products only reflects current/active products (rows with a null
      prd_end_dt); historical product records are excluded.
===============================================================================
*/


-- ===============================================================================
-- Creating Dimension: gold.dim_customers
-- ===============================================================================

IF OBJECT_ID('gold.dim_customers', 'V') IS NOT NULL
	DROP VIEW gold.dim_customers;
GO

CREATE VIEW gold.dim_customers AS
SELECT
	ROW_NUMBER() OVER(ORDER BY ci.cst_id) customer_key,
	ci.cst_id customer_id,
	ci.cst_key customer_number,
	ci.cst_firstname first_name,
	ci.cst_lastname last_name,
	loc.cntry country,
	ci.cst_marital_status marital_status,
	CASE 
		WHEN ci.cst_gndr != LOWER('n/a') THEN ci.cst_gndr  --CRM is the master for gender info
		ELSE COALESCE(ca.gen, 'n/a')
	END gender,
	ca.bdate birthdate,
	ci.cst_create_date create_date
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
	ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 loc
	ON ci.cst_key = loc.cid
WHERE ci.cst_id IS NOT NULL;

GO

-- ===============================================================================
-- Creating Dimension: gold.dim_products
-- ===============================================================================

IF OBJECT_ID('gold.dim_products', 'V') IS NOT NULL
	DROP VIEW gold.dim_products;
GO

CREATE VIEW gold.dim_products AS
SELECT
	ROW_NUMBER() OVER(ORDER BY pn.prd_start_dt, pn.prd_key) product_key,
	pn.prd_id product_id,
	pn.prd_key product_number,
	pn.prd_nm product_name,
	pn.cat_id category_id,
	pc.cat category,
	pc.subcat subcategory,
	pc.maintenance,
	pn.prd_cost cost,
	pn.prd_line product_line,
	pn.prd_start_dt start_date
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
	ON pn.cat_id = pc.id
WHERE prd_end_dt IS NULL; 

GO

-- ===============================================================================
-- Creating Fact: gold.fact_sales
-- ===============================================================================

IF OBJECT_ID('gold.fact_sales', 'V') IS NOT NULL
	DROP VIEW gold.fact_sales;
GO

CREATE VIEW gold.fact_sales AS
SELECT 
	sd.sls_ord_num order_number,
	pr.product_key, 
	cr.customer_key, 
	sd.sls_order_dt order_date,
	sd.sls_ship_dt shipping_date,
	sd.sls_due_dt due_date,
	sd.sls_sales sales_amount,
	sd.sls_quantity quantity,
	sd.sls_price price
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products pr
	ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers cr
	ON sd.sls_cust_id = cr.customer_id;
