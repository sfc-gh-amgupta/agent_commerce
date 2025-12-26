-- ============================================================================
-- AGENT COMMERCE - Load Sample Data
-- ============================================================================
-- This script loads generated sample data into Snowflake tables.
-- Run after all table creation scripts (01-05).
--
-- TWO OPTIONS FOR DATA UPLOAD:
--   1. LOCAL UPLOAD: Use SnowSQL or Snowflake UI to PUT files from local machine
--   2. S3 UPLOAD: Load from S3 bucket (requires external stage)
--
-- ============================================================================

USE ROLE AGENT_COMMERCE_ROLE;
USE DATABASE AGENT_COMMERCE;
USE WAREHOUSE AGENT_COMMERCE_WH;

-- ============================================================================
-- OPTION 1: LOCAL UPLOAD (Using Internal Stages)
-- ============================================================================
-- Run these commands from SnowSQL or Snowflake UI:
--
-- 1. Upload CSV files to internal stages:
--
-- PUT file:///path/to/beauty_analyzer/data/generated/csv/products.csv @PRODUCTS.PRODUCT_MEDIA/csv/;
-- PUT file:///path/to/beauty_analyzer/data/generated/csv/product_variants.csv @PRODUCTS.PRODUCT_MEDIA/csv/;
-- PUT file:///path/to/beauty_analyzer/data/generated/csv/product_media.csv @PRODUCTS.PRODUCT_MEDIA/csv/;
-- PUT file:///path/to/beauty_analyzer/data/generated/csv/product_labels.csv @PRODUCTS.PRODUCT_MEDIA/csv/;
-- PUT file:///path/to/beauty_analyzer/data/generated/csv/product_ingredients.csv @PRODUCTS.PRODUCT_MEDIA/csv/;
-- PUT file:///path/to/beauty_analyzer/data/generated/csv/product_warnings.csv @PRODUCTS.PRODUCT_MEDIA/csv/;
-- PUT file:///path/to/beauty_analyzer/data/generated/csv/price_history.csv @PRODUCTS.PRODUCT_MEDIA/csv/;
-- PUT file:///path/to/beauty_analyzer/data/generated/csv/promotions.csv @PRODUCTS.PRODUCT_MEDIA/csv/;
-- PUT file:///path/to/beauty_analyzer/data/generated/csv/customers.csv @CUSTOMERS.FACE_IMAGES/csv/;
-- PUT file:///path/to/beauty_analyzer/data/generated/csv/customer_face_embeddings.csv @CUSTOMERS.FACE_IMAGES/csv/;
-- PUT file:///path/to/beauty_analyzer/data/generated/csv/skin_analysis_history.csv @CUSTOMERS.FACE_IMAGES/csv/;
-- etc.
--
-- ============================================================================

-- ============================================================================
-- OPTION 2: S3 UPLOAD (Using External Stage)
-- ============================================================================
-- Uncomment and configure the following to load from S3:
--
-- -- Create storage integration for S3 access
-- CREATE OR REPLACE STORAGE INTEGRATION agent_commerce_s3_int
--     TYPE = EXTERNAL_STAGE
--     STORAGE_PROVIDER = 'S3'
--     ENABLED = TRUE
--     STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<account>:role/<role>'
--     STORAGE_ALLOWED_LOCATIONS = ('s3://<bucket>/agent_commerce/');
--
-- -- Create external stage pointing to S3
-- CREATE OR REPLACE STAGE UTIL.S3_DATA_STAGE
--     STORAGE_INTEGRATION = agent_commerce_s3_int
--     URL = 's3://<bucket>/agent_commerce/data/'
--     FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
--
-- -- Expected S3 directory structure (mirrors local):
-- -- s3://<bucket>/agent_commerce/
-- --   ├── data/
-- --   │   ├── csv/
-- --   │   │   ├── products.csv
-- --   │   │   ├── product_variants.csv
-- --   │   │   ├── customers.csv
-- --   │   │   └── ... (all CSVs)
-- --   │   └── images/
-- --   │       ├── hero/
-- --   │       │   ├── lips/
-- --   │       │   ├── face/
-- --   │       │   └── ...
-- --   │       ├── swatches/
-- --   │       ├── labels/
-- --   │       └── faces/
--
-- ============================================================================

-- ============================================================================
-- CREATE FILE FORMATS
-- ============================================================================

