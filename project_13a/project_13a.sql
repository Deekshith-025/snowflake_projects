-- PROJECT 13: ENTERPRISE RETAIL ANALYTICS
-- STAR SCHEMA VS. SNOWFLAKE SCHEMA IMPLEMENTATION

CREATE WAREHOUSE IF NOT EXISTS p_13a
WITH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

USE WAREHOUSE p_13a;



CREATE DATABASE IF NOT EXISTS p13a_dw;

CREATE SCHEMA IF NOT EXISTS p13a_dw.schema_comparison;

USE DATABASE p13a_dw;

USE SCHEMA p13a_dw.schema_comparison;

SELECT CURRENT_DATABASE(), CURRENT_SCHEMA();


CREATE OR REPLACE TABLE star_dim_store
(
    store_key NUMBER AUTOINCREMENT PRIMARY KEY,
    store_id NUMBER,
    store_name VARCHAR(100),
    city VARCHAR(50),
    state VARCHAR(50),
    region_name VARCHAR(50),
    regional_manager VARCHAR(100)
);

DESC TABLE star_dim_store;



INSERT INTO star_dim_store
(
    store_id,
    store_name,
    city,
    state,
    region_name,
    regional_manager
)
VALUES
    (201, 'Metro Flagship', 'Hyderabad', 'Telangana', 'South', 'Rajesh Kumar'),
    (202, 'Express Hub', 'Warangal', 'Telangana', 'South', 'Rajesh Kumar'),
    (203, 'Coastal Center', 'Vijayawada', 'Andhra Pradesh', 'South', 'Rajesh Kumar'),
    (204, 'Western Mart', 'Nagpur', 'Maharashtra', 'West', 'Sunil Verma');

SELECT *
FROM star_dim_store;



CREATE OR REPLACE TABLE star_dim_product
(
    product_key NUMBER AUTOINCREMENT PRIMARY KEY,
    product_id NUMBER,
    product_name VARCHAR(100),
    subcategory_name VARCHAR(50),
    category_name VARCHAR(50),
    unit_price NUMBER(10,2)
);

DESC TABLE star_dim_product;


-- ============================================================================
-- STEP 5: LOAD STAR PRODUCT DIMENSION
-- ============================================================================

INSERT INTO star_dim_product
(
    product_id,
    product_name,
    subcategory_name,
    category_name,
    unit_price
)
VALUES
    (501, 'Laptop Pro', 'Laptops', 'Electronics', 75000.00),
    (502, 'Wireless Mouse', 'Accessories', 'Electronics', 1500.00),
    (503, 'Ergonomic Chair', 'Office', 'Furniture', 12000.00),
    (504, 'Coffee Maker', 'Kitchen', 'Appliances', 4500.00);

SELECT *
FROM star_dim_product;


-- ============================================================================
-- STEP 6: CREATE STAR FACT TABLE
-- ============================================================================

CREATE OR REPLACE TABLE star_fact_sales
(
    sales_key NUMBER AUTOINCREMENT PRIMARY KEY,
    transaction_id VARCHAR(50),
    transaction_date DATE,
    customer_id NUMBER,
    store_key NUMBER,
    product_key NUMBER,
    quantity NUMBER,
    total_amount NUMBER(12,2)
);

DESC TABLE star_fact_sales;


-- ============================================================================
-- STEP 7: LOAD STAR FACT TABLE
-- ============================================================================

INSERT INTO star_fact_sales
(
    transaction_id,
    transaction_date,
    customer_id,
    store_key,
    product_key,
    quantity,
    total_amount
)
SELECT
    s.transaction_id,
    s.transaction_date,
    s.customer_id,
    ds.store_key,
    dp.product_key,
    s.quantity,
    s.quantity * s.unit_price
FROM
(
    SELECT
        column1 AS transaction_id,
        TO_DATE(column2) AS transaction_date,
        column3 AS customer_id,
        column4 AS store_id,
        column5 AS product_id,
        column6 AS quantity,
        column7 AS unit_price
    FROM
    VALUES
        ('TXN-3001', '2026-05-01', 101, 201, 501, 1, 75000.00),
        ('TXN-3002', '2026-05-02', 102, 202, 502, 2, 1500.00),
        ('TXN-3003', '2026-05-03', 103, 203, 503, 1, 12000.00),
        ('TXN-3004', '2026-05-04', 104, 201, 504, 1, 4500.00),
        ('TXN-3005', '2026-05-05', 105, 204, 502, 3, 1500.00)
) s
JOIN star_dim_store ds
    ON s.store_id = ds.store_id
