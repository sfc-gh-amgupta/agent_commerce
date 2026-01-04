-- ## Interop Iceberg demo: Starts

-- marketing domain Iceberg setup
-- https://docs.snowflake.com/user-guide/tables-iceberg-configure-external-volume-s3

use role accountadmin;
CREATE OR REPLACE EXTERNAL VOLUME marketing_iceberg_vol
   STORAGE_LOCATIONS =
      (
         (
            NAME = 'interop-demo-iceberg-location'
            STORAGE_PROVIDER = 'S3'
            STORAGE_BASE_URL = 's3://amgupta-interop-demo-iceberg/'
            STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::484577546576:role/amgupta_snow_iceberg_access'
            STORAGE_AWS_EXTERNAL_ID = 'iceberg_table_external_id'
         )
      )
      ALLOW_WRITES = TRUE;

      -- Get SnowflakeUser ARN and update the AWS Role 
DESC EXTERNAL VOLUME marketing_iceberg_vol;

 -- Verify Connectivity
SELECT SYSTEM$VERIFY_EXTERNAL_VOLUME('marketing_iceberg_vol');


--setup Marketing domain for Iceberg Format. 
    --Role, WH, database to hold reference to delta table, grant PRIVILEGES
    --allow creation, autofulfillment of data products
    --allow requesting & getting data products
use role accountadmin;
create or replace database marketing_db;
create role marketing_domain_role;
create warehouse marketing_wh;
grant ownership on warehouse marketing_wh to role marketing_domain_role;
grant ownership on database marketing_db to role marketing_domain_role;
grant usage on EXTERNAL VOLUME marketing_iceberg_vol to role marketing_domain_role;

-- To enable autofulfillment from this account, if not already enabled
--use role orgadmin;
--SELECT SYSTEM$ENABLE_GLOBAL_DATA_SHARING_FOR_ACCOUNT('AMGUPTA_SNOW_AWS_USEAST');
grant manage listing auto fulfillment on account to role marketing_domain_role;
grant create share on account to role marketing_domain_role;
grant create organization listing on account to role marketing_domain_role;
-- Get listings 
use role accountadmin;
grant import share on account to role  marketing_domain_role;
grant create database on  account to role  marketing_domain_role;
grant role marketing_domain_role to user john;

-- Config Marketing DB to use Iceberg as format. To connect to external Iceberg catalog; create catalog integration
ALTER database marketing_db SET CATALOG = 'SNOWFLAKE';
ALTER database marketing_db SET EXTERNAL_VOLUME = 'marketing_iceberg_vol';

-- Create Iceberg tables
use role marketing_domain_role;
create schema marketing_db.iceberg_data;
create or replace iceberg table marketing_db.iceberg_data.sf_accounts as select * from sf_ai_demo.demo_schema.sf_accounts;
create or replace iceberg table marketing_db.iceberg_data.MARKETING_CAMPAIGN_FACT as select * from sf_ai_demo.demo_schema.MARKETING_CAMPAIGN_FACT;
create or replace iceberg table marketing_db.iceberg_data.CAMPAIGN_DIM as select * from sf_ai_demo.demo_schema.CAMPAIGN_DIM;
create or replace iceberg table marketing_db.iceberg_data.CHANNEL_DIM as select * from sf_ai_demo.demo_schema.CHANNEL_DIM;
create or replace iceberg table marketing_db.iceberg_data.SF_CONTACTS as select * from sf_ai_demo.demo_schema.SF_CONTACTS;
create or replace iceberg table marketing_db.iceberg_data.SF_OPPORTUNITIES as select * from sf_ai_demo.demo_schema.SF_OPPORTUNITIES;
create or replace iceberg table marketing_db.iceberg_data.PRODUCT_DIM as select * from sf_ai_demo.demo_schema.PRODUCT_DIM;
create or replace iceberg table marketing_db.iceberg_data.REGION_DIM as select * from sf_ai_demo.demo_schema.REGION_DIM;

-- Create Marketing Data Product
use role marketing_domain_role;

create or replace share marketing_data_share;
grant usage on database marketing_db to share marketing_data_share;
grant usage on schema marketing_db.iceberg_data to share marketing_data_share;
grant select on all iceberg tables in schema marketing_db.iceberg_data to share marketing_data_share;


describe share marketing_data_share;

alter listing marketing_data_product unpublish;
drop listing marketing_data_product;

create organization listing marketing_data_product
share marketing_data_share as
$$
title: "[Interop Apache Iceberg X-Region] Marketing Facts"
description: "This data listing provides a comprehensive overview of **marketing campaigns** within our enterprise. It's a key resource for the marketing team, analysts, and business leaders to evaluate campaign effectiveness, optimize spending, and understand customer engagement. The dataset includes information on various marketing channels, campaign costs, and key performance metrics\n\n**Data Contract SLO**\n\n- **Frequency:** Updated every minute for realtime marketing events\n- **Source:** Data is curated from our various marketing platforms (e.g., Google Ads, Meta Ads Manager, Mailchimp)\n- **Access:** By Request. Access is restricted to authorized personnel to be determined by owner\n- **PII**"
data_preview:
  has_pii: true
data_dictionary:
 featured:
    database: 'MARKETING_DB'
    objects:
      - schema: '"ICEBERG_DATA"'
        domain: 'ICEBERG TABLE'
        name: '"CAMPAIGN_DIM"'
      - schema: '"ICEBERG_DATA"'
        domain: 'ICEBERG TABLE'
        name: '"MARKETING_CAMPAIGN_FACT"'
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

