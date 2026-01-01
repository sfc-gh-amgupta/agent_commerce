-- ============================================================================
-- AGENT COMMERCE - Semantic Views for Cortex Analyst
-- ============================================================================
-- This script creates Semantic Views that enable Cortex Analyst to convert
-- natural language queries into SQL.
--
-- Syntax per: https://docs.snowflake.com/sql-reference/sql/create-semantic-view
-- Note: Order matters - FACTS must come before DIMENSIONS, DIMENSIONS before METRICS
--
-- Run after 02_create_tables.sql
-- ============================================================================

USE ROLE AGENT_COMMERCE_ROLE;
USE DATABASE AGENT_COMMERCE;
USE WAREHOUSE AGENT_COMMERCE_WH;

-- ============================================================================
-- CUSTOMERS SCHEMA - Customer Semantic View
-- ============================================================================
USE SCHEMA CUSTOMERS;

CREATE OR REPLACE SEMANTIC VIEW CUSTOMER_SEMANTIC_VIEW
  TABLES (
    -- Core customer table
    customer AS CUSTOMERS
      PRIMARY KEY (customer_id)
      WITH SYNONYMS = ('customers', 'users', 'members', 'shoppers', 'buyers')
      COMMENT = 'Customer profiles with loyalty and skin profile information',
    
    -- Skin analysis history
    analysis AS SKIN_ANALYSIS_HISTORY
      PRIMARY KEY (analysis_id)
      WITH SYNONYMS = ('skin analysis', 'color analysis', 'beauty analysis', 'face analysis')
      COMMENT = 'History of skin tone and color analysis sessions'
  )
  
  RELATIONSHIPS (
    -- Customer has many skin analyses
    analysis(customer_id) REFERENCES customer(customer_id)
  )
  
  -- FACTS come before DIMENSIONS (required order)
  FACTS (
    customer.points_balance AS customer.points_balance
      WITH SYNONYMS = ('loyalty points', 'rewards points', 'points')
      COMMENT = 'Current loyalty points balance',
    customer.lifetime_points AS customer.lifetime_points
      COMMENT = 'Total points earned over lifetime',
    analysis.confidence_score AS analysis.confidence_score
      COMMENT = 'Confidence score of the analysis (0-1)'
  )
  
  DIMENSIONS (
    -- Customer dimensions
    customer.customer_id AS customer.customer_id
      COMMENT = 'Unique customer identifier',
    customer.email AS customer.email
      COMMENT = 'Customer email address',
    customer.first_name AS customer.first_name
      COMMENT = 'Customer first name',
    customer.last_name AS customer.last_name
      COMMENT = 'Customer last name',
    customer.loyalty_tier AS customer.loyalty_tier
      WITH SYNONYMS = ('tier', 'membership level', 'status')
      COMMENT = 'Loyalty program tier: Bronze, Silver, Gold, Platinum',
    customer.is_active AS customer.is_active
      COMMENT = 'Whether customer account is active',
    customer.created_at AS customer.created_at
      COMMENT = 'Date customer joined',
    
    -- Analysis dimensions
    analysis.analysis_id AS analysis.analysis_id
      COMMENT = 'Unique analysis session ID',
    analysis.customer_id AS analysis.customer_id
      COMMENT = 'Customer who was analyzed',
    analysis.skin_hex AS analysis.skin_hex
      WITH SYNONYMS = ('skin tone', 'skin shade', 'complexion', 'skin color')
      COMMENT = 'Detected skin color in hex format',
    analysis.undertone AS analysis.undertone
      WITH SYNONYMS = ('skin undertone', 'warm', 'cool', 'neutral')
      COMMENT = 'Skin undertone: warm, cool, or neutral',
    analysis.fitzpatrick_type AS analysis.fitzpatrick_type
      WITH SYNONYMS = ('fitzpatrick scale', 'fitzpatrick', 'skin type number')
      COMMENT = 'Fitzpatrick skin type (1-6)',
    analysis.monk_shade AS analysis.monk_shade
      WITH SYNONYMS = ('monk skin tone', 'monk scale', 'mst')
      COMMENT = 'Monk Skin Tone scale (1-10)',
    analysis.makeup_detected AS analysis.makeup_detected
      COMMENT = 'Whether makeup was detected during analysis',
    analysis.analyzed_at AS analysis.analyzed_at
      COMMENT = 'When the analysis was performed'
  )
  
  METRICS (
    -- Count of customers
    customer.customer_count AS COUNT(DISTINCT customer.customer_id)
      COMMENT = 'Number of customers',
    -- Average points
    customer.avg_points AS AVG(customer.points_balance)
      COMMENT = 'Average loyalty points balance',
    -- Total points
    customer.total_points AS SUM(customer.points_balance)
      COMMENT = 'Total loyalty points across customers',
    -- Count of analyses
    analysis.analysis_count AS COUNT(DISTINCT analysis.analysis_id)
      COMMENT = 'Number of skin analyses performed'
  )
  
  COMMENT = 'Semantic view for customer data, loyalty, and skin analysis';

