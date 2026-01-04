/* == SETUP Snowflake Intelligence ===
-- Mount Data Products from various domains programmatically

use role sales_domain_role;
create or replace database shared_delta_xregion_hr from listing ORGDATACLOUD$INTERNAL$HR_DATA_PRODUCT;
create or replace database shared_iceberg_xregion_marketing from listing ORGDATACLOUD$INTERNAL$MARKETING_DATA_PRODUCT;
create or replace database shared_delta_xregion_hr from listing ORGDATACLOUD$INTERNAL$HR_DATA_PRODUCT;
create or replace database shared_snow_xcloud_finance from listing ORGDATACLOUD$INTERNAL$FINANCE_DATA_PRODUCT;
create or replace database shared_cke_unstructured_xregion_enterprise from listing ORGDATACLOUD$INTERNAL$ENTERPRISE_DATA_PRODUCT;



--
use role sales_domain_role;

use schema sales_db.snow_data;

  -- NETWORK rule is part of db schema
CREATE OR REPLACE NETWORK RULE Snowflake_intelligence_WebAccessRule
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('0.0.0.0:80', '0.0.0.0:443');

use role accountadmin;
grant role sales_domain_role to role accountadmin;
grant create integration on account to role sales_domain_role ;
-- Removing below grants from Nick's code since there is role hierarcy between sale domain and accountadmin
--use role accountadmin;
--GRANT ALL PRIVILEGES ON DATABASE SALES_DB TO ROLE ACCOUNTADMIN;
--GRANT ALL PRIVILEGES ON SCHEMA SALES_DB.SNOW_DATA TO ROLE ACCOUNTADMIN;
--GRANT USAGE ON NETWORK RULE snowflake_intelligence_webaccessrule TO ROLE accountadmin;


use role sales_domain_role;
USE SCHEMA SALES_DB.SNOW_DATA;
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION Snowflake_intelligence_ExternalAccess_Integration
ALLOWED_NETWORK_RULES = (Snowflake_intelligence_WebAccessRule)
ENABLED = true;

CREATE NOTIFICATION INTEGRATION ai_email_int
  TYPE=EMAIL
  ENABLED=TRUE;

-- Enable Snowflake Intelligence by creating the Config DB & Schema
CREATE DATABASE IF NOT EXISTS snowflake_intelligence;
CREATE SCHEMA IF NOT EXISTS snowflake_intelligence.agents;

GRANT USAGE ON DATABASE snowflake_intelligence TO ROLE sales_domain_role;
GRANT USAGE ON SCHEMA snowflake_intelligence.agents TO ROLE sales_domain_role;
GRANT CREATE AGENT ON SCHEMA snowflake_intelligence.agents TO ROLE sales_domain_role;
--GRANT USAGE ON INTEGRATION Snowflake_intelligence_ExternalAccess_Integration TO ROLE sales_domain_role;
--GRANT USAGE ON INTEGRATION AI_EMAIL_INT TO ROLE sales_domain_role;


use role sales_domain_role;
-- CREATES A SNOWFLAKE INTELLIGENCE AGENT WITH MULTIPLE TOOLS

-- Amit's comment- With CKEs we likely cannot generate presigned url hence, this sp is doing almost nothing
-- Create stored procedure to generate presigned URLs for files in internal stages
CREATE OR REPLACE PROCEDURE Get_File_Presigned_URL_SP(
    RELATIVE_FILE_PATH STRING, 
    EXPIRATION_MINS INTEGER DEFAULT 60
)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Generates a presigned URL for a file in the static @INTERNAL_DATA_STAGE. Input is the relative file path.'
EXECUTE AS CALLER
AS
$$
DECLARE
    presigned_url STRING;
    sql_stmt STRING;
    expiration_seconds INTEGER;
   // stage_name STRING DEFAULT '@SALES_DB.SNOW_DATA.INTERNAL_DATA_STAGE';
BEGIN
    expiration_seconds := EXPIRATION_MINS * 60;

    //sql_stmt := 'SELECT GET_PRESIGNED_URL(' || stage_name || ', ' || '''' || RELATIVE_FILE_PATH || '''' || ', ' || expiration_seconds || ') AS url';
    
    //EXECUTE IMMEDIATE :sql_stmt;
    
    
    //SELECT "URL"
   // INTO :presigned_url
   // FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
    
    RETURN :presigned_url;
END;
$$;

-- Create stored procedure to send emails to verified recipients in Snowflake
use warehouse sales_wh;
CREATE OR REPLACE PROCEDURE send_mail(recipient TEXT, subject TEXT, text TEXT)
RETURNS TEXT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'send_mail'
AS
$$
def send_mail(session, recipient, subject, text):
    session.call(
        'SYSTEM$SEND_EMAIL',
        'ai_email_int',
        recipient,
        subject,
        text,
        'text/html'
    )
    return f'Email was sent to {recipient} with subject: "{subject}".'
$$;


---- Workaround: Needed cos semantic views LAF is not GA. Create semantic views locally on shared data
use role sales_domain_role;
create or replace schema sales_db.shared_data;
use schema sales_db.shared_data;

CREATE OR REPLACE SEMANTIC VIEW HR_SEMANTIC_VIEW
    -- Define table aliases and primary keys with business-friendly synonyms
    TABLES (
        DEPARTMENTS AS SHARED_DELTA_XREGION_HR.DBRIX_DELTADIRECT_DATA.DEPARTMENT_DIM 
            PRIMARY KEY (DEPARTMENT_KEY) 
            WITH SYNONYMS=('departments','business units') 
            COMMENT='Department dimension for organizational analysis',
            
        EMPLOYEES AS SHARED_DELTA_XREGION_HR.DBRIX_DELTADIRECT_DATA.EMPLOYEE_DIM 
            PRIMARY KEY (EMPLOYEE_KEY) 
            WITH SYNONYMS=('employees','staff','workforce') 
            COMMENT='Employee dimension with personal information',
            
        HR_RECORDS AS SHARED_DELTA_XREGION_HR.DBRIX_DELTADIRECT_DATA.HR_EMPLOYEE_FACT 
            PRIMARY KEY (HR_FACT_ID) 
            WITH SYNONYMS=('hr data','employee records') 
            COMMENT='HR employee fact data for workforce analysis',
            
        JOBS AS SHARED_DELTA_XREGION_HR.DBRIX_DELTADIRECT_DATA.JOB_DIM 
            PRIMARY KEY (JOB_KEY) 
            WITH SYNONYMS=('job titles','positions','roles') 
            COMMENT='Job dimension with titles and levels',
            
        LOCATIONS AS SHARED_DELTA_XREGION_HR.DBRIX_DELTADIRECT_DATA.LOCATION_DIM 
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

create or replace semantic view MARKETING_SEMANTIC_VIEW
	tables (
		ACCOUNTS as shared_iceberg_xregion_marketing.iceberg_data.SF_ACCOUNTS primary key (ACCOUNT_ID) with synonyms=('customers','accounts','clients') comment='Customer account information for revenue analysis',
		CAMPAIGNS as shared_iceberg_xregion_marketing.iceberg_data.MARKETING_CAMPAIGN_FACT primary key (CAMPAIGN_FACT_ID) with synonyms=('marketing campaigns','campaign data') comment='Marketing campaign performance data',
		CAMPAIGN_DETAILS as shared_iceberg_xregion_marketing.iceberg_data.CAMPAIGN_DIM primary key (CAMPAIGN_KEY) with synonyms=('campaign info','campaign details') comment='Campaign dimension with objectives and names',
		CHANNELS as shared_iceberg_xregion_marketing.iceberg_data.CHANNEL_DIM primary key (CHANNEL_KEY) with synonyms=('marketing channels','channels') comment='Marketing channel information',
		CONTACTS as shared_iceberg_xregion_marketing.iceberg_data.SF_CONTACTS primary key (CONTACT_ID) with synonyms=('leads','contacts','prospects') comment='Contact records generated from marketing campaigns',
		CONTACTS_FOR_OPPORTUNITIES as shared_iceberg_xregion_marketing.iceberg_data.SF_CONTACTS primary key (CONTACT_ID) with synonyms=('opportunity contacts') comment='Contact records generated from marketing campaigns, specifically for opportunities, not leads',
		OPPORTUNITIES as shared_iceberg_xregion_marketing.iceberg_data.SF_OPPORTUNITIES primary key (OPPORTUNITY_ID) with synonyms=('deals','opportunities','sales pipeline') comment='Sales opportunities and revenue data',
		PRODUCTS as shared_iceberg_xregion_marketing.iceberg_data.PRODUCT_DIM primary key (PRODUCT_KEY) with synonyms=('products','items') comment='Product dimension for campaign-specific analysis',
		REGIONS as shared_iceberg_xregion_marketing.iceberg_data.REGION_DIM primary key (REGION_KEY) with synonyms=('territories','regions','markets') comment='Regional information for campaign analysis'
	)
	relationships (
		CAMPAIGNS_TO_CHANNELS as CAMPAIGNS(CHANNEL_KEY) references CHANNELS(CHANNEL_KEY),
		CAMPAIGNS_TO_DETAILS as CAMPAIGNS(CAMPAIGN_KEY) references CAMPAIGN_DETAILS(CAMPAIGN_KEY),
		CAMPAIGNS_TO_PRODUCTS as CAMPAIGNS(PRODUCT_KEY) references PRODUCTS(PRODUCT_KEY),
		CAMPAIGNS_TO_REGIONS as CAMPAIGNS(REGION_KEY) references REGIONS(REGION_KEY),
		CONTACTS_TO_ACCOUNTS as CONTACTS(ACCOUNT_ID) references ACCOUNTS(ACCOUNT_ID),
		CONTACTS_TO_CAMPAIGNS as CONTACTS(CAMPAIGN_NO) references CAMPAIGNS(CAMPAIGN_FACT_ID),
		CONTACTS_TO_OPPORTUNITIES as CONTACTS_FOR_OPPORTUNITIES(OPPORTUNITY_ID) references OPPORTUNITIES(OPPORTUNITY_ID),
		OPPORTUNITIES_TO_ACCOUNTS as OPPORTUNITIES(ACCOUNT_ID) references ACCOUNTS(ACCOUNT_ID),
		OPPORTUNITIES_TO_CAMPAIGNS as OPPORTUNITIES(CAMPAIGN_ID) references CAMPAIGNS(CAMPAIGN_FACT_ID)
	)
	facts (
		PUBLIC CAMPAIGNS.CAMPAIGN_RECORD as 1 comment='Count of campaign activities',
		PUBLIC CAMPAIGNS.CAMPAIGN_SPEND as spend comment='Marketing spend in dollars',
		PUBLIC CAMPAIGNS.IMPRESSIONS as IMPRESSIONS comment='Number of impressions',
		PUBLIC CAMPAIGNS.LEADS_GENERATED as LEADS_GENERATED comment='Number of leads generated',
		PUBLIC CONTACTS.CONTACT_RECORD as 1 comment='Count of contacts generated',
		PUBLIC OPPORTUNITIES.OPPORTUNITY_RECORD as 1 comment='Count of opportunities created',
		PUBLIC OPPORTUNITIES.REVENUE as AMOUNT comment='Opportunity revenue in dollars'
	)
	dimensions (
		PUBLIC ACCOUNTS.ACCOUNT_ID as ACCOUNT_ID,
		PUBLIC ACCOUNTS.ACCOUNT_NAME as ACCOUNT_NAME with synonyms=('customer name','client name','company') comment='Name of the customer account',
		PUBLIC ACCOUNTS.ACCOUNT_TYPE as ACCOUNT_TYPE with synonyms=('customer type','account category') comment='Type of customer account',
		PUBLIC ACCOUNTS.ANNUAL_REVENUE as ANNUAL_REVENUE with synonyms=('customer revenue','company revenue') comment='Customer annual revenue',
		PUBLIC ACCOUNTS.EMPLOYEES as EMPLOYEES with synonyms=('company size','employee count') comment='Number of employees at customer',
		PUBLIC ACCOUNTS.INDUSTRY as INDUSTRY with synonyms=('industry','sector') comment='Customer industry',
		PUBLIC ACCOUNTS.SALES_CUSTOMER_KEY as CUSTOMER_KEY with synonyms=('Customer No','Customer ID') comment='This is the customer key thank links the Salesforce account to customers table.',
		PUBLIC CAMPAIGNS.CAMPAIGN_DATE as date with synonyms=('date','campaign date') comment='Date of the campaign activity',
		PUBLIC CAMPAIGNS.CAMPAIGN_FACT_ID as CAMPAIGN_FACT_ID,
		PUBLIC CAMPAIGNS.CAMPAIGN_KEY as CAMPAIGN_KEY,
		PUBLIC CAMPAIGNS.CAMPAIGN_MONTH as MONTH(date) comment='Month of the campaign',
		PUBLIC CAMPAIGNS.CAMPAIGN_YEAR as YEAR(date) comment='Year of the campaign',
		PUBLIC CAMPAIGNS.CHANNEL_KEY as CHANNEL_KEY,
		PUBLIC CAMPAIGNS.PRODUCT_KEY as PRODUCT_KEY with synonyms=('product_id','product identifier') comment='Product identifier for campaign targeting',
		PUBLIC CAMPAIGNS.REGION_KEY as REGION_KEY,
		PUBLIC CAMPAIGN_DETAILS.CAMPAIGN_KEY as CAMPAIGN_KEY,
		PUBLIC CAMPAIGN_DETAILS.CAMPAIGN_NAME as CAMPAIGN_NAME with synonyms=('campaign','campaign title') comment='Name of the marketing campaign',
		PUBLIC CAMPAIGN_DETAILS.CAMPAIGN_OBJECTIVE as OBJECTIVE with synonyms=('objective','goal','purpose') comment='Campaign objective',
		PUBLIC CHANNELS.CHANNEL_KEY as CHANNEL_KEY,
		PUBLIC CHANNELS.CHANNEL_NAME as CHANNEL_NAME with synonyms=('channel','marketing channel') comment='Name of the marketing channel',
		PUBLIC CONTACTS.ACCOUNT_ID as ACCOUNT_ID,
		PUBLIC CONTACTS.CAMPAIGN_NO as CAMPAIGN_NO,
		PUBLIC CONTACTS.CONTACT_ID as CONTACT_ID,
		PUBLIC CONTACTS.DEPARTMENT as DEPARTMENT with synonyms=('department','business unit') comment='Contact department',
		PUBLIC CONTACTS.EMAIL as EMAIL with synonyms=('email','email address') comment='Contact email address',
		PUBLIC CONTACTS.FIRST_NAME as FIRST_NAME with synonyms=('first name','contact name') comment='Contact first name',
		PUBLIC CONTACTS.LAST_NAME as LAST_NAME with synonyms=('last name','surname') comment='Contact last name',
		PUBLIC CONTACTS.LEAD_SOURCE as LEAD_SOURCE with synonyms=('lead source','source') comment='How the contact was generated',
		PUBLIC CONTACTS.OPPORTUNITY_ID as OPPORTUNITY_ID,
		PUBLIC CONTACTS.TITLE as TITLE with synonyms=('job title','position') comment='Contact job title',
		PUBLIC OPPORTUNITIES.ACCOUNT_ID as ACCOUNT_ID,
		PUBLIC OPPORTUNITIES.CAMPAIGN_ID as CAMPAIGN_ID with synonyms=('campaign fact id','marketing campaign id') comment='Campaign fact ID that links opportunity to marketing campaign',
		PUBLIC OPPORTUNITIES.CLOSE_DATE as CLOSE_DATE with synonyms=('close date','expected close') comment='Expected or actual close date',
		PUBLIC OPPORTUNITIES.OPPORTUNITY_ID as OPPORTUNITY_ID,
		PUBLIC OPPORTUNITIES.OPPORTUNITY_LEAD_SOURCE as lead_source with synonyms=('opportunity source','deal source') comment='Source of the opportunity',
		PUBLIC OPPORTUNITIES.OPPORTUNITY_NAME as OPPORTUNITY_NAME with synonyms=('deal name','opportunity title') comment='Name of the sales opportunity',
		PUBLIC OPPORTUNITIES.OPPORTUNITY_STAGE as STAGE_NAME comment='Stage name of the opportinity. Closed Won indicates an actual sale with revenue',
		PUBLIC OPPORTUNITIES.OPPORTUNITY_TYPE as TYPE with synonyms=('deal type','opportunity type') comment='Type of opportunity',
		PUBLIC OPPORTUNITIES.SALES_SALE_ID as SALE_ID with synonyms=('sales id','invoice no') comment='Sales_ID for sales_fact table that links this opp to a sales record.',
		PUBLIC PRODUCTS.PRODUCT_CATEGORY as CATEGORY_NAME with synonyms=('category','product category') comment='Category of the product',
		PUBLIC PRODUCTS.PRODUCT_KEY as PRODUCT_KEY,
		PUBLIC PRODUCTS.PRODUCT_NAME as PRODUCT_NAME with synonyms=('product','item','product title') comment='Name of the product being promoted',
		PUBLIC PRODUCTS.PRODUCT_VERTICAL as VERTICAL with synonyms=('vertical','industry') comment='Business vertical of the product',
		PUBLIC REGIONS.REGION_KEY as REGION_KEY,
		PUBLIC REGIONS.REGION_NAME as REGION_NAME with synonyms=('region','market','territory') comment='Name of the region'
	)
	metrics (
		PUBLIC CAMPAIGNS.AVERAGE_SPEND as AVG(CAMPAIGNS.spend) comment='Average campaign spend',
		PUBLIC CAMPAIGNS.TOTAL_CAMPAIGNS as COUNT(CAMPAIGNS.campaign_record) comment='Total number of campaign activities',
		PUBLIC CAMPAIGNS.TOTAL_IMPRESSIONS as SUM(CAMPAIGNS.impressions) comment='Total impressions across campaigns',
		PUBLIC CAMPAIGNS.TOTAL_LEADS as SUM(CAMPAIGNS.leads_generated) comment='Total leads generated from campaigns',
		PUBLIC CAMPAIGNS.TOTAL_SPEND as SUM(CAMPAIGNS.spend) comment='Total marketing spend',
		PUBLIC CONTACTS.TOTAL_CONTACTS as COUNT(CONTACTS.contact_record) comment='Total contacts generated from campaigns',
		PUBLIC OPPORTUNITIES.AVERAGE_DEAL_SIZE as AVG(OPPORTUNITIES.revenue) comment='Average opportunity size from marketing',
		PUBLIC OPPORTUNITIES.CLOSED_WON_REVENUE as SUM(CASE WHEN OPPORTUNITIES.opportunity_stage = 'Closed Won' THEN OPPORTUNITIES.revenue ELSE 0 END) comment='Revenue from closed won opportunities',
		PUBLIC OPPORTUNITIES.TOTAL_OPPORTUNITIES as COUNT(OPPORTUNITIES.opportunity_record) comment='Total opportunities from marketing',
		PUBLIC OPPORTUNITIES.TOTAL_REVENUE as SUM(OPPORTUNITIES.revenue) comment='Total revenue from marketing-driven opportunities'
	)
	comment='Enhanced semantic view for marketing campaign analysis with complete revenue attribution and ROI tracking'
	with extension (CA='{"tables":[{"name":"ACCOUNTS","dimensions":[{"name":"ACCOUNT_ID"},{"name":"ACCOUNT_NAME"},{"name":"ACCOUNT_TYPE"},{"name":"ANNUAL_REVENUE"},{"name":"EMPLOYEES"},{"name":"INDUSTRY"},{"name":"SALES_CUSTOMER_KEY"}]},{"name":"CAMPAIGNS","dimensions":[{"name":"CAMPAIGN_DATE"},{"name":"CAMPAIGN_FACT_ID"},{"name":"CAMPAIGN_KEY"},{"name":"CAMPAIGN_MONTH"},{"name":"CAMPAIGN_YEAR"},{"name":"CHANNEL_KEY"},{"name":"PRODUCT_KEY"},{"name":"REGION_KEY"}],"facts":[{"name":"CAMPAIGN_RECORD"},{"name":"CAMPAIGN_SPEND"},{"name":"IMPRESSIONS"},{"name":"LEADS_GENERATED"}],"metrics":[{"name":"AVERAGE_SPEND"},{"name":"TOTAL_CAMPAIGNS"},{"name":"TOTAL_IMPRESSIONS"},{"name":"TOTAL_LEADS"},{"name":"TOTAL_SPEND"}]},{"name":"CAMPAIGN_DETAILS","dimensions":[{"name":"CAMPAIGN_KEY"},{"name":"CAMPAIGN_NAME"},{"name":"CAMPAIGN_OBJECTIVE"}]},{"name":"CHANNELS","dimensions":[{"name":"CHANNEL_KEY"},{"name":"CHANNEL_NAME"}]},{"name":"CONTACTS","dimensions":[{"name":"ACCOUNT_ID"},{"name":"CAMPAIGN_NO"},{"name":"CONTACT_ID"},{"name":"DEPARTMENT"},{"name":"EMAIL"},{"name":"FIRST_NAME"},{"name":"LAST_NAME"},{"name":"LEAD_SOURCE"},{"name":"OPPORTUNITY_ID"},{"name":"TITLE"}],"facts":[{"name":"CONTACT_RECORD"}],"metrics":[{"name":"TOTAL_CONTACTS"}]},{"name":"CONTACTS_FOR_OPPORTUNITIES"},{"name":"OPPORTUNITIES","dimensions":[{"name":"ACCOUNT_ID"},{"name":"CAMPAIGN_ID"},{"name":"CLOSE_DATE"},{"name":"OPPORTUNITY_ID"},{"name":"OPPORTUNITY_LEAD_SOURCE"},{"name":"OPPORTUNITY_NAME"},{"name":"OPPORTUNITY_STAGE","sample_values":["Closed Won","Perception Analysis","Qualification"]},{"name":"OPPORTUNITY_TYPE"},{"name":"SALES_SALE_ID"}],"facts":[{"name":"OPPORTUNITY_RECORD"},{"name":"REVENUE"}],"metrics":[{"name":"AVERAGE_DEAL_SIZE"},{"name":"CLOSED_WON_REVENUE"},{"name":"TOTAL_OPPORTUNITIES"},{"name":"TOTAL_REVENUE"}]},{"name":"PRODUCTS","dimensions":[{"name":"PRODUCT_CATEGORY"},{"name":"PRODUCT_KEY"},{"name":"PRODUCT_NAME"},{"name":"PRODUCT_VERTICAL"}]},{"name":"REGIONS","dimensions":[{"name":"REGION_KEY"},{"name":"REGION_NAME"}]}],"relationships":[{"name":"CAMPAIGNS_TO_CHANNELS","relationship_type":"many_to_one"},{"name":"CAMPAIGNS_TO_DETAILS","relationship_type":"many_to_one"},{"name":"CAMPAIGNS_TO_PRODUCTS","relationship_type":"many_to_one"},{"name":"CAMPAIGNS_TO_REGIONS","relationship_type":"many_to_one"},{"name":"CONTACTS_TO_ACCOUNTS","relationship_type":"many_to_one"},{"name":"CONTACTS_TO_CAMPAIGNS","relationship_type":"many_to_one"},{"name":"CONTACTS_TO_OPPORTUNITIES","relationship_type":"many_to_one"},{"name":"OPPORTUNITIES_TO_ACCOUNTS","relationship_type":"many_to_one"},{"name":"OPPORTUNITIES_TO_CAMPAIGNS"}],"verified_queries":[{"name":"include opps that turned in to sales deal","question":"include opps that turned in to sales deal","sql":"WITH campaign_impressions AS (\\n  SELECT\\n    c.campaign_key,\\n    cd.campaign_name,\\n    SUM(c.impressions) AS total_impressions\\n  FROM\\n    campaigns AS c\\n    LEFT OUTER JOIN campaign_details AS cd ON c.campaign_key = cd.campaign_key\\n  WHERE\\n    c.campaign_year = 2025\\n  GROUP BY\\n    c.campaign_key,\\n    cd.campaign_name\\n),\\ncampaign_opportunities AS (\\n  SELECT\\n    c.campaign_key,\\n    COUNT(o.opportunity_record) AS total_opportunities,\\n    COUNT(\\n      CASE\\n        WHEN o.opportunity_stage = ''Closed Won'' THEN o.opportunity_record\\n      END\\n    ) AS closed_won_opportunities\\n  FROM\\n    campaigns AS c\\n    LEFT OUTER JOIN opportunities AS o ON c.campaign_fact_id = o.campaign_id\\n  WHERE\\n    c.campaign_year = 2025\\n  GROUP BY\\n    c.campaign_key\\n)\\nSELECT\\n  ci.campaign_name,\\n  ci.total_impressions,\\n  COALESCE(co.total_opportunities, 0) AS total_opportunities,\\n  COALESCE(co.closed_won_opportunities, 0) AS closed_won_opportunities\\nFROM\\n  campaign_impressions AS ci\\n  LEFT JOIN campaign_opportunities AS co ON ci.campaign_key = co.campaign_key\\nORDER BY\\n  ci.total_impressions DESC NULLS LAST","use_as_onboarding_question":false,"verified_by":"Nick Akincilar","verified_at":1757262696}]}');


create or replace semantic view sales_db.shared_data.FINANCE_SEMANTIC_VIEW
    tables (
        TRANSACTIONS as SHARED_SNOW_XCLOUD_FINANCE.SNOW_DATA.FINANCE_TRANSACTIONS primary key (TRANSACTION_ID) with synonyms=('finance transactions','financial data') comment='All financial transactions across departments',
        ACCOUNTS as SHARED_SNOW_XCLOUD_FINANCE.SNOW_DATA.ACCOUNT_DIM primary key (ACCOUNT_KEY) with synonyms=('chart of accounts','account types') comment='Account dimension for financial categorization',
        DEPARTMENTS as SHARED_SNOW_XCLOUD_FINANCE.SNOW_DATA.DEPARTMENT_DIM primary key (DEPARTMENT_KEY) with synonyms=('business units','departments') comment='Department dimension for cost center analysis',
        VENDORS as SHARED_SNOW_XCLOUD_FINANCE.SNOW_DATA.VENDOR_DIM primary key (VENDOR_KEY) with synonyms=('suppliers','vendors') comment='Vendor information for spend analysis',
        PRODUCTS as SHARED_SNOW_XCLOUD_FINANCE.SNOW_DATA.PRODUCT_DIM primary key (PRODUCT_KEY) with synonyms=('products','items') comment='Product dimension for transaction analysis',
        CUSTOMERS as SHARED_SNOW_XCLOUD_FINANCE.SNOW_DATA.CUSTOMER_DIM primary key (CUSTOMER_KEY) with synonyms=('clients','customers') comment='Customer dimension for revenue analysis'
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

  == SETUP Snowflake Intelligence: END === */


  /*== DEMO Snowflake Intelligence: START === */
