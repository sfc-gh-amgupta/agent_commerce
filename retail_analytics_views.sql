-- =====================================================
-- RETAIL DATA MODEL - ANALYTICAL VIEWS
-- =====================================================
-- Description: Pre-built analytical views for common retail queries
-- Platform: Snowflake
-- =====================================================

USE DATABASE RETAIL_DB;
USE SCHEMA RETAIL_SCHEMA;

-- =====================================================
-- SALES ANALYTICS VIEWS
-- =====================================================

-- View: Daily Sales Summary
CREATE OR REPLACE VIEW VW_DAILY_SALES_SUMMARY AS
SELECT 
    dd.DATE_ACTUAL,
    dd.DAY_NAME,
    dd.WEEK_OF_YEAR,
    dd.MONTH_NAME,
    dd.QUARTER_NAME,
    dd.YEAR_NUMBER,
    dd.IS_WEEKEND,
    dd.IS_HOLIDAY,
    COUNT(DISTINCT fs.TRANSACTION_ID) AS transaction_count,
    COUNT(DISTINCT fs.CUSTOMER_KEY) AS unique_customers,
    SUM(fs.QUANTITY_SOLD) AS total_units_sold,
    SUM(fs.EXTENDED_PRICE) AS total_extended_price,
    SUM(fs.DISCOUNT_AMOUNT) AS total_discounts,
    SUM(fs.TAX_AMOUNT) AS total_tax,
    SUM(fs.NET_SALES_AMOUNT) AS total_net_sales,
    SUM(fs.GROSS_PROFIT_AMOUNT) AS total_gross_profit,
    AVG(fs.GROSS_MARGIN_PERCENT) AS avg_gross_margin_pct,
    SUM(fs.NET_SALES_AMOUNT) / NULLIF(COUNT(DISTINCT fs.TRANSACTION_ID), 0) AS avg_transaction_value,
    SUM(fs.QUANTITY_SOLD) / NULLIF(COUNT(DISTINCT fs.TRANSACTION_ID), 0) AS avg_units_per_transaction
FROM FACT_SALES fs
JOIN DIM_DATE dd ON fs.DATE_KEY = dd.DATE_KEY
WHERE fs.TRANSACTION_TYPE = 'Sale'
GROUP BY 
    dd.DATE_ACTUAL,
    dd.DAY_NAME,
    dd.WEEK_OF_YEAR,
    dd.MONTH_NAME,
    dd.QUARTER_NAME,
    dd.YEAR_NUMBER,
    dd.IS_WEEKEND,
    dd.IS_HOLIDAY;

-- View: Sales by Store Performance
CREATE OR REPLACE VIEW VW_STORE_SALES_PERFORMANCE AS
SELECT 
    ds.STORE_ID,
    ds.STORE_NAME,
    ds.STORE_TYPE,
    ds.CITY,
    ds.STATE_PROVINCE,
    ds.REGION,
    ds.DISTRICT,
    COUNT(DISTINCT fs.TRANSACTION_ID) AS total_transactions,
    COUNT(DISTINCT fs.CUSTOMER_KEY) AS unique_customers,
    SUM(fs.QUANTITY_SOLD) AS total_units_sold,
    SUM(fs.NET_SALES_AMOUNT) AS total_sales,
    SUM(fs.GROSS_PROFIT_AMOUNT) AS total_gross_profit,
    AVG(fs.GROSS_MARGIN_PERCENT) AS avg_gross_margin_pct,
    SUM(fs.NET_SALES_AMOUNT) / NULLIF(ds.STORE_SIZE_SQFT, 0) AS sales_per_sqft,
    RANK() OVER (ORDER BY SUM(fs.NET_SALES_AMOUNT) DESC) AS sales_rank
FROM FACT_SALES fs
JOIN DIM_STORE ds ON fs.STORE_KEY = ds.STORE_KEY
WHERE fs.TRANSACTION_TYPE = 'Sale'
  AND ds.IS_CURRENT = TRUE
GROUP BY 
    ds.STORE_ID,
    ds.STORE_NAME,
    ds.STORE_TYPE,
    ds.CITY,
    ds.STATE_PROVINCE,
    ds.REGION,
    ds.DISTRICT,
    ds.STORE_SIZE_SQFT;

