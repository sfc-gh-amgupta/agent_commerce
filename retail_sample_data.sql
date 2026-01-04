-- =====================================================
-- RETAIL DATA MODEL - SAMPLE DATA GENERATION
-- =====================================================
-- Description: Sample data insertion for retail dimensional model
-- Platform: Snowflake
-- =====================================================

USE DATABASE RETAIL_DB;
USE SCHEMA RETAIL_SCHEMA;

-- =====================================================
-- POPULATE DIMENSION TABLES
-- =====================================================

-- Populate DIM_DATE (3 years of data)
INSERT INTO DIM_DATE (
    DATE_KEY, DATE_ACTUAL, DAY_OF_WEEK, DAY_NAME, DAY_OF_MONTH, DAY_OF_YEAR,
    WEEK_OF_YEAR, MONTH_NUMBER, MONTH_NAME, MONTH_ABBREV, QUARTER_NUMBER,
    QUARTER_NAME, YEAR_NUMBER, IS_WEEKEND, IS_HOLIDAY, HOLIDAY_NAME,
    FISCAL_YEAR, FISCAL_QUARTER, FISCAL_PERIOD
)
WITH date_range AS (
    SELECT 
        DATEADD(day, SEQ4(), '2022-01-01')::DATE AS date_actual
    FROM TABLE(GENERATOR(ROWCOUNT => 1095)) -- 3 years
)
SELECT
    TO_NUMBER(TO_CHAR(date_actual, 'YYYYMMDD')) AS DATE_KEY,
    date_actual,
    DAYOFWEEK(date_actual) AS DAY_OF_WEEK,
    DAYNAME(date_actual) AS DAY_NAME,
    DAYOFMONTH(date_actual) AS DAY_OF_MONTH,
    DAYOFYEAR(date_actual) AS DAY_OF_YEAR,
    WEEKOFYEAR(date_actual) AS WEEK_OF_YEAR,
    MONTH(date_actual) AS MONTH_NUMBER,
    MONTHNAME(date_actual) AS MONTH_NAME,
    TO_CHAR(date_actual, 'MON') AS MONTH_ABBREV,
    QUARTER(date_actual) AS QUARTER_NUMBER,
    'Q' || QUARTER(date_actual) AS QUARTER_NAME,
    YEAR(date_actual) AS YEAR_NUMBER,
    CASE WHEN DAYOFWEEK(date_actual) IN (0, 6) THEN TRUE ELSE FALSE END AS IS_WEEKEND,
    CASE 
        WHEN TO_CHAR(date_actual, 'MM-DD') = '01-01' THEN TRUE
        WHEN TO_CHAR(date_actual, 'MM-DD') = '07-04' THEN TRUE
        WHEN TO_CHAR(date_actual, 'MM-DD') = '12-25' THEN TRUE
        WHEN TO_CHAR(date_actual, 'MM-DD') = '11-24' THEN TRUE -- Thanksgiving (simplified)
        ELSE FALSE 
    END AS IS_HOLIDAY,
    CASE 
        WHEN TO_CHAR(date_actual, 'MM-DD') = '01-01' THEN 'New Year''s Day'
        WHEN TO_CHAR(date_actual, 'MM-DD') = '07-04' THEN 'Independence Day'
        WHEN TO_CHAR(date_actual, 'MM-DD') = '12-25' THEN 'Christmas Day'
        WHEN TO_CHAR(date_actual, 'MM-DD') = '11-24' THEN 'Thanksgiving'
        ELSE NULL 
    END AS HOLIDAY_NAME,
    YEAR(date_actual) AS FISCAL_YEAR,
    QUARTER(date_actual) AS FISCAL_QUARTER,
    MONTH(date_actual) AS FISCAL_PERIOD
FROM date_range;

-- Populate DIM_TIME (24 hours at 15-minute intervals)
INSERT INTO DIM_TIME (
    TIME_KEY, TIME_ACTUAL, HOUR_24, HOUR_12, MINUTE, SECOND, AM_PM, TIME_PERIOD
)
WITH time_range AS (
    SELECT 
        SEQ4() AS sequence_num
    FROM TABLE(GENERATOR(ROWCOUNT => 96)) -- 24 hours * 4 (15-min intervals)
)
SELECT
    sequence_num AS TIME_KEY,
    TIME_FROM_PARTS(
        FLOOR(sequence_num / 4)::INTEGER,
        (sequence_num % 4) * 15,
        0
    ) AS TIME_ACTUAL,
    FLOOR(sequence_num / 4)::INTEGER AS HOUR_24,
    CASE 
        WHEN FLOOR(sequence_num / 4) = 0 THEN 12
        WHEN FLOOR(sequence_num / 4) <= 12 THEN FLOOR(sequence_num / 4)
        ELSE FLOOR(sequence_num / 4) - 12 
    END::INTEGER AS HOUR_12,
    (sequence_num % 4) * 15 AS MINUTE,
    0 AS SECOND,
    CASE WHEN FLOOR(sequence_num / 4) < 12 THEN 'AM' ELSE 'PM' END AS AM_PM,
    CASE 
        WHEN FLOOR(sequence_num / 4) BETWEEN 5 AND 11 THEN 'Morning'
        WHEN FLOOR(sequence_num / 4) BETWEEN 12 AND 16 THEN 'Afternoon'
        WHEN FLOOR(sequence_num / 4) BETWEEN 17 AND 20 THEN 'Evening'
        ELSE 'Night'
    END AS TIME_PERIOD