-- CSV file format for data loading
CREATE OR REPLACE FILE FORMAT UTIL.CSV_FORMAT
    TYPE = CSV
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
    NULL_IF = ('', 'NULL', 'null')
    EMPTY_FIELD_AS_NULL = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;

-- ============================================================================
-- CREATE INTERNAL STAGES FOR DATA LOADING
-- ============================================================================

-- Create data loading stage in UTIL schema
CREATE STAGE IF NOT EXISTS UTIL.DATA_STAGE
    DIRECTORY = (ENABLE = TRUE)
    FILE_FORMAT = UTIL.CSV_FORMAT
    COMMENT = 'Stage for CSV data files';

-- ============================================================================
-- LOAD PRODUCTS SCHEMA DATA
-- ============================================================================
USE SCHEMA PRODUCTS;

-- Load products
COPY INTO PRODUCTS
FROM @UTIL.DATA_STAGE/csv/products.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Load product variants
COPY INTO PRODUCT_VARIANTS
FROM @UTIL.DATA_STAGE/csv/product_variants.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Load product media
COPY INTO PRODUCT_MEDIA
FROM @UTIL.DATA_STAGE/csv/product_media.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Load product labels
COPY INTO PRODUCT_LABELS
FROM @UTIL.DATA_STAGE/csv/product_labels.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Load product ingredients
COPY INTO PRODUCT_INGREDIENTS
FROM @UTIL.DATA_STAGE/csv/product_ingredients.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Load product warnings
COPY INTO PRODUCT_WARNINGS
FROM @UTIL.DATA_STAGE/csv/product_warnings.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Load price history
COPY INTO PRICE_HISTORY
FROM @UTIL.DATA_STAGE/csv/price_history.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Load promotions
COPY INTO PROMOTIONS
FROM @UTIL.DATA_STAGE/csv/promotions.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- ============================================================================
-- LOAD CUSTOMERS SCHEMA DATA
-- ============================================================================
USE SCHEMA CUSTOMERS;

-- Load customers
COPY INTO CUSTOMERS
FROM @UTIL.DATA_STAGE/csv/customers.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Note: Face embeddings require special handling for VECTOR type
-- The embedding column needs to be cast from JSON array to VECTOR(FLOAT, 128)
-- Using a staging table approach:

CREATE OR REPLACE TEMPORARY TABLE CUSTOMER_FACE_EMBEDDINGS_STAGING (
    embedding_id VARCHAR(36),
    customer_id VARCHAR(36),
    embedding VARCHAR,  -- JSON array as string
    quality_score FLOAT,
    lighting_condition VARCHAR(20),
    face_angle VARCHAR(20),
    is_active BOOLEAN,
    is_primary BOOLEAN,
    created_at TIMESTAMP_NTZ,
    source VARCHAR(50)
);

COPY INTO CUSTOMER_FACE_EMBEDDINGS_STAGING
FROM @UTIL.DATA_STAGE/csv/customer_face_embeddings.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE';

-- Insert with VECTOR conversion
INSERT INTO CUSTOMER_FACE_EMBEDDINGS (
    embedding_id, customer_id, embedding, quality_score, lighting_condition,
    face_angle, is_active, is_primary, created_at, source
)
SELECT 
    embedding_id,
    customer_id,
    PARSE_JSON(embedding)::VECTOR(FLOAT, 128),
    quality_score,
    lighting_condition,
    face_angle,
    is_active,
    is_primary,
    created_at,
    source
FROM CUSTOMER_FACE_EMBEDDINGS_STAGING;

DROP TABLE CUSTOMER_FACE_EMBEDDINGS_STAGING;

-- Load skin analysis history
COPY INTO SKIN_ANALYSIS_HISTORY
FROM @UTIL.DATA_STAGE/csv/skin_analysis_history.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- ============================================================================
-- LOAD INVENTORY SCHEMA DATA
-- ============================================================================
USE SCHEMA INVENTORY;

-- Load locations
COPY INTO LOCATIONS
FROM @UTIL.DATA_STAGE/csv/locations.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Load stock levels
COPY INTO STOCK_LEVELS
FROM @UTIL.DATA_STAGE/csv/stock_levels.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Load inventory transactions
COPY INTO INVENTORY_TRANSACTIONS
FROM @UTIL.DATA_STAGE/csv/inventory_transactions.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- ============================================================================
-- LOAD SOCIAL SCHEMA DATA
-- ============================================================================
USE SCHEMA SOCIAL;

