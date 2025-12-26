-- ============================================================================
-- AGENT COMMERCE - SPCS Backend Deployment
-- ============================================================================
-- This script deploys the FastAPI backend as a Snowpark Container Service.
--
-- Prerequisites:
--   1. Docker image built and pushed to Snowflake Image Repository
--   2. Compute pool created (01_setup_database.sql)
--   3. All tables created (02_create_tables.sql)
--
-- ============================================================================

USE ROLE AGENT_COMMERCE_ROLE;
USE DATABASE AGENT_COMMERCE;
USE WAREHOUSE AGENT_COMMERCE_WH;
USE SCHEMA UTIL;

-- ============================================================================
-- STEP 1: VERIFY IMAGE REPOSITORY
-- ============================================================================

-- Check image repository exists
SHOW IMAGE REPOSITORIES IN SCHEMA UTIL;

-- Get repository URL (use this for docker push)
SELECT REPOSITORY_URL 
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) 
WHERE "name" = 'AGENT_COMMERCE_REPO';

-- ============================================================================
-- STEP 2: BUILD AND PUSH DOCKER IMAGE
-- ============================================================================
-- Run these commands from terminal AFTER creating the image repository:
--
-- # 1. Login to Snowflake container registry
-- docker login <repository_url>
--
-- # 2. Build the image
-- cd beauty_analyzer/backend
-- docker build --platform linux/amd64 -t agent-commerce-backend:latest .
--
-- # 3. Tag for Snowflake repository
-- docker tag agent-commerce-backend:latest <repository_url>/agent-commerce-backend:latest
--
-- # 4. Push to Snowflake
-- docker push <repository_url>/agent-commerce-backend:latest
--
-- Example with actual repository URL:
-- docker login sfsenorthamerica-demo.registry.snowflakecomputing.com
-- docker tag agent-commerce-backend:latest \
--   sfsenorthamerica-demo.registry.snowflakecomputing.com/agent_commerce/util/agent_commerce_repo/agent-commerce-backend:latest
-- docker push sfsenorthamerica-demo.registry.snowflakecomputing.com/agent_commerce/util/agent_commerce_repo/agent-commerce-backend:latest
--
-- ============================================================================

-- ============================================================================
-- STEP 3: CREATE SERVICE SPECIFICATION
-- ============================================================================

-- Create the SPCS service
CREATE SERVICE IF NOT EXISTS UTIL.AGENT_COMMERCE_BACKEND
    IN COMPUTE POOL AGENT_COMMERCE_POOL
    FROM SPECIFICATION $$
    spec:
      containers:
        - name: backend
          image: /AGENT_COMMERCE/UTIL/AGENT_COMMERCE_REPO/agent-commerce-backend:latest
          resources:
            requests:
              cpu: 1
              memory: 4Gi
            limits:
              cpu: 2
              memory: 8Gi
          env:
            SNOWFLAKE_ACCOUNT: "{{ snowflake.account }}"
            SNOWFLAKE_USER: "{{ snowflake.user }}"
            SNOWFLAKE_DATABASE: "AGENT_COMMERCE"
            SNOWFLAKE_SCHEMA: "CUSTOMERS"
          readinessProbe:
            port: 8000
            path: /health
      endpoints:
        - name: api
          port: 8000
          public: true
    $$
    MIN_INSTANCES = 1
    MAX_INSTANCES = 3
    QUERY_WAREHOUSE = AGENT_COMMERCE_WH
    COMMENT = 'Face recognition and skin analysis backend service';

-- ============================================================================
-- STEP 4: VERIFY SERVICE STATUS
-- ============================================================================

-- Check service status
SHOW SERVICES IN SCHEMA UTIL;

-- Get service status
SELECT SYSTEM$GET_SERVICE_STATUS('UTIL.AGENT_COMMERCE_BACKEND');

-- Get service logs (for debugging)
SELECT SYSTEM$GET_SERVICE_LOGS('UTIL.AGENT_COMMERCE_BACKEND', 0, 'backend', 100);

-- Get public endpoint URL
SHOW ENDPOINTS IN SERVICE UTIL.AGENT_COMMERCE_BACKEND;

-- ============================================================================
-- STEP 5: CREATE SERVICE FUNCTIONS
-- ============================================================================
-- These SQL functions wrap the REST API endpoints for easier calling

