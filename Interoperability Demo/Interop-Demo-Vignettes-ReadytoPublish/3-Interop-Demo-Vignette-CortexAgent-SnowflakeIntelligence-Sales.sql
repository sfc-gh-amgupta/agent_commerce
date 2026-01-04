/*
================================================================================
HORIZON CATALOG - SNOWFLAKE INTELLIGENCE + CORTEX AGENT CONSUMING LISTINGS (XREGION, XCLOUD) w/ DATA, SEMANTICS, VECTORS 
================================================================================
Purpose: This script demonstrates how to:
         1. Set up a sales domain with proper RBAC (Role-Based Access Control)
         2. Create and publish a sales data product as an organization listing
         3. Integrate multiple data products from different domains (HR, Marketing, Finance)
         4. Build semantic views for AI-powered data analysis
         5. Create a Snowflake Intelligence agent that can query across domains

Key Concepts Demonstrated:
  - Data Product creation and sharing
  - Cross-cloud and cross-region data sharing
  - Semantic views for natural language querying
  - Multi-domain AI agent with Cortex Search and Cortex Analyst
  - Interoperability with Databricks Delta tables and Apache Iceberg

Author: Amit Gupta
Last Updated: October 15, 2025
Demo: Available at Interoperable Data Mesh Webinar - https://www.snowflake.com/en/webinars/demo/unlocking-ai-with-an-interoperable-data-mesh-2025-10-16/
 
================================================================================
*/


/*******************************************************************************
 * SECTION 1: SALES DOMAIN SETUP
 * 
 * Create the foundational infrastructure for the sales domain including:
 * - Role for sales domain management
 * - Warehouse for compute
 * - Database to hold sales data
 * - Necessary privileges for data sharing and listing management
 ******************************************************************************/

USE ROLE accountadmin;

-- Create the sales database that will hold our native Snowflake tables
CREATE OR REPLACE DATABASE sales_db;

-- Create a dedicated role for sales domain management
-- This follows best practice of domain-oriented data architecture
CREATE ROLE sales_domain_role;

-- Create compute warehouse for sales domain workloads
CREATE WAREHOUSE sales_wh;

-- Transfer ownership of resources to the sales domain role
-- This enables the sales domain to be self-sufficient
GRANT OWNERSHIP ON WAREHOUSE sales_wh TO ROLE sales_domain_role;
GRANT OWNERSHIP ON DATABASE sales_db TO ROLE sales_domain_role;


/*******************************************************************************
 * SECTION 2: DATA SHARING PRIVILEGES
 * 
 * Grant privileges required for the sales domain to:
 * - Create and manage data shares
 * - Publish organization listings
 * - Enable auto-fulfillment for consumers
 * 
 * Note: To enable global data sharing for the account, run as ORGADMIN:
 * SELECT SYSTEM$ENABLE_GLOBAL_DATA_SHARING_FOR_ACCOUNT('ACCOUNT_LOCATOR');
 ******************************************************************************/

-- Grant privilege to manage auto-fulfillment of data product requests
-- This allows automatic provisioning of data when consumers request access
GRANT MANAGE LISTING AUTO FULFILLMENT ON ACCOUNT TO ROLE sales_domain_role;

-- Grant privilege to create shares for data distribution
GRANT CREATE SHARE ON ACCOUNT TO ROLE sales_domain_role;

-- Grant privilege to create organization listings (internal data marketplace)
GRANT CREATE ORGANIZATION LISTING ON ACCOUNT TO ROLE sales_domain_role;

-- Grant privilege to consume shared data from other accounts
GRANT IMPORT SHARE ON ACCOUNT TO ROLE sales_domain_role;

-- Grant privilege to create databases (needed for mounting shared data)
GRANT CREATE DATABASE ON ACCOUNT TO ROLE sales_domain_role;

-- Assign the sales domain role to a user (replace 'john' with actual username)
GRANT ROLE sales_domain_role TO USER john;


/*******************************************************************************
 * SECTION 3: CREATE SNOWFLAKE TABLES (COMMENTED OUT)
 * 
 * This section shows how to create local copies of tables from a shared
 * data product. In this example, data comes from an "Interop Demo Setup"
 * organization listing.
 * 
 * Uncomment and modify this section if you need to create local tables
 * from a shared data source.
 ******************************************************************************/

/*
USE ROLE sales_domain_role;

-- Create schema to hold Snowflake native format data
CREATE OR REPLACE SCHEMA sales_db.snow_data;

-- Create dimension and fact tables from shared data product
-- These tables contain sales transaction data with customer, product, and regional dimensions
CREATE OR REPLACE TABLE sales_db.snow_data.CUSTOMER_DIM AS 
    SELECT * FROM ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.CUSTOMER_DIM;

CREATE OR REPLACE TABLE sales_db.snow_data.PRODUCT_DIM AS 
    SELECT * FROM ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.PRODUCT_DIM;

CREATE OR REPLACE TABLE sales_db.snow_data.PRODUCT_CATEGORY_DIM AS 
    SELECT * FROM ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.PRODUCT_CATEGORY_DIM;

CREATE OR REPLACE TABLE sales_db.snow_data.REGION_DIM AS 
    SELECT * FROM ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.REGION_DIM;

CREATE OR REPLACE TABLE sales_db.snow_data.SALES_FACT AS 
    SELECT * FROM ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.SALES_FACT;

CREATE OR REPLACE TABLE sales_db.snow_data.SALES_REP_DIM AS 
    SELECT * FROM ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.SALES_REP_DIM;

CREATE OR REPLACE TABLE sales_db.snow_data.VENDOR_DIM AS 
    SELECT * FROM ORGDATACLOUD$INTERNAL$INTEROPDEMOSETUP.demo_schema.VENDOR_DIM;
*/


/*******************************************************************************
 * SECTION 4: CREATE AND PUBLISH SALES DATA PRODUCT
 * 
 * This section demonstrates how to:
 * 1. Create a secure share containing sales data
 * 2. Package it as an organization listing with metadata
 * 3. Configure auto-fulfillment for automated provisioning
 * 4. Publish the listing to the internal data marketplace
 ******************************************************************************/

USE ROLE sales_domain_role;

-- Create a share to securely distribute sales data
-- Shares allow zero-copy data access without data movement
CREATE OR REPLACE SHARE sales_data_share;

