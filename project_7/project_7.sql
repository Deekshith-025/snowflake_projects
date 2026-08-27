
CREATE WAREHOUSE healthcare_wh
WITH
    warehouse_size = 'X-SMALL'
    auto_suspend = 60
    auto_resume = TRUE;

USE WAREHOUSE healthcare_wh;

CREATE DATABASE healthcare_dw;

CREATE SCHEMA healthcare_dw.analytics;

USE DATABASE healthcare_dw;

USE SCHEMA analytics;


CREATE OR REPLACE FILE FORMAT csv_format
TYPE = 'CSV'
field_delimiter = ','
FIELD_OPTIONALLY_ENCLOSED_BY = '"'
SKIP_HEADER = 1;

CREATE OR REPLACE STAGE healthcare_stage
FILE_FORMAT = csv_format;

LIST @healthcare_stage;


CREATE OR REPLACE TABLE raw_patients (
    patient_id VARCHAR,
    patient_name VARCHAR,
    gender VARCHAR,
    city VARCHAR,
    state VARCHAR
);

COPY INTO raw_patients
FROM @healthcare_stage/patients.csv
FILE_FORMAT = csv_format;

SELECT *
FROM raw_patients;


CREATE OR REPLACE TABLE raw_doctors (
    doctor_id VARCHAR,
    doctor_name VARCHAR,
    specialization VARCHAR
);

COPY INTO raw_doctors
FROM @healthcare_stage/doctors.csv
FILE_FORMAT = csv_format;

SELECT *
FROM raw_doctors;


CREATE OR REPLACE TABLE raw_hospitals (
    hospital_id VARCHAR,
    hospital_name VARCHAR,
    city VARCHAR,
    state VARCHAR,
    region VARCHAR
);

COPY INTO raw_hospitals
FROM @healthcare_stage/hospitals.csv
FILE_FORMAT = csv_format;

SELECT *
FROM raw_hospitals;


CREATE OR REPLACE TABLE raw_departments (
    department_id VARCHAR,
    department_name VARCHAR
);

COPY INTO raw_departments
FROM @healthcare_stage/departments.csv
FILE_FORMAT = csv_format;

SELECT *
FROM raw_departments;


CREATE OR REPLACE TABLE raw_treatments (
    treatment_id VARCHAR,
    treatment_name VARCHAR,
    treatment_category VARCHAR
);

COPY INTO raw_treatments
FROM @healthcare_stage/treatments.csv
FILE_FORMAT = csv_format;

SELECT *
FROM raw_treatments;


CREATE OR REPLACE TABLE raw_admissions (
    admission_id VARCHAR,
    patient_id VARCHAR,
    doctor_id VARCHAR,
    hospital_id VARCHAR,
    department_id VARCHAR,
    admission_date DATE,
    discharge_date DATE
);

COPY INTO raw_admissions
FROM @healthcare_stage/admissions.csv
FILE_FORMAT = csv_format;

SELECT *
FROM raw_admissions;



CREATE OR REPLACE TABLE raw_billing (
    admission_id VARCHAR,
    patient_id VARCHAR,
    doctor_id VARCHAR,
    hospital_id VARCHAR,
    department_id VARCHAR,
    admission_date DATE,
    discharge_date DATE
);

COPY INTO raw_billing
FROM @healthcare_stage/billing.csv
FILE_FORMAT = csv_format;

SELECT *
FROM raw_billing;



CREATE OR REPLACE TABLE dim_patient (
    patient_key NUMBER AUTOINCREMENT,
    patient_id VARCHAR,
    patient_name VARCHAR,
    gender VARCHAR,
    city VARCHAR,
    state VARCHAR,
    PRIMARY KEY (patient_key)
);

INSERT INTO dim_patient (
    patient_id,
    patient_name,
    gender,
    city,
    state
)
SELECT
    patient_id,
    patient_name,
    gender,
    city,
    state
FROM raw_patients;

SELECT *
FROM dim_patient
ORDER BY patient_key;



CREATE OR REPLACE TABLE dim_doctor (
    doctor_key NUMBER AUTOINCREMENT,
    doctor_id VARCHAR,
    doctor_name VARCHAR,
    specialization VARCHAR,
    PRIMARY KEY (doctor_key)
);

INSERT INTO dim_doctor (
    doctor_id,
    doctor_name,
    specialization
)
SELECT
    doctor_id,
    doctor_name,
    specialization
FROM raw_doctors;

SELECT *
FROM dim_doctor
ORDER BY doctor_key;


