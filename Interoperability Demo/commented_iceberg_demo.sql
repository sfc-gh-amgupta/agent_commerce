/*
================================================================================
INTEROPERABILITY DEMO: APACHE ICEBERG DATA PRODUCT
================================================================================
Purpose: Cross-region data sharing using Apache Iceberg format in Snowflake
Description: This script sets up a complete Marketing domain data product using
             Apache Iceberg table format, enabling interoperability across different
             cloud providers and regions. Iceberg tables stored in external S3 storage
             can be shared and accessed by other platforms while maintaining a single
             source of truth.

Contents:
  1. External Volume Setup - S3 storage configuration for Iceberg tables
  2. Marketing Domain Setup - Role, database, warehouse, and privileges
  3. Data Sharing Privileges - Permissions for listings and auto-fulfillment
  4. Iceberg Format Configuration - Catalog and external volume setup
  5. Create Iceberg Tables - Marketing fact and dimension tables
  6. Create Data Share - Share object for data distribution
  7. Create Data Product Listing - Marketplace publication with auto-fulfillment

Author: Amit Gupta
Last Updated: October 18, 2025
Reference: https://docs.snowflake.com/user-guide/tables-iceberg-configure-external-volume-s3
 
================================================================================
*/


-- ================================================================================
-- SECTION 1: EXTERNAL VOLUME SETUP
-- ================================================================================
-- Create an external volume that points to an S3 bucket for storing Iceberg
-- table metadata and data files. This enables Snowflake to read/write Iceberg
-- tables in an external location that can be accessed by other platforms.
-- ================================================================================

USE ROLE accountadmin;

-- Create the external volume with S3 storage configuration
-- This volume will be used to store all Iceberg table data for the marketing domain
CREATE OR REPLACE EXTERNAL VOLUME marketing_iceberg_vol
   STORAGE_LOCATIONS =
      (
         (
            NAME = 'interop-demo-iceberg-location'
            STORAGE_PROVIDER = 'S3'
            STORAGE_BASE_URL = 's3://amgupta-interop-demo-iceberg/'
            -- IAM role that Snowflake will assume to access the S3 bucket
            STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::484577546576:role/amgupta_snow_iceberg_access'
            -- External ID for additional security when assuming the IAM role
            STORAGE_AWS_EXTERNAL_ID = 'iceberg_table_external_id'
         )
      )
      -- Enable write operations to allow Snowflake to create and modify Iceberg tables
      ALLOW_WRITES = TRUE;

-- Get the Snowflake User ARN to configure the AWS IAM trust relationship
-- IMPORTANT: Copy the STORAGE_AWS_IAM_USER_ARN value from the output and add it to
-- the trust policy of the AWS IAM role 'amgupta_snow_iceberg_access'
DESC EXTERNAL VOLUME marketing_iceberg_vol;

-- Verify that Snowflake can successfully connect to the S3 bucket
-- This should return a success message if the configuration is correct
SELECT SYSTEM$VERIFY_EXTERNAL_VOLUME('marketing_iceberg_vol');


-- ================================================================================
-- SECTION 2: MARKETING DOMAIN SETUP
-- ================================================================================
-- Set up the complete infrastructure for the Marketing domain, including:
-- - Database to store Iceberg table references
-- - Role for marketing domain users with appropriate privileges
-- - Warehouse for compute resources
-- - Permissions for data sharing and listing creation
-- ================================================================================

USE ROLE accountadmin;

-- Create the marketing database that will hold Iceberg table references
CREATE OR REPLACE DATABASE marketing_db;

-- Create a dedicated role for marketing domain operations
CREATE ROLE marketing_domain_role;

-- Create a warehouse for marketing domain compute operations
CREATE WAREHOUSE marketing_wh;

-- Grant ownership of resources to the marketing domain role
GRANT OWNERSHIP ON WAREHOUSE marketing_wh TO ROLE marketing_domain_role;
GRANT OWNERSHIP ON DATABASE marketing_db TO ROLE marketing_domain_role;

-- Allow the marketing domain role to use the external volume for Iceberg tables
GRANT USAGE ON EXTERNAL VOLUME marketing_iceberg_vol TO ROLE marketing_domain_role;

-- ================================================================================
-- SECTION 3: DATA SHARING PRIVILEGES
-- ================================================================================
-- Grant privileges required for creating and managing data products:
-- - Auto-fulfillment: Automatically provision shared data to consumers
-- - Share creation: Create shares for data distribution
-- - Listing creation: Publish data products in the Data Marketplace
-- - Import share: Consume data products from other providers
-- ================================================================================

