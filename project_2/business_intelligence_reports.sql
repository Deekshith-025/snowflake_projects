CREATE WAREHOUSE RETAIL_WH
WITH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;

create database RETAIL_DB;
use database RETAIL_DB;

create schema SALES_SCHEMA;
use schema SALES_SCHEMA;

create file format csv_format
type = 'csv'
field_delimiter = ','
skip_header = 1
field_optionally_enclosed_by = '"';

create stage RETAIL_STAGE
FILE_FORMAT = CSV_FORMAT;

list @retail_stage;

create table customers(
    customer_id INTEGER,
    customer_name VARCHAR,
    city VARCHAR,
    membership VARCHAR
);

create table products(
    product_id INTEGER,
    product_name VARCHAR,
    category VARCHAR,
    price NUMBER(10,2)
);

create table branches(
    branch_id INTEGER,
    branch_name VARCHAR,
    city VARCHAR
);

create table sales(
    SALE_ID INTEGER,
    CUSTOMER_ID INTEGER,
    PRODUCT_ID INTEGER,
    BRANCH_ID INTEGER,
    QUANTITY INTEGER,
    SALE_DATE DATE,
    TOTAL_AMOUNT NUMBER(12,2)
);

show tables;

copy into customers
from @retail_stage/customers.csv
file_format = csv_format;

copy into products
from @retail_stage/products.csv
file_format = csv_format;

copy into branches
from @retail_stage/branches.csv
file_format = csv_format;

copy into sales
from @retail_stage/sales.csv
file_format = csv_format;

select * from customers;
select * from products;
select * from branches;
select * from sales;

SELECT
    sum(total_amount) as total_revenue
FROM sales;

SELECT
    c.customer_id,
    c.customer_name,
    c.membership,
    SUM(s.total_amount) AS total_sales
FROM customers c
JOIN sales s
    ON c.customer_id = s.customer_id
GROUP BY
    c.customer_id,
    c.customer_name,
    c.membership
ORDER BY total_sales DESC;

SELECT
    b.branch_id,
    b.branch_name,
    b.city,
    SUM(s.total_amount) AS total_sales
FROM branches b
JOIN sales s
    ON b.branch_id = s.branch_id
GROUP BY
    b.branch_id,
    b.branch_name,
    b.city
ORDER BY total_sales DESC;

SELECT
    p.product_id,
    p.product_name,
    SUM(s.quantity) AS total_quantity,
    SUM(s.total_amount) AS total_revenue
FROM products p
JOIN sales s
    ON p.product_id = s.product_id
GROUP BY
    p.product_id,
    p.product_name
ORDER BY total_revenue DESC;

SELECT
    p.category,
    SUM(s.total_amount) AS total_revenue
FROM products p
JOIN sales s
    ON p.product_id = s.product_id
GROUP BY p.category
ORDER BY total_revenue DESC;

SELECT
    b.branch_name,
    SUM(s.total_amount) AS total_revenue
FROM branches b
JOIN sales s
    ON b.branch_id = s.branch_id
GROUP BY b.branch_name
ORDER BY total_revenue DESC
LIMIT 1;

SELECT
    c.customer_name,
    SUM(s.total_amount) AS total_spending
FROM customers c
JOIN sales s
    ON c.customer_id = s.customer_id
GROUP BY c.customer_name
ORDER BY total_spending DESC
LIMIT 1;

SELECT
    p.product_name,
    SUM(s.total_amount) AS total_revenue
FROM products p
JOIN sales s
    ON p.product_id = s.product_id
GROUP BY p.product_name
ORDER BY total_revenue DESC
LIMIT 3;

SELECT
    c.customer_name,
    SUM(s.total_amount) AS total_spending
FROM customers c
JOIN sales s
    ON c.customer_id = s.customer_id
GROUP BY c.customer_name
ORDER BY total_spending DESC
LIMIT 3;

SELECT
    c.customer_name,
    SUM(s.total_amount) AS total_spending,
    RANK() OVER (
        ORDER BY SUM(s.total_amount) DESC
    ) AS customer_rank
FROM customers c
JOIN sales s
    ON c.customer_id = s.customer_id
GROUP BY
    c.customer_id,
    c.customer_name;

SELECT
    b.branch_name,
    SUM(s.total_amount) AS total_sales,
    RANK() OVER (
        ORDER BY SUM(s.total_amount) DESC
    ) AS branch_rank
FROM branches b
JOIN sales s
    ON b.branch_id = s.branch_id
GROUP BY
    b.branch_id,
    b.branch_name;

SELECT
    category,
    product_name,
    total_revenue
FROM (
    SELECT
        p.category,
        p.product_name,
        SUM(s.total_amount) AS total_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY p.category
            ORDER BY SUM(s.total_amount) DESC
        ) AS rn
    FROM products p
    JOIN sales s
        ON p.product_id = s.product_id
    GROUP BY
        p.category,
        p.product_name
)
WHERE rn = 1;

SELECT
    sale_date,
    total_amount,
    SUM(total_amount) OVER (
        ORDER BY sale_date
    ) AS cumulative_sales
FROM sales
ORDER BY sale_date;

SELECT
    sale_id,
    sale_date,
    total_amount,
    AVG(total_amount) OVER () AS average_sale_amount
FROM sales
ORDER BY sale_date;

WITH customer_revenue AS (
    SELECT
        c.customer_id,
        c.customer_name,
        SUM(s.total_amount) AS total_revenue
    FROM customers c
    JOIN sales s
        ON c.customer_id = s.customer_id
    GROUP BY
        c.customer_id,
        c.customer_name
)
SELECT *
FROM customer_revenue
ORDER BY total_revenue DESC;

WITH customer_revenue AS (
    SELECT
        c.customer_id,
        c.customer_name,
        SUM(s.total_amount) AS total_spending
    FROM customers c
    JOIN sales s
        ON c.customer_id = s.customer_id
    GROUP BY
        c.customer_id,
        c.customer_name
)
SELECT *
FROM customer_revenue
WHERE total_spending > (
    SELECT AVG(total_spending)
    FROM customer_revenue
)
ORDER BY total_spending DESC;

CREATE VIEW sales_report AS
SELECT
    s.sale_id,
    s.sale_date,
    c.customer_name,
    c.membership,
    p.product_name,
    p.category,
    b.branch_name,
    b.city AS branch_city,
    s.quantity,
    s.total_amount
FROM sales s
JOIN customers c
    ON s.customer_id = c.customer_id
JOIN products p
    ON s.product_id = p.product_id
JOIN branches b
    ON s.branch_id = b.branch_id;

SELECT *
FROM sales_report;

CREATE MATERIALIZED VIEW top_customers AS
SELECT
    customer_id,
    SUM(total_amount) AS total_spending
FROM sales
GROUP BY customer_id;

SELECT
    c.customer_id,
    c.customer_name,
    t.total_spending
FROM customers c
JOIN top_customers t
    ON c.customer_id = t.customer_id
ORDER BY t.total_spending DESC;