CREATE OR REPLACE TABLE dim_hospital (
    hospital_key NUMBER AUTOINCREMENT,
    hospital_id VARCHAR,
    hospital_name VARCHAR,
    city VARCHAR,
    state VARCHAR,
    region VARCHAR,
    PRIMARY KEY (hospital_key)
);

INSERT INTO dim_hospital (
    hospital_id,
    hospital_name,
    city,
    state,
    region
)
SELECT
    hospital_id,
    hospital_name,
    city,
    state,
    region
FROM raw_hospitals;

SELECT *
FROM dim_hospital
ORDER BY hospital_key;


CREATE OR REPLACE TABLE dim_department (
    department_key NUMBER AUTOINCREMENT,
    department_id VARCHAR,
    department_name VARCHAR,
    PRIMARY KEY (department_key)
);

INSERT INTO dim_department (
    department_id,
    department_name
)
SELECT
    department_id,
    department_name
FROM raw_departments;

SELECT *
FROM dim_department
ORDER BY department_key;

CREATE OR REPLACE TABLE dim_treatment (
    treatment_key NUMBER AUTOINCREMENT,
    treatment_id VARCHAR,
    treatment_name VARCHAR,
    treatment_category VARCHAR,
    PRIMARY KEY (treatment_key)
);

INSERT INTO dim_treatment (
    treatment_id,
    treatment_name,
    treatment_category
)
SELECT
    treatment_id,
    treatment_name,
    treatment_category
FROM raw_treatments;

SELECT *
FROM dim_treatment
ORDER BY treatment_key;


CREATE OR REPLACE TABLE dim_date (
    date_key NUMBER,
    full_date DATE,
    day NUMBER,
    day_name VARCHAR,
    week_no NUMBER,
    month NUMBER,
    month_name VARCHAR,
    quarter VARCHAR,
    year NUMBER,
    PRIMARY KEY (date_key)
);

INSERT INTO dim_date
SELECT
    TO_NUMBER(TO_CHAR(full_date, 'YYYYMMDD')) AS date_key,
    full_date,
    DAY(full_date) AS day,
    DAYNAME(full_date) AS day_name,
    WEEK(full_date) AS week_no,
    MONTH(full_date) AS month,
    MONTHNAME(full_date) AS month_name,
    'Q' || QUARTER(full_date) AS quarter,
    YEAR(full_date) AS year
FROM (
    SELECT
        DATEADD(
            DAY,
            seq4(),
            '2026-01-01'::DATE
        ) AS full_date
    FROM TABLE(GENERATOR(ROWCOUNT => 90))
);

SELECT *
FROM dim_date
ORDER BY full_date;

SELECT
    1 AS process_number,
    'Patient Admissions' AS business_process

UNION ALL

SELECT
    2 AS process_number,
    'Medical Billing' AS business_process;



CREATE OR REPLACE TABLE fact_admission (
    admission_key NUMBER AUTOINCREMENT,
    patient_key NUMBER,
    doctor_key NUMBER,
    hospital_key NUMBER,
    department_key NUMBER,
    date_key NUMBER,
    admission_count NUMBER,
    length_of_stay NUMBER,
    PRIMARY KEY (admission_key)
);



INSERT INTO fact_admission (
    patient_key,
    doctor_key,
    hospital_key,
    department_key,
    date_key,
    admission_count,
    length_of_stay
)
SELECT
    p.patient_key,
    d.doctor_key,
    h.hospital_key,
    dp.department_key,
    dt.date_key,
    1 AS admission_count,
    DATEDIFF(
        DAY,
        a.admission_date,
        a.discharge_date
    ) AS length_of_stay
FROM raw_admissions a
JOIN dim_patient p
    ON a.patient_id = p.patient_id
JOIN dim_doctor d
    ON a.doctor_id = d.doctor_id
JOIN dim_hospital h
    ON a.hospital_id = h.hospital_id
JOIN dim_department dp
    ON a.department_id = dp.department_id
JOIN dim_date dt
    ON a.admission_date = dt.full_date;

SELECT *
FROM fact_admission
ORDER BY admission_key;


CREATE OR REPLACE TABLE fact_billing (
    billing_key NUMBER AUTOINCREMENT,
    patient_key NUMBER,
    doctor_key NUMBER,
    hospital_key NUMBER,
    department_key NUMBER,
    treatment_key NUMBER,
    date_key NUMBER,
    quantity NUMBER,
    treatment_amount NUMBER(10,2),
    discount NUMBER(10,2),
    net_amount NUMBER(10,2),
    PRIMARY KEY (billing_key)
);