-- Load product reviews
COPY INTO PRODUCT_REVIEWS
FROM @UTIL.DATA_STAGE/csv/product_reviews.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Load social mentions
COPY INTO SOCIAL_MENTIONS
FROM @UTIL.DATA_STAGE/csv/social_mentions.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Load influencer mentions
COPY INTO INFLUENCER_MENTIONS
FROM @UTIL.DATA_STAGE/csv/influencer_mentions.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- ============================================================================
-- LOAD CART_OLTP SCHEMA DATA (Hybrid Tables)
-- ============================================================================
-- Note: Hybrid tables use INSERT instead of COPY for guaranteed ACID
-- ============================================================================
USE SCHEMA CART_OLTP;

-- For Hybrid Tables, we need to use INSERT statements
-- First, create temporary staging tables, then insert

-- Fulfillment Options (seed data)
CREATE OR REPLACE TEMPORARY TABLE FULFILLMENT_OPTIONS_STAGING LIKE FULFILLMENT_OPTIONS;
ALTER TABLE FULFILLMENT_OPTIONS_STAGING DROP PRIMARY KEY;

COPY INTO FULFILLMENT_OPTIONS_STAGING
FROM @UTIL.DATA_STAGE/csv/fulfillment_options.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE';

INSERT INTO FULFILLMENT_OPTIONS SELECT * FROM FULFILLMENT_OPTIONS_STAGING;
DROP TABLE FULFILLMENT_OPTIONS_STAGING;

-- Cart Sessions
CREATE OR REPLACE TEMPORARY TABLE CART_SESSIONS_STAGING (
    session_id VARCHAR(36),
    customer_id VARCHAR(36),
    status VARCHAR(30),
    subtotal_cents INTEGER,
    tax_cents INTEGER,
    shipping_cents INTEGER,
    discount_cents INTEGER,
    total_cents INTEGER,
    currency VARCHAR(3),
    applied_promo_codes VARCHAR(1000),
    applied_loyalty_points INTEGER,
    fulfillment_type VARCHAR(20),
    shipping_address VARCHAR(2000),
    billing_address VARCHAR(2000),
    shipping_method_id VARCHAR(36),
    is_gift BOOLEAN,
    gift_message VARCHAR(500),
    gift_recipient_email VARCHAR(255),
    is_valid BOOLEAN,
    validation_message VARCHAR(500),
    idempotency_key VARCHAR(100),
    created_at TIMESTAMP_NTZ,
    updated_at TIMESTAMP_NTZ,
    expires_at TIMESTAMP_NTZ,
    completed_at TIMESTAMP_NTZ
);

COPY INTO CART_SESSIONS_STAGING
FROM @UTIL.DATA_STAGE/csv/cart_sessions.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE';

INSERT INTO CART_SESSIONS SELECT * FROM CART_SESSIONS_STAGING;
DROP TABLE CART_SESSIONS_STAGING;

-- Cart Items
CREATE OR REPLACE TEMPORARY TABLE CART_ITEMS_STAGING (
    item_id VARCHAR(36),
    session_id VARCHAR(36),
    product_id VARCHAR(36),
    variant_id VARCHAR(36),
    quantity INTEGER,
    unit_price_cents INTEGER,
    subtotal_cents INTEGER,
    product_name VARCHAR(255),
    variant_name VARCHAR(100),
    product_image_url VARCHAR(1000),
    added_at TIMESTAMP_NTZ,
    updated_at TIMESTAMP_NTZ
);

COPY INTO CART_ITEMS_STAGING
FROM @UTIL.DATA_STAGE/csv/cart_items.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE';

INSERT INTO CART_ITEMS SELECT * FROM CART_ITEMS_STAGING;
DROP TABLE CART_ITEMS_STAGING;

-- Payment Methods
CREATE OR REPLACE TEMPORARY TABLE PAYMENT_METHODS_STAGING (
    payment_method_id VARCHAR(36),
    customer_id VARCHAR(36),
    payment_type VARCHAR(30),
    token VARCHAR(255),
    display_name VARCHAR(100),
    card_brand VARCHAR(20),
    card_last_four VARCHAR(4),
    expires_month INTEGER,
    expires_year INTEGER,
    is_default BOOLEAN,
    is_verified BOOLEAN,
    billing_address VARCHAR(2000),
    created_at TIMESTAMP_NTZ,
    last_used_at TIMESTAMP_NTZ
);

