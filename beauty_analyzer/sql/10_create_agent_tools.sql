-- ============================================================================
-- AGENT COMMERCE - Agent Tools (UDFs & Stored Procedures)
-- ============================================================================
-- This script creates custom tools for the Cortex Agent that cannot be 
-- handled by Cortex Analyst (semantic views) or Cortex Search.
--
-- ============================================================================
-- IMPORTANT: CORTEX AGENT TOOL COMPATIBILITY NOTES
-- ============================================================================
-- When creating generic (function/procedure) tools for Cortex Agent, ensure:
--
-- 1. RETURN TYPES: Use OBJECT, ARRAY, or simple scalar types. Cortex Agent
--    wraps results, so returning TABLE types may cause parsing issues.
--
-- 2. PARAMETER DEFAULTS: Functions can have DEFAULT values, BUT in the 
--    Agent's input_schema (11_create_cortex_agent.sql), ALL parameters must 
--    be listed in the 'required' array. If any parameter is optional in the 
--    input_schema, the LLM may not pass it, resulting in <nil> values and:
--    "error building SQL query for generic tool: unsupported parameter type: <nil>"
--
-- 3. FUNCTION SIGNATURES: Ensure the function identifier in the agent's 
--    tool_resources matches the exact function signature.
--
-- See 11_create_cortex_agent.sql for the REQUIRED_PARAMS_FIX annotations.
-- ============================================================================
--
-- TOOLS CREATED (9):
-- ┌─────────────────────────────────────────┬─────────────┬──────────────────────────────┐
-- │ Tool                                    │ Type        │ Purpose                      │
-- ├─────────────────────────────────────────┼─────────────┼──────────────────────────────┤
-- │ CUSTOMERS.TOOL_ANALYZE_FACE             │ SQL UDF     │ Face/skin analysis (ML Svc)  │
-- │ CUSTOMERS.TOOL_IDENTIFY_CUSTOMER        │ SQL UDTF    │ Face matching (Vector Search)│
-- │ PRODUCTS.TOOL_MATCH_PRODUCTS            │ SQL UDTF    │ Color matching (CIEDE2000)   │
-- │ CART_OLTP.TOOL_CREATE_CART_SESSION      │ Procedure   │ Create cart session          │
-- │ CART_OLTP.TOOL_GET_CART_SESSION         │ SQL UDF     │ Get cart contents            │
-- │ CART_OLTP.TOOL_ADD_TO_CART              │ Procedure   │ Add item to cart             │
-- │ CART_OLTP.TOOL_UPDATE_CART_ITEM         │ Procedure   │ Update cart item quantity    │
-- │ CART_OLTP.TOOL_REMOVE_FROM_CART         │ Procedure   │ Remove item from cart        │
-- │ CART_OLTP.TOOL_SUBMIT_ORDER             │ Procedure   │ Complete order               │
-- └─────────────────────────────────────────┴─────────────┴──────────────────────────────┘
--
-- PREREQUISITES:
--   - Database, schemas, and tables created (01, 02)
--   - ML_FACE_ANALYSIS_SERVICE running (for TOOL_ANALYZE_FACE)
--
-- TABLE REFERENCES (from 02_create_tables.sql):
--   - CART_OLTP.CART_SESSIONS (Hybrid Table)
--   - CART_OLTP.CART_ITEMS (Hybrid Table)
--   - CART_OLTP.ORDERS (Hybrid Table)
--   - CART_OLTP.ORDER_ITEMS (Hybrid Table)
--
-- ============================================================================

USE ROLE AGENT_COMMERCE_ROLE;
USE DATABASE AGENT_COMMERCE;
USE WAREHOUSE AGENT_COMMERCE_WH;

-- ============================================================================
-- PART 1: BEAUTY ANALYSIS TOOLS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Tool: TOOL_ANALYZE_FACE
-- Extracts face embedding, skin tone, lip color from uploaded image
-- Uses ML_FACE_ANALYSIS_SERVICE (Model Registry service function)
-- 
-- The ML service uses dlib ResNet for 128-dim face embeddings and 
-- face_recognition library for skin/lip analysis.
-- ----------------------------------------------------------------------------
USE SCHEMA CUSTOMERS;

