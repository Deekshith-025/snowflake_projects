

CREATE WAREHOUSE IF NOT EXISTS retail_warehouse
WITH
    WAREHOUSE_SIZE = 'x-small'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

USE WAREHOUSE retail_warehouse;


CREATE DATABASE IF NOT EXISTS retail_dw;

USE DATABASE retail_dw;

CREATE SCHEMA IF NOT EXISTS staging;

CREATE SCHEMA IF NOT EXISTS warehouse;



USE SCHEMA staging;

CREATE STAGE IF NOT EXISTS retail_stage;

SHOW STAGES;


CREATE FILE FORMAT IF NOT EXISTS retail_csv_format
    TYPE = 'csv'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('null', 'NULL');

SHOW FILE FORMATS;

CREATE OR REPLACE TABLE stg_customers (
    customer_id NUMBER,
    customer_name VARCHAR,
    city VARCHAR,
    state VARCHAR,
    membership VARCHAR
);

CREATE OR REPLACE TABLE stg_products (
    product_id NUMBER,
    product_name VARCHAR,
    category VARCHAR,
    brand VARCHAR,
    price NUMBER(12,2)
);

CREATE OR REPLACE TABLE stg_branches (
    branch_id NUMBER,
    branch_name VARCHAR,
    city VARCHAR,
    state VARCHAR,
    region VARCHAR,
    manager_name VARCHAR
);

CREATE OR REPLACE TABLE stg_calendar (
    date_id NUMBER,
    date DATE,
    day NUMBER,
    day_name VARCHAR,
    week_no NUMBER,
    month VARCHAR,
    quarter VARCHAR,
    year NUMBER,
    is_weekend VARCHAR
);

CREATE OR REPLACE TABLE stg_sales (
    sale_id NUMBER,
    customer_id NUMBER,
    product_id NUMBER,
    branch_id NUMBER,
    date_id NUMBER,
    quantity NUMBER,
    total_amount NUMBER(14,2)
);


LIST @retail_stage;


COPY INTO stg_customers
FROM @retail_stage/customers.csv
FILE_FORMAT = (FORMAT_NAME = 'retail_csv_format');

SELECT COUNT(*) AS row_count
FROM stg_customers;

SELECT *
FROM stg_customers;


COPY INTO stg_products
FROM @retail_stage/products.csv
FILE_FORMAT = (FORMAT_NAME = 'retail_csv_format');

SELECT COUNT(*) AS row_count
FROM stg_products;

SELECT *
FROM stg_products;


COPY INTO stg_branches
FROM @retail_stage/branches.csv
FILE_FORMAT = (FORMAT_NAME = 'retail_csv_format');

SELECT COUNT(*) AS row_count
FROM stg_branches;

SELECT *
FROM stg_branches;


COPY INTO stg_calendar
FROM @retail_stage/calendar.csv
FILE_FORMAT = (FORMAT_NAME = 'retail_csv_format');

SELECT COUNT(*) AS row_count
FROM stg_calendar;

SELECT *
FROM stg_calendar;


COPY INTO stg_sales
FROM @retail_stage/sales.csv
FILE_FORMAT = (FORMAT_NAME = 'retail_csv_format');

SELECT COUNT(*) AS row_count
FROM stg_sales;

SELECT *
FROM stg_sales;


SELECT 'customers' AS table_name, COUNT(*) AS row_count
FROM stg_customers
UNION ALL
SELECT 'products', COUNT(*)
FROM stg_products
UNION ALL
SELECT 'branches', COUNT(*)
FROM stg_branches
UNION ALL
SELECT 'calendar', COUNT(*)
FROM stg_calendar
UNION ALL
SELECT 'sales', COUNT(*)
FROM stg_sales;


USE SCHEMA warehouse;

CREATE OR REPLACE TABLE dim_customer (
    customer_id NUMBER PRIMARY KEY,
    customer_name VARCHAR,
    city VARCHAR,
    state VARCHAR,
    membership VARCHAR
);

CREATE OR REPLACE TABLE dim_product (
    product_id NUMBER PRIMARY KEY,
    product_name VARCHAR,
    category VARCHAR,
    brand VARCHAR,
    price NUMBER(12,2)
);

CREATE OR REPLACE TABLE dim_branch (
    branch_id NUMBER PRIMARY KEY,
    branch_name VARCHAR,
    city VARCHAR,
    state VARCHAR,
    region VARCHAR,
    manager_name VARCHAR
);

CREATE OR REPLACE TABLE dim_date (
    date_id NUMBER PRIMARY KEY,
    date DATE,
    day NUMBER,
    day_name VARCHAR,
    week_no NUMBER,
    month VARCHAR,
    quarter VARCHAR,
    year NUMBER,
    is_weekend VARCHAR
);


