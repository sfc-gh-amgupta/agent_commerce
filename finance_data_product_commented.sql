/*
================================================================================
FINANCE DATA PRODUCT WITH SEMANTIC VIEWS
================================================================================
Purpose: Create a Finance Data Product with semantic views and cross-cloud sharing
Description: This script demonstrates how to build a complete Finance data product
             in Snowflake with cross-cloud interoperability, semantic views, and
             auto-fulfillment capabilities for data sharing. It includes finance
             domain setup, data ingestion, organization listing creation, and
             semantic view definitions that enable natural language queries.

Contents:
  1. Finance Domain Setup - Role, warehouse, database, and permissions
  2. Data Sharing Privileges - Account-level grants for data products
  3. Data Ingestion - Copy tables from interop share
  4. Finance Data Product Share - Create and configure secure share
  5. Organization Listing - Publish with metadata and auto-fulfillment
  6. Finance Semantic View - Business-friendly interface for analytics
  7. Testing & Validation - Verify semantic view configuration

Author: Amit Gupta
Last Updated: October 18, 2025
Demo: Available at Interoperable Data Mesh Webinar - https://www.snowflake.com/en/webinars/demo/unlocking-ai-with-an-interoperable-data-mesh-2025-10-16/
 
================================================================================
*/

-- ================================================================================
-- SECTION 1: FINANCE DOMAIN SETUP
-- ================================================================================
-- This section creates the foundational infrastructure for the finance domain
-- including role, warehouse, and database with appropriate ownership grants.
-- ================================================================================

USE ROLE accountadmin;

-- Create the finance database to store all finance-related data
CREATE OR REPLACE DATABASE finance_db;

-- Create a dedicated role for finance domain operations
-- This role will own and manage all finance data and resources
CREATE ROLE finance_domain_role;

-- Create a dedicated warehouse for finance workloads
CREATE WAREHOUSE finance_wh;

-- Transfer ownership of the warehouse to the finance domain role
GRANT OWNERSHIP ON WAREHOUSE finance_wh TO ROLE finance_domain_role;

-- Transfer ownership of the database to the finance domain role
GRANT OWNERSHIP ON DATABASE finance_db TO ROLE finance_domain_role;

-- ================================================================================
-- SECTION 2: DATA SHARING PRIVILEGES
-- ================================================================================
-- Configure account-level privileges required for creating and managing
-- data products with auto-fulfillment capabilities.
-- ================================================================================

-- OPTIONAL: Enable global data sharing for the account (requires ORGADMIN role)
-- Uncomment the following lines if this feature needs to be enabled:
-- USE ROLE orgadmin;
-- SELECT SYSTEM$ENABLE_GLOBAL_DATA_SHARING_FOR_ACCOUNT('AMGUPTA_SNOW_AZUREUSEAST');

-- Grant permission to manage listing auto-fulfillment
-- This allows automatic provisioning of data to approved consumers
GRANT MANAGE LISTING AUTO FULFILLMENT ON ACCOUNT TO ROLE finance_domain_role;

-- Grant permission to create shares for data distribution
GRANT CREATE SHARE ON ACCOUNT TO ROLE finance_domain_role;

-- Grant permission to create organization-wide data listings
GRANT CREATE ORGANIZATION LISTING ON ACCOUNT TO ROLE finance_domain_role;

USE ROLE accountadmin;

-- Grant permission to import shares from other accounts
GRANT IMPORT SHARE ON ACCOUNT TO ROLE finance_domain_role;

-- Grant permission to create databases (needed for share consumption)
GRANT CREATE DATABASE ON ACCOUNT TO ROLE finance_domain_role;

-- Grant HR domain role to accountadmin for cross-domain access
GRANT ROLE hr_domain_role TO ROLE accountadmin;

-- Assign the finance domain role to user 'john'
GRANT ROLE finance_domain_role TO USER john;

-- ================================================================================
-- SECTION 3: DATA INGESTION FROM INTEROP SHARE
-- ================================================================================
-- Create Snowflake-native tables by copying data from an existing interoperability
-- share. This demonstrates cross-platform/cross-cloud data consumption.
-- ================================================================================