-- Grant necessary privileges on database and schema to the share
GRANT USAGE ON DATABASE sales_db TO SHARE sales_data_share;
GRANT USAGE ON SCHEMA sales_db.snow_data TO SHARE sales_data_share;

-- Grant read access to all tables and semantic views in the schema
-- This makes all current and future objects accessible to consumers
GRANT SELECT ON ALL TABLES IN SCHEMA sales_db.snow_data TO SHARE sales_data_share;
GRANT SELECT ON ALL SEMANTIC VIEWS IN SCHEMA sales_db.snow_data TO SHARE sales_data_share;

-- Clean up any existing listing before creating a new one
ALTER LISTING sales_data_product UNPUBLISH;
DROP LISTING sales_data_product;

-- Create organization listing with comprehensive metadata
-- This makes the data discoverable in Snowflake's internal marketplace
CREATE ORGANIZATION LISTING sales_data_product
SHARE sales_data_share AS
$$
title: "[Interop Snowflake Native] Sales Facts"

description: "This data listing provides a comprehensive overview of **sales transactions** within our enterprise. It's an essential resource for analyzing performance, identifying trends, and supporting strategic business decisions. The dataset includes information on all completed sales, from product details to customer demographics.\n\n**Data Contract SLO**\n\n- **Frequency:** Updated every hour to ensure a near real-time view of sales activities.\n- **Source:** Data is curated from point-of-sale (POS) and e-commerce systems\n- **Access:** By Request. Access is restricted to authorized personnel to be determined by owner\n- **No PII**"

data_preview:
  has_pii: false

-- Data dictionary highlights key tables for consumers
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

-- Links to documentation and demo materials
resources:
  documentation: https://www.example.com/documentation/
  media: https://www.youtube.com/watch?v=MEFlT3dc3uc

-- Target audience: all accounts within the organization
organization_profile: 'INTERNAL'
organization_targets:
  discovery:
    - all_internal_accounts: true
  access: []

-- Access requires request and approval workflow
request_approval_type: 'REQUEST_AND_APPROVE_IN_SNOWFLAKE'

-- Contact information for support and approvals
support_contact: "sales_domain_dl@snowflake.com"
approver_contact: "amit.gupta@snowflake.com"

-- Geographic availability (all regions)
locations:
  access_regions:
  - name: "ALL"

-- Auto-fulfillment configuration
-- Automatically provisions a replicated database for approved consumers
-- Refreshes every 1440 minutes (24 hours)
auto_fulfillment:
  refresh_type: 'SUB_DATABASE'
  refresh_schedule: '1440 MINUTE'
  refresh_schedule_override: true
$$ PUBLISH=TRUE;

-- Publish the listing to make it available in the marketplace
ALTER LISTING sales_data_product PUBLISH;


/*******************************************************************************
 * SECTION 5: SNOWFLAKE INTELLIGENCE SETUP
 * 
 * This section sets up a multi-domain data environment for Snowflake Intelligence
 * by mounting data products from various domains:
 * - HR data (from Databricks Delta tables)
 * - Marketing data (from Apache Iceberg tables)
 * - Finance data (from Snowflake native tables, cross-cloud)
 * - Unstructured enterprise data (from S3 using Cortex Knowledge Engine)
 ******************************************************************************/

/* == MOUNT DATA PRODUCTS FROM OTHER DOMAINS ==
 * 
 * These commands create databases that reference shared data products
 * This enables cross-domain analytics without data duplication
 */

/*
USE ROLE sales_domain_role;

-- Mount HR data product (Databricks Delta format, cross-region)
CREATE OR REPLACE DATABASE shared_delta_xregion_hr 
    FROM LISTING ORGDATACLOUD$INTERNAL$HR_DATA_PRODUCT;

-- Mount Marketing data product (Apache Iceberg format, cross-region)
CREATE OR REPLACE DATABASE shared_iceberg_xregion_marketing 
    FROM LISTING ORGDATACLOUD$INTERNAL$MARKETING_DATA_PRODUCT;

-- Mount Finance data product (Snowflake native format, cross-cloud)
CREATE OR REPLACE DATABASE shared_snow_xcloud_finance 
    FROM LISTING ORGDATACLOUD$INTERNAL$FINANCE_DATA_PRODUCT;

-- Mount unstructured enterprise data (Cortex Knowledge Engine, cross-region)
CREATE OR REPLACE DATABASE shared_cke_unstructured_xregion_enterprise 
    FROM LISTING ORGDATACLOUD$INTERNAL$ENTERPRISE_DATA_PRODUCT;
*/


/*******************************************************************************
 * SECTION 6: EXTERNAL ACCESS INTEGRATION
 * 
 * Configure network rules and external access integration to allow:
 * - Web scraping capabilities
 * - External API calls
 * - Email notifications
 * 
 * This is required for the AI agent's advanced features
 ******************************************************************************/

/*
USE ROLE sales_domain_role;
USE SCHEMA sales_db.snow_data;

-- Create network rule to allow outbound HTTPS connections
-- Required for web scraping and external API calls
CREATE OR REPLACE NETWORK RULE Snowflake_intelligence_WebAccessRule
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('0.0.0.0:80', '0.0.0.0:443');

-- Grant necessary privileges for external access integration
USE ROLE accountadmin;
GRANT ROLE sales_domain_role TO ROLE accountadmin;
GRANT CREATE INTEGRATION ON ACCOUNT TO ROLE sales_domain_role;

-- Create external access integration using the network rule
USE ROLE sales_domain_role;
USE SCHEMA SALES_DB.SNOW_DATA;

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION Snowflake_intelligence_ExternalAccess_Integration
ALLOWED_NETWORK_RULES = (Snowflake_intelligence_WebAccessRule)
ENABLED = true;

-- Create email notification integration for sending reports
CREATE NOTIFICATION INTEGRATION ai_email_int
  TYPE=EMAIL
  ENABLED=TRUE;

-- Create database and schema for Snowflake Intelligence agents
CREATE DATABASE IF NOT EXISTS snowflake_intelligence;
CREATE SCHEMA IF NOT EXISTS snowflake_intelligence.agents;

-- Grant necessary privileges to sales domain role
GRANT USAGE ON DATABASE snowflake_intelligence TO ROLE sales_domain_role;
GRANT USAGE ON SCHEMA snowflake_intelligence.agents TO ROLE sales_domain_role;
GRANT CREATE AGENT ON SCHEMA snowflake_intelligence.agents TO ROLE sales_domain_role;
*/


