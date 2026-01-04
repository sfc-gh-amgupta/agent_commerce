-- OpenAI Commerce Feed - Database Schema
-- Based on specification: https://developers.openai.com/commerce/specs/feed
-- Created: 2025-11-26

-- Drop table if exists (for fresh setup)
-- DROP TABLE IF EXISTS openai_commerce_products;

-- Main Product Feed Table
CREATE TABLE openai_commerce_products (
    -- Primary Key
    product_key VARCHAR(100) PRIMARY KEY,
    
    -- Core Product Identifiers (REQUIRED)
    id VARCHAR(100) NOT NULL,                    -- Unique merchant product ID
    gtin VARCHAR(14),                            -- Universal product identifier (RECOMMENDED)
    mpn VARCHAR(70),                             -- Manufacturer part number (REQUIRED if gtin missing)
    
    -- Product Information (REQUIRED)
    title VARCHAR(150) NOT NULL,                 -- Product title
    description TEXT NOT NULL,                   -- Full product description (max 5000 chars)
    link VARCHAR(2048) NOT NULL,                 -- Product detail page URL
    image_link VARCHAR(2048) NOT NULL,           -- Main product image URL
    brand VARCHAR(70) NOT NULL,                  -- Product brand
    product_category VARCHAR(500) NOT NULL,      -- Category path with ">" separator
    material VARCHAR(100) NOT NULL,              -- Primary material(s)
    weight VARCHAR(50) NOT NULL,                 -- Product weight with unit
    
    -- Product State (REQUIRED)
    availability VARCHAR(20) NOT NULL            -- in_stock, out_of_stock, preorder
        CHECK (availability IN ('in_stock', 'out_of_stock', 'preorder')),
    condition VARCHAR(20) DEFAULT 'new'          -- new, refurbished, used
        CHECK (condition IN ('new', 'refurbished', 'used')),
    
    -- Pricing (REQUIRED)
    price DECIMAL(10,2) NOT NULL,                -- Regular price
    price_currency VARCHAR(3) NOT NULL DEFAULT 'USD', -- ISO 4217 currency code
    sale_price DECIMAL(10,2),                    -- Discounted price (OPTIONAL)
    sale_price_currency VARCHAR(3),              -- Sale price currency
    sale_price_effective_start DATE,             -- Sale start date
    sale_price_effective_end DATE,               -- Sale end date
    
    -- ChatGPT Integration Controls (REQUIRED)
    enable_search BOOLEAN NOT NULL DEFAULT true,  -- Controls search surfacing
    enable_checkout BOOLEAN NOT NULL DEFAULT true,-- Allows direct purchase
    
    -- Additional Media (OPTIONAL)
    additional_image_links TEXT,                 -- Comma-separated image URLs
    video_link VARCHAR(2048),                    -- Product video URL
    model_3d_link VARCHAR(2048),                 -- 3D model URL (GLB/GLTF)
    
    -- Shipping & Delivery (CONDITIONAL/OPTIONAL)
    shipping VARCHAR(500),                       -- Format: country:region:method:cost
    delivery_estimate DATE,                      -- Estimated arrival date
    
    -- Seller Information (REQUIRED)
    seller_name VARCHAR(70) NOT NULL,            -- Seller name
    seller_url VARCHAR(2048) NOT NULL,           -- Seller page URL
    return_policy VARCHAR(2048) NOT NULL,        -- Return policy URL
    return_window INTEGER NOT NULL,              -- Days allowed for return
    
    -- Product Metrics (RECOMMENDED)
    popularity_score DECIMAL(3,2),               -- 0-5 scale
    return_rate DECIMAL(5,2),                    -- 0-100% return rate
    product_review_count INTEGER,                -- Number of reviews
    product_review_rating DECIMAL(3,2),          -- 0-5 scale average rating
    
    -- Compliance & Warnings (RECOMMENDED)
    warning TEXT,                                -- Product disclaimers
    warning_url VARCHAR(2048),                   -- Warning details URL
    age_restriction INTEGER,                     -- Minimum purchase age
    
    -- Product Relationships (RECOMMENDED)
    related_product_ids TEXT,                    -- Comma-separated product IDs
    relationship_type VARCHAR(30)                -- Type of relationship
        CHECK (relationship_type IN (
            'part_of_set', 'required_part', 'often_bought_with', 
            'substitute', 'different_brand', 'accessory'
        )),
    
    -- Geographic Pricing & Availability (RECOMMENDED)
    geo_price TEXT,                              -- Region-specific pricing
    geo_availability TEXT,                       -- Region-specific availability
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_synced_at TIMESTAMP,
    
    -- Constraints
    CONSTRAINT chk_sale_price CHECK (sale_price IS NULL OR sale_price <= price),
    CONSTRAINT chk_sale_dates CHECK (
        sale_price_effective_start IS NULL OR 
        sale_price_effective_end IS NULL OR 
        sale_price_effective_start < sale_price_effective_end
    ),
    CONSTRAINT chk_gtin_or_mpn CHECK (gtin IS NOT NULL OR mpn IS NOT NULL),
    CONSTRAINT chk_return_window CHECK (return_window > 0),
    CONSTRAINT chk_age_restriction CHECK (age_restriction IS NULL OR age_restriction > 0)
);

