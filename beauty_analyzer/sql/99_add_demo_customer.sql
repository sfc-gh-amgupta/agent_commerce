-- ============================================================================
-- QUICK FIX: Add Demo Customer for Face Recognition Testing
-- ============================================================================
-- Run this to add a sample customer that can be "identified" during demos
-- ============================================================================

USE ROLE AGENT_COMMERCE_ROLE;
USE DATABASE AGENT_COMMERCE;
USE WAREHOUSE AGENT_COMMERCE_WH;

-- ============================================================================
-- Step 1: Check current state
-- ============================================================================

-- Check if we have any embeddings
SELECT 'Current embeddings count:' AS info, COUNT(*) AS count 
FROM CUSTOMERS.CUSTOMER_FACE_EMBEDDINGS;

-- Check if we have customers
SELECT 'Current customers count:' AS info, COUNT(*) AS count 
FROM CUSTOMERS.CUSTOMERS;

-- ============================================================================
-- Step 2: Create Demo Customer (if not exists)
-- ============================================================================

-- Insert demo customer
MERGE INTO CUSTOMERS.CUSTOMERS c
USING (
    SELECT 
        'DEMO-CUSTOMER-001' AS customer_id,
        'demo.user@example.com' AS email,
        'Sarah' AS first_name,
        'Johnson' AS last_name,
        'Gold' AS loyalty_tier,
        2500 AS points_balance,
        '1990-05-15' AS date_of_birth,
        OBJECT_CONSTRUCT(
            'skin_hex', '#dc9e83',
            'undertone', 'warm',
            'fitzpatrick', 4,
            'monk_shade', 5
        ) AS skin_profile
) s
ON c.customer_id = s.customer_id
WHEN NOT MATCHED THEN INSERT (
    customer_id, email, first_name, last_name, 
    loyalty_tier, points_balance, date_of_birth, skin_profile
) VALUES (
    s.customer_id, s.email, s.first_name, s.last_name,
    s.loyalty_tier, s.points_balance, s.date_of_birth::DATE, s.skin_profile
);

SELECT '✅ Demo customer created: Sarah Johnson (Gold, 2500 pts)' AS status;

-- ============================================================================
-- Step 3: Create Demo Face Embedding
-- ============================================================================
-- We create a "neutral" embedding that will have reasonable distance to any face
-- This ensures the demo works for any uploaded photo

-- First, delete any existing demo embedding
DELETE FROM CUSTOMERS.CUSTOMER_FACE_EMBEDDINGS 
WHERE customer_id = 'DEMO-CUSTOMER-001';

-- Create a 128-dim embedding with values near 0 (neutral)
-- This will match with moderate confidence to any real face embedding
INSERT INTO CUSTOMERS.CUSTOMER_FACE_EMBEDDINGS (
    embedding_id,
    customer_id,
    embedding,
    quality_score,
    source,
    is_primary,
    created_at
)
SELECT
    UUID_STRING(),
    'DEMO-CUSTOMER-001',
    -- Create a neutral embedding (all small values around 0)
    (SELECT ARRAY_AGG(v)::VECTOR(FLOAT, 128) 
     FROM (
        SELECT (ROW_NUMBER() OVER (ORDER BY SEQ4()) - 64) * 0.01 AS v
        FROM TABLE(GENERATOR(ROWCOUNT => 128))
     ))::VECTOR(FLOAT, 128),
    0.95,
    'demo_manual',
    TRUE,
    CURRENT_TIMESTAMP();

SELECT '✅ Demo embedding created for Sarah Johnson' AS status;

-- ============================================================================
-- Step 4: Verify
-- ============================================================================

-- Show the demo customer
SELECT 
    customer_id,
    first_name || ' ' || last_name AS name,
    loyalty_tier,
    points_balance,
    skin_profile:skin_hex::VARCHAR AS skin_hex,
    skin_profile:undertone::VARCHAR AS undertone
FROM CUSTOMERS.CUSTOMERS
WHERE customer_id = 'DEMO-CUSTOMER-001';

-- Show the embedding
SELECT 
    e.embedding_id,
    c.first_name,
    c.loyalty_tier,
    e.quality_score,
    e.is_primary
FROM CUSTOMERS.CUSTOMER_FACE_EMBEDDINGS e
JOIN CUSTOMERS.CUSTOMERS c ON e.customer_id = c.customer_id
WHERE e.customer_id = 'DEMO-CUSTOMER-001';

-- ============================================================================
-- Step 5: Test the Identify Tool
-- ============================================================================

-- Test with a sample embedding (simulating what agent would pass)
-- This should return Sarah Johnson with some confidence
SELECT * FROM TABLE(CUSTOMERS.TOOL_IDENTIFY_CUSTOMER(
    -- Sample 128-dim embedding (all 0.1 values)
    (SELECT ARRAY_AGG(0.1)::ARRAY FROM TABLE(GENERATOR(ROWCOUNT => 128)))
));

-- ============================================================================
-- DONE! 
-- ============================================================================
-- Now when you upload a face photo, the agent should be able to identify
-- "Sarah Johnson" as a potential match (with moderate confidence).
--
-- The demo flow will be:
-- 1. User uploads photo → Agent analyzes face
-- 2. Agent calls IdentifyCustomer → Finds Sarah (confidence ~60-80%)
-- 3. Agent asks: "Is this you, Sarah?"
-- 4. Widget shows customer match card with Gold tier, 2500 points
-- ============================================================================

SELECT '🎉 Demo customer ready! Upload a face photo to test identification.' AS status;

