
/*
=======================================================================================
BUILD 2025 DEMO (PROVIDER SIDE) - MULTI-FORMAT AI-READY GLOBAL DATA PRODUCTS
=======================================================================================
Description:  This script demonstrates end-to-end global data products, including:
  - Registering Iceberg tables in Horizon with Delta Direct
  - Implementing cross-region governance with projection policies and Org 2.0 user groups
  - Publishing data products through Organizational Listings

Demonstrated by: Vino Duraisamy
Author: Amit Gupta
Last Updated: October 15, 2025
================================================================================
*/


-- Register Unity or Hive Metastore managed Delta Tables in Horizon using Delta Direct
 use role hr_domain_role;
 use schema hr_db.dbrix_deltadirect_data;

-- drop table job_dim;
 CREATE ICEBERG TABLE IF NOT EXISTS job_dim
  CATALOG = delta_catalog_integration
  EXTERNAL_VOLUME = hr_dbrix_deltadirect_vol
  BASE_LOCATION = 'delta/__unitystorage/catalogs/82522b28-33da-43f2-8e44-e415d76a8368/tables/1443db94-b898-46f8-af63-58c117c632a2/'
  AUTO_REFRESH = TRUE;

--drop table department_dim;
CREATE ICEBERG TABLE IF NOT EXISTS  department_dim
  CATALOG = delta_catalog_integration
  EXTERNAL_VOLUME = hr_dbrix_deltadirect_vol
  BASE_LOCATION = 'delta/__unitystorage/catalogs/82522b28-33da-43f2-8e44-e415d76a8368/tables/b8101a29-412e-4d5c-b7d4-2aa14a98fc33/'
  AUTO_REFRESH = TRUE;

-- drop table employee_dim;
  CREATE ICEBERG TABLE IF NOT EXISTS  employee_dim
  CATALOG = delta_catalog_integration
  EXTERNAL_VOLUME = hr_dbrix_deltadirect_vol
  BASE_LOCATION = 'delta/__unitystorage/catalogs/82522b28-33da-43f2-8e44-e415d76a8368/tables/17bd189a-55f5-49cd-ab41-5a204e0efb2f/'
  AUTO_REFRESH = TRUE;

 --drop table hr_employee_fact;
   CREATE ICEBERG TABLE IF NOT EXISTS hr_employee_fact
  CATALOG = delta_catalog_integration
  EXTERNAL_VOLUME = hr_dbrix_deltadirect_vol
  BASE_LOCATION = 'delta/__unitystorage/catalogs/82522b28-33da-43f2-8e44-e415d76a8368/tables/bfe04fbd-d8f3-4219-a60e-b028ae02297e/'
  AUTO_REFRESH = TRUE;

--drop table location_dim;
   CREATE ICEBERG TABLE IF NOT EXISTS location_dim
  CATALOG = delta_catalog_integration
  EXTERNAL_VOLUME = hr_dbrix_deltadirect_vol
  BASE_LOCATION = 'delta/__unitystorage/catalogs/82522b28-33da-43f2-8e44-e415d76a8368/tables/dd23c6bf-4d89-42c9-9c40-6dfcfc36f994/'
  AUTO_REFRESH = TRUE;


-- ## Interop Governance demo: start
-- Leverage Org Users and Org Groups for masking
-- https://docs.snowflake.com/en/user-guide/organization-users#extended-example

-- Create Projection policy and apply to Delta Table


--DROP  PROJECTION POLICY hr_db.dbrix_deltadirect_data.project_hr_only;
use role hr_domain_role;
USE SCHEMA hr_db.dbrix_deltadirect_data;

CREATE  PROJECTION POLICY IF NOT EXISTS project_hr_only AS ()
 RETURNS PROJECTION_CONSTRAINT ->
    CASE
    WHEN IS_ORGANIZATION_USER_GROUP_IN_SESSION('PII_ACCESS_ORG_GROUP') or CURRENT_ROLE() = 'HR_DOMAIN_ROLE'
        THEN PROJECTION_CONSTRAINT(ALLOW => true)
      ELSE PROJECTION_CONSTRAINT(ALLOW => false, ENFORCEMENT => 'FAIL')
    END;

    