INSERT INTO fact_billing (
    patient_key,
    doctor_key,
    hospital_key,
    department_key,
    treatment_key,
    date_key,
    quantity,
    treatment_amount,
    discount,
    net_amount
)
SELECT
    p.patient_key,
    d.doctor_key,
    h.hospital_key,
    dp.department_key,
    t.treatment_key,
    dt.date_key,
    b.quantity,
    b.treatment_amount,
    b.discount,
    b.treatment_amount - b.discount AS net_amount
FROM raw_billing b
JOIN dim_patient p
    ON b.patient_id = p.patient_id
JOIN dim_doctor d
    ON b.doctor_id = d.doctor_id
JOIN dim_hospital h
    ON b.hospital_id = h.hospital_id
JOIN dim_department dp
    ON b.department_id = dp.department_id
JOIN dim_treatment t
    ON b.treatment_id = t.treatment_id
JOIN dim_date dt
    ON b.billing_date = dt.full_date;

SELECT *
FROM fact_billing
ORDER BY billing_key;


SELECT
    'fact_admission' AS fact_table,
    'admission_count' AS measure,
    'additive' AS measure_type

UNION ALL

SELECT
    'fact_admission',
    'length_of_stay',
    'additive'

UNION ALL

SELECT
    'fact_billing',
    'quantity',
    'additive'

UNION ALL

SELECT
    'fact_billing',
    'treatment_amount',
    'additive'

UNION ALL

SELECT
    'fact_billing',
    'discount',
    'additive'

UNION ALL

SELECT
    'fact_billing',
    'net_amount',
    'additive';


SELECT
    'dim_patient' AS dimension,
    'fact_admission' AS fact_1,
    'fact_billing' AS fact_2

UNION ALL

SELECT
    'dim_doctor',
    'fact_admission',
    'fact_billing'

UNION ALL

SELECT
    'dim_hospital',
    'fact_admission',
    'fact_billing'

UNION ALL

SELECT
    'dim_department',
    'fact_admission',
    'fact_billing'

UNION ALL

SELECT
    'dim_date',
    'fact_admission',
    'fact_billing'

UNION ALL

SELECT
    'dim_treatment',
    '-',
    'fact_billing';




SELECT
    h.hospital_name,
    SUM(f.admission_count) AS total_admissions
FROM fact_admission f
JOIN dim_hospital h
    ON f.hospital_key = h.hospital_key
GROUP BY
    h.hospital_name
ORDER BY
    total_admissions DESC;



SELECT
    d.department_name,
    SUM(f.admission_count) AS total_admissions
FROM fact_admission f
JOIN dim_department d
    ON f.department_key = d.department_key
GROUP BY
    d.department_name
ORDER BY
    total_admissions DESC;



SELECT
    d.doctor_name,
    SUM(f.admission_count) AS total_admissions
FROM fact_admission f
JOIN dim_doctor d
    ON f.doctor_key = d.doctor_key
GROUP BY
    d.doctor_name
ORDER BY
    total_admissions DESC;


SELECT
    d.year,
    d.month,
    d.month_name,
    SUM(f.admission_count) AS total_admissions
FROM fact_admission f
JOIN dim_date d
    ON f.date_key = d.date_key
GROUP BY
    d.year,
    d.month,
    d.month_name
ORDER BY
    d.year,
    d.month;



SELECT
    h.hospital_name,
    AVG(f.length_of_stay) AS average_length_of_stay
FROM fact_admission f
JOIN dim_hospital h
    ON f.hospital_key = h.hospital_key
GROUP BY
    h.hospital_name
ORDER BY
    average_length_of_stay DESC;



SELECT
    h.hospital_name,
    SUM(f.net_amount) AS total_revenue
FROM fact_billing f
JOIN dim_hospital h
    ON f.hospital_key = h.hospital_key
GROUP BY
    h.hospital_name
ORDER BY
    total_revenue DESC;



SELECT
    d.department_name,
    SUM(f.net_amount) AS total_revenue
FROM fact_billing f
JOIN dim_department d
    ON f.department_key = d.department_key
GROUP BY
    d.department_name
ORDER BY
    total_revenue DESC;


SELECT
    t.treatment_name,
    SUM(f.quantity) AS total_quantity,
    SUM(f.net_amount) AS total_revenue
FROM fact_billing f
JOIN dim_treatment t
    ON f.treatment_key = t.treatment_key
GROUP BY
    t.treatment_name
ORDER BY
    total_revenue DESC;


SELECT
    TO_CHAR(
        DATE_FROM_PARTS(d.year, d.month, 1),
        'YYYY-MM'
    ) AS month,
    SUM(f.net_amount) AS total_revenue