-- View: Product Sales Performance
CREATE OR REPLACE VIEW VW_PRODUCT_SALES_PERFORMANCE AS
SELECT 
    dp.PRODUCT_ID,
    dp.PRODUCT_NAME,
    dp.SKU,
    dp.CATEGORY_LEVEL1,
    dp.CATEGORY_LEVEL2,
    dp.CATEGORY_LEVEL3,
    dp.BRAND,
    dp.LIST_PRICE,
    SUM(fs.QUANTITY_SOLD) AS total_quantity_sold,
    SUM(fs.NET_SALES_AMOUNT) AS total_sales,
    SUM(fs.GROSS_PROFIT_AMOUNT) AS total_gross_profit,
    AVG(fs.GROSS_MARGIN_PERCENT) AS avg_gross_margin_pct,
    COUNT(DISTINCT fs.TRANSACTION_ID) AS transaction_count,
    COUNT(DISTINCT fs.CUSTOMER_KEY) AS unique_customers,
    SUM(fs.NET_SALES_AMOUNT) / NULLIF(SUM(fs.QUANTITY_SOLD), 0) AS avg_selling_price,
    RANK() OVER (ORDER BY SUM(fs.NET_SALES_AMOUNT) DESC) AS sales_rank,
    RANK() OVER (ORDER BY SUM(fs.QUANTITY_SOLD) DESC) AS quantity_rank
FROM FACT_SALES fs
JOIN DIM_PRODUCT dp ON fs.PRODUCT_KEY = dp.PRODUCT_KEY
WHERE fs.TRANSACTION_TYPE = 'Sale'
  AND dp.IS_CURRENT = TRUE
GROUP BY 
    dp.PRODUCT_ID,
    dp.PRODUCT_NAME,
    dp.SKU,
    dp.CATEGORY_LEVEL1,
    dp.CATEGORY_LEVEL2,
    dp.CATEGORY_LEVEL3,
    dp.BRAND,
    dp.LIST_PRICE;

-- View: Sales by Category Hierarchy
CREATE OR REPLACE VIEW VW_CATEGORY_SALES_PERFORMANCE AS
SELECT 
    dp.CATEGORY_LEVEL1 AS department,
    dp.CATEGORY_LEVEL2 AS category,
    dp.CATEGORY_LEVEL3 AS subcategory,
    COUNT(DISTINCT dp.PRODUCT_KEY) AS product_count,
    SUM(fs.QUANTITY_SOLD) AS total_units_sold,
    SUM(fs.NET_SALES_AMOUNT) AS total_sales,
    SUM(fs.GROSS_PROFIT_AMOUNT) AS total_gross_profit,
    AVG(fs.GROSS_MARGIN_PERCENT) AS avg_gross_margin_pct,
    COUNT(DISTINCT fs.TRANSACTION_ID) AS transaction_count,
    SUM(fs.NET_SALES_AMOUNT) / NULLIF(COUNT(DISTINCT fs.TRANSACTION_ID), 0) AS avg_basket_size
FROM FACT_SALES fs
JOIN DIM_PRODUCT dp ON fs.PRODUCT_KEY = dp.PRODUCT_KEY
WHERE fs.TRANSACTION_TYPE = 'Sale'
  AND dp.IS_CURRENT = TRUE
GROUP BY 
    dp.CATEGORY_LEVEL1,
    dp.CATEGORY_LEVEL2,
    dp.CATEGORY_LEVEL3;

-- View: Promotion Effectiveness
CREATE OR REPLACE VIEW VW_PROMOTION_EFFECTIVENESS AS
SELECT 
    dp.PROMOTION_ID,
    dp.PROMOTION_NAME,
    dp.PROMOTION_TYPE,
    dp.PROMOTION_CATEGORY,
    dp.DISCOUNT_PERCENT,
    dp.START_DATE,
    dp.END_DATE,
    COUNT(DISTINCT fs.TRANSACTION_ID) AS transactions_with_promo,
    COUNT(DISTINCT fs.CUSTOMER_KEY) AS unique_customers,
    SUM(fs.QUANTITY_SOLD) AS total_units_sold,
    SUM(fs.EXTENDED_PRICE) AS total_extended_price,
    SUM(fs.DISCOUNT_AMOUNT) AS total_discount_given,
    SUM(fs.NET_SALES_AMOUNT) AS total_net_sales,
    SUM(fs.GROSS_PROFIT_AMOUNT) AS total_gross_profit,
    AVG(fs.DISCOUNT_AMOUNT / NULLIF(fs.EXTENDED_PRICE, 0) * 100) AS avg_discount_pct,
    SUM(fs.NET_SALES_AMOUNT) / NULLIF(SUM(fs.DISCOUNT_AMOUNT), 0) AS sales_to_discount_ratio
