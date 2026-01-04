--setup finance domain for Iceberg Format. 
    --Role, WH, database to hold reference to delta table, grant PRIVILEGES
    --allow creation, autofulfillment of data products
use role accountadmin;
create or replace database finance_db;
create role finance_domain_role;
create warehouse finance_wh;
grant ownership on warehouse finance_wh to role finance_domain_role;
grant ownership on database finance_db to role finance_domain_role;

-- To enable autofulfillment from this account, if not already enabled
--use role orgadmin;
--SELECT SYSTEM$ENABLE_GLOBAL_DATA_SHARING_FOR_ACCOUNT('AMGUPTA_SNOW_AZUREUSEAST');
grant manage listing auto fulfillment on account to role finance_domain_role;
grant create share on account to role finance_domain_role;
grant create organization listing on account to role finance_domain_role;
use role accountadmin;
grant import share on account to role finance_domain_role;
grant create database on  account to role finance_domain_role;
grant role hr_domain_role to role accountadmin;
grant role finance_domain_role to user john;

-- Create Snowflake tables from Interop Share
use role finance_domain_role;
create or replace schema finance_db.snow_data;
create or replace table finance_db.snow_data.FINANCE_TRANSACTIONS as select * from ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.FINANCE_TRANSACTIONS;
create or replace table finance_db.snow_data.ACCOUNT_DIM as select * from ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.ACCOUNT_DIM;
create or replace table finance_db.snow_data.DEPARTMENT_DIM as select * from ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.DEPARTMENT_DIM;
create or replace table finance_db.snow_data.VENDOR_DIM as select * from ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.VENDOR_DIM;
create or replace table finance_db.snow_data.PRODUCT_DIM as select * from ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.PRODUCT_DIM;
create or replace table finance_db.snow_data.CUSTOMER_DIM as select * from ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.CUSTOMER_DIM;


-- Create finance Data Product
use role finance_domain_role;

create or replace share finance_data_share;
grant usage on database finance_db to share finance_data_share;
grant usage on schema finance_db.snow_data to share finance_data_share;
grant select on all tables in schema finance_db.snow_data to share finance_data_share;


describe share finance_data_share;

alter listing finance_data_product unpublish;
drop listing finance_data_product;

create organization listing finance_data_product
share finance_data_share as
$$
title: "[Interop Snowflake Native X-Cloud] Finance Facts"
description: "This data listing provides a comprehensive overview of **financial activity** within our enterprise.  It is the definitive source for tracking, analyzing, and reporting on the company's fiscal health and performance. This dataset is compiled from the General Ledger (GL) and is structured to facilitate the generation of all primary financial statements (Income Statement, Balance Sheet, and Cash Flow).\n\n**Data Contract SLO**\n\n- **Frequency:** Updated every day for finance events\n- **Source:** Data is curated from our Enterprise Resource Planning (ERP) system\n- **Access:** By Request. Access is restricted to authorized personnel to be determined by owner\n- **no PII**"
data_preview:
  has_pii: true
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
resources:
  documentation: https://www.example.com/documentation/finance
  media: https://www.youtube.com/watch?v=MEFlT3dc3uc
organization_profile: 'INTERNAL'
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
request_approval_type: 'REQUEST_AND_APPROVE_IN_SNOWFLAKE'
support_contact: "finance_domain_dl@snowflake.com"
approver_contact: "amit.gupta@snowflake.com"
locations:
  access_regions:
  - name: "ALL"
auto_fulfillment:
  refresh_type: 'SUB_DATABASE'
  refresh_schedule: '1 MINUTE'
  refresh_schedule_override: true
$$ PUBLISH=true;

-- Create Semantic View on Snowflake Tables

-- ========================================================================
  -- finance SEMANTIC VIEW
  -- ========================================================================
use role finance_domain_role;
use schema finance_db.snow_data;