FROM time_range;

-- Populate DIM_CUSTOMER (1000 sample customers)
INSERT INTO DIM_CUSTOMER (
    CUSTOMER_ID, FIRST_NAME, LAST_NAME, EMAIL, PHONE, DATE_OF_BIRTH, GENDER,
    CUSTOMER_SEGMENT, LOYALTY_TIER, LOYALTY_POINTS, REGISTRATION_DATE, 
    FIRST_PURCHASE_DATE, LIFETIME_VALUE, ADDRESS_LINE1, CITY, STATE_PROVINCE,
    POSTAL_CODE, COUNTRY, EMAIL_OPTED_IN, SMS_OPTED_IN, EFFECTIVE_DATE, IS_CURRENT
)
WITH customer_data AS (
    SELECT 
        SEQ4() AS seq,
        'CUST-' || LPAD(SEQ4()::VARCHAR, 6, '0') AS customer_id
    FROM TABLE(GENERATOR(ROWCOUNT => 1000))
)
SELECT
    customer_id,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('John', 'Jane', 'Michael', 'Emily', 'David', 'Sarah', 'Robert', 'Lisa')[ABS(MOD(HASH(customer_id), 8))]
    ), '') AS FIRST_NAME,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis')[ABS(MOD(HASH(customer_id || 'last'), 8))]
    ), '') AS LAST_NAME,
    LOWER(customer_id) || '@email.com' AS EMAIL,
    '555-' || LPAD((ABS(MOD(HASH(customer_id), 900)) + 100)::VARCHAR, 3, '0') || '-' || LPAD((ABS(MOD(HASH(customer_id || 'phone'), 9000)) + 1000)::VARCHAR, 4, '0') AS PHONE,
    DATEADD(year, -1 * (ABS(MOD(HASH(customer_id), 50)) + 18), CURRENT_DATE()) AS DATE_OF_BIRTH,
    CASE WHEN MOD(seq, 2) = 0 THEN 'Male' ELSE 'Female' END AS GENDER,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('VIP', 'Premium', 'Standard', 'New')[ABS(MOD(HASH(customer_id), 4))]
    ), '') AS CUSTOMER_SEGMENT,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('Platinum', 'Gold', 'Silver', 'Bronze')[ABS(MOD(HASH(customer_id), 4))]
    ), '') AS LOYALTY_TIER,
    ABS(MOD(HASH(customer_id), 10000)) AS LOYALTY_POINTS,
    DATEADD(day, -1 * ABS(MOD(HASH(customer_id), 730)), CURRENT_DATE()) AS REGISTRATION_DATE,
    DATEADD(day, -1 * ABS(MOD(HASH(customer_id), 700)), CURRENT_DATE()) AS FIRST_PURCHASE_DATE,
    ROUND((ABS(MOD(HASH(customer_id), 10000)) + 100)::DECIMAL(15,2), 2) AS LIFETIME_VALUE,
    (ABS(MOD(HASH(customer_id), 9999)) + 1)::VARCHAR || ' Main Street' AS ADDRESS_LINE1,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 'Philadelphia', 'San Antonio', 'San Diego', 'Dallas', 'San Jose')[ABS(MOD(HASH(customer_id), 10))]
    ), '') AS CITY,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('NY', 'CA', 'IL', 'TX', 'AZ', 'PA', 'TX', 'CA', 'TX', 'CA')[ABS(MOD(HASH(customer_id), 10))]
    ), '') AS STATE_PROVINCE,
    LPAD((ABS(MOD(HASH(customer_id), 90000)) + 10000)::VARCHAR, 5, '0') AS POSTAL_CODE,
    'USA' AS COUNTRY,
    CASE WHEN MOD(seq, 3) != 0 THEN TRUE ELSE FALSE END AS EMAIL_OPTED_IN,
    CASE WHEN MOD(seq, 4) != 0 THEN TRUE ELSE FALSE END AS SMS_OPTED_IN,
    '2022-01-01'::DATE AS EFFECTIVE_DATE,
    TRUE AS IS_CURRENT
FROM customer_data;