/*******************************************************************************
 * SECTION 7: STORED PROCEDURES FOR AGENT TOOLS
 * 
 * Create stored procedures that the AI agent can use as tools:
 * 1. Get_File_Presigned_URL_SP - Generate presigned URLs for file access
 * 2. send_mail - Send email notifications to verified recipients
 ******************************************************************************/

/*
USE ROLE sales_domain_role;
USE WAREHOUSE sales_wh;

-- Stored procedure to generate presigned URLs for files in internal stages
-- Note: With Cortex Knowledge Engine, this may have limited functionality
-- as presigned URLs cannot always be generated for CKE-managed files
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
BEGIN
    -- Convert minutes to seconds
    expiration_seconds := EXPIRATION_MINS * 60;
    
    -- Note: URL generation logic would go here
    -- Currently placeholder as CKE may not support presigned URLs
    
    RETURN :presigned_url;
END;
$$;

-- Stored procedure to send emails via Snowflake's email notification system
-- Recipients must be verified in Snowflake before they can receive emails
CREATE OR REPLACE PROCEDURE send_mail(
    recipient TEXT,  -- Email address of recipient
    subject TEXT,    -- Email subject line
    text TEXT        -- Email body (supports HTML)
)
RETURNS TEXT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'send_mail'
AS
$$
def send_mail(session, recipient, subject, text):
    # Call system procedure to send email
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
*/


/*******************************************************************************
 * SECTION 8: SEMANTIC VIEWS FOR AI-POWERED QUERYING
 * 
 * Create semantic views that enable natural language querying via Cortex Analyst
 * Each semantic view defines:
 * - Tables and their relationships
 * - Facts (measurable metrics)
 * - Dimensions (attributes for filtering/grouping)
 * - Pre-calculated metrics for common queries
 * - Synonyms for natural language understanding
 * 
 * Workaround Note: These views are created locally because semantic view
 * listing and fulfillment (LAF) is not yet generally available
 ******************************************************************************/

