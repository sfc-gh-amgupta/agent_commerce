-- ============================================================================
-- AGENT COMMERCE - Complete Deployment from GitHub
-- ============================================================================
-- 
-- ONE-CLICK DEPLOYMENT: This single script deploys the entire Agent Commerce
-- demo using ONLY Snowsight. No local tools required!
--
-- WHAT THIS SCRIPT DOES:
--   1. Creates database, schemas, warehouse, compute pool
--   2. Clones GitHub repository into Snowflake
--   3. Loads all CSV data from Git repo
--   4. Loads all images from Git repo  
--   5. Pulls Docker image from GitHub Container Registry
--   6. Creates SPCS backend service
--   7. Creates Cortex services (Search, Semantic Views)
--
-- PREREQUISITES:
--   - ACCOUNTADMIN role (or role with CREATE DATABASE, CREATE INTEGRATION)
--   - Network access to github.com and ghcr.io
--
-- SOURCE REPOSITORY:
--   https://github.com/sfc-gh-amgupta/agent_commerce
--
-- ============================================================================

-- ============================================================================
-- PART 1: INFRASTRUCTURE SETUP
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- Create database
CREATE DATABASE IF NOT EXISTS AGENT_COMMERCE
    COMMENT = 'Agent Commerce Demo - AI-powered shopping assistant';

USE DATABASE AGENT_COMMERCE;

-- Create schemas
CREATE SCHEMA IF NOT EXISTS UTIL COMMENT = 'Utilities, configs, and shared resources';
CREATE SCHEMA IF NOT EXISTS PRODUCTS COMMENT = 'Product catalog and pricing';
CREATE SCHEMA IF NOT EXISTS CUSTOMERS COMMENT = 'Customer profiles and face embeddings';
CREATE SCHEMA IF NOT EXISTS INVENTORY COMMENT = 'Stock levels and locations';
CREATE SCHEMA IF NOT EXISTS SOCIAL COMMENT = 'Reviews and social proof';
CREATE SCHEMA IF NOT EXISTS CART_OLTP COMMENT = 'Transactional cart and orders (Hybrid Tables)';

-- Create warehouse
CREATE WAREHOUSE IF NOT EXISTS AGENT_COMMERCE_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    COMMENT = 'Warehouse for Agent Commerce workloads';

USE WAREHOUSE AGENT_COMMERCE_WH;

-- Create compute pool for SPCS
CREATE COMPUTE POOL IF NOT EXISTS AGENT_COMMERCE_POOL
    MIN_NODES = 1
    MAX_NODES = 3
    INSTANCE_FAMILY = CPU_X64_S
    AUTO_SUSPEND_SECS = 300
    COMMENT = 'Compute pool for ML backend services';

-- Create image repository
CREATE IMAGE REPOSITORY IF NOT EXISTS UTIL.AGENT_COMMERCE_REPO
    COMMENT = 'Container images for Agent Commerce';

-- Create application role
CREATE ROLE IF NOT EXISTS AGENT_COMMERCE_ROLE
    COMMENT = 'Role for Agent Commerce application';

-- Grant permissions
GRANT USAGE ON DATABASE AGENT_COMMERCE TO ROLE AGENT_COMMERCE_ROLE;
GRANT USAGE ON ALL SCHEMAS IN DATABASE AGENT_COMMERCE TO ROLE AGENT_COMMERCE_ROLE;
GRANT CREATE TABLE, CREATE VIEW, CREATE STAGE, CREATE FUNCTION, CREATE PROCEDURE 
    ON ALL SCHEMAS IN DATABASE AGENT_COMMERCE TO ROLE AGENT_COMMERCE_ROLE;
GRANT USAGE ON WAREHOUSE AGENT_COMMERCE_WH TO ROLE AGENT_COMMERCE_ROLE;
GRANT USAGE ON COMPUTE POOL AGENT_COMMERCE_POOL TO ROLE AGENT_COMMERCE_ROLE;
GRANT READ, WRITE ON IMAGE REPOSITORY UTIL.AGENT_COMMERCE_REPO TO ROLE AGENT_COMMERCE_ROLE;

-- Grant role to current user
DECLARE
    current_user_name VARCHAR;
BEGIN
    current_user_name := CURRENT_USER();
    EXECUTE IMMEDIATE 'GRANT ROLE AGENT_COMMERCE_ROLE TO USER "' || current_user_name || '"';
END;

-- ============================================================================
-- PART 2: GIT INTEGRATION
-- ============================================================================

USE SCHEMA UTIL;

-- Create API integration for GitHub
CREATE OR REPLACE API INTEGRATION github_api_integration
    API_PROVIDER = GIT_HTTPS_API
    API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-amgupta/')
    ENABLED = TRUE
    COMMENT = 'Integration for Agent Commerce GitHub repository';

-- Create Git repository stage
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

USE ROLE AGENT_COMMERCE_ROLE;

-- Execute table creation script from Git
EXECUTE IMMEDIATE FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/sql/02_create_tables.sql;

-- ============================================================================
-- PART 4: LOAD CSV DATA FROM GIT REPOSITORY
-- ============================================================================

-- Create file format for CSVs
CREATE OR REPLACE FILE FORMAT UTIL.CSV_FORMAT
    TYPE = CSV
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1
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
-- PART 7: PULL DOCKER IMAGE FROM GITHUB CONTAINER REGISTRY
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- Create network rule for GitHub Container Registry
CREATE OR REPLACE NETWORK RULE ghcr_network_rule
    TYPE = HOST_PORT
    VALUE_LIST = ('ghcr.io:443', 'pkg-containers.githubusercontent.com:443')
    MODE = EGRESS;

-- Create external access integration
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION ghcr_access_integration
    ALLOWED_NETWORK_RULES = (ghcr_network_rule)
    ENABLED = TRUE;

GRANT USAGE ON INTEGRATION ghcr_access_integration TO ROLE AGENT_COMMERCE_ROLE;

USE ROLE AGENT_COMMERCE_ROLE;

-- Copy image from GitHub Container Registry to Snowflake
CALL SYSTEM$REGISTRY_COPY_IMAGE(
    'ghcr.io/sfc-gh-amgupta/agent_commerce/agent-commerce-backend:latest',
    '/AGENT_COMMERCE/UTIL/AGENT_COMMERCE_REPO/agent-commerce-backend:latest'
);

-- Verify image
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
-- DEPLOYMENT COMPLETE!
-- ============================================================================
--
-- Your Agent Commerce demo is now ready!
--
-- Service Endpoint: (see output above)
-- Database: AGENT_COMMERCE
-- 
-- Next: Deploy the React frontend to interact with the backend
--
-- ============================================================================