USE ROLE finance_domain_role;

-- Create a schema to hold Snowflake-native data copies
CREATE OR REPLACE SCHEMA finance_db.snow_data;

-- Copy the finance transactions fact table
-- Contains all financial transaction records across the organization
CREATE OR REPLACE TABLE finance_db.snow_data.FINANCE_TRANSACTIONS 
AS SELECT * FROM ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.FINANCE_TRANSACTIONS;

-- Copy the account dimension table
-- Contains chart of accounts information for financial categorization
CREATE OR REPLACE TABLE finance_db.snow_data.ACCOUNT_DIM 
AS SELECT * FROM ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.ACCOUNT_DIM;

-- Copy the department dimension table
-- Contains organizational department/cost center information
CREATE OR REPLACE TABLE finance_db.snow_data.DEPARTMENT_DIM 
AS SELECT * FROM ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.DEPARTMENT_DIM;

-- Copy the vendor dimension table
-- Contains supplier/vendor information for spend analysis
CREATE OR REPLACE TABLE finance_db.snow_data.VENDOR_DIM 
AS SELECT * FROM ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.VENDOR_DIM;

-- Copy the product dimension table
-- Contains product/item information for transaction analysis
CREATE OR REPLACE TABLE finance_db.snow_data.PRODUCT_DIM 
AS SELECT * FROM ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.PRODUCT_DIM;

-- Copy the customer dimension table
-- Contains customer information for revenue analysis
CREATE OR REPLACE TABLE finance_db.snow_data.CUSTOMER_DIM 
AS SELECT * FROM ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.CUSTOMER_DIM;

-- ================================================================================
-- SECTION 4: CREATE FINANCE DATA PRODUCT SHARE
-- ================================================================================
-- Create a secure share containing the finance data and configure it as an
-- organization listing with auto-fulfillment for approved consumers.
-- ================================================================================

USE ROLE finance_domain_role;

-- Create a new share for the finance data product
CREATE OR REPLACE SHARE finance_data_share;

-- Grant usage on the database to the share
GRANT USAGE ON DATABASE finance_db TO SHARE finance_data_share;

-- Grant usage on the schema to the share
GRANT USAGE ON SCHEMA finance_db.snow_data TO SHARE finance_data_share;

-- Grant select permissions on all tables in the schema to the share
GRANT SELECT ON ALL TABLES IN SCHEMA finance_db.snow_data TO SHARE finance_data_share;

-- Verify the share configuration
DESCRIBE SHARE finance_data_share;

-- ================================================================================
-- SECTION 5: CREATE ORGANIZATION LISTING
-- ================================================================================
-- Publish the finance data product as an organization listing with rich metadata,
-- data governance policies, and auto-fulfillment configuration.
-- ================================================================================

-- Clean up any existing listing (if re-running this script)
ALTER LISTING finance_data_product UNPUBLISH;
DROP LISTING finance_data_product;

-- Create the organization listing with comprehensive metadata
CREATE ORGANIZATION LISTING finance_data_product
SHARE finance_data_share AS
$$
title: "[Interop Snowflake Native X-Cloud] Finance Facts"

description: "This data listing provides a comprehensive overview of **financial activity** within our enterprise.  It is the definitive source for tracking, analyzing, and reporting on the company's fiscal health and performance. This dataset is compiled from the General Ledger (GL) and is structured to facilitate the generation of all primary financial statements (Income Statement, Balance Sheet, and Cash Flow).\n\n**Data Contract SLO**\n\n- **Frequency:** Updated every day for finance events\n- **Source:** Data is curated from our Enterprise Resource Planning (ERP) system\n- **Access:** By Request. Access is restricted to authorized personnel to be determined by owner\n- **no PII**"

-- Configure data preview settings (PII flag for governance)
data_preview:
  has_pii: true

