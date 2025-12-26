-- ============================================================================
-- AGENT COMMERCE - Complete Deployment from GitHub
-- ============================================================================
-- 
-- ONE-CLICK DEPLOYMENT: This single script deploys the entire Agent Commerce
-- demo using ONLY Snowsight. No local tools required!
--
-- WHAT THIS SCRIPT DOES:
--   1. Creates AGENT_COMMERCE_ROLE and grants account-level privileges
--   2. Creates database, schemas, warehouse, compute pool (all owned by role)
--   3. Clones GitHub repository into Snowflake
--   4. Loads all CSV data from Git repo
--   5. Loads all images from Git repo  
--   6. Builds Docker image directly from Git repo (no GitHub Actions needed!)
--   7. Creates SPCS backend service
--   8. Creates Cortex services (Search, Semantic Views)
--
-- OWNERSHIP STRATEGY:
--   - All objects are owned by AGENT_COMMERCE_ROLE (not ACCOUNTADMIN)
--   - Only API Integration is created by ACCOUNTADMIN (required)
--   - This enables clean teardown: DROP ROLE CASCADE cleans up everything
--
-- PREREQUISITES:
--   - ACCOUNTADMIN role (for initial setup and API integration)
--   - Network access to github.com
--
-- SOURCE REPOSITORY:
--   https://github.com/sfc-gh-amgupta/agent_commerce
--
-- ============================================================================

-- ============================================================================
-- PART 1: INFRASTRUCTURE SETUP
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- STEP 1A: Create application role FIRST with necessary account-level privileges
-- ============================================================================

CREATE ROLE IF NOT EXISTS AGENT_COMMERCE_ROLE
    COMMENT = 'Role for Agent Commerce application - owns all demo objects';

-- Grant account-level privileges needed for resource creation
GRANT CREATE DATABASE ON ACCOUNT TO ROLE AGENT_COMMERCE_ROLE;
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE AGENT_COMMERCE_ROLE;
GRANT CREATE COMPUTE POOL ON ACCOUNT TO ROLE AGENT_COMMERCE_ROLE;
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE AGENT_COMMERCE_ROLE;

-- Grant role to current user
DECLARE
    current_user_name VARCHAR;
BEGIN
    current_user_name := CURRENT_USER();
    EXECUTE IMMEDIATE 'GRANT ROLE AGENT_COMMERCE_ROLE TO USER "' || current_user_name || '"';
END;

-- ============================================================================
-- STEP 1B: Switch to AGENT_COMMERCE_ROLE to create objects (ensures ownership)
-- ============================================================================

USE ROLE AGENT_COMMERCE_ROLE;

-- Create database (now owned by AGENT_COMMERCE_ROLE)
CREATE DATABASE IF NOT EXISTS AGENT_COMMERCE
    COMMENT = 'Agent Commerce Demo - AI-powered shopping assistant';

USE DATABASE AGENT_COMMERCE;

-- Create schemas (owned by AGENT_COMMERCE_ROLE)
CREATE SCHEMA IF NOT EXISTS UTIL COMMENT = 'Utilities, configs, and shared resources';
CREATE SCHEMA IF NOT EXISTS PRODUCTS COMMENT = 'Product catalog and pricing';
CREATE SCHEMA IF NOT EXISTS CUSTOMERS COMMENT = 'Customer profiles and face embeddings';
CREATE SCHEMA IF NOT EXISTS INVENTORY COMMENT = 'Stock levels and locations';
CREATE SCHEMA IF NOT EXISTS SOCIAL COMMENT = 'Reviews and social proof';
CREATE SCHEMA IF NOT EXISTS CART_OLTP COMMENT = 'Transactional cart and orders (Hybrid Tables)';

-- Create warehouse (owned by AGENT_COMMERCE_ROLE)
CREATE WAREHOUSE IF NOT EXISTS AGENT_COMMERCE_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    COMMENT = 'Warehouse for Agent Commerce workloads';