-- ============================================================================
-- PRODUCTS SCHEMA - Products Semantic View
-- ============================================================================
USE SCHEMA PRODUCTS;

CREATE OR REPLACE SEMANTIC VIEW PRODUCT_SEMANTIC_VIEW
  TABLES (
    product AS PRODUCTS
      PRIMARY KEY (product_id)
      WITH SYNONYMS = ('products', 'items', 'cosmetics', 'beauty products', 'makeup')
      COMMENT = 'Core product catalog',
    
    variant AS PRODUCT_VARIANTS
      PRIMARY KEY (variant_id)
      WITH SYNONYMS = ('variants', 'shades', 'colors', 'sizes', 'options')
      COMMENT = 'Product variants (shades, sizes)',
    
    price_hist AS PRICE_HISTORY
      PRIMARY KEY (history_id)
      WITH SYNONYMS = ('price changes', 'price trends', 'pricing history')
      COMMENT = 'Historical price changes',
    
    promo AS PROMOTIONS
      PRIMARY KEY (promotion_id)
      WITH SYNONYMS = ('promotions', 'deals', 'sales', 'discounts', 'offers', 'coupons')
      COMMENT = 'Active and past promotions'
  )
  
  RELATIONSHIPS (
    variant(product_id) REFERENCES product(product_id),
    price_hist(product_id) REFERENCES product(product_id)
  )
  
  FACTS (
    -- Product pricing facts
    product.base_price AS product.base_price
      WITH SYNONYMS = ('regular price', 'original price', 'msrp')
      COMMENT = 'Base/regular price',
    product.current_price AS product.current_price
      WITH SYNONYMS = ('price', 'sale price', 'cost')
      COMMENT = 'Current selling price',
    product.spf_value AS product.spf_value
      COMMENT = 'SPF value if applicable',
    
    -- Variant pricing
    variant.price_modifier AS variant.price_modifier
      COMMENT = 'Price adjustment for variant',
    
    -- Promotion values
    promo.discount_value AS promo.discount_value
      WITH SYNONYMS = ('discount', 'savings', 'off')
      COMMENT = 'Discount value (percentage or fixed amount)',
    promo.min_purchase_amount AS promo.min_purchase_amount
      COMMENT = 'Minimum purchase required for promotion',
    
    -- Price history
    price_hist.price AS price_hist.price
      COMMENT = 'Price at a point in time',
    price_hist.previous_price AS price_hist.previous_price
      COMMENT = 'Previous price before change'
  )
  
  DIMENSIONS (
    -- Product dimensions
    product.product_id AS product.product_id
      COMMENT = 'Unique product identifier',
    product.sku AS product.sku
      COMMENT = 'Stock keeping unit',
    product.name AS product.name
      WITH SYNONYMS = ('product name', 'title', 'product')
      COMMENT = 'Product name',
    product.brand AS product.brand
      WITH SYNONYMS = ('brand name', 'manufacturer', 'company')
      COMMENT = 'Brand name',
    product.category AS product.category
      WITH SYNONYMS = ('type', 'product type', 'product category')
      COMMENT = 'Product category: foundation, lipstick, blush, etc.',
    product.subcategory AS product.subcategory
      COMMENT = 'Product subcategory: liquid, powder, cream',
    product.color_name AS product.color_name
      WITH SYNONYMS = ('shade name', 'color', 'shade')
      COMMENT = 'Color/shade name',
    product.color_hex AS product.color_hex
      COMMENT = 'Color in hex format',
    product.finish AS product.finish
      WITH SYNONYMS = ('texture', 'formula')
      COMMENT = 'Product finish: matte, satin, glossy, shimmer',
    product.is_vegan AS product.is_vegan
      COMMENT = 'Whether product is vegan',
    product.is_cruelty_free AS product.is_cruelty_free
      COMMENT = 'Whether product is cruelty-free',
    product.is_active AS product.is_active
      WITH SYNONYMS = ('available', 'in stock')
      COMMENT = 'Whether product is currently available',
    product.is_featured AS product.is_featured
      COMMENT = 'Whether product is featured',
    product.launch_date AS product.launch_date
      COMMENT = 'Product launch date',
    
    -- Variant dimensions
    variant.variant_id AS variant.variant_id
      COMMENT = 'Unique variant identifier',
    variant.product_id AS variant.product_id
      COMMENT = 'Parent product ID',
    variant.shade_name AS variant.shade_name
      COMMENT = 'Shade name for this variant',
    variant.shade_code AS variant.shade_code
      COMMENT = 'Shade code',
    variant.size AS variant.size
      COMMENT = 'Product size',
    variant.is_available AS variant.is_available
      COMMENT = 'Whether variant is in stock',
    
    -- Promotion dimensions
    promo.promotion_id AS promo.promotion_id
      COMMENT = 'Unique promotion identifier',
    promo.name AS promo.name
      WITH SYNONYMS = ('deal name', 'offer name', 'sale name', 'promo name')
      COMMENT = 'Promotion name',
    promo.promo_code AS promo.promo_code
      WITH SYNONYMS = ('coupon code', 'discount code', 'code')
      COMMENT = 'Promotional code to apply',
    promo.discount_type AS promo.discount_type
      COMMENT = 'Type: percentage, fixed, bogo, free_shipping',
    promo.is_active AS promo.is_active
      COMMENT = 'Whether promotion is currently active',
    promo.start_date AS promo.start_date
      COMMENT = 'Promotion start date',
    promo.end_date AS promo.end_date
      COMMENT = 'Promotion end date',
    
    -- Price history dimensions
    price_hist.history_id AS price_hist.history_id
      COMMENT = 'Unique price history ID',
    price_hist.product_id AS price_hist.product_id
      COMMENT = 'Product ID',
    price_hist.effective_date AS price_hist.effective_date
      COMMENT = 'Date price became effective',
    price_hist.change_reason AS price_hist.change_reason
      COMMENT = 'Reason for price change'
  )
  
  METRICS (
    product.product_count AS COUNT(DISTINCT product.product_id)
      COMMENT = 'Number of products',
    product.avg_price AS AVG(product.current_price)
      WITH SYNONYMS = ('average price')
      COMMENT = 'Average product price',
    product.min_price AS MIN(product.current_price)
      WITH SYNONYMS = ('lowest price', 'cheapest')
      COMMENT = 'Minimum product price',
    product.max_price AS MAX(product.current_price)
      WITH SYNONYMS = ('highest price', 'most expensive')
      COMMENT = 'Maximum product price',
    variant.variant_count AS COUNT(DISTINCT variant.variant_id)
      COMMENT = 'Number of variants',
    promo.active_promos AS COUNT(DISTINCT CASE WHEN promo.is_active THEN promo.promotion_id END)
      COMMENT = 'Number of active promotions'
  )
  
  COMMENT = 'Semantic view for product catalog, variants, pricing, and promotions';