FROM FACT_SALES fs
JOIN DIM_PROMOTION dp ON fs.PROMOTION_KEY = dp.PROMOTION_KEY
WHERE fs.TRANSACTION_TYPE = 'Sale'
GROUP BY 
    dp.PROMOTION_ID,
    dp.PROMOTION_NAME,
    dp.PROMOTION_TYPE,
    dp.PROMOTION_CATEGORY,
    dp.DISCOUNT_PERCENT,
    dp.START_DATE,
    dp.END_DATE;

-- View: Channel Performance
CREATE OR REPLACE VIEW VW_CHANNEL_PERFORMANCE AS
SELECT 
    fs.CHANNEL,
    dd.YEAR_NUMBER,
    dd.QUARTER_NAME,
    dd.MONTH_NAME,
    COUNT(DISTINCT fs.TRANSACTION_ID) AS transaction_count,
    COUNT(DISTINCT fs.CUSTOMER_KEY) AS unique_customers,
    SUM(fs.QUANTITY_SOLD) AS total_units_sold,
    SUM(fs.NET_SALES_AMOUNT) AS total_sales,
    SUM(fs.GROSS_PROFIT_AMOUNT) AS total_gross_profit,
    AVG(fs.GROSS_MARGIN_PERCENT) AS avg_gross_margin_pct,
    SUM(fs.NET_SALES_AMOUNT) / NULLIF(COUNT(DISTINCT fs.TRANSACTION_ID), 0) AS avg_order_value
FROM FACT_SALES fs
JOIN DIM_DATE dd ON fs.DATE_KEY = dd.DATE_KEY
WHERE fs.TRANSACTION_TYPE = 'Sale'
GROUP BY 
    fs.CHANNEL,
    dd.YEAR_NUMBER,
    dd.QUARTER_NAME,
    dd.MONTH_NAME;

-- =====================================================
-- CUSTOMER ANALYTICS VIEWS
-- =====================================================

-- View: Customer Lifetime Value Analysis
CREATE OR REPLACE VIEW VW_CUSTOMER_LIFETIME_VALUE AS
SELECT 
    dc.CUSTOMER_ID,
    dc.FIRST_NAME,
    dc.LAST_NAME,
    dc.EMAIL,
    dc.CUSTOMER_SEGMENT,
    dc.LOYALTY_TIER,
    dc.REGISTRATION_DATE,
    dc.CITY,
    dc.STATE_PROVINCE,
    COUNT(DISTINCT fs.TRANSACTION_ID) AS total_transactions,
    SUM(fs.QUANTITY_SOLD) AS total_units_purchased,
    SUM(fs.NET_SALES_AMOUNT) AS total_lifetime_value,
    AVG(fs.NET_SALES_AMOUNT) AS avg_transaction_value,
    MIN(dd.DATE_ACTUAL) AS first_purchase_date,
    MAX(dd.DATE_ACTUAL) AS last_purchase_date,
    DATEDIFF(day, MIN(dd.DATE_ACTUAL), MAX(dd.DATE_ACTUAL)) AS customer_tenure_days,
    SUM(fs.NET_SALES_AMOUNT) / NULLIF(COUNT(DISTINCT fs.TRANSACTION_ID), 0) AS avg_order_value,
    COUNT(DISTINCT fs.TRANSACTION_ID) / NULLIF(DATEDIFF(month, MIN(dd.DATE_ACTUAL), MAX(dd.DATE_ACTUAL)), 0) AS avg_orders_per_month
FROM DIM_CUSTOMER dc
LEFT JOIN FACT_SALES fs ON dc.CUSTOMER_KEY = fs.CUSTOMER_KEY
LEFT JOIN DIM_DATE dd ON fs.DATE_KEY = dd.DATE_KEY
WHERE dc.IS_CURRENT = TRUE
  AND (fs.TRANSACTION_TYPE = 'Sale' OR fs.TRANSACTION_TYPE IS NULL)
GROUP BY 
    dc.CUSTOMER_ID,
    dc.FIRST_NAME,
    dc.LAST_NAME,
    dc.EMAIL,
    dc.CUSTOMER_SEGMENT,
    dc.LOYALTY_TIER,
    dc.REGISTRATION_DATE,
    dc.CITY,
    dc.STATE_PROVINCE;