-- Enable global data sharing for the account (if not already enabled)
-- Uncomment and run as ORGADMIN if this is the first time setting up data sharing:
-- USE ROLE orgadmin;
-- SELECT SYSTEM$ENABLE_GLOBAL_DATA_SHARING_FOR_ACCOUNT('AMGUPTA_SNOW_AWS_USEAST');

-- Grant privileges for creating and managing data product listings
GRANT MANAGE LISTING AUTO FULFILLMENT ON ACCOUNT TO ROLE marketing_domain_role;
GRANT CREATE SHARE ON ACCOUNT TO ROLE marketing_domain_role;
GRANT CREATE ORGANIZATION LISTING ON ACCOUNT TO ROLE marketing_domain_role;

-- Grant privileges for consuming data products from other domains
USE ROLE accountadmin;
GRANT IMPORT SHARE ON ACCOUNT TO ROLE marketing_domain_role;
GRANT CREATE DATABASE ON ACCOUNT TO ROLE marketing_domain_role;

-- Assign the marketing domain role to a user (replace 'john' with actual username)
GRANT ROLE marketing_domain_role TO USER john;


-- ================================================================================
-- SECTION 4: ICEBERG FORMAT CONFIGURATION
-- ================================================================================
-- Configure the marketing database to use Iceberg as the default table format
-- and specify the external volume for storage.
-- ================================================================================

-- Set the catalog to SNOWFLAKE (Snowflake-managed Iceberg catalog)
ALTER DATABASE marketing_db SET CATALOG = 'SNOWFLAKE';

-- Set the default external volume for all Iceberg tables in this database
ALTER DATABASE marketing_db SET EXTERNAL_VOLUME = 'marketing_iceberg_vol';


-- ================================================================================
-- SECTION 5: CREATE ICEBERG TABLES
-- ================================================================================
-- Create Iceberg format tables in the marketing database by copying data from
-- an existing demo schema. These tables will be stored in the S3 bucket and
-- can be accessed by other platforms that support Apache Iceberg.
-- ================================================================================

USE ROLE marketing_domain_role;

-- Create a schema to organize marketing Iceberg tables
CREATE SCHEMA marketing_db.iceberg_data;

-- Create Iceberg tables by copying data from the source demo database
-- Each table represents a different aspect of the marketing domain:

-- Salesforce accounts data
CREATE OR REPLACE ICEBERG TABLE marketing_db.iceberg_data.sf_accounts 
AS SELECT * FROM sf_ai_demo.demo_schema.sf_accounts;

-- Marketing campaign performance metrics (fact table)
CREATE OR REPLACE ICEBERG TABLE marketing_db.iceberg_data.MARKETING_CAMPAIGN_FACT 
AS SELECT * FROM sf_ai_demo.demo_schema.MARKETING_CAMPAIGN_FACT;

-- Campaign dimension table (campaign details and metadata)
CREATE OR REPLACE ICEBERG TABLE marketing_db.iceberg_data.CAMPAIGN_DIM 
AS SELECT * FROM sf_ai_demo.demo_schema.CAMPAIGN_DIM;

-- Marketing channel dimension (email, social media, paid ads, etc.)
CREATE OR REPLACE ICEBERG TABLE marketing_db.iceberg_data.CHANNEL_DIM 
AS SELECT * FROM sf_ai_demo.demo_schema.CHANNEL_DIM;

-- Salesforce contacts data
CREATE OR REPLACE ICEBERG TABLE marketing_db.iceberg_data.SF_CONTACTS 
AS SELECT * FROM sf_ai_demo.demo_schema.SF_CONTACTS;

-- Salesforce opportunities data
CREATE OR REPLACE ICEBERG TABLE marketing_db.iceberg_data.SF_OPPORTUNITIES 
AS SELECT * FROM sf_ai_demo.demo_schema.SF_OPPORTUNITIES;

-- Product dimension table
CREATE OR REPLACE ICEBERG TABLE marketing_db.iceberg_data.PRODUCT_DIM 
AS SELECT * FROM sf_ai_demo.demo_schema.PRODUCT_DIM;

-- Geographic region dimension table
CREATE OR REPLACE ICEBERG TABLE marketing_db.iceberg_data.REGION_DIM 
AS SELECT * FROM sf_ai_demo.demo_schema.REGION_DIM;


-- ================================================================================
-- SECTION 6: CREATE DATA SHARE
-- ================================================================================
-- Create a share object that defines what data will be made available to consumers.
-- The share includes all Iceberg tables in the marketing schema.
-- ================================================================================

USE ROLE marketing_domain_role;

-- Create a new share for the marketing data product
CREATE OR REPLACE SHARE marketing_data_share;