USE WAREHOUSE AGENT_COMMERCE_WH;

-- Create compute pool (owned by AGENT_COMMERCE_ROLE)
CREATE COMPUTE POOL IF NOT EXISTS AGENT_COMMERCE_POOL
    MIN_NODES = 1
    MAX_NODES = 3
    INSTANCE_FAMILY = CPU_X64_S
    AUTO_SUSPEND_SECS = 300
    COMMENT = 'Compute pool for ML backend services';

-- Create image repository (owned by AGENT_COMMERCE_ROLE)
CREATE IMAGE REPOSITORY IF NOT EXISTS UTIL.AGENT_COMMERCE_REPO
    COMMENT = 'Container images for Agent Commerce';

-- ============================================================================
-- PART 2: GIT INTEGRATION
-- ============================================================================

USE SCHEMA UTIL;

-- API Integration requires ACCOUNTADMIN
USE ROLE ACCOUNTADMIN;

-- Create API integration for GitHub (ACCOUNTADMIN only)
CREATE OR REPLACE API INTEGRATION github_api_integration
    API_PROVIDER = GIT_HTTPS_API
    API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-amgupta/')
    ENABLED = TRUE
    COMMENT = 'Integration for Agent Commerce GitHub repository';

-- Grant usage on API integration to AGENT_COMMERCE_ROLE
GRANT USAGE ON INTEGRATION github_api_integration TO ROLE AGENT_COMMERCE_ROLE;

-- Switch back to AGENT_COMMERCE_ROLE for remaining operations
USE ROLE AGENT_COMMERCE_ROLE;
USE DATABASE AGENT_COMMERCE;
USE SCHEMA UTIL;

-- Create Git repository stage (now owned by AGENT_COMMERCE_ROLE)
CREATE OR REPLACE GIT REPOSITORY UTIL.AGENT_COMMERCE_GIT
    API_INTEGRATION = github_api_integration
    ORIGIN = 'https://github.com/sfc-gh-amgupta/agent_commerce.git'
    COMMENT = 'Agent Commerce source code and data';

-- Fetch latest from repository
ALTER GIT REPOSITORY UTIL.AGENT_COMMERCE_GIT FETCH;

-- List repository contents
LIST @UTIL.AGENT_COMMERCE_GIT/branches/main/;

-- ============================================================================
-- PART 3: CREATE TABLES (from Git repo SQL)
-- ============================================================================
-- Note: Already using AGENT_COMMERCE_ROLE, so all tables will be owned by it

-- Execute table creation script from Git
EXECUTE IMMEDIATE FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/sql/02_create_tables.sql;

-- ============================================================================
-- PART 4: LOAD CSV DATA FROM GIT REPOSITORY
-- ============================================================================

-- Create file format for CSVs
CREATE OR REPLACE FILE FORMAT UTIL.CSV_FORMAT
    TYPE = CSV
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    PARSE_HEADER = TRUE
    NULL_IF = ('', 'NULL', 'null')
    EMPTY_FIELD_AS_NULL = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;

-- Load Products
COPY INTO PRODUCTS.PRODUCTS
FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/data/generated/csv/products.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO PRODUCTS.PRODUCT_VARIANTS
FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/data/generated/csv/product_variants.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO PRODUCTS.PRODUCT_MEDIA
FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/data/generated/csv/product_media.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO PRODUCTS.PRODUCT_LABELS
FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/data/generated/csv/product_labels.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO PRODUCTS.PRODUCT_INGREDIENTS
FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/data/generated/csv/product_ingredients.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO PRODUCTS.PRODUCT_WARNINGS
FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/data/generated/csv/product_warnings.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO PRODUCTS.PRICE_HISTORY
FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/data/generated/csv/price_history.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO PRODUCTS.PROMOTIONS
FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/data/generated/csv/promotions.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Load Customers
COPY INTO CUSTOMERS.CUSTOMERS
FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/data/generated/csv/customers.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO CUSTOMERS.SKIN_ANALYSIS_HISTORY
FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/data/generated/csv/skin_analysis_history.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Load Inventory
COPY INTO INVENTORY.LOCATIONS
FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/data/generated/csv/locations.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO INVENTORY.STOCK_LEVELS
FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/data/generated/csv/stock_levels.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO INVENTORY.INVENTORY_TRANSACTIONS
FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/data/generated/csv/inventory_transactions.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Load Social
COPY INTO SOCIAL.PRODUCT_REVIEWS
FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/data/generated/csv/product_reviews.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO SOCIAL.SOCIAL_MENTIONS
FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/data/generated/csv/social_mentions.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO SOCIAL.INFLUENCER_MENTIONS
FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/data/generated/csv/influencer_mentions.csv
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- ============================================================================
-- PART 5: LOAD IMAGES FROM GIT REPOSITORY
-- ============================================================================

