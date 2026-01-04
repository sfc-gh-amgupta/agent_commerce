-- ============================================================================
-- AGENT COMMERCE - Database Infrastructure Setup
-- ============================================================================
-- This script creates the foundational Snowflake objects for the Agent Commerce
-- platform, including database, schemas, warehouse, and grants.
--
-- All objects are created under AGENT_COMMERCE_ROLE for proper ownership.
-- Run this script first before any other SQL scripts.
-- ============================================================================

-- ============================================================================
-- STEP 1: Create Role and Grant Permissions (Run as ACCOUNTADMIN or SYSADMIN)
-- ============================================================================
-- Note: This section must be run by a user with CREATE ROLE privileges

USE ROLE ACCOUNTADMIN;  -- Or SYSADMIN if preferred

-- Create the application role that will own all Agent Commerce objects
CREATE ROLE IF NOT EXISTS AGENT_COMMERCE_ROLE
    COMMENT = 'Owner role for all Agent Commerce platform objects';

-- Grant role to current user dynamically (works for any user)
BEGIN
    LET my_user VARCHAR := CURRENT_USER();
    LET grant_stmt VARCHAR := 'GRANT ROLE AGENT_COMMERCE_ROLE TO USER "' || my_user || '"';
    EXECUTE IMMEDIATE grant_stmt;
END;

-- Grant necessary account-level privileges to the role
GRANT CREATE DATABASE ON ACCOUNT TO ROLE AGENT_COMMERCE_ROLE;
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE AGENT_COMMERCE_ROLE;
GRANT CREATE COMPUTE POOL ON ACCOUNT TO ROLE AGENT_COMMERCE_ROLE;
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE AGENT_COMMERCE_ROLE;

-- ============================================================================
-- STEP 2: Switch to AGENT_COMMERCE_ROLE to Create Objects
-- ============================================================================
-- All objects created from this point will be owned by AGENT_COMMERCE_ROLE

USE ROLE AGENT_COMMERCE_ROLE;

-- ----------------------------------------------------------------------------
-- STEP 3: Create Database
-- ----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS AGENT_COMMERCE
    COMMENT = 'AI-Powered Commerce Platform with Cortex Agent';

USE DATABASE AGENT_COMMERCE;

-- ----------------------------------------------------------------------------
-- STEP 4: Create Schemas
-- ----------------------------------------------------------------------------
-- Note: Each domain schema contains its own Cortex Search, Cortex Analyst,
-- Semantic Views, and UDFs. No separate CORTEX schema needed.
-- ----------------------------------------------------------------------------

-- Customer data and face embeddings
-- Includes: Cortex Vector Search (face embeddings), Cortex Analyst (customer queries)
CREATE SCHEMA IF NOT EXISTS CUSTOMERS
    COMMENT = 'Customer profiles, face embeddings, analysis history, and customer-related Cortex services';

-- Product catalog
-- Includes: Cortex Search (products, labels), Cortex Analyst (product queries)
CREATE SCHEMA IF NOT EXISTS PRODUCTS
    COMMENT = 'Product catalog, variants, media, labels, and product-related Cortex services';

-- Inventory management
-- Includes: Cortex Analyst (inventory queries)
CREATE SCHEMA IF NOT EXISTS INVENTORY
    COMMENT = 'Inventory levels, locations, and stock management';

-- Social proof data (reviews, mentions, influencers)
-- Includes: Cortex Search (social content), Cortex Analyst (social proof queries)
CREATE SCHEMA IF NOT EXISTS SOCIAL
    COMMENT = 'Product reviews, social mentions, influencer content, trends, and social Cortex services';

-- Cart and checkout data (uses Hybrid Tables for ACID transactions)
-- OLTP = Online Transaction Processing (low-latency transactional workloads)
-- Includes: Cortex Analyst (cart/order queries)
CREATE SCHEMA IF NOT EXISTS CART_OLTP
    COMMENT = 'OLTP schema for cart sessions, payments, orders (Hybrid Tables for ACID)';

-- Utility schema for SPCS, shared UDFs, and integrations
CREATE SCHEMA IF NOT EXISTS UTIL
    COMMENT = 'SPCS container services, shared UDFs, stored procedures, and integrations';

-- Demo configuration and retailer settings
CREATE SCHEMA IF NOT EXISTS DEMO_CONFIG
    COMMENT = 'Retailer configuration, themes, branding, and demo settings';

-- ----------------------------------------------------------------------------
-- STEP 5: Create Warehouse
-- ----------------------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS AGENT_COMMERCE_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse for Agent Commerce queries and tasks';