/*
USE ROLE sales_domain_role;

-- Create schema for shared data semantic views
CREATE OR REPLACE SCHEMA sales_db.shared_data;
USE SCHEMA sales_db.shared_data;


-- ============================================================================
-- HR SEMANTIC VIEW
-- Purpose: Enable natural language queries about employees, departments, and HR metrics
-- ============================================================================

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
            WITH SYNONYMS=('turnover_indicator','employee_departure_flag','separation_flag',
                          'employee_retention_status','churn_status','employee_exit_indicator') 
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
    -- Includes sample values and verified queries to improve AI understanding
    WITH EXTENSION (
        CA='{"tables":[{"name":"DEPARTMENTS","dimensions":[{"name":"DEPARTMENT_KEY"},{"name":"DEPARTMENT_NAME","sample_values":["Finance","Accounting","Treasury"]}]},{"name":"EMPLOYEES","dimensions":[{"name":"EMPLOYEE_KEY"},{"name":"EMPLOYEE_NAME","sample_values":["Grant Frey","Elizabeth George","Olivia Mcdaniel"]},{"name":"GENDER"},{"name":"HIRE_DATE"}]},{"name":"HR_RECORDS","dimensions":[{"name":"DEPARTMENT_KEY"},{"name":"EMPLOYEE_KEY"},{"name":"HR_FACT_ID"},{"name":"JOB_KEY"},{"name":"LOCATION_KEY"},{"name":"RECORD_DATE"},{"name":"RECORD_MONTH"},{"name":"RECORD_YEAR"}],"facts":[{"name":"ATTRITION_FLAG","sample_values":["0","1"]},{"name":"EMPLOYEE_RECORD"},{"name":"EMPLOYEE_SALARY"}],"metrics":[{"name":"ATTRITION_COUNT"},{"name":"AVG_SALARY"},{"name":"TOTAL_EMPLOYEES"},{"name":"TOTAL_SALARY_COST"}]},{"name":"JOBS","dimensions":[{"name":"JOB_KEY"},{"name":"JOB_LEVEL"},{"name":"JOB_TITLE"}]},{"name":"LOCATIONS","dimensions":[{"name":"LOCATION_KEY"},{"name":"LOCATION_NAME"}]}],"relationships":[{"name":"HR_TO_DEPARTMENTS","relationship_type":"many_to_one"},{"name":"HR_TO_EMPLOYEES","relationship_type":"many_to_one"},{"name":"HR_TO_JOBS","relationship_type":"many_to_one"},{"name":"HR_TO_LOCATIONS","relationship_type":"many_to_one"}],"verified_queries":[{"name":"List of all active employees","question":"List of all active employees","sql":"select\\n  h.employee_key,\\n  e.employee_name,\\nfrom\\n  employees e\\n  left join hr_records h on e.employee_key = h.employee_key\\ngroup by\\n  all\\nhaving\\n  sum(h.attrition_flag) = 0;","use_as_onboarding_question":false,"verified_by":"Nick Akincilar","verified_at":1753846263},{"name":"List of all inactive employees","question":"List of all inactive employees","sql":"SELECT\\n  h.employee_key,\\n  e.employee_name\\nFROM\\n  employees AS e\\n  LEFT JOIN hr_records AS h ON e.employee_key = h.employee_key\\nGROUP BY\\n  ALL\\nHAVING\\n  SUM(h.attrition_flag) > 0","use_as_onboarding_question":false,"verified_by":"Nick Akincilar","verified_at":1753846300}],"custom_instructions":"- Each employee can have multiple hr_employee_fact records. \\n- Only one hr_employee_fact record per employee is valid and that is the one which has the highest date value."}'
    );


-- ============================================================================
-- MARKETING SEMANTIC VIEW
-- Purpose: Enable natural language queries about campaigns, leads, and marketing ROI
-- ============================================================================

CREATE OR REPLACE SEMANTIC VIEW MARKETING_SEMANTIC_VIEW
    TABLES (
        ACCOUNTS AS shared_iceberg_xregion_marketing.iceberg_data.SF_ACCOUNTS 
            PRIMARY KEY (ACCOUNT_ID) 
            WITH SYNONYMS=('customers','accounts','clients') 
            COMMENT='Customer account information for revenue analysis',
            
        CAMPAIGNS AS shared_iceberg_xregion_marketing.iceberg_data.MARKETING_CAMPAIGN_FACT 
            PRIMARY KEY (CAMPAIGN_FACT_ID) 
            WITH SYNONYMS=('marketing campaigns','campaign data') 
            COMMENT='Marketing campaign performance data',
            
        CAMPAIGN_DETAILS AS shared_iceberg_xregion_marketing.iceberg_data.CAMPAIGN_DIM 
            PRIMARY KEY (CAMPAIGN_KEY) 
            WITH SYNONYMS=('campaign info','campaign details') 
            COMMENT='Campaign dimension with objectives and names',
            
        CHANNELS AS shared_iceberg_xregion_marketing.iceberg_data.CHANNEL_DIM 
            PRIMARY KEY (CHANNEL_KEY) 
            WITH SYNONYMS=('marketing channels','channels') 
            COMMENT='Marketing channel information',
            
        CONTACTS AS shared_iceberg_xregion_marketing.iceberg_data.SF_CONTACTS 
            PRIMARY KEY (CONTACT_ID) 
            WITH SYNONYMS=('leads','contacts','prospects') 
            COMMENT='Contact records generated from marketing campaigns',
            
        CONTACTS_FOR_OPPORTUNITIES AS shared_iceberg_xregion_marketing.iceberg_data.SF_CONTACTS 
            PRIMARY KEY (CONTACT_ID) 
            WITH SYNONYMS=('opportunity contacts') 
            COMMENT='Contact records generated from marketing campaigns, specifically for opportunities, not leads',
            
        OPPORTUNITIES AS shared_iceberg_xregion_marketing.iceberg_data.SF_OPPORTUNITIES 
            PRIMARY KEY (OPPORTUNITY_ID) 
            WITH SYNONYMS=('deals','opportunities','sales pipeline') 
            COMMENT='Sales opportunities and revenue data',
            
        PRODUCTS AS shared_iceberg_xregion_marketing.iceberg_data.PRODUCT_DIM 
            PRIMARY KEY (PRODUCT_KEY) 
            WITH SYNONYMS=('products','items') 
            COMMENT='Product dimension for campaign-specific analysis',
            
        REGIONS AS shared_iceberg_xregion_marketing.iceberg_data.REGION_DIM 
            PRIMARY KEY (REGION_KEY) 
            WITH SYNONYMS=('territories','regions','markets') 
            COMMENT='Regional information for campaign analysis'
    )
    
    RELATIONSHIPS (
        CAMPAIGNS_TO_CHANNELS AS CAMPAIGNS(CHANNEL_KEY) REFERENCES CHANNELS(CHANNEL_KEY),
        CAMPAIGNS_TO_DETAILS AS CAMPAIGNS(CAMPAIGN_KEY) REFERENCES CAMPAIGN_DETAILS(CAMPAIGN_KEY),
        CAMPAIGNS_TO_PRODUCTS AS CAMPAIGNS(PRODUCT_KEY) REFERENCES PRODUCTS(PRODUCT_KEY),
        CAMPAIGNS_TO_REGIONS AS CAMPAIGNS(REGION_KEY) REFERENCES REGIONS(REGION_KEY),
        CONTACTS_TO_ACCOUNTS AS CONTACTS(ACCOUNT_ID) REFERENCES ACCOUNTS(ACCOUNT_ID),
        CONTACTS_TO_CAMPAIGNS AS CONTACTS(CAMPAIGN_NO) REFERENCES CAMPAIGNS(CAMPAIGN_FACT_ID),
        CONTACTS_TO_OPPORTUNITIES AS CONTACTS_FOR_OPPORTUNITIES(OPPORTUNITY_ID) REFERENCES OPPORTUNITIES(OPPORTUNITY_ID),
        OPPORTUNITIES_TO_ACCOUNTS AS OPPORTUNITIES(ACCOUNT_ID) REFERENCES ACCOUNTS(ACCOUNT_ID),
        OPPORTUNITIES_TO_CAMPAIGNS AS OPPORTUNITIES(CAMPAIGN_ID) REFERENCES CAMPAIGNS(CAMPAIGN_FACT_ID)
    )
    
    FACTS (
        PUBLIC CAMPAIGNS.CAMPAIGN_RECORD AS 1 
            COMMENT='Count of campaign activities',
        PUBLIC CAMPAIGNS.CAMPAIGN_SPEND AS spend 
            COMMENT='Marketing spend in dollars',
        PUBLIC CAMPAIGNS.IMPRESSIONS AS IMPRESSIONS 
            COMMENT='Number of impressions',
        PUBLIC CAMPAIGNS.LEADS_GENERATED AS LEADS_GENERATED 
            COMMENT='Number of leads generated',
        PUBLIC CONTACTS.CONTACT_RECORD AS 1 
            COMMENT='Count of contacts generated',
        PUBLIC OPPORTUNITIES.OPPORTUNITY_RECORD AS 1 
            COMMENT='Count of opportunities created',
        PUBLIC OPPORTUNITIES.REVENUE AS AMOUNT 
            COMMENT='Opportunity revenue in dollars'
    )
    
    DIMENSIONS (
        -- Account dimensions
        PUBLIC ACCOUNTS.ACCOUNT_ID AS ACCOUNT_ID,
        PUBLIC ACCOUNTS.ACCOUNT_NAME AS ACCOUNT_NAME 
            WITH SYNONYMS=('customer name','client name','company') 
            COMMENT='Name of the customer account',
        PUBLIC ACCOUNTS.ACCOUNT_TYPE AS ACCOUNT_TYPE 
            WITH SYNONYMS=('customer type','account category') 
            COMMENT='Type of customer account',
        PUBLIC ACCOUNTS.ANNUAL_REVENUE AS ANNUAL_REVENUE 
            WITH SYNONYMS=('customer revenue','company revenue') 
            COMMENT='Customer annual revenue',
        PUBLIC ACCOUNTS.EMPLOYEES AS EMPLOYEES 
            WITH SYNONYMS=('company size','employee count') 
            COMMENT='Number of employees at customer',
        PUBLIC ACCOUNTS.INDUSTRY AS INDUSTRY 
            WITH SYNONYMS=('industry','sector') 
            COMMENT='Customer industry',
        PUBLIC ACCOUNTS.SALES_CUSTOMER_KEY AS CUSTOMER_KEY 
            WITH SYNONYMS=('Customer No','Customer ID') 
            COMMENT='This is the customer key that links the Salesforce account to customers table.',
            
        -- Campaign dimensions
        PUBLIC CAMPAIGNS.CAMPAIGN_DATE AS date 
            WITH SYNONYMS=('date','campaign date') 
            COMMENT='Date of the campaign activity',
        PUBLIC CAMPAIGNS.CAMPAIGN_FACT_ID AS CAMPAIGN_FACT_ID,
        PUBLIC CAMPAIGNS.CAMPAIGN_KEY AS CAMPAIGN_KEY,
        PUBLIC CAMPAIGNS.CAMPAIGN_MONTH AS MONTH(date) 
            COMMENT='Month of the campaign',
        PUBLIC CAMPAIGNS.CAMPAIGN_YEAR AS YEAR(date) 
            COMMENT='Year of the campaign',
        PUBLIC CAMPAIGNS.CHANNEL_KEY AS CHANNEL_KEY,
        PUBLIC CAMPAIGNS.PRODUCT_KEY AS PRODUCT_KEY 
            WITH SYNONYMS=('product_id','product identifier') 
            COMMENT='Product identifier for campaign targeting',
        PUBLIC CAMPAIGNS.REGION_KEY AS REGION_KEY,
        
        -- Campaign detail dimensions
        PUBLIC CAMPAIGN_DETAILS.CAMPAIGN_KEY AS CAMPAIGN_KEY,
        PUBLIC CAMPAIGN_DETAILS.CAMPAIGN_NAME AS CAMPAIGN_NAME 
            WITH SYNONYMS=('campaign','campaign title') 
            COMMENT='Name of the marketing campaign',
        PUBLIC CAMPAIGN_DETAILS.CAMPAIGN_OBJECTIVE AS OBJECTIVE 
            WITH SYNONYMS=('objective','goal','purpose') 
            COMMENT='Campaign objective',
            
        -- Channel dimensions
        PUBLIC CHANNELS.CHANNEL_KEY AS CHANNEL_KEY,
        PUBLIC CHANNELS.CHANNEL_NAME AS CHANNEL_NAME 
            WITH SYNONYMS=('channel','marketing channel') 
            COMMENT='Name of the marketing channel',
            
        -- Contact dimensions
        PUBLIC CONTACTS.ACCOUNT_ID AS ACCOUNT_ID,
        PUBLIC CONTACTS.CAMPAIGN_NO AS CAMPAIGN_NO,
        PUBLIC CONTACTS.CONTACT_ID AS CONTACT_ID,
        PUBLIC CONTACTS.DEPARTMENT AS DEPARTMENT 
            WITH SYNONYMS=('department','business unit') 
            COMMENT='Contact department',
        PUBLIC CONTACTS.EMAIL AS EMAIL 
            WITH SYNONYMS=('email','email address') 
            COMMENT='Contact email address',
        PUBLIC CONTACTS.FIRST_NAME AS FIRST_NAME 
            WITH SYNONYMS=('first name','contact name') 
            COMMENT='Contact first name',
        PUBLIC CONTACTS.LAST_NAME AS LAST_NAME 
            WITH SYNONYMS=('last name','surname') 
            COMMENT='Contact last name',
        PUBLIC CONTACTS.LEAD_SOURCE AS LEAD_SOURCE 
            WITH SYNONYMS=('lead source','source') 
            COMMENT='How the contact was generated',
        PUBLIC CONTACTS.OPPORTUNITY_ID AS OPPORTUNITY_ID,
        PUBLIC CONTACTS.TITLE AS TITLE 
            WITH SYNONYMS=('job title','position') 
            COMMENT='Contact job title',
            
        -- Opportunity dimensions
        PUBLIC OPPORTUNITIES.ACCOUNT_ID AS ACCOUNT_ID,
        PUBLIC OPPORTUNITIES.CAMPAIGN_ID AS CAMPAIGN_ID 
            WITH SYNONYMS=('campaign fact id','marketing campaign id') 
            COMMENT='Campaign fact ID that links opportunity to marketing campaign',
        PUBLIC OPPORTUNITIES.CLOSE_DATE AS CLOSE_DATE 
            WITH SYNONYMS=('close date','expected close') 
            COMMENT='Expected or actual close date',
        PUBLIC OPPORTUNITIES.OPPORTUNITY_ID AS OPPORTUNITY_ID,
        PUBLIC OPPORTUNITIES.OPPORTUNITY_LEAD_SOURCE AS lead_source 
            WITH SYNONYMS=('opportunity source','deal source') 
            COMMENT='Source of the opportunity',
        PUBLIC OPPORTUNITIES.OPPORTUNITY_NAME AS OPPORTUNITY_NAME 
            WITH SYNONYMS=('deal name','opportunity title') 
            COMMENT='Name of the sales opportunity',
        PUBLIC OPPORTUNITIES.OPPORTUNITY_STAGE AS STAGE_NAME 
            COMMENT='Stage name of the opportunity. Closed Won indicates an actual sale with revenue',
        PUBLIC OPPORTUNITIES.OPPORTUNITY_TYPE AS TYPE 
            WITH SYNONYMS=('deal type','opportunity type') 
            COMMENT='Type of opportunity',
        PUBLIC OPPORTUNITIES.SALES_SALE_ID AS SALE_ID 
            WITH SYNONYMS=('sales id','invoice no') 
            COMMENT='Sales_ID for sales_fact table that links this opp to a sales record.',
            
        -- Product dimensions
        PUBLIC PRODUCTS.PRODUCT_CATEGORY AS CATEGORY_NAME 
            WITH SYNONYMS=('category','product category') 
            COMMENT='Category of the product',
        PUBLIC PRODUCTS.PRODUCT_KEY AS PRODUCT_KEY,
        PUBLIC PRODUCTS.PRODUCT_NAME AS PRODUCT_NAME 
            WITH SYNONYMS=('product','item','product title') 
            COMMENT='Name of the product being promoted',
        PUBLIC PRODUCTS.PRODUCT_VERTICAL AS VERTICAL 
            WITH SYNONYMS=('vertical','industry') 
            COMMENT='Business vertical of the product',
            
        -- Region dimensions
        PUBLIC REGIONS.REGION_KEY AS REGION_KEY,
        PUBLIC REGIONS.REGION_NAME AS REGION_NAME 
            WITH SYNONYMS=('region','market','territory') 
            COMMENT='Name of the region'
    )
    
    METRICS (
        PUBLIC CAMPAIGNS.AVERAGE_SPEND AS AVG(CAMPAIGNS.spend) 
            COMMENT='Average campaign spend',
        PUBLIC CAMPAIGNS.TOTAL_CAMPAIGNS AS COUNT(CAMPAIGNS.campaign_record) 
            COMMENT='Total number of campaign activities',
        PUBLIC CAMPAIGNS.TOTAL_IMPRESSIONS AS SUM(CAMPAIGNS.impressions) 
            COMMENT='Total impressions across campaigns',
        PUBLIC CAMPAIGNS.TOTAL_LEADS AS SUM(CAMPAIGNS.leads_generated) 
            COMMENT='Total leads generated from campaigns',
        PUBLIC CAMPAIGNS.TOTAL_SPEND AS SUM(CAMPAIGNS.spend) 
            COMMENT='Total marketing spend',
        PUBLIC CONTACTS.TOTAL_CONTACTS AS COUNT(CONTACTS.contact_record) 
            COMMENT='Total contacts generated from campaigns',
        PUBLIC OPPORTUNITIES.AVERAGE_DEAL_SIZE AS AVG(OPPORTUNITIES.revenue) 
            COMMENT='Average opportunity size from marketing',
        PUBLIC OPPORTUNITIES.CLOSED_WON_REVENUE AS SUM(CASE WHEN OPPORTUNITIES.opportunity_stage = 'Closed Won' THEN OPPORTUNITIES.revenue ELSE 0 END) 
            COMMENT='Revenue from closed won opportunities',
        PUBLIC OPPORTUNITIES.TOTAL_OPPORTUNITIES AS COUNT(OPPORTUNITIES.opportunity_record) 
            COMMENT='Total opportunities from marketing',
        PUBLIC OPPORTUNITIES.TOTAL_REVENUE AS SUM(OPPORTUNITIES.revenue) 
            COMMENT='Total revenue from marketing-driven opportunities'
    )
    
    COMMENT='Enhanced semantic view for marketing campaign analysis with complete revenue attribution and ROI tracking'
    
    WITH EXTENSION (CA='{"tables":[{"name":"ACCOUNTS","dimensions":[{"name":"ACCOUNT_ID"},{"name":"ACCOUNT_NAME"},{"name":"ACCOUNT_TYPE"},{"name":"ANNUAL_REVENUE"},{"name":"EMPLOYEES"},{"name":"INDUSTRY"},{"name":"SALES_CUSTOMER_KEY"}]},{"name":"CAMPAIGNS","dimensions":[{"name":"CAMPAIGN_DATE"},{"name":"CAMPAIGN_FACT_ID"},{"name":"CAMPAIGN_KEY"},{"name":"CAMPAIGN_MONTH"},{"name":"CAMPAIGN_YEAR"},{"name":"CHANNEL_KEY"},{"name":"PRODUCT_KEY"},{"name":"REGION_KEY"}],"facts":[{"name":"CAMPAIGN_RECORD"},{"name":"CAMPAIGN_SPEND"},{"name":"IMPRESSIONS"},{"name":"LEADS_GENERATED"}],"metrics":[{"name":"AVERAGE_SPEND"},{"name":"TOTAL_CAMPAIGNS"},{"name":"TOTAL_IMPRESSIONS"},{"name":"TOTAL_LEADS"},{"name":"TOTAL_SPEND"}]},{"name":"CAMPAIGN_DETAILS","dimensions":[{"name":"CAMPAIGN_KEY"},{"name":"CAMPAIGN_NAME"},{"name":"CAMPAIGN_OBJECTIVE"}]},{"name":"CHANNELS","dimensions":[{"name":"CHANNEL_KEY"},{"name":"CHANNEL_NAME"}]},{"name":"CONTACTS","dimensions":[{"name":"ACCOUNT_ID"},{"name":"CAMPAIGN_NO"},{"name":"CONTACT_ID"},{"name":"DEPARTMENT"},{"name":"EMAIL"},{"name":"FIRST_NAME"},{"name":"LAST_NAME"},{"name":"LEAD_SOURCE"},{"name":"OPPORTUNITY_ID"},{"name":"TITLE"}],"facts":[{"name":"CONTACT_RECORD"}],"metrics":[{"name":"TOTAL_CONTACTS"}]},{"name":"CONTACTS_FOR_OPPORTUNITIES"},{"name":"OPPORTUNITIES","dimensions":[{"name":"ACCOUNT_ID"},{"name":"CAMPAIGN_ID"},{"name":"CLOSE_DATE"},{"name":"OPPORTUNITY_ID"},{"name":"OPPORTUNITY_LEAD_SOURCE"},{"name":"OPPORTUNITY_NAME"},{"name":"OPPORTUNITY_STAGE","sample_values":["Closed Won","Perception Analysis","Qualification"]},{"name":"OPPORTUNITY_TYPE"},{"name":"SALES_SALE_ID"}],"facts":[{"name":"OPPORTUNITY_RECORD"},{"name":"REVENUE"}],"metrics":[{"name":"AVERAGE_DEAL_SIZE"},{"name":"CLOSED_WON_REVENUE"},{"name":"TOTAL_OPPORTUNITIES"},{"name":"TOTAL_REVENUE"}]},{"name":"PRODUCTS","dimensions":[{"name":"PRODUCT_CATEGORY"},{"name":"PRODUCT_KEY"},{"name":"PRODUCT_NAME"},{"name":"PRODUCT_VERTICAL"}]},{"name":"REGIONS","dimensions":[{"name":"REGION_KEY"},{"name":"REGION_NAME"}]}],"relationships":[{"name":"CAMPAIGNS_TO_CHANNELS","relationship_type":"many_to_one"},{"name":"CAMPAIGNS_TO_DETAILS","relationship_type":"many_to_one"},{"name":"CAMPAIGNS_TO_PRODUCTS","relationship_type":"many_to_one"},{"name":"CAMPAIGNS_TO_REGIONS","relationship_type":"many_to_one"},{"name":"CONTACTS_TO_ACCOUNTS","relationship_type":"many_to_one"},{"name":"CONTACTS_TO_CAMPAIGNS","relationship_type":"many_to_one"},{"name":"CONTACTS_TO_OPPORTUNITIES","relationship_type":"many_to_one"},{"name":"OPPORTUNITIES_TO_ACCOUNTS","relationship_type":"many_to_one"},{"name":"OPPORTUNITIES_TO_CAMPAIGNS"}],"verified_queries":[{"name":"include opps that turned in to sales deal","question":"include opps that turned in to sales deal","sql":"WITH campaign_impressions AS (\\n  SELECT\\n    c.campaign_key,\\n    cd.campaign_name,\\n    SUM(c.impressions) AS total_impressions\\n  FROM\\n    campaigns AS c\\n    LEFT OUTER JOIN campaign_details AS cd ON c.campaign_key = cd.campaign_key\\n  WHERE\\n    c.campaign_year = 2025\\n  GROUP BY\\n    c.campaign_key,\\n    cd.campaign_name\\n),\\ncampaign_opportunities AS (\\n  SELECT\\n    c.campaign_key,\\n    COUNT(o.opportunity_record) AS total_opportunities,\\n    COUNT(\\n      CASE\\n        WHEN o.opportunity_stage = ''Closed Won'' THEN o.opportunity_record\\n      END\\n    ) AS closed_won_opportunities\\n  FROM\\n    campaigns AS c\\n    LEFT OUTER JOIN opportunities AS o ON c.campaign_fact_id = o.campaign_id\\n  WHERE\\n    c.campaign_year = 2025\\n  GROUP BY\\n    c.campaign_key\\n)\\nSELECT\\n  ci.campaign_name,\\n  ci.total_impressions,\\n  COALESCE(co.total_opportunities, 0) AS total_opportunities,\\n  COALESCE(co.closed_won_opportunities, 0) AS closed_won_opportunities\\nFROM\\n  campaign_impressions AS ci\\n  LEFT JOIN campaign_opportunities AS co ON ci.campaign_key = co.campaign_key\\nORDER BY\\n  ci.total_impressions DESC NULLS LAST","use_as_onboarding_question":false,"verified_by":"Nick Akincilar","verified_at":1757262696}]}');


-- ============================================================================
-- FINANCE SEMANTIC VIEW
-- Purpose: Enable natural language queries about financial transactions and budgets
-- ============================================================================

CREATE OR REPLACE SEMANTIC VIEW sales_db.shared_data.FINANCE_SEMANTIC_VIEW
    TABLES (
        TRANSACTIONS AS SHARED_SNOW_XCLOUD_FINANCE.SNOW_DATA.FINANCE_TRANSACTIONS 
            PRIMARY KEY (TRANSACTION_ID) 
            WITH SYNONYMS=('finance transactions','financial data') 
            COMMENT='All financial transactions across departments',
            
        ACCOUNTS AS SHARED_SNOW_XCLOUD_FINANCE.SNOW_DATA.ACCOUNT_DIM 
            PRIMARY KEY (ACCOUNT_KEY) 
            WITH SYNONYMS=('chart of accounts','account types') 
            COMMENT='Account dimension for financial categorization',
            
        DEPARTMENTS AS SHARED_SNOW_XCLOUD_FINANCE.SNOW_DATA.DEPARTMENT_DIM 
            PRIMARY KEY (DEPARTMENT_KEY) 
            WITH SYNONYMS=('business units','departments') 
            COMMENT='Department dimension for cost center analysis',
            
        VENDORS AS SHARED_SNOW_XCLOUD_FINANCE.SNOW_DATA.VENDOR_DIM 
            PRIMARY KEY (VENDOR_KEY) 
            WITH SYNONYMS=('suppliers','vendors') 
            COMMENT='Vendor information for spend analysis',
            
        PRODUCTS AS SHARED_SNOW_XCLOUD_FINANCE.SNOW_DATA.PRODUCT_DIM 
            PRIMARY KEY (PRODUCT_KEY) 
            WITH SYNONYMS=('products','items') 
            COMMENT='Product dimension for transaction analysis',
            
        CUSTOMERS AS SHARED_SNOW_XCLOUD_FINANCE.SNOW_DATA.CUSTOMER_DIM 
            PRIMARY KEY (CUSTOMER_KEY) 
            WITH SYNONYMS=('clients','customers') 
            COMMENT='Customer dimension for revenue analysis'
    )
    
    RELATIONSHIPS (
        TRANSACTIONS_TO_ACCOUNTS AS TRANSACTIONS(ACCOUNT_KEY) REFERENCES ACCOUNTS(ACCOUNT_KEY),
        TRANSACTIONS_TO_DEPARTMENTS AS TRANSACTIONS(DEPARTMENT_KEY) REFERENCES DEPARTMENTS(DEPARTMENT_KEY),
        TRANSACTIONS_TO_VENDORS AS TRANSACTIONS(VENDOR_KEY) REFERENCES VENDORS(VENDOR_KEY),
        TRANSACTIONS_TO_PRODUCTS AS TRANSACTIONS(PRODUCT_KEY) REFERENCES PRODUCTS(PRODUCT_KEY),
        TRANSACTIONS_TO_CUSTOMERS AS TRANSACTIONS(CUSTOMER_KEY) REFERENCES CUSTOMERS(CUSTOMER_KEY)
    )
    
    FACTS (
        TRANSACTIONS.TRANSACTION_AMOUNT AS amount 
            COMMENT='Transaction amount in dollars',
        TRANSACTIONS.TRANSACTION_RECORD AS 1 
            COMMENT='Count of transactions'
    )
    
    DIMENSIONS (
        TRANSACTIONS.TRANSACTION_DATE AS date 
            WITH SYNONYMS=('date','transaction date') 
            COMMENT='Date of the financial transaction',
        TRANSACTIONS.TRANSACTION_MONTH AS MONTH(date) 
            COMMENT='Month of the transaction',
        TRANSACTIONS.TRANSACTION_YEAR AS YEAR(date) 
            COMMENT='Year of the transaction',
        ACCOUNTS.ACCOUNT_NAME AS account_name 
            WITH SYNONYMS=('account','account type') 
            COMMENT='Name of the account',
        ACCOUNTS.ACCOUNT_TYPE AS account_type 
            WITH SYNONYMS=('type','category') 
            COMMENT='Type of account (Income/Expense)',
        DEPARTMENTS.DEPARTMENT_NAME AS department_name 
            WITH SYNONYMS=('department','business unit') 
            COMMENT='Name of the department',
        VENDORS.VENDOR_NAME AS vendor_name 
            WITH SYNONYMS=('vendor','supplier') 
            COMMENT='Name of the vendor',
        PRODUCTS.PRODUCT_NAME AS product_name 
            WITH SYNONYMS=('product','item') 
            COMMENT='Name of the product',
        CUSTOMERS.CUSTOMER_NAME AS customer_name 
            WITH SYNONYMS=('customer','client') 
            COMMENT='Name of the customer'
    )
    
    METRICS (
        TRANSACTIONS.AVERAGE_AMOUNT AS AVG(transactions.amount) 
            COMMENT='Average transaction amount',
        TRANSACTIONS.TOTAL_AMOUNT AS SUM(transactions.amount) 
            COMMENT='Total transaction amount',
        TRANSACTIONS.TOTAL_TRANSACTIONS AS COUNT(transactions.transaction_record) 
            COMMENT='Total number of transactions'
    )
    
    COMMENT='Semantic view for financial analysis and reporting';
*/