-- Indexes for performance optimization
CREATE INDEX idx_product_id ON openai_commerce_products(id);
CREATE INDEX idx_brand ON openai_commerce_products(brand);
CREATE INDEX idx_availability ON openai_commerce_products(availability);
CREATE INDEX idx_price ON openai_commerce_products(price);
CREATE INDEX idx_enable_search ON openai_commerce_products(enable_search);
CREATE INDEX idx_enable_checkout ON openai_commerce_products(enable_checkout);
CREATE INDEX idx_category ON openai_commerce_products(product_category);
CREATE INDEX idx_updated_at ON openai_commerce_products(updated_at);

-- View for active, searchable products
CREATE VIEW vw_active_products AS
SELECT 
    id,
    title,
    description,
    brand,
    price,
    price_currency,
    sale_price,
    availability,
    image_link,
    link,
    product_review_rating,
    product_review_count
FROM openai_commerce_products
WHERE 
    enable_search = true
    AND availability = 'in_stock';

-- View for checkout-enabled products
CREATE VIEW vw_checkout_enabled_products AS
SELECT 
    id,
    title,
    brand,
    price,
    price_currency,
    sale_price,
    availability,
    image_link,
    link,
    seller_name,
    return_policy,
    return_window
FROM openai_commerce_products
WHERE 
    enable_checkout = true
    AND availability IN ('in_stock', 'preorder');

-- Comments on important fields
COMMENT ON COLUMN openai_commerce_products.id IS 'Unique merchant product ID - must remain stable over time';
COMMENT ON COLUMN openai_commerce_products.gtin IS 'GTIN/UPC/ISBN - 8-14 digits, no dashes or spaces';
COMMENT ON COLUMN openai_commerce_products.enable_search IS 'Controls whether product can be surfaced in ChatGPT search results';
COMMENT ON COLUMN openai_commerce_products.enable_checkout IS 'Allows direct purchase inside ChatGPT';
COMMENT ON COLUMN openai_commerce_products.shipping IS 'Format: country:region:method:cost (e.g., US:CA:Overnight:16.00 USD)';

-- Sample insert statement (for reference)
/*
INSERT INTO openai_commerce_products (
    product_key, id, title, description, link, image_link, 
    price, price_currency, availability, brand, product_category, 
    material, weight, enable_search, enable_checkout,
    seller_name, seller_url, return_policy, return_window
) VALUES (
    'PROD001', 'SKU12345', 'Men''s Trail Running Shoes Black',
    'Waterproof trail shoe with cushioned sole for maximum comfort and durability',
    'https://example.com/product/SKU12345',
    'https://example.com/images/SKU12345.jpg',
    79.99, 'USD', 'in_stock', 'OpenAI',
    'Apparel & Accessories > Shoes > Athletic Shoes',
    'Synthetic, Rubber', '1.5 lb', true, true,
    'Example Store', 'https://example.com/store',
    'https://example.com/returns', 30
);
*/