-- Grant usage on warehouse to the role (owned by role, but explicit for clarity)
GRANT USAGE ON WAREHOUSE AGENT_COMMERCE_WH TO ROLE AGENT_COMMERCE_ROLE;

-- ----------------------------------------------------------------------------
-- STEP 6: Create Image Repository (for SPCS container images)
-- ----------------------------------------------------------------------------
USE SCHEMA UTIL;

CREATE IMAGE REPOSITORY IF NOT EXISTS AGENT_COMMERCE_REPO
    COMMENT = 'Docker image repository for SPCS containers';

-- ----------------------------------------------------------------------------
-- STEP 7: Create Compute Pool (for SPCS)
-- ----------------------------------------------------------------------------
CREATE COMPUTE POOL IF NOT EXISTS AGENT_COMMERCE_POOL
    MIN_NODES = 1
    MAX_NODES = 3
    INSTANCE_FAMILY = CPU_X64_S
    AUTO_SUSPEND_SECS = 300
    AUTO_RESUME = TRUE
    COMMENT = 'Compute pool for Agent Commerce SPCS services';

-- Grant usage on compute pool
GRANT USAGE ON COMPUTE POOL AGENT_COMMERCE_POOL TO ROLE AGENT_COMMERCE_ROLE;

-- ----------------------------------------------------------------------------
-- STEP 8: Create Stages for File Storage
-- ----------------------------------------------------------------------------

-- Stage for customer face images (temporary processing)
USE SCHEMA CUSTOMERS;
CREATE STAGE IF NOT EXISTS FACE_IMAGES
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Temporary storage for face images during analysis';

-- Stage for V2 face upload (agent-orchestrated analysis)
CREATE STAGE IF NOT EXISTS FACE_UPLOAD_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Face images uploaded via widget for agent to analyze with TOOL_ANALYZE_FACE';

-- Stage for product media (labels, swatches)
USE SCHEMA PRODUCTS;
CREATE STAGE IF NOT EXISTS PRODUCT_MEDIA
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Product images, labels, and media files';

-- Stage for retailer configuration
USE SCHEMA DEMO_CONFIG;
CREATE STAGE IF NOT EXISTS SETTINGS
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Retailer configuration files (retailer.json, logo.png)';

-- ============================================================================
-- STEP 9: Verify Setup
-- ============================================================================

-- Confirm we're using the correct role
SELECT CURRENT_ROLE() AS current_role;

-- Show all schemas
SHOW SCHEMAS IN DATABASE AGENT_COMMERCE;

-- Show warehouse
SHOW WAREHOUSES LIKE 'AGENT_COMMERCE_WH';

-- Show compute pool
SHOW COMPUTE POOLS LIKE 'AGENT_COMMERCE_POOL';

-- Show image repository
SHOW IMAGE REPOSITORIES IN SCHEMA AGENT_COMMERCE.UTIL;

-- Show stages
SHOW STAGES IN SCHEMA AGENT_COMMERCE.CUSTOMERS;
SHOW STAGES IN SCHEMA AGENT_COMMERCE.PRODUCTS;
SHOW STAGES IN SCHEMA AGENT_COMMERCE.DEMO_CONFIG;

-- Verify object ownership
SELECT 
    'DATABASE' AS object_type, 
    DATABASE_NAME AS object_name, 
    DATABASE_OWNER AS owner
FROM AGENT_COMMERCE.INFORMATION_SCHEMA.DATABASES
WHERE DATABASE_NAME = 'AGENT_COMMERCE'

UNION ALL

SELECT 
    'SCHEMA' AS object_type,
    SCHEMA_NAME AS object_name,
    SCHEMA_OWNER AS owner
FROM AGENT_COMMERCE.INFORMATION_SCHEMA.SCHEMATA
WHERE CATALOG_NAME = 'AGENT_COMMERCE'
ORDER BY object_type, object_name;

-- ----------------------------------------------------------------------------
-- Output repository URL for Docker push
-- ----------------------------------------------------------------------------
SELECT CONCAT(
    CURRENT_ACCOUNT_NAME(),
    '.registry.snowflakecomputing.com/',
    'agent_commerce/util/agent_commerce_repo'
) AS docker_registry_url;

-- ============================================================================
-- OPTIONAL: Grant Role to Other Users
-- ============================================================================
-- Uncomment and modify to grant access to other users:

-- GRANT ROLE AGENT_COMMERCE_ROLE TO USER other_user;

-- ============================================================================
-- NEXT STEPS:
-- 1. Run sql/02_create_tables.sql to create all tables (use AGENT_COMMERCE_ROLE)
-- 2. Run sql/03_create_cortex_services.sql for Cortex Search and Vector Search
-- ============================================================================