CREATE OR REPLACE TABLE fact_sales (
    sale_id NUMBER PRIMARY KEY,
    customer_id NUMBER,
    product_id NUMBER,
    branch_id NUMBER,
    date_id NUMBER,
    quantity NUMBER,
    total_amount NUMBER(14,2),

    FOREIGN KEY (customer_id)
        REFERENCES dim_customer(customer_id),

    FOREIGN KEY (product_id)
        REFERENCES dim_product(product_id),

    FOREIGN KEY (branch_id)
        REFERENCES dim_branch(branch_id),

    FOREIGN KEY (date_id)
        REFERENCES dim_date(date_id)
);


INSERT INTO dim_customer (
    customer_id,
    customer_name,
    city,
    state,
    membership
)
SELECT
    customer_id,
    customer_name,
    city,
    state,
    membership
FROM staging.stg_customers;

SELECT COUNT(*) AS row_count
FROM dim_customer;

SELECT *
FROM dim_customer;


INSERT INTO dim_product (
    product_id,
    product_name,
    category,
    brand,
    price
)
SELECT
    product_id,
    product_name,
    category,
    brand,
    price
FROM staging.stg_products;

SELECT COUNT(*) AS row_count
FROM dim_product;

SELECT *
FROM dim_product;


INSERT INTO dim_branch (
    branch_id,
    branch_name,
    city,
    state,
    region,
    manager_name
)
SELECT
    branch_id,
    branch_name,
    city,
    state,
    region,
    manager_name
FROM staging.stg_branches;

SELECT COUNT(*) AS row_count
FROM dim_branch;

SELECT *
FROM dim_branch;


INSERT INTO dim_date (
    date_id,
    date,
    day,
    day_name,
    week_no,
    month,
    quarter,
    year,
    is_weekend
)
SELECT
    date_id,
    date,
    day,
    day_name,
    week_no,
    month,
    quarter,
    year,
    is_weekend
FROM staging.stg_calendar;

SELECT COUNT(*) AS row_count
FROM dim_date;

SELECT *
FROM dim_date;


INSERT INTO fact_sales (
    sale_id,
    customer_id,
    product_id,
    branch_id,
    date_id,
    quantity,
    total_amount
)
SELECT
    sale_id,
    customer_id,
    product_id,
    branch_id,
    date_id,
    quantity,
    total_amount
FROM staging.stg_sales;

SELECT COUNT(*) AS row_count
FROM fact_sales;

SELECT *
FROM fact_sales;


SELECT 'dim_customer' AS table_name, COUNT(*) AS row_count
FROM dim_customer
UNION ALL
SELECT 'dim_product', COUNT(*)
FROM dim_product
UNION ALL
SELECT 'dim_branch', COUNT(*)
FROM dim_branch
UNION ALL
SELECT 'dim_date', COUNT(*)
FROM dim_date
UNION ALL
SELECT 'fact_sales', COUNT(*)
FROM fact_sales;


SELECT
    f.sale_id,
    c.customer_name,
    p.product_name,
    b.branch_name,
    d.date,
    f.quantity,
    f.total_amount
FROM fact_sales f
JOIN dim_customer c
    ON f.customer_id = c.customer_id
JOIN dim_product p
    ON f.product_id = p.product_id
JOIN dim_branch b
    ON f.branch_id = b.branch_id
JOIN dim_date d
    ON f.date_id = d.date_id
ORDER BY f.sale_id;


SELECT
    c.customer_id,
    c.customer_name,
    SUM(f.total_amount) AS total_sales
FROM fact_sales f
JOIN dim_customer c
    ON f.customer_id = c.customer_id
GROUP BY
    c.customer_id,
    c.customer_name
ORDER BY total_sales DESC;


SELECT
    p.product_id,
    p.product_name,
    p.category,
    SUM(f.total_amount) AS total_revenue
FROM fact_sales f
JOIN dim_product p
    ON f.product_id = p.product_id
GROUP BY
    p.product_id,
    p.product_name,
    p.category
ORDER BY total_revenue DESC;


SELECT
    b.branch_id,
    b.branch_name,
    b.city,
    b.state,
    SUM(f.total_amount) AS total_sales
FROM fact_sales f
JOIN dim_branch b
    ON f.branch_id = b.branch_id
GROUP BY
    b.branch_id,
    b.branch_name,
    b.city,
    b.state
ORDER BY total_sales DESC;

SELECT
    d.year,
    d.month,
    SUM(f.total_amount) AS total_revenue
FROM fact_sales f
JOIN dim_date d
    ON f.date_id = d.date_id
GROUP BY
    d.year,
    d.month
ORDER BY
    d.year,
    MIN(d.date);


