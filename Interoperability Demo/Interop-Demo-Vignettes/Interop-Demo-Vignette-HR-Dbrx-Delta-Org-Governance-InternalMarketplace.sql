/* === SETUP DATABRICKS Delta Domain (HR): START ========
--- STEP1 HR Domain -  Databricks setup 

-- Create user for PROGRAMMATIC access from databricks to Snowflake over Lakehouse Query Federation . MFA Enabled user eg John will not work
create user interop_user;
ALTER USER interop_user SET RSA_PUBLIC_KEY='MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqRH9fnXzdkZ8kGaWQ0latV3ForMUvFJAwhW3wcq1sqiX6XxLnjWQn3rjmUBiQKrDBL+GGMCUxk5tw3bDEmN3tHQS9FeYGbZXUuS1KfE27gIn3kcHRXvIeWdMAqfxoWvJxi0hLwo91tzvOxFLucGbxBqG5bOTGdw8P4LpRqcOQp9kA86dAjxtXmvLGGS5dgBUU+NPxq3YC7EjkwConkJj3KHv3WaU6pWn95ebtT6hMRg2xCjfy6fWsCpZfrRabH/JaPcYxG+spIUo5uw1vW7U6vW8TkyfZtdZHqP9OArvC432z/HvqKcT+IONffr0AX962OybDjkqFGRCyd111uzOIwIDAQAB';
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
--- STEP2 HR Domain - Snowflake Delta Direct Setup
-- https://docs.snowflake.com/user-guide/tables-iceberg-configure-external-volume-s3

use role accountadmin;

-- Create external volume pointing to delta tables in S3 bucket
CREATE EXTERNAL VOLUME  IF NOT EXISTS hr_dbrix_deltadirect_vol
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

-- Get SnowflakeUser ARN and update the AWS Role 
DESC EXTERNAL VOLUME hr_dbrix_deltadirect_vol; 

 -- Verify Connectivity
SELECT SYSTEM$VERIFY_EXTERNAL_VOLUME('hr_dbrix_deltadirect_vol');

--create catalog integration with static values for delta direct
CREATE CATALOG INTEGRATION IF NOT EXISTS delta_catalog_integration
  CATALOG_SOURCE = OBJECT_STORE
  TABLE_FORMAT = DELTA
  ENABLED = TRUE;

-- grant privileges to HR domain role to use external volume and integration
grant usage on EXTERNAL VOLUME hr_dbrix_deltadirect_vol to role hr_domain_role;
grant usage on INTEGRATION delta_catalog_integration to role hr_domain_role;

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

/*
-- Org users and Org groups created in Org account by Org admin 
USE ROLE GLOBALORGADMIN;
CREATE ORGANIZATION USER pii_access_org_user
EMAIL = 'amit.gupta@snowflake.com'
LOGIN_NAME = 'AMGUPTA_PII_ACCESS_USER';

CREATE ORGANIZATION USER GROUP pii_access_org_group;
ALTER ORGANIZATION USER GROUP pii_access_org_group ADD ORGANIZATION USERS pii_access_org_user;
ALTER ORGANIZATION USER GROUP pii_access_org_group SET VISIBILITY = ALL;

*/

-- Hydrate Org Users and groups in local account
USE ROLE ACCOUNTADMIN;
SHOW ORGANIZATION USER GROUPS;
SHOW ORGANIZATION USERS IN ORGANIZATION USER GROUP PII_ACCESS_ORG_GROUP;
-- Hydrates local account with Org user group and create local role with the same name. Also creates 
ALTER ACCOUNT ADD ORGANIZATION USER GROUP PII_ACCESS_ORG_GROUP;

SHOW ORGANIZATION USER GROUPS; -- Check if is_imported column is true
SHOW ORGANIZATION USERS IN ORGANIZATION USER GROUP PII_ACCESS_ORG_GROUP; -- Check if is_imported column is true

SHOW USERS;
SHOW ROLES;

-- Grant Org user to the existing HR domain role. Allow HR role to create projection policies
use role accountadmin;
grant role marketing_domain_role to user PII_ACCESS_ORG_USER;
GRANT CREATE PROJECTION POLICY ON SCHEMA hr_db.dbrix_deltadirect_data TO ROLE hr_domain_role;
GRANT APPLY PROJECTION POLICY ON ACCOUNT TO ROLE hr_domain_role;

use role hr_domain_role;
USE SCHEMA hr_db.dbrix_deltadirect_data;

-- Create Projection policy and apply to Delta Table

---- ALTER ICEBERG TABLE HR_DB.DBRIX_DELTADIRECT_DATA.HR_EMPLOYEE_FACT MODIFY COLUMN salary UNSET PROJECTION POLICY;
---- drop projection policy project_analyst_only;

/* == Old Code
DROP  PROJECTION POLICY hr_db.dbrix_deltadirect_data.project_hr_only;
use role hr_domain_role;
USE SCHEMA hr_db.dbrix_deltadirect_data;
CREATE  PROJECTION POLICY IF NOT EXISTS project_hr_only AS ()
  RETURNS PROJECTION_CONSTRAINT ->
    CASE
      WHEN CURRENT_ORGANIZATION_USER() = 'PII_DENIED_ORG_USER'
        THEN PROJECTION_CONSTRAINT(ALLOW => false, ENFORCEMENT => 'FAIL')
    WHEN CURRENT_ORGANIZATION_USER() = 'PII_ACCESS_ORG_USER' or CURRENT_ROLE() = 'HR_DOMAIN_ROLE'
        THEN PROJECTION_CONSTRAINT(ALLOW => true)
      ELSE PROJECTION_CONSTRAINT(ALLOW => false, ENFORCEMENT => 'FAIL')
    END;

    */

DROP  PROJECTION POLICY hr_db.dbrix_deltadirect_data.project_hr_only;
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

-- Showcase workings of projection constraints
use role hr_domain_role;
use database hr_db;
-- project salary. shows salary
select salary, * from DBRIX_DELTADIRECT_DATA.HR_EMPLOYEE_FACT;
-- show count of employees with salaray > 70k. Returns correct results
select count(distinct employee_key) from DBRIX_DELTADIRECT_DATA.HR_EMPLOYEE_FACT where salary > 70000;

use role accountadmin;
-- project salary. shows nulls
select salary, * from HR_DB.DBRIX_DELTADIRECT_DATA.HR_EMPLOYEE_FACT;
-- show count of employees with salaray > 70k. Returns results same as HR_domain
select count(distinct employee_key) from HR_DB.DBRIX_DELTADIRECT_DATA.HR_EMPLOYEE_FACT where salary > 70000;

-- Go to Sales Account in different region and showcase the projection constraints working cross region
----- grant role PII_ACCESS_ORG_GROUP to 

-- ## Interop Governance demo: end

-- Create HR Data Product
use role hr_domain_role;

create or replace share  hr_data_share;
grant usage on database hr_db to share hr_data_share;
grant usage on schema hr_db.dbrix_deltadirect_data to share hr_data_share;
grant select on all iceberg tables in schema hr_db.dbrix_deltadirect_data to share hr_data_share;


describe share hr_data_share;

alter listing hr_data_product unpublish;
drop listing hr_data_product;
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

-- Show Databricks Delta data has now been made available to 
---- Sales Domain Role in another region - AWS US West
---- Finance Domain Role in another cloud - Azure East US