create or replace semantic view FINANCE_SEMANTIC_VIEW
    tables (
        TRANSACTIONS as FINANCE_TRANSACTIONS primary key (TRANSACTION_ID) with synonyms=('finance transactions','financial data') comment='All financial transactions across departments',
        ACCOUNTS as ACCOUNT_DIM primary key (ACCOUNT_KEY) with synonyms=('chart of accounts','account types') comment='Account dimension for financial categorization',
        DEPARTMENTS as DEPARTMENT_DIM primary key (DEPARTMENT_KEY) with synonyms=('business units','departments') comment='Department dimension for cost center analysis',
        VENDORS as VENDOR_DIM primary key (VENDOR_KEY) with synonyms=('suppliers','vendors') comment='Vendor information for spend analysis',
        PRODUCTS as PRODUCT_DIM primary key (PRODUCT_KEY) with synonyms=('products','items') comment='Product dimension for transaction analysis',
        CUSTOMERS as CUSTOMER_DIM primary key (CUSTOMER_KEY) with synonyms=('clients','customers') comment='Customer dimension for revenue analysis'
    )
    relationships (
        TRANSACTIONS_TO_ACCOUNTS as TRANSACTIONS(ACCOUNT_KEY) references ACCOUNTS(ACCOUNT_KEY),
        TRANSACTIONS_TO_DEPARTMENTS as TRANSACTIONS(DEPARTMENT_KEY) references DEPARTMENTS(DEPARTMENT_KEY),
        TRANSACTIONS_TO_VENDORS as TRANSACTIONS(VENDOR_KEY) references VENDORS(VENDOR_KEY),
        TRANSACTIONS_TO_PRODUCTS as TRANSACTIONS(PRODUCT_KEY) references PRODUCTS(PRODUCT_KEY),
        TRANSACTIONS_TO_CUSTOMERS as TRANSACTIONS(CUSTOMER_KEY) references CUSTOMERS(CUSTOMER_KEY)
    )
    facts (
        TRANSACTIONS.TRANSACTION_AMOUNT as amount comment='Transaction amount in dollars',
        TRANSACTIONS.TRANSACTION_RECORD as 1 comment='Count of transactions'
    )
    dimensions (
        TRANSACTIONS.TRANSACTION_DATE as date with synonyms=('date','transaction date') comment='Date of the financial transaction',
        TRANSACTIONS.TRANSACTION_MONTH as MONTH(date) comment='Month of the transaction',
        TRANSACTIONS.TRANSACTION_YEAR as YEAR(date) comment='Year of the transaction',
        ACCOUNTS.ACCOUNT_NAME as account_name with synonyms=('account','account type') comment='Name of the account',
        ACCOUNTS.ACCOUNT_TYPE as account_type with synonyms=('type','category') comment='Type of account (Income/Expense)',
        DEPARTMENTS.DEPARTMENT_NAME as department_name with synonyms=('department','business unit') comment='Name of the department',
        VENDORS.VENDOR_NAME as vendor_name with synonyms=('vendor','supplier') comment='Name of the vendor',
        PRODUCTS.PRODUCT_NAME as product_name with synonyms=('product','item') comment='Name of the product',
        CUSTOMERS.CUSTOMER_NAME as customer_name with synonyms=('customer','client') comment='Name of the customer'
    )
    metrics (
        TRANSACTIONS.AVERAGE_AMOUNT as AVG(transactions.amount) comment='Average transaction amount',
        TRANSACTIONS.TOTAL_AMOUNT as SUM(transactions.amount) comment='Total transaction amount',
        TRANSACTIONS.TOTAL_TRANSACTIONS as COUNT(transactions.transaction_record) comment='Total number of transactions'
    )
    comment='Semantic view for financial analysis and reporting';


-- test semantic view on Snowflake
use schema finance_db.snow_data;
  -- Show all semantic views
  SHOW SEMANTIC VIEWS;
  -- Show dimensions for each semantic view
  SHOW SEMANTIC DIMENSIONS;
  -- Show metrics for each semantic view
  SHOW SEMANTIC METRICS; 
  
  -- Query Semantic View

  SELECT * FROM SEMANTIC_VIEW(
    finance_db.snow_data.finance_SEMANTIC_VIEW
    DIMENSIONS ACCOUNTS.ACCOUNT_NAME
  );

    /*-- Query semantic view in data product
     SELECT * FROM SEMANTIC_VIEW(
       ORGDATACLOUD$INTERNAL$HR_FACTS.DBRIX_DELTADIRECT_DATA.HR_SEMANTIC_VIEW
        DIMENSIONS DEPARTMENTS.DEPARTMENT_KEY
      );
      */