-- View: Customer Segmentation RFM (Recency, Frequency, Monetary)
CREATE OR REPLACE VIEW VW_CUSTOMER_RFM_ANALYSIS AS
WITH customer_metrics AS (
    SELECT 
        fs.CUSTOMER_KEY,
        MAX(dd.DATE_ACTUAL) AS last_purchase_date,
        COUNT(DISTINCT fs.TRANSACTION_ID) AS frequency,
        SUM(fs.NET_SALES_AMOUNT) AS monetary_value
    FROM FACT_SALES fs
    JOIN DIM_DATE dd ON fs.DATE_KEY = dd.DATE_KEY
    WHERE fs.TRANSACTION_TYPE = 'Sale'
    GROUP BY fs.CUSTOMER_KEY
),
rfm_scores AS (
    SELECT 
        CUSTOMER_KEY,
        DATEDIFF(day, last_purchase_date, CURRENT_DATE()) AS recency_days,
        frequency,
        monetary_value,
        NTILE(5) OVER (ORDER BY DATEDIFF(day, last_purchase_date, CURRENT_DATE()) DESC) AS recency_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS frequency_score,
        NTILE(5) OVER (ORDER BY monetary_value ASC) AS monetary_score
    FROM customer_metrics
)
SELECT 
    dc.CUSTOMER_ID,
    dc.FIRST_NAME,
    dc.LAST_NAME,
    dc.EMAIL,
    dc.CUSTOMER_SEGMENT,
    rs.recency_days,
    rs.frequency,
    rs.monetary_value,
    rs.recency_score,
    rs.frequency_score,
    rs.monetary_score,
    (rs.recency_score + rs.frequency_score + rs.monetary_score) AS rfm_total_score,
    CASE 
        WHEN rs.recency_score >= 4 AND rs.frequency_score >= 4 AND rs.monetary_score >= 4 THEN 'Champions'
        WHEN rs.recency_score >= 3 AND rs.frequency_score >= 3 THEN 'Loyal Customers'
        WHEN rs.recency_score >= 4 AND rs.frequency_score <= 2 THEN 'New Customers'
        WHEN rs.recency_score >= 3 AND rs.monetary_score >= 3 THEN 'Potential Loyalists'
        WHEN rs.recency_score <= 2 AND rs.frequency_score >= 3 THEN 'At Risk'
        WHEN rs.recency_score <= 2 AND rs.frequency_score <= 2 THEN 'Lost Customers'
        ELSE 'Needs Attention'
    END AS customer_segment_rfm
FROM rfm_scores rs
JOIN DIM_CUSTOMER dc ON rs.CUSTOMER_KEY = dc.CUSTOMER_KEY
WHERE dc.IS_CURRENT = TRUE;

-- View: Customer Purchase Patterns by Time
CREATE OR REPLACE VIEW VW_CUSTOMER_PURCHASE_PATTERNS AS
SELECT 
    fs.CUSTOMER_KEY,
    dc.CUSTOMER_ID,
    dc.CUSTOMER_SEGMENT,
    dd.DAY_NAME,
    dd.IS_WEEKEND,
    dt.TIME_PERIOD,
    dt.HOUR_24,
    COUNT(DISTINCT fs.TRANSACTION_ID) AS transaction_count,
    SUM(fs.NET_SALES_AMOUNT) AS total_sales,
    AVG(fs.NET_SALES_AMOUNT) AS avg_transaction_value
FROM FACT_SALES fs
JOIN DIM_CUSTOMER dc ON fs.CUSTOMER_KEY = dc.CUSTOMER_KEY
JOIN DIM_DATE dd ON fs.DATE_KEY = dd.DATE_KEY
JOIN DIM_TIME dt ON fs.TIME_KEY = dt.TIME_KEY
WHERE fs.TRANSACTION_TYPE = 'Sale'
  AND dc.IS_CURRENT = TRUE
GROUP BY 
    fs.CUSTOMER_KEY,
    dc.CUSTOMER_ID,
    dc.CUSTOMER_SEGMENT,
    dd.DAY_NAME,
    dd.IS_WEEKEND,
    dt.TIME_PERIOD,
    dt.HOUR_24;

-- =====================================================
-- INVENTORY ANALYTICS VIEWS
-- =====================================================

