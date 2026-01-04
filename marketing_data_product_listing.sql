/*
================================================================================
SNOWFLAKE ORGANIZATION LISTING: MARKETING DATA PRODUCT
================================================================================
This script creates an organization listing for marketing data products using
Apache Iceberg tables with proper data governance and sharing controls.

Features:
- Cross-account data sharing with role-based access
- Auto-fulfillment with scheduled refresh
- Comprehensive data dictionary and documentation
- Request and approval workflow integration
================================================================================
*/

-- Create organization listing for marketing data product
CREATE ORGANIZATION LISTING marketing_data_product
    SHARE = marketing_data_share
    AS
    $$
    {
        "title": "[Interop Apache Iceberg] Marketing Facts",
        
        "description": "This data listing provides a comprehensive overview of **marketing campaigns** within our enterprise. It's a key resource for the marketing team, analysts, and business leaders to evaluate campaign effectiveness, optimize spending, and understand customer engagement. The dataset includes information on various marketing channels, campaign costs, and key performance metrics.\n\n**Data Contract SLO**\n\n- **Frequency:** Updated every hour\n- **Source:** Data is curated from our various marketing platforms (e.g., Google Ads, Meta Ads Manager, Mailchimp)\n- **Access:** By Request. Access is restricted to authorized personnel to be determined by owner\n- **No PII**",
        
        "data_preview": {
            "has_pii": false
        },
        
        "data_dictionary": {
            "featured": {
                "database": "MARKETING_DB",
                "objects": [
                    {
                        "schema": "ICEBERG_DATA",
                        "domain": "ICEBERG TABLE",
                        "name": "CAMPAIGN_DIM"
                    },
                    {
                        "schema": "ICEBERG_DATA", 
                        "domain": "ICEBERG TABLE",
                        "name": "MARKETING_CAMPAIGN_FACT"
                    }
                ]
            }
        },
        
        "resources": {
            "documentation": "https://www.example.com/documentation/marketing",
            "media": "https://www.youtube.com/watch?v=MEFlT3dc3uc"
        },
        
        "organization_profile": "INTERNAL",
        
        "organization_targets": {
            "discovery": [
                {
                    "all_internal_accounts": true
                }
            ],
            "access": [
                {
                    "account": "AMGUPTA_SNOW_AWSUSWEST1",
                    "roles": [
                        "SALES_DOMAIN_ROLE"
                    ]
                },
                {
                    "account": "AMGUPTA_SNOW_AZUREUSEAST", 
                    "roles": [
                        "FINANCE_DOMAIN_ROLE"
                    ]
                }
            ]
        },
        
        "request_approval_type": "REQUEST_AND_APPROVE_IN_SNOWFLAKE",
        
        "support_contact": "marketing_domain_dl@snowflake.com",
        
        "approver_contact": "amit.gupta@snowflake.com",
        
        "locations": {
            "access_regions": [
                {
                    "name": "ALL"
                }
            ]
        },
        
        "auto_fulfillment": {
            "refresh_type": "SUB_DATABASE",
            "refresh_schedule": "1 MINUTE",
            "refresh_schedule_override": true
        }
    }
    $$
    PUBLISH = true;

/*
================================================================================
ALTERNATIVE SYNTAX (IF ABOVE DOESN'T WORK)
================================================================================
Some Snowflake versions may require a different syntax structure.
*/

-- Alternative approach using individual parameters
CREATE ORGANIZATION LISTING IF NOT EXISTS marketing_data_product_alt
    SHARE = marketing_data_share
    TITLE = '[Interop Apache Iceberg] Marketing Facts'
    DESCRIPTION = 'This data listing provides a comprehensive overview of marketing campaigns within our enterprise. It is a key resource for the marketing team, analysts, and business leaders to evaluate campaign effectiveness, optimize spending, and understand customer engagement.'
    ORGANIZATION_PROFILE = 'INTERNAL'
    SUPPORT_CONTACT = 'marketing_domain_dl@snowflake.com'
    APPROVER_CONTACT = 'amit.gupta@snowflake.com'
    REQUEST_APPROVAL_TYPE = 'REQUEST_AND_APPROVE_IN_SNOWFLAKE'
    PUBLISH = true;

/*
================================================================================
PREREQUISITE SETUP COMMANDS
================================================================================
Run these commands before creating the organization listing to ensure
all required objects and permissions are in place.
*/

-- Ensure the marketing share exists
USE ROLE accountadmin;

-- Create the marketing data share if it doesn't exist
CREATE SHARE IF NOT EXISTS marketing_data_share
    COMMENT = 'Share for marketing data products including campaign and performance metrics';

-- Grant database to the share
GRANT USAGE ON DATABASE MARKETING_DB TO SHARE marketing_data_share;
GRANT USAGE ON SCHEMA MARKETING_DB.ICEBERG_DATA TO SHARE marketing_data_share;

-- Grant access to specific tables
GRANT SELECT ON TABLE MARKETING_DB.ICEBERG_DATA.CAMPAIGN_DIM TO SHARE marketing_data_share;
GRANT SELECT ON TABLE MARKETING_DB.ICEBERG_DATA.MARKETING_CAMPAIGN_FACT TO SHARE marketing_data_share;

-- Verify share contents
SHOW GRANTS TO SHARE marketing_data_share;

/*
================================================================================
VALIDATION QUERIES
================================================================================
Use these queries to validate the organization listing was created successfully.
*/

-- Show all organization listings
SHOW ORGANIZATION LISTINGS;

-- Show details of the specific listing
SHOW ORGANIZATION LISTINGS LIKE 'marketing_data_product%';

-- Describe the organization listing
DESC ORGANIZATION LISTING marketing_data_product;

/*
================================================================================
TROUBLESHOOTING NOTES
================================================================================

Common Issues and Solutions:

1. **Share doesn't exist**: Create the share first using CREATE SHARE
2. **Insufficient privileges**: Ensure you have ORGADMIN or ACCOUNTADMIN role
3. **Invalid JSON**: Validate JSON structure in the $$ block
4. **Account identifiers**: Verify account names are correct format
5. **Role names**: Ensure target roles exist in destination accounts

Required Privileges:
- CREATE ORGANIZATION LISTING privilege
- USAGE on the share being referenced
- Appropriate role assignments for cross-account access
================================================================================
*/


