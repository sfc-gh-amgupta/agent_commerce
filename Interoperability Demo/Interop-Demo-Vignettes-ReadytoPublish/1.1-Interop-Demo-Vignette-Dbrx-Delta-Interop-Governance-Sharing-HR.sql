/*
=======================================================================================
HORIZON CATALOG - INTEROPERABILITY (DELTA) + GOVERNANCE + DATA SHARING w/ LISTINGS (XREGION, XCLOUD)
=======================================================================================
Description:  This script demonstrates end-to-end data interoperability between 
 Snowflake and Databricks using Delta Direct integration, including:
  - Setting up programmatic access for Lakehouse Query Federation
  - Creating Delta Direct external volumes and catalog integrations
  - Implementing cross-platform, cross-region governance with projection policies + Org 2.0 user groups
  - Publishing data products through Organizational Listings
  
Author: Amit Gupta
Last Updated: October 15, 2025
Demo: Available at Interoperable Data Mesh Webinar - https://www.snowflake.com/en/webinars/demo/unlocking-ai-with-an-interoperable-data-mesh-2025-10-16/
================================================================================
*/

/* === SETUP DATABRICKS Delta Domain (HR): START ========
--- STEP1 HR Domain -  Databricks setup 

-- Create user for PROGRAMMATIC access from databricks to Snowflake over Lakehouse Query Federation . MFA Enabled user eg John will not work
create user interop_user;
ALTER USER interop_user SET RSA_PUBLIC_KEY='<INSERT PUBLIC KEY HERE>';
grant role sf_intelligence_demo to user interop_user; -- important for lakehouse query federation to work. As Use this role to connect from databricks to run describe
create warehouse interopdemo_setup_wh;


-- Setup Databricks to read sf_ai_demo - Called this - amgupta_interop_snow_catalog
-- Setup Databricks to write local delta in S3. Called this - amgupta_interop_dbrix_local
-- TIP: Lakehouse federation uses describe table which requires role connecting to be the owner of the objects. Else you see error "Your request failed with status FAILED: [BAD_REQUEST] SQL access control error: Insufficient privileges to operate on table 'CAMPAIGN_DIM'."
-- Run below commands in Databricks sql editor to create HR Domain in Databricks

-- DATABRICKS SQL CODE: Start
create or replace table amgupta_interop_dbrix_local.default.department_dim as
select * from amgupta_interop_snow_catalog.demo_schema.department_dim;

create  or replace table amgupta_interop_dbrix_local.default.employee_dim as
select * from amgupta_interop_snow_catalog.demo_schema.employee_dim;

create  or replace  table amgupta_interop_dbrix_local.default.hr_employee_fact as
select * from amgupta_interop_snow_catalog.demo_schema.hr_employee_fact;

create  or replace table amgupta_interop_dbrix_local.default.job_dim as
select * from amgupta_interop_snow_catalog.demo_schema.job_dim;

create  or replace table amgupta_interop_dbrix_local.default.location_dim as
select * from amgupta_interop_snow_catalog.demo_schema.location_dim;
-- DATABRICKS SQL CODE: End

--setup HR domain for databricks delta direct. 
    --Role, WH, database to hold reference to delta table, grant PRIVILEGES
    --allow creation, autofulfillment of data products
use role accountadmin;
create or replace database hr_db;
create role hr_domain_role;
create warehouse hr_wh;
grant ownership on warehouse hr_wh to role hr_domain_role;
grant ownership on database hr_db to role hr_domain_role;

-- To enable autofulfillment from this account, if not already enabled
--use role orgadmin;
--SELECT SYSTEM$ENABLE_GLOBAL_DATA_SHARING_FOR_ACCOUNT('AMGUPTA_SNOW_AWS_USEAST');
use role accountadmin;
grant manage listing auto fulfillment on account to role hr_domain_role;
grant create share on account to role hr_domain_role;
grant create organization listing on account to role hr_domain_role;
grant import share on account to role hr_domain_role;
grant create database on  account to role hr_domain_role;
grant role hr_domain_role to role accountadmin; -- create role hierarchy with accountadmin. needed for governance piece of demo
grant role hr_domain_role to user john;
alter user john set default_secondary_roles=(); -- needed to ensure org listings are not accessible when domain roles are switched

use role hr_domain_role;
create or replace schema hr_db.dbrix_deltadirect_data;
use schema hr_db.dbrix_deltadirect_data;

*/

