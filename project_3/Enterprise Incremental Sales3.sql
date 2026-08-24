create warehouse enterprise_wh
warehouse_size = 'X-SMALL'
auto_suspend = 60
auto_resume = TRUE;
USE warehouse enterprise_wh;

create database enterprise_db;
use database enterprise_db;

create schema sales_schema;
use schema sales_schema;

create file format csv_format
type = 'csv'
field_delimiter = ','
skip_header = 1
field_optionally_enclosed_by = '"';

create stage sales_stage
file_format = csv_format;

list @sales_stage;

create table customers(
    customer_id INTEGER,
    customer_name VARCHAR,
    city VARCHAR,
    membership VARCHAR
);

create table products(
    product_id INTEGER,
    product_name VARCHAR(10),
    category VARCHAR(50),
    price number(12,2)
);

create table branches(
    branch_id NUMBER,
    branch_name VARCHAR(40),
    state VARCHAR(50)
);

create table sales_history(
    sale_id INTEGER,
    customer_id INTEGER,
    product_id INTEGER,
    branch_id INTEGER,
    quantity NUMBER,
    sale_date DATE,
    total_amount NUMBER(12,2)
);

create table new_sales(
    sale_id NUMBER, 
    customer_id NUMBER,
    product_id NUMBER,
    branch_id NUMBER,
    quantity NUMBER,
    sale_date DATE,
    total_amount NUMBER(12,2)
);

copy into customers
from @sales_stage/customers.csv
file_format = csv_format;

copy into products
from @sales_stage/products.csv
file_format = csv_format;

copy into branches
from @sales_stage/branches.csv
file_format = csv_format;

copy into sales_history
from @sales_stage/sales_history.csv
file_format = csv_format;

copy into new_sales
from @sales_stage/new_sales.csv
file_format = csv_format;

select * from customers;
select * from products;
select * from branches;
select * from sales_history;
select * from new_sales;

SELECT * FROM sales_history
ORDER BY sale_id;

CREATE OR REPLACE STREAM sales_stream
ON TABLE sales_history;

SHOW STREAMS;

CREATE OR REPLACE TABLE new_sales_stage (
    sale_id NUMBER,
    customer_id NUMBER,
    product_id NUMBER,
    branch_id NUMBER,
    quantity NUMBER,
    sale_date DATE,
    total_amount NUMBER(12,2)
);

COPY INTO new_sales_stage
FROM @sales_stage/new_sales.csv
FILE_FORMAT = csv_format;

SELECT *
FROM new_sales_stage
ORDER BY sale_id;

MERGE INTO sales_history AS target
USING new_sales_stage AS source
ON target.sale_id = source.sale_id

WHEN NOT MATCHED THEN
    INSERT (
        sale_id,
        customer_id,
        product_id,
        branch_id,
        quantity,
        sale_date,
        total_amount
    )
    VALUES (
        source.sale_id,
        source.customer_id,
        source.product_id,
        source.branch_id,
        source.quantity,
        source.sale_date,
        source.total_amount
    );
    
SELECT *
FROM sales_history
ORDER BY sale_id;

SELECT
    sale_id,
    customer_id,
    product_id,
    branch_id,
    quantity,
    sale_date,
    total_amount,
    metadata$action
FROM sales_stream
ORDER BY sale_id;

SELECT
    sale_id,
    COUNT(*) AS cnt
FROM sales_history
GROUP BY sale_id
HAVING COUNT(*) > 1;

SELECT s.*
FROM sales_history AS s
LEFT JOIN customers AS c
    ON s.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

SELECT s.*
FROM sales_history AS s
LEFT JOIN products AS p
    ON s.product_id = p.product_id
WHERE p.product_id IS NULL;

SELECT COUNT(*) AS new_record_count
FROM sales_history
WHERE sale_id >= 6;

SELECT *
FROM sales_history
WHERE sale_id = 10;

DELETE FROM sales_history
WHERE sale_id = 10;

SELECT LAST_QUERY_ID();
--Copy the query ID.

INSERT INTO sales_history
SELECT *
FROM sales_history BEFORE (
    STATEMENT => '01c67f0b-000d-eb09-0001-44a2000f507e'
)
WHERE sale_id = 10;

SELECT *
FROM sales_history
WHERE sale_id = 10;

CREATE OR REPLACE TABLE sales_test
CLONE sales_history;

SELECT *
FROM sales_test
ORDER BY sale_id;

INSERT INTO sales_test
VALUES (
    999,
    1,
    101,
    1,
    1,
    '2026-07-15',
    60000
);

SELECT *
FROM sales_test
WHERE sale_id = 999;


CREATE OR REPLACE TABLE sales_load_audit (
    audit_time TIMESTAMP,
    sale_id NUMBER,
    action VARCHAR,
    load_source VARCHAR
);