SELECT
    b.state,
    SUM(f.total_amount) AS total_revenue
FROM fact_sales f
JOIN dim_branch b
    ON f.branch_id = b.branch_id
GROUP BY
    b.state
ORDER BY total_revenue DESC;

SELECT
    p.category,
    SUM(f.total_amount) AS total_revenue
FROM fact_sales f
JOIN dim_product p
    ON f.product_id = p.product_id
GROUP BY
    p.category
ORDER BY total_revenue DESC;

SELECT
    c.customer_id,
    c.customer_name,
    SUM(f.total_amount) AS total_sales
FROM fact_sales f
JOIN dim_customer c
    ON f.customer_id = c.customer_id
GROUP BY
    c.customer_id,
    c.customer_name
ORDER BY total_sales DESC
LIMIT 10;

SELECT
    p.product_id,
    p.product_name,
    SUM(f.total_amount) AS total_revenue
FROM fact_sales f
JOIN dim_product p
    ON f.product_id = p.product_id
GROUP BY
    p.product_id,
    p.product_name
ORDER BY total_revenue DESC
LIMIT 10;


SELECT
    b.branch_id,
    b.branch_name,
    SUM(f.total_amount) AS total_sales
FROM fact_sales f
JOIN dim_branch b
    ON f.branch_id = b.branch_id
GROUP BY
    b.branch_id,
    b.branch_name
ORDER BY total_sales DESC
LIMIT 10;


SELECT
    d.date,
    SUM(f.total_amount) AS daily_sales
FROM fact_sales f
JOIN dim_date d
    ON f.date_id = d.date_id
GROUP BY
    d.date
ORDER BY d.date;


SELECT
    c.customer_id,
    c.customer_name,
    c.membership,
    COUNT(f.sale_id) AS total_transactions,
    SUM(f.quantity) AS total_quantity,
    SUM(f.total_amount) AS total_spent
FROM fact_sales f
JOIN dim_customer c
    ON f.customer_id = c.customer_id
GROUP BY
    c.customer_id,
    c.customer_name,
    c.membership
ORDER BY total_spent DESC;


SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.brand,
    SUM(f.quantity) AS total_quantity,
    SUM(f.total_amount) AS total_revenue
FROM fact_sales f
JOIN dim_product p
    ON f.product_id = p.product_id
GROUP BY
    p.product_id,
    p.product_name,
    p.category,
    p.brand
ORDER BY total_revenue DESC;


SELECT
    b.branch_id,
    b.branch_name,
    b.region,
    SUM(f.quantity) AS total_quantity,
    SUM(f.total_amount) AS total_sales
FROM fact_sales f
JOIN dim_branch b
    ON f.branch_id = b.branch_id
GROUP BY
    b.branch_id,
    b.branch_name,
    b.region
ORDER BY total_sales DESC;


SELECT
    b.region,
    SUM(f.total_amount) AS total_sales
FROM fact_sales f
JOIN dim_branch b
    ON f.branch_id = b.branch_id
GROUP BY
    b.region
ORDER BY total_sales DESC;


SELECT
    d.year,
    d.quarter,
    SUM(f.total_amount) AS total_revenue
FROM fact_sales f
JOIN dim_date d
    ON f.date_id = d.date_id
GROUP BY
    d.year,
    d.quarter
ORDER BY
    d.year,
    d.quarter;


CREATE OR REPLACE VIEW customer_sales_report AS
SELECT
    c.customer_id,
    c.customer_name,
    SUM(f.total_amount) AS total_sales
FROM fact_sales f
JOIN dim_customer c
    ON f.customer_id = c.customer_id
GROUP BY
    c.customer_id,
    c.customer_name;

SELECT *
FROM customer_sales_report
ORDER BY total_sales DESC;

CREATE OR REPLACE VIEW product_revenue_report AS
SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.brand,
    SUM(f.total_amount) AS total_revenue
FROM fact_sales f
JOIN dim_product p
    ON f.product_id = p.product_id
GROUP BY
    p.product_id,
    p.product_name,
    p.category,
    p.brand;

SELECT *
FROM product_revenue_report
ORDER BY total_revenue DESC;


CREATE OR REPLACE VIEW branch_performance_report AS
SELECT
    b.branch_id,
    b.branch_name,
    b.city,
    b.state,
    b.region,
    SUM(f.quantity) AS total_quantity,
    SUM(f.total_amount) AS total_sales
FROM fact_sales f
JOIN dim_branch b
    ON f.branch_id = b.branch_id
GROUP BY
    b.branch_id,
    b.branch_name,
    b.city,
    b.state,
    b.region;

SELECT *
FROM branch_performance_report
ORDER BY total_sales DESC;


SHOW TABLES;

SHOW VIEWS;

SHOW STAGES;