/* ===================================================================
 * STEP 2: HR DOMAIN - SNOWFLAKE DELTA DIRECT SETUP
 * 
 * This section configures Snowflake Delta Direct integration to access
 * Delta tables stored in S3 managed by Databricks Unity Catalog or Hive Metastore and written by Databricks Compute.
 * 
 * Reference: https://docs.snowflake.com/user-guide/tables-iceberg-configure-external-volume-s3
 * =================================================================== */

-- Switch to account admin role for infrastructure setup
use role accountadmin;

-- Create external volume pointing to delta tables in S3 bucket
-- This volume provides Snowflake access to the S3 location where Databricks stores Delta tables
CREATE EXTERNAL VOLUME IF NOT EXISTS hr_dbrix_deltadirect_vol
   STORAGE_LOCATIONS =
      (
         (
            -- Friendly name for this storage location
            NAME = 'interop-demo-deltadirect-location'
            -- Cloud provider (AWS S3 in this case)
            STORAGE_PROVIDER = 'S3'
            -- Base S3 URL where Delta tables are stored
            STORAGE_BASE_URL = 's3://amgupta-interop-demo-dbrix-delta/'
            -- AWS IAM role ARN that Snowflake will assume to access S3
            STORAGE_AWS_ROLE_ARN = '[YOUR S3 STORAGE ROLE ARN]'
            -- External ID for additional security when assuming the AWS role
            STORAGE_AWS_EXTERNAL_ID = 'deltadirect_table_external_id'
         )
      )
      -- Allow Snowflake to write to this volume (needed for some Delta operations)
      ALLOW_WRITES = TRUE;

-- Get SnowflakeUser ARN and update the AWS Role 
-- This command shows the Snowflake IAM user that needs to be trusted by the AWS role and included in your S3 policy
DESC EXTERNAL VOLUME hr_dbrix_deltadirect_vol; 

-- Verify that Snowflake can successfully connect to the external volume
-- This should return 'VALIDATION SUCCESSFUL' if configuration is correct
SELECT SYSTEM$VERIFY_EXTERNAL_VOLUME('hr_dbrix_deltadirect_vol');

-- Create catalog integration for Delta format tables
-- This integration tells Snowflake how to interpret Delta table metadata
CREATE CATALOG INTEGRATION IF NOT EXISTS delta_catalog_integration
  -- Source is object store (S3) rather than a metastore service
  CATALOG_SOURCE = OBJECT_STORE
  -- Table format is Delta Lake
  TABLE_FORMAT = DELTA
  -- Enable the integration
  ENABLED = TRUE;

-- Grant necessary privileges to HR domain role to use external volume and integration
-- These grants allow the HR domain role to create and manage Delta Direct tables
grant usage on EXTERNAL VOLUME hr_dbrix_deltadirect_vol to role hr_domain_role;
grant usage on INTEGRATION delta_catalog_integration to role hr_domain_role;

/* ===================================================================
 * REGISTER UNITY CATALOG MANAGED DELTA TABLES IN SNOWFLAKE
 * 
 * This section creates Iceberg table references in Snowflake that point
 * to Delta tables managed by Databricks Unity Catalog. Each table
 * registration includes the specific Unity Catalog table UUID path.
 * =================================================================== */

-- Switch to HR domain role for table creation
use role hr_domain_role;
use schema hr_db.dbrix_deltadirect_data;

-- Register Job Dimension table from Unity Catalog
-- The BASE_LOCATION contains the Unity Catalog table UUID path
-- drop table job_dim; -- Uncomment if you need to recreate the table
CREATE ICEBERG TABLE IF NOT EXISTS job_dim
  -- Use the Delta catalog integration created above
  CATALOG = delta_catalog_integration
  -- Use the external volume for S3 access
  EXTERNAL_VOLUME = hr_dbrix_deltadirect_vol
  -- Unity Catalog table path with unique table identifier
  BASE_LOCATION = 'delta/__unitystorage/catalogs/82522b28-33da-43f2-8e44-e415d76a8368/tables/1443db94-b898-46f8-af63-58c117c632a2/'
  -- Enable automatic refresh when underlying Delta table changes
  AUTO_REFRESH = TRUE;