-- Populate DIM_PRODUCT (500 sample products)
INSERT INTO DIM_PRODUCT (
    PRODUCT_ID, PRODUCT_NAME, PRODUCT_DESCRIPTION, SKU, BARCODE,
    CATEGORY_LEVEL1, CATEGORY_LEVEL2, CATEGORY_LEVEL3, BRAND, MANUFACTURER,
    SIZE, COLOR, UNIT_COST, LIST_PRICE, MSRP, PRODUCT_STATUS,
    EFFECTIVE_DATE, IS_CURRENT
)
WITH product_data AS (
    SELECT 
        SEQ4() AS seq,
        'PROD-' || LPAD(SEQ4()::VARCHAR, 6, '0') AS product_id
    FROM TABLE(GENERATOR(ROWCOUNT => 500))
)
SELECT
    product_id,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('Premium', 'Classic', 'Deluxe', 'Essential', 'Pro', 'Elite', 'Standard', 'Ultimate')[ABS(MOD(HASH(product_id), 8))]
    ), '') || ' ' ||
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('Widget', 'Gadget', 'Item', 'Product', 'Device', 'Tool', 'Accessory')[ABS(MOD(HASH(product_id || 'name'), 7))]
    ), '') AS PRODUCT_NAME,
    'High-quality product with excellent features and durability' AS PRODUCT_DESCRIPTION,
    'SKU-' || LPAD(seq::VARCHAR, 8, '0') AS SKU,
    'BAR' || LPAD(seq::VARCHAR, 12, '0') AS BARCODE,
    -- Category Hierarchy
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('Electronics', 'Clothing', 'Home & Garden', 'Sports', 'Books')[ABS(MOD(seq, 5))]
    ), '') AS CATEGORY_LEVEL1,
    CASE 
        WHEN MOD(seq, 5) = 0 THEN ARRAY_TO_STRING(ARRAY_CONSTRUCT(ARRAY_AGG('Computers', 'Mobile', 'Audio')[ABS(MOD(seq, 3))]), '')
        WHEN MOD(seq, 5) = 1 THEN ARRAY_TO_STRING(ARRAY_CONSTRUCT(ARRAY_AGG('Men', 'Women', 'Kids')[ABS(MOD(seq, 3))]), '')
        WHEN MOD(seq, 5) = 2 THEN ARRAY_TO_STRING(ARRAY_CONSTRUCT(ARRAY_AGG('Furniture', 'Kitchen', 'Decor')[ABS(MOD(seq, 3))]), '')
        WHEN MOD(seq, 5) = 3 THEN ARRAY_TO_STRING(ARRAY_CONSTRUCT(ARRAY_AGG('Outdoor', 'Fitness', 'Team Sports')[ABS(MOD(seq, 3))]), '')
        ELSE ARRAY_TO_STRING(ARRAY_CONSTRUCT(ARRAY_AGG('Fiction', 'Non-Fiction', 'Educational')[ABS(MOD(seq, 3))]), '')
    END AS CATEGORY_LEVEL2,
    'Subcategory ' || (MOD(seq, 5) + 1)::VARCHAR AS CATEGORY_LEVEL3,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('BrandA', 'BrandB', 'BrandC', 'BrandD', 'BrandE')[ABS(MOD(HASH(product_id), 5))]
    ), '') AS BRAND,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('Manufacturer1', 'Manufacturer2', 'Manufacturer3')[ABS(MOD(seq, 3))]
    ), '') AS MANUFACTURER,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('Small', 'Medium', 'Large', 'XL')[ABS(MOD(seq, 4))]
    ), '') AS SIZE,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('Red', 'Blue', 'Green', 'Black', 'White', 'Gray')[ABS(MOD(seq, 6))]
    ), '') AS COLOR,
    ROUND((ABS(MOD(HASH(product_id), 500)) + 10)::DECIMAL(15,2), 2) AS UNIT_COST,
    ROUND((ABS(MOD(HASH(product_id), 1000)) + 20)::DECIMAL(15,2), 2) AS LIST_PRICE,
    ROUND((ABS(MOD(HASH(product_id), 1200)) + 25)::DECIMAL(15,2), 2) AS MSRP,
    CASE WHEN MOD(seq, 20) = 0 THEN 'Discontinued' ELSE 'Active' END AS PRODUCT_STATUS,
    '2022-01-01'::DATE AS EFFECTIVE_DATE,
    TRUE AS IS_CURRENT
FROM product_data;

-- Populate DIM_STORE (50 sample stores)
INSERT INTO DIM_STORE (
    STORE_ID, STORE_NAME, STORE_NUMBER, STORE_TYPE, STORE_FORMAT, STORE_SIZE_SQFT,
    ADDRESS_LINE1, CITY, STATE_PROVINCE, POSTAL_CODE, COUNTRY,
    REGION, DISTRICT, OPENING_DATE, IS_ACTIVE, EFFECTIVE_DATE, IS_CURRENT
)
WITH store_data AS (
    SELECT 
        SEQ4() AS seq,
        'STORE-' || LPAD(SEQ4()::VARCHAR, 4, '0') AS store_id
    FROM TABLE(GENERATOR(ROWCOUNT => 50))
)
SELECT
    store_id,
    'Retail Store #' || seq::VARCHAR AS STORE_NAME,
    LPAD(seq::VARCHAR, 4, '0') AS STORE_NUMBER,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('Flagship', 'Standard', 'Outlet')[ABS(MOD(seq, 3))]
    ), '') AS STORE_TYPE,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('Mall', 'Standalone', 'Strip Center')[ABS(MOD(seq, 3))]
    ), '') AS STORE_FORMAT,
    (ABS(MOD(HASH(store_id), 50000)) + 5000)::INTEGER AS STORE_SIZE_SQFT,
    (seq * 100)::VARCHAR || ' Commerce Boulevard' AS ADDRESS_LINE1,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix', 'Philadelphia', 'San Antonio', 'San Diego', 'Dallas', 'San Jose')[ABS(MOD(seq, 10))]
    ), '') AS CITY,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('NY', 'CA', 'IL', 'TX', 'AZ', 'PA', 'TX', 'CA', 'TX', 'CA')[ABS(MOD(seq, 10))]
    ), '') AS STATE_PROVINCE,
    LPAD((ABS(MOD(HASH(store_id), 90000)) + 10000)::VARCHAR, 5, '0') AS POSTAL_CODE,
    'USA' AS COUNTRY,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('Northeast', 'Southeast', 'Midwest', 'Southwest', 'West')[ABS(MOD(seq, 5))]
    ), '') AS REGION,
    'District ' || (MOD(seq, 10) + 1)::VARCHAR AS DISTRICT,
    DATEADD(day, -1 * (seq * 30), '2022-01-01'::DATE) AS OPENING_DATE,
    TRUE AS IS_ACTIVE,
    '2022-01-01'::DATE AS EFFECTIVE_DATE,
    TRUE AS IS_CURRENT