-- ============================================================================
-- INVENTORY SCHEMA - Inventory Semantic View
-- ============================================================================
USE SCHEMA INVENTORY;

CREATE OR REPLACE SEMANTIC VIEW INVENTORY_SEMANTIC_VIEW
  TABLES (
    location AS LOCATIONS
      PRIMARY KEY (location_id)
      WITH SYNONYMS = ('locations', 'stores', 'warehouses', 'shops')
      COMMENT = 'Physical store and warehouse locations',
    
    stock AS STOCK_LEVELS
      PRIMARY KEY (stock_id)
      WITH SYNONYMS = ('inventory', 'stock', 'availability', 'quantities')
      COMMENT = 'Current stock levels by location'
  )
  
  RELATIONSHIPS (
    stock(location_id) REFERENCES location(location_id)
  )
  
  FACTS (
    stock.quantity_on_hand AS stock.quantity_on_hand
      WITH SYNONYMS = ('on hand', 'available', 'in stock', 'qty')
      COMMENT = 'Total quantity on hand',
    stock.quantity_reserved AS stock.quantity_reserved
      WITH SYNONYMS = ('reserved', 'held', 'allocated')
      COMMENT = 'Quantity reserved for orders',
    stock.reorder_point AS stock.reorder_point
      COMMENT = 'Quantity threshold to trigger reorder',
    stock.reorder_quantity AS stock.reorder_quantity
      COMMENT = 'Standard reorder quantity',
    location.latitude AS location.latitude
      COMMENT = 'Location latitude',
    location.longitude AS location.longitude
      COMMENT = 'Location longitude'
  )
  
  DIMENSIONS (
    -- Location dimensions
    location.location_id AS location.location_id
      COMMENT = 'Unique location identifier',
    location.name AS location.name
      WITH SYNONYMS = ('store name', 'warehouse name', 'location name')
      COMMENT = 'Location name',
    location.location_type AS location.location_type
      WITH SYNONYMS = ('type')
      COMMENT = 'Type: warehouse, store, popup',
    location.location_code AS location.location_code
      COMMENT = 'Location code',
    location.city AS location.city
      COMMENT = 'City',
    location.state AS location.state
      COMMENT = 'State/Province',
    location.postal_code AS location.postal_code
      WITH SYNONYMS = ('zip', 'zip code')
      COMMENT = 'Postal/ZIP code',
    location.country AS location.country
      COMMENT = 'Country code',
    location.is_active AS location.is_active
      COMMENT = 'Whether location is active',
    location.is_pickup_enabled AS location.is_pickup_enabled
      WITH SYNONYMS = ('bopis', 'buy online pickup in store', 'curbside', 'pickup available')
      COMMENT = 'Whether pickup is available',
    
    -- Stock dimensions
    stock.stock_id AS stock.stock_id
      COMMENT = 'Unique stock record identifier',
    stock.product_id AS stock.product_id
      COMMENT = 'Product identifier',
    stock.variant_id AS stock.variant_id
      COMMENT = 'Variant identifier',
    stock.location_id AS stock.location_id
      COMMENT = 'Location identifier',
    stock.last_restock_date AS stock.last_restock_date
      COMMENT = 'Date of last restock'
  )
  
  METRICS (
    stock.total_on_hand AS SUM(stock.quantity_on_hand)
      COMMENT = 'Total quantity on hand across locations',
    stock.total_reserved AS SUM(stock.quantity_reserved)
      COMMENT = 'Total quantity reserved',
    stock.total_available AS SUM(stock.quantity_on_hand - stock.quantity_reserved)
      WITH SYNONYMS = ('available inventory', 'sellable inventory')
      COMMENT = 'Total available inventory (on hand minus reserved)',
    location.location_count AS COUNT(DISTINCT location.location_id)
      COMMENT = 'Number of locations',
    stock.low_stock_count AS COUNT(DISTINCT CASE WHEN stock.quantity_on_hand <= stock.reorder_point THEN stock.stock_id END)
      COMMENT = 'Number of products at or below reorder point'
  )
  
  COMMENT = 'Semantic view for inventory levels and store locations';

