-- PROJECT 10: Customer Membership History using SCD Type 3 and Type 6

CREATE OR REPLACE WAREHOUSE customer_scd_wh
WITH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;

USE WAREHOUSE customer_scd_wh;


CREATE OR REPLACE DATABASE customer_scd_db;

USE DATABASE customer_scd_db;


CREATE OR REPLACE SCHEMA customer_scd_schema;

USE SCHEMA customer_scd_schema;


CREATE OR REPLACE FILE FORMAT customer_csv_format
TYPE = 'CSV'
FIELD_DELIMITER = ','
SKIP_HEADER = 1
FIELD_OPTIONALLY_ENCLOSED_BY = '"'
NULL_IF = ('NULL', 'null', '');

CREATE OR REPLACE STAGE customer_stage
FILE_FORMAT = customer_csv_format;

LIST @customer_stage;


CREATE OR REPLACE TABLE customers_initial (
    customer_id NUMBER,
    customer_name VARCHAR,
    city VARCHAR,
    state VARCHAR,
    membership VARCHAR,
    segment VARCHAR
);

CREATE OR REPLACE TABLE customer_updates (
    customer_id NUMBER,
    customer_name VARCHAR,
    city VARCHAR,
    state VARCHAR,
    membership VARCHAR,
    segment VARCHAR,
    effective_date DATE
);


COPY INTO customers_initial
FROM @customer_stage/customers_initial.csv
FILE_FORMAT = customer_csv_format
ON_ERROR = 'ABORT_STATEMENT';

SELECT *
FROM customers_initial
ORDER BY customer_id;


COPY INTO customer_updates
FROM @customer_stage/customer_updates.csv
FILE_FORMAT = customer_csv_format
ON_ERROR = 'ABORT_STATEMENT';

SELECT *
FROM customer_updates
ORDER BY customer_id;


CREATE OR REPLACE TABLE dim_customer_type3 (
    customer_key NUMBER AUTOINCREMENT,
    customer_id NUMBER,
    customer_name VARCHAR,
    city VARCHAR,
    state VARCHAR,
    current_membership VARCHAR,
    previous_membership VARCHAR,
    segment VARCHAR
);



INSERT INTO dim_customer_type3 (
    customer_id,
    customer_name,
    city,
    state,
    current_membership,
    previous_membership,
    segment
)
SELECT
    customer_id,
    customer_name,
    city,
    state,
    membership,
    NULL,
    segment
FROM customers_initial;

SELECT *
FROM dim_customer_type3
ORDER BY customer_id;


MERGE INTO dim_customer_type3 AS target
USING customer_updates AS source
ON target.customer_id = source.customer_id

WHEN MATCHED THEN
UPDATE SET
    target.customer_name = source.customer_name,
    target.city = source.city,
    target.state = source.state,
    target.previous_membership = target.current_membership,
    target.current_membership = source.membership,
    target.segment = source.segment;


SELECT
    customer_id,
    customer_name,
    city,
    current_membership,
    previous_membership
FROM dim_customer_type3
ORDER BY customer_id;


SELECT
    customer_id,
    customer_name,
    current_membership,
    previous_membership
FROM dim_customer_type3
WHERE customer_id = 101;


CREATE OR REPLACE TABLE dim_customer_type6 (
    customer_key NUMBER AUTOINCREMENT,
    customer_id NUMBER,
    customer_name VARCHAR,
    city VARCHAR,
    state VARCHAR,
    current_membership VARCHAR,
    previous_membership VARCHAR,
    historical_membership VARCHAR,
    segment VARCHAR,
    effective_date DATE,
    expiry_date DATE,
    is_current BOOLEAN
);


INSERT INTO dim_customer_type6 (
    customer_id,
    customer_name,
    city,
    state,
    current_membership,
    previous_membership,
    historical_membership,
    segment,
    effective_date,
    expiry_date,
    is_current
)
SELECT
    customer_id,
    customer_name,
    city,
    state,
    membership,
    NULL,
    membership,
    segment,
    '2026-01-01',
    '9999-12-31',
    TRUE
FROM customers_initial;

SELECT *
FROM dim_customer_type6
ORDER BY customer_id;


UPDATE dim_customer_type6
SET
    expiry_date = DATEADD(DAY, -1, '2026-04-01'),
    is_current = FALSE