JOIN star_dim_product dp
    ON s.product_id = dp.product_id;

SELECT *
FROM star_fact_sales
ORDER BY sales_key;


-- ============================================================================
-- STEP 8: VERIFY STAR SCHEMA COUNTS
-- ============================================================================

SELECT COUNT(*) AS record_count
FROM star_dim_store;

SELECT COUNT(*) AS record_count
FROM star_dim_product;

SELECT COUNT(*) AS record_count
FROM star_fact_sales;


-- ============================================================================
-- STEP 9: CREATE SNOWFLAKE SCHEMA - REGION DIMENSION
-- ============================================================================

CREATE OR REPLACE TABLE snow_dim_region
(
    region_key NUMBER AUTOINCREMENT PRIMARY KEY,
    region_name VARCHAR(50),
    regional_manager VARCHAR(100)
);

DESC TABLE snow_dim_region;


-- ============================================================================
-- STEP 10: CREATE SNOWFLAKE SCHEMA - STORE DIMENSION
-- ============================================================================

CREATE OR REPLACE TABLE snow_dim_store
(
    store_key NUMBER AUTOINCREMENT PRIMARY KEY,
    store_id NUMBER,
    store_name VARCHAR(100),
    city VARCHAR(50),
    state VARCHAR(50),
    region_key NUMBER
);

DESC TABLE snow_dim_store;


-- ============================================================================
-- STEP 11: LOAD SNOWFLAKE REGION DIMENSION
-- ============================================================================

INSERT INTO snow_dim_region
(
    region_name,
    regional_manager
)
VALUES
    ('South', 'Rajesh Kumar'),
    ('West', 'Sunil Verma');

SELECT *
FROM snow_dim_region;


-- ============================================================================
-- STEP 12: LOAD SNOWFLAKE STORE DIMENSION
-- ============================================================================

INSERT INTO snow_dim_store
(
    store_id,
    store_name,
    city,
    state,
    region_key
)
SELECT
    s.store_id,
    s.store_name,
    s.city,
    s.state,
    r.region_key
FROM
(
    SELECT
        column1 AS store_id,
        column2 AS store_name,
        column3 AS city,
        column4 AS state,
        column5 AS region_name
    FROM
    VALUES
        (201, 'Metro Flagship', 'Hyderabad', 'Telangana', 'South'),
        (202, 'Express Hub', 'Warangal', 'Telangana', 'South'),
        (203, 'Coastal Center', 'Vijayawada', 'Andhra Pradesh', 'South'),
        (204, 'Western Mart', 'Nagpur', 'Maharashtra', 'West')
) s
JOIN snow_dim_region r
    ON s.region_name = r.region_name;

SELECT *
FROM snow_dim_store;


-- ============================================================================
-- STEP 13: CREATE SNOWFLAKE SCHEMA - CATEGORY DIMENSION
-- ============================================================================

CREATE OR REPLACE TABLE snow_dim_category
(
    category_key NUMBER AUTOINCREMENT PRIMARY KEY,
    category_name VARCHAR(50)
);

DESC TABLE snow_dim_category;


-- ============================================================================
-- STEP 14: CREATE SNOWFLAKE SCHEMA - SUBCATEGORY DIMENSION
-- ============================================================================

CREATE OR REPLACE TABLE snow_dim_subcategory
(
    subcategory_key NUMBER AUTOINCREMENT PRIMARY KEY,
    subcategory_name VARCHAR(50),
    category_key NUMBER
);

DESC TABLE snow_dim_subcategory;


-- ============================================================================
-- STEP 15: CREATE SNOWFLAKE SCHEMA - PRODUCT DIMENSION
-- ============================================================================

CREATE OR REPLACE TABLE snow_dim_product
(
    product_key NUMBER AUTOINCREMENT PRIMARY KEY,
    product_id NUMBER,
    product_name VARCHAR(100),
    unit_price NUMBER(10,2),
    subcategory_key NUMBER
);

DESC TABLE snow_dim_product;


-- ============================================================================
-- STEP 16: LOAD SNOWFLAKE CATEGORY DIMENSION
-- ============================================================================

