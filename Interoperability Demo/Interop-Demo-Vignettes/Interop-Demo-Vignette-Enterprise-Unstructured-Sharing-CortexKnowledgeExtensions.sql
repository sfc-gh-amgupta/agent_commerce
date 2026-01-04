-- ## Interop Unstructured demo: starts
-- Cortex Knowledge Extensions to vectorize unstructured documents and share x-region, x-cloud

-- Create storage integration pointing to unstructured in S3 bucket
--https://docs.snowflake.com/en/user-guide/data-load-s3-config-storage-integration
use role accountadmin;
CREATE OR REPLACE STORAGE INTEGRATION enterprise_unstructured_storage
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::484577546576:role/amgupta_snow_unstructured_access'
  STORAGE_ALLOWED_LOCATIONS = ('*');

--Retrieve snowflake IAM user and external ID
  DESC INTEGRATION enterprise_unstructured_storage;

-- Create Enterprise Domain
use role accountadmin;
create or replace database enterprise_db;
create or replace schema enterprise_db.S3_UNSTRUCTURED_DATA;
create role enterprise_domain_role;

create or replace warehouse enterprise_wh;
grant ownership on warehouse enterprise_wh to role enterprise_domain_role;
grant ownership on database enterprise_db to role enterprise_domain_role;
grant ownership on schema enterprise_db.S3_UNSTRUCTURED_DATA to role enterprise_domain_role;
grant create stage ON schema enterprise_db.S3_UNSTRUCTURED_DATA TO role enterprise_domain_role;
grant usage on INTEGRATION enterprise_unstructured_storage to role enterprise_domain_role;
-- To enable autofulfillment from this account, if not already enabled
--use role orgadmin;
--SELECT SYSTEM$ENABLE_GLOBAL_DATA_SHARING_FOR_ACCOUNT('AMGUPTA_SNOW_AWS_USEAST');
grant manage listing auto fulfillment on account to role enterprise_domain_role;
grant create share on account to role enterprise_domain_role;
grant create organization listing on account to role enterprise_domain_role;
-- Get listings 
use role accountadmin;
grant import share on account to role enterprise_domain_role;
grant create database on  account to role enterprise_domain_role;
grant role enterprise_domain_role to user john;

-- Demo from here
USE SCHEMA enterprise_db.S3_UNSTRUCTURED_DATA;
use role enterprise_domain_role;

CREATE or replace STAGE enterprise_unstructured_stage
  STORAGE_INTEGRATION = enterprise_unstructured_storage
  URL = 's3://amgupta-interop-demo-unstructured/'
  DIRECTORY = (ENABLE = TRUE);

-- test connectivity

select relative_path 
   ,BUILD_STAGE_FILE_URL('@ENTERPRISE_DB.S3_UNSTRUCTURED_DATA.ENTERPRISE_UNSTRUCTURED_STAGE', relative_path) as file_url
    ,TO_File(BUILD_STAGE_FILE_URL('@ENTERPRISE_DB.S3_UNSTRUCTURED_DATA.ENTERPRISE_UNSTRUCTURED_STAGE', relative_path) ) file_object
 from directory(@ENTERPRISE_DB.S3_UNSTRUCTURED_DATA.ENTERPRISE_UNSTRUCTURED_STAGE) 
where relative_path ilike '%.pdf' ;

-- Parse document contents
create table if not exists parsed_content as 
select relative_path 
   ,BUILD_STAGE_FILE_URL('@ENTERPRISE_DB.S3_UNSTRUCTURED_DATA.ENTERPRISE_UNSTRUCTURED_STAGE', relative_path) as file_url
    ,TO_File(BUILD_STAGE_FILE_URL('@ENTERPRISE_DB.S3_UNSTRUCTURED_DATA.ENTERPRISE_UNSTRUCTURED_STAGE', relative_path) ) file_object
    ,AI_PARSE_DOCUMENT( TO_FILE('@ENTERPRISE_DB.S3_UNSTRUCTURED_DATA.ENTERPRISE_UNSTRUCTURED_STAGE',relative_path), {'mode': 'LAYOUT'}):content::string as Content 
 from directory(@ENTERPRISE_DB.S3_UNSTRUCTURED_DATA.ENTERPRISE_UNSTRUCTURED_STAGE) 
where relative_path ilike '%.pdf' ;

use role enterprise_domain_role;

-- Create search service for finance documents
-- This enables semantic search over finance-related documents
use schema enterprise_db.s3_unstructured_data;

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
                REGEXP_SUBSTR(relative_path, '[^/]+$') as title, -- Extract filename as title
                content
            FROM parsed_content
            WHERE relative_path ilike '%finance/%'
        );
    
    -- Create search service for HR documents
    -- This enables semantic search over HR-related documents
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
                REGEXP_SUBSTR(relative_path, '[^/]+$') as title,
                content
            FROM parsed_content
            WHERE relative_path ilike '%hr/%'
        );

    -- Create search service for marketing documents
    -- This enables semantic search over marketing-related documents
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
                REGEXP_SUBSTR(relative_path, '[^/]+$') as title,
                content
            FROM parsed_content
            WHERE relative_path ilike '%marketing/%'
        );

    -- Create search service for sales documents
    -- This enables semantic search over sales-related documents
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
                REGEXP_SUBSTR(relative_path, '[^/]+$') as title,
                content
            FROM parsed_content
            WHERE relative_path ilike '%sales/%'
        );



-- Cortex Knowledge Extensions and include it in data product
create share if not exists enterprise_unstructured_share;
grant usage on database enterprise_db to share enterprise_unstructured_share;
grant usage on schema enterprise_db.s3_unstructured_data to share enterprise_unstructured_share;
grant usage on cortex search service search_finance_docs to share enterprise_unstructured_share;
grant usage on cortex search service search_hr_docs to share enterprise_unstructured_share;
grant usage on cortex search service search_marketing_docs to share enterprise_unstructured_share;
grant usage on cortex search service search_sales_docs to share enterprise_unstructured_share;

--alter listing enterprise_data_product unpublish;
--drop listing enterprise_data_product;

create organization listing if not exists enterprise_data_product
share enterprise_unstructured_share as
$$
title: "[Interop Unstructured CKE X-Region] Enterprise Documents"
description: "This data listing provides access to a consolidated collection of **unstructured documents** from key functional areas across the enterprise: Sales, Finance, Marketing, and HR. This dataset is a rich, though raw, source of qualitative and detailed business information. It's intended for advanced data science, Natural Language Processing (NLP) initiatives, and deep business process analysis.\n\n**Data Contract SLO**\n\n- **Frequency:** Updated every minute for realtime marketing events\n- **Source:** Data is aggregated from various content repositories (e.g., SharePoint, shared drives, email servers, CRM document attachments\n- **Access:** By Request. Access is restricted to authorized personnel to be determined by owner\n- **PII**"
resources:
  documentation: https://www.example.com/documentation/marketing
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
support_contact: "marketing_domain_dl@snowflake.com"
approver_contact: "amit.gupta@snowflake.com"
locations:
  access_regions:
  - name: "ALL"
auto_fulfillment:
  refresh_type: 'SUB_DATABASE'
  refresh_schedule: '1 MINUTE'
  refresh_schedule_override: true
$$ PUBLISH=true;



-- ## Interop Unstructured demo: Ends