WHERE customer_id = 101
  AND is_current = TRUE;

INSERT INTO dim_customer_type6 (
    customer_id,
    customer_name,
    city,
    state,
    current_membership,
    previous_membership,
    historical_membership,
    segment,
    effective_date,
    expiry_date,
    is_current
)
SELECT
    u.customer_id,
    u.customer_name,
    u.city,
    u.state,
    u.membership,
    t.current_membership,
    u.membership,
    u.segment,
    u.effective_date,
    '9999-12-31',
    TRUE
FROM customer_updates u
JOIN dim_customer_type6 t
    ON u.customer_id = t.customer_id
WHERE u.customer_id = 101
  AND t.is_current = FALSE
  AND t.expiry_date = '2026-03-31';


UPDATE dim_customer_type6
SET
    expiry_date = DATEADD(DAY, -1, '2026-04-05'),
    is_current = FALSE
WHERE customer_id = 103
  AND is_current = TRUE;

INSERT INTO dim_customer_type6 (
    customer_id,
    customer_name,
    city,
    state,
    current_membership,
    previous_membership,
    historical_membership,
    segment,
    effective_date,
    expiry_date,
    is_current
)
SELECT
    u.customer_id,
    u.customer_name,
    u.city,
    u.state,
    u.membership,
    t.current_membership,
    u.membership,
    u.segment,
    u.effective_date,
    '9999-12-31',
    TRUE
FROM customer_updates u
JOIN dim_customer_type6 t
    ON u.customer_id = t.customer_id
WHERE u.customer_id = 103
  AND t.is_current = FALSE
  AND t.expiry_date = '2026-04-04';


UPDATE dim_customer_type6
SET
    expiry_date = DATEADD(DAY, -1, '2026-04-10'),
    is_current = FALSE
WHERE customer_id = 104
  AND is_current = TRUE;

INSERT INTO dim_customer_type6 (
    customer_id,
    customer_name,
    city,
    state,
    current_membership,
    previous_membership,
    historical_membership,
    segment,
    effective_date,
    expiry_date,
    is_current
)
SELECT
    u.customer_id,
    u.customer_name,
    u.city,
    u.state,
    u.membership,
    t.current_membership,
    u.membership,
    u.membership,
    u.segment,
    u.effective_date,
    '9999-12-31',
    TRUE
FROM customer_updates u
JOIN dim_customer_type6 t
    ON u.customer_id = t.customer_id
WHERE u.customer_id = 104
  AND t.is_current = FALSE
  AND t.expiry_date = '2026-04-09';



SELECT
    customer_id,
    customer_name,
    current_membership,
    previous_membership,
    effective_date,
    expiry_date,
    is_current
FROM dim_customer_type6
ORDER BY
    customer_id,
    effective_date;


SELECT
    customer_id,
    customer_name,
    city,
    current_membership,
    previous_membership
FROM dim_customer_type6
WHERE is_current = TRUE
ORDER BY customer_id;



SELECT
    customer_id,
    customer_name,
    current_membership,
    effective_date,
    expiry_date
FROM dim_customer_type6
WHERE customer_id = 101
  AND '2026-03-15' BETWEEN effective_date AND expiry_date;



SELECT
    'SCD TYPE 3' AS scd_type,
    'current + previous value' AS capability
UNION ALL
SELECT
    'SCD TYPE 6',
    'current + previous + historical rows + dates';



SELECT COUNT(*) AS scd_type3_record_count
FROM dim_customer_type3;


SELECT COUNT(*) AS scd_type6_record_count
FROM dim_customer_type6;


SELECT COUNT(*) AS scd_type6_current_record_count
FROM dim_customer_type6
WHERE is_current = TRUE;


SELECT COUNT(*) AS scd_type6_historical_record_count
FROM dim_customer_type6
WHERE is_current = FALSE;


SELECT
    (SELECT COUNT(*)
     FROM dim_customer_type3) AS scd_type3_record_count,

    (SELECT COUNT(*)
     FROM dim_customer_type6) AS scd_type6_record_count,

    (SELECT COUNT(*)
     FROM dim_customer_type6
     WHERE is_current = TRUE) AS scd_type6_current_record_count,

    (SELECT COUNT(*)
     FROM dim_customer_type6
     WHERE is_current = FALSE) AS scd_type6_historical_record_count;

