

CREATE WAREHOUSE IF NOT EXISTS retail_wh
WITH
    WAREHOUSE_SIZE = 'x-small'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

USE WAREHOUSE retail_wh;



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

CREATE OR REPLACE TABLE dim_region (
    region_id NUMBER PRIMARY KEY,
    region_name VARCHAR
);

CREATE OR REPLACE TABLE dim_state (
    state_id NUMBER PRIMARY KEY,
    state_name VARCHAR,
    region_id NUMBER,
    FOREIGN KEY (region_id)
        REFERENCES dim_region(region_id)
);

CREATE OR REPLACE TABLE dim_city (
    city_id NUMBER PRIMARY KEY,
    city_name VARCHAR,
    state_id NUMBER,
    FOREIGN KEY (state_id)
        REFERENCES dim_state(state_id)
);

CREATE OR REPLACE TABLE dim_category (
    category_id NUMBER PRIMARY KEY,
    category_name VARCHAR
);

CREATE OR REPLACE TABLE dim_brand (
    brand_id NUMBER PRIMARY KEY,
    brand_name VARCHAR,
    category_id NUMBER,
    FOREIGN KEY (category_id)
        REFERENCES dim_category(category_id)
);

CREATE OR REPLACE TABLE dim_year (
    year_id NUMBER PRIMARY KEY,
    year_value NUMBER
);

CREATE OR REPLACE TABLE dim_quarter (
    quarter_id NUMBER PRIMARY KEY,
    quarter_name VARCHAR,
    year_id NUMBER,
    FOREIGN KEY (year_id)
        REFERENCES dim_year(year_id)
);

CREATE OR REPLACE TABLE dim_month (
    month_id NUMBER PRIMARY KEY,
    month_name VARCHAR,
    quarter_id NUMBER,
    FOREIGN KEY (quarter_id)
        REFERENCES dim_quarter(quarter_id)
);


INSERT INTO dim_region (
    region_id,
    region_name
)
SELECT
    ROW_NUMBER() OVER (ORDER BY region) AS region_id,
    region
FROM (
    SELECT DISTINCT region
    FROM staging.stg_branches
);


INSERT INTO dim_state (
    state_id,
    state_name,
    region_id
)
SELECT
    ROW_NUMBER() OVER (ORDER BY state_name) AS state_id,
    state_name,
    region_id
FROM (
    SELECT
        state AS state_name,
        region_id
    FROM (
        SELECT DISTINCT
            b.state,
            r.region_id
        FROM staging.stg_branches b
        JOIN dim_region r
            ON b.region = r.region_name
    )

    UNION

    SELECT
        state AS state_name,
        CASE
            WHEN state IN ('Andhra Pradesh') THEN
                (SELECT region_id FROM dim_region WHERE region_name = 'South')
            WHEN state IN ('Bihar', 'Madhya Pradesh', 'Chandigarh') THEN
                (SELECT region_id FROM dim_region WHERE region_name = 'North')
            ELSE NULL
        END AS region_id
    FROM staging.stg_customers
    WHERE state NOT IN (
        SELECT DISTINCT state
        FROM staging.stg_branches
    )
);

INSERT INTO dim_city (
    city_id,
    city_name,
    state_id
)
SELECT
    ROW_NUMBER() OVER (ORDER BY city_name) AS city_id,
    city_name,
    state_id
FROM (
    SELECT DISTINCT
        c.city AS city_name,
        s.state_id
    FROM staging.stg_customers c
    JOIN dim_state s
        ON c.state = s.state_name

    UNION

    SELECT DISTINCT
        b.city AS city_name,
        s.state_id
    FROM staging.stg_branches b
    JOIN dim_state s
        ON b.state = s.state_name
);


INSERT INTO dim_category (
    category_id,
    category_name
)
SELECT
    ROW_NUMBER() OVER (ORDER BY category) AS category_id,
    category
FROM (
    SELECT DISTINCT category
    FROM staging.stg_products
);


INSERT INTO dim_brand (
    brand_id,
    brand_name,
    category_id
)
SELECT
    ROW_NUMBER() OVER (ORDER BY p.brand) AS brand_id,
    p.brand,
    c.category_id
FROM (
    SELECT DISTINCT
        brand,
        category
    FROM staging.stg_products
) p
JOIN dim_category c
    ON p.category = c.category_name;


