/*
================================================================================
HORIZON CATALOG -  SEMANTIC VIEW + SEMANTIC SHARING w/ LISTINGS (XREGION, XCLOUD)
================================================================================
Purpose: Create AI-ready semantic views for HR and Marketing data products
Description: This script creates semantic views that provide business-friendly
             interfaces to underlying data lakes (Databricks Delta & Apache Iceberg).
             Semantic views enable natural language queries and self-service analytics
             by defining business terminology, relationships, and pre-calculated metrics.

Contents:
  1. HR Semantic View - HR analytics on Databricks Delta data
  2. Marketing Semantic View - Marketing campaign analysis on Apache Iceberg data

Author: Amit Gupta
Last Updated: October 15, 2025
Demo: Available at Interoperable Data Mesh Webinar - https://www.snowflake.com/en/webinars/demo/unlocking-ai-with-an-interoperable-data-mesh-2025-10-16/
 
================================================================================
*/


-- ============================================================================
-- SECTION 1: HR SEMANTIC VIEW ON DATABRICKS DELTA DATA
-- ============================================================================
-- Purpose: Creates a semantic layer over HR data stored in Databricks Delta format
-- Use Case: Enables natural language queries about employees, departments,
--           jobs, locations, and attrition analysis
-- ============================================================================

-- Switch to HR domain role and schema context
USE ROLE hr_domain_role;
USE SCHEMA hr_db.dbrix_deltadirect_data;

-- Clean up any existing semantic view before creating new one
DROP SEMANTIC VIEW IF EXISTS HR_SEMANTIC_VIEW;

