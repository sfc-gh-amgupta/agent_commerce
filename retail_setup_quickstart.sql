-- =====================================================
-- RETAIL DATA MODEL - QUICK START SETUP
-- =====================================================
-- Description: One-click setup script for retail data model
-- Platform: Snowflake
-- Usage: Run this script to set up the complete retail data model
-- =====================================================

-- =====================================================
-- STEP 1: CREATE DATABASE AND SCHEMA
-- =====================================================
-- This creates the database and schema structure

CREATE DATABASE IF NOT EXISTS RETAIL_DB;
USE DATABASE RETAIL_DB;

CREATE SCHEMA IF NOT EXISTS RETAIL_SCHEMA;
USE SCHEMA RETAIL_SCHEMA;

-- Set context
USE ROLE SYSADMIN;  -- Adjust role as needed
USE WAREHOUSE COMPUTE_WH;  -- Adjust warehouse as needed

-- =====================================================
-- STEP 2: RUN DDL SCRIPT
-- =====================================================
-- Creates all dimension tables, fact tables, and bridge tables
-- Execute: retail_data_model.sql

!source retail_data_model.sql;

-- Alternative if !source doesn't work:
-- Copy and paste the contents of retail_data_model.sql here

-- =====================================================
-- STEP 3: LOAD SAMPLE DATA
-- =====================================================
-- Populates all tables with sample data
-- Execute: retail_sample_data.sql

!source retail_sample_data.sql;

-- Alternative if !source doesn't work:
-- Copy and paste the contents of retail_sample_data.sql here

-- =====================================================
-- STEP 4: CREATE ANALYTICAL VIEWS
-- =====================================================
-- Creates pre-built analytical views
-- Execute: retail_analytics_views.sql

!source retail_analytics_views.sql;

-- Alternative if !source doesn't work:
-- Copy and paste the contents of retail_analytics_views.sql here

-- =====================================================
-- STEP 5: VERIFY INSTALLATION
-- =====================================================

-- Check all tables exist
SHOW TABLES IN RETAIL_DB.RETAIL_SCHEMA;

-- Check row counts
SELECT 'VERIFICATION: Row Counts' AS check_type, '---' AS table_name, NULL AS row_count
UNION ALL
SELECT 'Dimension Tables', 'DIM_DATE', COUNT(*) FROM DIM_DATE
UNION ALL
SELECT '', 'DIM_TIME', COUNT(*) FROM DIM_TIME
UNION ALL
SELECT '', 'DIM_CUSTOMER', COUNT(*) FROM DIM_CUSTOMER
UNION ALL
SELECT '', 'DIM_PRODUCT', COUNT(*) FROM DIM_PRODUCT
UNION ALL
SELECT '', 'DIM_STORE', COUNT(*) FROM DIM_STORE
UNION ALL
SELECT '', 'DIM_PROMOTION', COUNT(*) FROM DIM_PROMOTION
UNION ALL
SELECT '', 'DIM_PAYMENT_METHOD', COUNT(*) FROM DIM_PAYMENT_METHOD
UNION ALL
SELECT '', 'DIM_EMPLOYEE', COUNT(*) FROM DIM_EMPLOYEE
UNION ALL
SELECT '', 'DIM_SUPPLIER', COUNT(*) FROM DIM_SUPPLIER
UNION ALL
SELECT 'Fact Tables', 'FACT_SALES', COUNT(*) FROM FACT_SALES
UNION ALL
SELECT '', 'FACT_INVENTORY', COUNT(*) FROM FACT_INVENTORY
UNION ALL
SELECT '', 'FACT_CUSTOMER_INTERACTION', COUNT(*) FROM FACT_CUSTOMER_INTERACTION
UNION ALL
SELECT 'Bridge Tables', 'BRIDGE_PRODUCT_SUPPLIER', COUNT(*) FROM BRIDGE_PRODUCT_SUPPLIER
UNION ALL
SELECT '', 'BRIDGE_PROMOTION_PRODUCT', COUNT(*) FROM BRIDGE_PROMOTION_PRODUCT;

-- Check views exist
SHOW VIEWS IN RETAIL_DB.RETAIL_SCHEMA;

-- =====================================================
-- STEP 6: RUN SAMPLE QUERIES
-- =====================================================

