# Data Dictionary — Gold Layer

## Overview
The Gold layer contains business-ready, consumable views built on top of the Silver layer. It follows a star schema, with two dimension tables and one fact table.

---

## 1. gold.dim_customers
**Type:** Dimension Table
**Description:** Contains customer details enriched with demographic and geographic data, sourced from CRM and ERP systems.

| Column Name      | Data Type    | Description                                                                 |
|-------------------|-------------|-------------------------------------------------------------------------------|
| customer_key      | INT         | Surrogate key uniquely identifying each customer record in the dimension table. |
| customer_id       | INT         | Unique numeric identifier assigned to each customer (source: CRM).           |
| customer_number   | NVARCHAR(50)| Alphanumeric identifier used to track and reference the customer.            |
| first_name        | NVARCHAR(50)| Customer's first name, as recorded in the CRM system.                        |
| last_name         | NVARCHAR(50)| Customer's last name or family name, as recorded in the CRM system.          |
| country           | NVARCHAR(50)| Country of residence for the customer (source: ERP location data).           |
| marital_status    | NVARCHAR(50)| Marital status of the customer (e.g., Single, Married).                      |
| gender            | NVARCHAR(50)| Customer's gender. CRM is treated as the master source; ERP is used as a fallback when CRM data is missing or 'n/a'. |
| birthdate         | DATE        | Customer's date of birth (source: ERP).                                      |
| create_date       | DATE        | Date the customer record was first created in the source CRM system.        |

---

## 2. gold.dim_products
**Type:** Dimension Table
**Description:** Contains product details along with category, subcategory, and cost information. Only reflects current, active products (historical/expired records are excluded).

| Column Name    | Data Type    | Description                                                                 |
|-----------------|-------------|-------------------------------------------------------------------------------|
| product_key     | INT         | Surrogate key uniquely identifying each product record in the dimension table. |
| product_id      | INT         | Unique numeric identifier assigned to each product (source: CRM).           |
| product_number  | NVARCHAR(50)| Alphanumeric code identifying the product, extracted from the source product key. |
| product_name    | NVARCHAR(50)| Descriptive name of the product.                                             |
| category_id     | NVARCHAR(50)| Identifier linking the product to its category, extracted from the product key. |
| category        | NVARCHAR(50)| High-level classification of the product (e.g., Bikes, Components).          |
| subcategory     | NVARCHAR(50)| More detailed classification of the product within its category.            |
| maintenance     | NVARCHAR(50)| Indicates whether the product requires maintenance.                          |
| cost            | INT         | Cost or base price of the product, in whole currency units.                  |
| product_line    | NVARCHAR(50)| Product line the item belongs to (e.g., Mountain, Road, Touring, Other Sales). |
| start_date      | DATE        | Date the product became available or active.                                |

---

## 3. gold.fact_sales
**Type:** Fact Table
**Description:** Contains transactional sales data, linked to the customer and product dimensions, for reporting and analysis purposes.

| Column Name    | Data Type    | Description                                                                 |
|-----------------|-------------|-------------------------------------------------------------------------------|
| order_number    | NVARCHAR(50)| Unique identifier for the sales order.                                       |
| product_key     | INT         | Foreign key referencing gold.dim_products (product_key).                     |
| customer_key    | INT         | Foreign key referencing gold.dim_customers (customer_key).                   |
| order_date      | DATE        | Date the order was placed.                                                   |
| shipping_date   | DATE        | Date the order was shipped.                                                  |
| due_date        | DATE        | Date the order payment/delivery was due.                                     |
| sales_amount    | INT         | Total monetary value of the sale, in whole currency units.                   |
| quantity        | INT         | Number of units sold in the transaction.                                     |
| price           | INT         | Unit price of the product at the time of sale, in whole currency units.      |

---

## Relationships
- `gold.fact_sales.product_key` → `gold.dim_products.product_key`
- `gold.fact_sales.customer_key` → `gold.dim_customers.customer_key`