-- Define the data dictionary highlighting key tables
data_dictionary:
 featured:
    database: 'FINANCE_DB'
    objects:
      - schema: '"SNOW_DATA"'
        domain: 'TABLE'
        name: '"ACCOUNT_DIM"'
      - schema: '"SNOW_DATA"'
        domain: 'TABLE'
        name: '"FINANCE_TRANSACTIONS"'

-- Provide links to documentation and demo resources
resources:
  documentation: https://www.example.com/documentation/finance
  media: https://www.youtube.com/watch?v=MEFlT3dc3uc

-- Set organization profile (internal sharing within organization)
organization_profile: 'INTERNAL'

-- Configure which accounts can discover and access this listing
organization_targets:
  discovery:
    - all_internal_accounts: true
  access:
    - account: 'AMGUPTA_SNOW_AWSUSWEST1'
      roles:
        - 'SALES_DOMAIN_ROLE'
    - account: 'AMGUPTA_SNOW_AWS_USEAST'
      roles:
        - 'HR_DOMAIN_ROLE'

-- Set approval workflow (requests must be approved in Snowflake)
request_approval_type: 'REQUEST_AND_APPROVE_IN_SNOWFLAKE'

-- Define support and approval contacts
support_contact: "finance_domain_dl@snowflake.com"
approver_contact: "amit.gupta@snowflake.com"

-- Configure cross-cloud access (available in all regions)
locations:
  access_regions:
  - name: "ALL"

-- Configure auto-fulfillment settings
auto_fulfillment:
  refresh_type: 'SUB_DATABASE'              # Use sub-database refresh for efficiency
  refresh_schedule: '1 MINUTE'              # Refresh every minute for near real-time data
  refresh_schedule_override: true           # Override default refresh schedule

$$ PUBLISH=true;  -- Immediately publish the listing

-- ================================================================================
-- SECTION 6: CREATE SEMANTIC VIEW
-- ================================================================================
-- Define a semantic view that provides a business-friendly abstraction layer
-- over the finance data model. This enables natural language queries and
-- simplifies BI tool integration.
-- ================================================================================

USE ROLE finance_domain_role;
USE SCHEMA finance_db.snow_data;