-- Sample Query 1: Daily Sales Summary (Last 7 Days)
SELECT 
    DATE_ACTUAL,
    DAY_NAME,
    transaction_count,
    unique_customers,
    ROUND(total_net_sales, 2) AS total_sales,
    ROUND(avg_transaction_value, 2) AS avg_transaction
FROM VW_DAILY_SALES_SUMMARY
WHERE DATE_ACTUAL >= DATEADD(day, -7, CURRENT_DATE())
ORDER BY DATE_ACTUAL DESC;

-- Sample Query 2: Top 10 Products by Sales
SELECT 
    PRODUCT_NAME,
    CATEGORY_LEVEL1,
    BRAND,
    ROUND(total_sales, 2) AS total_sales,
    total_quantity_sold,
    sales_rank
FROM VW_PRODUCT_SALES_PERFORMANCE
WHERE sales_rank <= 10
ORDER BY sales_rank;

-- Sample Query 3: Store Performance Summary
SELECT 
    REGION,
    COUNT(DISTINCT STORE_ID) AS store_count,
    ROUND(SUM(total_sales), 2) AS regional_sales,
    ROUND(AVG(total_sales), 2) AS avg_store_sales
FROM VW_STORE_SALES_PERFORMANCE
GROUP BY REGION
ORDER BY regional_sales DESC;

-- Sample Query 4: Customer Segmentation
SELECT 
    customer_segment_rfm,
    COUNT(*) AS customer_count,
    ROUND(AVG(monetary_value), 2) AS avg_ltv,
    ROUND(AVG(frequency), 1) AS avg_purchases
FROM VW_CUSTOMER_RFM_ANALYSIS
GROUP BY customer_segment_rfm
ORDER BY customer_count DESC;

-- Sample Query 5: Inventory Alerts
SELECT 
    STORE_NAME,
    PRODUCT_NAME,
    CATEGORY_LEVEL1,
    ENDING_ON_HAND_QUANTITY AS qty_on_hand,
    REORDER_POINT,
    inventory_alert
FROM VW_CURRENT_INVENTORY_STATUS
WHERE inventory_alert IN ('Critical', 'Reorder')
ORDER BY 
    CASE inventory_alert 
        WHEN 'Critical' THEN 1 
        WHEN 'Reorder' THEN 2 
    END,
    ENDING_ON_HAND_QUANTITY
LIMIT 20;

-- =====================================================
-- SETUP COMPLETE!
-- =====================================================

SELECT '✓ Retail Data Model Setup Complete!' AS status,
       'Database: RETAIL_DB, Schema: RETAIL_SCHEMA' AS location,
       '9 Dimensions, 4 Facts, 2 Bridges, 17 Views' AS objects,
       'Review RETAIL_DATA_MODEL_README.md for documentation' AS next_steps;

-- =====================================================
-- OPTIONAL: CREATE SAMPLE DASHBOARDS
-- =====================================================

-- Use these queries to build dashboards in your BI tool

-- Dashboard 1: Executive Summary
CREATE OR REPLACE VIEW VW_DASHBOARD_EXECUTIVE AS
WITH current_period AS (
    SELECT 
        SUM(total_net_sales) AS total_sales,
        SUM(total_gross_profit) AS total_profit,
        COUNT(DISTINCT unique_customers) AS unique_customers,
        SUM(transaction_count) AS total_transactions
    FROM VW_DAILY_SALES_SUMMARY
    WHERE DATE_ACTUAL >= DATEADD(day, -30, CURRENT_DATE())
),
prior_period AS (
    SELECT 
        SUM(total_net_sales) AS total_sales,
        SUM(total_gross_profit) AS total_profit,
        COUNT(DISTINCT unique_customers) AS unique_customers,
        SUM(transaction_count) AS total_transactions
    FROM VW_DAILY_SALES_SUMMARY
    WHERE DATE_ACTUAL BETWEEN DATEADD(day, -60, CURRENT_DATE()) AND DATEADD(day, -31, CURRENT_DATE())
)
SELECT 
    'Last 30 Days' AS period,
    ROUND(cp.total_sales, 2) AS total_sales,
    ROUND(cp.total_profit, 2) AS total_profit,
    cp.unique_customers,
    cp.total_transactions,
    ROUND((cp.total_sales - pp.total_sales) / NULLIF(pp.total_sales, 0) * 100, 1) AS sales_growth_pct,
    ROUND((cp.total_profit - pp.total_profit) / NULLIF(pp.total_profit, 0) * 100, 1) AS profit_growth_pct,
    ROUND((cp.unique_customers - pp.unique_customers) / NULLIF(pp.unique_customers, 0) * 100, 1) AS customer_growth_pct