-- View: Current Inventory Status
CREATE OR REPLACE VIEW VW_CURRENT_INVENTORY_STATUS AS
WITH latest_snapshot AS (
    SELECT 
        PRODUCT_KEY,
        STORE_KEY,
        MAX(SNAPSHOT_DATE) AS latest_date
    FROM FACT_INVENTORY
    GROUP BY PRODUCT_KEY, STORE_KEY
)
SELECT 
    dp.PRODUCT_ID,
    dp.PRODUCT_NAME,
    dp.SKU,
    dp.CATEGORY_LEVEL1,
    dp.BRAND,
    ds.STORE_ID,
    ds.STORE_NAME,
    ds.CITY,
    ds.STATE_PROVINCE,
    fi.SNAPSHOT_DATE,
    fi.ENDING_ON_HAND_QUANTITY,
    fi.REORDER_POINT,
    fi.SAFETY_STOCK_QUANTITY,
    fi.INVENTORY_VALUE,
    fi.DAYS_OF_SUPPLY,
    fi.STOCK_STATUS,
    CASE 
        WHEN fi.ENDING_ON_HAND_QUANTITY <= fi.SAFETY_STOCK_QUANTITY THEN 'Critical'
        WHEN fi.ENDING_ON_HAND_QUANTITY <= fi.REORDER_POINT THEN 'Reorder'
        ELSE 'Adequate'
    END AS inventory_alert
FROM FACT_INVENTORY fi
JOIN DIM_PRODUCT dp ON fi.PRODUCT_KEY = dp.PRODUCT_KEY
JOIN DIM_STORE ds ON fi.STORE_KEY = ds.STORE_KEY
JOIN latest_snapshot ls ON fi.PRODUCT_KEY = ls.PRODUCT_KEY 
                        AND fi.STORE_KEY = ls.STORE_KEY 
                        AND fi.SNAPSHOT_DATE = ls.latest_date
WHERE dp.IS_CURRENT = TRUE
  AND ds.IS_CURRENT = TRUE;

-- View: Inventory Turnover Analysis
CREATE OR REPLACE VIEW VW_INVENTORY_TURNOVER AS
WITH inventory_metrics AS (
    SELECT 
        fi.PRODUCT_KEY,
        fi.STORE_KEY,
        AVG(fi.ENDING_ON_HAND_QUANTITY) AS avg_inventory,
        SUM(fi.SALES_QUANTITY) AS total_units_sold
    FROM FACT_INVENTORY fi
    WHERE fi.SNAPSHOT_DATE >= DATEADD(month, -3, CURRENT_DATE())
    GROUP BY fi.PRODUCT_KEY, fi.STORE_KEY
)
SELECT 
    dp.PRODUCT_ID,
    dp.PRODUCT_NAME,
    dp.CATEGORY_LEVEL1,
    dp.CATEGORY_LEVEL2,
    ds.STORE_ID,
    ds.STORE_NAME,
    im.avg_inventory,
    im.total_units_sold,
    CASE 
        WHEN im.avg_inventory > 0 THEN ROUND(im.total_units_sold / im.avg_inventory, 2)
        ELSE 0 
    END AS inventory_turnover_ratio,
    CASE 
        WHEN im.total_units_sold > 0 THEN ROUND(90 * im.avg_inventory / im.total_units_sold, 1)
        ELSE NULL 
    END AS days_inventory_on_hand
FROM inventory_metrics im
JOIN DIM_PRODUCT dp ON im.PRODUCT_KEY = dp.PRODUCT_KEY
JOIN DIM_STORE ds ON im.STORE_KEY = ds.STORE_KEY
WHERE dp.IS_CURRENT = TRUE
  AND ds.IS_CURRENT = TRUE;

-- View: Stock-Out Analysis
CREATE OR REPLACE VIEW VW_STOCKOUT_ANALYSIS AS
SELECT 
    dp.PRODUCT_ID,
    dp.PRODUCT_NAME,
    dp.CATEGORY_LEVEL1,
    ds.STORE_ID,
    ds.STORE_NAME,
    COUNT(*) AS stockout_days,
    MIN(fi.SNAPSHOT_DATE) AS first_stockout_date,
    MAX(fi.SNAPSHOT_DATE) AS last_stockout_date,
    SUM(fi.INVENTORY_VALUE) AS lost_inventory_value
