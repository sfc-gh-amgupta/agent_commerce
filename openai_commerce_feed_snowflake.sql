-- ============================================================================
-- OpenAI Commerce Feed - Snowflake Database Schema
-- Based on specification: https://developers.openai.com/commerce/specs/feed
-- Created: 2025-11-26
-- ============================================================================

-- Database and Schema Setup
USE ROLE SYSADMIN;
-- CREATE DATABASE IF NOT EXISTS COMMERCE_DB;
-- USE DATABASE COMMERCE_DB;
-- CREATE SCHEMA IF NOT EXISTS OPENAI_FEED;
-- USE SCHEMA OPENAI_FEED;

-- ============================================================================
-- Main Product Feed Table
-- ============================================================================

CREATE OR REPLACE TABLE OPENAI_COMMERCE_PRODUCTS (
    -- Primary Key
    PRODUCT_KEY VARCHAR(100) PRIMARY KEY,
    
    -- Core Product Identifiers (REQUIRED)
    ID VARCHAR(100) NOT NULL,                    -- Unique merchant product ID
    GTIN VARCHAR(14),                            -- Universal product identifier (RECOMMENDED)
    MPN VARCHAR(70),                             -- Manufacturer part number (REQUIRED if gtin missing)
    
    -- Product Information (REQUIRED)
    TITLE VARCHAR(150) NOT NULL,                 -- Product title
    DESCRIPTION VARCHAR(5000) NOT NULL,          -- Full product description
    LINK VARCHAR(2048) NOT NULL,                 -- Product detail page URL
    IMAGE_LINK VARCHAR(2048) NOT NULL,           -- Main product image URL
    BRAND VARCHAR(70) NOT NULL,                  -- Product brand
    PRODUCT_CATEGORY VARCHAR(500) NOT NULL,      -- Category path with ">" separator
    MATERIAL VARCHAR(100) NOT NULL,              -- Primary material(s)
    WEIGHT VARCHAR(50) NOT NULL,                 -- Product weight with unit
    
    -- Product State (REQUIRED)
    AVAILABILITY VARCHAR(20) NOT NULL,           -- in_stock, out_of_stock, preorder
    CONDITION VARCHAR(20) DEFAULT 'new',         -- new, refurbished, used
    
    -- Pricing (REQUIRED)
    PRICE NUMBER(10,2) NOT NULL,                 -- Regular price
    PRICE_CURRENCY VARCHAR(3) NOT NULL DEFAULT 'USD', -- ISO 4217 currency code
    SALE_PRICE NUMBER(10,2),                     -- Discounted price (OPTIONAL)
    SALE_PRICE_CURRENCY VARCHAR(3),              -- Sale price currency
    SALE_PRICE_EFFECTIVE_START DATE,             -- Sale start date
    SALE_PRICE_EFFECTIVE_END DATE,               -- Sale end date
    
    -- ChatGPT Integration Controls (REQUIRED)
    ENABLE_SEARCH BOOLEAN NOT NULL DEFAULT TRUE,  -- Controls search surfacing
    ENABLE_CHECKOUT BOOLEAN NOT NULL DEFAULT TRUE,-- Allows direct purchase
    
    -- Additional Media (OPTIONAL)
    ADDITIONAL_IMAGE_LINKS VARIANT,              -- Array of image URLs stored as JSON
    VIDEO_LINK VARCHAR(2048),                    -- Product video URL
    MODEL_3D_LINK VARCHAR(2048),                 -- 3D model URL (GLB/GLTF)
    
    -- Shipping & Delivery (CONDITIONAL/OPTIONAL)
    SHIPPING VARIANT,                            -- Array of shipping options stored as JSON
    DELIVERY_ESTIMATE DATE,                      -- Estimated arrival date
    
    -- Seller Information (REQUIRED)
    SELLER_NAME VARCHAR(70) NOT NULL,            -- Seller name
    SELLER_URL VARCHAR(2048) NOT NULL,           -- Seller page URL
    RETURN_POLICY VARCHAR(2048) NOT NULL,        -- Return policy URL
    RETURN_WINDOW INTEGER NOT NULL,              -- Days allowed for return
    
    -- Product Metrics (RECOMMENDED)
    POPULARITY_SCORE NUMBER(3,2),                -- 0-5 scale
    RETURN_RATE NUMBER(5,2),                     -- 0-100% return rate
    PRODUCT_REVIEW_COUNT INTEGER,                -- Number of reviews
    PRODUCT_REVIEW_RATING NUMBER(3,2),           -- 0-5 scale average rating
    
    -- Compliance & Warnings (RECOMMENDED)
    WARNING VARCHAR(5000),                       -- Product disclaimers
    WARNING_URL VARCHAR(2048),                   -- Warning details URL
    AGE_RESTRICTION INTEGER,                     -- Minimum purchase age
    
    -- Product Relationships (RECOMMENDED)
    RELATED_PRODUCT_IDS VARIANT,                 -- Array of related product IDs
    RELATIONSHIP_TYPE VARCHAR(30),               -- Type of relationship
    
    -- Geographic Pricing & Availability (RECOMMENDED)
    GEO_PRICE VARIANT,                           -- JSON object with region-specific pricing
    GEO_AVAILABILITY VARIANT,                    -- JSON object with region-specific availability
    
    -- Metadata
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    LAST_SYNCED_AT TIMESTAMP_NTZ,
    
    -- Data Quality Flags
    IS_VALID BOOLEAN DEFAULT TRUE,
    VALIDATION_ERRORS VARIANT,                   -- JSON array of validation issues
    
    -- Constraints
    CONSTRAINT CHK_AVAILABILITY CHECK (AVAILABILITY IN ('in_stock', 'out_of_stock', 'preorder')),
    CONSTRAINT CHK_CONDITION CHECK (CONDITION IN ('new', 'refurbished', 'used')),
    CONSTRAINT CHK_SALE_PRICE CHECK (SALE_PRICE IS NULL OR SALE_PRICE <= PRICE),
    CONSTRAINT CHK_SALE_DATES CHECK (
        SALE_PRICE_EFFECTIVE_START IS NULL OR 
        SALE_PRICE_EFFECTIVE_END IS NULL OR 
        SALE_PRICE_EFFECTIVE_START < SALE_PRICE_EFFECTIVE_END
    ),
    CONSTRAINT CHK_RETURN_WINDOW CHECK (RETURN_WINDOW > 0),
    CONSTRAINT CHK_AGE_RESTRICTION CHECK (AGE_RESTRICTION IS NULL OR AGE_RESTRICTION > 0),
    CONSTRAINT CHK_RELATIONSHIP_TYPE CHECK (
        RELATIONSHIP_TYPE IS NULL OR 
        RELATIONSHIP_TYPE IN ('part_of_set', 'required_part', 'often_bought_with', 
                             'substitute', 'different_brand', 'accessory')
    )
);

