-- ============================================================================
-- AGENT COMMERCE - Table Definitions
-- ============================================================================
-- This script creates all tables for the Agent Commerce platform.
-- Run after 01_setup_database.sql
--
-- All tables are created under AGENT_COMMERCE_ROLE for proper ownership.
-- ============================================================================

-- Use the Agent Commerce role to ensure proper ownership
USE ROLE AGENT_COMMERCE_ROLE;

USE DATABASE AGENT_COMMERCE;
USE WAREHOUSE AGENT_COMMERCE_WH;

-- ============================================================================
-- CUSTOMERS SCHEMA - Customer data and identity
-- ============================================================================
USE SCHEMA CUSTOMERS;

-- ----------------------------------------------------------------------------
-- Core customer profile
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS CUSTOMERS (
    customer_id VARCHAR(36) PRIMARY KEY DEFAULT UUID_STRING(),
    email VARCHAR(255) UNIQUE,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    phone VARCHAR(20),
    
    -- Loyalty program
    loyalty_tier VARCHAR(20) DEFAULT 'Bronze',  -- Bronze, Silver, Gold, Platinum
    points_balance INTEGER DEFAULT 0,
    lifetime_points INTEGER DEFAULT 0,
    
    -- Beauty profile (populated after analysis)
    skin_profile OBJECT,  -- {skin_tone, undertone, fitzpatrick, monk, hex, lab}
    
    -- Preferences
    preferences OBJECT,   -- {favorite_brands, allergies, notifications, etc.}
    
    -- Metadata
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ,
    last_login_at TIMESTAMP_NTZ,
    is_active BOOLEAN DEFAULT TRUE
);

-- ----------------------------------------------------------------------------
-- Face embeddings for recognition
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS CUSTOMER_FACE_EMBEDDINGS (
    embedding_id VARCHAR(36) PRIMARY KEY DEFAULT UUID_STRING(),
    customer_id VARCHAR(36) NOT NULL REFERENCES CUSTOMERS(customer_id),
    
    -- 128-dimensional face embedding from dlib
    embedding VECTOR(FLOAT, 128) NOT NULL,
    
    -- Quality metadata
    quality_score FLOAT,           -- 0-1, higher is better
    lighting_condition VARCHAR(20), -- 'good', 'low', 'bright', 'mixed'
    face_angle VARCHAR(20),        -- 'frontal', 'slight_left', 'slight_right'
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_primary BOOLEAN DEFAULT FALSE,
    
    -- Metadata
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    source VARCHAR(50)             -- 'widget_camera', 'widget_upload', 'profile_upload'
);

-- ----------------------------------------------------------------------------
-- Skin analysis history
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SKIN_ANALYSIS_HISTORY (
    analysis_id VARCHAR(36) PRIMARY KEY DEFAULT UUID_STRING(),
    customer_id VARCHAR(36) REFERENCES CUSTOMERS(customer_id),
    
    -- Image reference (stored in stage)
    image_stage_path VARCHAR(500),
    
    -- Skin analysis results
    skin_hex VARCHAR(7),           -- #RRGGBB
    skin_lab ARRAY,                -- [L, a, b]
    skin_rgb ARRAY,                -- [R, G, B]
    
    -- Lip analysis results
    lip_hex VARCHAR(7),
    lip_lab ARRAY,
    lip_rgb ARRAY,
    lip_is_natural BOOLEAN,        -- False if makeup detected
    estimated_natural_lip_hex VARCHAR(7),
    
    -- Classifications
    fitzpatrick_type INTEGER,      -- 1-6
    monk_shade INTEGER,            -- 1-10
    undertone VARCHAR(20),         -- warm, cool, neutral
    ita_angle FLOAT,               -- Individual Typology Angle
    
    -- Makeup detection
    makeup_detected BOOLEAN DEFAULT FALSE,
    detected_makeup_types ARRAY,   -- ['lipstick', 'foundation', etc.]
    
    -- Quality metrics
    confidence_score FLOAT,        -- 0-1
    face_quality_score FLOAT,
    lighting_quality VARCHAR(20),
    
    -- Metadata
    analyzed_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    analysis_duration_ms INTEGER,
    model_version VARCHAR(20)
);