FROM FACT_INVENTORY fi
JOIN DIM_PRODUCT dp ON fi.PRODUCT_KEY = dp.PRODUCT_KEY
JOIN DIM_STORE ds ON fi.STORE_KEY = ds.STORE_KEY
WHERE fi.STOCK_STATUS = 'Out of Stock'
  AND dp.IS_CURRENT = TRUE
  AND ds.IS_CURRENT = TRUE
  AND fi.SNAPSHOT_DATE >= DATEADD(month, -6, CURRENT_DATE())
GROUP BY 
    dp.PRODUCT_ID,
    dp.PRODUCT_NAME,
    dp.CATEGORY_LEVEL1,
    ds.STORE_ID,
    ds.STORE_NAME
HAVING COUNT(*) > 0
ORDER BY stockout_days DESC;

-- =====================================================
-- EMPLOYEE PERFORMANCE VIEWS
-- =====================================================

-- View: Employee Sales Performance
CREATE OR REPLACE VIEW VW_EMPLOYEE_SALES_PERFORMANCE AS
SELECT 
    de.EMPLOYEE_ID,
    de.FIRST_NAME,
    de.LAST_NAME,
    de.JOB_TITLE,
    de.DEPARTMENT,
    ds.STORE_NAME,
    COUNT(DISTINCT fs.TRANSACTION_ID) AS transactions_assisted,
    COUNT(DISTINCT fs.CUSTOMER_KEY) AS unique_customers_served,
    SUM(fs.NET_SALES_AMOUNT) AS total_sales,
    SUM(fs.GROSS_PROFIT_AMOUNT) AS total_gross_profit,
    AVG(fs.NET_SALES_AMOUNT) AS avg_sale_amount,
    SUM(fs.NET_SALES_AMOUNT) / NULLIF(COUNT(DISTINCT fs.TRANSACTION_ID), 0) AS avg_transaction_value,
    RANK() OVER (PARTITION BY ds.STORE_KEY ORDER BY SUM(fs.NET_SALES_AMOUNT) DESC) AS store_rank
FROM FACT_SALES fs
JOIN DIM_EMPLOYEE de ON fs.EMPLOYEE_KEY = de.EMPLOYEE_KEY
JOIN DIM_STORE ds ON fs.STORE_KEY = ds.STORE_KEY
WHERE fs.TRANSACTION_TYPE = 'Sale'
  AND de.IS_CURRENT = TRUE
  AND ds.IS_CURRENT = TRUE
GROUP BY 
    de.EMPLOYEE_ID,
    de.FIRST_NAME,
    de.LAST_NAME,
    de.JOB_TITLE,
    de.DEPARTMENT,
    ds.STORE_NAME,
    ds.STORE_KEY;

-- =====================================================
-- TREND ANALYSIS VIEWS
-- =====================================================

-- View: Year-over-Year Sales Comparison
CREATE OR REPLACE VIEW VW_YOY_SALES_COMPARISON AS
WITH current_year AS (
    SELECT 
        dd.MONTH_NUMBER,
        dd.MONTH_NAME,
        dd.YEAR_NUMBER,
        SUM(fs.NET_SALES_AMOUNT) AS total_sales,
        SUM(fs.QUANTITY_SOLD) AS total_units,
        COUNT(DISTINCT fs.TRANSACTION_ID) AS transaction_count
    FROM FACT_SALES fs
    JOIN DIM_DATE dd ON fs.DATE_KEY = dd.DATE_KEY
    WHERE fs.TRANSACTION_TYPE = 'Sale'
    GROUP BY dd.MONTH_NUMBER, dd.MONTH_NAME, dd.YEAR_NUMBER
)
SELECT 
    cy.YEAR_NUMBER AS current_year,
    cy.MONTH_NUMBER,
    cy.MONTH_NAME,
    cy.total_sales AS current_year_sales,
    cy.total_units AS current_year_units,
    cy.transaction_count AS current_year_transactions,
    py.total_sales AS prior_year_sales,
    py.total_units AS prior_year_units,
    py.transaction_count AS prior_year_transactions,
    ROUND((cy.total_sales - py.total_sales) / NULLIF(py.total_sales, 0) * 100, 2) AS sales_growth_pct,
    ROUND((cy.total_units - py.total_units) / NULLIF(py.total_units, 0) * 100, 2) AS units_growth_pct,
    ROUND((cy.transaction_count - py.transaction_count) / NULLIF(py.transaction_count, 0) * 100, 2) AS transaction_growth_pct