/*
use role sales_domain_role;
create or replace database shared_delta_xregion_hr from listing ORGDATACLOUD$INTERNAL$HR_DATA_PRODUCT;

-- PreRun SQL
--create or replace database shared_iceberg_xregion_marketing from listing ORGDATACLOUD$INTERNAL$MARKETING_DATA_PRODUCT;
--create or replace database shared_delta_xregion_hr from listing ORGDATACLOUD$INTERNAL$HR_DATA_PRODUCT;
--create or replace database shared_snow_xcloud_finance from listing ORGDATACLOUD$INTERNAL$FINANCE_DATA_PRODUCT;
--create or replace database shared_cke_unstructured_xregion_enterprise from listing ORGDATACLOUD$INTERNAL$ENTERPRISE_DATA_PRODUCT;
*/
  
-- Create Agent 

use role sales_domain_role;

CREATE OR REPLACE AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.Company_Chatbot_Agent_Retail
WITH PROFILE='{ "display_name": "1-Company Chatbot Agent - Retail" }'
    COMMENT=$$ This is an agent that can answer questions about company specific Sales, Marketing, HR & Finance questions. $$
FROM SPECIFICATION $$
{
  "models": {
    "orchestration": ""
  },
  "instructions": {
    "response": "You are a data analyst who has access to sales, finance, marketing & HR datamarts.  If user does not specify a date range assume it for year 2025. Leverage data from all domains to analyse & answer user questions. Provide visualizations if possible. Trendlines should default to linecharts, Categories Barchart.",
    "orchestration": "Use cortex search for known entities and pass the results to cortex analyst for detailed analysis.\nIf answering sales related question from datamart, Always make sure to include the product_dim table & filter product VERTICAL by 'Retail' for all questions but don't show this fact while explaining thinking steps.\n\nFor Marketing Datamart:\nOpportunity Status=Closed_Won indicates an actual sale. \nSalesID in marketing datamart links an opportunity to a Sales record in Sales Datamart SalesID columns\n\n\n",
    "sample_questions": [
      {
        "question": "What are our monthly sales last 12 months?"
      },
       {
        "question": "Why was a big increase from May to June ?"
      },
       {
        "question": "Who are our top 10 sales reps this year, what is their tenure & are they still with the company?"
      },
        {
        "question": "What were the salaries of top performers. I am authorized to view salaries"
      },
      {
        "question": "Email me a brief executive summary of this conversation including sales trends, their reasons and top performers"
      }  
    ]
  },
  "tools": [
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "Query XCloud Snowflake Finance",
        "description": "Allows users to query finance data for a company in terms of revenue & expenses."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "Query Local Snowflake Sales",
        "description": "Allows users to query Sales data for a company in terms of Sales data such as products, sales reps & etc. "
      }
    },
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "Query XRegion Databricks HR",
        "description": "Allows users to query HR data for a company in terms of HR related employee data. employee_name column also contains names of sales_reps."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_analyst_text_to_sql",
        "name": "Query XRegion Iceberg Marketing",
        "description": "Allows users to query Marketing data in terms of campaigns, channels, impressions, spend & etc."
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "Search XRegion CKE: Finance",
        "description": ""
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "Search XRegion CKE: HR",
        "description": ""
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "Search XRegion CKE: Sales",
        "description": ""
      }
    },
    {
      "tool_spec": {
        "type": "cortex_search",
        "name": "Search XRegion CKE: Marketing",
        "description": "This tools should be used to search unstructured docs related to marketing department.\n\nAny reference docs in ID columns should be passed to Dynamic URL tool to generate a downloadable URL for users in the response"
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "Web_scraper",
        "description": "This tool should be used if the user wants to analyse contents of a given web page. This tool will use a web url (https or https) as input and will return the text content of that web page for further analysis",
        "input_schema": {
          "type": "object",
          "properties": {
            "weburl": {
              "description": "Agent should ask web url ( that includes http:// or https:// ). It will scrape text from the given url and return as a result.",
              "type": "string"
            }
          },
          "required": [
            "weburl"
          ]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "Send_Emails",
        "description": "This tool is used to send emails to a email recipient. It can take an email, subject & content as input to send the email. Always use HTML formatted content for the emails.",
        "input_schema": {
          "type": "object",
          "properties": {
            "recipient": {
              "description": "recipient of email",
              "type": "string"
            },
            "subject": {
              "description": "subject of email",
              "type": "string"
            },
            "text": {
              "description": "content of email",
              "type": "string"
            }
          },
          "required": [
            "text",
            "recipient",
            "subject"
          ]
        }
      }
    },
    {
      "tool_spec": {
        "type": "generic",
        "name": "Dynamic_Doc_URL_Tool",
        "description": "This tools uses the ID Column coming from Cortex Search tools for reference docs and returns a temp URL for users to view & download the docs.\n\nReturned URL should be presented as a HTML Hyperlink where doc title should be the text and out of this tool should be the url.\n\nURL format for PDF docs that are are like this which has no PDF in the url. Create the Hyperlink format so the PDF doc opens up in a browser instead of downloading the file.\nhttps://domain/path/unique_guid",
        "input_schema": {
          "type": "object",
          "properties": {
            "expiration_mins": {
              "description": "default should be 5",
              "type": "number"
            },
            "relative_file_path": {
              "description": "This is the ID Column value Coming from Cortex Search tool.",
              "type": "string"
            }
          },
          "required": [
            "expiration_mins",
            "relative_file_path"
          ]
        }
      }
    }
  ],
  "tool_resources": {
    "Dynamic_Doc_URL_Tool": {
      "execution_environment": {
        "query_timeout": 0,
        "type": "warehouse",
        "warehouse": "SALES_WH"
      },
      "identifier": "SALES_DB.SNOW_DATA.GET_FILE_PRESIGNED_URL_SP",
      "name": "GET_FILE_PRESIGNED_URL_SP(VARCHAR, DEFAULT NUMBER)",
      "type": "procedure"
    },
    "Query XCloud Snowflake Finance": {
      "semantic_view": "SALES_DB.SHARED_DATA.FINANCE_SEMANTIC_VIEW",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "SALES_WH",
        "query_timeout": 0
      }
    },
    "Query XRegion Databricks HR": {
      "semantic_view": "SALES_DB.SHARED_DATA.HR_SEMANTIC_VIEW",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "SALES_WH",
        "query_timeout": 0
      }
    },
    "Query XRegion Iceberg Marketing": {
      "semantic_view": "SALES_DB.SHARED_DATA.MARKETING_SEMANTIC_VIEW",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "SALES_WH",
        "query_timeout": 0
      }
    },
    "Query Local Snowflake Sales": {
      "semantic_view": "SALES_DB.SNOW_DATA.SALES_SEMANTIC_VIEW",
      "execution_environment": {
        "type": "warehouse",
        "warehouse": "SALES_WH",
        "query_timeout": 0
      }
    },
    "Search XRegion CKE: Finance": {
      "id_column": "FILE_URL",
      "max_results": 5,
      "name": "SHARED_CKE_UNSTRUCTURED_XREGION_ENTERPRISE.S3_UNSTRUCTURED_DATA.SEARCH_FINANCE_DOCS",
      "title_column": "TITLE"
    },
    "Search XRegion CKE: HR": {
      "id_column": "FILE_URL",
      "max_results": 5,
      "name": "SHARED_CKE_UNSTRUCTURED_XREGION_ENTERPRISE.S3_UNSTRUCTURED_DATA.SEARCH_HR_DOCS",
      "title_column": "TITLE"
    },
    "Search XRegion CKE: Marketing": {
      "id_column": "RELATIVE_PATH",
      "max_results": 5,
      "name": "SHARED_CKE_UNSTRUCTURED_XREGION_ENTERPRISE.S3_UNSTRUCTURED_DATA.SEARCH_MARKETING_DOCS",
      "title_column": "TITLE"
    },
    "Search XRegion CKE: Sales": {
      "id_column": "FILE_URL",
      "max_results": 5,
      "name": "SHARED_CKE_UNSTRUCTURED_XREGION_ENTERPRISE.S3_UNSTRUCTURED_DATA.SEARCH_SALES_DOCS",
      "title_column": "TITLE"
    },
    "Send_Emails": {
      "execution_environment": {
        "query_timeout": 0,
        "type": "warehouse",
        "warehouse": "SALES_WH"
      },
      "identifier": "SALES_DB.SNOW_DATA.SEND_MAIL",
      "name": "SEND_MAIL(VARCHAR, VARCHAR, VARCHAR)",
      "type": "procedure"
    },
    "Web_scraper": {
      "execution_environment": {
        "query_timeout": 0,
        "type": "warehouse",
        "warehouse": "SALES_WH"
      },
      "identifier": "SALES_DB.SNOW_DATA.WEB_SCRAPE",
      "name": "WEB_SCRAPE(VARCHAR)",
      "type": "function"
    }
  }
}
$$;