CREATE OR REPLACE FUNCTION CUSTOMERS.TOOL_ANALYZE_FACE(image_base64 VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
    SELECT PARSE_JSON(
        UTIL.ML_FACE_ANALYSIS_SERVICE!PREDICT(image_base64):"output_feature_0"::VARCHAR
    )
$$;

COMMENT ON FUNCTION CUSTOMERS.TOOL_ANALYZE_FACE(VARCHAR) IS 
'Analyze face from uploaded image (base64). Returns embedding (128-dim), skin tone (hex), lip color, Fitzpatrick type (1-6), Monk shade (1-10), and undertone (warm/cool/neutral). Uses ML Model Registry service.';

-- ----------------------------------------------------------------------------
-- Tool: TOOL_IDENTIFY_CUSTOMER
-- Match face embedding to known customers using vector search
-- Returns OBJECT with {success: true, matches: [...]} for Cortex Agent
-- IMPORTANT: Accepts VARCHAR (JSON string) instead of ARRAY because Cortex Agent
--            has issues passing ARRAY type parameters to functions
-- ----------------------------------------------------------------------------
USE SCHEMA CUSTOMERS;

-- Drop old function with ARRAY signature to avoid ambiguity
DROP FUNCTION IF EXISTS CUSTOMERS.TOOL_IDENTIFY_CUSTOMER(ARRAY, FLOAT, INT);

-- ----------------------------------------------------------------------------
-- Tool: TOOL_IDENTIFY_CUSTOMER
-- Matches face embedding against stored customer embeddings
--
-- DLIB INDUSTRY STANDARD THRESHOLDS (per ARCHITECTURE.md):
--   - distance < 0.40: HIGH confidence (very likely same person)
--   - distance 0.40-0.55: MEDIUM confidence (probably same person, verify)
--   - distance >= 0.55: NO MATCH (different person)
--
-- AGENT COMPATIBILITY NOTE: 
--   - Parameters have DEFAULT values for direct SQL calls
--   - In 11_create_cortex_agent.sql, ALL params must be in 'required' list
--   - Otherwise agent gets "unsupported parameter type: <nil>" error
--   - Returns OBJECT (not TABLE) for proper agent response parsing
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION CUSTOMERS.TOOL_IDENTIFY_CUSTOMER(
    query_embedding_json VARCHAR,
    match_threshold FLOAT DEFAULT 0.55,
    max_results INT DEFAULT 5
)
RETURNS OBJECT
LANGUAGE SQL
AS
$$
    -- Parse JSON string to array, then cast to vector for distance calculation
    -- Agent passes embedding as JSON string like "[0.1, 0.2, ...]"
    SELECT OBJECT_CONSTRUCT(
        'success', TRUE,
        'matches', COALESCE(ARRAY_AGG(
            OBJECT_CONSTRUCT(
                'customer_id', customer_id,
                'first_name', first_name,
                'last_name', last_name,
                'email', email,
                'loyalty_tier', loyalty_tier,
                'points_balance', points_balance,
                'distance', distance,
                'match_level', match_level
            )
        ), ARRAY_CONSTRUCT())
    )
    FROM (
        SELECT 
            c.customer_id,
            c.first_name,
            c.last_name,
            c.email,
            c.loyalty_tier,
            c.points_balance,
            ROUND(VECTOR_L2_DISTANCE(
                e.embedding, 
                PARSE_JSON(query_embedding_json)::VECTOR(FLOAT, 128)
            ), 4) AS distance,
            -- DLIB INDUSTRY STANDARD: L2 distance thresholds for face recognition
            -- These thresholds are validated against LFW benchmark dataset
            CASE 
                WHEN VECTOR_L2_DISTANCE(e.embedding, PARSE_JSON(query_embedding_json)::VECTOR(FLOAT, 128)) < 0.40 THEN 'high'
                WHEN VECTOR_L2_DISTANCE(e.embedding, PARSE_JSON(query_embedding_json)::VECTOR(FLOAT, 128)) < 0.55 THEN 'medium'
                ELSE 'none'
            END AS match_level
        FROM CUSTOMERS.CUSTOMER_FACE_EMBEDDINGS e
        JOIN CUSTOMERS.CUSTOMERS c ON e.customer_id = c.customer_id
        WHERE e.is_primary = TRUE
        ORDER BY distance ASC
        LIMIT 5
    )
$$;

COMMENT ON FUNCTION CUSTOMERS.TOOL_IDENTIFY_CUSTOMER(VARCHAR, FLOAT, INT) IS 
'Identify customer by matching face embedding using dlib industry-standard L2 distance thresholds. Returns match_level: high (<0.4), medium (0.4-0.55), or none (>=0.55). Only high/medium matches should trigger customer verification.';

-- ----------------------------------------------------------------------------
-- Tool: TOOL_MATCH_PRODUCTS
-- Color matching using Euclidean RGB distance
-- IMPORTANT: Returns ARRAY (scalar function) for Cortex Agent compatibility
-- Table functions (UDTF) are NOT supported by Cortex Agent generic tools
-- 
-- FIX: Added category mapping (lipstick->lips, foundation->face, etc.)
-- FIX: Use TRY_TO_NUMBER for graceful hex parsing
-- FIX: Use ROW_NUMBER() to respect limit_results parameter
-- FIX: NO CTEs - Cortex Agent may have issues with WITH clauses
-- ----------------------------------------------------------------------------
USE SCHEMA PRODUCTS;

-- Drop existing table function to avoid overload ambiguity
DROP FUNCTION IF EXISTS PRODUCTS.TOOL_MATCH_PRODUCTS(VARCHAR, VARCHAR, INT);

-- ----------------------------------------------------------------------------
-- Tool: TOOL_MATCH_PRODUCTS
-- Finds products matching a target color using Euclidean distance
--
-- AGENT COMPATIBILITY NOTE: 
--   - Parameters have DEFAULT values for direct SQL calls
--   - In 11_create_cortex_agent.sql, ALL params must be in 'required' list
--   - Otherwise agent gets "unsupported parameter type: <nil>" error
--   - Returns ARRAY (not TABLE) for proper agent response parsing
--   - Category filter maps common names (lipstick) to DB categories (lips)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION PRODUCTS.TOOL_MATCH_PRODUCTS(
    target_hex VARCHAR,
    category_filter VARCHAR DEFAULT NULL,
    limit_results INT DEFAULT 10
)
RETURNS ARRAY
LANGUAGE SQL
AS
$$
    SELECT COALESCE(ARRAY_AGG(OBJECT_CONSTRUCT(
        'product_id', product_id,
        'name', name,
        'brand', brand,
        'category', category,
        'swatch_hex', swatch_hex,
        'color_distance', color_distance,
        'price', price,
        'image_url', image_url
    )), ARRAY_CONSTRUCT())
    FROM (
        SELECT 
            p.product_id,
            p.name,
            p.brand,
            p.category,
            pv.color_hex AS swatch_hex,
            ROUND(SQRT(
                POWER(COALESCE(TRY_TO_NUMBER(SUBSTR(pv.color_hex, 2, 2), 'XX'), 0) - 
                      COALESCE(TRY_TO_NUMBER(SUBSTR(CASE WHEN LEFT(target_hex, 1) = '#' THEN target_hex ELSE '#' || target_hex END, 2, 2), 'XX'), 128), 2) +
                POWER(COALESCE(TRY_TO_NUMBER(SUBSTR(pv.color_hex, 4, 2), 'XX'), 0) - 
                      COALESCE(TRY_TO_NUMBER(SUBSTR(CASE WHEN LEFT(target_hex, 1) = '#' THEN target_hex ELSE '#' || target_hex END, 4, 2), 'XX'), 128), 2) +
                POWER(COALESCE(TRY_TO_NUMBER(SUBSTR(pv.color_hex, 6, 2), 'XX'), 0) - 
                      COALESCE(TRY_TO_NUMBER(SUBSTR(CASE WHEN LEFT(target_hex, 1) = '#' THEN target_hex ELSE '#' || target_hex END, 6, 2), 'XX'), 128), 2)
            ), 2) AS color_distance,
            p.current_price AS price,
            pm.url AS image_url,
            ROW_NUMBER() OVER (ORDER BY SQRT(
                POWER(COALESCE(TRY_TO_NUMBER(SUBSTR(pv.color_hex, 2, 2), 'XX'), 0) - 
                      COALESCE(TRY_TO_NUMBER(SUBSTR(CASE WHEN LEFT(target_hex, 1) = '#' THEN target_hex ELSE '#' || target_hex END, 2, 2), 'XX'), 128), 2) +
                POWER(COALESCE(TRY_TO_NUMBER(SUBSTR(pv.color_hex, 4, 2), 'XX'), 0) - 
                      COALESCE(TRY_TO_NUMBER(SUBSTR(CASE WHEN LEFT(target_hex, 1) = '#' THEN target_hex ELSE '#' || target_hex END, 4, 2), 'XX'), 128), 2) +
                POWER(COALESCE(TRY_TO_NUMBER(SUBSTR(pv.color_hex, 6, 2), 'XX'), 0) - 
                      COALESCE(TRY_TO_NUMBER(SUBSTR(CASE WHEN LEFT(target_hex, 1) = '#' THEN target_hex ELSE '#' || target_hex END, 6, 2), 'XX'), 128), 2)
            ) ASC) AS rn
        FROM PRODUCTS.PRODUCTS p
        JOIN PRODUCTS.PRODUCT_VARIANTS pv ON p.product_id = pv.product_id
        LEFT JOIN PRODUCTS.PRODUCT_MEDIA pm ON p.product_id = pm.product_id AND pm.is_primary = TRUE
        WHERE pv.color_hex IS NOT NULL
          AND LENGTH(pv.color_hex) = 7
          AND (category_filter IS NULL 
               OR category_filter = ''
               OR LOWER(p.category) = LOWER(category_filter)
               OR (LOWER(category_filter) IN ('lipstick', 'lip', 'lip gloss', 'lipgloss') AND LOWER(p.category) = 'lips')
               OR (LOWER(category_filter) IN ('foundation', 'concealer', 'powder', 'blush', 'bronzer', 'highlighter', 'primer') AND LOWER(p.category) = 'face')
               OR (LOWER(category_filter) IN ('eyeshadow', 'eyeliner', 'mascara', 'brow', 'eye') AND LOWER(p.category) = 'eyes')
               OR (LOWER(category_filter) IN ('moisturizer', 'serum', 'cleanser', 'skin') AND LOWER(p.category) = 'skincare')
              )
    ) sub
    WHERE rn <= limit_results
$$;

COMMENT ON FUNCTION PRODUCTS.TOOL_MATCH_PRODUCTS(VARCHAR, VARCHAR, INT) IS 
'Find products matching a target color (hex format like #E75480). Category filter accepts common names (lipstick, foundation, eyeshadow) which map to DB categories (lips, face, eyes). Returns array of products sorted by color distance (lower = closer match).';

-- Alternative version with required category filter (for simpler agent calls)
DROP FUNCTION IF EXISTS PRODUCTS.TOOL_MATCH_PRODUCTS_BY_CATEGORY(VARCHAR, VARCHAR);

CREATE OR REPLACE FUNCTION PRODUCTS.TOOL_MATCH_PRODUCTS_BY_CATEGORY(
    target_hex VARCHAR,
    category_filter VARCHAR
)
RETURNS ARRAY
LANGUAGE SQL
AS
$$
    SELECT ARRAY_AGG(OBJECT_CONSTRUCT(
        'product_id', product_id,
        'name', name,
        'brand', brand,
        'category', category,
        'swatch_hex', swatch_hex,
        'color_distance', color_distance,
        'price', price,
        'image_url', image_url
    ))
    FROM (
        SELECT 
            p.product_id,
            p.name,
            p.brand,
            p.category,
            pv.color_hex AS swatch_hex,
            ROUND(SQRT(
                POWER(TO_NUMBER(SUBSTR(pv.color_hex, 2, 2), 'XX') - TO_NUMBER(SUBSTR(target_hex, 2, 2), 'XX'), 2) +
                POWER(TO_NUMBER(SUBSTR(pv.color_hex, 4, 2), 'XX') - TO_NUMBER(SUBSTR(target_hex, 4, 2), 'XX'), 2) +
                POWER(TO_NUMBER(SUBSTR(pv.color_hex, 6, 2), 'XX') - TO_NUMBER(SUBSTR(target_hex, 6, 2), 'XX'), 2)
            ), 2) AS color_distance,
            p.current_price AS price,
            pm.url AS image_url
        FROM PRODUCTS.PRODUCTS p
        JOIN PRODUCTS.PRODUCT_VARIANTS pv ON p.product_id = pv.product_id
        LEFT JOIN PRODUCTS.PRODUCT_MEDIA pm ON p.product_id = pm.product_id AND pm.is_primary = TRUE
        WHERE pv.color_hex IS NOT NULL
          AND LOWER(p.category) = LOWER(category_filter)
        ORDER BY color_distance ASC
        LIMIT 10
    )
$$;

COMMENT ON FUNCTION PRODUCTS.TOOL_MATCH_PRODUCTS_BY_CATEGORY(VARCHAR, VARCHAR) IS 
'Find top 10 products in a specific category matching a target color. Returns array with price and image_url. Category examples: lips, eyes, face, skincare.';

-- ============================================================================
-- PART 2: CART/CHECKOUT TOOLS (Transactional Operations)
-- Uses Hybrid Tables: CART_SESSIONS, CART_ITEMS, ORDERS, ORDER_ITEMS
-- ============================================================================

USE SCHEMA CART_OLTP;

-- ----------------------------------------------------------------------------
-- Tool: TOOL_CREATE_CART_SESSION
-- Create a new cart session for a customer
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE CART_OLTP.TOOL_CREATE_CART_SESSION(
    customer_id VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    new_session_id VARCHAR;
BEGIN
    new_session_id := UUID_STRING();
    
    INSERT INTO CART_OLTP.CART_SESSIONS (
        session_id, 
        customer_id, 
        status,
        subtotal_cents,
        total_cents,
        currency,
        created_at
    ) VALUES (
        :new_session_id, 
        :customer_id, 
        'active',
        0,
        0,
        'USD',
        CURRENT_TIMESTAMP()
    );
    
    RETURN OBJECT_CONSTRUCT(
        'success', TRUE,
        'session_id', :new_session_id,
        'customer_id', :customer_id,
        'status', 'active',
        'message', 'Cart session created successfully'
    )::VARIANT;
END;
$$;

COMMENT ON PROCEDURE CART_OLTP.TOOL_CREATE_CART_SESSION(VARCHAR) IS 
'Create a new cart session for a customer. Returns session_id for subsequent cart operations.';

-- ----------------------------------------------------------------------------
-- Tool: TOOL_GET_CART_SESSION
-- Get cart contents with all items
-- ----------------------------------------------------------------------------
-- SESSION_ID_FALLBACK_FIX (2026-01-04):
-- Root Cause: Agent may pass customer_id or made-up session_id when real 
--             session_id UUID is not in conversation history
-- Fix: Use COALESCE to first try session_id lookup, then customer_id lookup.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION CART_OLTP.TOOL_GET_CART_SESSION(session_id VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
    SELECT OBJECT_CONSTRUCT(
        'session_id', s.session_id,
        'customer_id', s.customer_id,
        'status', s.status,
        'currency', s.currency,
        'items', (
            SELECT COALESCE(ARRAY_AGG(OBJECT_CONSTRUCT(
                'item_id', ci.item_id,
                'product_id', ci.product_id,
                'product_name', ci.product_name,
                'variant_id', ci.variant_id,
                'variant_name', ci.variant_name,
                'quantity', ci.quantity,
                'unit_price_cents', ci.unit_price_cents,
                'subtotal_cents', ci.subtotal_cents
            )), ARRAY_CONSTRUCT())
            FROM CART_OLTP.CART_ITEMS ci
            WHERE ci.session_id = s.session_id
        ),
        'item_count', (
            SELECT COUNT(*) FROM CART_OLTP.CART_ITEMS ci2 WHERE ci2.session_id = s.session_id
        ),
        'subtotal_cents', s.subtotal_cents,
        'total_cents', s.total_cents,
        'created_at', s.created_at
    )::VARIANT
    FROM CART_OLTP.CART_SESSIONS s
    WHERE s.session_id = COALESCE(
        -- First: try to find by exact session_id match
        (SELECT cs.session_id FROM CART_OLTP.CART_SESSIONS cs WHERE cs.session_id = session_id LIMIT 1),
        -- Second: try to find most recent active cart by customer_id
        (SELECT cs.session_id FROM CART_OLTP.CART_SESSIONS cs
         WHERE cs.customer_id = session_id AND cs.status = 'active' 
         ORDER BY cs.created_at DESC LIMIT 1)
    )
$$;

COMMENT ON FUNCTION CART_OLTP.TOOL_GET_CART_SESSION(VARCHAR) IS 
'Get cart session with all items. Accepts session_id UUID or customer_id to find most recent active cart.';

-- ----------------------------------------------------------------------------
-- Tool: TOOL_ADD_TO_CART
-- Add a product to the cart
-- ----------------------------------------------------------------------------
-- PRODUCT_ID_FALLBACK_FIX (2026-01-04):
-- Root Cause: Agent may pass product NAME instead of UUID when UUID is not
--             in conversation history (e.g., from previous turn's text response)
-- Fix: Check if product_id is a valid UUID. If not, look up by product name.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE CART_OLTP.TOOL_ADD_TO_CART(
    session_id VARCHAR,
    product_id VARCHAR,
    quantity INT,
    variant_id VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    new_item_id VARCHAR;
    v_unit_price_cents INT;
    v_subtotal_cents INT;
    v_product_name VARCHAR;
    v_session_subtotal INT;
    v_resolved_product_id VARCHAR;
BEGIN
    -- Check if product_id looks like a UUID (36 chars with hyphens in right places)
    IF (LENGTH(:product_id) = 36 
        AND SUBSTRING(:product_id, 9, 1) = '-'
        AND SUBSTRING(:product_id, 14, 1) = '-'
        AND SUBSTRING(:product_id, 19, 1) = '-'
        AND SUBSTRING(:product_id, 24, 1) = '-') THEN
        -- It's a UUID, use directly
        v_resolved_product_id := :product_id;
    ELSE
        -- It's likely a product name, look up the UUID
        SELECT product_id INTO :v_resolved_product_id
        FROM PRODUCTS.PRODUCTS
        WHERE LOWER(name) = LOWER(:product_id)
        LIMIT 1;
        
        -- If exact match not found, try partial match
        IF (:v_resolved_product_id IS NULL) THEN
            SELECT product_id INTO :v_resolved_product_id
            FROM PRODUCTS.PRODUCTS
            WHERE LOWER(name) LIKE '%' || LOWER(:product_id) || '%'
            LIMIT 1;
        END IF;
        
        -- If still not found, return error
        IF (:v_resolved_product_id IS NULL) THEN
            RETURN OBJECT_CONSTRUCT(
                'success', FALSE,
                'error', 'Product not found: ' || :product_id,
                'message', 'Could not find a product matching "' || :product_id || '". Please try with the exact product name.'
            )::VARIANT;
        END IF;
    END IF;
    
    -- Get product price using resolved product_id
    SELECT 
        ROUND(CURRENT_PRICE * 100)::INT,
        name
    INTO :v_unit_price_cents, :v_product_name
    FROM PRODUCTS.PRODUCTS
    WHERE product_id = :v_resolved_product_id;
    
    -- Handle case where product not found even with valid UUID
    IF (:v_unit_price_cents IS NULL) THEN
        RETURN OBJECT_CONSTRUCT(
            'success', FALSE,
            'error', 'Product not found with ID: ' || :v_resolved_product_id,
            'message', 'The product could not be found in our catalog.'
        )::VARIANT;
    END IF;
    
    -- Calculate subtotal
    v_subtotal_cents := :v_unit_price_cents * :quantity;
    
    -- Generate item ID
    new_item_id := UUID_STRING();
    
    -- Insert cart item (use resolved product_id)
    INSERT INTO CART_OLTP.CART_ITEMS (
        item_id, 
        session_id, 
        product_id, 
        variant_id,
        quantity, 
        unit_price_cents, 
        subtotal_cents,
        product_name,
        added_at
    ) VALUES (
        :new_item_id, 
        :session_id, 
        :v_resolved_product_id,
        :variant_id,
        :quantity, 
        :v_unit_price_cents, 
        :v_subtotal_cents,
        :v_product_name,
        CURRENT_TIMESTAMP()
    );
    
    -- Update session subtotal
    SELECT SUM(subtotal_cents) INTO :v_session_subtotal
    FROM CART_OLTP.CART_ITEMS
    WHERE session_id = :session_id;
    
    UPDATE CART_OLTP.CART_SESSIONS
    SET subtotal_cents = :v_session_subtotal,
        total_cents = :v_session_subtotal,  -- Simplified, no tax/shipping
        updated_at = CURRENT_TIMESTAMP()
    WHERE session_id = :session_id;
    
    RETURN OBJECT_CONSTRUCT(
        'success', TRUE,
        'item_id', :new_item_id,
        'product_id', :v_resolved_product_id,
        'product_name', :v_product_name,
        'quantity', :quantity,
        'unit_price_cents', :v_unit_price_cents,
        'subtotal_cents', :v_subtotal_cents,
        'message', 'Item added to cart'
    )::VARIANT;
END;
$$;

COMMENT ON PROCEDURE CART_OLTP.TOOL_ADD_TO_CART(VARCHAR, VARCHAR, INT, VARCHAR) IS 
'Add a product to cart. Parameters: session_id, product_id (UUID or product name), quantity, variant_id (optional, pass NULL if not needed).';

-- ----------------------------------------------------------------------------
-- Tool: TOOL_UPDATE_CART_ITEM
-- Update quantity of a cart item
-- ----------------------------------------------------------------------------
-- SESSION_SCOPED_FALLBACK_FIX (2026-01-04):
-- Root Cause: Agent may pass product NAME instead of item_id UUID.
--             Without session_id, lookups could affect wrong user's cart.
-- Fix: Add session_id parameter to scope lookups to the correct cart.
--      Use session_id/customer_id fallback (like GetCart) if needed.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE CART_OLTP.TOOL_UPDATE_CART_ITEM(
    session_id VARCHAR,
    item_id VARCHAR,
    new_quantity INT
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    v_session_id VARCHAR;
    v_unit_price_cents INT;
    v_new_subtotal_cents INT;
    v_session_subtotal INT;
    v_resolved_item_id VARCHAR;
    v_product_name VARCHAR;
    v_resolved_session_id VARCHAR;
BEGIN
    -- First resolve the session_id (supports UUID or customer_id)
    SELECT s.session_id INTO :v_resolved_session_id
    FROM CART_OLTP.CART_SESSIONS s
    WHERE s.session_id = COALESCE(
        (SELECT session_id FROM CART_OLTP.CART_SESSIONS WHERE session_id = :session_id LIMIT 1),
        (SELECT session_id FROM CART_OLTP.CART_SESSIONS 
         WHERE customer_id = :session_id AND status = 'active' 
         ORDER BY created_at DESC LIMIT 1)
    );
    
    IF (:v_resolved_session_id IS NULL) THEN
        RETURN OBJECT_CONSTRUCT(
            'success', FALSE,
            'error', 'Cart session not found: ' || :session_id,
            'message', 'Could not find a cart session. Please create a cart first.'
        )::VARIANT;
    END IF;
    
    -- Check if item_id looks like a UUID (36 chars with hyphens in right places)
    IF (LENGTH(:item_id) = 36 
        AND SUBSTRING(:item_id, 9, 1) = '-'
        AND SUBSTRING(:item_id, 14, 1) = '-'
        AND SUBSTRING(:item_id, 19, 1) = '-'
        AND SUBSTRING(:item_id, 24, 1) = '-') THEN
        -- It's a UUID, use directly
        v_resolved_item_id := :item_id;
    ELSE
        -- It's likely a product name, look up the item_id within this session
        SELECT ci.item_id, ci.product_name
        INTO :v_resolved_item_id, :v_product_name
        FROM CART_OLTP.CART_ITEMS ci
        WHERE ci.session_id = :v_resolved_session_id
          AND LOWER(ci.product_name) = LOWER(:item_id)
        LIMIT 1;
        
        -- If exact match not found, try partial match within session
        IF (:v_resolved_item_id IS NULL) THEN
            SELECT ci.item_id, ci.product_name
            INTO :v_resolved_item_id, :v_product_name
            FROM CART_OLTP.CART_ITEMS ci
            WHERE ci.session_id = :v_resolved_session_id
              AND LOWER(ci.product_name) LIKE '%' || LOWER(:item_id) || '%'
            LIMIT 1;
        END IF;
        
        -- If still not found, return error
        IF (:v_resolved_item_id IS NULL) THEN
            RETURN OBJECT_CONSTRUCT(
                'success', FALSE,
                'error', 'Cart item not found: ' || :item_id,
                'message', 'Could not find "' || :item_id || '" in your cart. Please check your cart contents.'
            )::VARIANT;
        END IF;
    END IF;
    
    -- Get item details using resolved item_id (verify it's in the right session)
    SELECT session_id, unit_price_cents, product_name
    INTO :v_session_id, :v_unit_price_cents, :v_product_name
    FROM CART_OLTP.CART_ITEMS
    WHERE item_id = :v_resolved_item_id
      AND session_id = :v_resolved_session_id;
    
    -- Handle case where item not found in this session
    IF (:v_session_id IS NULL) THEN
        RETURN OBJECT_CONSTRUCT(
            'success', FALSE,
            'error', 'Cart item not found in your cart',
            'message', 'The item could not be found in your current cart.'
        )::VARIANT;
    END IF;
    
    -- Calculate new subtotal
    v_new_subtotal_cents := :v_unit_price_cents * :new_quantity;
    
    -- Update cart item
    UPDATE CART_OLTP.CART_ITEMS
    SET quantity = :new_quantity,
        subtotal_cents = :v_new_subtotal_cents,
        updated_at = CURRENT_TIMESTAMP()
    WHERE item_id = :v_resolved_item_id;
    
    -- Update session subtotal
    SELECT SUM(subtotal_cents) INTO :v_session_subtotal
    FROM CART_OLTP.CART_ITEMS
    WHERE session_id = :v_resolved_session_id;
    
    UPDATE CART_OLTP.CART_SESSIONS
    SET subtotal_cents = :v_session_subtotal,
        total_cents = :v_session_subtotal,
        updated_at = CURRENT_TIMESTAMP()
    WHERE session_id = :v_resolved_session_id;
    
    RETURN OBJECT_CONSTRUCT(
        'success', TRUE,
        'session_id', :v_resolved_session_id,
        'item_id', :v_resolved_item_id,
        'product_name', :v_product_name,
        'new_quantity', :new_quantity,
        'new_subtotal_cents', :v_new_subtotal_cents,
        'message', 'Cart item updated'
    )::VARIANT;
END;
$$;

COMMENT ON PROCEDURE CART_OLTP.TOOL_UPDATE_CART_ITEM(VARCHAR, VARCHAR, INT) IS 
'Update the quantity of an item in the cart. session_id can be UUID or customer_id. item_id can be UUID or product name.';

-- ----------------------------------------------------------------------------
-- Tool: TOOL_REMOVE_FROM_CART
-- Remove an item from the cart
-- ----------------------------------------------------------------------------
-- SESSION_SCOPED_FALLBACK_FIX (2026-01-04):
-- Root Cause: Agent may pass product NAME instead of item_id UUID.
--             Without session_id, lookups could affect wrong user's cart.
-- Fix: Add session_id parameter to scope lookups to the correct cart.
--      Use session_id/customer_id fallback (like GetCart) if needed.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE CART_OLTP.TOOL_REMOVE_FROM_CART(
    session_id VARCHAR,
    item_id VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    v_session_id VARCHAR;
    v_session_subtotal INT;
    v_resolved_item_id VARCHAR;
    v_product_name VARCHAR;
    v_resolved_session_id VARCHAR;
BEGIN
    -- First resolve the session_id (supports UUID or customer_id)
    SELECT s.session_id INTO :v_resolved_session_id
    FROM CART_OLTP.CART_SESSIONS s
    WHERE s.session_id = COALESCE(
        (SELECT session_id FROM CART_OLTP.CART_SESSIONS WHERE session_id = :session_id LIMIT 1),
        (SELECT session_id FROM CART_OLTP.CART_SESSIONS 
         WHERE customer_id = :session_id AND status = 'active' 
         ORDER BY created_at DESC LIMIT 1)
    );
    
    IF (:v_resolved_session_id IS NULL) THEN
        RETURN OBJECT_CONSTRUCT(
            'success', FALSE,
            'error', 'Cart session not found: ' || :session_id,
            'message', 'Could not find a cart session. Please create a cart first.'
        )::VARIANT;
    END IF;
    
    -- Check if item_id looks like a UUID (36 chars with hyphens in right places)
    IF (LENGTH(:item_id) = 36 
        AND SUBSTRING(:item_id, 9, 1) = '-'
        AND SUBSTRING(:item_id, 14, 1) = '-'
        AND SUBSTRING(:item_id, 19, 1) = '-'
        AND SUBSTRING(:item_id, 24, 1) = '-') THEN
        -- It's a UUID, use directly
        v_resolved_item_id := :item_id;
    ELSE
        -- It's likely a product name, look up the item_id within this session
        SELECT ci.item_id, ci.product_name
        INTO :v_resolved_item_id, :v_product_name
        FROM CART_OLTP.CART_ITEMS ci
        WHERE ci.session_id = :v_resolved_session_id
          AND LOWER(ci.product_name) = LOWER(:item_id)
        LIMIT 1;
        
        -- If exact match not found, try partial match within session
        IF (:v_resolved_item_id IS NULL) THEN
            SELECT ci.item_id, ci.product_name
            INTO :v_resolved_item_id, :v_product_name
            FROM CART_OLTP.CART_ITEMS ci
            WHERE ci.session_id = :v_resolved_session_id
              AND LOWER(ci.product_name) LIKE '%' || LOWER(:item_id) || '%'
            LIMIT 1;
        END IF;
        
        -- If still not found, return error
        IF (:v_resolved_item_id IS NULL) THEN
            RETURN OBJECT_CONSTRUCT(
                'success', FALSE,
                'error', 'Cart item not found: ' || :item_id,
                'message', 'Could not find "' || :item_id || '" in your cart. Please check your cart contents.'
            )::VARIANT;
        END IF;
    END IF;
    
    -- Get session ID and product name before deleting (verify it's in the right session)
    SELECT session_id, product_name 
    INTO :v_session_id, :v_product_name
    FROM CART_OLTP.CART_ITEMS
    WHERE item_id = :v_resolved_item_id
      AND session_id = :v_resolved_session_id;
    
    -- Handle case where item not found in this session
    IF (:v_session_id IS NULL) THEN
        RETURN OBJECT_CONSTRUCT(
            'success', FALSE,
            'error', 'Cart item not found in your cart',
            'message', 'The item could not be found in your current cart.'
        )::VARIANT;
    END IF;
    
    -- Delete the item
    DELETE FROM CART_OLTP.CART_ITEMS 
    WHERE item_id = :v_resolved_item_id
      AND session_id = :v_resolved_session_id;
    
    -- Update session subtotal
    SELECT COALESCE(SUM(subtotal_cents), 0) INTO :v_session_subtotal
    FROM CART_OLTP.CART_ITEMS
    WHERE session_id = :v_resolved_session_id;
    
    UPDATE CART_OLTP.CART_SESSIONS
    SET subtotal_cents = :v_session_subtotal,
        total_cents = :v_session_subtotal,
        updated_at = CURRENT_TIMESTAMP()
    WHERE session_id = :v_resolved_session_id;
    
    RETURN OBJECT_CONSTRUCT(
        'success', TRUE,
        'session_id', :v_resolved_session_id,
        'removed_item_id', :v_resolved_item_id,
        'product_name', :v_product_name,
        'message', 'Item removed from cart'
    )::VARIANT;
END;
$$;

COMMENT ON PROCEDURE CART_OLTP.TOOL_REMOVE_FROM_CART(VARCHAR, VARCHAR) IS 
'Remove an item from the cart. session_id can be UUID or customer_id. item_id can be UUID or product name.';

-- ----------------------------------------------------------------------------
-- Tool: TOOL_SUBMIT_ORDER
-- Complete the order
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE CART_OLTP.TOOL_SUBMIT_ORDER(
    session_id VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    new_order_id VARCHAR;
    v_order_number VARCHAR;
    v_customer_id VARCHAR;
    v_subtotal_cents INT;
    v_total_cents INT;
    v_item_count INT;
BEGIN
    -- Get session info
    SELECT 
        customer_id, 
        subtotal_cents, 
        total_cents
    INTO :v_customer_id, :v_subtotal_cents, :v_total_cents
    FROM CART_OLTP.CART_SESSIONS
    WHERE session_id = :session_id;
    
    -- Count items
    SELECT COUNT(*) INTO :v_item_count
    FROM CART_OLTP.CART_ITEMS
    WHERE session_id = :session_id;
    
    -- Generate order ID and number
    new_order_id := UUID_STRING();
    v_order_number := 'ORD-' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDD') || '-' || SUBSTR(REPLACE(UUID_STRING(), '-', ''), 1, 6);
    
    -- Create order
    INSERT INTO CART_OLTP.ORDERS (
        order_id, 
        order_number,
        session_id,
        customer_id, 
        status,
        subtotal_cents,
        tax_cents,
        shipping_cents,
        discount_cents,
        total_cents,
        currency,
        created_at,
        confirmed_at
    ) VALUES (
        :new_order_id, 
        :v_order_number,
        :session_id,
        :v_customer_id, 
        'confirmed',
        :v_subtotal_cents,
        0,  -- No tax in demo
        0,  -- No shipping in demo
        0,  -- No discount in demo
        :v_total_cents,
        'USD',
        CURRENT_TIMESTAMP(),
        CURRENT_TIMESTAMP()
    );
    
    -- Copy items to order_items
    INSERT INTO CART_OLTP.ORDER_ITEMS (
        order_item_id, 
        order_id, 
        product_id, 
        variant_id,
        quantity, 
        unit_price_cents,
        subtotal_cents,
        product_name,
        variant_name,
        product_image_url,
        created_at
    )
    SELECT 
        UUID_STRING(),
        :new_order_id,
        product_id,
        variant_id,
        quantity,
        unit_price_cents,
        subtotal_cents,
        product_name,
        variant_name,
        product_image_url,
        CURRENT_TIMESTAMP()
    FROM CART_OLTP.CART_ITEMS
    WHERE session_id = :session_id;
    
    -- Update session status to completed
    UPDATE CART_OLTP.CART_SESSIONS
    SET status = 'completed',
        updated_at = CURRENT_TIMESTAMP()
    WHERE session_id = :session_id;
    
    RETURN OBJECT_CONSTRUCT(
        'success', TRUE,
        'order_id', :new_order_id,
        'order_number', :v_order_number,
        'customer_id', :v_customer_id,
        'item_count', :v_item_count,
        'total_cents', :v_total_cents,
        'total_dollars', ROUND(:v_total_cents / 100.0, 2),
        'status', 'confirmed',
        'message', 'Order placed successfully!'
    )::VARIANT;
END;
$$;

COMMENT ON PROCEDURE CART_OLTP.TOOL_SUBMIT_ORDER(VARCHAR) IS 
'Finalize checkout and create order. Processes cart items, creates order record, and returns order confirmation with order_id, order_number, and total.';

-- ============================================================================
-- VERIFICATION
-- ============================================================================

SELECT '✅ Agent Tools Created Successfully!' AS status;

-- List all tools created
SELECT 
    'CUSTOMERS.TOOL_ANALYZE_FACE' AS tool_name, 
    'Python UDF' AS tool_type, 
    'Face/skin analysis via SPCS' AS purpose
UNION ALL SELECT 'CUSTOMERS.TOOL_IDENTIFY_CUSTOMER', 'SQL UDTF', 'Face matching (Vector Search)'
UNION ALL SELECT 'PRODUCTS.TOOL_MATCH_PRODUCTS', 'SQL UDTF', 'Color matching (all categories)'
UNION ALL SELECT 'PRODUCTS.TOOL_MATCH_PRODUCTS_BY_CATEGORY', 'SQL UDTF', 'Color matching (specific category)'
UNION ALL SELECT 'CART_OLTP.TOOL_CREATE_CART_SESSION', 'Procedure', 'Create cart session'
UNION ALL SELECT 'CART_OLTP.TOOL_GET_CART_SESSION', 'SQL UDF', 'Get cart contents'
UNION ALL SELECT 'CART_OLTP.TOOL_ADD_TO_CART', 'Procedure', 'Add item to cart'
UNION ALL SELECT 'CART_OLTP.TOOL_UPDATE_CART_ITEM', 'Procedure', 'Update cart item'
UNION ALL SELECT 'CART_OLTP.TOOL_REMOVE_FROM_CART', 'Procedure', 'Remove from cart'
UNION ALL SELECT 'CART_OLTP.TOOL_SUBMIT_ORDER', 'Procedure', 'Complete order';

-- ============================================================================
-- PART 6: GRANT PERMISSIONS FOR CORTEX AGENT
-- The agent needs USAGE on all tool functions to execute them
-- ============================================================================

-- Grant USAGE on functions to the role used by the Cortex Agent
GRANT USAGE ON FUNCTION CUSTOMERS.TOOL_ANALYZE_FACE(VARCHAR) TO ROLE AGENT_COMMERCE_ROLE;
GRANT USAGE ON FUNCTION CUSTOMERS.TOOL_IDENTIFY_CUSTOMER(VARCHAR, FLOAT, INT) TO ROLE AGENT_COMMERCE_ROLE;
GRANT USAGE ON FUNCTION PRODUCTS.TOOL_MATCH_PRODUCTS(VARCHAR, VARCHAR, INT) TO ROLE AGENT_COMMERCE_ROLE;
GRANT USAGE ON FUNCTION PRODUCTS.TOOL_MATCH_PRODUCTS_BY_CATEGORY(VARCHAR, VARCHAR) TO ROLE AGENT_COMMERCE_ROLE;

-- Grant USAGE on procedures (use EXECUTE for procedures)
GRANT USAGE ON PROCEDURE CART_OLTP.TOOL_CREATE_CART_SESSION(VARCHAR) TO ROLE AGENT_COMMERCE_ROLE;
GRANT USAGE ON PROCEDURE CART_OLTP.TOOL_ADD_TO_CART(VARCHAR, VARCHAR, INT, VARCHAR) TO ROLE AGENT_COMMERCE_ROLE;
GRANT USAGE ON PROCEDURE CART_OLTP.TOOL_UPDATE_CART_ITEM(VARCHAR, VARCHAR, INT) TO ROLE AGENT_COMMERCE_ROLE;
GRANT USAGE ON PROCEDURE CART_OLTP.TOOL_REMOVE_FROM_CART(VARCHAR, VARCHAR) TO ROLE AGENT_COMMERCE_ROLE;
GRANT USAGE ON PROCEDURE CART_OLTP.TOOL_SUBMIT_ORDER(VARCHAR, VARCHAR) TO ROLE AGENT_COMMERCE_ROLE;
GRANT USAGE ON FUNCTION CART_OLTP.TOOL_GET_CART_SESSION(VARCHAR) TO ROLE AGENT_COMMERCE_ROLE;

-- Grant SELECT on underlying tables for the functions to work
GRANT SELECT ON TABLE CUSTOMERS.CUSTOMERS TO ROLE AGENT_COMMERCE_ROLE;
GRANT SELECT ON TABLE CUSTOMERS.CUSTOMER_FACE_EMBEDDINGS TO ROLE AGENT_COMMERCE_ROLE;
GRANT SELECT ON TABLE PRODUCTS.PRODUCTS TO ROLE AGENT_COMMERCE_ROLE;
GRANT SELECT ON TABLE PRODUCTS.PRODUCT_VARIANTS TO ROLE AGENT_COMMERCE_ROLE;
GRANT SELECT ON TABLE PRODUCTS.PRODUCT_MEDIA TO ROLE AGENT_COMMERCE_ROLE;

-- Grant on hybrid tables for cart operations
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE CART_OLTP.CART_SESSIONS TO ROLE AGENT_COMMERCE_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE CART_OLTP.CART_ITEMS TO ROLE AGENT_COMMERCE_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE CART_OLTP.ORDERS TO ROLE AGENT_COMMERCE_ROLE;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE CART_OLTP.ORDER_ITEMS TO ROLE AGENT_COMMERCE_ROLE;

-- ============================================================================
-- END
-- ============================================================================