INSERT INTO snow_dim_category
(
    category_name
)
VALUES
    ('Electronics'),
    ('Furniture'),
    ('Appliances');

SELECT *
FROM snow_dim_category;


-- ============================================================================
-- STEP 17: LOAD SNOWFLAKE SUBCATEGORY DIMENSION
-- ============================================================================

INSERT INTO snow_dim_subcategory
(
    subcategory_name,
    category_key
)
SELECT
    p.subcategory_name,
    c.category_key
FROM
(
    SELECT
        column1 AS subcategory_name,
        column2 AS category_name
    FROM
    VALUES
        ('Laptops', 'Electronics'),
        ('Accessories', 'Electronics'),
        ('Office', 'Furniture'),
        ('Kitchen', 'Appliances')
) p
JOIN snow_dim_category c
    ON p.category_name = c.category_name;

SELECT *
FROM snow_dim_subcategory;


-- ============================================================================
-- STEP 18: LOAD SNOWFLAKE PRODUCT DIMENSION
-- ============================================================================

INSERT INTO snow_dim_product
(
    product_id,
    product_name,
    unit_price,
    subcategory_key
)
SELECT
    p.product_id,
    p.product_name,
    p.unit_price,
    s.subcategory_key
FROM
(
    SELECT
        column1 AS product_id,
        column2 AS product_name,
        column3 AS subcategory_name,
        column4 AS unit_price
    FROM
    VALUES
        (501, 'Laptop Pro', 'Laptops', 75000.00),
        (502, 'Wireless Mouse', 'Accessories', 1500.00),
        (503, 'Ergonomic Chair', 'Office', 12000.00),
        (504, 'Coffee Maker', 'Kitchen', 4500.00)
) p
JOIN snow_dim_subcategory s
    ON p.subcategory_name = s.subcategory_name;

SELECT *
FROM snow_dim_product;


-- ============================================================================
-- STEP 19: CREATE SNOWFLAKE FACT TABLE
-- ============================================================================

CREATE OR REPLACE TABLE snow_fact_sales
(
    sales_key NUMBER AUTOINCREMENT PRIMARY KEY,
    transaction_id VARCHAR(50),
    transaction_date DATE,
    customer_id NUMBER,
    store_key NUMBER,
    product_key NUMBER,
    quantity NUMBER,
    total_amount NUMBER(12,2)
);

DESC TABLE snow_fact_sales;


-- ============================================================================
-- STEP 20: LOAD SNOWFLAKE FACT TABLE
-- ============================================================================

INSERT INTO snow_fact_sales
(
    transaction_id,
    transaction_date,
    customer_id,
    store_key,
    product_key,
    quantity,
    total_amount
)
SELECT
    s.transaction_id,
    s.transaction_date,
    s.customer_id,
    ds.store_key,
    dp.product_key,
    s.quantity,
    s.quantity * s.unit_price
FROM
(
    SELECT
        column1 AS transaction_id,
        TO_DATE(column2) AS transaction_date,
        column3 AS customer_id,
        column4 AS store_id,
        column5 AS product_id,
        column6 AS quantity,
        column7 AS unit_price
    FROM
    VALUES
        ('TXN-3001', '2026-05-01', 101, 201, 501, 1, 75000.00),
        ('TXN-3002', '2026-05-02', 102, 202, 502, 2, 1500.00),
        ('TXN-3003', '2026-05-03', 103, 203, 503, 1, 12000.00),
        ('TXN-3004', '2026-05-04', 104, 201, 504, 1, 4500.00),
        ('TXN-3005', '2026-05-05', 105, 204, 502, 3, 1500.00)
) s
JOIN snow_dim_store ds
    ON s.store_id = ds.store_id
JOIN snow_dim_product dp
    ON s.product_id = dp.product_id;

SELECT *
FROM snow_fact_sales
ORDER BY sales_key;


-- ============================================================================
-- STEP 21: VERIFY SNOWFLAKE SCHEMA COUNTS
-- ============================================================================

SELECT COUNT(*) AS record_count
FROM snow_dim_region;

SELECT COUNT(*) AS record_count
FROM snow_dim_store;

SELECT COUNT(*) AS record_count
FROM snow_dim_category;

SELECT COUNT(*) AS record_count
FROM snow_dim_subcategory;