-- Grant database and schema access to the share
GRANT USAGE ON DATABASE marketing_db TO SHARE marketing_data_share;
GRANT USAGE ON SCHEMA marketing_db.iceberg_data TO SHARE marketing_data_share;

-- Grant SELECT privileges on all Iceberg tables to the share
-- Consumers will be able to query these tables but not modify them
GRANT SELECT ON ALL ICEBERG TABLES IN SCHEMA marketing_db.iceberg_data TO SHARE marketing_data_share;

-- View the contents of the share to verify configuration
DESCRIBE SHARE marketing_data_share;


-- ================================================================================
-- SECTION 7: CREATE DATA PRODUCT LISTING
-- ================================================================================
-- Publish the marketing data as a discoverable data product with comprehensive
-- metadata, access controls, and auto-fulfillment configuration.
--
-- This listing enables:
-- - Cross-region access (AWS US East to AWS US West, Azure US East)
-- - Automated provisioning of data to approved consumers
-- - Real-time synchronization with 1-minute refresh interval
-- - Request-based access approval workflow
-- ================================================================================

-- Clean up any existing listing (optional - for development/testing)
ALTER LISTING marketing_data_product UNPUBLISH;
DROP LISTING marketing_data_product;

-- Create a new organization listing for the marketing data product
CREATE ORGANIZATION LISTING marketing_data_product
SHARE marketing_data_share AS
$$
-- Listing title visible in the Data Marketplace
title: "[Interop Apache Iceberg X-Region] Marketing Facts"

-- Detailed description using Markdown format
description: "This data listing provides a comprehensive overview of **marketing campaigns** within our enterprise. It's a key resource for the marketing team, analysts, and business leaders to evaluate campaign effectiveness, optimize spending, and understand customer engagement. The dataset includes information on various marketing channels, campaign costs, and key performance metrics\n\n**Data Contract SLO**\n\n- **Frequency:** Updated every minute for realtime marketing events\n- **Source:** Data is curated from our various marketing platforms (e.g., Google Ads, Meta Ads Manager, Mailchimp)\n- **Access:** By Request. Access is restricted to authorized personnel to be determined by owner\n- **PII**"

-- Data preview configuration
data_preview:
  has_pii: true  -- Indicates the dataset contains Personally Identifiable Information

-- Data dictionary: highlights key tables in the listing
data_dictionary:
 featured:
    database: 'MARKETING_DB'
    objects:
      -- Core marketing campaign dimension table
      - schema: '"ICEBERG_DATA"'
        domain: 'ICEBERG TABLE'
        name: '"CAMPAIGN_DIM"'
      -- Main fact table with campaign metrics
      - schema: '"ICEBERG_DATA"'
        domain: 'ICEBERG TABLE'
        name: '"MARKETING_CAMPAIGN_FACT"'

-- Links to external documentation and resources
resources:
  documentation: https://www.example.com/documentation/marketing
  media: https://www.youtube.com/watch?v=MEFlT3dc3uc

-- Listing visibility: internal to the organization
organization_profile: 'INTERNAL'

-- Target accounts and roles that can discover and access this listing
organization_targets:
  discovery:
    # Make discoverable to all accounts in the organization
    - all_internal_accounts: true
  access:
    # AWS US West account - Sales domain access
    - account: 'AMGUPTA_SNOW_AWSUSWEST1'
      roles:
        - 'SALES_DOMAIN_ROLE'
    # Azure US East account - Finance domain access
    - account: 'AMGUPTA_SNOW_AZUREUSEAST'
      roles:
        - 'FINANCE_DOMAIN_ROLE'

-- Access control: requires request and approval workflow
request_approval_type: 'REQUEST_AND_APPROVE_IN_SNOWFLAKE'

-- Contact information
support_contact: "marketing_domain_dl@snowflake.com"
approver_contact: "amit.gupta@snowflake.com"

-- Regional access configuration
locations:
  access_regions:
  - name: "ALL"  -- Available in all regions

-- Auto-fulfillment configuration for automatic data provisioning
auto_fulfillment:
  refresh_type: 'SUB_DATABASE'  -- Replicate at the database level
  refresh_schedule: '1 MINUTE'  -- Sync data every minute for near real-time updates
  refresh_schedule_override: true  -- Allow consumers to override the refresh schedule

$$ PUBLISH=true;  -- Publish the listing immediately

-- ================================================================================
-- END OF SCRIPT
-- ================================================================================
-- Next Steps:
-- 1. Verify the listing appears in the Data Marketplace
-- 2. Test access from target consumer accounts
-- 3. Monitor auto-fulfillment logs for successful data synchronization
-- 4. Update the listing description and metadata as needed
-- ================================================================================

