-- ============================================================================
-- AGENT COMMERCE - Agent Tools (UDFs & Stored Procedures)
-- ============================================================================
-- This script creates custom tools for the Cortex Agent that cannot be 
-- handled by Cortex Analyst (semantic views) or Cortex Search.
--
-- TOOLS CREATED (9):
-- ┌─────────────────────────────────────────┬─────────────┬──────────────────────────────┐
-- │ Tool                                    │ Type        │ Purpose                      │
-- ├─────────────────────────────────────────┼─────────────┼──────────────────────────────┤
-- │ CUSTOMERS.TOOL_ANALYZE_FACE             │ Python UDF  │ Face/skin analysis via SPCS  │
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
--   - SPCS backend running (for TOOL_ANALYZE_FACE)
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
-- Calls SPCS backend for ML processing
-- 
-- NOTE: This UDF calls the SPCS backend. For it to work:
--   1. The SPCS service must be running
--   2. If calling from outside SPCS, you need EXTERNAL ACCESS INTEGRATION
--   3. Inside SPCS network, services communicate via internal DNS
-- ----------------------------------------------------------------------------
USE SCHEMA CUSTOMERS;

CREATE OR REPLACE FUNCTION CUSTOMERS.TOOL_ANALYZE_FACE(image_base64 VARCHAR)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python', 'requests')
HANDLER = 'analyze_face'
AS
$$
import json

def analyze_face(image_base64):
    """
    Analyze face from base64 image.
    Returns: embedding, skin_tone, lip_color, fitzpatrick, monk_shade, undertone
    
    NOTE: This function calls SPCS endpoints. It works when:
    - Running inside SPCS network (service-to-service)
    - Or with proper EXTERNAL ACCESS INTEGRATION configured
    """
    try:
        import requests
        
        # SPCS backend internal DNS
        spcs_url = "http://agent-commerce-backend:8000"
        
        # Extract embedding
        embedding_response = requests.post(
            f"{spcs_url}/extract-embedding",
            json={"image_base64": image_base64},
            timeout=30
        )
        embedding_result = embedding_response.json()
        
        # Analyze skin
        skin_response = requests.post(
            f"{spcs_url}/analyze-skin",
            json={"image_base64": image_base64},
            timeout=30
        )
        skin_result = skin_response.json()
        
        return {
            "success": True,
            "face_detected": embedding_result.get("face_detected", False),
            "embedding": embedding_result.get("embedding"),
            "quality_score": embedding_result.get("quality_score"),
            "skin_hex": skin_result.get("skin_hex"),
            "skin_rgb": skin_result.get("skin_rgb"),
            "skin_lab": skin_result.get("skin_lab"),
            "lip_hex": skin_result.get("lip_hex"),
            "lip_rgb": skin_result.get("lip_rgb"),
            "fitzpatrick_type": skin_result.get("fitzpatrick_type"),
            "monk_shade": skin_result.get("monk_shade"),
            "undertone": skin_result.get("undertone")
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }
$$;

COMMENT ON FUNCTION CUSTOMERS.TOOL_ANALYZE_FACE(VARCHAR) IS 
'Analyze face from uploaded image (base64). Returns embedding (128-dim), skin tone (hex, RGB, LAB), lip color, Fitzpatrick type (1-6), Monk shade (1-10), and undertone (warm/cool/neutral). Requires SPCS backend.';

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

CREATE OR REPLACE FUNCTION CUSTOMERS.TOOL_IDENTIFY_CUSTOMER(
    query_embedding_json VARCHAR,
    match_threshold FLOAT DEFAULT 0.6,
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
                'match_confidence', match_confidence
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
            -- Confidence: distance < 0.6 = same person (dlib threshold)
            -- Map distance 0-1.5 to confidence 1-0
            ROUND(GREATEST(0, LEAST(1, 1 - (VECTOR_L2_DISTANCE(
                e.embedding, 
                PARSE_JSON(query_embedding_json)::VECTOR(FLOAT, 128)
            ) / 1.5))), 3) AS match_confidence
        FROM CUSTOMERS.CUSTOMER_FACE_EMBEDDINGS e
        JOIN CUSTOMERS.CUSTOMERS c ON e.customer_id = c.customer_id
        WHERE e.is_primary = TRUE
        ORDER BY distance ASC
        LIMIT 5
    )
$$;