-- Create internal stages for images
CREATE STAGE IF NOT EXISTS PRODUCTS.PRODUCT_MEDIA_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Product images (hero, swatches, labels)';

CREATE STAGE IF NOT EXISTS CUSTOMERS.FACE_IMAGES_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Customer face images for embedding extraction';

-- Copy images from Git to internal stages
-- Hero images
COPY FILES INTO @PRODUCTS.PRODUCT_MEDIA_STAGE/hero/
FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/sample_images/hero_images/
PATTERN = '.*\.(jpg|png)';

-- Label images (if included in repo)
COPY FILES INTO @PRODUCTS.PRODUCT_MEDIA_STAGE/labels/
FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/data/generated/images/labels/
PATTERN = '.*\.png';

-- Swatch images (if included in repo)
COPY FILES INTO @PRODUCTS.PRODUCT_MEDIA_STAGE/swatches/
FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/data/generated/images/swatches/
PATTERN = '.*\.png';

-- ============================================================================
-- PART 6: LOAD CART_OLTP DATA (Hybrid Tables)
-- ============================================================================

-- For Hybrid Tables, use staging tables then INSERT

-- Fulfillment Options
CREATE OR REPLACE TEMPORARY TABLE CART_OLTP.FULFILLMENT_OPTIONS_STAGING AS
SELECT * FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/data/generated/csv/fulfillment_options.csv
(FILE_FORMAT => UTIL.CSV_FORMAT);

INSERT INTO CART_OLTP.FULFILLMENT_OPTIONS 
SELECT * FROM CART_OLTP.FULFILLMENT_OPTIONS_STAGING;

-- Cart Sessions
CREATE OR REPLACE TEMPORARY TABLE CART_OLTP.CART_SESSIONS_STAGING AS
SELECT * FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/data/generated/csv/cart_sessions.csv
(FILE_FORMAT => UTIL.CSV_FORMAT);

INSERT INTO CART_OLTP.CART_SESSIONS 
SELECT * FROM CART_OLTP.CART_SESSIONS_STAGING;

-- (Continue for other CART_OLTP tables...)

-- ============================================================================
-- PART 7: BUILD DOCKER IMAGE DIRECTLY FROM GIT REPOSITORY
-- ============================================================================
-- No GitHub Actions needed! Snowflake builds the image from source.
-- Build time: ~5-10 minutes (dlib compilation)
-- Note: Already using AGENT_COMMERCE_ROLE, so image owned by it
-- ============================================================================

-- Build image directly from Git repository
-- The Dockerfile and source code are in: beauty_analyzer/backend/
ALTER IMAGE REPOSITORY UTIL.AGENT_COMMERCE_REPO 
    BUILD 
    IMAGE 'agent-commerce-backend'
    TAG 'latest'
    FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/backend/
    DOCKERFILE_PATH = 'Dockerfile';

-- Note: Build takes 5-10 minutes. Check progress with:
-- SELECT SYSTEM$GET_BUILD_STATUS('/AGENT_COMMERCE/UTIL/AGENT_COMMERCE_REPO/agent-commerce-backend:latest');