FROM current_year cy
LEFT JOIN current_year py 
    ON cy.MONTH_NUMBER = py.MONTH_NUMBER 
    AND cy.YEAR_NUMBER = py.YEAR_NUMBER + 1
ORDER BY cy.YEAR_NUMBER, cy.MONTH_NUMBER;

-- View: Sales Trends by Week
CREATE OR REPLACE VIEW VW_WEEKLY_SALES_TRENDS AS
SELECT 
    dd.YEAR_NUMBER,
    dd.WEEK_OF_YEAR,
    MIN(dd.DATE_ACTUAL) AS week_start_date,
    MAX(dd.DATE_ACTUAL) AS week_end_date,
    COUNT(DISTINCT fs.TRANSACTION_ID) AS transaction_count,
    COUNT(DISTINCT fs.CUSTOMER_KEY) AS unique_customers,
    SUM(fs.QUANTITY_SOLD) AS total_units_sold,
    SUM(fs.NET_SALES_AMOUNT) AS total_sales,
    SUM(fs.GROSS_PROFIT_AMOUNT) AS total_gross_profit,
    AVG(fs.NET_SALES_AMOUNT) AS avg_transaction_value,
    SUM(fs.NET_SALES_AMOUNT) / 7 AS avg_daily_sales
FROM FACT_SALES fs
JOIN DIM_DATE dd ON fs.DATE_KEY = dd.DATE_KEY
WHERE fs.TRANSACTION_TYPE = 'Sale'
GROUP BY dd.YEAR_NUMBER, dd.WEEK_OF_YEAR
ORDER BY dd.YEAR_NUMBER, dd.WEEK_OF_YEAR;

-- =====================================================
-- FINANCIAL SUMMARY VIEWS
-- =====================================================

-- View: Financial Summary by Period
CREATE OR REPLACE VIEW VW_FINANCIAL_SUMMARY AS
SELECT 
    dd.YEAR_NUMBER AS fiscal_year,
    dd.QUARTER_NAME AS fiscal_quarter,
    dd.MONTH_NAME AS fiscal_month,
    -- Revenue
    SUM(fs.EXTENDED_PRICE) AS gross_revenue,
    SUM(fs.DISCOUNT_AMOUNT) AS total_discounts,
    SUM(fs.NET_SALES_AMOUNT) - SUM(fs.TAX_AMOUNT) AS net_revenue,
    SUM(fs.TAX_AMOUNT) AS total_tax_collected,
    -- Costs
    SUM(fs.UNIT_COST * fs.QUANTITY_SOLD) AS cost_of_goods_sold,
    -- Profit
    SUM(fs.GROSS_PROFIT_AMOUNT) AS gross_profit,
    ROUND(SUM(fs.GROSS_PROFIT_AMOUNT) / NULLIF(SUM(fs.NET_SALES_AMOUNT) - SUM(fs.TAX_AMOUNT), 0) * 100, 2) AS gross_margin_pct,
    -- Volume
    SUM(fs.QUANTITY_SOLD) AS total_units_sold,
    COUNT(DISTINCT fs.TRANSACTION_ID) AS total_transactions,
    COUNT(DISTINCT fs.CUSTOMER_KEY) AS unique_customers,
    -- Averages
    SUM(fs.NET_SALES_AMOUNT) / NULLIF(COUNT(DISTINCT fs.TRANSACTION_ID), 0) AS avg_transaction_value,
    SUM(fs.NET_SALES_AMOUNT) / NULLIF(COUNT(DISTINCT fs.CUSTOMER_KEY), 0) AS avg_revenue_per_customer
FROM FACT_SALES fs
JOIN DIM_DATE dd ON fs.DATE_KEY = dd.DATE_KEY
WHERE fs.TRANSACTION_TYPE = 'Sale'
GROUP BY 
    dd.YEAR_NUMBER,
    dd.QUARTER_NAME,
    dd.MONTH_NAME,
    dd.QUARTER_NUMBER,
    dd.MONTH_NUMBER
ORDER BY 
    dd.YEAR_NUMBER,
    dd.QUARTER_NUMBER,
    dd.MONTH_NUMBER;

-- =====================================================
-- MARKET BASKET ANALYSIS VIEW
-- =====================================================