FROM store_data;

-- Populate DIM_PROMOTION (20 sample promotions)
INSERT INTO DIM_PROMOTION (
    PROMOTION_ID, PROMOTION_NAME, PROMOTION_DESCRIPTION, PROMOTION_TYPE,
    PROMOTION_CATEGORY, DISCOUNT_PERCENT, START_DATE, END_DATE, IS_ACTIVE
)
VALUES
    ('PROMO-001', 'Spring Sale', '20% off spring collection', 'Percentage Off', 'Seasonal', 20.00, '2024-03-01', '2024-03-31', TRUE),
    ('PROMO-002', 'Summer Clearance', 'Up to 50% off summer items', 'Percentage Off', 'Clearance', 50.00, '2024-06-01', '2024-08-31', TRUE),
    ('PROMO-003', 'Back to School', '15% off school supplies', 'Percentage Off', 'Seasonal', 15.00, '2024-08-01', '2024-09-15', TRUE),
    ('PROMO-004', 'Black Friday', 'Massive Black Friday discounts', 'Percentage Off', 'Seasonal', 40.00, '2024-11-24', '2024-11-24', TRUE),
    ('PROMO-005', 'Cyber Monday', 'Online-only Cyber Monday deals', 'Percentage Off', 'Seasonal', 35.00, '2024-11-27', '2024-11-27', TRUE),
    ('PROMO-006', 'Holiday Sale', 'Holiday shopping discounts', 'Percentage Off', 'Seasonal', 25.00, '2024-12-01', '2024-12-24', TRUE),
    ('PROMO-007', 'New Year Kickoff', 'Start the year with savings', 'Percentage Off', 'Seasonal', 30.00, '2025-01-01', '2025-01-15', TRUE),
    ('PROMO-008', 'Loyalty Bonus', 'Extra 10% for loyalty members', 'Percentage Off', 'Loyalty', 10.00, '2024-01-01', '2024-12-31', TRUE),
    ('PROMO-009', 'BOGO Electronics', 'Buy one get one on select electronics', 'BOGO', 'New Product', NULL, '2024-05-01', '2024-05-31', TRUE),
    ('PROMO-010', 'Weekend Special', 'Weekend-only discounts', 'Percentage Off', 'Seasonal', 15.00, '2024-01-01', '2024-12-31', TRUE),
    ('PROMO-011', 'Flash Sale', 'Limited time flash sale', 'Percentage Off', 'Clearance', 45.00, '2024-07-15', '2024-07-16', FALSE),
    ('PROMO-012', 'VIP Early Access', 'VIP member early access sale', 'Percentage Off', 'Loyalty', 20.00, '2024-10-01', '2024-10-31', TRUE),
    ('PROMO-013', 'Bundle Deal', 'Save when you bundle', 'Bundle', 'New Product', 25.00, '2024-04-01', '2024-06-30', TRUE),
    ('PROMO-014', 'Clearance Event', 'Final clearance on select items', 'Percentage Off', 'Clearance', 60.00, '2024-09-01', '2024-09-30', TRUE),
    ('PROMO-015', 'New Customer Welcome', 'Welcome discount for new customers', 'Percentage Off', 'New Product', 20.00, '2024-01-01', '2024-12-31', TRUE),
    ('PROMO-016', 'Email Exclusive', 'Exclusive offer for email subscribers', 'Percentage Off', 'Loyalty', 15.00, '2024-01-01', '2024-12-31', TRUE),
    ('PROMO-017', 'Birthday Special', 'Birthday month discount', 'Percentage Off', 'Loyalty', 20.00, '2024-01-01', '2024-12-31', TRUE),
    ('PROMO-018', 'Friends & Family', 'Friends and family sale event', 'Percentage Off', 'Seasonal', 30.00, '2024-10-15', '2024-10-22', TRUE),
    ('PROMO-019', 'Price Match Guarantee', 'We match competitor prices', 'Dollar Off', 'New Product', NULL, '2024-01-01', '2024-12-31', TRUE),
    ('PROMO-020', 'Free Shipping', 'Free shipping on orders over $50', 'Dollar Off', 'Seasonal', NULL, '2024-01-01', '2024-12-31', TRUE);

