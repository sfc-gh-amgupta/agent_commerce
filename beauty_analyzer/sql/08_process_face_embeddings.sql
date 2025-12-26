-- ============================================================================
-- AGENT COMMERCE - Process Face Embeddings via SPCS
-- ============================================================================
-- This script uploads FairFace images and extracts embeddings using SPCS backend.
--
-- Flow:
--   1. Upload FairFace images to internal stage
--   2. Map images to customer records
--   3. Call SPCS backend to extract embeddings
--   4. Update CUSTOMER_FACE_EMBEDDINGS table
--
-- ============================================================================

USE ROLE AGENT_COMMERCE_ROLE;
USE DATABASE AGENT_COMMERCE;
USE WAREHOUSE AGENT_COMMERCE_WH;
USE SCHEMA CUSTOMERS;

-- ============================================================================
-- STEP 1: CREATE FACE IMAGES STAGE
-- ============================================================================

CREATE STAGE IF NOT EXISTS CUSTOMERS.FACE_IMAGES
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for customer face images';

-- ============================================================================
-- STEP 2: UPLOAD FAIRFACE IMAGES
-- ============================================================================
-- Run from SnowSQL (not in worksheet):
--
-- -- Upload selected FairFace images (2,000 files)
-- PUT file:///Users/amgupta/Documents/Snowflake/Demo/beauty_analyzer/sample_images/fairface_data/FairFace/train/*.jpg
--     @AGENT_COMMERCE.CUSTOMERS.FACE_IMAGES/fairface/
--     PARALLEL=10
--     AUTO_COMPRESS=FALSE
--     OVERWRITE=TRUE;
--
-- ============================================================================
-- ALTERNATIVE: S3 UPLOAD
-- ============================================================================
-- If uploading from S3 instead of local:
--
-- -- Create external stage
-- CREATE OR REPLACE STAGE CUSTOMERS.FAIRFACE_S3_STAGE
--     URL = 's3://<bucket>/agent_commerce/fairface/'
--     STORAGE_INTEGRATION = agent_commerce_s3_int;
--
-- -- Copy to internal stage
-- COPY FILES INTO @CUSTOMERS.FACE_IMAGES/fairface/
-- FROM @CUSTOMERS.FAIRFACE_S3_STAGE
-- FILES = ('*.jpg');
--
-- ============================================================================

-- Verify uploaded files
LIST @CUSTOMERS.FACE_IMAGES/fairface/ PATTERN = '.*\.jpg';

-- Count files
SELECT COUNT(*) AS file_count FROM DIRECTORY(@CUSTOMERS.FACE_IMAGES);

-- ============================================================================
-- STEP 3: CREATE MAPPING TABLE (Image to Customer)
-- ============================================================================

-- Create temporary mapping table
CREATE OR REPLACE TEMPORARY TABLE FACE_IMAGE_MAPPING (
    customer_id VARCHAR(36),
    embedding_id VARCHAR(36),
    fairface_file VARCHAR(255),
    stage_path VARCHAR(500),
    processed BOOLEAN DEFAULT FALSE,
    embedding ARRAY,
    quality_score FLOAT,
    error_message VARCHAR(1000)
);

-- Load FairFace labels to get selected files
CREATE OR REPLACE TEMPORARY TABLE FAIRFACE_SELECTION AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY file) AS row_num,
    REPLACE(file, 'train/', '') AS filename,
    age,
    gender,
    race
FROM (
    -- This matches the selection logic from generate_all.py (80% F, 20% M, adults only)
    SELECT * FROM (
        SELECT * 
        FROM @UTIL.DATA_STAGE/fairface_labels.csv
        (FILE_FORMAT => 'UTIL.CSV_FORMAT')
        WHERE age NOT IN ('0-2', '3-9', '10-19')
    )
    QUALIFY 
        (gender = 'Female' AND ROW_NUMBER() OVER (PARTITION BY gender ORDER BY RANDOM()) <= 1600)
        OR
        (gender = 'Male' AND ROW_NUMBER() OVER (PARTITION BY gender ORDER BY RANDOM()) <= 400)
);

-- Map customers to FairFace files
INSERT INTO FACE_IMAGE_MAPPING (customer_id, embedding_id, fairface_file, stage_path)
SELECT 
    c.customer_id,
    e.embedding_id,
    f.filename,
    '@CUSTOMERS.FACE_IMAGES/fairface/' || f.filename AS stage_path