COPY INTO PAYMENT_METHODS_STAGING
FROM @UTIL.DATA_STAGE/csv/payment_methods.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE';

INSERT INTO PAYMENT_METHODS SELECT * FROM PAYMENT_METHODS_STAGING;
DROP TABLE PAYMENT_METHODS_STAGING;

-- Orders
CREATE OR REPLACE TEMPORARY TABLE ORDERS_STAGING (
    order_id VARCHAR(36),
    order_number VARCHAR(20),
    session_id VARCHAR(36),
    customer_id VARCHAR(36),
    status VARCHAR(30),
    subtotal_cents INTEGER,
    tax_cents INTEGER,
    shipping_cents INTEGER,
    discount_cents INTEGER,
    total_cents INTEGER,
    currency VARCHAR(3),
    shipping_address VARCHAR(2000),
    shipping_method VARCHAR(100),
    tracking_number VARCHAR(100),
    tracking_url VARCHAR(500),
    created_at TIMESTAMP_NTZ,
    confirmed_at TIMESTAMP_NTZ,
    shipped_at TIMESTAMP_NTZ,
    delivered_at TIMESTAMP_NTZ,
    cancelled_at TIMESTAMP_NTZ
);

COPY INTO ORDERS_STAGING
FROM @UTIL.DATA_STAGE/csv/orders.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE';

INSERT INTO ORDERS SELECT * FROM ORDERS_STAGING;
DROP TABLE ORDERS_STAGING;

-- Order Items
CREATE OR REPLACE TEMPORARY TABLE ORDER_ITEMS_STAGING (
    order_item_id VARCHAR(36),
    order_id VARCHAR(36),
    product_id VARCHAR(36),
    variant_id VARCHAR(36),
    quantity INTEGER,
    unit_price_cents INTEGER,
    subtotal_cents INTEGER,
    product_name VARCHAR(255),
    variant_name VARCHAR(100),
    product_image_url VARCHAR(1000),
    created_at TIMESTAMP_NTZ
);

COPY INTO ORDER_ITEMS_STAGING
FROM @UTIL.DATA_STAGE/csv/order_items.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE';

INSERT INTO ORDER_ITEMS SELECT * FROM ORDER_ITEMS_STAGING;
DROP TABLE ORDER_ITEMS_STAGING;

-- Payment Transactions
CREATE OR REPLACE TEMPORARY TABLE PAYMENT_TRANSACTIONS_STAGING (
    transaction_id VARCHAR(36),
    session_id VARCHAR(36),
    payment_method_id VARCHAR(36),
    amount_cents INTEGER,
    currency VARCHAR(3),
    status VARCHAR(30),
    psp_name VARCHAR(50),
    psp_transaction_id VARCHAR(255),
    psp_response VARCHAR(4000),
    failure_code VARCHAR(50),
    failure_message VARCHAR(500),
    created_at TIMESTAMP_NTZ,
    updated_at TIMESTAMP_NTZ
);

COPY INTO PAYMENT_TRANSACTIONS_STAGING
FROM @UTIL.DATA_STAGE/csv/payment_transactions.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE';