-- Populate DIM_PAYMENT_METHOD
INSERT INTO DIM_PAYMENT_METHOD (
    PAYMENT_METHOD_ID, PAYMENT_METHOD_NAME, PAYMENT_TYPE, PAYMENT_PROCESSOR, IS_ACTIVE
)
VALUES
    ('PAY-001', 'Visa Credit Card', 'Credit Card', 'Visa', TRUE),
    ('PAY-002', 'Mastercard Credit Card', 'Credit Card', 'Mastercard', TRUE),
    ('PAY-003', 'American Express', 'Credit Card', 'Amex', TRUE),
    ('PAY-004', 'Discover Card', 'Credit Card', 'Discover', TRUE),
    ('PAY-005', 'Debit Card', 'Debit Card', 'Various', TRUE),
    ('PAY-006', 'Cash', 'Cash', 'N/A', TRUE),
    ('PAY-007', 'Gift Card', 'Gift Card', 'Internal', TRUE),
    ('PAY-008', 'Apple Pay', 'Digital Wallet', 'Apple', TRUE),
    ('PAY-009', 'Google Pay', 'Digital Wallet', 'Google', TRUE),
    ('PAY-010', 'PayPal', 'Digital Wallet', 'PayPal', TRUE);

-- Populate DIM_EMPLOYEE (200 sample employees)
INSERT INTO DIM_EMPLOYEE (
    EMPLOYEE_ID, FIRST_NAME, LAST_NAME, EMAIL, PHONE, HIRE_DATE,
    EMPLOYMENT_STATUS, JOB_TITLE, DEPARTMENT, EFFECTIVE_DATE, IS_CURRENT
)
WITH employee_data AS (
    SELECT 
        SEQ4() AS seq,
        'EMP-' || LPAD(SEQ4()::VARCHAR, 5, '0') AS employee_id
    FROM TABLE(GENERATOR(ROWCOUNT => 200))
)
SELECT
    employee_id,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('Alex', 'Brian', 'Chris', 'Diana', 'Eric', 'Fiona', 'George', 'Hannah')[ABS(MOD(seq, 8))]
    ), '') AS FIRST_NAME,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('Anderson', 'Baker', 'Clark', 'Davis', 'Evans', 'Foster', 'Gray', 'Harris')[ABS(MOD(seq + 1, 8))]
    ), '') AS LAST_NAME,
    LOWER(employee_id) || '@retailcompany.com' AS EMAIL,
    '555-' || LPAD((ABS(MOD(seq, 900)) + 100)::VARCHAR, 3, '0') || '-' || LPAD((ABS(MOD(seq * 7, 9000)) + 1000)::VARCHAR, 4, '0') AS PHONE,
    DATEADD(day, -1 * (seq * 5), '2024-01-01'::DATE) AS HIRE_DATE,
    'Active' AS EMPLOYMENT_STATUS,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('Sales Associate', 'Store Manager', 'Assistant Manager', 'Cashier', 'Stock Clerk')[ABS(MOD(seq, 5))]
    ), '') AS JOB_TITLE,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('Sales', 'Operations', 'Customer Service')[ABS(MOD(seq, 3))]
    ), '') AS DEPARTMENT,
    '2022-01-01'::DATE AS EFFECTIVE_DATE,
    TRUE AS IS_CURRENT
FROM employee_data;

-- Populate DIM_SUPPLIER (30 sample suppliers)
INSERT INTO DIM_SUPPLIER (
    SUPPLIER_ID, SUPPLIER_NAME, SUPPLIER_TYPE, CONTACT_NAME, EMAIL, PHONE,
    CITY, STATE_PROVINCE, COUNTRY, PAYMENT_TERMS, LEAD_TIME_DAYS,
    IS_PREFERRED_SUPPLIER, SUPPLIER_RATING, IS_ACTIVE, EFFECTIVE_DATE, IS_CURRENT
)
WITH supplier_data AS (
    SELECT 
        SEQ4() AS seq,
        'SUP-' || LPAD(SEQ4()::VARCHAR, 4, '0') AS supplier_id
    FROM TABLE(GENERATOR(ROWCOUNT => 30))
)
SELECT
    supplier_id,
    'Supplier Company ' || seq::VARCHAR AS SUPPLIER_NAME,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('Manufacturer', 'Distributor', 'Wholesaler')[ABS(MOD(seq, 3))]
    ), '') AS SUPPLIER_TYPE,
    'Contact ' || seq::VARCHAR AS CONTACT_NAME,
    LOWER(supplier_id) || '@supplier.com' AS EMAIL,
    '555-SUP-' || LPAD(seq::VARCHAR, 4, '0') AS PHONE,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('Chicago', 'Atlanta', 'Seattle', 'Denver', 'Boston')[ABS(MOD(seq, 5))]
    ), '') AS CITY,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('IL', 'GA', 'WA', 'CO', 'MA')[ABS(MOD(seq, 5))]
    ), '') AS STATE_PROVINCE,
    'USA' AS COUNTRY,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('Net 30', 'Net 60', 'Net 90')[ABS(MOD(seq, 3))]
    ), '') AS PAYMENT_TERMS,
    (MOD(seq, 20) + 5)::INTEGER AS LEAD_TIME_DAYS,
    CASE WHEN MOD(seq, 5) = 0 THEN TRUE ELSE FALSE END AS IS_PREFERRED_SUPPLIER,
    ROUND((3.0 + (MOD(seq, 20) / 10.0))::DECIMAL(3,2), 2) AS SUPPLIER_RATING,
    TRUE AS IS_ACTIVE,
    '2022-01-01'::DATE AS EFFECTIVE_DATE,
    TRUE AS IS_CURRENT
