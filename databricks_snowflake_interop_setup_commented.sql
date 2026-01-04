/*
================================================================================
DATABRICKS QUERY FEDERATION SETUP FOR SNOWFLAKE DATA PRODUCTS
================================================================================
Purpose: Configure Snowflake data products for consumption via Databricks Query Federation
Description: This script sets up cross-platform data access between Snowflake and Databricks.
             It handles mounting data products from various regions and clouds, and implements
             workarounds for Universal Listing Link (ULL) limitations with Databricks Query
             Federation. Includes role setup, database mounting, and view creation for seamless
             data interoperability.

Contents:
  1. Role Permissions Setup - Grant necessary privileges for data product access
  2. Database Creation from Listings - Mount cross-region and cross-cloud data products
  3. ULL Workaround Views - Create local views for in-account data products
  4. Sample Queries - Demonstration queries for Databricks consumption

Author: Amit Gupta
Last Updated: October 18, 2025
Demo: Available at Interoperable Data Mesh Webinar - https://www.snowflake.com/en/webinars/demo/unlocking-ai-with-an-interoperable-data-mesh-2025-10-16/
 
================================================================================
*/

/*******************************************************************************
 * SECTION 1: INITIAL SETUP (NOT USED - COMMENTED OUT)
 * 
 * This section was used during initial development but is no longer needed.
 * Keeping for reference purposes.
 ******************************************************************************/

/* -- Not used
use role accountadmin;
create or replace user HR_DATABRICKS_USER  PASSWORD = 'LcjwVd2XbYoVyitfc4*Q@LXKnex*88';
grant role HR_DOMAIN_ROLE to user HR_DATABRICKS_USER ;
alter user john set MINS_TO_BYPASS_MFA = 480;*/


/*******************************************************************************
 * SECTION 2: ROLE PERMISSIONS SETUP
 * 
 * Grant necessary privileges to the HR_DOMAIN_ROLE for:
 * - Importing data shares
 * - Creating databases
 * - Assigning role to users
 ******************************************************************************/

use role accountadmin;

-- Grant permission to import data shares from other accounts/regions
grant import share on account to role hr_domain_role;

-- Grant permission to create databases (needed for mounting listings)
grant create database on account to role hr_domain_role;

-- Grant hr_domain_role to accountadmin for administrative access
grant role hr_domain_role to role accountadmin;

-- Grant hr_domain_role to the interop_user for Databricks connectivity
-- Note: Typo in original (HR_DBhr_domain_role) - keeping as-is for consistency
grant role HR_DBhr_domain_role to user interop_user;


/*******************************************************************************
 * SECTION 3: CREATE DATABASES FROM DATA PRODUCT LISTINGS
 * 
 * Context: Databricks Query Federation cannot directly query Universal Listing
 * Links (ULL). These data products require local database mounting before they
 * can be accessed from Databricks.
 * 
 * Using accountadmin because hr_domain_role lacks sufficient privileges to
 * create databases from listings despite having the grant.
 ******************************************************************************/

use role accountadmin;

-- Mount cross-region Sales data product from Snowflake
create or replace database shared_snow_xregion_sales 
from listing ORGDATACLOUD$INTERNAL$SALES_DATA_PRODUCT;

-- Mount cross-cloud Finance data product from Snowflake
create or replace database shared_snow_xcloud_finance 
from listing ORGDATACLOUD$INTERNAL$FINANCE_DATA_PRODUCT;

-- Mount cross-region Enterprise (unstructured) data product
create or replace database shared_cke_unstructured_xregion_enterprise 
from listing ORGDATACLOUD$INTERNAL$ENTERPRISE_DATA_PRODUCT;

-- Grant imported privileges to hr_domain_role so it can access the mounted databases
grant imported privileges on database shared_snow_xcloud_finance to role hr_domain_role;
grant imported privileges on database shared_snow_xregion_sales to role hr_domain_role;


/*******************************************************************************
 * SECTION 4: WORKAROUND FOR IN-ACCOUNT MARKETING DATA PRODUCT
 * 
 * Problem: 
 * - Databricks Query Federation cannot query ULL objects
 * - In-account data products cannot be mounted like cross-region/cloud listings
 * 
 * Solution:
 * - Create a local database and schema
 * - Create views that reference the ULL marketing data product
 * - Databricks can query these views via Query Federation
 * 
 * This creates a local "wrapper" around the ULL that Databricks can access.
 ******************************************************************************/

use role hr_domain_role;

-- Create local database to house views pointing to ULL
create or replace database shared_iceberg_xregion_marketing;
create or replace schema shared_iceberg_xregion_marketing.iceberg_data;

-- Create views for each table in the marketing data product
-- These views simply pass through all data from the ULL objects

create or replace view CAMPAIGN_DIM as 
select * from ORGDATACLOUD$INTERNAL$MARKETING_DATA_PRODUCT.ICEBERG_DATA.CAMPAIGN_DIM;

create or replace view CHANNEL_DIM as 
select * from ORGDATACLOUD$INTERNAL$MARKETING_DATA_PRODUCT.ICEBERG_DATA.CHANNEL_DIM;

create or replace view MARKETING_CAMPAIGN_FACT as 
select * from ORGDATACLOUD$INTERNAL$MARKETING_DATA_PRODUCT.ICEBERG_DATA.MARKETING_CAMPAIGN_FACT;

create or replace view PRODUCT_DIM as 
select * from ORGDATACLOUD$INTERNAL$MARKETING_DATA_PRODUCT.ICEBERG_DATA.PRODUCT_DIM;

