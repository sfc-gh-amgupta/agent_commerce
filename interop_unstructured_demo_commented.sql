/*
================================================================================
INTEROPERABILITY UNSTRUCTURED DATA DEMO
================================================================================
Purpose: Demonstrate Cortex Knowledge Extensions for vectorizing and sharing unstructured documents
Description: This script demonstrates how to use Cortex Knowledge Extensions to vectorize 
             unstructured documents from S3 and share them across regions and clouds
             using Snowflake's data sharing capabilities. It showcases AI-powered document
             parsing, semantic search, and governed cross-cloud data products.

Contents:
  1. AWS S3 Storage Integration Setup
  2. Enterprise Domain Setup (RBAC and resource provisioning)
  3. Stage Creation and Document Access
  4. Document Parsing with Cortex AI
  5. Cortex Search Services Creation (Finance, HR, Marketing, Sales)
  6. Data Sharing Configuration
  7. Organization Listing Creation (Cross-cloud/Cross-region)

Author: Amit Gupta
Last Updated: October 18, 2025
Demo: Available at Interoperable Data Mesh Webinar - https://www.snowflake.com/en/webinars/demo/unlocking-ai-with-an-interoperable-data-mesh-2025-10-16/
 
================================================================================
*/


-- ================================================================================
-- SECTION 1: AWS S3 Storage Integration Setup
-- ================================================================================
-- This section creates a storage integration that allows Snowflake to securely
-- access unstructured documents stored in an AWS S3 bucket.
-- Reference: https://docs.snowflake.com/en/user-guide/data-load-s3-config-storage-integration
-- ================================================================================

USE ROLE accountadmin;

-- Create storage integration for accessing S3 bucket containing unstructured documents
-- This establishes trust between Snowflake and AWS IAM for secure data access
CREATE OR REPLACE STORAGE INTEGRATION enterprise_unstructured_storage
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::484577546576:role/amgupta_snow_unstructured_access'
  STORAGE_ALLOWED_LOCATIONS = ('*');

-- Retrieve Snowflake's IAM user ARN and external ID
-- These values must be added to the AWS IAM role's trust policy
DESC INTEGRATION enterprise_unstructured_storage;


-- ================================================================================
-- SECTION 2: Enterprise Domain Setup
-- ================================================================================
-- Creates the enterprise database, schema, role, and warehouse that will house
-- the unstructured data and search services. This establishes proper RBAC.
-- ================================================================================

USE ROLE accountadmin;

-- Create core database and schema for enterprise unstructured data
CREATE OR REPLACE DATABASE enterprise_db;
CREATE OR REPLACE SCHEMA enterprise_db.S3_UNSTRUCTURED_DATA;

-- Create dedicated role for enterprise domain management
CREATE ROLE enterprise_domain_role;

-- Create warehouse for processing and search operations
CREATE OR REPLACE WAREHOUSE enterprise_wh;

-- Grant ownership of resources to enterprise domain role
GRANT OWNERSHIP ON WAREHOUSE enterprise_wh TO ROLE enterprise_domain_role;
GRANT OWNERSHIP ON DATABASE enterprise_db TO ROLE enterprise_domain_role;
GRANT OWNERSHIP ON SCHEMA enterprise_db.S3_UNSTRUCTURED_DATA TO ROLE enterprise_domain_role;

-- Grant necessary privileges for stage and integration usage
GRANT CREATE STAGE ON SCHEMA enterprise_db.S3_UNSTRUCTURED_DATA TO ROLE enterprise_domain_role;
GRANT USAGE ON INTEGRATION enterprise_unstructured_storage TO ROLE enterprise_domain_role;

-- Grant privileges for data sharing and listing creation
-- Note: Uncomment below to enable global data sharing if not already enabled
-- USE ROLE orgadmin;
-- SELECT SYSTEM$ENABLE_GLOBAL_DATA_SHARING_FOR_ACCOUNT('AMGUPTA_SNOW_AWS_USEAST');

GRANT MANAGE LISTING AUTO FULFILLMENT ON ACCOUNT TO ROLE enterprise_domain_role;
GRANT CREATE SHARE ON ACCOUNT TO ROLE enterprise_domain_role;
GRANT CREATE ORGANIZATION LISTING ON ACCOUNT TO ROLE enterprise_domain_role;

-- Grant privileges for consuming shared data
USE ROLE accountadmin;
GRANT IMPORT SHARE ON ACCOUNT TO ROLE enterprise_domain_role;
GRANT CREATE DATABASE ON ACCOUNT TO ROLE enterprise_domain_role;

-- Assign enterprise domain role to user 'john'
GRANT ROLE enterprise_domain_role TO USER john;


-- ================================================================================
-- SECTION 3: Stage Creation and Document Access
-- ================================================================================
-- Creates an external stage pointing to the S3 bucket and validates connectivity
-- by listing available documents.
-- ================================================================================

USE SCHEMA enterprise_db.S3_UNSTRUCTURED_DATA;
USE ROLE enterprise_domain_role;