FROM supplier_data;

-- =====================================================
-- POPULATE FACT TABLES WITH SAMPLE DATA
-- =====================================================

-- Populate FACT_SALES (100,000 sample transactions)
INSERT INTO FACT_SALES (
    DATE_KEY, TIME_KEY, CUSTOMER_KEY, PRODUCT_KEY, STORE_KEY, PROMOTION_KEY,
    PAYMENT_METHOD_KEY, EMPLOYEE_KEY, TRANSACTION_ID, TRANSACTION_LINE_NUMBER,
    TRANSACTION_TIMESTAMP, QUANTITY_SOLD, UNIT_PRICE, UNIT_COST, EXTENDED_PRICE,
    DISCOUNT_AMOUNT, TAX_AMOUNT, NET_SALES_AMOUNT, GROSS_PROFIT_AMOUNT,
    GROSS_MARGIN_PERCENT, TRANSACTION_TYPE, CHANNEL
)
WITH sales_data AS (
    SELECT 
        SEQ4() AS seq
    FROM TABLE(GENERATOR(ROWCOUNT => 100000))
),
random_dates AS (
    SELECT 
        seq,
        DATEADD(day, -1 * ABS(MOD(HASH(seq), 730)), CURRENT_DATE()) AS trans_date,
        ABS(MOD(HASH(seq || 'time'), 96)) AS time_seq,
        ABS(MOD(HASH(seq || 'cust'), 1000)) + 1 AS cust_key,
        ABS(MOD(HASH(seq || 'prod'), 500)) + 1 AS prod_key,
        ABS(MOD(HASH(seq || 'store'), 50)) + 1 AS store_key,
        CASE WHEN MOD(seq, 5) = 0 THEN ABS(MOD(HASH(seq || 'promo'), 20)) + 1 ELSE NULL END AS promo_key,
        ABS(MOD(HASH(seq || 'pay'), 10)) + 1 AS pay_key,
        ABS(MOD(HASH(seq || 'emp'), 200)) + 1 AS emp_key,
        ABS(MOD(HASH(seq || 'qty'), 10)) + 1 AS quantity
    FROM sales_data
)
SELECT
    TO_NUMBER(TO_CHAR(rd.trans_date, 'YYYYMMDD')) AS DATE_KEY,
    rd.time_seq AS TIME_KEY,
    rd.cust_key AS CUSTOMER_KEY,
    rd.prod_key AS PRODUCT_KEY,
    rd.store_key AS STORE_KEY,
    rd.promo_key AS PROMOTION_KEY,
    rd.pay_key AS PAYMENT_METHOD_KEY,
    rd.emp_key AS EMPLOYEE_KEY,
    'TXN-' || LPAD(rd.seq::VARCHAR, 10, '0') AS TRANSACTION_ID,
    1 AS TRANSACTION_LINE_NUMBER,
    TIMESTAMP_NTZ_FROM_PARTS(
        DATE_PART(year, rd.trans_date)::INTEGER,
        DATE_PART(month, rd.trans_date)::INTEGER,
        DATE_PART(day, rd.trans_date)::INTEGER,
        FLOOR(rd.time_seq / 4)::INTEGER,
        (rd.time_seq % 4) * 15,
        0
    ) AS TRANSACTION_TIMESTAMP,
    rd.quantity AS QUANTITY_SOLD,
    p.LIST_PRICE AS UNIT_PRICE,
    p.UNIT_COST,
    ROUND(p.LIST_PRICE * rd.quantity, 2) AS EXTENDED_PRICE,
    CASE 
        WHEN rd.promo_key IS NOT NULL THEN ROUND(p.LIST_PRICE * rd.quantity * 0.15, 2)
        ELSE 0 
    END AS DISCOUNT_AMOUNT,
    ROUND(p.LIST_PRICE * rd.quantity * 0.08, 2) AS TAX_AMOUNT,
    ROUND(
        (p.LIST_PRICE * rd.quantity) - 
        CASE WHEN rd.promo_key IS NOT NULL THEN (p.LIST_PRICE * rd.quantity * 0.15) ELSE 0 END +
        (p.LIST_PRICE * rd.quantity * 0.08),
        2
    ) AS NET_SALES_AMOUNT,
    ROUND(
        (p.LIST_PRICE * rd.quantity) - 
        CASE WHEN rd.promo_key IS NOT NULL THEN (p.LIST_PRICE * rd.quantity * 0.15) ELSE 0 END -
        (p.UNIT_COST * rd.quantity),
        2
    ) AS GROSS_PROFIT_AMOUNT,
    CASE 
        WHEN (p.LIST_PRICE * rd.quantity) - CASE WHEN rd.promo_key IS NOT NULL THEN (p.LIST_PRICE * rd.quantity * 0.15) ELSE 0 END > 0
        THEN ROUND(
            ((p.LIST_PRICE * rd.quantity) - CASE WHEN rd.promo_key IS NOT NULL THEN (p.LIST_PRICE * rd.quantity * 0.15) ELSE 0 END - (p.UNIT_COST * rd.quantity)) /
            ((p.LIST_PRICE * rd.quantity) - CASE WHEN rd.promo_key IS NOT NULL THEN (p.LIST_PRICE * rd.quantity * 0.15) ELSE 0 END) * 100,
            2
        )
        ELSE 0
    END AS GROSS_MARGIN_PERCENT,
    CASE WHEN MOD(rd.seq, 50) = 0 THEN 'Return' ELSE 'Sale' END AS TRANSACTION_TYPE,
    ARRAY_TO_STRING(ARRAY_CONSTRUCT(
        ARRAY_AGG('In-Store', 'Online', 'Mobile')[ABS(MOD(rd.seq, 3))]
    ), '') AS CHANNEL