COMMENT ON FUNCTION CUSTOMERS.TOOL_IDENTIFY_CUSTOMER(VARCHAR, FLOAT, INT) IS 
'Identify customer by matching face embedding against stored embeddings. Pass embedding as JSON string (e.g., "[0.1, 0.2, ...]"). Returns top 5 matching customers with confidence scores, loyalty tier, and points.';

-- ----------------------------------------------------------------------------
-- Tool: TOOL_MATCH_PRODUCTS
-- Color matching using Euclidean RGB distance
-- IMPORTANT: Returns ARRAY (scalar function) for Cortex Agent compatibility
-- Table functions (UDTF) are NOT supported by Cortex Agent generic tools
-- ----------------------------------------------------------------------------
USE SCHEMA PRODUCTS;

-- Drop existing table function to avoid overload ambiguity
DROP FUNCTION IF EXISTS PRODUCTS.TOOL_MATCH_PRODUCTS(VARCHAR, VARCHAR, INT);

CREATE OR REPLACE FUNCTION PRODUCTS.TOOL_MATCH_PRODUCTS(
    target_hex VARCHAR,
    category_filter VARCHAR DEFAULT NULL,
    limit_results INT DEFAULT 10
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
          AND (category_filter IS NULL OR LOWER(p.category) = LOWER(category_filter))
        ORDER BY color_distance ASC
        LIMIT 10
    )
$$;

COMMENT ON FUNCTION PRODUCTS.TOOL_MATCH_PRODUCTS(VARCHAR, VARCHAR, INT) IS 
'Find products matching a target color (hex format like #E75480). Optional category_filter (lips, eyes, face, skincare) and limit_results (default 10). Returns array of products sorted by color distance (lower = closer match).';

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
    customer_id_param VARCHAR
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
        :customer_id_param, 
        'active',
        0,
        0,
        'USD',
        CURRENT_TIMESTAMP()
    );
    
    RETURN OBJECT_CONSTRUCT(
        'success', TRUE,
        'session_id', :new_session_id,
        'customer_id', :customer_id_param,
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
CREATE OR REPLACE FUNCTION CART_OLTP.TOOL_GET_CART_SESSION(session_id_param VARCHAR)
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
            SELECT COUNT(*) FROM CART_OLTP.CART_ITEMS WHERE session_id = s.session_id
        ),
        'subtotal_cents', s.subtotal_cents,
        'total_cents', s.total_cents,
        'created_at', s.created_at
    )::VARIANT
    FROM CART_OLTP.CART_SESSIONS s
    WHERE s.session_id = session_id_param
$$;

COMMENT ON FUNCTION CART_OLTP.TOOL_GET_CART_SESSION(VARCHAR) IS 
'Get cart session with all items, quantities, prices (in cents), and totals.';

-- ----------------------------------------------------------------------------
-- Tool: TOOL_ADD_TO_CART
-- Add a product to the cart
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE CART_OLTP.TOOL_ADD_TO_CART(
    session_id_param VARCHAR,
    product_id_param VARCHAR,
    quantity_param INT,
    variant_id_param VARCHAR
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
BEGIN
    -- Get product price (assuming price is in dollars, convert to cents)
    SELECT 
        ROUND(COALESCE(sale_price, price) * 100)::INT,
        name
    INTO :v_unit_price_cents, :v_product_name
    FROM PRODUCTS.PRODUCTS
    WHERE product_id = :product_id_param;
    
    -- Calculate subtotal
    v_subtotal_cents := :v_unit_price_cents * :quantity_param;
    
    -- Generate item ID
    new_item_id := UUID_STRING();
    
    -- Insert cart item
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
        :session_id_param, 
        :product_id_param, 
        :variant_id_param,
        :quantity_param, 
        :v_unit_price_cents, 
        :v_subtotal_cents,
        :v_product_name,
        CURRENT_TIMESTAMP()
    );
    
    -- Update session subtotal
    SELECT SUM(subtotal_cents) INTO :v_session_subtotal
    FROM CART_OLTP.CART_ITEMS
    WHERE session_id = :session_id_param;
    
    UPDATE CART_OLTP.CART_SESSIONS
    SET subtotal_cents = :v_session_subtotal,
        total_cents = :v_session_subtotal,  -- Simplified, no tax/shipping
        updated_at = CURRENT_TIMESTAMP()
    WHERE session_id = :session_id_param;
    
    RETURN OBJECT_CONSTRUCT(
        'success', TRUE,
        'item_id', :new_item_id,
        'product_id', :product_id_param,
        'product_name', :v_product_name,
        'quantity', :quantity_param,
        'unit_price_cents', :v_unit_price_cents,
        'subtotal_cents', :v_subtotal_cents,
        'message', 'Item added to cart'
    )::VARIANT;