-- ============================================================================
-- Indexes for Performance Optimization
-- ============================================================================

-- Clustering key for better performance on common queries
ALTER TABLE OPENAI_COMMERCE_PRODUCTS CLUSTER BY (BRAND, AVAILABILITY, UPDATED_AT);

-- ============================================================================
-- Staging Table for Data Ingestion
-- ============================================================================

CREATE OR REPLACE TABLE OPENAI_COMMERCE_PRODUCTS_STAGING (
    RAW_DATA VARIANT,                            -- Raw JSON data from feed
    FILE_NAME VARCHAR(500),
    FILE_ROW_NUMBER INTEGER,
    LOAD_TIMESTAMP TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- Views
-- ============================================================================

-- View for active, searchable products
CREATE OR REPLACE VIEW VW_ACTIVE_PRODUCTS AS
SELECT 
    ID,
    TITLE,
    DESCRIPTION,
    BRAND,
    PRICE,
    PRICE_CURRENCY,
    SALE_PRICE,
    AVAILABILITY,
    IMAGE_LINK,
    LINK,
    PRODUCT_REVIEW_RATING,
    PRODUCT_REVIEW_COUNT,
    POPULARITY_SCORE
FROM OPENAI_COMMERCE_PRODUCTS
WHERE 
    ENABLE_SEARCH = TRUE
    AND AVAILABILITY = 'in_stock'
    AND IS_VALID = TRUE;

-- View for checkout-enabled products
CREATE OR REPLACE VIEW VW_CHECKOUT_ENABLED_PRODUCTS AS
SELECT 
    ID,
    TITLE,
    BRAND,
    PRICE,
    PRICE_CURRENCY,
    SALE_PRICE,
    AVAILABILITY,
    IMAGE_LINK,
    LINK,
    SELLER_NAME,
    RETURN_POLICY,
    RETURN_WINDOW,
    WARNING,
    AGE_RESTRICTION
FROM OPENAI_COMMERCE_PRODUCTS
WHERE 
    ENABLE_CHECKOUT = TRUE
    AND AVAILABILITY IN ('in_stock', 'preorder')
    AND IS_VALID = TRUE;

-- View for products on sale
CREATE OR REPLACE VIEW VW_SALE_PRODUCTS AS
SELECT 
    ID,
    TITLE,
    BRAND,
    PRICE,
    SALE_PRICE,
    ROUND(((PRICE - SALE_PRICE) / PRICE) * 100, 2) AS DISCOUNT_PERCENTAGE,
    SALE_PRICE_EFFECTIVE_START,
    SALE_PRICE_EFFECTIVE_END,
    IMAGE_LINK,
    LINK
FROM OPENAI_COMMERCE_PRODUCTS
WHERE 
    SALE_PRICE IS NOT NULL
    AND SALE_PRICE < PRICE
    AND (SALE_PRICE_EFFECTIVE_START IS NULL OR SALE_PRICE_EFFECTIVE_START <= CURRENT_DATE())
    AND (SALE_PRICE_EFFECTIVE_END IS NULL OR SALE_PRICE_EFFECTIVE_END >= CURRENT_DATE())
    AND IS_VALID = TRUE;

-- View for product metrics and analytics
CREATE OR REPLACE VIEW VW_PRODUCT_METRICS AS
SELECT 
    BRAND,
    COUNT(*) AS PRODUCT_COUNT,
    AVG(PRICE) AS AVG_PRICE,
    AVG(PRODUCT_REVIEW_RATING) AS AVG_RATING,
    SUM(PRODUCT_REVIEW_COUNT) AS TOTAL_REVIEWS,
    SUM(CASE WHEN AVAILABILITY = 'in_stock' THEN 1 ELSE 0 END) AS IN_STOCK_COUNT,
    SUM(CASE WHEN AVAILABILITY = 'out_of_stock' THEN 1 ELSE 0 END) AS OUT_OF_STOCK_COUNT,
    AVG(RETURN_RATE) AS AVG_RETURN_RATE
FROM OPENAI_COMMERCE_PRODUCTS
WHERE IS_VALID = TRUE
GROUP BY BRAND;

-- ============================================================================
-- Stored Procedures
-- ============================================================================

-- Procedure to load data from staging to main table
CREATE OR REPLACE PROCEDURE SP_LOAD_PRODUCTS_FROM_STAGING()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- Insert or update products from staging
    MERGE INTO OPENAI_COMMERCE_PRODUCTS AS TARGET
    USING (
        SELECT 
            RAW_DATA:id::VARCHAR AS ID,
            RAW_DATA:id::VARCHAR AS PRODUCT_KEY,
            RAW_DATA:gtin::VARCHAR AS GTIN,
            RAW_DATA:mpn::VARCHAR AS MPN,
            RAW_DATA:title::VARCHAR(150) AS TITLE,
            RAW_DATA:description::VARCHAR(5000) AS DESCRIPTION,
            RAW_DATA:link::VARCHAR AS LINK,
            RAW_DATA:image_link::VARCHAR AS IMAGE_LINK,
            RAW_DATA:brand::VARCHAR AS BRAND,
            RAW_DATA:product_category::VARCHAR AS PRODUCT_CATEGORY,
            RAW_DATA:material::VARCHAR AS MATERIAL,
            RAW_DATA:weight::VARCHAR AS WEIGHT,
            RAW_DATA:availability::VARCHAR AS AVAILABILITY,
            RAW_DATA:condition::VARCHAR AS CONDITION,
            RAW_DATA:price::NUMBER AS PRICE,
            RAW_DATA:price_currency::VARCHAR AS PRICE_CURRENCY,
            RAW_DATA:sale_price::NUMBER AS SALE_PRICE,
            RAW_DATA:sale_price_currency::VARCHAR AS SALE_PRICE_CURRENCY,
            RAW_DATA:enable_search::BOOLEAN AS ENABLE_SEARCH,
            RAW_DATA:enable_checkout::BOOLEAN AS ENABLE_CHECKOUT,
            RAW_DATA:additional_image_links AS ADDITIONAL_IMAGE_LINKS,
            RAW_DATA:video_link::VARCHAR AS VIDEO_LINK,
            RAW_DATA:model_3d_link::VARCHAR AS MODEL_3D_LINK,
            RAW_DATA:shipping AS SHIPPING,
            RAW_DATA:seller_name::VARCHAR AS SELLER_NAME,
            RAW_DATA:seller_url::VARCHAR AS SELLER_URL,
            RAW_DATA:return_policy::VARCHAR AS RETURN_POLICY,
            RAW_DATA:return_window::INTEGER AS RETURN_WINDOW,
            RAW_DATA:popularity_score::NUMBER AS POPULARITY_SCORE,
            RAW_DATA:return_rate::NUMBER AS RETURN_RATE,
            RAW_DATA:product_review_count::INTEGER AS PRODUCT_REVIEW_COUNT,
            RAW_DATA:product_review_rating::NUMBER AS PRODUCT_REVIEW_RATING,
            RAW_DATA:warning::VARCHAR AS WARNING,
            RAW_DATA:age_restriction::INTEGER AS AGE_RESTRICTION,
            RAW_DATA:related_product_ids AS RELATED_PRODUCT_IDS,
            RAW_DATA:relationship_type::VARCHAR AS RELATIONSHIP_TYPE,
            RAW_DATA:geo_price AS GEO_PRICE,
            RAW_DATA:geo_availability AS GEO_AVAILABILITY,
            CURRENT_TIMESTAMP() AS LAST_SYNCED_AT
        FROM OPENAI_COMMERCE_PRODUCTS_STAGING
    ) AS SOURCE
    ON TARGET.PRODUCT_KEY = SOURCE.PRODUCT_KEY
    WHEN MATCHED THEN UPDATE SET
        TARGET.TITLE = SOURCE.TITLE,
        TARGET.DESCRIPTION = SOURCE.DESCRIPTION,
        TARGET.PRICE = SOURCE.PRICE,
        TARGET.SALE_PRICE = SOURCE.SALE_PRICE,
        TARGET.AVAILABILITY = SOURCE.AVAILABILITY,
        TARGET.UPDATED_AT = CURRENT_TIMESTAMP(),
        TARGET.LAST_SYNCED_AT = SOURCE.LAST_SYNCED_AT
    WHEN NOT MATCHED THEN INSERT (
        PRODUCT_KEY, ID, GTIN, MPN, TITLE, DESCRIPTION, LINK, IMAGE_LINK,
        BRAND, PRODUCT_CATEGORY, MATERIAL, WEIGHT, AVAILABILITY, CONDITION,
        PRICE, PRICE_CURRENCY, SALE_PRICE, SALE_PRICE_CURRENCY,
        ENABLE_SEARCH, ENABLE_CHECKOUT, ADDITIONAL_IMAGE_LINKS, VIDEO_LINK,
        MODEL_3D_LINK, SHIPPING, SELLER_NAME, SELLER_URL, RETURN_POLICY,
        RETURN_WINDOW, POPULARITY_SCORE, RETURN_RATE, PRODUCT_REVIEW_COUNT,
        PRODUCT_REVIEW_RATING, WARNING, AGE_RESTRICTION, RELATED_PRODUCT_IDS,
        RELATIONSHIP_TYPE, GEO_PRICE, GEO_AVAILABILITY, LAST_SYNCED_AT
    ) VALUES (
        SOURCE.PRODUCT_KEY, SOURCE.ID, SOURCE.GTIN, SOURCE.MPN, SOURCE.TITLE,
        SOURCE.DESCRIPTION, SOURCE.LINK, SOURCE.IMAGE_LINK, SOURCE.BRAND,
        SOURCE.PRODUCT_CATEGORY, SOURCE.MATERIAL, SOURCE.WEIGHT, SOURCE.AVAILABILITY,
        SOURCE.CONDITION, SOURCE.PRICE, SOURCE.PRICE_CURRENCY, SOURCE.SALE_PRICE,
        SOURCE.SALE_PRICE_CURRENCY, SOURCE.ENABLE_SEARCH, SOURCE.ENABLE_CHECKOUT,
        SOURCE.ADDITIONAL_IMAGE_LINKS, SOURCE.VIDEO_LINK, SOURCE.MODEL_3D_LINK,
        SOURCE.SHIPPING, SOURCE.SELLER_NAME, SOURCE.SELLER_URL, SOURCE.RETURN_POLICY,
        SOURCE.RETURN_WINDOW, SOURCE.POPULARITY_SCORE, SOURCE.RETURN_RATE,
        SOURCE.PRODUCT_REVIEW_COUNT, SOURCE.PRODUCT_REVIEW_RATING, SOURCE.WARNING,
        SOURCE.AGE_RESTRICTION, SOURCE.RELATED_PRODUCT_IDS, SOURCE.RELATIONSHIP_TYPE,
        SOURCE.GEO_PRICE, SOURCE.GEO_AVAILABILITY, SOURCE.LAST_SYNCED_AT
    );
    
    -- Clear staging table
    TRUNCATE TABLE OPENAI_COMMERCE_PRODUCTS_STAGING;
    
    RETURN 'Products loaded successfully';
END;
$$;

-- ============================================================================
-- Sample Data Load (JSON Format)
-- ============================================================================

-- Example: Load from JSON file using COPY command
/*
COPY INTO OPENAI_COMMERCE_PRODUCTS_STAGING(RAW_DATA, FILE_NAME, FILE_ROW_NUMBER)
FROM (
    SELECT 
        $1,
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER
    FROM @YOUR_STAGE/product_feed.json
)
FILE_FORMAT = (TYPE = JSON);

-- Process the staging data
CALL SP_LOAD_PRODUCTS_FROM_STAGING();
*/

-- ============================================================================
-- Sample Insert Statement
-- ============================================================================

/*
INSERT INTO OPENAI_COMMERCE_PRODUCTS (
    PRODUCT_KEY, ID, TITLE, DESCRIPTION, LINK, IMAGE_LINK, 
    PRICE, PRICE_CURRENCY, AVAILABILITY, BRAND, PRODUCT_CATEGORY, 
    MATERIAL, WEIGHT, ENABLE_SEARCH, ENABLE_CHECKOUT,
    SELLER_NAME, SELLER_URL, RETURN_POLICY, RETURN_WINDOW
) VALUES (
    'PROD001', 'SKU12345', 'Men''s Trail Running Shoes Black',
    'Waterproof trail shoe with cushioned sole for maximum comfort and durability',
    'https://example.com/product/SKU12345',
    'https://example.com/images/SKU12345.jpg',
    79.99, 'USD', 'in_stock', 'OpenAI',
    'Apparel & Accessories > Shoes > Athletic Shoes',
    'Synthetic, Rubber', '1.5 lb', TRUE, TRUE,
    'Example Store', 'https://example.com/store',
    'https://example.com/returns', 30
);
*/

-- ============================================================================
-- Useful Queries
-- ============================================================================

-- Check data quality
/*
SELECT 
    COUNT(*) AS TOTAL_PRODUCTS,
    SUM(CASE WHEN IS_VALID THEN 1 ELSE 0 END) AS VALID_PRODUCTS,
    SUM(CASE WHEN GTIN IS NULL AND MPN IS NULL THEN 1 ELSE 0 END) AS MISSING_IDENTIFIERS,
    SUM(CASE WHEN ENABLE_SEARCH THEN 1 ELSE 0 END) AS SEARCHABLE_PRODUCTS,
    SUM(CASE WHEN ENABLE_CHECKOUT THEN 1 ELSE 0 END) AS CHECKOUT_ENABLED
FROM OPENAI_COMMERCE_PRODUCTS;
*/

-- Top selling products
/*
SELECT 
    ID,
    TITLE,
    BRAND,
    PRICE,
    PRODUCT_REVIEW_RATING,
    PRODUCT_REVIEW_COUNT,
    POPULARITY_SCORE
FROM OPENAI_COMMERCE_PRODUCTS
WHERE ENABLE_SEARCH = TRUE AND AVAILABILITY = 'in_stock'
ORDER BY POPULARITY_SCORE DESC, PRODUCT_REVIEW_RATING DESC
LIMIT 100;
*/