FROM random_dates rd
JOIN DIM_PRODUCT p ON rd.prod_key = p.PRODUCT_KEY
WHERE p.IS_CURRENT = TRUE;

-- Populate FACT_INVENTORY (Daily snapshots for last 30 days)
INSERT INTO FACT_INVENTORY (
    DATE_KEY, PRODUCT_KEY, STORE_KEY, SUPPLIER_KEY, SNAPSHOT_DATE,
    BEGINNING_ON_HAND_QUANTITY, RECEIPTS_QUANTITY, SALES_QUANTITY,
    RETURNS_QUANTITY, ADJUSTMENTS_QUANTITY, ENDING_ON_HAND_QUANTITY,
    REORDER_POINT, SAFETY_STOCK_QUANTITY, UNIT_COST, INVENTORY_VALUE,
    DAYS_OF_SUPPLY, STOCK_STATUS
)
WITH inventory_dates AS (
    SELECT 
        DATEADD(day, SEQ4(), DATEADD(day, -30, CURRENT_DATE()))::DATE AS snapshot_date
    FROM TABLE(GENERATOR(ROWCOUNT => 30))
),
inventory_combinations AS (
    SELECT 
        id.snapshot_date,
        p.PRODUCT_KEY,
        s.STORE_KEY,
        ABS(MOD(HASH(p.PRODUCT_KEY || s.STORE_KEY), 30)) + 1 AS supplier_key
    FROM inventory_dates id
    CROSS JOIN (SELECT PRODUCT_KEY FROM DIM_PRODUCT WHERE IS_CURRENT = TRUE LIMIT 100) p
    CROSS JOIN (SELECT STORE_KEY FROM DIM_STORE WHERE IS_CURRENT = TRUE LIMIT 10) s
)
SELECT
    TO_NUMBER(TO_CHAR(ic.snapshot_date, 'YYYYMMDD')) AS DATE_KEY,
    ic.PRODUCT_KEY,
    ic.STORE_KEY,
    ic.supplier_key AS SUPPLIER_KEY,
    ic.snapshot_date,
    ABS(MOD(HASH(ic.PRODUCT_KEY || ic.STORE_KEY || ic.snapshot_date), 1000)) + 100 AS BEGINNING_ON_HAND_QUANTITY,
    ABS(MOD(HASH(ic.PRODUCT_KEY || ic.STORE_KEY || ic.snapshot_date || 'receipts'), 50)) AS RECEIPTS_QUANTITY,
    ABS(MOD(HASH(ic.PRODUCT_KEY || ic.STORE_KEY || ic.snapshot_date || 'sales'), 30)) AS SALES_QUANTITY,
    ABS(MOD(HASH(ic.PRODUCT_KEY || ic.STORE_KEY || ic.snapshot_date || 'returns'), 5)) AS RETURNS_QUANTITY,
    ABS(MOD(HASH(ic.PRODUCT_KEY || ic.STORE_KEY || ic.snapshot_date || 'adj'), 3)) - 1 AS ADJUSTMENTS_QUANTITY,
    ABS(MOD(HASH(ic.PRODUCT_KEY || ic.STORE_KEY || ic.snapshot_date), 1000)) + 100 +
    ABS(MOD(HASH(ic.PRODUCT_KEY || ic.STORE_KEY || ic.snapshot_date || 'receipts'), 50)) -
    ABS(MOD(HASH(ic.PRODUCT_KEY || ic.STORE_KEY || ic.snapshot_date || 'sales'), 30)) +
    ABS(MOD(HASH(ic.PRODUCT_KEY || ic.STORE_KEY || ic.snapshot_date || 'returns'), 5)) +
    ABS(MOD(HASH(ic.PRODUCT_KEY || ic.STORE_KEY || ic.snapshot_date || 'adj'), 3)) - 1 AS ENDING_ON_HAND_QUANTITY,
    50 AS REORDER_POINT,
    25 AS SAFETY_STOCK_QUANTITY,
    p.UNIT_COST,
    ROUND(p.UNIT_COST * (
        ABS(MOD(HASH(ic.PRODUCT_KEY || ic.STORE_KEY || ic.snapshot_date), 1000)) + 100 +
        ABS(MOD(HASH(ic.PRODUCT_KEY || ic.STORE_KEY || ic.snapshot_date || 'receipts'), 50)) -
        ABS(MOD(HASH(ic.PRODUCT_KEY || ic.STORE_KEY || ic.snapshot_date || 'sales'), 30)) +
        ABS(MOD(HASH(ic.PRODUCT_KEY || ic.STORE_KEY || ic.snapshot_date || 'returns'), 5))
    ), 2) AS INVENTORY_VALUE,
    ABS(MOD(HASH(ic.PRODUCT_KEY || ic.STORE_KEY), 30)) + 5 AS DAYS_OF_SUPPLY,
    CASE 
        WHEN ABS(MOD(HASH(ic.PRODUCT_KEY || ic.STORE_KEY || ic.snapshot_date), 1000)) > 500 THEN 'In Stock'
        WHEN ABS(MOD(HASH(ic.PRODUCT_KEY || ic.STORE_KEY || ic.snapshot_date), 1000)) > 100 THEN 'Low Stock'
        ELSE 'Out of Stock'
    END AS STOCK_STATUS