END;
$$;

COMMENT ON PROCEDURE CART_OLTP.TOOL_ADD_TO_CART(VARCHAR, VARCHAR, INT, VARCHAR) IS 
'Add a product to cart. Parameters: session_id, product_id, quantity, variant_id (optional, pass NULL if not needed).';

-- ----------------------------------------------------------------------------
-- Tool: TOOL_UPDATE_CART_ITEM
-- Update quantity of a cart item
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE CART_OLTP.TOOL_UPDATE_CART_ITEM(
    item_id_param VARCHAR,
    new_quantity_param INT
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
BEGIN
    -- Get item details
    SELECT session_id, unit_price_cents 
    INTO :v_session_id, :v_unit_price_cents
    FROM CART_OLTP.CART_ITEMS
    WHERE item_id = :item_id_param;
    
    -- Calculate new subtotal
    v_new_subtotal_cents := :v_unit_price_cents * :new_quantity_param;
    
    -- Update cart item
    UPDATE CART_OLTP.CART_ITEMS
    SET quantity = :new_quantity_param,
        subtotal_cents = :v_new_subtotal_cents,
        updated_at = CURRENT_TIMESTAMP()
    WHERE item_id = :item_id_param;
    
    -- Update session subtotal
    SELECT SUM(subtotal_cents) INTO :v_session_subtotal
    FROM CART_OLTP.CART_ITEMS
    WHERE session_id = :v_session_id;
    
    UPDATE CART_OLTP.CART_SESSIONS
    SET subtotal_cents = :v_session_subtotal,
        total_cents = :v_session_subtotal,
        updated_at = CURRENT_TIMESTAMP()
    WHERE session_id = :v_session_id;
    
    RETURN OBJECT_CONSTRUCT(
        'success', TRUE,
        'item_id', :item_id_param,
        'new_quantity', :new_quantity_param,
        'new_subtotal_cents', :v_new_subtotal_cents,
        'message', 'Cart item updated'
    )::VARIANT;
END;
$$;

COMMENT ON PROCEDURE CART_OLTP.TOOL_UPDATE_CART_ITEM(VARCHAR, INT) IS 
'Update the quantity of an item in the cart.';

-- ----------------------------------------------------------------------------
-- Tool: TOOL_REMOVE_FROM_CART
-- Remove an item from the cart
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE CART_OLTP.TOOL_REMOVE_FROM_CART(
    item_id_param VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    v_session_id VARCHAR;
    v_session_subtotal INT;
BEGIN
    -- Get session ID before deleting
    SELECT session_id INTO :v_session_id
    FROM CART_OLTP.CART_ITEMS
    WHERE item_id = :item_id_param;
    
    -- Delete the item
    DELETE FROM CART_OLTP.CART_ITEMS 
    WHERE item_id = :item_id_param;
    
    -- Update session subtotal
    SELECT COALESCE(SUM(subtotal_cents), 0) INTO :v_session_subtotal
    FROM CART_OLTP.CART_ITEMS
    WHERE session_id = :v_session_id;
    
    UPDATE CART_OLTP.CART_SESSIONS
    SET subtotal_cents = :v_session_subtotal,
        total_cents = :v_session_subtotal,
        updated_at = CURRENT_TIMESTAMP()
    WHERE session_id = :v_session_id;
    
    RETURN OBJECT_CONSTRUCT(
        'success', TRUE,
        'removed_item_id', :item_id_param,
        'message', 'Item removed from cart'
    )::VARIANT;
END;
$$;

COMMENT ON PROCEDURE CART_OLTP.TOOL_REMOVE_FROM_CART(VARCHAR) IS 
'Remove an item from the cart.';

-- ----------------------------------------------------------------------------
-- Tool: TOOL_SUBMIT_ORDER
-- Complete the order
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE CART_OLTP.TOOL_SUBMIT_ORDER(
    session_id_param VARCHAR
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
    WHERE session_id = :session_id_param;
    
    -- Count items
    SELECT COUNT(*) INTO :v_item_count
    FROM CART_OLTP.CART_ITEMS
    WHERE session_id = :session_id_param;
    
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
        :session_id_param,
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
    WHERE session_id = :session_id_param;
    
    -- Update session status to completed
    UPDATE CART_OLTP.CART_SESSIONS
    SET status = 'completed',
        updated_at = CURRENT_TIMESTAMP()
    WHERE session_id = :session_id_param;
    
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