INSERT INTO dim_year (
    year_id,
    year_value
)
SELECT
    ROW_NUMBER() OVER (ORDER BY year) AS year_id,
    year
FROM (
    SELECT DISTINCT year
    FROM staging.stg_calendar
);


INSERT INTO dim_quarter (
    quarter_id,
    quarter_name,
    year_id
)
SELECT
    ROW_NUMBER() OVER (ORDER BY c.year, c.quarter) AS quarter_id,
    c.quarter,
    y.year_id
FROM (
    SELECT DISTINCT
        year,
        quarter
    FROM staging.stg_calendar
) c
JOIN dim_year y
    ON c.year = y.year_value;


INSERT INTO dim_month (
    month_id,
    month_name,
    quarter_id
)
SELECT
    ROW_NUMBER() OVER (ORDER BY c.year, c.month) AS month_id,
    c.month,
    q.quarter_id
FROM (
    SELECT DISTINCT
        year,
        quarter,
        month
    FROM staging.stg_calendar
) c
JOIN dim_year y
    ON c.year = y.year_value
JOIN dim_quarter q
    ON q.year_id = y.year_id
    AND q.quarter_name = c.quarter;


CREATE OR REPLACE TABLE dim_customer (
    customer_id NUMBER PRIMARY KEY,
    customer_name VARCHAR,
    city_id NUMBER,
    membership VARCHAR,
    FOREIGN KEY (city_id)
        REFERENCES dim_city(city_id)
);



CREATE OR REPLACE TABLE dim_product (
    product_id NUMBER PRIMARY KEY,
    product_name VARCHAR,
    brand_id NUMBER,
    price NUMBER(12,2),
    FOREIGN KEY (brand_id)
        REFERENCES dim_brand(brand_id)
);


CREATE OR REPLACE TABLE dim_branch (
    branch_id NUMBER PRIMARY KEY,
    branch_name VARCHAR,
    city_id NUMBER,
    manager_name VARCHAR,
    FOREIGN KEY (city_id)
        REFERENCES dim_city(city_id)
);



CREATE OR REPLACE TABLE dim_date (
    date_id NUMBER PRIMARY KEY,
    date DATE,
    day NUMBER,
    day_name VARCHAR,
    week_no NUMBER,
    month_id NUMBER,
    is_weekend VARCHAR,
    FOREIGN KEY (month_id)
        REFERENCES dim_month(month_id)
);


INSERT INTO dim_customer (
    customer_id,
    customer_name,
    city_id,
    membership
)
SELECT
    c.customer_id,
    c.customer_name,
    ci.city_id,
    c.membership
FROM staging.stg_customers c
JOIN dim_city ci
    ON c.city = ci.city_name;


SELECT COUNT(*) AS row_count
FROM dim_customer;

SELECT *
FROM dim_customer;


INSERT INTO dim_product (
    product_id,
    product_name,
    brand_id,
    price
)
SELECT
    p.product_id,
    p.product_name,
    b.brand_id,
    p.price
FROM staging.stg_products p
JOIN dim_brand b
    ON p.brand = b.brand_name;


SELECT COUNT(*) AS row_count
FROM dim_product;

SELECT *
FROM dim_product;


INSERT INTO dim_branch (
    branch_id,
    branch_name,
    city_id,
    manager_name
)
SELECT
    b.branch_id,
    b.branch_name,
    ci.city_id,
    b.manager_name
FROM staging.stg_branches b
JOIN dim_city ci
    ON b.city = ci.city_name;


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
    month_id,
    is_weekend
)
SELECT
    c.date_id,
    c.date,
    c.day,
    c.day_name,
    c.week_no,
    m.month_id,
    c.is_weekend
FROM staging.stg_calendar c
JOIN dim_month m
    ON c.month = m.month_name;


SELECT COUNT(*) AS row_count
FROM dim_date;

SELECT *
FROM dim_date;


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
SELECT 'dim_city', COUNT(*)
FROM dim_city
UNION ALL
SELECT 'dim_state', COUNT(*)
FROM dim_state
UNION ALL
SELECT 'dim_region', COUNT(*)
FROM dim_region
UNION ALL
SELECT 'dim_category', COUNT(*)
FROM dim_category
UNION ALL
SELECT 'dim_brand', COUNT(*)
FROM dim_brand
UNION ALL
SELECT 'dim_month', COUNT(*)
FROM dim_month
UNION ALL
SELECT 'dim_quarter', COUNT(*)
FROM dim_quarter
UNION ALL
SELECT 'dim_year', COUNT(*)
FROM dim_year
UNION ALL
SELECT 'fact_sales', COUNT(*)
FROM fact_sales;