show projection policies;
--ALTER ICEBERG TABLE HR_DB.DBRIX_DELTADIRECT_DATA.HR_EMPLOYEE_FACT MODIFY COLUMN salary UNSET PROJECTION POLICY;
ALTER ICEBERG TABLE HR_DB.DBRIX_DELTADIRECT_DATA.HR_EMPLOYEE_FACT MODIFY COLUMN salary SET PROJECTION POLICY HR_DB.DBRIX_DELTADIRECT_DATA.project_hr_only;


-- ## Interop Governance demo: end

-- Create HR Data Product
use role hr_domain_role;

create or replace share  hr_data_share_live;
grant usage on database hr_db to share hr_data_share_live;
grant usage on schema hr_db.dbrix_deltadirect_data to share hr_data_share_live;
grant select on all iceberg tables in schema hr_db.dbrix_deltadirect_data to share hr_data_share_live;

describe share hr_data_share_live;

organization_profile: "MyOrgPROFILE"

alter listing hr_data_product_live unpublish;
drop listing hr_data_product_live;
create organization listing hr_data_product_live
share hr_data_share_live as
$$
title: "[BUILD DEMO Delta X-Region] HR Facts Live Demo"
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

-- Show Databricks Delta data has now been made available to 
---- Sales Domain Role in another region - AWS US West
---- Finance Domain Role in another cloud - Azure East US




