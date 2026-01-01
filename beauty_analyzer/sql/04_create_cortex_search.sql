-- ============================================================================
-- AGENT COMMERCE - Cortex Search Services
-- ============================================================================
-- This script creates Cortex Search services for semantic text search.
-- ONE search service per domain for simplicity.
--
-- Syntax per: https://docs.snowflake.com/sql-reference/sql/create-cortex-search
--
-- Run after 03_create_semantic_views.sql
-- ============================================================================

USE ROLE AGENT_COMMERCE_ROLE;
USE DATABASE AGENT_COMMERCE;
USE WAREHOUSE AGENT_COMMERCE_WH;

-- ============================================================================
-- PRODUCTS SCHEMA - Unified Product Search Service
-- ============================================================================
USE SCHEMA PRODUCTS;

-- ----------------------------------------------------------------------------
-- First, create a unified view combining all searchable product content
-- This enables single search across products, labels, ingredients, warnings
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW PRODUCT_SEARCH_CONTENT AS

-- Product catalog entries
SELECT
    'product' AS content_type,
    p.product_id AS id,
    p.product_id,
    p.name AS title,
    COALESCE(p.description, p.short_description, '') AS content,
    p.brand,
    p.category,
    p.subcategory,
    p.color_name,
    p.finish,
    p.current_price,
    p.is_vegan,
    p.is_cruelty_free,
    NULL AS source_image_url,
    NULL AS severity
FROM PRODUCTS p
WHERE p.is_active = TRUE

UNION ALL

-- Product label content (ingredients list, claims, directions)
SELECT
    'label' AS content_type,
    pl.label_id AS id,
    pl.product_id,
    CONCAT(p.name, ' - ', pl.label_type) AS title,
    pl.extracted_text AS content,
    p.brand,
    p.category,
    p.subcategory,
    NULL AS color_name,
    NULL AS finish,
    p.current_price,
    p.is_vegan,
    p.is_cruelty_free,
    pl.source_image_url,
    NULL AS severity
FROM PRODUCT_LABELS pl
JOIN PRODUCTS p ON pl.product_id = p.product_id
WHERE p.is_active = TRUE

UNION ALL

-- Individual ingredients (for allergen/ingredient searches)
SELECT
    'ingredient' AS content_type,
    pi.ingredient_id AS id,
    pi.product_id,
    CONCAT(p.name, ' - Ingredient: ', pi.ingredient_name) AS title,
    CONCAT(
        pi.ingredient_name, 
        COALESCE(' (' || pi.ingredient_name_normalized || ')', ''),
        CASE WHEN pi.is_allergen THEN ' [ALLERGEN: ' || COALESCE(pi.allergen_type, 'unknown') || ']' ELSE '' END
    ) AS content,
    p.brand,
    p.category,
    p.subcategory,
    NULL AS color_name,
    NULL AS finish,
    p.current_price,
    p.is_vegan,
    p.is_cruelty_free,
    pi.source_image_url,
    NULL AS severity
FROM PRODUCT_INGREDIENTS pi
JOIN PRODUCTS p ON pi.product_id = p.product_id
WHERE p.is_active = TRUE

UNION ALL

-- Product warnings
SELECT
    'warning' AS content_type,
    pw.warning_id AS id,
    pw.product_id,
    CONCAT(p.name, ' - Warning') AS title,
    pw.warning_text AS content,
    p.brand,
    p.category,
    p.subcategory,
    NULL AS color_name,
    NULL AS finish,
    p.current_price,
    p.is_vegan,
    p.is_cruelty_free,
    pw.source_image_url,
    pw.severity
FROM PRODUCT_WARNINGS pw
JOIN PRODUCTS p ON pw.product_id = p.product_id
WHERE p.is_active = TRUE;

-- ----------------------------------------------------------------------------
-- Single Product Search Service
-- Searches across: products, labels, ingredients, warnings
-- Filter by content_type at query time
-- ----------------------------------------------------------------------------
CREATE OR REPLACE CORTEX SEARCH SERVICE PRODUCT_SEARCH_SERVICE
  ON content
  ATTRIBUTES content_type, id, product_id, title, brand, category, subcategory, color_name, finish, current_price, is_vegan, is_cruelty_free, source_image_url, severity
  WAREHOUSE = AGENT_COMMERCE_WH
  TARGET_LAG = '1 hour'
  COMMENT = 'Unified search across products, labels, ingredients, and warnings'
AS (
  SELECT
    content_type,
    id,
    product_id,
    title,
    content,
    brand,
    category,
    subcategory,
    color_name,
    finish,
    current_price,
    is_vegan,
    is_cruelty_free,
    source_image_url,
    severity
  FROM PRODUCT_SEARCH_CONTENT
);

-- ============================================================================
-- SOCIAL SCHEMA - Unified Social Proof Search Service
-- ============================================================================
USE SCHEMA SOCIAL;

-- ----------------------------------------------------------------------------
-- Unified view combining reviews, social mentions, influencer content
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW SOCIAL_SEARCH_CONTENT AS

-- Product reviews
SELECT
    'review' AS content_type,
    r.review_id AS id,
    r.product_id,
    r.title,
    COALESCE(r.review_text, '') AS content,
    r.review_url AS url,
    NULL AS author_handle,
    NULL AS author_name,
    r.platform,
    r.rating,
    r.helpful_votes AS engagement_score,
    r.verified_purchase,
    r.reviewer_skin_tone AS skin_tone,
    r.reviewer_skin_type AS skin_type,
    r.reviewer_undertone AS undertone,
    NULL AS sentiment_label,
    NULL AS is_sponsored,
    r.created_at AS posted_at