-- Create external stage with directory table enabled for easy file discovery
CREATE OR REPLACE STAGE enterprise_unstructured_stage
  STORAGE_INTEGRATION = enterprise_unstructured_storage
  URL = 's3://amgupta-interop-demo-unstructured/'
  DIRECTORY = (ENABLE = TRUE);

-- Test connectivity and list all PDF files in the stage
-- This query demonstrates how to build file URLs and convert files to Snowflake objects
SELECT 
    relative_path,
    BUILD_STAGE_FILE_URL('@ENTERPRISE_DB.S3_UNSTRUCTURED_DATA.ENTERPRISE_UNSTRUCTURED_STAGE', relative_path) AS file_url,
    TO_FILE(BUILD_STAGE_FILE_URL('@ENTERPRISE_DB.S3_UNSTRUCTURED_DATA.ENTERPRISE_UNSTRUCTURED_STAGE', relative_path)) AS file_object
FROM directory(@ENTERPRISE_DB.S3_UNSTRUCTURED_DATA.ENTERPRISE_UNSTRUCTURED_STAGE) 
WHERE relative_path ILIKE '%.pdf';


-- ================================================================================
-- SECTION 4: Document Parsing with Cortex AI
-- ================================================================================
-- Uses Snowflake's AI_PARSE_DOCUMENT function to extract text content from PDFs
-- and store it in a structured table for downstream processing.
-- ================================================================================

-- Create table with parsed document content
-- AI_PARSE_DOCUMENT extracts text using LAYOUT mode for better structure preservation
CREATE TABLE IF NOT EXISTS parsed_content AS 
SELECT 
    relative_path,
    BUILD_STAGE_FILE_URL('@ENTERPRISE_DB.S3_UNSTRUCTURED_DATA.ENTERPRISE_UNSTRUCTURED_STAGE', relative_path) AS file_url,
    TO_FILE(BUILD_STAGE_FILE_URL('@ENTERPRISE_DB.S3_UNSTRUCTURED_DATA.ENTERPRISE_UNSTRUCTURED_STAGE', relative_path)) AS file_object,
    AI_PARSE_DOCUMENT(
        TO_FILE('@ENTERPRISE_DB.S3_UNSTRUCTURED_DATA.ENTERPRISE_UNSTRUCTURED_STAGE', relative_path), 
        {'mode': 'LAYOUT'}
    ):content::STRING AS Content 
FROM directory(@ENTERPRISE_DB.S3_UNSTRUCTURED_DATA.ENTERPRISE_UNSTRUCTURED_STAGE) 
WHERE relative_path ILIKE '%.pdf';


-- ================================================================================
-- SECTION 5: Cortex Search Services Creation
-- ================================================================================
-- Creates department-specific search services using Cortex Search.
-- Each search service enables semantic search over documents from a specific
-- business function (Finance, HR, Marketing, Sales).
-- ================================================================================

USE ROLE enterprise_domain_role;
USE SCHEMA enterprise_db.s3_unstructured_data;

-- --------------------------------------------------------------------------------
-- Finance Documents Search Service
-- --------------------------------------------------------------------------------
-- Enables semantic search over finance-related documents
-- Uses Snowflake Arctic embedding model for high-quality vector representations
CREATE CORTEX SEARCH SERVICE IF NOT EXISTS Search_finance_docs
    ON content
    ATTRIBUTES relative_path, file_url, title
    WAREHOUSE = ENTERPRISE_WH
    TARGET_LAG = '30 day'
    EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
    AS (
        SELECT
            relative_path,
            file_url,
            REGEXP_SUBSTR(relative_path, '[^/]+$') AS title,  -- Extract filename as document title
            content
        FROM parsed_content
        WHERE relative_path ILIKE '%finance/%'
    );

-- --------------------------------------------------------------------------------
-- HR Documents Search Service
-- --------------------------------------------------------------------------------
-- Enables semantic search over HR-related documents
-- Useful for employee handbooks, policies, and HR communications
CREATE CORTEX SEARCH SERVICE IF NOT EXISTS Search_hr_docs
    ON content
    ATTRIBUTES relative_path, file_url, title
    WAREHOUSE = ENTERPRISE_WH
    TARGET_LAG = '30 day'
    EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
    AS (
        SELECT
            relative_path,
            file_url,
            REGEXP_SUBSTR(relative_path, '[^/]+$') AS title,
            content
        FROM parsed_content
        WHERE relative_path ILIKE '%hr/%'
    );

-- --------------------------------------------------------------------------------
-- Marketing Documents Search Service
-- --------------------------------------------------------------------------------
-- Enables semantic search over marketing-related documents
-- Includes campaigns, collateral, presentations, and marketing materials
CREATE CORTEX SEARCH SERVICE IF NOT EXISTS Search_marketing_docs
    ON content
    ATTRIBUTES relative_path, file_url, title
    WAREHOUSE = ENTERPRISE_WH
    TARGET_LAG = '30 day'
    EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
    AS (
        SELECT
            relative_path,
            file_url,
            REGEXP_SUBSTR(relative_path, '[^/]+$') AS title,
            content
        FROM parsed_content
        WHERE relative_path ILIKE '%marketing/%'
    );