FROM fact_billing f
JOIN dim_date d
    ON f.date_key = d.date_key
GROUP BY
    d.year,
    d.month
ORDER BY
    d.year,
    d.month;



SELECT
    d.doctor_name,
    SUM(f.net_amount) AS total_revenue
FROM fact_billing f
JOIN dim_doctor d
    ON f.doctor_key = d.doctor_key
GROUP BY
    d.doctor_name
ORDER BY
    total_revenue DESC;



WITH admission_summary AS (
    SELECT
        hospital_key,
        SUM(admission_count) AS total_admissions
    FROM fact_admission
    GROUP BY
        hospital_key
),
billing_summary AS (
    SELECT
        hospital_key,
        SUM(net_amount) AS total_revenue
    FROM fact_billing
    GROUP BY
        hospital_key
)
SELECT
    h.hospital_name,
    a.total_admissions,
    b.total_revenue
FROM dim_hospital h
LEFT JOIN admission_summary a
    ON h.hospital_key = a.hospital_key
LEFT JOIN billing_summary b
    ON h.hospital_key = b.hospital_key
ORDER BY
    h.hospital_name;



SELECT
    'dim_patient' AS dimension,
    '✓' AS fact_admission,
    '✓' AS fact_billing

UNION ALL

SELECT
    'dim_doctor',
    '✓',
    '✓'

UNION ALL

SELECT
    'dim_hospital',
    '✓',
    '✓'

UNION ALL

SELECT
    'dim_department',
    '✓',
    '✓'

UNION ALL

SELECT
    'dim_date',
    '✓',
    '✓'

UNION ALL

SELECT
    'dim_treatment',
    '—',
    '✓';

SHOW TABLES;


SELECT
    'dim_patient' AS table_name,
    COUNT(*) AS row_count
FROM dim_patient

UNION ALL

SELECT
    'dim_doctor',
    COUNT(*)
FROM dim_doctor

UNION ALL

SELECT
    'dim_hospital',
    COUNT(*)
FROM dim_hospital

UNION ALL

SELECT
    'dim_department',
    COUNT(*)
FROM dim_department

UNION ALL

SELECT
    'dim_treatment',
    COUNT(*)
FROM dim_treatment

UNION ALL

SELECT
    'dim_date',
    COUNT(*)
FROM dim_date;


SELECT
    COUNT(*) AS total_rows,
    SUM(admission_count) AS total_admissions,
    SUM(length_of_stay) AS total_length_of_stay
FROM fact_admission;


SELECT
    COUNT(*) AS total_rows,
    SUM(quantity) AS total_quantity,
    SUM(treatment_amount) AS total_treatment_amount,
    SUM(discount) AS total_discount,
    SUM(net_amount) AS total_revenue
FROM fact_billing;



SELECT
    billing_key,
    treatment_amount,
    discount,
    net_amount,
    treatment_amount - discount AS calculated_net_amount
FROM fact_billing;



SELECT *
FROM fact_billing
WHERE net_amount <> treatment_amount - discount;



SELECT
    COUNT(*) AS unmatched_admission_rows
FROM fact_admission f
LEFT JOIN dim_patient p
    ON f.patient_key = p.patient_key
LEFT JOIN dim_doctor d
    ON f.doctor_key = d.doctor_key
LEFT JOIN dim_hospital h
    ON f.hospital_key = h.hospital_key
LEFT JOIN dim_department dp
    ON f.department_key = dp.department_key
LEFT JOIN dim_date dt
    ON f.date_key = dt.date_key
WHERE
    p.patient_key IS NULL
    OR d.doctor_key IS NULL
    OR h.hospital_key IS NULL
    OR dp.department_key IS NULL
    OR dt.date_key IS NULL;


SELECT
    COUNT(*) AS unmatched_billing_rows
FROM fact_billing f
LEFT JOIN dim_patient p
    ON f.patient_key = p.patient_key
LEFT JOIN dim_doctor d
    ON f.doctor_key = d.doctor_key
LEFT JOIN dim_hospital h
    ON f.hospital_key = h.hospital_key
LEFT JOIN dim_department dp
    ON f.department_key = dp.department_key
LEFT JOIN dim_treatment t
    ON f.treatment_key = t.treatment_key
LEFT JOIN dim_date dt
    ON f.date_key = dt.date_key
WHERE
    p.patient_key IS NULL
    OR d.doctor_key IS NULL
    OR h.hospital_key IS NULL
    OR dp.department_key IS NULL
    OR t.treatment_key IS NULL
    OR dt.date_key IS NULL;

