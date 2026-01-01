-- ============================================================================
-- AGENT COMMERCE - Vector Search for Face Embeddings
-- ============================================================================
-- This script creates vector similarity search procedures for customer
-- identification via face embeddings.
--
-- Uses Snowflake's native VECTOR data type and similarity functions.
-- The CUSTOMER_FACE_EMBEDDINGS table stores 128-dim dlib face embeddings.
--
-- Note: VECTOR type not supported as procedure parameter, so we accept ARRAY
-- and cast to VECTOR inside the procedure.
--
-- Run after 04_create_cortex_search.sql
-- ============================================================================

USE ROLE AGENT_COMMERCE_ROLE;
USE DATABASE AGENT_COMMERCE;
USE WAREHOUSE AGENT_COMMERCE_WH;
USE SCHEMA CUSTOMERS;

-- ============================================================================
-- VECTOR SIMILARITY SEARCH PROCEDURES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Find Customer by Face Embedding
-- Returns matching customers ranked by similarity score
-- 
-- Confidence Levels:
--   HIGH   (≥0.95): Very likely same person - auto-login candidate
--   MEDIUM (≥0.85): Probably same person - confirm identity
--   LOW    (≥0.70): Possible match - ask for verification
--   NONE   (<0.70): No match - new customer flow
--
-- Usage: CALL FIND_CUSTOMER_BY_FACE(ARRAY_CONSTRUCT(0.1, 0.2, ...), 0.85, 5);
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE FIND_CUSTOMER_BY_FACE(
    query_embedding_array ARRAY,
    similarity_threshold FLOAT DEFAULT 0.70,
    max_results INTEGER DEFAULT 5
)
RETURNS TABLE (
    customer_id VARCHAR,
    email VARCHAR,
    first_name VARCHAR,
    last_name VARCHAR,
    loyalty_tier VARCHAR,
    similarity_score FLOAT,
    confidence_level VARCHAR
)
LANGUAGE SQL
AS
DECLARE
    res RESULTSET;
BEGIN
    -- Cast ARRAY to VECTOR and perform similarity search
    res := (
        SELECT 
            c.customer_id,
            c.email,
            c.first_name,
            c.last_name,
            c.loyalty_tier,
            VECTOR_COSINE_SIMILARITY(e.embedding, :query_embedding_array::VECTOR(FLOAT, 128)) AS similarity_score,
            CASE 
                WHEN VECTOR_COSINE_SIMILARITY(e.embedding, :query_embedding_array::VECTOR(FLOAT, 128)) >= 0.95 THEN 'HIGH'
                WHEN VECTOR_COSINE_SIMILARITY(e.embedding, :query_embedding_array::VECTOR(FLOAT, 128)) >= 0.85 THEN 'MEDIUM'
                WHEN VECTOR_COSINE_SIMILARITY(e.embedding, :query_embedding_array::VECTOR(FLOAT, 128)) >= 0.70 THEN 'LOW'
                ELSE 'NONE'
            END AS confidence_level
        FROM CUSTOMER_FACE_EMBEDDINGS e
        JOIN CUSTOMERS c ON e.customer_id = c.customer_id
        WHERE e.is_active = TRUE
          AND c.is_active = TRUE
          AND VECTOR_COSINE_SIMILARITY(e.embedding, :query_embedding_array::VECTOR(FLOAT, 128)) >= :similarity_threshold
        ORDER BY similarity_score DESC
        LIMIT :max_results
    );
    RETURN TABLE(res);
END;

-- ----------------------------------------------------------------------------
-- Quick Check: Does Customer Exist?
-- Returns a single object with match status
--
-- Usage: CALL CHECK_CUSTOMER_EXISTS(ARRAY_CONSTRUCT(0.1, 0.2, ...), 0.85);
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE CHECK_CUSTOMER_EXISTS(
    query_embedding_array ARRAY,
    threshold FLOAT DEFAULT 0.85
)
RETURNS OBJECT
LANGUAGE SQL
AS
DECLARE
    v_result OBJECT;
    v_customer_id VARCHAR;
    v_first_name VARCHAR;
    v_last_name VARCHAR;
    v_similarity FLOAT;
    v_confidence VARCHAR;
    v_found BOOLEAN DEFAULT FALSE;