-- --------------------------------------------------------------------------------
-- Sales Documents Search Service
-- --------------------------------------------------------------------------------
-- Enables semantic search over sales-related documents
-- Includes proposals, contracts, presentations, and sales enablement materials
CREATE CORTEX SEARCH SERVICE IF NOT EXISTS Search_sales_docs
    ON content
    ATTRIBUTES relative_path, file_url, title
    WAREHOUSE = ENTERPRISE_WH
    TARGET_LAG = '30 day'
    EMBEDDING_MODEL = 'snowflake-arctic-embed-l-v2.0'
    AS (
        SELECT
            relative_path,
            file_url,
            REGEXP_SUBSTR(relative_path, '[^/]+$') AS title,
            content
        FROM parsed_content
        WHERE relative_path ILIKE '%sales/%'
    );


-- ================================================================================
-- SECTION 6: Data Sharing Configuration
-- ================================================================================
-- Creates a share containing all Cortex Search Services and grants access
-- to specific accounts and roles across different regions and cloud providers.
-- ================================================================================

-- Create share for distributing search services
CREATE SHARE IF NOT EXISTS enterprise_unstructured_share;

-- Grant necessary privileges on database and schema to the share
GRANT USAGE ON DATABASE enterprise_db TO SHARE enterprise_unstructured_share;
GRANT USAGE ON SCHEMA enterprise_db.s3_unstructured_data TO SHARE enterprise_unstructured_share;

-- Grant usage on all department-specific search services
GRANT USAGE ON CORTEX SEARCH SERVICE search_finance_docs TO SHARE enterprise_unstructured_share;
GRANT USAGE ON CORTEX SEARCH SERVICE search_hr_docs TO SHARE enterprise_unstructured_share;
GRANT USAGE ON CORTEX SEARCH SERVICE search_marketing_docs TO SHARE enterprise_unstructured_share;
GRANT USAGE ON CORTEX SEARCH SERVICE search_sales_docs TO SHARE enterprise_unstructured_share;


-- ================================================================================
-- SECTION 7: Organization Listing Creation
-- ================================================================================
-- Creates a published data product listing that makes the search services
-- discoverable and accessible to internal accounts across regions/clouds.
-- ================================================================================

-- Cleanup commands (commented out - use when needed to reset listing)
-- ALTER LISTING enterprise_data_product UNPUBLISH;
-- DROP LISTING enterprise_data_product;

-- Create organization listing for enterprise unstructured data product
-- This listing enables cross-region, cross-cloud sharing with governance
CREATE ORGANIZATION LISTING IF NOT EXISTS enterprise_data_product
SHARE enterprise_unstructured_share AS
$$
title: "[Interop Unstructured CKE X-Region] Enterprise Documents"

description: "This data listing provides access to a consolidated collection of **unstructured documents** from key functional areas across the enterprise: Sales, Finance, Marketing, and HR. This dataset is a rich, though raw, source of qualitative and detailed business information. It's intended for advanced data science, Natural Language Processing (NLP) initiatives, and deep business process analysis.\n\n**Data Contract SLO**\n\n- **Frequency:** Updated every minute for realtime marketing events\n- **Source:** Data is aggregated from various content repositories (e.g., SharePoint, shared drives, email servers, CRM document attachments)\n- **Access:** By Request. Access is restricted to authorized personnel to be determined by owner\n- **PII:** Sensitive information may be present; handle according to data governance policies"

resources:
  documentation: https://www.example.com/documentation/marketing
  media: https://www.youtube.com/watch?v=MEFlT3dc3uc

organization_profile: 'INTERNAL'

organization_targets:
  discovery:
    - all_internal_accounts: true  -- Make discoverable to all internal accounts
  access:
    - account: 'AMGUPTA_SNOW_AWSUSWEST1'  -- AWS US West account
      roles:
        - 'SALES_DOMAIN_ROLE'
    - account: 'AMGUPTA_SNOW_AZUREUSEAST'  -- Azure US East account
      roles:
        - 'FINANCE_DOMAIN_ROLE'

request_approval_type: 'REQUEST_AND_APPROVE_IN_SNOWFLAKE'

support_contact: "marketing_domain_dl@snowflake.com"
approver_contact: "amit.gupta@snowflake.com"

locations:
  access_regions:
  - name: "ALL"  -- Available in all regions

auto_fulfillment:
  refresh_type: 'SUB_DATABASE'
  refresh_schedule: '1 MINUTE'  -- Near real-time refresh
  refresh_schedule_override: true

$$ PUBLISH=true;


-- ================================================================================
-- END OF DEMO
-- ================================================================================
-- Summary:
-- This demo showcases Snowflake's capabilities for:
--   1. Integrating with external cloud storage (AWS S3)
--   2. Processing unstructured data using Cortex AI
--   3. Creating semantic search services with embeddings
--   4. Sharing AI-powered search capabilities across regions and clouds
--   5. Implementing governed data products with SLOs and access controls
--
-- Use Cases:
--   - Enterprise knowledge management
--   - Document search and discovery
--   - Cross-functional data collaboration
--   - AI/ML feature engineering from unstructured data
-- ================================================================================