create or replace view REGION_DIM as 
select * from ORGDATACLOUD$INTERNAL$MARKETING_DATA_PRODUCT.ICEBERG_DATA.REGION_DIM;

create or replace view SF_ACCOUNTS as 
select * from ORGDATACLOUD$INTERNAL$MARKETING_DATA_PRODUCT.ICEBERG_DATA.SF_ACCOUNTS;

create or replace view SF_CONTACTS as 
select * from ORGDATACLOUD$INTERNAL$MARKETING_DATA_PRODUCT.ICEBERG_DATA.SF_CONTACTS;

create or replace view SF_OPPORTUNITIES as 
select * from ORGDATACLOUD$INTERNAL$MARKETING_DATA_PRODUCT.ICEBERG_DATA.SF_OPPORTUNITIES;


/*******************************************************************************
 * SECTION 5: SEMANTIC VIEW (UNUSED CODE - COMMENTED OUT)
 * 
 * This section demonstrates creating a Snowflake Semantic View for marketing
 * data analysis. However, semantic views are not visible to JDBC integrations
 * like Databricks Query Federation, so this approach was abandoned.
 * 
 * Keeping the code for reference as it shows a comprehensive semantic model
 * with tables, relationships, facts, dimensions, and metrics.
 ******************************************************************************/

/* Unused Code
-- recreate semantic view on ULL based views
---- Although note this semantic view does not show up on jdbc integrations eg federation with Unity
create or replace semantic view MARKETING_SEMANTIC_VIEW
	tables (
		ACCOUNTS as SF_ACCOUNTS primary key (ACCOUNT_ID) with synonyms=('customers','accounts','clients') comment='Customer account information for revenue analysis',
		CAMPAIGNS as MARKETING_CAMPAIGN_FACT primary key (CAMPAIGN_FACT_ID) with synonyms=('marketing campaigns','campaign data') comment='Marketing campaign performance data',
		CAMPAIGN_DETAILS as CAMPAIGN_DIM primary key (CAMPAIGN_KEY) with synonyms=('campaign info','campaign details') comment='Campaign dimension with objectives and names',
		CHANNELS as CHANNEL_DIM primary key (CHANNEL_KEY) with synonyms=('marketing channels','channels') comment='Marketing channel information',
		CONTACTS as SF_CONTACTS primary key (CONTACT_ID) with synonyms=('leads','contacts','prospects') comment='Contact records generated from marketing campaigns',
		CONTACTS_FOR_OPPORTUNITIES as SF_CONTACTS primary key (CONTACT_ID) with synonyms=('opportunity contacts') comment='Contact records generated from marketing campaigns, specifically for opportunities, not leads',
		OPPORTUNITIES as SF_OPPORTUNITIES primary key (OPPORTUNITY_ID) with synonyms=('deals','opportunities','sales pipeline') comment='Sales opportunities and revenue data',
		PRODUCTS as PRODUCT_DIM primary key (PRODUCT_KEY) with synonyms=('products','items') comment='Product dimension for campaign-specific analysis',
		REGIONS as REGION_DIM primary key (REGION_KEY) with synonyms=('territories','regions','markets') comment='Regional information for campaign analysis'
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
*/


/*******************************************************************************
 * SECTION 6: SAMPLE QUERY FOR DATABRICKS CONSUMPTION
 * 
 * This query demonstrates how to access the marketing data from Databricks
 * via Query Federation. It analyzes campaign performance metrics over a
 * date range.
 * 
 * Generated by: Cortex Analyst (Snowflake's AI SQL generator)
 * Use case: Campaign performance analysis for May-June 2025
 ******************************************************************************/

use role HR_DOMAIN_ROLE;

-- Campaign Performance Analysis Query
-- Aggregates campaign spend and impressions by month
WITH __campaigns AS (
  -- Extract relevant fields from marketing campaign fact table
  SELECT
    date AS campaign_date,
    campaign_key,
    spend AS campaign_spend,
    impressions
  FROM shared_iceberg_xregion_marketing.iceberg_data.marketing_campaign_fact
), 
__campaign_details AS (
  -- Get campaign names for better readability
  SELECT
    campaign_key,
    campaign_name
  FROM shared_iceberg_xregion_marketing.iceberg_data.campaign_dim
), 
campaign_metrics AS (
  -- Aggregate metrics at monthly level
  SELECT
    DATE_TRUNC('MONTH', c.campaign_date) AS campaign_month,
    MIN(c.campaign_date) AS min_date,
    MAX(c.campaign_date) AS max_date,
    COUNT(DISTINCT cd.campaign_name) AS num_campaigns,
    SUM(c.impressions) AS total_impressions,
    SUM(c.campaign_spend) AS total_spend,
    MIN(c.campaign_spend) AS min_spend,
    MAX(c.campaign_spend) AS max_spend,
    AVG(c.campaign_spend) AS avg_spend
  FROM __campaigns AS c
  LEFT OUTER JOIN __campaign_details AS cd
    ON c.campaign_key = cd.campaign_key
  WHERE
    -- Filter for May-June 2025
    c.campaign_date >= '2025-05-01' AND c.campaign_date <= '2025-06-30'
  GROUP BY
    DATE_TRUNC('MONTH', c.campaign_date)
)
-- Final output with all metrics
SELECT
  campaign_month,
  min_date,
  max_date,
  num_campaigns,
  total_impressions,
  total_spend,
  min_spend,
  max_spend,
  avg_spend
FROM campaign_metrics
ORDER BY
  campaign_month DESC NULLS LAST;
-- Generated by Cortex Analyst