-- Register Department Dimension table from Unity Catalog
--drop table department_dim; -- Uncomment if you need to recreate the table
CREATE ICEBERG TABLE IF NOT EXISTS department_dim
  CATALOG = delta_catalog_integration
  EXTERNAL_VOLUME = hr_dbrix_deltadirect_vol
  BASE_LOCATION = 'delta/__unitystorage/catalogs/82522b28-33da-43f2-8e44-e415d76a8368/tables/b8101a29-412e-4d5c-b7d4-2aa14a98fc33/'
  AUTO_REFRESH = TRUE;

-- Register Employee Dimension table from Unity Catalog
-- drop table employee_dim; -- Uncomment if you need to recreate the table
CREATE ICEBERG TABLE IF NOT EXISTS employee_dim
  CATALOG = delta_catalog_integration
  EXTERNAL_VOLUME = hr_dbrix_deltadirect_vol
  BASE_LOCATION = 'delta/__unitystorage/catalogs/82522b28-33da-43f2-8e44-e415d76a8368/tables/17bd189a-55f5-49cd-ab41-5a204e0efb2f/'
  AUTO_REFRESH = TRUE;

-- Register HR Employee Fact table from Unity Catalog
-- This is the main fact table containing sensitive salary information
--drop table hr_employee_fact; -- Uncomment if you need to recreate the table
CREATE ICEBERG TABLE IF NOT EXISTS hr_employee_fact
  CATALOG = delta_catalog_integration
  EXTERNAL_VOLUME = hr_dbrix_deltadirect_vol
  BASE_LOCATION = 'delta/__unitystorage/catalogs/82522b28-33da-43f2-8e44-e415d76a8368/tables/bfe04fbd-d8f3-4219-a60e-b028ae02297e/'
  AUTO_REFRESH = TRUE;

-- Register Location Dimension table from Unity Catalog
--drop table location_dim; -- Uncomment if you need to recreate the table
CREATE ICEBERG TABLE IF NOT EXISTS location_dim
  CATALOG = delta_catalog_integration
  EXTERNAL_VOLUME = hr_dbrix_deltadirect_vol
  BASE_LOCATION = 'delta/__unitystorage/catalogs/82522b28-33da-43f2-8e44-e415d76a8368/tables/dd23c6bf-4d89-42c9-9c40-6dfcfc36f994/'
  AUTO_REFRESH = TRUE;

/* ===================================================================
 * INTEROPERABILITY GOVERNANCE DEMO
 * 
 * This section demonstrates cross-platform governance using Snowflake's
 * Organization Users and Groups with Projection Policies to control
 * access to sensitive data (like salary information) across different
 * platforms and regions.
 * 
 * Reference: https://docs.snowflake.com/en/user-guide/organization-users#extended-example
 * =================================================================== */

/*
-- ORG ADMIN SETUP (Run these commands in Organization account)
-- These commands would be run by the Organization Admin to create
-- organization-level users and groups that can be used across accounts

USE ROLE GLOBALORGADMIN;

-- Create organization user with PII access privileges
CREATE ORGANIZATION USER pii_access_org_user
EMAIL = 'amit.gupta@snowflake.com'
LOGIN_NAME = 'AMGUPTA_PII_ACCESS_USER';

-- Create organization group for users who can access PII data
CREATE ORGANIZATION USER GROUP pii_access_org_group;

-- Add the PII access user to the PII access group
ALTER ORGANIZATION USER GROUP pii_access_org_group ADD ORGANIZATION USERS pii_access_org_user;

-- Make the group visible to all accounts in the organization
ALTER ORGANIZATION USER GROUP pii_access_org_group SET VISIBILITY = ALL;
*/

-- ACCOUNT-LEVEL SETUP: Hydrate Organization Users and Groups
-- Import the organization-level user group into this local account
USE ROLE ACCOUNTADMIN;

-- Show available organization user groups
SHOW ORGANIZATION USER GROUPS;

-- Show users in the PII access group
SHOW ORGANIZATION USERS IN ORGANIZATION USER GROUP PII_ACCESS_ORG_GROUP;

-- Import the organization user group into this account
-- This creates local representations of the org users and groups
ALTER ACCOUNT ADD ORGANIZATION USER GROUP PII_ACCESS_ORG_GROUP;

-- Verify the import was successful (is_imported should be true)
SHOW ORGANIZATION USER GROUPS;
SHOW ORGANIZATION USERS IN ORGANIZATION USER GROUP PII_ACCESS_ORG_GROUP;

-- Show all users and roles to verify the org user was created locally
SHOW USERS;
SHOW ROLES;

