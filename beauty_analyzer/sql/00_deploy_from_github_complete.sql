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
--   5. Loads product images from Git repo  
--   6. Loads CART_OLTP data (Hybrid Tables)
--   7. (MANUAL) Push Docker image using deploy.sh or pull_and_push.sh
--   8. Creates SPCS backend service
--   9. Creates Cortex services (Search, Semantic Views)
--  10. Loads face images and extracts embeddings
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
-- Note: COPY INTO doesn't support Git stages directly, so we:
--   1. Create an internal stage for CSV data
--   2. Copy files from Git repo to internal stage
--   3. COPY INTO tables from internal stage

-- Create file format for CSVs
CREATE OR REPLACE FILE FORMAT UTIL.CSV_FORMAT
    TYPE = CSV
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    PARSE_HEADER = TRUE
    NULL_IF = ('', 'NULL', 'null')
    EMPTY_FIELD_AS_NULL = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;

-- Create internal stage for CSV data
CREATE STAGE IF NOT EXISTS UTIL.CSV_DATA_STAGE
    COMMENT = 'Internal stage for CSV data files';

-- Copy all CSV files from Git to internal stage
COPY FILES INTO @UTIL.CSV_DATA_STAGE/
FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/data/generated/csv/
PATTERN = '.*\.csv';

-- Verify files copied
LIST @UTIL.CSV_DATA_STAGE/;

-- Load Products
COPY INTO PRODUCTS.PRODUCTS
FROM @UTIL.CSV_DATA_STAGE/
FILES = ('products.csv')
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO PRODUCTS.PRODUCT_VARIANTS
FROM @UTIL.CSV_DATA_STAGE/
FILES = ('product_variants.csv')
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO PRODUCTS.PRODUCT_MEDIA
FROM @UTIL.CSV_DATA_STAGE/
FILES = ('product_media.csv')
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO PRODUCTS.PRODUCT_LABELS
FROM @UTIL.CSV_DATA_STAGE/
FILES = ('product_labels.csv')
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO PRODUCTS.PRODUCT_INGREDIENTS
FROM @UTIL.CSV_DATA_STAGE/
FILES = ('product_ingredients.csv')
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO PRODUCTS.PRODUCT_WARNINGS
FROM @UTIL.CSV_DATA_STAGE/
FILES = ('product_warnings.csv')
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO PRODUCTS.PRICE_HISTORY
FROM @UTIL.CSV_DATA_STAGE/
FILES = ('price_history.csv')
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO PRODUCTS.PROMOTIONS
FROM @UTIL.CSV_DATA_STAGE/
FILES = ('promotions.csv')
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Load Customers
COPY INTO CUSTOMERS.CUSTOMERS
FROM @UTIL.CSV_DATA_STAGE/
FILES = ('customers.csv')
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO CUSTOMERS.SKIN_ANALYSIS_HISTORY
FROM @UTIL.CSV_DATA_STAGE/
FILES = ('skin_analysis_history.csv')
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Load Inventory
COPY INTO INVENTORY.LOCATIONS
FROM @UTIL.CSV_DATA_STAGE/
FILES = ('locations.csv')
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO INVENTORY.STOCK_LEVELS
FROM @UTIL.CSV_DATA_STAGE/
FILES = ('stock_levels.csv')
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO INVENTORY.INVENTORY_TRANSACTIONS
FROM @UTIL.CSV_DATA_STAGE/
FILES = ('inventory_transactions.csv')
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Load Social
COPY INTO SOCIAL.PRODUCT_REVIEWS
FROM @UTIL.CSV_DATA_STAGE/
FILES = ('product_reviews.csv')
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO SOCIAL.SOCIAL_MENTIONS
FROM @UTIL.CSV_DATA_STAGE/
FILES = ('social_mentions.csv')
FILE_FORMAT = UTIL.CSV_FORMAT
ON_ERROR = 'CONTINUE'
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

