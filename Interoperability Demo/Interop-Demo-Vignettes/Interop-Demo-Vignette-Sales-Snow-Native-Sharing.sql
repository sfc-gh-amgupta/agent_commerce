--setup sales domain for Snowflake Native Format. 
    --Role, WH, database to hold reference to delta table, grant PRIVILEGES
    --allow creation, autofulfillment of data products
use role accountadmin;
create or replace database sales_db;
create role sales_domain_role;
create warehouse sales_wh;
grant ownership on warehouse sales_wh to role sales_domain_role;
grant ownership on database sales_db to role sales_domain_role;

-- To enable autofulfillment from this account, if not already enabled
--use role orgadmin;
--SELECT SYSTEM$ENABLE_GLOBAL_DATA_SHARING_FOR_ACCOUNT('AMGUPTA_SNOW_AWSUSWEST1');
grant manage listing auto fulfillment on account to role sales_domain_role;
grant create share on account to role sales_domain_role;
grant create organization listing on account to role sales_domain_role;
grant import share on account to role sales_domain_role;
grant create database on  account to role sales_domain_role;
grant role sales_domain_role to user john;

-- Create Snowflake tables from Interop Share
-- Interopdemosetup org listing is a listing created with Nick Ackinlair's Snowflake Intelligence Demo
/*
use role sales_domain_role;
create or replace schema sales_db.snow_data;
create or replace table sales_db.snow_data.CUSTOMER_DIM as select * from ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.CUSTOMER_DIM;
create or replace table sales_db.snow_data.PRODUCT_DIM as select * from ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.PRODUCT_DIM;
create or replace table sales_db.snow_data.PRODUCT_CATEGORY_DIM as select * from ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.PRODUCT_CATEGORY_DIM;
create or replace table sales_db.snow_data.REGION_DIM as select * from ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.REGION_DIM;
create or replace table sales_db.snow_data.SALES_FACT as select * from ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.SALES_FACT;
create or replace table sales_db.snow_data.SALES_REP_DIM as select * from ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.SALES_REP_DIM;
create or replace table sales_db.snow_data.VENDOR_DIM as select * from ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.VENDOR_DIM;
*/


-- Create Sales Data Product
use role sales_domain_role;

create or replace share sales_data_share;
grant usage on database sales_db to share sales_data_share;
grant usage on schema sales_db.snow_data to share sales_data_share;
grant select on all tables in schema sales_db.snow_data to share sales_data_share;
grant select on all semantic views in schema sales_db.snow_data to share sales_data_share;

alter listing sales_data_product unpublish;
drop listing sales_data_product;
create organization listing sales_data_product
share sales_data_share as
$$
title: "[Interop Snowflake Native] Sales Facts"
description: "This data listing provides a comprehensive overview of **sales transactions** within our enterprise. It's an essential resource for analyzing performance, identifying trends, and supporting strategic business decisions. The dataset includes information on all completed sales, from product details to customer demographics.\n\n**Data Contract SLO**\n\n- **Frequency:** Updated every hour to ensure a near real-time view of sales activities.\n- **Source:** Data is curated from point-of-sale (POS) and e-commerce systems\n- **Access:** By Request. Access is restricted to authorized personnel to be determined by owner\n- **No PII**"
data_preview:
  has_pii: false
data_dictionary:
 featured:
    database: 'SALES_DB'
    objects:
      - schema: '"SNOW_DATA"'
        domain: 'TABLE'
        name: '"SALES_REP_DIM"'
      - schema: '"SNOW_DATA"'
        domain: 'TABLE'
        name: '"SALES_FACT"'
resources:
  documentation: https://www.example.com/documentation/
  media: https://www.youtube.com/watch?v=MEFlT3dc3uc
organization_profile: 'INTERNAL'
organization_targets:
  discovery:
    - all_internal_accounts: true
  access: []
request_approval_type: 'REQUEST_AND_APPROVE_IN_SNOWFLAKE'
support_contact: "sales_domain_dl@snowflake.com"
approver_contact: "amit.gupta@snowflake.com"
locations:
  access_regions:
  - name: "ALL"
auto_fulfillment:
  refresh_type: 'SUB_DATABASE'
  refresh_schedule: '1440 MINUTE'
  refresh_schedule_override: true
$$ PUBLISH=TRUE;

alter listing sales_data_product publish;