-- ============================================================================
-- SOCIAL SCHEMA - Social Proof Semantic View
-- ============================================================================
USE SCHEMA SOCIAL;

CREATE OR REPLACE SEMANTIC VIEW SOCIAL_PROOF_SEMANTIC_VIEW
  TABLES (
    review AS PRODUCT_REVIEWS
      PRIMARY KEY (review_id)
      WITH SYNONYMS = ('reviews', 'ratings', 'feedback', 'customer reviews')
      COMMENT = 'Customer product reviews',
    
    mention AS SOCIAL_MENTIONS
      PRIMARY KEY (mention_id)
      WITH SYNONYMS = ('social posts', 'mentions', 'social media', 'posts')
      COMMENT = 'Social media mentions of products',
    
    influencer AS INFLUENCER_MENTIONS
      PRIMARY KEY (mention_id)
      WITH SYNONYMS = ('influencer posts', 'influencer reviews', 'creator content', 'influencers')
      COMMENT = 'Influencer product mentions and reviews',
    
    trending AS TRENDING_PRODUCTS
      PRIMARY KEY (trend_id)
      WITH SYNONYMS = ('trending', 'viral', 'popular', 'hot products')
      COMMENT = 'Currently trending products'
  )
  
  FACTS (
    -- Review facts
    review.rating AS review.rating
      WITH SYNONYMS = ('stars', 'score', 'review rating')
      COMMENT = 'Star rating (1-5)',
    review.helpful_votes AS review.helpful_votes
      COMMENT = 'Number of helpful votes',
    
    -- Social mention facts
    mention.likes AS mention.likes
      COMMENT = 'Number of likes',
    mention.comments AS mention.comments
      COMMENT = 'Number of comments',
    mention.shares AS mention.shares
      COMMENT = 'Number of shares',
    mention.views AS mention.views
      COMMENT = 'Number of views',
    mention.sentiment_score AS mention.sentiment_score
      COMMENT = 'Sentiment score (-1 to 1)',
    mention.author_follower_count AS mention.author_follower_count
      COMMENT = 'Author follower count',
    
    -- Influencer facts
    influencer.likes AS influencer.likes
      COMMENT = 'Content likes',
    influencer.comments AS influencer.comments
      COMMENT = 'Content comments',
    influencer.views AS influencer.views
      COMMENT = 'Content views',
    influencer.follower_count AS influencer.follower_count
      COMMENT = 'Influencer follower count',
    influencer.engagement_rate AS influencer.engagement_rate
      COMMENT = 'Engagement rate',
    
    -- Trending facts
    trending.trend_rank AS trending.trend_rank
      COMMENT = 'Position in trending list',
    trending.trend_score AS trending.trend_score
      COMMENT = 'Calculated trend score',
    trending.mention_velocity AS trending.mention_velocity
      COMMENT = 'Mentions per hour'
  )
  
  DIMENSIONS (
    -- Review dimensions
    review.review_id AS review.review_id
      COMMENT = 'Unique review identifier',
    review.product_id AS review.product_id
      COMMENT = 'Product being reviewed',
    review.platform AS review.platform
      COMMENT = 'Platform: website, app, bazaarvoice',
    review.title AS review.title
      COMMENT = 'Review title',
    review.review_text AS review.review_text
      WITH SYNONYMS = ('review', 'comment', 'feedback text')
      COMMENT = 'Full review text',
    review.verified_purchase AS review.verified_purchase
      COMMENT = 'Whether reviewer is verified buyer',
    review.reviewer_skin_tone AS review.reviewer_skin_tone
      COMMENT = 'Reviewer skin tone',
    review.reviewer_skin_type AS review.reviewer_skin_type
      COMMENT = 'Reviewer skin type',
    review.reviewer_undertone AS review.reviewer_undertone
      COMMENT = 'Reviewer undertone',
    review.created_at AS review.created_at
      COMMENT = 'When review was posted',
    
    -- Social mention dimensions
    mention.mention_id AS mention.mention_id
      COMMENT = 'Unique mention identifier',
    mention.product_id AS mention.product_id
      COMMENT = 'Product mentioned',
    mention.platform AS mention.platform
      WITH SYNONYMS = ('social network', 'channel')
      COMMENT = 'Platform: instagram, tiktok, youtube, twitter',
    mention.post_url AS mention.post_url
      COMMENT = 'Link to original post',
    mention.content_text AS mention.content_text
      COMMENT = 'Post content',
    mention.author_handle AS mention.author_handle
      WITH SYNONYMS = ('username', 'handle', 'poster', 'author')
      COMMENT = 'Author social handle',
    mention.sentiment_label AS mention.sentiment_label
      WITH SYNONYMS = ('sentiment', 'mood', 'tone')
      COMMENT = 'Sentiment: positive, neutral, negative',
    mention.posted_at AS mention.posted_at
      COMMENT = 'When post was made',
    
    -- Influencer dimensions
    influencer.mention_id AS influencer.mention_id
      COMMENT = 'Unique influencer mention ID',
    influencer.product_id AS influencer.product_id
      COMMENT = 'Product featured',
    influencer.influencer_handle AS influencer.influencer_handle
      WITH SYNONYMS = ('influencer', 'creator', 'blogger')
      COMMENT = 'Influencer social handle',
    influencer.influencer_name AS influencer.influencer_name
      COMMENT = 'Influencer display name',
    influencer.platform AS influencer.platform
      COMMENT = 'Platform',
    influencer.content_type AS influencer.content_type
      COMMENT = 'Type: post, story, reel, video',
    influencer.post_url AS influencer.post_url
      COMMENT = 'Link to content',
    influencer.influencer_skin_tone AS influencer.influencer_skin_tone
      COMMENT = 'Influencer skin tone',
    influencer.is_sponsored AS influencer.is_sponsored
      WITH SYNONYMS = ('ad', 'paid', 'partnership', 'sponsored')
      COMMENT = 'Whether content is sponsored',
    influencer.posted_at AS influencer.posted_at
      COMMENT = 'When content was posted',
    
    -- Trending dimensions
    trending.trend_id AS trending.trend_id
      COMMENT = 'Unique trend record ID',
    trending.product_id AS trending.product_id
      COMMENT = 'Trending product',
    trending.is_viral AS trending.is_viral
      COMMENT = 'Whether product is currently viral',
    trending.viral_reason AS trending.viral_reason
      COMMENT = 'Reason for virality'
  )
  
  METRICS (
    review.review_count AS COUNT(DISTINCT review.review_id)
      COMMENT = 'Number of reviews',
    review.avg_rating AS AVG(review.rating)
      WITH SYNONYMS = ('average rating', 'average stars')
      COMMENT = 'Average review rating',
    mention.mention_count AS COUNT(DISTINCT mention.mention_id)
      COMMENT = 'Number of social mentions',
    mention.total_engagement AS SUM(mention.likes + mention.comments + mention.shares)
      COMMENT = 'Total social engagement',
    influencer.influencer_mention_count AS COUNT(DISTINCT influencer.mention_id)
      COMMENT = 'Number of influencer mentions',
    trending.viral_product_count AS COUNT(DISTINCT CASE WHEN trending.is_viral THEN trending.product_id END)
      COMMENT = 'Number of currently viral products'
  )
  
  COMMENT = 'Semantic view for reviews, social mentions, and influencer content';