/*******************************************************************************
 * SECTION 9: MOUNT DATA PRODUCTS FOR DEMO
 * 
 * Pre-run SQL commands to mount all necessary data products before
 * creating the AI agent
 ******************************************************************************/

/*
USE ROLE sales_domain_role;

-- Mount all required data products from organization listings
CREATE OR REPLACE DATABASE shared_delta_xregion_hr 
    FROM LISTING ORGDATACLOUD$INTERNAL$HR_DATA_PRODUCT;

CREATE OR REPLACE DATABASE shared_iceberg_xregion_marketing 
    FROM LISTING ORGDATACLOUD$INTERNAL$MARKETING_DATA_PRODUCT;

CREATE OR REPLACE DATABASE shared_snow_xcloud_finance 
    FROM LISTING ORGDATACLOUD$INTERNAL$FINANCE_DATA_PRODUCT;

CREATE OR REPLACE DATABASE shared_cke_unstructured_xregion_enterprise 
    FROM LISTING ORGDATACLOUD$INTERNAL$ENTERPRISE_DATA_PRODUCT;
*/


/*******************************************************************************
 * SECTION 10: CREATE SNOWFLAKE INTELLIGENCE AGENT
 * 
 * Create a multi-domain AI agent that can:
 * - Query structured data across Sales, Marketing, HR, and Finance domains
 * - Search unstructured documents using Cortex Search
 * - Scrape and analyze web content
 * - Send email reports to verified recipients
 * - Generate presigned URLs for document access
 * 
 * The agent uses Cortex Analyst for text-to-SQL and Cortex Search for
 * semantic search across unstructured data
 ******************************************************************************/