-- ============================================================================
-- HR SEMANTIC VIEW ON DATABRICKS DELTA DATA
-- ============================================================================
use role hr_domain_role;
use schema hr_db.dbrix_deltadirect_data;
drop semantic view HR_SEMANTIC_VIEW;
CREATE OR REPLACE SEMANTIC VIEW HR_SEMANTIC_VIEW
    -- Define table aliases and primary keys with business-friendly synonyms
    TABLES (
        DEPARTMENTS AS DEPARTMENT_DIM 
            PRIMARY KEY (DEPARTMENT_KEY) 
            WITH SYNONYMS=('departments','business units') 
            COMMENT='Department dimension for organizational analysis',
            
        EMPLOYEES AS EMPLOYEE_DIM 
            PRIMARY KEY (EMPLOYEE_KEY) 
            WITH SYNONYMS=('employees','staff','workforce') 
            COMMENT='Employee dimension with personal information',
            
        HR_RECORDS AS HR_EMPLOYEE_FACT 
            PRIMARY KEY (HR_FACT_ID) 
            WITH SYNONYMS=('hr data','employee records') 
            COMMENT='HR employee fact data for workforce analysis',
            
        JOBS AS JOB_DIM 
            PRIMARY KEY (JOB_KEY) 
            WITH SYNONYMS=('job titles','positions','roles') 
            COMMENT='Job dimension with titles and levels',
            
        LOCATIONS AS LOCATION_DIM 
            PRIMARY KEY (LOCATION_KEY) 
            WITH SYNONYMS=('locations','offices','sites') 
            COMMENT='Location dimension for geographic analysis'
    )
    
    -- Define relationships between tables for proper joins
    RELATIONSHIPS (
        HR_TO_DEPARTMENTS AS HR_RECORDS(DEPARTMENT_KEY) REFERENCES DEPARTMENTS(DEPARTMENT_KEY),
        HR_TO_EMPLOYEES AS HR_RECORDS(EMPLOYEE_KEY) REFERENCES EMPLOYEES(EMPLOYEE_KEY),
        HR_TO_JOBS AS HR_RECORDS(JOB_KEY) REFERENCES JOBS(JOB_KEY),
        HR_TO_LOCATIONS AS HR_RECORDS(LOCATION_KEY) REFERENCES LOCATIONS(LOCATION_KEY)
    )
    
    -- Define measurable facts for analytics
    FACTS (
        HR_RECORDS.ATTRITION_FLAG AS attrition_flag 
            WITH SYNONYMS=('turnover_indicator','employee_departure_flag','separation_flag','employee_retention_status','churn_status','employee_exit_indicator') 
            COMMENT='Attrition flag. Value is 0 if employee is currently active, 1 if employee quit & left the company. Always filter by 0 to show active employees unless specified otherwise',
            
        HR_RECORDS.EMPLOYEE_RECORD AS 1 
            COMMENT='Count of employee records',
            
        HR_RECORDS.EMPLOYEE_SALARY AS salary 
            COMMENT='Employee salary in dollars'
    )
    
    -- Define dimensional attributes for filtering and grouping
    DIMENSIONS (
        -- Department dimensions
        DEPARTMENTS.DEPARTMENT_KEY AS DEPARTMENT_KEY,
        DEPARTMENTS.DEPARTMENT_NAME AS department_name 
            WITH SYNONYMS=('department','business unit','division') 
            COMMENT='Name of the department',
            
        -- Employee dimensions
        EMPLOYEES.EMPLOYEE_KEY AS EMPLOYEE_KEY,
        EMPLOYEES.EMPLOYEE_NAME AS employee_name 
            WITH SYNONYMS=('employee','staff member','person','sales rep','manager','director','executive') 
            COMMENT='Name of the employee',
        EMPLOYEES.GENDER AS gender 
            WITH SYNONYMS=('gender','sex') 
            COMMENT='Employee gender',
        EMPLOYEES.HIRE_DATE AS hire_date 
            WITH SYNONYMS=('hire date','start date') 
            COMMENT='Date when employee was hired',
            
        -- HR record dimensions
        HR_RECORDS.DEPARTMENT_KEY AS DEPARTMENT_KEY,
        HR_RECORDS.EMPLOYEE_KEY AS EMPLOYEE_KEY,
        HR_RECORDS.HR_FACT_ID AS HR_FACT_ID,
        HR_RECORDS.JOB_KEY AS JOB_KEY,
        HR_RECORDS.LOCATION_KEY AS LOCATION_KEY,
        HR_RECORDS.RECORD_DATE AS date 
            WITH SYNONYMS=('date','record date') 
            COMMENT='Date of the HR record',
        HR_RECORDS.RECORD_MONTH AS MONTH(date) 
            COMMENT='Month of the HR record',
        HR_RECORDS.RECORD_YEAR AS YEAR(date) 
            COMMENT='Year of the HR record',
            
        -- Job dimensions
        JOBS.JOB_KEY AS JOB_KEY,
        JOBS.JOB_LEVEL AS job_level 
            WITH SYNONYMS=('level','grade','seniority') 
            COMMENT='Job level or grade',
        JOBS.JOB_TITLE AS job_title 
            WITH SYNONYMS=('job title','position','role') 
            COMMENT='Employee job title',
            
        -- Location dimensions
        LOCATIONS.LOCATION_KEY AS LOCATION_KEY,
        LOCATIONS.LOCATION_NAME AS location_name 
            WITH SYNONYMS=('location','office','site') 
            COMMENT='Work location'
    )
    
    -- Define pre-calculated metrics for common business questions
    METRICS (
        HR_RECORDS.ATTRITION_COUNT AS SUM(hr_records.attrition_flag) 
            COMMENT='Number of employees who left',
        HR_RECORDS.AVG_SALARY AS AVG(hr_records.employee_salary) 
            COMMENT='Average employee salary',
        HR_RECORDS.TOTAL_EMPLOYEES AS COUNT(hr_records.employee_record) 
            COMMENT='Total number of employees',
        HR_RECORDS.TOTAL_SALARY_COST AS SUM(hr_records.EMPLOYEE_SALARY) 
            COMMENT='Total salary cost'
    )
    
    COMMENT='Semantic view for HR analytics and workforce management'
    
    -- Extended metadata for enhanced AI and BI tool integration
    WITH EXTENSION (
        CA='{"tables":[{"name":"DEPARTMENTS","dimensions":[{"name":"DEPARTMENT_KEY"},{"name":"DEPARTMENT_NAME","sample_values":["Finance","Accounting","Treasury"]}]},{"name":"EMPLOYEES","dimensions":[{"name":"EMPLOYEE_KEY"},{"name":"EMPLOYEE_NAME","sample_values":["Grant Frey","Elizabeth George","Olivia Mcdaniel"]},{"name":"GENDER"},{"name":"HIRE_DATE"}]},{"name":"HR_RECORDS","dimensions":[{"name":"DEPARTMENT_KEY"},{"name":"EMPLOYEE_KEY"},{"name":"HR_FACT_ID"},{"name":"JOB_KEY"},{"name":"LOCATION_KEY"},{"name":"RECORD_DATE"},{"name":"RECORD_MONTH"},{"name":"RECORD_YEAR"}],"facts":[{"name":"ATTRITION_FLAG","sample_values":["0","1"]},{"name":"EMPLOYEE_RECORD"},{"name":"EMPLOYEE_SALARY"}],"metrics":[{"name":"ATTRITION_COUNT"},{"name":"AVG_SALARY"},{"name":"TOTAL_EMPLOYEES"},{"name":"TOTAL_SALARY_COST"}]},{"name":"JOBS","dimensions":[{"name":"JOB_KEY"},{"name":"JOB_LEVEL"},{"name":"JOB_TITLE"}]},{"name":"LOCATIONS","dimensions":[{"name":"LOCATION_KEY"},{"name":"LOCATION_NAME"}]}],"relationships":[{"name":"HR_TO_DEPARTMENTS","relationship_type":"many_to_one"},{"name":"HR_TO_EMPLOYEES","relationship_type":"many_to_one"},{"name":"HR_TO_JOBS","relationship_type":"many_to_one"},{"name":"HR_TO_LOCATIONS","relationship_type":"many_to_one"}],"verified_queries":[{"name":"List of all active employees","question":"List of all active employees","sql":"select\\n  h.employee_key,\\n  e.employee_name,\\nfrom\\n  employees e\\n  left join hr_records h on e.employee_key = h.employee_key\\ngroup by\\n  all\\nhaving\\n  sum(h.attrition_flag) = 0;","use_as_onboarding_question":false,"verified_by":"Nick Akincilar","verified_at":1753846263},{"name":"List of all inactive employees","question":"List of all inactive employees","sql":"SELECT\\n  h.employee_key,\\n  e.employee_name\\nFROM\\n  employees AS e\\n  LEFT JOIN hr_records AS h ON e.employee_key = h.employee_key\\nGROUP BY\\n  ALL\\nHAVING\\n  SUM(h.attrition_flag) > 0","use_as_onboarding_question":false,"verified_by":"Nick Akincilar","verified_at":1753846300}],"custom_instructions":"- Each employee can have multiple hr_employee_fact records. \\n- Only one hr_employee_fact record per employee is valid and that is the one which has the highest date value."}'
    );


-- Make Cortex AI Ready Data Product
grant select on all semantic views in schema hr_db.dbrix_deltadirect_data to share hr_data_share_live;



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



--alter
liing enterpriseenterprise_data_product_live;
--drop lisng enterpriseenterprise_data_product_liveorganization listing if not exists enterprise_data_product
share ent_liveerprise_unstructured_share as
$$
title: "[Interop Unstructured CKE X-Region] Enterpriseuctured Documents"
description: "This data listing provides access to a consolidated collection of **unstructured documents** from key functional areas across the enterprise: Sales, Finance, Marketing, and HR. This dataset is a rich, though raw, source of qualitative and detailed business information. It's intended for advanced data science, Natural Language Processing (NLP) initiatives, and deep business process analysis.\n\n**Data Contract SLO**\n\n- **Frequency:** Updated every minute for realtime marketing events\n- **Source:** Data is aggregated from various content repositories (e.g., SharePoint, shared drives, email servers, CRM document attachments\n- **Access:** By Request. Access is restricted to authorized personnel to be determined by owner\n- **PII**"
resources:
  documentation: https://www.example.com/documentation/marketing
  media: https://www.youtube.com/watch?v=MEFlT3dc3uc
organization_profile: 'HR'
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