FROM PRODUCT_REVIEWS r
WHERE r.is_approved = TRUE

UNION ALL

-- Social media mentions
SELECT
    'social_mention' AS content_type,
    m.mention_id AS id,
    m.product_id,
    NULL AS title,
    COALESCE(m.content_text, '') AS content,
    m.post_url AS url,
    m.author_handle,
    m.author_name,
    m.platform,
    NULL AS rating,
    (m.likes + m.comments + m.shares) AS engagement_score,
    NULL AS verified_purchase,
    NULL AS skin_tone,
    NULL AS skin_type,
    NULL AS undertone,
    m.sentiment_label,
    NULL AS is_sponsored,
    m.posted_at
FROM SOCIAL_MENTIONS m

UNION ALL

-- Influencer content
SELECT
    'influencer' AS content_type,
    i.mention_id AS id,
    i.product_id,
    CONCAT(i.influencer_name, ' on ', i.platform) AS title,
    COALESCE(i.content_text, '') AS content,
    i.post_url AS url,
    i.influencer_handle AS author_handle,
    i.influencer_name AS author_name,
    i.platform,
    NULL AS rating,
    (i.likes + i.comments + i.views) AS engagement_score,
    NULL AS verified_purchase,
    i.influencer_skin_tone AS skin_tone,
    i.influencer_skin_type AS skin_type,
    i.influencer_undertone AS undertone,
    NULL AS sentiment_label,
    i.is_sponsored,
    i.posted_at
FROM INFLUENCER_MENTIONS i;

-- ----------------------------------------------------------------------------
-- Single Social Proof Search Service
-- Searches across: reviews, social mentions, influencer content
-- Filter by content_type at query time
-- ----------------------------------------------------------------------------
CREATE OR REPLACE CORTEX SEARCH SERVICE SOCIAL_SEARCH_SERVICE
  ON content
  ATTRIBUTES content_type, id, product_id, title, url, author_handle, author_name, platform, rating, engagement_score, verified_purchase, skin_tone, skin_type, undertone, sentiment_label, is_sponsored, posted_at
  WAREHOUSE = AGENT_COMMERCE_WH
  TARGET_LAG = '1 hour'
  COMMENT = 'Unified search across reviews, social mentions, and influencer content'
AS (
  SELECT
    content_type,
    id,
    product_id,
    title,
    content,
    url,
    author_handle,
    author_name,
    platform,
    rating,
    engagement_score,
    verified_purchase,
    skin_tone,
    skin_type,
    undertone,
    sentiment_label,
    is_sponsored,
    posted_at
  FROM SOCIAL_SEARCH_CONTENT
);

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Show Cortex Search services
SHOW CORTEX SEARCH SERVICES IN DATABASE AGENT_COMMERCE;

-- ============================================================================
-- USAGE EXAMPLES
-- ============================================================================
--
-- Example 1: Search products (all types)
-- SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
--   'PRODUCTS.PRODUCT_SEARCH_SERVICE',
--   '{
--     "query": "moisturizer for dry sensitive skin",
--     "columns": ["content_type", "product_id", "title", "brand", "category"],
--     "limit": 10
--   }'
-- );
--
-- Example 2: Search only product catalog (filter by content_type)
-- SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
--   'PRODUCTS.PRODUCT_SEARCH_SERVICE',
--   '{
--     "query": "matte lipstick",
--     "columns": ["product_id", "title", "brand", "current_price"],
--     "filter": {"@eq": {"content_type": "product"}},
--     "limit": 10
--   }'
-- );
--
-- Example 3: Search ingredients for allergens
-- SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
--   'PRODUCTS.PRODUCT_SEARCH_SERVICE',
--   '{
--     "query": "paraben free no sulfates",
--     "columns": ["product_id", "title", "brand", "source_image_url"],
--     "filter": {"@eq": {"content_type": "ingredient"}},
--     "limit": 10
--   }'
-- );
--
-- Example 4: Search reviews from users with similar skin type
-- SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
--   'SOCIAL.SOCIAL_SEARCH_SERVICE',
--   '{
--     "query": "great coverage for oily skin",
--     "columns": ["content_type", "product_id", "title", "content", "rating", "skin_type"],
--     "filter": {"@and": [
--       {"@eq": {"content_type": "review"}},
--       {"@eq": {"skin_type": "Oily"}}
--     ]},
--     "limit": 10
--   }'
-- );
--
-- Example 5: Search influencer content matching user's skin tone
-- SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
--   'SOCIAL.SOCIAL_SEARCH_SERVICE',
--   '{
--     "query": "foundation recommendation",
--     "columns": ["author_name", "platform", "url", "skin_tone"],
--     "filter": {"@and": [
--       {"@eq": {"content_type": "influencer"}},
--       {"@eq": {"skin_tone": "Medium"}}
--     ]},
--     "limit": 5
--   }'
-- );
--
-- ============================================================================

-- ============================================================================
-- NEXT STEPS:
-- 1. Run sql/05_create_vector_search.sql for face embedding search
-- 2. Run sql/06_load_sample_data.sql to populate tables
-- ============================================================================