USE ROLE sales_domain_role;

CREATE OR REPLACE AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.Company_Chatbot_Agent_Retail
WITH PROFILE='{ "display_name": "1-Company Chatbot Agent - Retail" }'
    COMMENT=$$ This is an agent that can answer questions about company specific Sales, Marketing, HR & Finance questions. $$
FROM SPECIFICATION $$
{
  "models": {
    "orchestration": ""
  },
  
  "instructions": {
    -- Primary behavior: Act as a data analyst with access to multiple domains
    "response": "You are a data analyst who has access to sales, finance, marketing & HR datamarts. If user does not specify a date range assume it for year 2025. Leverage data from all domains to analyse & answer user questions. Provide visualizations if possible. Trendlines should default to linecharts, Categories Barchart.",
    
    -- Orchestration strategy: Combine Cortex Search with Cortex Analyst
    "orchestration": "Use cortex search for known entities and pass the results to cortex analyst for detailed analysis.\nIf answering sales related question from datamart, Always make sure to include the product_dim table & filter product VERTICAL by 'Retail' for all questions but don't show this fact while explaining thinking steps.\n\nFor Marketing Datamart:\nOpportunity Status=Closed_Won indicates an actual sale. \nSalesID in marketing datamart links an opportunity to a Sales record in Sales Datamart SalesID columns\n\n\n",
    
    -- Sample questions to demonstrate capabilities
    "sample_questions": [
      {
        "question": "What are our monthly sales last 12 months?"
      },
      {
        "question": "Why was a big increase from May to June?"
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
    -- =========================================================================
    -- CORTEX ANALYST TOOLS (Text-to-SQL for structured data)
    -- =========================================================================
    
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
        "description": "Allows users to query Sales data for a company in terms of Sales data such as products, sales reps & etc."
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
    
    -- =========================================================================
    -- CORTEX SEARCH TOOLS (Semantic search for unstructured data)
    -- =========================================================================
    
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
    
    -- =========================================================================
    -- GENERIC TOOLS (Custom stored procedures and functions)
    -- =========================================================================
    
    {
      "tool_spec": {
        "type": "generic",
        "name": "Web_scraper",
        "description": "This tool should be used if the user wants to analyse contents of a given web page. This tool will use a web url (https or https) as input and will return the text content of that web page for further analysis",
        "input_schema": {
          "type": "object",
          "properties": {
            "weburl": {
              "description": "Agent should ask web url (that includes http:// or https://). It will scrape text from the given url and return as a result.",
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
  
  -- ===========================================================================
  -- TOOL RESOURCES (Connect tools to their implementations)
  -- ===========================================================================
  
  "tool_resources": {
    -- Generic tool implementations (stored procedures/functions)
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
    
    -- Cortex Analyst tool implementations (semantic views)
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
    
    -- Cortex Search tool implementations (search services)
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
    
    -- Email tool implementation
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
    
    -- Web scraper tool implementation
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


/*******************************************************************************
 * END OF SCRIPT
 * 
 * Summary:
 * This script demonstrates a complete implementation of:
 * 1. Domain-oriented data architecture with proper RBAC
 * 2. Data product creation and publishing to internal marketplace
 * 3. Cross-cloud and cross-region data sharing
 * 4. Semantic views for AI-powered natural language querying
 * 5. Multi-domain AI agent with access to structured and unstructured data
 * 
 * Key Snowflake Features Used:
 * - Secure Data Sharing
 * - Organization Listings
 * - Auto-fulfillment
 * - Semantic Views
 * - Cortex Analyst (Text-to-SQL)
 * - Cortex Search (Semantic Search)
 * - Snowflake Intelligence (AI Agents)
 * - External Access Integration
 * - Snowpark Stored Procedures
 * 
 * For questions or support, contact: amit.gupta@snowflake.com
 ******************************************************************************/

