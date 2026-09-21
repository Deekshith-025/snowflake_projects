-- PROJECT 9: CUSTOMER HISTORY MANAGEMENT USING SCD TYPE 1 AND TYPE 2

CREATE WAREHOUSE project_9_wh
WITH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

USE WAREHOUSE project_9_wh;

CREATE DATABASE customer_history_db;

USE DATABASE customer_history_db;

CREATE SCHEMA customer_history_schema;

USE SCHEMA customer_history_schema;


CREATE FILE FORMAT customer_csv_format
TYPE = 'CSV'
FIELD_DELIMITER = ','
SKIP_HEADER = 1
FIELD_OPTIONALLY_ENCLOSED_BY = '"'
NULL_IF = ('NULL', 'null');

CREATE STAGE customer_stage
FILE_FORMAT = customer_csv_format;

SHOW STAGES;

LIST @customer_stage;

CREATE TABLE customers_initial (
    customer_id NUMBER,
    customer_name VARCHAR(100),
    city VARCHAR(50),
    state VARCHAR(50),
    membership VARCHAR(30),
    segment VARCHAR(30)
);

DESC TABLE customers_initial;

COPY INTO customers_initial
FROM @customer_stage
FILES = ('customers_initial.csv')
FILE_FORMAT = (
    FORMAT_NAME = customer_csv_format
)
ON_ERROR = 'CONTINUE';

SELECT *
FROM customers_initial
ORDER BY customer_id;

CREATE TABLE customer_updates (
    customer_id NUMBER,
    customer_name VARCHAR(100),
    city VARCHAR(50),
    state VARCHAR(50),
    membership VARCHAR(30),
    segment VARCHAR(30),
    effective_date DATE
);


COPY INTO customer_updates
FROM @customer_stage
FILES = ('customer_updates.csv')
FILE_FORMAT = (
    FORMAT_NAME = customer_csv_format
)
ON_ERROR = 'CONTINUE';

SELECT *
FROM customer_updates
ORDER BY customer_id;


CREATE TABLE customer_scd1 (
    customer_key NUMBER,
    customer_id NUMBER,
    customer_name VARCHAR(100),
    city VARCHAR(50),
    state VARCHAR(50),
    membership VARCHAR(30),
    segment VARCHAR(30)
);


CREATE SEQUENCE customer_scd1_seq
START = 1
INCREMENT = 1;


INSERT INTO customer_scd1 (
    customer_key,
    customer_id,
    customer_name,
    city,
    state,
    membership,
    segment
)
SELECT
    customer_scd1_seq.NEXTVAL,
    customer_id,
    customer_name,
    city,
    state,
    membership,
    segment
FROM customers_initial;


-- CHECK TYPE 1 INITIAL DATA
SELECT *
FROM customer_scd1
ORDER BY customer_id;


MERGE INTO customer_scd1 AS target
USING customer_updates AS source
ON target.customer_id = source.customer_id

WHEN MATCHED THEN
UPDATE SET
    target.customer_name = source.customer_name,
    target.city = source.city,
    target.state = source.state,
    target.membership = source.membership,
    target.segment = source.segment;


SELECT
    customer_id,
    customer_name,
    city,
    state,
    membership,
    segment
FROM customer_scd1
ORDER BY customer_id;


SELECT
    customer_id,
    city,
    state,
    membership
FROM customer_scd1
WHERE customer_id = 101;


CREATE TABLE customer_scd2 (
    customer_key NUMBER,
    customer_id NUMBER,
    customer_name VARCHAR(100),
    city VARCHAR(50),
    state VARCHAR(50),
    membership VARCHAR(30),
    segment VARCHAR(30),
    effective_date DATE,
    expiry_date DATE,
    is_current BOOLEAN
);

CREATE SEQUENCE customer_scd2_seq
START = 1
INCREMENT = 1;


INSERT INTO customer_scd2 (
    customer_key,
    customer_id,
    customer_name,
    city,
    state,
    membership,
    segment,
    effective_date,
    expiry_date,
    is_current
)
SELECT
    customer_scd2_seq.NEXTVAL,
    customer_id,
    customer_name,
    city,
    state,
    membership,
    segment,
    '2026-01-01',
    '9999-12-31',
    TRUE
FROM customers_initial;


SELECT *
FROM customer_scd2
ORDER BY customer_id, effective_date;


UPDATE customer_scd2
SET
    expiry_date = '2026-03-31',
    is_current = FALSE