SELECT COUNT(*) AS record_count
FROM snow_dim_product;

SELECT COUNT(*) AS record_count
FROM snow_fact_sales;


-- ============================================================================
-- STEP 22: STAR SCHEMA ANALYTICS
-- TOTAL REVENUE BY REGION AND CATEGORY
-- ============================================================================

SELECT
    ds.region_name,
    dp.category_name,
    SUM(fs.total_amount) AS total_revenue
FROM star_fact_sales fs
JOIN star_dim_store ds
    ON fs.store_key = ds.store_key
JOIN star_dim_product dp
    ON fs.product_key = dp.product_key
GROUP BY
    ds.region_name,
    dp.category_name
ORDER BY
    ds.region_name,
    dp.category_name;


-- ============================================================================
-- STEP 23: SNOWFLAKE SCHEMA ANALYTICS
-- TOTAL REVENUE BY REGION AND CATEGORY
-- ============================================================================

SELECT
    r.region_name,
    c.category_name,
    SUM(fs.total_amount) AS total_revenue
FROM snow_fact_sales fs
JOIN snow_dim_store ds
    ON fs.store_key = ds.store_key
JOIN snow_dim_region r
    ON ds.region_key = r.region_key
JOIN snow_dim_product dp
    ON fs.product_key = dp.product_key
JOIN snow_dim_subcategory sc
    ON dp.subcategory_key = sc.subcategory_key
JOIN snow_dim_category c
    ON sc.category_key = c.category_key
GROUP BY
    r.region_name,
    c.category_name
ORDER BY
    r.region_name,
    c.category_name;


-- ============================================================================
-- STEP 24: STAR VS. SNOWFLAKE ARCHITECTURAL COMPARISON
-- ============================================================================

SELECT
    'Dimension Normalization Level' AS metric,
    'Denormalized (Flat)' AS star_schema,
    'Normalized (Hierarchical)' AS snowflake_schema

UNION ALL

SELECT
    'Total Dimension Tables',
    '2 Tables',
    '5 Tables'

UNION ALL

SELECT
    'Joins for Category Revenue',
    '2 Joins',
    '5 Joins'

UNION ALL

SELECT
    'Data Redundancy',
    'Higher',
    'Lower'

UNION ALL

SELECT
    'Query Simplicity',
    'High',
    'Lower';


-- ============================================================================
-- STEP 25: REGIONAL MANAGER SALES PERFORMANCE
-- ============================================================================

SELECT
    ds.regional_manager,
    SUM(fs.quantity) AS total_items_sold,
    SUM(fs.total_amount) AS total_sales_amount
FROM star_fact_sales fs
JOIN star_dim_store ds
    ON fs.store_key = ds.store_key
GROUP BY
    ds.regional_manager
ORDER BY
    ds.regional_manager;


-- ============================================================================
-- STEP 26: FULL WAREHOUSE ARCHITECTURE AUDIT
-- ============================================================================

SELECT
    'Star Schema' AS schema_type,
    'STAR_DIM_STORE' AS table_name,
    COUNT(*) AS record_count
FROM star_dim_store

UNION ALL

SELECT
    'Star Schema',
    'STAR_DIM_PRODUCT',
    COUNT(*)
FROM star_dim_product

UNION ALL

SELECT
    'Star Schema',
    'STAR_FACT_SALES',
    COUNT(*)
FROM star_fact_sales

UNION ALL

SELECT
    'Snowflake Schema',
    'SNOW_DIM_REGION',
    COUNT(*)
FROM snow_dim_region

UNION ALL

SELECT
    'Snowflake Schema',
    'SNOW_DIM_STORE',
    COUNT(*)
FROM snow_dim_store

UNION ALL

SELECT
    'Snowflake Schema',
    'SNOW_DIM_CATEGORY',
    COUNT(*)
FROM snow_dim_category

UNION ALL

SELECT
    'Snowflake Schema',
    'SNOW_DIM_SUBCATEGORY',
    COUNT(*)
FROM snow_dim_subcategory

UNION ALL

SELECT
    'Snowflake Schema',
    'SNOW_DIM_PRODUCT',
    COUNT(*)
FROM snow_dim_product

UNION ALL

SELECT
    'Snowflake Schema',
    'SNOW_FACT_SALES',
    COUNT(*)
FROM snow_fact_sales;

