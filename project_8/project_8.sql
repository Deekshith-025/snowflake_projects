-- PROJECT 8
-- CUSTOMER PROFILE HISTORY ANALYSIS USING SNOWFLAKE
-- SLOWLY CHANGING DIMENSION PROBLEM

CREATE OR REPLACE WAREHOUSE customer_history_wh
WITH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

USE WAREHOUSE customer_history_wh;

CREATE OR REPLACE DATABASE customer_profile_history_db;

USE DATABASE customer_profile_history_db;

CREATE OR REPLACE SCHEMA customer_history;

USE SCHEMA customer_history;


CREATE OR REPLACE FILE FORMAT customer_csv_format
TYPE = 'CSV'
FIELD_DELIMITER = ','
SKIP_HEADER = 1
FIELD_OPTIONALLY_ENCLOSED_BY = '"'
EMPTY_FIELD_AS_NULL = TRUE;


CREATE OR REPLACE STAGE initial_customer_stage
FILE_FORMAT = customer_csv_format;

LIST @initial_customer_stage;


CREATE OR REPLACE TABLE dim_customer (
    customer_key NUMBER AUTOINCREMENT,
    customer_id NUMBER,
    customer_name VARCHAR(100),
    city VARCHAR(100),
    state VARCHAR(100),
    membership VARCHAR(50),
    segment VARCHAR(50)
);


COPY INTO dim_customer (
    customer_id,
    customer_name,
    city,
    state,
    membership,
    segment
)
FROM @initial_customer_stage
FILE_FORMAT = (
    FORMAT_NAME = customer_csv_format
)
ON_ERROR = 'ABORT_STATEMENT';



SELECT COUNT(*) AS total_customers
FROM dim_customer;


SELECT
    customer_id,
    customer_name,
    city,
    state,
    membership,
    segment
FROM dim_customer
ORDER BY customer_id;


CREATE OR REPLACE STAGE customer_updates_stage
FILE_FORMAT = customer_csv_format;

show stages;
LIST @customer_updates_stage;


CREATE OR REPLACE TABLE customer_updates (
    customer_id NUMBER,
    customer_name VARCHAR(100),
    city VARCHAR(100),
    state VARCHAR(100),
    membership VARCHAR(50),
    segment VARCHAR(50)
);


COPY INTO customer_updates (
    customer_id,
    customer_name,
    city,
    state,
    membership,
    segment
)
FROM @customer_updates_stage
FILE_FORMAT = (
    FORMAT_NAME = customer_csv_format
)
ON_ERROR = 'ABORT_STATEMENT';


SELECT COUNT(*) AS records_received
FROM customer_updates;


SELECT
    customer_id,
    customer_name,
    city,
    state,
    membership,
    segment
FROM customer_updates
ORDER BY customer_id;


SELECT
    d.customer_id,
    d.city AS old_city,
    u.city AS new_city,
    d.membership AS old_membership,
    u.membership AS new_membership
FROM dim_customer d
INNER JOIN customer_updates u
    ON d.customer_id = u.customer_id
WHERE d.city <> u.city
   OR d.state <> u.state
   OR d.membership <> u.membership
   OR d.segment <> u.segment
ORDER BY d.customer_id;


SELECT
    d.customer_id,
    'CITY' AS attribute,
    d.city AS old_value,
    u.city AS new_value
FROM dim_customer d
INNER JOIN customer_updates u
    ON d.customer_id = u.customer_id
WHERE d.city <> u.city

UNION ALL

SELECT
    d.customer_id,
    'STATE' AS attribute,
    d.state AS old_value,
    u.state AS new_value
FROM dim_customer d
INNER JOIN customer_updates u
    ON d.customer_id = u.customer_id
WHERE d.state <> u.state

UNION ALL

SELECT
    d.customer_id,
    'MEMBERSHIP' AS attribute,
    d.membership AS old_value,
    u.membership AS new_value
FROM dim_customer d
INNER JOIN customer_updates u
    ON d.customer_id = u.customer_id
WHERE d.membership <> u.membership

UNION ALL

SELECT
    d.customer_id,
    'SEGMENT' AS attribute,
    d.segment AS old_value,
    u.segment AS new_value
FROM dim_customer d
INNER JOIN customer_updates u
    ON d.customer_id = u.customer_id
WHERE d.segment <> u.segment

ORDER BY customer_id, attribute;


UPDATE dim_customer d
SET
    customer_name = u.customer_name,
    city = u.city,
    state = u.state,
    membership = u.membership,
    segment = u.segment
FROM customer_updates u
WHERE d.customer_id = u.customer_id;


SELECT
    customer_id,
    customer_name,
    city,
    state,
    membership,
    segment
FROM dim_customer
ORDER BY customer_id;


SELECT
    customer_id,
    customer_name,
    city,
    state,
    membership
FROM dim_customer
WHERE customer_id = 101;


SELECT COUNT(*) AS total_customers
FROM dim_customer;