SELECT
    c.customer_id,
    c.customer_name,
    ci.city_name,
    s.state_name,
    r.region_name,
    c.membership
FROM dim_customer c
JOIN dim_city ci
    ON c.city_id = ci.city_id
JOIN dim_state s
    ON ci.state_id = s.state_id
LEFT JOIN dim_region r
    ON s.region_id = r.region_id
ORDER BY c.customer_id;



SELECT
    p.product_id,
    p.product_name,
    b.brand_name,
    c.category_name,
    p.price
FROM dim_product p
JOIN dim_brand b
    ON p.brand_id = b.brand_id
JOIN dim_category c
    ON b.category_id = c.category_id
ORDER BY p.product_id;


SELECT
    b.branch_id,
    b.branch_name,
    ci.city_name,
    s.state_name,
    r.region_name,
    b.manager_name
FROM dim_branch b
JOIN dim_city ci
    ON b.city_id = ci.city_id
JOIN dim_state s
    ON ci.state_id = s.state_id
JOIN dim_region r
    ON s.region_id = r.region_id
ORDER BY b.branch_id;


SELECT
    d.date_id,
    d.date,
    d.day,
    d.day_name,
    d.week_no,
    m.month_name,
    q.quarter_name,
    y.year_value,
    d.is_weekend
FROM dim_date d
JOIN dim_month m
    ON d.month_id = m.month_id
JOIN dim_quarter q
    ON m.quarter_id = q.quarter_id
JOIN dim_year y
    ON q.year_id = y.year_id
ORDER BY d.date_id;

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
    SUM(f.total_amount) AS total_revenue
FROM fact_sales f
JOIN dim_product p
    ON f.product_id = p.product_id
GROUP BY
    p.product_id,
    p.product_name
ORDER BY total_revenue DESC;


SELECT
    b.brand_name,
    SUM(f.total_amount) AS total_revenue
FROM fact_sales f
JOIN dim_product p
    ON f.product_id = p.product_id
JOIN dim_brand b
    ON p.brand_id = b.brand_id
GROUP BY
    b.brand_name
ORDER BY total_revenue DESC;



SELECT
    c.category_name,
    SUM(f.total_amount) AS total_revenue
FROM fact_sales f
JOIN dim_product p
    ON f.product_id = p.product_id
JOIN dim_brand b
    ON p.brand_id = b.brand_id
JOIN dim_category c
    ON b.category_id = c.category_id
GROUP BY
    c.category_name
ORDER BY total_revenue DESC;


SELECT
    ci.city_name,
    SUM(f.total_amount) AS total_sales
FROM fact_sales f
JOIN dim_customer c
    ON f.customer_id = c.customer_id
JOIN dim_city ci
    ON c.city_id = ci.city_id
GROUP BY
    ci.city_name
ORDER BY total_sales DESC;



SELECT
    s.state_name,
    SUM(f.total_amount) AS total_revenue
FROM fact_sales f
JOIN dim_customer c
    ON f.customer_id = c.customer_id
JOIN dim_city ci
    ON c.city_id = ci.city_id
JOIN dim_state s
    ON ci.state_id = s.state_id
GROUP BY
    s.state_name
ORDER BY total_revenue DESC;


SELECT
    r.region_name,
    SUM(f.total_amount) AS total_revenue
FROM fact_sales f
JOIN dim_branch b
    ON f.branch_id = b.branch_id
JOIN dim_city ci
    ON b.city_id = ci.city_id
JOIN dim_state s
    ON ci.state_id = s.state_id
JOIN dim_region r
    ON s.region_id = r.region_id
GROUP BY
    r.region_name
ORDER BY total_revenue DESC;


SELECT
    m.month_name,
    SUM(f.total_amount) AS total_revenue
FROM fact_sales f
JOIN dim_date d
    ON f.date_id = d.date_id
JOIN dim_month m
    ON d.month_id = m.month_id
GROUP BY
    m.month_name
ORDER BY total_revenue DESC;


SELECT
    q.quarter_name,
    SUM(f.total_amount) AS total_revenue
FROM fact_sales f
JOIN dim_date d
    ON f.date_id = d.date_id