COPY INTO SOCIAL.INFLUENCER_MENTIONS
FROM @UTIL.CSV_DATA_STAGE/
FILES = ('influencer_mentions.csv')
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
-- Hybrid Tables support COPY INTO but with restrictions:
--   - ON_ERROR = 'CONTINUE' is NOT supported
--   - Data must be clean (no errors allowed)
-- Note: CSVs already copied to @UTIL.CSV_DATA_STAGE in PART 4

-- Fulfillment Options
COPY INTO CART_OLTP.FULFILLMENT_OPTIONS
FROM @UTIL.CSV_DATA_STAGE/
FILES = ('fulfillment_options.csv')
FILE_FORMAT = UTIL.CSV_FORMAT
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Payment Methods
COPY INTO CART_OLTP.PAYMENT_METHODS
FROM @UTIL.CSV_DATA_STAGE/
FILES = ('payment_methods.csv')
FILE_FORMAT = UTIL.CSV_FORMAT
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Cart Sessions
COPY INTO CART_OLTP.CART_SESSIONS
FROM @UTIL.CSV_DATA_STAGE/
FILES = ('cart_sessions.csv')
FILE_FORMAT = UTIL.CSV_FORMAT
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Cart Items
COPY INTO CART_OLTP.CART_ITEMS
FROM @UTIL.CSV_DATA_STAGE/
FILES = ('cart_items.csv')
FILE_FORMAT = UTIL.CSV_FORMAT
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Orders
COPY INTO CART_OLTP.ORDERS
FROM @UTIL.CSV_DATA_STAGE/
FILES = ('orders.csv')
FILE_FORMAT = UTIL.CSV_FORMAT
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Order Items
COPY INTO CART_OLTP.ORDER_ITEMS
FROM @UTIL.CSV_DATA_STAGE/
FILES = ('order_items.csv')
FILE_FORMAT = UTIL.CSV_FORMAT
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- Payment Transactions
COPY INTO CART_OLTP.PAYMENT_TRANSACTIONS
FROM @UTIL.CSV_DATA_STAGE/
FILES = ('payment_transactions.csv')
FILE_FORMAT = UTIL.CSV_FORMAT
MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- ============================================================================
-- PART 7: PUSH DOCKER IMAGE TO SNOWFLAKE (REQUIRES DOCKER CLI)
-- ============================================================================
-- SPCS requires images in Snowflake's internal registry.
-- Run this in your terminal BEFORE continuing:
--
--   cd beauty_analyzer/backend
--   ./deploy.sh
--
-- OR use the pre-built Docker Hub image:
--
--   cd beauty_analyzer/backend  
--   ./pull_and_push.sh
--
-- Both scripts will:
--   1. Prompt for your Snowflake account and credentials
--   2. Build/pull the Docker image
--   3. Push to your Snowflake image repository
--
-- Docker Hub image (public, no auth required):
--   amitgupta392/agent-commerce-backend:latest
-- ============================================================================

-- After running deploy.sh or pull_and_push.sh, verify image was uploaded:
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
-- PART 10: LOAD FACE IMAGES AND EXTRACT EMBEDDINGS
-- ============================================================================

-- Execute Face Image Loading and Embedding Extraction
EXECUTE IMMEDIATE FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/sql/09_load_face_images_and_embeddings.sql;

-- ============================================================================
-- PART 11: CREATE AGENT TOOLS (UDFs & Stored Procedures)
-- ============================================================================
-- Creates custom tools for the Cortex Agent:
--   - TOOL_ANALYZE_FACE (Python UDF - calls SPCS backend)
--   - TOOL_IDENTIFY_CUSTOMER (SQL UDTF - vector search)
--   - TOOL_MATCH_PRODUCTS (SQL UDTF - color matching)
--   - Cart/Checkout tools (6 procedures)
-- ============================================================================

EXECUTE IMMEDIATE FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/sql/10_create_agent_tools.sql;