FROM current_period cp
CROSS JOIN prior_period pp;

-- Dashboard 2: Sales by Category (Last 30 Days)
CREATE OR REPLACE VIEW VW_DASHBOARD_CATEGORY_SALES AS
SELECT 
    dp.CATEGORY_LEVEL1 AS category,
    COUNT(DISTINCT fs.PRODUCT_KEY) AS product_count,
    SUM(fs.QUANTITY_SOLD) AS units_sold,
    ROUND(SUM(fs.NET_SALES_AMOUNT), 2) AS total_sales,
    ROUND(SUM(fs.GROSS_PROFIT_AMOUNT), 2) AS gross_profit,
    ROUND(AVG(fs.GROSS_MARGIN_PERCENT), 1) AS margin_pct,
    ROUND(SUM(fs.NET_SALES_AMOUNT) / SUM(SUM(fs.NET_SALES_AMOUNT)) OVER () * 100, 1) AS pct_of_total
FROM FACT_SALES fs
JOIN DIM_PRODUCT dp ON fs.PRODUCT_KEY = dp.PRODUCT_KEY
JOIN DIM_DATE dd ON fs.DATE_KEY = dd.DATE_KEY
WHERE dd.DATE_ACTUAL >= DATEADD(day, -30, CURRENT_DATE())
  AND fs.TRANSACTION_TYPE = 'Sale'
  AND dp.IS_CURRENT = TRUE
GROUP BY dp.CATEGORY_LEVEL1
ORDER BY total_sales DESC;

-- Dashboard 3: Top 10 Stores
CREATE OR REPLACE VIEW VW_DASHBOARD_TOP_STORES AS
SELECT 
    STORE_NAME,
    CITY,
    STATE_PROVINCE,
    REGION,
    ROUND(total_sales, 2) AS total_sales,
    total_transactions,
    ROUND(avg_transaction_value, 2) AS avg_transaction,
    sales_rank
FROM VW_STORE_SALES_PERFORMANCE
WHERE sales_rank <= 10
ORDER BY sales_rank;

-- Dashboard 4: Sales Trend (Last 12 Weeks)
CREATE OR REPLACE VIEW VW_DASHBOARD_SALES_TREND AS
SELECT 
    YEAR_NUMBER,
    WEEK_OF_YEAR,
    week_start_date,
    ROUND(total_sales, 2) AS total_sales,
    transaction_count,
    unique_customers,
    ROUND(avg_transaction_value, 2) AS avg_transaction
FROM VW_WEEKLY_SALES_TRENDS
WHERE week_start_date >= DATEADD(week, -12, CURRENT_DATE())
ORDER BY YEAR_NUMBER, WEEK_OF_YEAR;

-- =====================================================
-- OPTIONAL: GRANT PERMISSIONS
-- =====================================================

-- Grant read access to analysts
-- Uncomment and modify as needed:

-- GRANT USAGE ON DATABASE RETAIL_DB TO ROLE ANALYST_ROLE;
-- GRANT USAGE ON SCHEMA RETAIL_DB.RETAIL_SCHEMA TO ROLE ANALYST_ROLE;
-- GRANT SELECT ON ALL TABLES IN SCHEMA RETAIL_DB.RETAIL_SCHEMA TO ROLE ANALYST_ROLE;
-- GRANT SELECT ON ALL VIEWS IN SCHEMA RETAIL_DB.RETAIL_SCHEMA TO ROLE ANALYST_ROLE;
-- GRANT SELECT ON FUTURE TABLES IN SCHEMA RETAIL_DB.RETAIL_SCHEMA TO ROLE ANALYST_ROLE;
-- GRANT SELECT ON FUTURE VIEWS IN SCHEMA RETAIL_DB.RETAIL_SCHEMA TO ROLE ANALYST_ROLE;

-- =====================================================
-- END OF QUICK START SETUP
-- =====================================================