CREATE OR REPLACE SEMANTIC VIEW HR_SEMANTIC_VIEW
    
    -- ========================================================================
    -- TABLES SECTION
    -- ========================================================================
    -- Define the underlying tables with business-friendly aliases and synonyms
    -- This allows users to reference tables using common business terminology
    -- ========================================================================
    TABLES (
        -- Department master data - organizational structure
        DEPARTMENTS AS DEPARTMENT_DIM 
            PRIMARY KEY (DEPARTMENT_KEY) 
            WITH SYNONYMS=('departments','business units') 
            COMMENT='Department dimension for organizational analysis',
            
        -- Employee master data - workforce information
        EMPLOYEES AS EMPLOYEE_DIM 
            PRIMARY KEY (EMPLOYEE_KEY) 
            WITH SYNONYMS=('employees','staff','workforce') 
            COMMENT='Employee dimension with personal information',
            
        -- HR fact table - core employee records with salary and attrition data
        HR_RECORDS AS HR_EMPLOYEE_FACT 
            PRIMARY KEY (HR_FACT_ID) 
            WITH SYNONYMS=('hr data','employee records') 
            COMMENT='HR employee fact data for workforce analysis',
            
        -- Job master data - position and title information
        JOBS AS JOB_DIM 
            PRIMARY KEY (JOB_KEY) 
            WITH SYNONYMS=('job titles','positions','roles') 
            COMMENT='Job dimension with titles and levels',
            
        -- Location master data - geographic/office information
        LOCATIONS AS LOCATION_DIM 
            PRIMARY KEY (LOCATION_KEY) 
            WITH SYNONYMS=('locations','offices','sites') 
            COMMENT='Location dimension for geographic analysis'
    )
    
    -- ========================================================================
    -- RELATIONSHIPS SECTION
    -- ========================================================================
    -- Define how tables connect to each other (foreign key relationships)
    -- This enables the semantic view to automatically generate proper joins
    -- ========================================================================
    RELATIONSHIPS (
        -- HR_RECORDS connects to DEPARTMENTS via department_key
        HR_TO_DEPARTMENTS AS HR_RECORDS(DEPARTMENT_KEY) REFERENCES DEPARTMENTS(DEPARTMENT_KEY),
        
        -- HR_RECORDS connects to EMPLOYEES via employee_key
        HR_TO_EMPLOYEES AS HR_RECORDS(EMPLOYEE_KEY) REFERENCES EMPLOYEES(EMPLOYEE_KEY),
        
        -- HR_RECORDS connects to JOBS via job_key
        HR_TO_JOBS AS HR_RECORDS(JOB_KEY) REFERENCES JOBS(JOB_KEY),
        
        -- HR_RECORDS connects to LOCATIONS via location_key
        HR_TO_LOCATIONS AS HR_RECORDS(LOCATION_KEY) REFERENCES LOCATIONS(LOCATION_KEY)
    )
    
    -- ========================================================================
    -- FACTS SECTION
    -- ========================================================================
    -- Define measurable numeric values that can be aggregated
    -- These are the "numbers" that users want to analyze
    -- ========================================================================
    FACTS (
        -- Attrition indicator: 0 = active employee, 1 = employee has left
        -- Important: Default behavior should filter to active employees (0) unless specified
        HR_RECORDS.ATTRITION_FLAG AS attrition_flag 
            WITH SYNONYMS=('turnover_indicator','employee_departure_flag','separation_flag','employee_retention_status','churn_status','employee_exit_indicator') 
            COMMENT='Attrition flag. Value is 0 if employee is currently active, 1 if employee quit & left the company. Always filter by 0 to show active employees unless specified otherwise',
            
        -- Record counter - used to count number of employee records
        HR_RECORDS.EMPLOYEE_RECORD AS 1 
            COMMENT='Count of employee records',
            
        -- Salary amount in dollars - can be summed, averaged, etc.
        HR_RECORDS.EMPLOYEE_SALARY AS salary 
            COMMENT='Employee salary in dollars'
    )
    
    -- ========================================================================
    -- DIMENSIONS SECTION
    -- ========================================================================
    -- Define attributes used for filtering, grouping, and detailed analysis
    -- These are the "descriptive" fields (text, dates, categories)
    -- ========================================================================
    DIMENSIONS (
        -- ====================================================================
        -- DEPARTMENT DIMENSIONS
        -- ====================================================================
        DEPARTMENTS.DEPARTMENT_KEY AS DEPARTMENT_KEY,
        DEPARTMENTS.DEPARTMENT_NAME AS department_name 
            WITH SYNONYMS=('department','business unit','division') 
            COMMENT='Name of the department',
            
        -- ====================================================================
        -- EMPLOYEE DIMENSIONS
        -- ====================================================================
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
            
        -- ====================================================================
        -- HR RECORD DIMENSIONS (from fact table)
        -- ====================================================================
        HR_RECORDS.DEPARTMENT_KEY AS DEPARTMENT_KEY,
        HR_RECORDS.EMPLOYEE_KEY AS EMPLOYEE_KEY,
        HR_RECORDS.HR_FACT_ID AS HR_FACT_ID,
        HR_RECORDS.JOB_KEY AS JOB_KEY,
        HR_RECORDS.LOCATION_KEY AS LOCATION_KEY,
        
        -- Time-based dimensions for temporal analysis
        HR_RECORDS.RECORD_DATE AS date 
            WITH SYNONYMS=('date','record date') 
            COMMENT='Date of the HR record',
        HR_RECORDS.RECORD_MONTH AS MONTH(date) 
            COMMENT='Month of the HR record',
        HR_RECORDS.RECORD_YEAR AS YEAR(date) 
            COMMENT='Year of the HR record',
            
        -- ====================================================================
        -- JOB DIMENSIONS
        -- ====================================================================
        JOBS.JOB_KEY AS JOB_KEY,
        JOBS.JOB_LEVEL AS job_level 
            WITH SYNONYMS=('level','grade','seniority') 
            COMMENT='Job level or grade',
        JOBS.JOB_TITLE AS job_title 
            WITH SYNONYMS=('job title','position','role') 
            COMMENT='Employee job title',
            
        -- ====================================================================
        -- LOCATION DIMENSIONS
        -- ====================================================================
        LOCATIONS.LOCATION_KEY AS LOCATION_KEY,
        LOCATIONS.LOCATION_NAME AS location_name 
            WITH SYNONYMS=('location','office','site') 
            COMMENT='Work location'
    )
    
    -- ========================================================================
    -- METRICS SECTION
    -- ========================================================================
    -- Define pre-calculated aggregations for common business questions
    -- These are ready-to-use KPIs that combine facts with aggregate functions
    -- ========================================================================
    METRICS (
        -- Total number of employees who have left the organization
        HR_RECORDS.ATTRITION_COUNT AS SUM(hr_records.attrition_flag) 
            COMMENT='Number of employees who left',
        
        -- Average salary across employees
        HR_RECORDS.AVG_SALARY AS AVG(hr_records.employee_salary) 
            COMMENT='Average employee salary',
        
        -- Total employee count
        HR_RECORDS.TOTAL_EMPLOYEES AS COUNT(hr_records.employee_record) 
            COMMENT='Total number of employees',
        
        -- Total salary expenditure
        HR_RECORDS.TOTAL_SALARY_COST AS SUM(hr_records.EMPLOYEE_SALARY) 
            COMMENT='Total salary cost'
    )
    
    COMMENT='Semantic view for HR analytics and workforce management'
    
    -- ========================================================================
    -- CORTEX ANALYST EXTENSION
    -- ========================================================================
    -- Extended metadata for AI-powered analytics and BI tool integration
    -- Includes sample values and verified queries for better AI understanding
    -- ========================================================================
    WITH EXTENSION (
        CA='{"tables":[{"name":"DEPARTMENTS","dimensions":[{"name":"DEPARTMENT_KEY"},{"name":"DEPARTMENT_NAME","sample_values":["Finance","Accounting","Treasury"]}]},{"name":"EMPLOYEES","dimensions":[{"name":"EMPLOYEE_KEY"},{"name":"EMPLOYEE_NAME","sample_values":["Grant Frey","Elizabeth George","Olivia Mcdaniel"]},{"name":"GENDER"},{"name":"HIRE_DATE"}]},{"name":"HR_RECORDS","dimensions":[{"name":"DEPARTMENT_KEY"},{"name":"EMPLOYEE_KEY"},{"name":"HR_FACT_ID"},{"name":"JOB_KEY"},{"name":"LOCATION_KEY"},{"name":"RECORD_DATE"},{"name":"RECORD_MONTH"},{"name":"RECORD_YEAR"}],"facts":[{"name":"ATTRITION_FLAG","sample_values":["0","1"]},{"name":"EMPLOYEE_RECORD"},{"name":"EMPLOYEE_SALARY"}],"metrics":[{"name":"ATTRITION_COUNT"},{"name":"AVG_SALARY"},{"name":"TOTAL_EMPLOYEES"},{"name":"TOTAL_SALARY_COST"}]},{"name":"JOBS","dimensions":[{"name":"JOB_KEY"},{"name":"JOB_LEVEL"},{"name":"JOB_TITLE"}]},{"name":"LOCATIONS","dimensions":[{"name":"LOCATION_KEY"},{"name":"LOCATION_NAME"}]}],"relationships":[{"name":"HR_TO_DEPARTMENTS","relationship_type":"many_to_one"},{"name":"HR_TO_EMPLOYEES","relationship_type":"many_to_one"},{"name":"HR_TO_JOBS","relationship_type":"many_to_one"},{"name":"HR_TO_LOCATIONS","relationship_type":"many_to_one"}],"verified_queries":[{"name":"List of all active employees","question":"List of all active employees","sql":"select\\n  h.employee_key,\\n  e.employee_name,\\nfrom\\n  employees e\\n  left join hr_records h on e.employee_key = h.employee_key\\ngroup by\\n  all\\nhaving\\n  sum(h.attrition_flag) = 0;","use_as_onboarding_question":false,"verified_by":"Nick Akincilar","verified_at":1753846263},{"name":"List of all inactive employees","question":"List of all inactive employees","sql":"SELECT\\n  h.employee_key,\\n  e.employee_name\\nFROM\\n  employees AS e\\n  LEFT JOIN hr_records AS h ON e.employee_key = h.employee_key\\nGROUP BY\\n  ALL\\nHAVING\\n  SUM(h.attrition_flag) > 0","use_as_onboarding_question":false,"verified_by":"Nick Akincilar","verified_at":1753846300}],"custom_instructions":"- Each employee can have multiple hr_employee_fact records. \\n- Only one hr_employee_fact record per employee is valid and that is the one which has the highest date value."}'
    );