-- ============================================================================
-- PART 12: CREATE CORTEX AGENT
-- ============================================================================
-- Creates the Cortex Agent with 16 tools:
--   - 5 Cortex Analyst tools (semantic views)
--   - 2 Cortex Search tools (search services)
--   - 10 Generic tools (custom UDFs/procedures from Part 11)
-- ============================================================================

EXECUTE IMMEDIATE FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/sql/11_create_cortex_agent.sql;

-- ============================================================================
-- PART 13: VERIFICATION
-- ============================================================================

-- Check data loaded
SELECT 'PRODUCTS' AS domain, COUNT(*) AS row_count FROM PRODUCTS.PRODUCTS
UNION ALL SELECT 'CUSTOMERS', COUNT(*) FROM CUSTOMERS.CUSTOMERS
UNION ALL SELECT 'INVENTORY', COUNT(*) FROM INVENTORY.LOCATIONS
UNION ALL SELECT 'SOCIAL', COUNT(*) FROM SOCIAL.PRODUCT_REVIEWS
UNION ALL SELECT 'CART_OLTP', COUNT(*) FROM CART_OLTP.ORDERS;

-- Check service status
SELECT SYSTEM$GET_SERVICE_STATUS('UTIL.AGENT_COMMERCE_BACKEND');

-- Get service endpoint
SHOW ENDPOINTS IN SERVICE UTIL.AGENT_COMMERCE_BACKEND;

-- Check Cortex Agent created
SHOW AGENTS IN SCHEMA UTIL;

-- List custom tools created
SELECT 'Agent Tools' AS category, COUNT(*) AS count FROM (
    SELECT function_name FROM AGENT_COMMERCE.INFORMATION_SCHEMA.FUNCTIONS 
    WHERE function_name LIKE 'TOOL_%'
    UNION ALL
    SELECT procedure_name FROM AGENT_COMMERCE.INFORMATION_SCHEMA.PROCEDURES 
    WHERE procedure_name LIKE 'TOOL_%'
);

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
-- COMPONENTS DEPLOYED:
--   ✅ Database & Schemas: AGENT_COMMERCE (CUSTOMERS, PRODUCTS, INVENTORY, SOCIAL, CART_OLTP, UTIL)
--   ✅ Tables: Including Hybrid Tables for CART_OLTP
--   ✅ Semantic Views: 5 views for Cortex Analyst
--   ✅ Cortex Search: 2 search services
--   ✅ SPCS Backend: Face recognition & skin analysis API
--   ✅ Agent Tools: 10 custom UDFs/procedures
--   ✅ Cortex Agent: BEAUTY_ADVISOR_AGENT with 17 tools
--
-- SERVICE ENDPOINT: (see output above)
-- DATABASE: AGENT_COMMERCE
-- OWNER: AGENT_COMMERCE_ROLE
-- 
-- CORTEX AGENT: UTIL.BEAUTY_ADVISOR_AGENT
--   - 5 Cortex Analyst tools (semantic views)
--   - 2 Cortex Search tools (product & social search)
--   - 3 Beauty analysis tools (face, identify, color match)
--   - 6 Cart/checkout tools (ACP compliant)
--
-- CLEANUP (when done):
--   USE ROLE ACCOUNTADMIN;
--   DROP DATABASE IF EXISTS AGENT_COMMERCE CASCADE;
--   DROP WAREHOUSE IF EXISTS AGENT_COMMERCE_WH;
--   DROP COMPUTE POOL IF EXISTS AGENT_COMMERCE_POOL;
--   DROP INTEGRATION IF EXISTS github_api_integration;
--   DROP ROLE IF EXISTS AGENT_COMMERCE_ROLE;
--
-- NEXT STEPS:
--   1. Test the Cortex Agent via REST API or Snowsight
--   2. Deploy the React frontend chatbot widget
--
-- ============================================================================