-- Extract face embedding function
CREATE OR REPLACE FUNCTION CUSTOMERS.EXTRACT_FACE_EMBEDDING(image_base64 VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
    SELECT SYSTEM$CALL_SPCS_SERVICE(
        '/AGENT_COMMERCE/UTIL/AGENT_COMMERCE_BACKEND',
        'api',
        'POST',
        '/extract-embedding',
        OBJECT_CONSTRUCT('image_base64', image_base64)
    )
$$;

-- Analyze skin function
CREATE OR REPLACE FUNCTION CUSTOMERS.ANALYZE_SKIN(image_base64 VARCHAR)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
    SELECT SYSTEM$CALL_SPCS_SERVICE(
        '/AGENT_COMMERCE/UTIL/AGENT_COMMERCE_BACKEND',
        'api',
        'POST',
        '/analyze-skin',
        OBJECT_CONSTRUCT('image_base64', image_base64)
    )
$$;

-- ============================================================================
-- STEP 6: TEST SERVICE FUNCTIONS
-- ============================================================================

-- Test health check (simple)
SELECT SYSTEM$CALL_SPCS_SERVICE(
    '/AGENT_COMMERCE/UTIL/AGENT_COMMERCE_BACKEND',
    'api',
    'POST',
    '/health',
    NULL
) AS health_check;

-- ============================================================================
-- STEP 7: CREATE BATCH EMBEDDING EXTRACTION PROCEDURE
-- ============================================================================
-- This procedure processes FairFace images and populates CUSTOMER_FACE_EMBEDDINGS

CREATE OR REPLACE PROCEDURE CUSTOMERS.BATCH_EXTRACT_EMBEDDINGS(
    stage_path VARCHAR,
    batch_size INTEGER DEFAULT 100
)
RETURNS TABLE (customer_id VARCHAR, success BOOLEAN, error VARCHAR)
LANGUAGE SQL
AS
$$
DECLARE
    result_set RESULTSET;
    processed_count INTEGER DEFAULT 0;
    error_count INTEGER DEFAULT 0;
BEGIN
    -- Get list of images from stage
    LET images RESULTSET := (
        SELECT 
            c.customer_id,
            '@' || :stage_path || '/' || SPLIT_PART(e.source, '/', -1) AS image_path
        FROM CUSTOMERS.CUSTOMERS c
        JOIN CUSTOMERS.CUSTOMER_FACE_EMBEDDINGS e ON c.customer_id = e.customer_id
        WHERE e.source LIKE 'fairface%'
        LIMIT :batch_size
    );
    
    -- Process each image through SPCS backend
    FOR record IN images DO
        BEGIN
            -- Read image from stage and convert to base64
            LET image_data VARCHAR := (
                SELECT BASE64_ENCODE(
                    GET_PRESIGNED_URL(record.image_path, 3600)
                )
            );
            
            -- Call SPCS service
            LET result VARIANT := (
                SELECT CUSTOMERS.EXTRACT_FACE_EMBEDDING(image_data)
            );
            
            -- Update embedding in table
            IF (result:success = TRUE) THEN
                UPDATE CUSTOMERS.CUSTOMER_FACE_EMBEDDINGS
                SET embedding = PARSE_JSON(result:embedding)::VECTOR(FLOAT, 128),
                    quality_score = result:quality_score::FLOAT
                WHERE customer_id = record.customer_id;
                
                processed_count := processed_count + 1;
            ELSE
                error_count := error_count + 1;
            END IF;
            
        EXCEPTION
            WHEN OTHER THEN
                error_count := error_count + 1;
        END;
    END FOR;
    
    RETURN TABLE(
        SELECT 
            'Summary' AS customer_id, 
            (error_count = 0) AS success,
            'Processed: ' || processed_count || ', Errors: ' || error_count AS error
    );
END;
$$;

-- ============================================================================
-- ALTERNATIVE: UPLOAD FAIRFACE IMAGES TO STAGE
-- ============================================================================
-- Run from SnowSQL or Snowflake UI:
--
-- -- Upload FairFace images to stage
-- PUT file:///path/to/beauty_analyzer/sample_images/fairface_data/FairFace/train/*.jpg 
--     @CUSTOMERS.FACE_IMAGES/fairface/ 
--     PARALLEL=10 
--     AUTO_COMPRESS=FALSE;
--
-- -- For S3:
-- -- CREATE OR REPLACE STAGE CUSTOMERS.FAIRFACE_STAGE
-- --     URL = 's3://<bucket>/agent_commerce/fairface/'
-- --     STORAGE_INTEGRATION = agent_commerce_s3_int;
--
-- ============================================================================

-- ============================================================================
-- SERVICE MANAGEMENT COMMANDS
-- ============================================================================

-- Suspend service (to save costs)
-- ALTER SERVICE UTIL.AGENT_COMMERCE_BACKEND SUSPEND;

-- Resume service
-- ALTER SERVICE UTIL.AGENT_COMMERCE_BACKEND RESUME;

-- Scale service
-- ALTER SERVICE UTIL.AGENT_COMMERCE_BACKEND SET MIN_INSTANCES = 2, MAX_INSTANCES = 5;

-- Drop service
-- DROP SERVICE IF EXISTS UTIL.AGENT_COMMERCE_BACKEND;

-- ============================================================================
-- NEXT STEPS
-- ============================================================================
-- 1. Build and push Docker image to Snowflake repository
-- 2. Start the service
-- 3. Upload FairFace images to stage
-- 4. Run BATCH_EXTRACT_EMBEDDINGS procedure
-- 5. Verify embeddings in CUSTOMER_FACE_EMBEDDINGS table
-- ============================================================================