-- ============================================================================
-- PRODUCTS SCHEMA - Product catalog
-- ============================================================================
USE SCHEMA PRODUCTS;

-- ----------------------------------------------------------------------------
-- Core products
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS PRODUCTS (
    product_id VARCHAR(36) PRIMARY KEY DEFAULT UUID_STRING(),
    sku VARCHAR(50) UNIQUE,
    
    -- Basic info
    name VARCHAR(255) NOT NULL,
    brand VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,      -- foundation, lipstick, blush, bronzer, concealer
    subcategory VARCHAR(50),            -- liquid, powder, cream, stick
    
    -- Descriptions
    description TEXT,
    short_description VARCHAR(500),
    
    -- Pricing
    base_price DECIMAL(10,2) NOT NULL,
    current_price DECIMAL(10,2) NOT NULL,
    cost DECIMAL(10,2),
    
    -- Color attributes (for color-matching products)
    color_hex VARCHAR(7),              -- Primary color hex
    color_lab ARRAY,                   -- [L, a, b] for CIEDE2000
    color_name VARCHAR(50),            -- "Rose Beige", "Honey Glow"
    finish VARCHAR(30),                -- matte, satin, glossy, shimmer, metallic
    
    -- Compatibility (for recommendations)
    skin_tone_compatibility ARRAY,     -- ['fair', 'light', 'medium', 'tan', 'deep']
    undertone_compatibility ARRAY,     -- ['warm', 'cool', 'neutral']
    monk_scale_min INTEGER,            -- Minimum Monk scale (1-10)
    monk_scale_max INTEGER,            -- Maximum Monk scale (1-10)
    
    -- Product attributes
    size VARCHAR(50),
    size_unit VARCHAR(20),             -- ml, oz, g
    ingredients TEXT,
    is_vegan BOOLEAN DEFAULT FALSE,
    is_cruelty_free BOOLEAN DEFAULT FALSE,
    spf_value INTEGER,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_featured BOOLEAN DEFAULT FALSE,
    launch_date DATE,
    discontinue_date DATE,
    
    -- Metadata
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ
);

-- ----------------------------------------------------------------------------
-- Product variants (shades/sizes)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS PRODUCT_VARIANTS (
    variant_id VARCHAR(36) PRIMARY KEY DEFAULT UUID_STRING(),
    product_id VARCHAR(36) NOT NULL REFERENCES PRODUCTS(product_id),
    sku VARCHAR(50) UNIQUE,
    
    -- Variant attributes
    shade_name VARCHAR(100),           -- "N10 Porcelain", "420 Caramel"
    shade_code VARCHAR(20),            -- "N10", "420"
    color_hex VARCHAR(7),
    color_lab ARRAY,
    
    -- Size variant
    size VARCHAR(50),
    size_unit VARCHAR(20),
    
    -- Pricing
    price_modifier DECIMAL(10,2) DEFAULT 0,  -- Added to base price
    
    -- Status
    is_available BOOLEAN DEFAULT TRUE,
    is_default BOOLEAN DEFAULT FALSE,
    
    -- Metadata
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    display_order INTEGER DEFAULT 0
);