INSERT INTO PAYMENT_TRANSACTIONS SELECT * FROM PAYMENT_TRANSACTIONS_STAGING;
DROP TABLE PAYMENT_TRANSACTIONS_STAGING;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Count rows in each table
SELECT 'PRODUCTS.PRODUCTS' AS table_name, COUNT(*) AS row_count FROM PRODUCTS.PRODUCTS
UNION ALL SELECT 'PRODUCTS.PRODUCT_VARIANTS', COUNT(*) FROM PRODUCTS.PRODUCT_VARIANTS
UNION ALL SELECT 'PRODUCTS.PRODUCT_MEDIA', COUNT(*) FROM PRODUCTS.PRODUCT_MEDIA
UNION ALL SELECT 'PRODUCTS.PRODUCT_LABELS', COUNT(*) FROM PRODUCTS.PRODUCT_LABELS
UNION ALL SELECT 'PRODUCTS.PRODUCT_INGREDIENTS', COUNT(*) FROM PRODUCTS.PRODUCT_INGREDIENTS
UNION ALL SELECT 'PRODUCTS.PRODUCT_WARNINGS', COUNT(*) FROM PRODUCTS.PRODUCT_WARNINGS
UNION ALL SELECT 'PRODUCTS.PRICE_HISTORY', COUNT(*) FROM PRODUCTS.PRICE_HISTORY
UNION ALL SELECT 'PRODUCTS.PROMOTIONS', COUNT(*) FROM PRODUCTS.PROMOTIONS
UNION ALL SELECT 'CUSTOMERS.CUSTOMERS', COUNT(*) FROM CUSTOMERS.CUSTOMERS
UNION ALL SELECT 'CUSTOMERS.CUSTOMER_FACE_EMBEDDINGS', COUNT(*) FROM CUSTOMERS.CUSTOMER_FACE_EMBEDDINGS
UNION ALL SELECT 'CUSTOMERS.SKIN_ANALYSIS_HISTORY', COUNT(*) FROM CUSTOMERS.SKIN_ANALYSIS_HISTORY
UNION ALL SELECT 'INVENTORY.LOCATIONS', COUNT(*) FROM INVENTORY.LOCATIONS
UNION ALL SELECT 'INVENTORY.STOCK_LEVELS', COUNT(*) FROM INVENTORY.STOCK_LEVELS
UNION ALL SELECT 'INVENTORY.INVENTORY_TRANSACTIONS', COUNT(*) FROM INVENTORY.INVENTORY_TRANSACTIONS
UNION ALL SELECT 'SOCIAL.PRODUCT_REVIEWS', COUNT(*) FROM SOCIAL.PRODUCT_REVIEWS
UNION ALL SELECT 'SOCIAL.SOCIAL_MENTIONS', COUNT(*) FROM SOCIAL.SOCIAL_MENTIONS
UNION ALL SELECT 'SOCIAL.INFLUENCER_MENTIONS', COUNT(*) FROM SOCIAL.INFLUENCER_MENTIONS
UNION ALL SELECT 'CART_OLTP.CART_SESSIONS', COUNT(*) FROM CART_OLTP.CART_SESSIONS
UNION ALL SELECT 'CART_OLTP.CART_ITEMS', COUNT(*) FROM CART_OLTP.CART_ITEMS
UNION ALL SELECT 'CART_OLTP.FULFILLMENT_OPTIONS', COUNT(*) FROM CART_OLTP.FULFILLMENT_OPTIONS
UNION ALL SELECT 'CART_OLTP.PAYMENT_METHODS', COUNT(*) FROM CART_OLTP.PAYMENT_METHODS
UNION ALL SELECT 'CART_OLTP.PAYMENT_TRANSACTIONS', COUNT(*) FROM CART_OLTP.PAYMENT_TRANSACTIONS
UNION ALL SELECT 'CART_OLTP.ORDERS', COUNT(*) FROM CART_OLTP.ORDERS
UNION ALL SELECT 'CART_OLTP.ORDER_ITEMS', COUNT(*) FROM CART_OLTP.ORDER_ITEMS
ORDER BY table_name;

-- Sample data verification
SELECT 'Sample Products' AS check_type, name, brand, category, current_price 
FROM PRODUCTS.PRODUCTS LIMIT 5;

SELECT 'Sample Customers' AS check_type, first_name, last_name, loyalty_tier, points_balance 
FROM CUSTOMERS.CUSTOMERS LIMIT 5;

SELECT 'Sample Orders' AS check_type, order_number, status, total_cents/100.0 AS total_dollars 
FROM CART_OLTP.ORDERS LIMIT 5;

-- ============================================================================
-- OPTIONAL: S3 UPLOAD ALTERNATIVE
-- ============================================================================
-- If loading from S3, replace @UTIL.DATA_STAGE with @UTIL.S3_DATA_STAGE
-- in all COPY INTO statements above.
--
-- Example:
-- COPY INTO PRODUCTS.PRODUCTS
-- FROM @UTIL.S3_DATA_STAGE/csv/products.csv
-- FILE_FORMAT = UTIL.CSV_FORMAT
-- ON_ERROR = 'CONTINUE'
-- MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;
--
-- ============================================================================

-- ============================================================================
-- NEXT STEPS:
-- 1. Upload images to stages (hero, swatches, labels)
-- 2. Configure Cortex Agent with tools
-- 3. Deploy SPCS backend service
-- 4. Deploy frontend widget
-- ============================================================================