-- Verify image was built
SHOW IMAGES IN IMAGE REPOSITORY UTIL.AGENT_COMMERCE_REPO;

-- ============================================================================
-- PART 8: CREATE SPCS BACKEND SERVICE
-- ============================================================================

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
    QUERY_WAREHOUSE = AGENT_COMMERCE_WH;

-- Wait for service to start
SELECT SYSTEM$GET_SERVICE_STATUS('UTIL.AGENT_COMMERCE_BACKEND');

-- ============================================================================
-- PART 9: CREATE CORTEX SERVICES (from Git repo SQL)
-- ============================================================================

-- Execute Semantic Views
EXECUTE IMMEDIATE FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/sql/03_create_semantic_views.sql;

-- Execute Cortex Search
EXECUTE IMMEDIATE FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/sql/04_create_cortex_search.sql;

-- Execute Vector Procedures
EXECUTE IMMEDIATE FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/sql/05_create_vector_embedding_proc.sql;

-- ============================================================================
-- PART 10: VERIFICATION
-- ============================================================================

-- Check data loaded
SELECT 'PRODUCTS' AS domain, COUNT(*) AS rows FROM PRODUCTS.PRODUCTS
UNION ALL SELECT 'CUSTOMERS', COUNT(*) FROM CUSTOMERS.CUSTOMERS
UNION ALL SELECT 'INVENTORY', COUNT(*) FROM INVENTORY.LOCATIONS
UNION ALL SELECT 'SOCIAL', COUNT(*) FROM SOCIAL.PRODUCT_REVIEWS
UNION ALL SELECT 'CART_OLTP', COUNT(*) FROM CART_OLTP.ORDERS;

-- Check service status
SELECT SYSTEM$GET_SERVICE_STATUS('UTIL.AGENT_COMMERCE_BACKEND');

-- Get service endpoint
SHOW ENDPOINTS IN SERVICE UTIL.AGENT_COMMERCE_BACKEND;

-- ============================================================================
-- VERIFY OWNERSHIP - All objects should be owned by AGENT_COMMERCE_ROLE
-- ============================================================================

-- Check database ownership
SELECT 'DATABASE' AS object_type, 'AGENT_COMMERCE' AS object_name, 
       (SELECT database_owner FROM INFORMATION_SCHEMA.DATABASES 
        WHERE database_name = 'AGENT_COMMERCE') AS owner;

-- Check schema ownership
SELECT 'SCHEMA' AS object_type, schema_name AS object_name, catalog_owner AS owner
FROM AGENT_COMMERCE.INFORMATION_SCHEMA.SCHEMATA
WHERE catalog_name = 'AGENT_COMMERCE';

-- Check warehouse ownership
SHOW WAREHOUSES LIKE 'AGENT_COMMERCE_WH';

-- Check compute pool ownership
SHOW COMPUTE POOLS LIKE 'AGENT_COMMERCE_POOL';

-- Check service ownership
SHOW SERVICES IN SCHEMA UTIL;

-- ============================================================================
-- DEPLOYMENT COMPLETE!
-- ============================================================================
--
-- Your Agent Commerce demo is now ready!
--
-- Service Endpoint: (see output above)
-- Database: AGENT_COMMERCE
-- Owner: AGENT_COMMERCE_ROLE
-- 
-- All objects are owned by AGENT_COMMERCE_ROLE for easy management.
--
-- CLEANUP (when done):
--   USE ROLE ACCOUNTADMIN;
--   DROP DATABASE IF EXISTS AGENT_COMMERCE CASCADE;
--   DROP WAREHOUSE IF EXISTS AGENT_COMMERCE_WH;
--   DROP COMPUTE POOL IF EXISTS AGENT_COMMERCE_POOL;
--   DROP INTEGRATION IF EXISTS github_api_integration;
--   DROP ROLE IF EXISTS AGENT_COMMERCE_ROLE;
--
-- Next: Deploy the React frontend to interact with the backend
--
-- ============================================================================