-- View: Product Affinity (Products frequently bought together)
CREATE OR REPLACE VIEW VW_PRODUCT_AFFINITY AS
WITH transaction_products AS (
    SELECT 
        fs1.TRANSACTION_ID,
        fs1.PRODUCT_KEY AS product_key_1,
        fs2.PRODUCT_KEY AS product_key_2
    FROM FACT_SALES fs1
    JOIN FACT_SALES fs2 
        ON fs1.TRANSACTION_ID = fs2.TRANSACTION_ID 
        AND fs1.PRODUCT_KEY < fs2.PRODUCT_KEY
    WHERE fs1.TRANSACTION_TYPE = 'Sale'
      AND fs2.TRANSACTION_TYPE = 'Sale'
)
SELECT 
    dp1.PRODUCT_ID AS product_1_id,
    dp1.PRODUCT_NAME AS product_1_name,
    dp1.CATEGORY_LEVEL1 AS product_1_category,
    dp2.PRODUCT_ID AS product_2_id,
    dp2.PRODUCT_NAME AS product_2_name,
    dp2.CATEGORY_LEVEL1 AS product_2_category,
    COUNT(*) AS times_purchased_together,
    COUNT(*) * 1.0 / (
        SELECT COUNT(DISTINCT TRANSACTION_ID) 
        FROM FACT_SALES 
        WHERE TRANSACTION_TYPE = 'Sale'
    ) * 100 AS support_percentage
FROM transaction_products tp
JOIN DIM_PRODUCT dp1 ON tp.product_key_1 = dp1.PRODUCT_KEY
JOIN DIM_PRODUCT dp2 ON tp.product_key_2 = dp2.PRODUCT_KEY
WHERE dp1.IS_CURRENT = TRUE
  AND dp2.IS_CURRENT = TRUE
GROUP BY 
    dp1.PRODUCT_ID,
    dp1.PRODUCT_NAME,
    dp1.CATEGORY_LEVEL1,
    dp2.PRODUCT_ID,
    dp2.PRODUCT_NAME,
    dp2.CATEGORY_LEVEL1
HAVING COUNT(*) >= 5  -- Only show products purchased together at least 5 times
ORDER BY times_purchased_together DESC
LIMIT 1000;

-- =====================================================
-- DOCUMENTATION
-- =====================================================

COMMENT ON VIEW VW_DAILY_SALES_SUMMARY IS 'Daily sales summary with key metrics by date';
COMMENT ON VIEW VW_STORE_SALES_PERFORMANCE IS 'Store-level sales performance and rankings';
COMMENT ON VIEW VW_PRODUCT_SALES_PERFORMANCE IS 'Product-level sales performance and rankings';
COMMENT ON VIEW VW_CATEGORY_SALES_PERFORMANCE IS 'Sales performance by product category hierarchy';
COMMENT ON VIEW VW_PROMOTION_EFFECTIVENESS IS 'Promotion effectiveness and ROI analysis';
COMMENT ON VIEW VW_CHANNEL_PERFORMANCE IS 'Sales performance by channel (In-Store, Online, Mobile)';
COMMENT ON VIEW VW_CUSTOMER_LIFETIME_VALUE IS 'Customer lifetime value and purchase history';
COMMENT ON VIEW VW_CUSTOMER_RFM_ANALYSIS IS 'Customer segmentation using RFM (Recency, Frequency, Monetary) analysis';
COMMENT ON VIEW VW_CUSTOMER_PURCHASE_PATTERNS IS 'Customer purchase patterns by time of day and day of week';
COMMENT ON VIEW VW_CURRENT_INVENTORY_STATUS IS 'Current inventory status with reorder alerts';
COMMENT ON VIEW VW_INVENTORY_TURNOVER IS 'Inventory turnover and days on hand analysis';
COMMENT ON VIEW VW_STOCKOUT_ANALYSIS IS 'Stock-out history and lost sales analysis';
COMMENT ON VIEW VW_EMPLOYEE_SALES_PERFORMANCE IS 'Employee sales performance and rankings';
COMMENT ON VIEW VW_YOY_SALES_COMPARISON IS 'Year-over-year sales comparison by month';
COMMENT ON VIEW VW_WEEKLY_SALES_TRENDS IS 'Weekly sales trends and metrics';
COMMENT ON VIEW VW_FINANCIAL_SUMMARY IS 'Financial summary by year/quarter/month';
COMMENT ON VIEW VW_PRODUCT_AFFINITY IS 'Market basket analysis - products frequently purchased together';

-- =====================================================
-- END OF ANALYTICAL VIEWS
-- =====================================================