-- ============================================================================
-- HR SEMANTIC VIEW TESTING AND VALIDATION
-- ============================================================================
-- These commands verify the semantic view was created correctly
-- ============================================================================

USE SCHEMA hr_db.dbrix_deltadirect_data;

-- Display all semantic views in the current schema
SHOW SEMANTIC VIEWS;

-- List all dimensions available in semantic views
SHOW SEMANTIC DIMENSIONS;

-- List all pre-calculated metrics in semantic views
SHOW SEMANTIC METRICS; 

-- Switch to appropriate warehouse for query execution
USE WAREHOUSE hr_wh;

-- Test query: Retrieve data using the semantic view interface
-- This demonstrates how to query semantic views with specific dimensions
SELECT * FROM SEMANTIC_VIEW(
    HR_DB.DBRIX_DELTADIRECT_DATA.HR_SEMANTIC_VIEW
    DIMENSIONS EMPLOYEES.EMPLOYEE_KEY
);


-- ============================================================================
-- SHARE SEMANTIC VIEW IN DATA PRODUCT
-- ============================================================================
-- Grant access to semantic views in the HR data share
-- This makes the HR data product AI-ready for consumers
-- ============================================================================
GRANT SELECT ON ALL SEMANTIC VIEWS IN SCHEMA hr_db.dbrix_deltadirect_data TO SHARE hr_data_share;



