/*
================================================================================
SHARING DELTA LAKE FORMAT USING SNOWFLAKE DATA SHARING
================================================================================

Author: Amit Gupta
Purpose: Demonstrates how to share Delta Lake tables from Databricks using 
         Snowflake's Delta Direct feature and Data Sharing / Listing capabilities

Overview:
This script sets up the complete workflow for sharing Delta Lake format data:
1. Creates external volume pointing to Delta tables in S3
2. Configures catalog integration for Delta format
3. Registers Delta tables as Iceberg tables in Snowflake
4. Creates and publishes a data product for cross-account sharing

Prerequisites:
- AWS S3 bucket containing Delta Lake tables from Databricks
- Proper AWS IAM roles configured for Snowflake access
- Snowflake accounts with appropriate roles (hr_domain_role, etc.)
================================================================================
*/

-- ============================================================================
-- STEP 1: INITIAL SETUP - Use Account Admin Role
-- ============================================================================

USE ROLE accountadmin;

-- ============================================================================
-- STEP 2: CREATE EXTERNAL VOLUME FOR DELTA TABLES
-- ============================================================================

/*
External Volume Configuration:
- Points to S3 bucket containing Delta Lake tables from Databricks
- Enables Snowflake to read Delta format data directly from object storage
- Requires proper AWS IAM role with S3 access permissions
*/

CREATE EXTERNAL VOLUME IF NOT EXISTS hr_dbrix_deltadirect_vol
   STORAGE_LOCATIONS =
      (
         (
            NAME = 'interop-demo-deltadirect-location'
            STORAGE_PROVIDER = 'S3'
            STORAGE_BASE_URL = 's3://amgupta-interop-demo-dbrix-delta/'
            STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::484577546576:role/amgupta_snow_deltadirect_access'
            STORAGE_AWS_EXTERNAL_ID = 'deltadirect_table_external_id'
         )
      )
      ALLOW_WRITES = TRUE;

-- ============================================================================
-- STEP 3: VERIFY EXTERNAL VOLUME CONFIGURATION
-- ============================================================================

/*
Important: Copy the SNOWFLAKE_USER_ARN from the output below and add it to 
your AWS IAM role's trust policy to complete the authentication setup
*/

-- Get Snowflake User ARN for AWS role configuration
DESC EXTERNAL VOLUME hr_dbrix_deltadirect_vol; 

-- Test connectivity to the external volume
SELECT SYSTEM$VERIFY_EXTERNAL_VOLUME('hr_dbrix_deltadirect_vol');

-- ============================================================================
-- STEP 4: CREATE CATALOG INTEGRATION FOR DELTA FORMAT
-- ============================================================================

/*
Catalog Integration:
- Enables Snowflake to understand Delta Lake table format
- Required for reading Delta table metadata and transaction logs
- Uses OBJECT_STORE as the catalog source for direct S3 access
*/

CREATE CATALOG INTEGRATION IF NOT EXISTS delta_catalog_integration
  CATALOG_SOURCE = OBJECT_STORE
  TABLE_FORMAT = DELTA
  ENABLED = TRUE;

-- ============================================================================
-- STEP 5: GRANT PERMISSIONS TO DOMAIN ROLE
-- ============================================================================

/*
Security Setup:
- Grants HR domain role access to external volume and catalog integration
- Follows principle of least privilege by limiting access to specific roles
*/

GRANT USAGE ON EXTERNAL VOLUME hr_dbrix_deltadirect_vol TO ROLE hr_domain_role;
GRANT USAGE ON INTEGRATION delta_catalog_integration TO ROLE hr_domain_role;

-- ============================================================================
-- STEP 6: REGISTER DELTA TABLES AS ICEBERG TABLES
-- ============================================================================

/*
Delta Direct Table Registration:
- Registers Unity Catalog or Hive Metastore managed Delta tables
- Creates Iceberg table in Snowflake that points to Delta data in S3
- AUTO_REFRESH ensures table metadata stays synchronized with source
*/

USE ROLE hr_domain_role;
USE SCHEMA hr_db.dbrix_deltadirect_data;

-- Clean up existing table if needed
-- DROP TABLE job_dim;

-- Register Delta table as Iceberg table in Snowflake
CREATE ICEBERG TABLE IF NOT EXISTS job_dim
  CATALOG = delta_catalog_integration
  EXTERNAL_VOLUME = hr_dbrix_deltadirect_vol
  BASE_LOCATION = 'delta/__unitystorage/catalogs/82522b28-33da-43f2-8e44-e415d76a8368/tables/1443db94-b898-46f8-af63-58c117c632a2/'
  AUTO_REFRESH = TRUE;

-- ============================================================================
-- STEP 7: CREATE DATA SHARE FOR HR DATA PRODUCT
-- ============================================================================

/*
Data Sharing Setup:
- Creates a secure share containing HR data from Delta tables
- Enables cross-account data sharing without data movement
- Maintains data governance and access controls
*/

USE ROLE hr_domain_role;

-- Create the data share
CREATE OR REPLACE SHARE hr_data_share;

-- Grant necessary permissions to the share
GRANT USAGE ON DATABASE hr_db TO SHARE hr_data_share;
GRANT USAGE ON SCHEMA hr_db.dbrix_deltadirect_data TO SHARE hr_data_share;
GRANT SELECT ON ALL ICEBERG TABLES IN SCHEMA hr_db.dbrix_deltadirect_data TO SHARE hr_data_share;

-- Verify share configuration
DESCRIBE SHARE hr_data_share;

-- ============================================================================
-- STEP 8: CREATE AND PUBLISH DATA PRODUCT LISTING
-- ============================================================================

/*
Data Product Publication:
- Creates a comprehensive data product listing in Snowflake Marketplace
- Includes metadata, documentation, and access controls
- Enables discovery and consumption by authorized accounts
- Supports automated refresh and approval workflows
*/

CREATE ORGANIZATION LISTING hr_data_product
SHARE hr_data_share AS
$$
title: "[Interop Databricks Delta X-Region] HR Facts Live Demo"

description: "This data listing provides a comprehensive overview of **people lifecycle** within our enterprise. It's a critical resource for HR professionals, department managers, and leadership to analyze workforce trends, optimize talent management, and support strategic planning. The dataset includes information on employee demographics, tenure, performance, and compensation.\n\n**Data Contract SLO**\n\n- **Frequency:** Updated every day\n- **Source:** Data is curated from Human Resources Information System (HRIS)\n- **Access:** By Request. Access is restricted to authorized personnel to be determined by owner\n- **PII:** Contains personally identifiable information - handle with care"

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

-- ============================================================================
-- COMPLETION
-- ============================================================================

/*
Next Steps:
1. Verify the data product appears in Snowflake Marketplace
2. Test data access from consumer accounts
3. Monitor refresh schedules and data quality
4. Update documentation and metadata as needed

Troubleshooting:
- If external volume verification fails, check AWS IAM role trust policy
- If table registration fails, verify Delta table paths in S3
- If sharing fails, ensure proper role permissions are granted

For more information:
https://docs.snowflake.com/user-guide/tables-iceberg-configure-external-volume-s3
*/