FROM CUSTOMERS c
JOIN CUSTOMER_FACE_EMBEDDINGS e ON c.customer_id = e.customer_id
JOIN FAIRFACE_SELECTION f ON f.row_num = ROW_NUMBER() OVER (ORDER BY c.customer_id)
LIMIT 2000;

-- Verify mapping
SELECT COUNT(*) AS mapped_count FROM FACE_IMAGE_MAPPING;

-- ============================================================================
-- STEP 4: PROCESS EMBEDDINGS VIA SPCS
-- ============================================================================

-- Process embeddings in batches using SPCS backend
CREATE OR REPLACE PROCEDURE CUSTOMERS.PROCESS_FACE_EMBEDDINGS_BATCH(
    batch_size INTEGER DEFAULT 50
)
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
AS
$$
    var processed = 0;
    var errors = 0;
    
    // Get unprocessed records
    var stmt = snowflake.createStatement({
        sqlText: `
            SELECT customer_id, embedding_id, stage_path 
            FROM FACE_IMAGE_MAPPING 
            WHERE processed = FALSE 
            LIMIT ?
        `,
        binds: [BATCH_SIZE]
    });
    
    var result = stmt.execute();
    
    while (result.next()) {
        var customerId = result.getColumnValue('CUSTOMER_ID');
        var embeddingId = result.getColumnValue('EMBEDDING_ID');
        var stagePath = result.getColumnValue('STAGE_PATH');
        
        try {
            // Read image from stage and encode as base64
            var readStmt = snowflake.createStatement({
                sqlText: `
                    SELECT BASE64_ENCODE(
                        TO_BINARY(
                            GET_PRESIGNED_URL('${stagePath}', 3600)::VARIANT, 'UTF-8'
                        )
                    ) AS image_b64
                `
            });
            
            // This is a placeholder - actual implementation needs file reading
            // In practice, you'd use a Python UDF or external function
            
            // Call SPCS backend
            var callStmt = snowflake.createStatement({
                sqlText: `
                    SELECT CUSTOMERS.EXTRACT_FACE_EMBEDDING(?) AS result
                `,
                binds: ['placeholder_base64']
            });
            
            var callResult = callStmt.execute();
            if (callResult.next()) {
                var response = JSON.parse(callResult.getColumnValue('RESULT'));
                
                if (response.success) {
                    // Update embedding
                    var updateStmt = snowflake.createStatement({
                        sqlText: `
                            UPDATE FACE_IMAGE_MAPPING 
                            SET processed = TRUE,
                                embedding = PARSE_JSON(?),
                                quality_score = ?
                            WHERE embedding_id = ?
                        `,
                        binds: [JSON.stringify(response.embedding), response.quality_score, embeddingId]
                    });
                    updateStmt.execute();
                    processed++;
                } else {
                    // Record error
                    var errorStmt = snowflake.createStatement({
                        sqlText: `
                            UPDATE FACE_IMAGE_MAPPING 
                            SET processed = TRUE,
                                error_message = ?
                            WHERE embedding_id = ?
                        `,
                        binds: [response.error || 'Unknown error', embeddingId]
                    });
                    errorStmt.execute();
                    errors++;
                }
            }
        } catch (err) {
            errors++;
            var errStmt = snowflake.createStatement({
                sqlText: `
                    UPDATE FACE_IMAGE_MAPPING 
                    SET processed = TRUE,
                        error_message = ?
                    WHERE embedding_id = ?
                `,
                binds: [err.message, embeddingId]
            });
            errStmt.execute();
        }
    }
    
    return `Processed: ${processed}, Errors: ${errors}`;
$$;

-- ============================================================================
-- ALTERNATIVE: Python UDF for Image Processing
-- ============================================================================
-- This approach uses a Python UDF to read images and call the SPCS service

CREATE OR REPLACE FUNCTION CUSTOMERS.READ_IMAGE_AS_BASE64(stage_path VARCHAR)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.10'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'read_image'
AS
$$
import base64
from snowflake.snowpark.files import SnowflakeFile

def read_image(stage_path):
    try:
        with SnowflakeFile.open(stage_path, 'rb') as f:
            image_bytes = f.read()
            return base64.b64encode(image_bytes).decode('utf-8')
    except Exception as e:
        return f"ERROR: {str(e)}"
$$;