WHERE customer_id = 101
  AND is_current = TRUE;


INSERT INTO customer_scd2 (
    customer_key,
    customer_id,
    customer_name,
    city,
    state,
    membership,
    segment,
    effective_date,
    expiry_date,
    is_current
)
SELECT
    customer_scd2_seq.NEXTVAL,
    customer_id,
    customer_name,
    city,
    state,
    membership,
    segment,
    effective_date,
    '9999-12-31',
    TRUE
FROM customer_updates
WHERE customer_id = 101;


SELECT
    customer_id,
    city,
    membership,
    effective_date,
    expiry_date,
    is_current
FROM customer_scd2
WHERE customer_id = 101
ORDER BY effective_date;


UPDATE customer_scd2
SET
    expiry_date = '2026-04-04',
    is_current = FALSE
WHERE customer_id = 103
  AND is_current = TRUE;


INSERT INTO customer_scd2 (
    customer_key,
    customer_id,
    customer_name,
    city,
    state,
    membership,
    segment,
    effective_date,
    expiry_date,
    is_current
)
SELECT
    customer_scd2_seq.NEXTVAL,
    customer_id,
    customer_name,
    city,
    state,
    membership,
    segment,
    effective_date,
    '9999-12-31',
    TRUE
FROM customer_updates
WHERE customer_id = 103;


SELECT
    customer_id,
    city,
    membership,
    effective_date,
    expiry_date,
    is_current
FROM customer_scd2
WHERE customer_id = 103
ORDER BY effective_date;


UPDATE customer_scd2
SET
    expiry_date = '2026-04-09',
    is_current = FALSE
WHERE customer_id = 104
  AND is_current = TRUE;


INSERT INTO customer_scd2 (
    customer_key,
    customer_id,
    customer_name,
    city,
    state,
    membership,
    segment,
    effective_date,
    expiry_date,
    is_current
)
SELECT
    customer_scd2_seq.NEXTVAL,
    customer_id,
    customer_name,
    city,
    state,
    membership,
    segment,
    effective_date,
    '9999-12-31',
    TRUE
FROM customer_updates
WHERE customer_id = 104;


SELECT
    customer_id,
    city,
    membership,
    effective_date,
    expiry_date,
    is_current
FROM customer_scd2
WHERE customer_id = 104
ORDER BY effective_date;


SELECT
    customer_id,
    customer_name,
    city,
    state,
    membership,
    effective_date,
    expiry_date,
    is_current
FROM customer_scd2
ORDER BY customer_id, effective_date;


SELECT
    customer_id,
    customer_name,
    city,
    state,
    membership,
    segment
FROM customer_scd2
WHERE is_current = TRUE
ORDER BY customer_id;


SELECT
    customer_id,
    customer_name,
    membership,
    city,
    effective_date,
    expiry_date
FROM customer_scd2
WHERE customer_id = 101
  AND '2026-03-15' BETWEEN effective_date AND expiry_date;


-- SCD TYPE 1:
-- Old value -> overwritten
-- History -> not preserved
-- New row -> no

-- SCD TYPE 2:
-- Old value -> preserved
-- History -> preserved
-- New row -> yes
-- Effective date -> yes
-- Expiry date -> yes
-- Is_current -> yes



-- TYPE 1 RECORD COUNT
SELECT COUNT(*) AS scd_type_1_record_count
FROM customer_scd1;


-- TYPE 2 TOTAL RECORD COUNT
SELECT COUNT(*) AS scd_type_2_record_count
FROM customer_scd2;


-- TYPE 2 CURRENT RECORD COUNT
SELECT COUNT(*) AS scd_type_2_current_record_count
FROM customer_scd2
WHERE is_current = TRUE;


-- TYPE 2 HISTORICAL RECORD COUNT
SELECT COUNT(*) AS scd_type_2_historical_record_count
FROM customer_scd2
WHERE is_current = FALSE;


SELECT
    (SELECT COUNT(*) FROM customer_scd1) AS scd_type_1_record_count,
    (SELECT COUNT(*) FROM customer_scd2) AS scd_type_2_record_count,
    (SELECT COUNT(*) FROM customer_scd2 WHERE is_current = TRUE) AS scd_type_2_current_record_count,
    (SELECT COUNT(*) FROM customer_scd2 WHERE is_current = FALSE) AS scd_type_2_historical_record_count;