BEGIN
    -- Find best match using ARRAY cast to VECTOR
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
        VECTOR_COSINE_SIMILARITY(e.embedding, :query_embedding_array::VECTOR(FLOAT, 128)) AS similarity_score,
        CASE 
            WHEN VECTOR_COSINE_SIMILARITY(e.embedding, :query_embedding_array::VECTOR(FLOAT, 128)) >= 0.95 THEN 'HIGH'
            WHEN VECTOR_COSINE_SIMILARITY(e.embedding, :query_embedding_array::VECTOR(FLOAT, 128)) >= 0.85 THEN 'MEDIUM'
            WHEN VECTOR_COSINE_SIMILARITY(e.embedding, :query_embedding_array::VECTOR(FLOAT, 128)) >= 0.70 THEN 'LOW'
            ELSE 'NONE'
        END AS confidence_level
    INTO :v_customer_id, :v_first_name, :v_last_name, :v_similarity, :v_confidence
    FROM CUSTOMER_FACE_EMBEDDINGS e
    JOIN CUSTOMERS c ON e.customer_id = c.customer_id
    WHERE e.is_active = TRUE
      AND c.is_active = TRUE
    ORDER BY similarity_score DESC
    LIMIT 1;
    
    -- Check if above threshold
    IF (v_similarity IS NOT NULL AND v_similarity >= threshold) THEN
        v_found := TRUE;
    END IF;
    
    v_result := OBJECT_CONSTRUCT(
        'found', v_found,
        'customer_id', v_customer_id,
        'first_name', v_first_name,
        'last_name', v_last_name,
        'similarity_score', v_similarity,
        'confidence_level', v_confidence
    );
    
    RETURN v_result;
EXCEPTION
    WHEN OTHER THEN
        RETURN OBJECT_CONSTRUCT(
            'found', FALSE,
            'customer_id', NULL,
            'similarity_score', NULL,
            'confidence_level', 'NONE',
            'error', SQLERRM
        );
END;

-- ----------------------------------------------------------------------------
-- Register New Face Embedding for Customer
-- Adds a new face embedding linked to an existing customer
--
-- Usage: CALL REGISTER_FACE_EMBEDDING('customer-id', ARRAY_CONSTRUCT(0.1,...), 0.95, 'good', 'frontal', 'widget_camera');
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE REGISTER_FACE_EMBEDDING(
    p_customer_id VARCHAR,
    p_embedding_array ARRAY,
    p_quality_score FLOAT DEFAULT NULL,
    p_lighting_condition VARCHAR DEFAULT NULL,
    p_face_angle VARCHAR DEFAULT NULL,
    p_source VARCHAR DEFAULT 'widget_camera'
)
RETURNS OBJECT
LANGUAGE SQL
AS
DECLARE
    v_embedding_id VARCHAR;
    v_customer_exists BOOLEAN;
BEGIN
    -- Check if customer exists
    SELECT COUNT(*) > 0 INTO v_customer_exists
    FROM CUSTOMERS 
    WHERE customer_id = :p_customer_id AND is_active = TRUE;
    
    IF (NOT v_customer_exists) THEN
        RETURN OBJECT_CONSTRUCT(
            'success', FALSE,
            'error', 'Customer not found or inactive'
        );
    END IF;
    
    -- Generate embedding ID
    v_embedding_id := UUID_STRING();
    
    -- Insert the embedding (cast ARRAY to VECTOR)
    INSERT INTO CUSTOMER_FACE_EMBEDDINGS (
        embedding_id,
        customer_id,
        embedding,
        quality_score,
        lighting_condition,
        face_angle,
        is_active,
        is_primary,
        source,
        created_at
    ) VALUES (
        :v_embedding_id,
        :p_customer_id,
        :p_embedding_array::VECTOR(FLOAT, 128),
        :p_quality_score,
        :p_lighting_condition,
        :p_face_angle,
        TRUE,
        FALSE,
        :p_source,
        CURRENT_TIMESTAMP()
    );
    
    RETURN OBJECT_CONSTRUCT(
        'success', TRUE,
        'embedding_id', v_embedding_id,
        'customer_id', p_customer_id
    );
END;

-- ----------------------------------------------------------------------------
-- Find Similar Customers (for grouping/segmentation)
-- Given a customer, find others with similar face features
--
-- Usage: CALL FIND_SIMILAR_CUSTOMERS('customer-id', 0.80, 10);
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE FIND_SIMILAR_CUSTOMERS(
    source_customer_id VARCHAR,
    similarity_threshold FLOAT DEFAULT 0.80,
    max_results INTEGER DEFAULT 10
)
RETURNS TABLE (
    customer_id VARCHAR,
    email VARCHAR,
    first_name VARCHAR,
    last_name VARCHAR,
    similarity_score FLOAT
)
LANGUAGE SQL
AS
DECLARE
    res RESULTSET;