CREATE OR REPLACE TASK daily_sales_audit_task
WAREHOUSE = enterprise_wh
SCHEDULE = 'USING CRON 0 0 * * * UTC'
WHEN SYSTEM$STREAM_HAS_DATA('sales_stream')
AS
INSERT INTO sales_load_audit
SELECT
    CURRENT_TIMESTAMP(),
    sale_id,
    metadata$action,
    'sales_stream'
FROM sales_stream;

ALTER TASK daily_sales_audit_task RESUME;

SHOW TASKS;

EXECUTE TASK daily_sales_audit_task;

SELECT *
FROM sales_load_audit
ORDER BY audit_time DESC;

SELECT *
FROM TABLE(
    INFORMATION_SCHEMA.TASK_HISTORY(
        TASK_NAME => 'DAILY_SALES_AUDIT_TASK'
    )
)
ORDER BY scheduled_time DESC;

SELECT
    c.customer_id,
    c.customer_name,
    SUM(s.total_amount) AS total_revenue
FROM customers AS c
JOIN sales_history AS s
    ON c.customer_id = s.customer_id
GROUP BY
    c.customer_id,
    c.customer_name
ORDER BY total_revenue DESC;

SELECT
    b.branch_id,
    b.branch_name,
    SUM(s.total_amount) AS total_revenue
FROM branches AS b
JOIN sales_history AS s
    ON b.branch_id = s.branch_id
GROUP BY
    b.branch_id,
    b.branch_name
ORDER BY total_revenue DESC;

SELECT
    p.product_id,
    p.product_name,
    SUM(s.quantity) AS total_quantity,
    SUM(s.total_amount) AS total_revenue
FROM products AS p
JOIN sales_history AS s
    ON p.product_id = s.product_id
GROUP BY
    p.product_id,
    p.product_name
ORDER BY total_revenue DESC;

SELECT
    DATE_TRUNC('MONTH', sale_date) AS month,
    SUM(total_amount) AS monthly_revenue
FROM sales_history
GROUP BY DATE_TRUNC('MONTH', sale_date)
ORDER BY month;

SELECT
    c.customer_id,
    c.customer_name,
    SUM(s.total_amount) AS total_revenue
FROM customers AS c
JOIN sales_history AS s
    ON c.customer_id = s.customer_id
GROUP BY
    c.customer_id,
    c.customer_name
ORDER BY total_revenue DESC
LIMIT 5;

SELECT
    b.branch_id,
    b.branch_name,
    SUM(s.total_amount) AS total_revenue
FROM branches AS b
JOIN sales_history AS s
    ON b.branch_id = s.branch_id
GROUP BY
    b.branch_id,
    b.branch_name
ORDER BY total_revenue DESC
LIMIT 1;

SELECT
    p.product_id,
    p.product_name,
    SUM(s.total_amount) AS total_revenue
FROM products AS p
JOIN sales_history AS s
    ON p.product_id = s.product_id
GROUP BY
    p.product_id,
    p.product_name
ORDER BY total_revenue DESC
LIMIT 5;

SELECT
    c.customer_id,
    c.customer_name,
    COUNT(s.sale_id) AS purchase_frequency
FROM customers AS c
JOIN sales_history AS s
    ON c.customer_id = s.customer_id
GROUP BY
    c.customer_id,
    c.customer_name
ORDER BY purchase_frequency DESC;

SELECT
    sale_date,
    sale_id,
    total_amount,
    SUM(total_amount) OVER (
        ORDER BY sale_date, sale_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_revenue
FROM sales_history
ORDER BY sale_date, sale_id;

WITH customer_revenue AS (
    SELECT
        c.customer_id,
        c.customer_name,
        SUM(s.total_amount) AS total_revenue
    FROM customers AS c
    JOIN sales_history AS s
        ON c.customer_id = s.customer_id
    GROUP BY
        c.customer_id,
        c.customer_name
)

SELECT
    customer_id,
    customer_name,
    total_revenue,
    RANK() OVER (
        ORDER BY total_revenue DESC
    ) AS customer_rank
FROM customer_revenue
ORDER BY customer_rank;

CREATE OR REPLACE VIEW customer_revenue AS
SELECT
    c.customer_id,
    c.customer_name,
    SUM(s.total_amount) AS total_revenue
FROM customers AS c
JOIN sales_history AS s
    ON c.customer_id = s.customer_id
GROUP BY
    c.customer_id,
    c.customer_name;

SELECT *
FROM customer_revenue
ORDER BY total_revenue DESC;

CREATE OR REPLACE MATERIALIZED VIEW branch_revenue AS
SELECT
    branch_id,
    SUM(total_amount) AS total_revenue
FROM sales_history
GROUP BY branch_id;

SELECT *
FROM branch_revenue
ORDER BY total_revenue DESC;

SHOW TABLES;

SHOW STREAMS;

SHOW TASKS;

SHOW VIEWS;

SHOW MATERIALIZED VIEWS;