-- ============================================================================
-- CART_OLTP SCHEMA - Cart & Orders Semantic View (Hybrid Tables)
-- ============================================================================
USE SCHEMA CART_OLTP;

CREATE OR REPLACE SEMANTIC VIEW CART_SEMANTIC_VIEW
  TABLES (
    session AS CART_SESSIONS
      PRIMARY KEY (session_id)
      WITH SYNONYMS = ('checkout', 'cart', 'shopping cart', 'basket')
      COMMENT = 'Cart/checkout sessions (Hybrid Table)',
    
    item AS CART_ITEMS
      PRIMARY KEY (item_id)
      WITH SYNONYMS = ('cart items', 'line items', 'items', 'products in cart')
      COMMENT = 'Items in cart session (Hybrid Table)',
    
    order_tbl AS ORDERS
      PRIMARY KEY (order_id)
      WITH SYNONYMS = ('orders', 'purchases', 'transactions')
      COMMENT = 'Completed orders (Hybrid Table)',
    
    order_item AS ORDER_ITEMS
      PRIMARY KEY (order_item_id)
      WITH SYNONYMS = ('order items', 'purchased items')
      COMMENT = 'Items in completed order (Hybrid Table)',
    
    fulfillment AS FULFILLMENT_OPTIONS
      PRIMARY KEY (option_id)
      WITH SYNONYMS = ('shipping options', 'delivery options', 'fulfillment')
      COMMENT = 'Available shipping/pickup options (Hybrid Table)'
  )
  
  RELATIONSHIPS (
    item(session_id) REFERENCES session(session_id),
    order_tbl(session_id) REFERENCES session(session_id),
    order_item(order_id) REFERENCES order_tbl(order_id)
  )
  
  FACTS (
    -- Session facts (amounts in cents)
    session.subtotal_cents AS session.subtotal_cents
      WITH SYNONYMS = ('subtotal', 'items total', 'cart subtotal')
      COMMENT = 'Cart subtotal in cents',
    session.tax_cents AS session.tax_cents
      COMMENT = 'Tax amount in cents',
    session.shipping_cents AS session.shipping_cents
      COMMENT = 'Shipping cost in cents',
    session.discount_cents AS session.discount_cents
      WITH SYNONYMS = ('discount', 'savings')
      COMMENT = 'Discount amount in cents',
    session.total_cents AS session.total_cents
      WITH SYNONYMS = ('total', 'grand total', 'cart total')
      COMMENT = 'Total amount in cents',
    session.applied_loyalty_points AS session.applied_loyalty_points
      COMMENT = 'Loyalty points applied',
    
    -- Line item facts
    item.quantity AS item.quantity
      WITH SYNONYMS = ('qty', 'count')
      COMMENT = 'Quantity of item',
    item.unit_price_cents AS item.unit_price_cents
      COMMENT = 'Price per unit in cents',
    item.subtotal_cents AS item.subtotal_cents
      COMMENT = 'Line item subtotal in cents',
    
    -- Order facts
    order_tbl.subtotal_cents AS order_tbl.subtotal_cents
      COMMENT = 'Order subtotal in cents',
    order_tbl.tax_cents AS order_tbl.tax_cents
      COMMENT = 'Order tax in cents',
    order_tbl.shipping_cents AS order_tbl.shipping_cents
      COMMENT = 'Order shipping in cents',
    order_tbl.discount_cents AS order_tbl.discount_cents
      COMMENT = 'Order discount in cents',
    order_tbl.total_cents AS order_tbl.total_cents
      COMMENT = 'Order total in cents',
    
    -- Fulfillment facts
    fulfillment.price_cents AS fulfillment.price_cents
      COMMENT = 'Shipping option price in cents',
    fulfillment.free_threshold_cents AS fulfillment.free_threshold_cents
      COMMENT = 'Minimum for free shipping in cents',
    fulfillment.estimated_days_min AS fulfillment.estimated_days_min
      COMMENT = 'Minimum delivery days',
    fulfillment.estimated_days_max AS fulfillment.estimated_days_max
      COMMENT = 'Maximum delivery days'
  )
  
  DIMENSIONS (
    -- Session dimensions
    session.session_id AS session.session_id
      COMMENT = 'Unique session identifier',
    session.customer_id AS session.customer_id
      COMMENT = 'Customer identifier',
    session.status AS session.status
      WITH SYNONYMS = ('cart status', 'checkout status')
      COMMENT = 'Status: active, pending_payment, completed, expired',
    session.currency AS session.currency
      COMMENT = 'Currency code',
    session.fulfillment_type AS session.fulfillment_type
      WITH SYNONYMS = ('delivery type', 'shipping type')
      COMMENT = 'Type: shipping or pickup',
    session.is_gift AS session.is_gift
      COMMENT = 'Whether order is a gift',
    session.is_valid AS session.is_valid
      COMMENT = 'Whether checkout is valid',
    session.created_at AS session.created_at
      COMMENT = 'When cart was created',
    session.completed_at AS session.completed_at
      COMMENT = 'When checkout completed',
    
    -- Cart item dimensions
    item.item_id AS item.item_id
      COMMENT = 'Unique cart item ID',
    item.session_id AS item.session_id
      COMMENT = 'Session this item belongs to',
    item.product_id AS item.product_id
      COMMENT = 'Product in cart',
    item.variant_id AS item.variant_id
      COMMENT = 'Variant in cart',
    item.product_name AS item.product_name
      COMMENT = 'Product name',
    item.variant_name AS item.variant_name
      COMMENT = 'Variant name',
    item.added_at AS item.added_at
      COMMENT = 'When item was added',
    
    -- Order dimensions
    order_tbl.order_id AS order_tbl.order_id
      COMMENT = 'Unique order identifier',
    order_tbl.order_number AS order_tbl.order_number
      WITH SYNONYMS = ('order number', 'confirmation number')
      COMMENT = 'Human-readable order number',
    order_tbl.session_id AS order_tbl.session_id
      COMMENT = 'Original checkout session',
    order_tbl.status AS order_tbl.status
      WITH SYNONYMS = ('order status', 'order state')
      COMMENT = 'Status: pending, confirmed, shipped, delivered',
    order_tbl.tracking_number AS order_tbl.tracking_number
      COMMENT = 'Shipment tracking number',
    order_tbl.created_at AS order_tbl.created_at
      COMMENT = 'When order was placed',
    order_tbl.shipped_at AS order_tbl.shipped_at
      COMMENT = 'When order shipped',
    order_tbl.delivered_at AS order_tbl.delivered_at
      COMMENT = 'When order was delivered',
    
    -- Order item dimensions
    order_item.order_item_id AS order_item.order_item_id
      COMMENT = 'Unique order item ID',
    order_item.order_id AS order_item.order_id
      COMMENT = 'Order this item belongs to',
    order_item.product_id AS order_item.product_id
      COMMENT = 'Product purchased',
    order_item.product_name AS order_item.product_name
      COMMENT = 'Product name at time of order',
    order_item.quantity AS order_item.quantity
      COMMENT = 'Quantity purchased',
    order_item.unit_price_cents AS order_item.unit_price_cents
      COMMENT = 'Unit price at time of order',
    order_item.subtotal_cents AS order_item.subtotal_cents
      COMMENT = 'Line subtotal at time of order',
    
    -- Fulfillment dimensions
    fulfillment.option_id AS fulfillment.option_id
      COMMENT = 'Unique option ID',
    fulfillment.name AS fulfillment.name
      WITH SYNONYMS = ('shipping option', 'shipping method', 'delivery method')
      COMMENT = 'Shipping option name',
    fulfillment.fulfillment_type AS fulfillment.fulfillment_type
      COMMENT = 'Type: shipping or pickup',
    fulfillment.carrier AS fulfillment.carrier
      COMMENT = 'Shipping carrier'
  )
  
  METRICS (
    session.cart_count AS COUNT(DISTINCT session.session_id)
      COMMENT = 'Number of checkout sessions',
    session.completed_cart_count AS COUNT(DISTINCT CASE WHEN session.status = 'completed' THEN session.session_id END)
      COMMENT = 'Number of completed checkouts',
    session.avg_cart_value AS AVG(session.total_cents) / 100.0
      WITH SYNONYMS = ('average order value', 'aov')
      COMMENT = 'Average cart value in dollars',
    item.total_items AS SUM(item.quantity)
      COMMENT = 'Total items across all carts',
    order_tbl.order_count AS COUNT(DISTINCT order_tbl.order_id)
      COMMENT = 'Number of orders',
    order_tbl.total_revenue AS SUM(order_tbl.total_cents) / 100.0
      WITH SYNONYMS = ('revenue', 'sales')
      COMMENT = 'Total revenue in dollars'
  )
  
  COMMENT = 'Semantic view for cart sessions, cart items, orders, and order items (Hybrid Tables)';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Show all semantic views
SHOW SEMANTIC VIEWS IN DATABASE AGENT_COMMERCE;

-- ============================================================================
-- USAGE EXAMPLE: Cortex Analyst Query
-- ============================================================================
-- Once semantic views are created, use Cortex Analyst like this:
--
-- SELECT SNOWFLAKE.CORTEX.ANALYST(
--     MODEL => 'llama3.1-70b',
--     SEMANTIC_VIEW => 'PRODUCTS.PRODUCT_SEMANTIC_VIEW',
--     QUESTION => 'What are the top 5 best-selling lipsticks under $30?'
-- );
--
-- ============================================================================

-- ============================================================================
-- NEXT STEPS:
-- 1. Run sql/04_create_cortex_search.sql for Cortex Search services
-- 2. Run sql/05_create_vector_search.sql for face embedding search
-- ============================================================================