JOIN dim_month m
    ON d.month_id = m.month_id
JOIN dim_quarter q
    ON m.quarter_id = q.quarter_id
GROUP BY
    q.quarter_name
ORDER BY total_revenue DESC;


SELECT
    c.customer_id,
    c.customer_name,
    SUM(f.total_amount) AS total_revenue
FROM fact_sales f
JOIN dim_customer c
    ON f.customer_id = c.customer_id
GROUP BY
    c.customer_id,
    c.customer_name
ORDER BY total_revenue DESC
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
    SUM(f.total_amount) AS total_revenue
FROM fact_sales f
JOIN dim_branch b
    ON f.branch_id = b.branch_id
GROUP BY
    b.branch_id,
    b.branch_name
ORDER BY total_revenue DESC
LIMIT 10;



SELECT
    c.customer_name,
    d.date,
    SUM(f.total_amount) AS daily_purchase
FROM fact_sales f
JOIN dim_customer c
    ON f.customer_id = c.customer_id
JOIN dim_date d
    ON f.date_id = d.date_id
GROUP BY
    c.customer_name,
    d.date
ORDER BY
    c.customer_name,
    d.date;



SELECT
    p.product_name,
    SUM(f.quantity) AS total_quantity,
    SUM(f.total_amount) AS total_revenue
FROM fact_sales f
JOIN dim_product p
    ON f.product_id = p.product_id
GROUP BY
    p.product_name
ORDER BY total_revenue DESC;


SELECT
    r.region_name,
    SUM(f.quantity) AS total_quantity,
    SUM(f.total_amount) AS total_revenue
FROM fact_sales f
JOIN dim_branch b
    ON f.branch_id = b.branch_id
JOIN dim_city ci
    ON b.city_id = ci.city_id
JOIN dim_state s
    ON ci.state_id = s.state_id
JOIN dim_region r
    ON s.region_id = r.region_id
GROUP BY
    r.region_name
ORDER BY total_revenue DESC;


SELECT
    f.sale_id,
    c.customer_name,
    ci.city_name AS customer_city,
    cs.state_name AS customer_state,
    p.product_name,
    pb.brand_name,
    pc.category_name,
    br.branch_name,
    bci.city_name AS branch_city,
    bs.state_name AS branch_state,
    r.region_name,
    d.date,
    m.month_name,
    q.quarter_name,
    y.year_value,
    f.quantity,
    f.total_amount
FROM fact_sales f
JOIN dim_customer c
    ON f.customer_id = c.customer_id
JOIN dim_city ci
    ON c.city_id = ci.city_id
JOIN dim_state cs
    ON ci.state_id = cs.state_id
LEFT JOIN dim_region cr
    ON cs.region_id = cr.region_id
JOIN dim_product p
    ON f.product_id = p.product_id
JOIN dim_brand pb
    ON p.brand_id = pb.brand_id
JOIN dim_category pc
    ON pb.category_id = pc.category_id
JOIN dim_branch br
    ON f.branch_id = br.branch_id
JOIN dim_city bci
    ON br.city_id = bci.city_id
JOIN dim_state bs
    ON bci.state_id = bs.state_id
JOIN dim_region r
    ON bs.region_id = r.region_id
JOIN dim_date d
    ON f.date_id = d.date_id
JOIN dim_month m
    ON d.month_id = m.month_id
JOIN dim_quarter q
    ON m.quarter_id = q.quarter_id
JOIN dim_year y
    ON q.year_id = y.year_id
ORDER BY f.sale_id;


SELECT
    (SELECT COUNT(*) FROM dim_customer) AS customers,
    (SELECT COUNT(*) FROM dim_product) AS products,
    (SELECT COUNT(*) FROM dim_branch) AS branches,
    (SELECT COUNT(*) FROM dim_date) AS dates,
    (SELECT COUNT(*) FROM dim_city) AS cities,
    (SELECT COUNT(*) FROM dim_state) AS states,
    (SELECT COUNT(*) FROM dim_region) AS regions,
    (SELECT COUNT(*) FROM dim_category) AS categories,
    (SELECT COUNT(*) FROM dim_brand) AS brands,
    (SELECT COUNT(*) FROM dim_month) AS months,
    (SELECT COUNT(*) FROM dim_quarter) AS quarters,
    (SELECT COUNT(*) FROM dim_year) AS years,
    (SELECT COUNT(*) FROM fact_sales) AS sales;