BEGIN
    res := (
        WITH source_embedding AS (
            SELECT embedding
            FROM CUSTOMER_FACE_EMBEDDINGS
            WHERE customer_id = :source_customer_id
              AND is_active = TRUE
              AND is_primary = TRUE
            LIMIT 1
        )
        SELECT 
            c.customer_id,
            c.email,
            c.first_name,
            c.last_name,
            VECTOR_COSINE_SIMILARITY(e.embedding, se.embedding) AS similarity_score
        FROM CUSTOMER_FACE_EMBEDDINGS e
        JOIN CUSTOMERS c ON e.customer_id = c.customer_id
        CROSS JOIN source_embedding se
        WHERE e.is_active = TRUE
          AND c.is_active = TRUE
          AND c.customer_id != :source_customer_id
          AND VECTOR_COSINE_SIMILARITY(e.embedding, se.embedding) >= :similarity_threshold
        ORDER BY similarity_score DESC
        LIMIT :max_results
    );
    RETURN TABLE(res);
END;

-- ----------------------------------------------------------------------------
-- Deactivate Face Embedding (GDPR/Privacy compliance)
-- Soft-deletes a face embedding
--
-- Usage: CALL DEACTIVATE_FACE_EMBEDDING('embedding-id');
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE DEACTIVATE_FACE_EMBEDDING(
    p_embedding_id VARCHAR
)
RETURNS OBJECT
LANGUAGE SQL
AS
BEGIN
    UPDATE CUSTOMER_FACE_EMBEDDINGS
    SET is_active = FALSE
    WHERE embedding_id = :p_embedding_id;
    
    RETURN OBJECT_CONSTRUCT(
        'success', TRUE,
        'embedding_id', p_embedding_id,
        'action', 'deactivated'
    );
END;

-- ----------------------------------------------------------------------------
-- Deactivate All Face Embeddings for Customer (GDPR right to erasure)
--
-- Usage: CALL DEACTIVATE_ALL_CUSTOMER_EMBEDDINGS('customer-id');
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE DEACTIVATE_ALL_CUSTOMER_EMBEDDINGS(
    p_customer_id VARCHAR
)
RETURNS OBJECT
LANGUAGE SQL
AS
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE CUSTOMER_FACE_EMBEDDINGS
    SET is_active = FALSE
    WHERE customer_id = :p_customer_id;
    
    SELECT COUNT(*) INTO v_count
    FROM CUSTOMER_FACE_EMBEDDINGS
    WHERE customer_id = :p_customer_id AND is_active = FALSE;
    
    RETURN OBJECT_CONSTRUCT(
        'success', TRUE,
        'customer_id', p_customer_id,
        'embeddings_deactivated', v_count
    );
END;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

-- Show procedures
SHOW PROCEDURES IN SCHEMA CUSTOMERS;

-- ============================================================================
-- USAGE EXAMPLES
-- ============================================================================
--
-- 1. Find customer by face (pass embedding as ARRAY):
-- CALL FIND_CUSTOMER_BY_FACE(
--   ARRAY_CONSTRUCT(0.1, -0.2, 0.3, ...),  -- 128 float values
--   0.85,  -- similarity threshold
--   3      -- max results
-- );
--
-- 2. Quick check if customer exists:
-- CALL CHECK_CUSTOMER_EXISTS(
--   ARRAY_CONSTRUCT(0.1, -0.2, 0.3, ...),  -- 128 float values
--   0.85  -- threshold
-- );
-- 
-- Returns: {"found": true, "customer_id": "abc123", "confidence_level": "HIGH", ...}
--
-- 3. Register new embedding for existing customer:
-- CALL REGISTER_FACE_EMBEDDING(
--   'customer-uuid-here',
--   ARRAY_CONSTRUCT(0.1, -0.2, 0.3, ...),  -- 128 float values
--   0.95,           -- quality score
--   'good',         -- lighting condition
--   'frontal',      -- face angle
--   'widget_camera' -- source
-- );
--
-- 4. Find similar customers (uses customer_id, embedding looked up internally):
-- CALL FIND_SIMILAR_CUSTOMERS('customer-uuid', 0.80, 10);
--
-- 5. GDPR: Deactivate all face data for a customer:
-- CALL DEACTIVATE_ALL_CUSTOMER_EMBEDDINGS('customer-uuid-here');
--
-- ============================================================================
-- NOTE: From Python/FastAPI backend, convert numpy array to list before calling:
--   embedding_list = face_embedding.tolist()  # numpy array to Python list
--   Then pass to Snowflake as ARRAY_CONSTRUCT(...)
-- ============================================================================

-- ============================================================================
-- NEXT STEPS:
-- 1. Run sql/06_load_sample_data.sql to populate tables with test data
-- 2. Create the SPCS backend service for ML (face detection, analysis)
-- ============================================================================