-- ============================================================================
-- STEP 5: BATCH PROCESS WITH PYTHON UDF
-- ============================================================================

CREATE OR REPLACE PROCEDURE CUSTOMERS.EXTRACT_ALL_EMBEDDINGS()
RETURNS TABLE (customer_id VARCHAR, status VARCHAR)
LANGUAGE SQL
AS
$$
DECLARE
    result_cursor CURSOR FOR
        SELECT 
            m.customer_id,
            m.embedding_id,
            CUSTOMERS.READ_IMAGE_AS_BASE64(m.stage_path) AS image_base64
        FROM FACE_IMAGE_MAPPING m
        WHERE m.processed = FALSE
        LIMIT 100;
BEGIN
    -- Process each record
    FOR record IN result_cursor DO
        -- Skip if image read failed
        IF (record.image_base64 NOT LIKE 'ERROR:%') THEN
            -- Call SPCS to extract embedding
            LET spcs_result VARIANT := (
                SELECT CUSTOMERS.EXTRACT_FACE_EMBEDDING(record.image_base64)
            );
            
            -- Update mapping table with result
            IF (spcs_result:success = TRUE) THEN
                UPDATE FACE_IMAGE_MAPPING
                SET processed = TRUE,
                    embedding = spcs_result:embedding,
                    quality_score = spcs_result:quality_score
                WHERE embedding_id = record.embedding_id;
                
                -- Also update main embeddings table
                UPDATE CUSTOMER_FACE_EMBEDDINGS
                SET embedding = PARSE_JSON(spcs_result:embedding::VARCHAR)::VECTOR(FLOAT, 128),
                    quality_score = spcs_result:quality_score::FLOAT
                WHERE embedding_id = record.embedding_id;
            ELSE
                UPDATE FACE_IMAGE_MAPPING
                SET processed = TRUE,
                    error_message = spcs_result:error::VARCHAR
                WHERE embedding_id = record.embedding_id;
            END IF;
        ELSE
            UPDATE FACE_IMAGE_MAPPING
            SET processed = TRUE,
                error_message = record.image_base64
            WHERE embedding_id = record.embedding_id;
        END IF;
    END FOR;
    
    -- Return summary
    RETURN TABLE(
        SELECT 
            'Total' AS customer_id,
            'Processed: ' || SUM(CASE WHEN embedding IS NOT NULL THEN 1 ELSE 0 END) ||
            ', Errors: ' || SUM(CASE WHEN error_message IS NOT NULL THEN 1 ELSE 0 END) AS status
        FROM FACE_IMAGE_MAPPING
    );
END;
$$;

-- ============================================================================
-- STEP 6: EXECUTE EXTRACTION
-- ============================================================================

-- Run extraction (call multiple times for all 2,000 images)
-- CALL CUSTOMERS.EXTRACT_ALL_EMBEDDINGS();

-- Check progress
SELECT 
    SUM(CASE WHEN processed THEN 1 ELSE 0 END) AS processed,
    SUM(CASE WHEN embedding IS NOT NULL THEN 1 ELSE 0 END) AS with_embedding,
    SUM(CASE WHEN error_message IS NOT NULL THEN 1 ELSE 0 END) AS errors,
    COUNT(*) AS total
FROM FACE_IMAGE_MAPPING;

-- ============================================================================
-- STEP 7: COPY EMBEDDINGS TO MAIN TABLE
-- ============================================================================

-- Update main embeddings table with extracted embeddings
UPDATE CUSTOMER_FACE_EMBEDDINGS e
SET 
    embedding = PARSE_JSON(m.embedding::VARCHAR)::VECTOR(FLOAT, 128),
    quality_score = m.quality_score
FROM FACE_IMAGE_MAPPING m
WHERE e.embedding_id = m.embedding_id
AND m.embedding IS NOT NULL;

-- Verify results
SELECT 
    COUNT(*) AS total_embeddings,
    SUM(CASE WHEN quality_score > 0.5 THEN 1 ELSE 0 END) AS high_quality
FROM CUSTOMER_FACE_EMBEDDINGS
WHERE embedding IS NOT NULL;

-- ============================================================================
-- CLEANUP
-- ============================================================================

-- Drop temporary tables when done
-- DROP TABLE IF EXISTS FACE_IMAGE_MAPPING;
-- DROP TABLE IF EXISTS FAIRFACE_SELECTION;