-- ROLE AND PRIVILEGE SETUP
-- Grant the organization user access to the marketing domain role
-- and set up projection policy privileges for the HR domain role
use role accountadmin;
grant role marketing_domain_role to user PII_ACCESS_ORG_USER;

-- Grant HR domain role the ability to create and apply projection policies
GRANT CREATE PROJECTION POLICY ON SCHEMA hr_db.dbrix_deltadirect_data TO ROLE hr_domain_role;
GRANT APPLY PROJECTION POLICY ON ACCOUNT TO ROLE hr_domain_role;

/* ===================================================================
 * PROJECTION POLICY IMPLEMENTATION
 * 
 * Projection policies control which columns can be accessed in query
 * results based on the user's identity or role. This is used to
 * protect sensitive information like salary data.
 * =================================================================== */

use role hr_domain_role;
USE SCHEMA hr_db.dbrix_deltadirect_data;

-- Clean up any existing projection policy
---- ALTER ICEBERG TABLE HR_DB.DBRIX_DELTADIRECT_DATA.HR_EMPLOYEE_FACT MODIFY COLUMN salary UNSET PROJECTION POLICY;
---- drop projection policy project_analyst_only;

/* == Previous Implementation (commented out for reference)
-- This was the old approach using individual organization users
DROP PROJECTION POLICY hr_db.dbrix_deltadirect_data.project_hr_only;
use role hr_domain_role;
USE SCHEMA hr_db.dbrix_deltadirect_data;
CREATE PROJECTION POLICY IF NOT EXISTS project_hr_only AS ()
  RETURNS PROJECTION_CONSTRAINT ->
    CASE
      WHEN CURRENT_ORGANIZATION_USER() = 'PII_DENIED_ORG_USER'
        THEN PROJECTION_CONSTRAINT(ALLOW => false, ENFORCEMENT => 'FAIL')
    WHEN CURRENT_ORGANIZATION_USER() = 'PII_ACCESS_ORG_USER' or CURRENT_ROLE() = 'HR_DOMAIN_ROLE'
        THEN PROJECTION_CONSTRAINT(ALLOW => true)
      ELSE PROJECTION_CONSTRAINT(ALLOW => false, ENFORCEMENT => 'FAIL')
    END;
*/

-- Remove any existing projection policy before creating new one
DROP PROJECTION POLICY hr_db.dbrix_deltadirect_data.project_hr_only;
use role hr_domain_role;
USE SCHEMA hr_db.dbrix_deltadirect_data;

-- Create projection policy that restricts salary column access
-- Only users in the PII_ACCESS_ORG_GROUP or with HR_DOMAIN_ROLE can see salary data
CREATE PROJECTION POLICY IF NOT EXISTS project_hr_only AS ()
 RETURNS PROJECTION_CONSTRAINT ->
    CASE
    -- Allow access if user is in the PII access group OR has HR domain role
    WHEN IS_ORGANIZATION_USER_GROUP_IN_SESSION('PII_ACCESS_ORG_GROUP') or CURRENT_ROLE() = 'HR_DOMAIN_ROLE'
        THEN PROJECTION_CONSTRAINT(ALLOW => true)
    -- Deny access for all other users and fail the query
    ELSE PROJECTION_CONSTRAINT(ALLOW => false, ENFORCEMENT => 'FAIL')
    END;

-- Show all projection policies to verify creation
show projection policies;

-- Apply the projection policy to the salary column in the HR fact table
-- Users without proper access will see NULL values or query failures for this column
--ALTER ICEBERG TABLE HR_DB.DBRIX_DELTADIRECT_DATA.HR_EMPLOYEE_FACT MODIFY COLUMN salary UNSET PROJECTION POLICY;
ALTER ICEBERG TABLE HR_DB.DBRIX_DELTADIRECT_DATA.HR_EMPLOYEE_FACT MODIFY COLUMN salary SET PROJECTION POLICY HR_DB.DBRIX_DELTADIRECT_DATA.project_hr_only;

/* ===================================================================
 * PROJECTION POLICY TESTING
 * 
 * These queries demonstrate how projection policies work with different
 * roles and users. The HR domain role can see salary data, while other
 * roles cannot.
 * =================================================================== */

-- Test with HR domain role (should show salary values)
use role hr_domain_role;
use database hr_db;
-- Project salary column - should display actual salary values
select salary, * from DBRIX_DELTADIRECT_DATA.HR_EMPLOYEE_FACT;
-- Count employees with salary > 70k - should return correct results
select count(distinct employee_key) from DBRIX_DELTADIRECT_DATA.HR_EMPLOYEE_FACT where salary > 70000;