FROM inventory_combinations ic
JOIN DIM_PRODUCT p ON ic.PRODUCT_KEY = p.PRODUCT_KEY;

-- Populate BRIDGE_PRODUCT_SUPPLIER
INSERT INTO BRIDGE_PRODUCT_SUPPLIER (
    PRODUCT_KEY, SUPPLIER_KEY, IS_PRIMARY_SUPPLIER, UNIT_COST,
    LEAD_TIME_DAYS, MINIMUM_ORDER_QUANTITY, EFFECTIVE_DATE, IS_ACTIVE
)
WITH product_supplier_combo AS (
    SELECT 
        p.PRODUCT_KEY,
        s.SUPPLIER_KEY,
        ROW_NUMBER() OVER (PARTITION BY p.PRODUCT_KEY ORDER BY s.SUPPLIER_KEY) AS rn
    FROM (SELECT PRODUCT_KEY FROM DIM_PRODUCT WHERE IS_CURRENT = TRUE LIMIT 100) p
    CROSS JOIN (SELECT SUPPLIER_KEY FROM DIM_SUPPLIER WHERE IS_CURRENT = TRUE) s
    WHERE ABS(MOD(HASH(p.PRODUCT_KEY || s.SUPPLIER_KEY), 10)) < 3  -- Each product has 2-3 suppliers
)
SELECT
    PRODUCT_KEY,
    SUPPLIER_KEY,
    CASE WHEN rn = 1 THEN TRUE ELSE FALSE END AS IS_PRIMARY_SUPPLIER,
    ROUND((ABS(MOD(HASH(PRODUCT_KEY || SUPPLIER_KEY), 500)) + 10)::DECIMAL(15,2), 2) AS UNIT_COST,
    ABS(MOD(HASH(PRODUCT_KEY || SUPPLIER_KEY), 20)) + 5 AS LEAD_TIME_DAYS,
    ABS(MOD(HASH(PRODUCT_KEY || SUPPLIER_KEY), 50)) + 10 AS MINIMUM_ORDER_QUANTITY,
    '2022-01-01'::DATE AS EFFECTIVE_DATE,
    TRUE AS IS_ACTIVE
FROM product_supplier_combo;

-- =====================================================
-- DATA QUALITY CHECKS
-- =====================================================

-- Check row counts
SELECT 'DIM_DATE' AS table_name, COUNT(*) AS row_count FROM DIM_DATE
UNION ALL
SELECT 'DIM_TIME', COUNT(*) FROM DIM_TIME
UNION ALL
SELECT 'DIM_CUSTOMER', COUNT(*) FROM DIM_CUSTOMER
UNION ALL
SELECT 'DIM_PRODUCT', COUNT(*) FROM DIM_PRODUCT
UNION ALL
SELECT 'DIM_STORE', COUNT(*) FROM DIM_STORE
UNION ALL
SELECT 'DIM_PROMOTION', COUNT(*) FROM DIM_PROMOTION
UNION ALL
SELECT 'DIM_PAYMENT_METHOD', COUNT(*) FROM DIM_PAYMENT_METHOD
UNION ALL
SELECT 'DIM_EMPLOYEE', COUNT(*) FROM DIM_EMPLOYEE
UNION ALL
SELECT 'DIM_SUPPLIER', COUNT(*) FROM DIM_SUPPLIER
UNION ALL
SELECT 'FACT_SALES', COUNT(*) FROM FACT_SALES
UNION ALL
SELECT 'FACT_INVENTORY', COUNT(*) FROM FACT_INVENTORY
UNION ALL
SELECT 'BRIDGE_PRODUCT_SUPPLIER', COUNT(*) FROM BRIDGE_PRODUCT_SUPPLIER
ORDER BY table_name;

-- =====================================================
-- END OF SAMPLE DATA GENERATION
-- =====================================================