-- ============================================================================
-- SECTION 2: MARKETING SEMANTIC VIEW ON APACHE ICEBERG DATA
-- ============================================================================
-- Purpose: Creates a semantic layer over marketing data stored in Apache Iceberg format
-- Use Case: Enables natural language queries about marketing campaigns,
--           leads, opportunities, revenue attribution, and ROI analysis
-- ============================================================================

-- Switch to Marketing domain role and schema context
USE ROLE marketing_domain_role;
USE SCHEMA marketing_db.iceberg_data;

CREATE OR REPLACE SEMANTIC VIEW MARKETING_SEMANTIC_VIEW
    
    -- ========================================================================
    -- TABLES SECTION
    -- ========================================================================
    -- Define marketing data model with campaign, lead, opportunity, and revenue tracking
    -- ========================================================================
    TABLES (
        -- Customer account master data (from Salesforce)
        ACCOUNTS AS SF_ACCOUNTS 
            PRIMARY KEY (ACCOUNT_ID) 
            WITH SYNONYMS=('customers','accounts','clients') 
            COMMENT='Customer account information for revenue analysis',
        
        -- Marketing campaign fact table - core campaign performance metrics
        CAMPAIGNS AS MARKETING_CAMPAIGN_FACT 
            PRIMARY KEY (CAMPAIGN_FACT_ID) 
            WITH SYNONYMS=('marketing campaigns','campaign data') 
            COMMENT='Marketing campaign performance data',
        
        -- Campaign details dimension - campaign names and objectives
        CAMPAIGN_DETAILS AS CAMPAIGN_DIM 
            PRIMARY KEY (CAMPAIGN_KEY) 
            WITH SYNONYMS=('campaign info','campaign details') 
            COMMENT='Campaign dimension with objectives and names',
        
        -- Marketing channel dimension - channels used for campaigns
        CHANNELS AS CHANNEL_DIM 
            PRIMARY KEY (CHANNEL_KEY) 
            WITH SYNONYMS=('marketing channels','channels') 
            COMMENT='Marketing channel information',
        
        -- Contact/Lead records generated from marketing (from Salesforce)
        CONTACTS AS SF_CONTACTS 
            PRIMARY KEY (CONTACT_ID) 
            WITH SYNONYMS=('leads','contacts','prospects') 
            COMMENT='Contact records generated from marketing campaigns',
        
        -- Contacts associated with sales opportunities (from Salesforce)
        CONTACTS_FOR_OPPORTUNITIES AS SF_CONTACTS 
            PRIMARY KEY (CONTACT_ID) 
            WITH SYNONYMS=('opportunity contacts') 
            COMMENT='Contact records generated from marketing campaigns, specifically for opportunities, not leads',
        
        -- Sales opportunity records - deals in the pipeline (from Salesforce)
        OPPORTUNITIES AS SF_OPPORTUNITIES 
            PRIMARY KEY (OPPORTUNITY_ID) 
            WITH SYNONYMS=('deals','opportunities','sales pipeline') 
            COMMENT='Sales opportunities and revenue data',
        
        -- Product dimension - products promoted in campaigns
        PRODUCTS AS PRODUCT_DIM 
            PRIMARY KEY (PRODUCT_KEY) 
            WITH SYNONYMS=('products','items') 
            COMMENT='Product dimension for campaign-specific analysis',
        
        -- Region dimension - geographic targeting for campaigns
        REGIONS AS REGION_DIM 
            PRIMARY KEY (REGION_KEY) 
            WITH SYNONYMS=('territories','regions','markets') 
            COMMENT='Regional information for campaign analysis'
    )
    
    -- ========================================================================
    -- RELATIONSHIPS SECTION
    -- ========================================================================
    -- Define the complete attribution chain from campaigns to revenue
    -- Campaign → Contact/Lead → Opportunity → Revenue
    -- ========================================================================
    RELATIONSHIPS (
        -- Campaign dimension relationships
        CAMPAIGNS_TO_CHANNELS AS CAMPAIGNS(CHANNEL_KEY) REFERENCES CHANNELS(CHANNEL_KEY),
        CAMPAIGNS_TO_DETAILS AS CAMPAIGNS(CAMPAIGN_KEY) REFERENCES CAMPAIGN_DETAILS(CAMPAIGN_KEY),
        CAMPAIGNS_TO_PRODUCTS AS CAMPAIGNS(PRODUCT_KEY) REFERENCES PRODUCTS(PRODUCT_KEY),
        CAMPAIGNS_TO_REGIONS AS CAMPAIGNS(REGION_KEY) REFERENCES REGIONS(REGION_KEY),
        
        -- Contact/Lead attribution relationships
        CONTACTS_TO_ACCOUNTS AS CONTACTS(ACCOUNT_ID) REFERENCES ACCOUNTS(ACCOUNT_ID),
        CONTACTS_TO_CAMPAIGNS AS CONTACTS(CAMPAIGN_NO) REFERENCES CAMPAIGNS(CAMPAIGN_FACT_ID),
        CONTACTS_TO_OPPORTUNITIES AS CONTACTS_FOR_OPPORTUNITIES(OPPORTUNITY_ID) REFERENCES OPPORTUNITIES(OPPORTUNITY_ID),
        
        -- Opportunity revenue attribution relationships
        OPPORTUNITIES_TO_ACCOUNTS AS OPPORTUNITIES(ACCOUNT_ID) REFERENCES ACCOUNTS(ACCOUNT_ID),
        OPPORTUNITIES_TO_CAMPAIGNS AS OPPORTUNITIES(CAMPAIGN_ID) REFERENCES CAMPAIGNS(CAMPAIGN_FACT_ID)
    )
    
    -- ========================================================================
    -- FACTS SECTION
    -- ========================================================================
    -- Define measurable values across the marketing funnel
    -- From spend and impressions → leads → opportunities → revenue
    -- ========================================================================
    FACTS (
        -- Campaign activity metrics
        PUBLIC CAMPAIGNS.CAMPAIGN_RECORD AS 1 
            COMMENT='Count of campaign activities',
        PUBLIC CAMPAIGNS.CAMPAIGN_SPEND AS spend 
            COMMENT='Marketing spend in dollars',
        PUBLIC CAMPAIGNS.IMPRESSIONS AS IMPRESSIONS 
            COMMENT='Number of impressions',
        PUBLIC CAMPAIGNS.LEADS_GENERATED AS LEADS_GENERATED 
            COMMENT='Number of leads generated',
        
        -- Lead/Contact generation metrics
        PUBLIC CONTACTS.CONTACT_RECORD AS 1 
            COMMENT='Count of contacts generated',
        
        -- Opportunity and revenue metrics
        PUBLIC OPPORTUNITIES.OPPORTUNITY_RECORD AS 1 
            COMMENT='Count of opportunities created',
        PUBLIC OPPORTUNITIES.REVENUE AS AMOUNT 
            COMMENT='Opportunity revenue in dollars'
    )
    
    -- ========================================================================
    -- DIMENSIONS SECTION
    -- ========================================================================
    -- Define attributes for detailed marketing analysis and attribution
    -- ========================================================================
    DIMENSIONS (
        -- ====================================================================
        -- ACCOUNT DIMENSIONS (Customer information)
        -- ====================================================================
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
            COMMENT='This is the customer key thank links the Salesforce account to customers table.',
        
        -- ====================================================================
        -- CAMPAIGN DIMENSIONS (Campaign facts and time dimensions)
        -- ====================================================================
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
        
        -- ====================================================================
        -- CAMPAIGN DETAIL DIMENSIONS
        -- ====================================================================
        PUBLIC CAMPAIGN_DETAILS.CAMPAIGN_KEY AS CAMPAIGN_KEY,
        PUBLIC CAMPAIGN_DETAILS.CAMPAIGN_NAME AS CAMPAIGN_NAME 
            WITH SYNONYMS=('campaign','campaign title') 
            COMMENT='Name of the marketing campaign',
        PUBLIC CAMPAIGN_DETAILS.CAMPAIGN_OBJECTIVE AS OBJECTIVE 
            WITH SYNONYMS=('objective','goal','purpose') 
            COMMENT='Campaign objective',
        
        -- ====================================================================
        -- CHANNEL DIMENSIONS
        -- ====================================================================
        PUBLIC CHANNELS.CHANNEL_KEY AS CHANNEL_KEY,
        PUBLIC CHANNELS.CHANNEL_NAME AS CHANNEL_NAME 
            WITH SYNONYMS=('channel','marketing channel') 
            COMMENT='Name of the marketing channel',
        
        -- ====================================================================
        -- CONTACT/LEAD DIMENSIONS
        -- ====================================================================
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
        
        -- ====================================================================
        -- OPPORTUNITY DIMENSIONS (Sales pipeline)
        -- ====================================================================
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
            COMMENT='Stage name of the opportinity. Closed Won indicates an actual sale with revenue',
        PUBLIC OPPORTUNITIES.OPPORTUNITY_TYPE AS TYPE 
            WITH SYNONYMS=('deal type','opportunity type') 
            COMMENT='Type of opportunity',
        PUBLIC OPPORTUNITIES.SALES_SALE_ID AS SALE_ID 
            WITH SYNONYMS=('sales id','invoice no') 
            COMMENT='Sales_ID for sales_fact table that links this opp to a sales record.',
        
        -- ====================================================================
        -- PRODUCT DIMENSIONS
        -- ====================================================================
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
        
        -- ====================================================================
        -- REGION DIMENSIONS
        -- ====================================================================
        PUBLIC REGIONS.REGION_KEY AS REGION_KEY,
        PUBLIC REGIONS.REGION_NAME AS REGION_NAME 
            WITH SYNONYMS=('region','market','territory') 
            COMMENT='Name of the region'
    )
    
    -- ========================================================================
    -- METRICS SECTION
    -- ========================================================================
    -- Pre-calculated KPIs for marketing performance and ROI analysis
    -- ========================================================================
    METRICS (
        -- Campaign spend metrics
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
        
        -- Contact/Lead metrics
        PUBLIC CONTACTS.TOTAL_CONTACTS AS COUNT(CONTACTS.contact_record) 
            COMMENT='Total contacts generated from campaigns',
        
        -- Revenue attribution metrics
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
    
    -- ========================================================================
    -- CORTEX ANALYST EXTENSION
    -- ========================================================================
    -- Extended metadata including verified queries for campaign-to-revenue analysis
    -- ========================================================================
    WITH EXTENSION (
        CA='{"tables":[{"name":"ACCOUNTS","dimensions":[{"name":"ACCOUNT_ID"},{"name":"ACCOUNT_NAME"},{"name":"ACCOUNT_TYPE"},{"name":"ANNUAL_REVENUE"},{"name":"EMPLOYEES"},{"name":"INDUSTRY"},{"name":"SALES_CUSTOMER_KEY"}]},{"name":"CAMPAIGNS","dimensions":[{"name":"CAMPAIGN_DATE"},{"name":"CAMPAIGN_FACT_ID"},{"name":"CAMPAIGN_KEY"},{"name":"CAMPAIGN_MONTH"},{"name":"CAMPAIGN_YEAR"},{"name":"CHANNEL_KEY"},{"name":"PRODUCT_KEY"},{"name":"REGION_KEY"}],"facts":[{"name":"CAMPAIGN_RECORD"},{"name":"CAMPAIGN_SPEND"},{"name":"IMPRESSIONS"},{"name":"LEADS_GENERATED"}],"metrics":[{"name":"AVERAGE_SPEND"},{"name":"TOTAL_CAMPAIGNS"},{"name":"TOTAL_IMPRESSIONS"},{"name":"TOTAL_LEADS"},{"name":"TOTAL_SPEND"}]},{"name":"CAMPAIGN_DETAILS","dimensions":[{"name":"CAMPAIGN_KEY"},{"name":"CAMPAIGN_NAME"},{"name":"CAMPAIGN_OBJECTIVE"}]},{"name":"CHANNELS","dimensions":[{"name":"CHANNEL_KEY"},{"name":"CHANNEL_NAME"}]},{"name":"CONTACTS","dimensions":[{"name":"ACCOUNT_ID"},{"name":"CAMPAIGN_NO"},{"name":"CONTACT_ID"},{"name":"DEPARTMENT"},{"name":"EMAIL"},{"name":"FIRST_NAME"},{"name":"LAST_NAME"},{"name":"LEAD_SOURCE"},{"name":"OPPORTUNITY_ID"},{"name":"TITLE"}],"facts":[{"name":"CONTACT_RECORD"}],"metrics":[{"name":"TOTAL_CONTACTS"}]},{"name":"CONTACTS_FOR_OPPORTUNITIES"},{"name":"OPPORTUNITIES","dimensions":[{"name":"ACCOUNT_ID"},{"name":"CAMPAIGN_ID"},{"name":"CLOSE_DATE"},{"name":"OPPORTUNITY_ID"},{"name":"OPPORTUNITY_LEAD_SOURCE"},{"name":"OPPORTUNITY_NAME"},{"name":"OPPORTUNITY_STAGE","sample_values":["Closed Won","Perception Analysis","Qualification"]},{"name":"OPPORTUNITY_TYPE"},{"name":"SALES_SALE_ID"}],"facts":[{"name":"OPPORTUNITY_RECORD"},{"name":"REVENUE"}],"metrics":[{"name":"AVERAGE_DEAL_SIZE"},{"name":"CLOSED_WON_REVENUE"},{"name":"TOTAL_OPPORTUNITIES"},{"name":"TOTAL_REVENUE"}]},{"name":"PRODUCTS","dimensions":[{"name":"PRODUCT_CATEGORY"},{"name":"PRODUCT_KEY"},{"name":"PRODUCT_NAME"},{"name":"PRODUCT_VERTICAL"}]},{"name":"REGIONS","dimensions":[{"name":"REGION_KEY"},{"name":"REGION_NAME"}]}],"relationships":[{"name":"CAMPAIGNS_TO_CHANNELS","relationship_type":"many_to_one"},{"name":"CAMPAIGNS_TO_DETAILS","relationship_type":"many_to_one"},{"name":"CAMPAIGNS_TO_PRODUCTS","relationship_type":"many_to_one"},{"name":"CAMPAIGNS_TO_REGIONS","relationship_type":"many_to_one"},{"name":"CONTACTS_TO_ACCOUNTS","relationship_type":"many_to_one"},{"name":"CONTACTS_TO_CAMPAIGNS","relationship_type":"many_to_one"},{"name":"CONTACTS_TO_OPPORTUNITIES","relationship_type":"many_to_one"},{"name":"OPPORTUNITIES_TO_ACCOUNTS","relationship_type":"many_to_one"},{"name":"OPPORTUNITIES_TO_CAMPAIGNS"}],"verified_queries":[{"name":"include opps that turned in to sales deal","question":"include opps that turned in to sales deal","sql":"WITH campaign_impressions AS (\\n  SELECT\\n    c.campaign_key,\\n    cd.campaign_name,\\n    SUM(c.impressions) AS total_impressions\\n  FROM\\n    campaigns AS c\\n    LEFT OUTER JOIN campaign_details AS cd ON c.campaign_key = cd.campaign_key\\n  WHERE\\n    c.campaign_year = 2025\\n  GROUP BY\\n    c.campaign_key,\\n    cd.campaign_name\\n),\\ncampaign_opportunities AS (\\n  SELECT\\n    c.campaign_key,\\n    COUNT(o.opportunity_record) AS total_opportunities,\\n    COUNT(\\n      CASE\\n        WHEN o.opportunity_stage = ''Closed Won'' THEN o.opportunity_record\\n      END\\n    ) AS closed_won_opportunities\\n  FROM\\n    campaigns AS c\\n    LEFT OUTER JOIN opportunities AS o ON c.campaign_fact_id = o.campaign_id\\n  WHERE\\n    c.campaign_year = 2025\\n  GROUP BY\\n    c.campaign_key\\n)\\nSELECT\\n  ci.campaign_name,\\n  ci.total_impressions,\\n  COALESCE(co.total_opportunities, 0) AS total_opportunities,\\n  COALESCE(co.closed_won_opportunities, 0) AS closed_won_opportunities\\nFROM\\n  campaign_impressions AS ci\\n  LEFT JOIN campaign_opportunities AS co ON ci.campaign_key = co.campaign_key\\nORDER BY\\n  ci.total_impressions DESC NULLS LAST","use_as_onboarding_question":false,"verified_by":"Nick Akincilar","verified_at":1757262696}]}'
    );


-- ============================================================================
-- MARKETING SEMANTIC VIEW TESTING AND VALIDATION
-- ============================================================================
-- These commands verify the semantic view was created correctly
-- ============================================================================

USE SCHEMA marketing_db.iceberg_data;

-- Display all semantic views in the current schema
SHOW SEMANTIC VIEWS;

-- List all dimensions available in semantic views
SHOW SEMANTIC DIMENSIONS;

-- List all pre-calculated metrics in semantic views
SHOW SEMANTIC METRICS; 

-- Switch to appropriate warehouse for query execution
USE WAREHOUSE marketing_wh;

-- Test query: Retrieve data using the semantic view interface
-- This demonstrates marketing campaign analysis with semantic views
SELECT * FROM SEMANTIC_VIEW(
    MARKETING_DB.ICEBERG_DATA.MARKETING_SEMANTIC_VIEW
    DIMENSIONS CAMPAIGNS.CAMPAIGN_KEY
);


-- ============================================================================
-- SHARE SEMANTIC VIEW IN DATA PRODUCT
-- ============================================================================
-- Grant access to semantic views in the Marketing data share
-- This makes the Marketing data product AI-ready for consumers
-- ============================================================================
GRANT SELECT ON ALL SEMANTIC VIEWS IN SCHEMA marketing_db.iceberg_data TO SHARE marketing_data_share;


/*
================================================================================
END OF SCRIPT
================================================================================
Key Benefits of Semantic Views:
1. Natural Language Queries - Business users can ask questions in plain English
2. Self-Service Analytics - No need to understand underlying table structures
3. Consistent Metrics - Everyone uses the same definitions and calculations
4. AI-Ready - Compatible with Snowflake Cortex Analyst and BI tools
5. Data Products - Can be shared with consumers who don't need SQL expertise

Usage Examples:
- "Show me total salary cost by department for active employees"
- "What's the ROI of email campaigns in Q4 2024?"
- "List all employees hired in the last 6 months"
- "Which campaigns generated the most closed-won revenue?"

These semantic views abstract away complex joins and business logic, making
data accessible to non-technical users while maintaining governance and consistency.
================================================================================
*/