CREATE OR REPLACE SEMANTIC VIEW FINANCE_SEMANTIC_VIEW
    -- Define the tables (entities) included in the semantic model
    tables (
        TRANSACTIONS as FINANCE_TRANSACTIONS 
            primary key (TRANSACTION_ID) 
            with synonyms=('finance transactions','financial data') 
            comment='All financial transactions across departments',
        
        ACCOUNTS as ACCOUNT_DIM 
            primary key (ACCOUNT_KEY) 
            with synonyms=('chart of accounts','account types') 
            comment='Account dimension for financial categorization',
        
        DEPARTMENTS as DEPARTMENT_DIM 
            primary key (DEPARTMENT_KEY) 
            with synonyms=('business units','departments') 
            comment='Department dimension for cost center analysis',
        
        VENDORS as VENDOR_DIM 
            primary key (VENDOR_KEY) 
            with synonyms=('suppliers','vendors') 
            comment='Vendor information for spend analysis',
        
        PRODUCTS as PRODUCT_DIM 
            primary key (PRODUCT_KEY) 
            with synonyms=('products','items') 
            comment='Product dimension for transaction analysis',
        
        CUSTOMERS as CUSTOMER_DIM 
            primary key (CUSTOMER_KEY) 
            with synonyms=('clients','customers') 
            comment='Customer dimension for revenue analysis'
    )
    
    -- Define relationships between tables (foreign key relationships)
    relationships (
        TRANSACTIONS_TO_ACCOUNTS as 
            TRANSACTIONS(ACCOUNT_KEY) references ACCOUNTS(ACCOUNT_KEY),
        
        TRANSACTIONS_TO_DEPARTMENTS as 
            TRANSACTIONS(DEPARTMENT_KEY) references DEPARTMENTS(DEPARTMENT_KEY),
        
        TRANSACTIONS_TO_VENDORS as 
            TRANSACTIONS(VENDOR_KEY) references VENDORS(VENDOR_KEY),
        
        TRANSACTIONS_TO_PRODUCTS as 
            TRANSACTIONS(PRODUCT_KEY) references PRODUCTS(PRODUCT_KEY),
        
        TRANSACTIONS_TO_CUSTOMERS as 
            TRANSACTIONS(CUSTOMER_KEY) references CUSTOMERS(CUSTOMER_KEY)
    )
    
    -- Define facts (measures that can be aggregated)
    facts (
        TRANSACTIONS.TRANSACTION_AMOUNT as amount 
            comment='Transaction amount in dollars',
        
        TRANSACTIONS.TRANSACTION_RECORD as 1 
            comment='Count of transactions'
    )
    
    -- Define dimensions (attributes for grouping and filtering)
    dimensions (
        TRANSACTIONS.TRANSACTION_DATE as date 
            with synonyms=('date','transaction date') 
            comment='Date of the financial transaction',
        
        TRANSACTIONS.TRANSACTION_MONTH as MONTH(date) 
            comment='Month of the transaction',
        
        TRANSACTIONS.TRANSACTION_YEAR as YEAR(date) 
            comment='Year of the transaction',
        
        ACCOUNTS.ACCOUNT_NAME as account_name 
            with synonyms=('account','account type') 
            comment='Name of the account',
        
        ACCOUNTS.ACCOUNT_TYPE as account_type 
            with synonyms=('type','category') 
            comment='Type of account (Income/Expense)',
        
        DEPARTMENTS.DEPARTMENT_NAME as department_name 
            with synonyms=('department','business unit') 
            comment='Name of the department',
        
        VENDORS.VENDOR_NAME as vendor_name 
            with synonyms=('vendor','supplier') 
            comment='Name of the vendor',
        
        PRODUCTS.PRODUCT_NAME as product_name 
            with synonyms=('product','item') 
            comment='Name of the product',
        
        CUSTOMERS.CUSTOMER_NAME as customer_name 
            with synonyms=('customer','client') 
            comment='Name of the customer'
    )
    
    -- Define metrics (pre-calculated aggregations)
    metrics (
        TRANSACTIONS.AVERAGE_AMOUNT as AVG(transactions.amount) 
            comment='Average transaction amount',
        
        TRANSACTIONS.TOTAL_AMOUNT as SUM(transactions.amount) 
            comment='Total transaction amount',
        
        TRANSACTIONS.TOTAL_TRANSACTIONS as COUNT(transactions.transaction_record) 
            comment='Total number of transactions'
    )
    comment='Semantic view for financial analysis and reporting';

-- ================================================================================
-- SECTION 7: TEST AND VALIDATE SEMANTIC VIEW
-- ================================================================================
-- Verify that the semantic view is properly configured and can be queried.
-- ================================================================================

USE SCHEMA finance_db.snow_data;

-- Display all semantic views in the current schema
SHOW SEMANTIC VIEWS;

-- Display all dimensions defined in semantic views
SHOW SEMANTIC DIMENSIONS;

-- Display all metrics defined in semantic views
SHOW SEMANTIC METRICS;

-- ================================================================================
-- SECTION 8: EXAMPLE QUERIES
-- ================================================================================

-- Example 1: Query the semantic view with account dimension
-- This query aggregates data by account name
SELECT * FROM SEMANTIC_VIEW(
    finance_db.snow_data.finance_SEMANTIC_VIEW
    DIMENSIONS ACCOUNTS.ACCOUNT_NAME
);

-- Example 2: Query semantic view from a consumed data product (commented out)
-- This demonstrates how consumers would query the semantic view from their account
/*
SELECT * FROM SEMANTIC_VIEW(
    ORGDATACLOUD$INTERNAL$HR_FACTS.DBRIX_DELTADIRECT_DATA.HR_SEMANTIC_VIEW
    DIMENSIONS DEPARTMENTS.DEPARTMENT_KEY
);
*/

-- ================================================================================
-- END OF SCRIPT
-- ================================================================================
-- For questions or support, contact: amit.gupta@snowflake.com
-- ================================================================================