-- ----------------------------------------------------------------------------
-- Product media (images/videos)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS PRODUCT_MEDIA (
    media_id VARCHAR(36) PRIMARY KEY DEFAULT UUID_STRING(),
    product_id VARCHAR(36) NOT NULL REFERENCES PRODUCTS(product_id),
    variant_id VARCHAR(36) REFERENCES PRODUCT_VARIANTS(variant_id),
    
    -- Media info
    url VARCHAR(1000) NOT NULL,
    media_type VARCHAR(20) NOT NULL,   -- image, video
    media_subtype VARCHAR(30),         -- hero, swatch, label, ingredients, warnings, lifestyle, tutorial
    
    -- Metadata
    alt_text VARCHAR(255),
    width INTEGER,
    height INTEGER,
    file_size_bytes INTEGER,
    
    -- Display
    display_order INTEGER DEFAULT 0,
    is_primary BOOLEAN DEFAULT FALSE,
    
    -- Processing status (for AI extraction)
    is_processed BOOLEAN DEFAULT FALSE,
    processed_at TIMESTAMP_NTZ,
    
    -- Metadata
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ----------------------------------------------------------------------------
-- Product labels (extracted via AI_EXTRACT)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS PRODUCT_LABELS (
    label_id VARCHAR(36) PRIMARY KEY DEFAULT UUID_STRING(),
    product_id VARCHAR(36) NOT NULL REFERENCES PRODUCTS(product_id),
    
    -- Label type
    label_type VARCHAR(30) NOT NULL,   -- ingredients, warnings, claims, directions
    
    -- Extracted content
    extracted_text TEXT,               -- Raw text
    structured_data VARIANT,           -- Full JSON from AI_EXTRACT
    
    -- Source traceability
    source_image_url VARCHAR(1000),
    source_media_id VARCHAR(36) REFERENCES PRODUCT_MEDIA(media_id),
    
    -- Extraction metadata
    extraction_model VARCHAR(50),
    extraction_confidence FLOAT,
    extraction_date TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ----------------------------------------------------------------------------
-- Product ingredients (flattened for search)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS PRODUCT_INGREDIENTS (
    ingredient_id VARCHAR(36) PRIMARY KEY DEFAULT UUID_STRING(),
    product_id VARCHAR(36) NOT NULL REFERENCES PRODUCTS(product_id),
    label_id VARCHAR(36) REFERENCES PRODUCT_LABELS(label_id),
    
    -- Ingredient info
    ingredient_name VARCHAR(255) NOT NULL,
    ingredient_name_normalized VARCHAR(255),  -- Standardized name
    position INTEGER,                  -- Order of concentration (1 = highest)
    percentage FLOAT,                  -- If disclosed
    
    -- Classification
    is_active BOOLEAN DEFAULT FALSE,   -- Active ingredient
    is_allergen BOOLEAN DEFAULT FALSE,
    allergen_type VARCHAR(50),
    
    -- Traceability
    source_image_url VARCHAR(1000),
    
    -- Metadata
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ----------------------------------------------------------------------------
-- Product warnings (flattened for search)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS PRODUCT_WARNINGS (
    warning_id VARCHAR(36) PRIMARY KEY DEFAULT UUID_STRING(),
    product_id VARCHAR(36) NOT NULL REFERENCES PRODUCTS(product_id),
    label_id VARCHAR(36) REFERENCES PRODUCT_LABELS(label_id),
    
    -- Warning info
    warning_type VARCHAR(50),          -- allergy, usage, storage, age_restriction
    warning_text TEXT NOT NULL,
    severity VARCHAR(20),              -- info, caution, warning, danger
    
    -- Traceability
    source_image_url VARCHAR(1000),
    
    -- Metadata
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ----------------------------------------------------------------------------
-- Price history
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS PRICE_HISTORY (
    history_id VARCHAR(36) PRIMARY KEY DEFAULT UUID_STRING(),
    product_id VARCHAR(36) NOT NULL REFERENCES PRODUCTS(product_id),
    variant_id VARCHAR(36) REFERENCES PRODUCT_VARIANTS(variant_id),
    
    -- Price info
    price DECIMAL(10,2) NOT NULL,
    previous_price DECIMAL(10,2),
    
    -- Effective period
    effective_date DATE NOT NULL,
    end_date DATE,
    
    -- Change reason
    change_reason VARCHAR(100),        -- promotion, cost_increase, seasonal, clearance
    
    -- Metadata
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ----------------------------------------------------------------------------
-- Promotions
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS PROMOTIONS (
    promotion_id VARCHAR(36) PRIMARY KEY DEFAULT UUID_STRING(),
    
    -- Promotion info
    name VARCHAR(255) NOT NULL,
    description TEXT,
    promo_code VARCHAR(50),
    
    -- Discount type
    discount_type VARCHAR(20) NOT NULL, -- percentage, fixed, bogo, free_shipping
    discount_value DECIMAL(10,2),       -- Percentage or fixed amount
    
    -- Scope
    applies_to VARCHAR(20),            -- all, category, brand, product
    product_ids ARRAY,
    category_ids ARRAY,
    brand_names ARRAY,
    
    -- Conditions
    min_purchase_amount DECIMAL(10,2),
    max_uses INTEGER,
    max_uses_per_customer INTEGER,
    current_uses INTEGER DEFAULT 0,
    
    -- Validity
    start_date TIMESTAMP_NTZ NOT NULL,
    end_date TIMESTAMP_NTZ NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Metadata
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);


-- ============================================================================
-- INVENTORY SCHEMA - Locations and stock management
-- ============================================================================
USE SCHEMA INVENTORY;

-- ----------------------------------------------------------------------------
-- Locations (stores/warehouses)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS LOCATIONS (
    location_id VARCHAR(36) PRIMARY KEY DEFAULT UUID_STRING(),
    
    -- Location info
    name VARCHAR(255) NOT NULL,
    location_type VARCHAR(20) NOT NULL, -- warehouse, store, popup
    location_code VARCHAR(20) UNIQUE,
    
    -- Address
    address_line1 VARCHAR(255),
    address_line2 VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(50),
    postal_code VARCHAR(20),
    country VARCHAR(2) DEFAULT 'US',
    
    -- Coordinates
    latitude FLOAT,
    longitude FLOAT,
    
    -- Contact
    phone VARCHAR(20),
    email VARCHAR(255),
    
    -- Hours
    operating_hours OBJECT,            -- {mon: {open: "09:00", close: "21:00"}, ...}
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_pickup_enabled BOOLEAN DEFAULT FALSE,
    
    -- Metadata
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ----------------------------------------------------------------------------
-- Inventory levels
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS STOCK_LEVELS (
    stock_id VARCHAR(36) PRIMARY KEY DEFAULT UUID_STRING(),
    product_id VARCHAR(36) NOT NULL,   -- References PRODUCTS.PRODUCTS
    variant_id VARCHAR(36),            -- References PRODUCTS.PRODUCT_VARIANTS
    location_id VARCHAR(36) NOT NULL REFERENCES LOCATIONS(location_id),
    
    -- Quantities
    quantity_on_hand INTEGER NOT NULL DEFAULT 0,
    quantity_reserved INTEGER NOT NULL DEFAULT 0,
    -- Note: quantity_available, is_in_stock, needs_reorder are calculated at query time
    
    -- Reorder settings
    reorder_point INTEGER DEFAULT 10,
    reorder_quantity INTEGER DEFAULT 50,
    
    -- Status
    last_restock_date DATE,
    
    -- Metadata
    last_updated TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    
    -- Unique constraint
    UNIQUE (product_id, variant_id, location_id)
);

-- ----------------------------------------------------------------------------
-- Inventory transactions (for audit trail)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS INVENTORY_TRANSACTIONS (
    transaction_id VARCHAR(36) PRIMARY KEY DEFAULT UUID_STRING(),
    stock_id VARCHAR(36) NOT NULL REFERENCES STOCK_LEVELS(stock_id),
    
    -- Transaction details
    transaction_type VARCHAR(30) NOT NULL,  -- received, sold, reserved, released, adjusted, returned
    quantity INTEGER NOT NULL,
    quantity_before INTEGER,
    quantity_after INTEGER,
    
    -- Reference
    reference_type VARCHAR(30),        -- order, purchase_order, adjustment, return
    reference_id VARCHAR(36),
    
    -- Notes
    notes TEXT,
    
    -- Metadata
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR(100)
);

-- ============================================================================
-- SOCIAL SCHEMA - Reviews, mentions, influencers
-- ============================================================================
USE SCHEMA SOCIAL;

-- ----------------------------------------------------------------------------
-- Product reviews (retailer's platform)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS PRODUCT_REVIEWS (
    review_id VARCHAR(36) PRIMARY KEY DEFAULT UUID_STRING(),
    product_id VARCHAR(36) NOT NULL,
    customer_id VARCHAR(36),           -- Nullable for anonymous
    
    -- Platform
    platform VARCHAR(30) NOT NULL,     -- website, app, bazaarvoice, yotpo
    
    -- Review content
    rating INTEGER NOT NULL,  -- Values 1-5 (validated at application level)
    title VARCHAR(255),
    review_text TEXT,
    
    -- Direct link
    review_url VARCHAR(1000),
    
    -- Engagement
    helpful_votes INTEGER DEFAULT 0,
    not_helpful_votes INTEGER DEFAULT 0,
    
    -- Verification
    verified_purchase BOOLEAN DEFAULT FALSE,
    
    -- Reviewer demographics (from profile, if available)
    reviewer_skin_tone VARCHAR(30),    -- Fair, Light, Medium, Tan, Deep
    reviewer_skin_type VARCHAR(30),    -- Oily, Dry, Combination, Normal, Sensitive
    reviewer_undertone VARCHAR(20),    -- Warm, Cool, Neutral
    reviewer_age_range VARCHAR(20),    -- 18-24, 25-34, 35-44, 45-54, 55+
    
    -- Moderation
    is_approved BOOLEAN DEFAULT TRUE,
    moderation_status VARCHAR(20),     -- pending, approved, rejected
    
    -- Metadata
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ
);

-- ----------------------------------------------------------------------------
-- Social media mentions
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS SOCIAL_MENTIONS (
    mention_id VARCHAR(36) PRIMARY KEY DEFAULT UUID_STRING(),
    product_id VARCHAR(36) NOT NULL,
    
    -- Platform
    platform VARCHAR(30) NOT NULL,     -- instagram, tiktok, youtube, twitter, pinterest
    
    -- Content
    post_url VARCHAR(1000) NOT NULL,
    content_text TEXT,
    media_url VARCHAR(1000),           -- Image/video thumbnail
    
    -- Author
    author_handle VARCHAR(100),
    author_name VARCHAR(255),
    author_follower_count INTEGER,
    
    -- Engagement
    likes INTEGER DEFAULT 0,
    comments INTEGER DEFAULT 0,
    shares INTEGER DEFAULT 0,
    views INTEGER DEFAULT 0,
    
    -- Analysis
    sentiment_score FLOAT,             -- -1 to 1
    sentiment_label VARCHAR(20),       -- positive, neutral, negative
    
    -- Metadata
    posted_at TIMESTAMP_NTZ,
    ingested_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ----------------------------------------------------------------------------
-- Influencer mentions
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS INFLUENCER_MENTIONS (
    mention_id VARCHAR(36) PRIMARY KEY DEFAULT UUID_STRING(),
    product_id VARCHAR(36) NOT NULL,
    
    -- Influencer info
    influencer_id VARCHAR(36),
    influencer_handle VARCHAR(100) NOT NULL,
    influencer_name VARCHAR(255),
    
    -- Platform
    platform VARCHAR(30) NOT NULL,
    
    -- Content
    post_url VARCHAR(1000) NOT NULL,
    content_text TEXT,
    media_url VARCHAR(1000),
    content_type VARCHAR(30),          -- post, story, reel, video, review
    
    -- Engagement
    likes INTEGER DEFAULT 0,
    comments INTEGER DEFAULT 0,
    shares INTEGER DEFAULT 0,
    views INTEGER DEFAULT 0,
    
    -- Influencer demographics (from Viral Nation/CreatorIQ or manual curation)
    influencer_skin_tone VARCHAR(30),  -- Fair, Light, Medium, Tan, Deep
    influencer_skin_type VARCHAR(30),  -- Oily, Dry, Combination, Normal
    influencer_undertone VARCHAR(20),  -- Warm, Cool, Neutral
    
    -- Influencer stats
    follower_count INTEGER,
    engagement_rate FLOAT,
    
    -- Audience demographics (from external platforms)
    audience_demographics OBJECT,      -- {age_ranges, gender_split, top_locations}
    
    -- Partnership
    is_sponsored BOOLEAN DEFAULT FALSE,
    is_affiliate BOOLEAN DEFAULT FALSE,
    
    -- Metadata
    posted_at TIMESTAMP_NTZ,
    ingested_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ----------------------------------------------------------------------------
-- Trending products (calculated)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS TRENDING_PRODUCTS (
    trend_id VARCHAR(36) PRIMARY KEY DEFAULT UUID_STRING(),
    product_id VARCHAR(36) NOT NULL,
    
    -- Trend metrics
    trend_rank INTEGER,
    trend_score FLOAT,
    mention_velocity FLOAT,            -- Mentions per hour
    sentiment_average FLOAT,
    
    -- Status
    is_viral BOOLEAN DEFAULT FALSE,
    viral_reason VARCHAR(255),
    
    -- Sources
    trending_platforms ARRAY,          -- Where it's trending
    top_hashtags ARRAY,
    
    -- Time window
    window_start TIMESTAMP_NTZ,
    window_end TIMESTAMP_NTZ,
    
    -- Metadata
    calculated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ============================================================================
-- CART_OLTP SCHEMA - Cart, checkout, payments (HYBRID TABLES for ACID transactions)
-- ============================================================================
-- OLTP = Online Transaction Processing
-- Note: Using HYBRID TABLES for transactional integrity:
--   - ACID transactions for cart updates and payments
--   - Row-level locking for concurrent users
--   - Enforced foreign key constraints
--   - Low-latency single-row operations (10-50ms)
-- Ref: https://docs.snowflake.com/en/sql-reference/sql/create-hybrid-table
-- ============================================================================
USE SCHEMA CART_OLTP;

-- ----------------------------------------------------------------------------
-- Cart sessions (HYBRID TABLE)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE HYBRID TABLE CART_SESSIONS (
    session_id VARCHAR(36) PRIMARY KEY,
    customer_id VARCHAR(36),           -- Nullable for guest checkout
    
    -- Status
    status VARCHAR(30) NOT NULL DEFAULT 'active',  
    -- active, pending_payment, completed, expired, cancelled, abandoned
    
    -- Pricing (amounts in cents for precision)
    subtotal_cents INTEGER DEFAULT 0,
    tax_cents INTEGER DEFAULT 0,
    shipping_cents INTEGER DEFAULT 0,
    discount_cents INTEGER DEFAULT 0,
    total_cents INTEGER DEFAULT 0,
    currency VARCHAR(3) DEFAULT 'USD',
    
    -- Applied promotions
    applied_promo_codes VARCHAR(1000), -- JSON array as string (HYBRID limitation)
    applied_loyalty_points INTEGER DEFAULT 0,
    
    -- Fulfillment
    fulfillment_type VARCHAR(20),      -- shipping, pickup
    shipping_address VARCHAR(2000),    -- JSON as string (HYBRID limitation)
    billing_address VARCHAR(2000),     -- JSON as string (HYBRID limitation)
    shipping_method_id VARCHAR(36),
    
    -- Gift options
    is_gift BOOLEAN DEFAULT FALSE,
    gift_message VARCHAR(500),
    gift_recipient_email VARCHAR(255),
    
    -- Validation (ACP aligned)
    is_valid BOOLEAN DEFAULT TRUE,
    validation_message VARCHAR(500),
    
    -- Idempotency
    idempotency_key VARCHAR(100),
    
    -- Metadata
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ,
    expires_at TIMESTAMP_NTZ,
    completed_at TIMESTAMP_NTZ,
    
    -- Index for fast customer lookup
    INDEX idx_cart_customer (customer_id),
    INDEX idx_cart_status (status)
);

-- ----------------------------------------------------------------------------
-- Cart items (HYBRID TABLE)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE HYBRID TABLE CART_ITEMS (
    item_id VARCHAR(36) PRIMARY KEY,
    session_id VARCHAR(36) NOT NULL,
    product_id VARCHAR(36) NOT NULL,
    variant_id VARCHAR(36),
    
    -- Quantity
    quantity INTEGER NOT NULL DEFAULT 1,
    
    -- Pricing (in cents)
    unit_price_cents INTEGER NOT NULL,
    subtotal_cents INTEGER NOT NULL,
    
    -- Product snapshot (at time of adding)
    product_name VARCHAR(255),
    variant_name VARCHAR(100),
    product_image_url VARCHAR(1000),
    
    -- Metadata
    added_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ,
    
    -- Foreign key to cart session
    FOREIGN KEY (session_id) REFERENCES CART_SESSIONS(session_id),
    
    -- Index for fast session lookup
    INDEX idx_cart_items_session (session_id)
);

-- ----------------------------------------------------------------------------
-- Fulfillment options (HYBRID TABLE)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE HYBRID TABLE FULFILLMENT_OPTIONS (
    option_id VARCHAR(36) PRIMARY KEY,
    
    -- Option info
    name VARCHAR(100) NOT NULL,        -- Standard Shipping, Express, Next Day, Store Pickup
    description VARCHAR(255),
    fulfillment_type VARCHAR(20) NOT NULL,  -- shipping, pickup
    
    -- Pricing (in cents)
    price_cents INTEGER NOT NULL,
    free_threshold_cents INTEGER,      -- Free if order exceeds this
    
    -- Timing
    estimated_days_min INTEGER,
    estimated_days_max INTEGER,
    
    -- Carrier
    carrier VARCHAR(50),               -- UPS, FedEx, USPS, etc.
    
    -- Availability
    is_available BOOLEAN DEFAULT TRUE,
    available_countries VARCHAR(500),  -- Comma-separated (HYBRID limitation)
    
    -- Display
    display_order INTEGER DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    
    -- Index for availability lookup
    INDEX idx_fulfillment_available (is_available, fulfillment_type)
);

-- ----------------------------------------------------------------------------
-- Payment methods (HYBRID TABLE)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE HYBRID TABLE PAYMENT_METHODS (
    payment_method_id VARCHAR(36) PRIMARY KEY,
    customer_id VARCHAR(36) NOT NULL,
    
    -- Payment type
    payment_type VARCHAR(30) NOT NULL, -- card, paypal, apple_pay, google_pay, klarna
    
    -- Tokenized data (never store raw card data)
    token VARCHAR(255) NOT NULL,       -- PSP token
    
    -- Display info
    display_name VARCHAR(100),         -- "Visa ****4242"
    card_brand VARCHAR(20),            -- visa, mastercard, amex, discover
    card_last_four VARCHAR(4),
    
    -- Expiration
    expires_month INTEGER,
    expires_year INTEGER,
    
    -- Status
    is_default BOOLEAN DEFAULT FALSE,
    is_verified BOOLEAN DEFAULT FALSE,
    
    -- Billing address
    billing_address VARCHAR(2000),     -- JSON as string (HYBRID limitation)
    
    -- Metadata
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    last_used_at TIMESTAMP_NTZ,
    
    -- Index for customer lookup
    INDEX idx_payment_customer (customer_id)
);

-- ----------------------------------------------------------------------------
-- Payment transactions (HYBRID TABLE)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE HYBRID TABLE PAYMENT_TRANSACTIONS (
    transaction_id VARCHAR(36) PRIMARY KEY,
    session_id VARCHAR(36) NOT NULL,
    payment_method_id VARCHAR(36),
    
    -- Amount
    amount_cents INTEGER NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    
    -- Status
    status VARCHAR(30) NOT NULL,       -- pending, authorized, captured, failed, refunded, voided
    
    -- PSP reference
    psp_name VARCHAR(50),              -- stripe, braintree, adyen
    psp_transaction_id VARCHAR(255),
    psp_response VARCHAR(4000),        -- JSON as string (HYBRID limitation)
    
    -- Failure info
    failure_code VARCHAR(50),
    failure_message VARCHAR(500),
    
    -- Metadata
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ,
    
    -- Foreign key to cart session
    FOREIGN KEY (session_id) REFERENCES CART_SESSIONS(session_id),
    
    -- Index for session lookup
    INDEX idx_payment_session (session_id)
);

-- ----------------------------------------------------------------------------
-- Orders (HYBRID TABLE - created after successful checkout)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE HYBRID TABLE ORDERS (
    order_id VARCHAR(36) PRIMARY KEY,
    order_number VARCHAR(20) NOT NULL, -- Human-readable order number
    session_id VARCHAR(36),
    customer_id VARCHAR(36),
    
    -- Status
    status VARCHAR(30) NOT NULL DEFAULT 'pending',
    -- pending, confirmed, processing, shipped, delivered, cancelled, returned
    
    -- Amounts (in cents)
    subtotal_cents INTEGER NOT NULL,
    tax_cents INTEGER NOT NULL,
    shipping_cents INTEGER NOT NULL,
    discount_cents INTEGER DEFAULT 0,
    total_cents INTEGER NOT NULL,
    currency VARCHAR(3) DEFAULT 'USD',
    
    -- Shipping
    shipping_address VARCHAR(2000),    -- JSON as string
    shipping_method VARCHAR(100),
    tracking_number VARCHAR(100),
    tracking_url VARCHAR(500),
    
    -- Dates
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    confirmed_at TIMESTAMP_NTZ,
    shipped_at TIMESTAMP_NTZ,
    delivered_at TIMESTAMP_NTZ,
    cancelled_at TIMESTAMP_NTZ,
    
    -- Foreign key to cart session
    FOREIGN KEY (session_id) REFERENCES CART_SESSIONS(session_id),
    
    -- Indexes
    INDEX idx_order_customer (customer_id),
    INDEX idx_order_status (status),
    INDEX idx_order_number (order_number)
);

-- ----------------------------------------------------------------------------
-- Order items (HYBRID TABLE - snapshot of cart items at order time)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE HYBRID TABLE ORDER_ITEMS (
    order_item_id VARCHAR(36) PRIMARY KEY,
    order_id VARCHAR(36) NOT NULL,
    product_id VARCHAR(36) NOT NULL,
    variant_id VARCHAR(36),
    
    -- Quantity
    quantity INTEGER NOT NULL,
    
    -- Pricing snapshot (at time of order)
    unit_price_cents INTEGER NOT NULL,
    subtotal_cents INTEGER NOT NULL,
    
    -- Product snapshot
    product_name VARCHAR(255),
    variant_name VARCHAR(100),
    product_image_url VARCHAR(1000),
    
    -- Metadata
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    
    -- Foreign key to order
    FOREIGN KEY (order_id) REFERENCES ORDERS(order_id),
    
    -- Index for order lookup
    INDEX idx_order_items_order (order_id)
);

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Confirm current role
SELECT CURRENT_ROLE() AS current_role;

-- Show all tables in each schema
SHOW TABLES IN SCHEMA AGENT_COMMERCE.CUSTOMERS;
SHOW TABLES IN SCHEMA AGENT_COMMERCE.PRODUCTS;
SHOW TABLES IN SCHEMA AGENT_COMMERCE.INVENTORY;
SHOW TABLES IN SCHEMA AGENT_COMMERCE.SOCIAL;

-- Show hybrid tables in CART_OLTP schema
SHOW HYBRID TABLES IN SCHEMA AGENT_COMMERCE.CART_OLTP;

-- Count tables per schema
SELECT 
    TABLE_SCHEMA,
    COUNT(*) AS table_count
FROM AGENT_COMMERCE.INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
  AND TABLE_SCHEMA NOT IN ('INFORMATION_SCHEMA')
GROUP BY TABLE_SCHEMA
ORDER BY TABLE_SCHEMA;

-- ============================================================================
-- NEXT STEPS:
-- 1. Run sql/03_create_cortex_services.sql for Vector Search and Cortex Search
-- 2. Run sql/04_create_semantic_views.sql for Cortex Analyst
-- ============================================================================