-- Test with account admin role (should show NULLs for salary)
use role accountadmin;
-- Project salary column - should show NULL values due to projection policy
select salary, * from HR_DB.DBRIX_DELTADIRECT_DATA.HR_EMPLOYEE_FACT;
-- Count employees with salary > 70k - should still return same count (policy allows filtering)
select count(distinct employee_key) from HR_DB.DBRIX_DELTADIRECT_DATA.HR_EMPLOYEE_FACT where salary > 70000;

-- Note: You can also test this in Sales Account in different region to showcase 
-- projection constraints working cross-region
----- grant role PII_ACCESS_ORG_GROUP to [user_in_other_region]

-- ## Interop Governance demo: end

/* ===================================================================
 * DATA PRODUCT CREATION AND MARKETPLACE LISTING
 * 
 * This section creates a data share and publishes it as an organization
 * listing in Snowflake Marketplace, making the HR data available to
 * other accounts and regions with proper governance controls.
 * =================================================================== */

-- Create HR Data Product Share
use role hr_domain_role;

-- Create a share containing the HR Delta Direct tables
create or replace share hr_data_share;
-- Grant database and schema usage to the share
grant usage on database hr_db to share hr_data_share;
grant usage on schema hr_db.dbrix_deltadirect_data to share hr_data_share;
-- Grant select privileges on all Iceberg tables to the share
grant select on all iceberg tables in schema hr_db.dbrix_deltadirect_data to share hr_data_share;

-- Verify the share contents
describe share hr_data_share;

-- Clean up any existing listing before creating new one
alter listing hr_data_product unpublish;
drop listing hr_data_product;

-- Create organization listing for the HR data product
-- This makes the data available through Snowflake Marketplace
create organization listing hr_data_product
share hr_data_share as
$$
title: "[Interop Databricks Delta X-Region] HR Facts Live Demo"
description: "This data listing provides a comprehensive overview of **people lifecycle** within our enterprise. It's a critical resource for HR professionals, department managers, and leadership to analyze workforce trends, optimize talent management, and support strategic planning. The dataset includes information on employee demographics, tenure, performance, and compensation.\n\n**Data Contract SLO**\n\n- **Frequency:** Updated every day\n- **Source:** Data is curated from Human Resources Information System (HRIS)\n- **Access:** By Request. Access is restricted to authorized personnel to be determined by owner\n- **PII**"
data_preview:
  has_pii: true
data_dictionary:
 featured:
    database: 'HR_DB'
    objects:
      - schema: '"DBRIX_DELTADIRECT_DATA"'
        domain: 'ICEBERG TABLE'
        name: '"EMPLOYEE_DIM"'
      - schema: '"DBRIX_DELTADIRECT_DATA"'
        domain: 'ICEBERG TABLE'
        name: '"HR_EMPLOYEE_FACT"'
resources:
  documentation: https://www.example.com/documentation/hr
  media: https://www.youtube.com/watch?v=MEFlT3dc3uc
organization_profile: 'INTERNAL'
organization_targets:
  discovery:
    - all_internal_accounts: true
  access:
    - account: 'AMGUPTA_SNOW_AWSUSWEST1'
      roles:
        - 'SALES_DOMAIN_ROLE'
    - account: 'AMGUPTA_SNOW_AZUREUSEAST'
      roles:
        - 'FINANCE_DOMAIN_ROLE'
request_approval_type: 'REQUEST_AND_APPROVE_IN_SNOWFLAKE'
support_contact: "hr_domain_dl@snowflake.com"
approver_contact: "amit.gupta@snowflake.com"
locations:
  access_regions:
  - name: "ALL"
auto_fulfillment:
  refresh_type: 'SUB_DATABASE'
  refresh_schedule: '1 MINUTE'
  refresh_schedule_override: true
$$ PUBLISH=true;

/* ===================================================================
 * DEMO OUTCOME
 * 
 * This demo showcases:
 * 1. Databricks Delta data is now accessible in Snowflake via Delta Direct
 * 2. Cross-platform governance with projection policies and Org 2.0 user groups protecting PII
 * 3. Data product published to multiple regions and cloud providers:
 *    - Sales Domain Role in AWS US West region
 *    - Finance Domain Role in Azure East US region
 * 4. Automatic refresh and real-time data synchronization
 * 5. Organization-level user management across accounts
 * =================================================================== */