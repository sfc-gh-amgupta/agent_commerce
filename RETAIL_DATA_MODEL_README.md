# Retail Data Model Documentation

## Overview

This is a comprehensive retail data model designed for Snowflake, implementing a dimensional modeling approach (Star Schema) optimized for analytical queries and business intelligence reporting.

## Architecture

### Model Type
- **Star Schema** - Dimensional model with fact tables at the center surrounded by dimension tables
- **Platform**: Snowflake
- **Database**: `RETAIL_DB`
- **Schema**: `RETAIL_SCHEMA`

### Design Principles
1. **Dimensional Modeling**: Uses Kimball methodology with star schema design
2. **Slowly Changing Dimensions (SCD)**: Type 2 implementation for historical tracking
3. **Grain Clarity**: Each fact table has a clearly defined grain
4. **Additive Facts**: Metrics are designed to be aggregatable
5. **Snowflake Optimization**: Leverages Snowflake features like clustering and micro-partitions

---

## Database Objects

### Dimension Tables (9 tables)

#### 1. DIM_DATE
- **Purpose**: Calendar dimension for date-based analysis
- **Grain**: One row per day
- **Key Features**:
  - 3 years of calendar data
  - Fiscal calendar attributes
  - Holiday flags
  - Weekend indicators
- **Key Columns**: DATE_KEY (PK), DATE_ACTUAL, YEAR_NUMBER, QUARTER_NUMBER, MONTH_NAME, IS_WEEKEND, IS_HOLIDAY

#### 2. DIM_TIME
- **Purpose**: Time dimension for intraday analysis
- **Grain**: One row per 15-minute interval
- **Key Features**:
  - 24-hour coverage at 15-minute granularity
  - Time period classification (Morning, Afternoon, Evening, Night)
  - 12-hour and 24-hour formats
- **Key Columns**: TIME_KEY (PK), TIME_ACTUAL, HOUR_24, TIME_PERIOD

#### 3. DIM_CUSTOMER
- **Purpose**: Customer master data
- **Grain**: One row per customer per version
- **SCD Type**: Type 2 (Historical tracking)
- **Key Features**:
  - Complete customer demographics
  - Loyalty program information
  - Marketing preferences
  - Address information
  - Lifetime value tracking
- **Key Columns**: CUSTOMER_KEY (PK), CUSTOMER_ID (Business Key), FIRST_NAME, LAST_NAME, EMAIL, CUSTOMER_SEGMENT, LOYALTY_TIER, EFFECTIVE_DATE, EXPIRATION_DATE, IS_CURRENT

#### 4. DIM_PRODUCT
- **Purpose**: Product catalog master
- **Grain**: One row per product per version
- **SCD Type**: Type 2 (Historical tracking)
- **Key Features**:
  - 3-level category hierarchy (Department → Category → Subcategory)
  - Product attributes (size, color, weight)
  - Pricing information
  - Brand and manufacturer details
- **Key Columns**: PRODUCT_KEY (PK), PRODUCT_ID (Business Key), PRODUCT_NAME, SKU, CATEGORY_LEVEL1, CATEGORY_LEVEL2, CATEGORY_LEVEL3, BRAND, LIST_PRICE, EFFECTIVE_DATE, IS_CURRENT

#### 5. DIM_STORE
- **Purpose**: Store/location master
- **Grain**: One row per store per version
- **SCD Type**: Type 2 (Historical tracking)
- **Key Features**:
  - Store type and format classification
  - Geographic location (lat/long)
  - Regional hierarchy (Region → District → Territory)
  - Store size and opening date
- **Key Columns**: STORE_KEY (PK), STORE_ID (Business Key), STORE_NAME, STORE_TYPE, CITY, STATE_PROVINCE, REGION, DISTRICT, EFFECTIVE_DATE, IS_CURRENT

#### 6. DIM_PROMOTION
- **Purpose**: Marketing promotions and discounts
- **Grain**: One row per promotion
- **Key Features**:
  - Promotion type classification
  - Discount details (percentage or amount)
  - Date range validity
  - Promotion scope (store-wide, online-only)
- **Key Columns**: PROMOTION_KEY (PK), PROMOTION_ID (Business Key), PROMOTION_NAME, PROMOTION_TYPE, DISCOUNT_PERCENT, START_DATE, END_DATE

#### 7. DIM_PAYMENT_METHOD
- **Purpose**: Payment methods catalog
- **Grain**: One row per payment method
- **Key Features**:
  - Payment type classification
  - Payment processor information
- **Key Columns**: PAYMENT_METHOD_KEY (PK), PAYMENT_METHOD_ID (Business Key), PAYMENT_METHOD_NAME, PAYMENT_TYPE

#### 8. DIM_EMPLOYEE
- **Purpose**: Employee master (for sales attribution)
- **Grain**: One row per employee per version
- **SCD Type**: Type 2 (Historical tracking)
- **Key Features**:
  - Employment details
  - Job title and department
  - Store assignment
  - Manager hierarchy
- **Key Columns**: EMPLOYEE_KEY (PK), EMPLOYEE_ID (Business Key), FIRST_NAME, LAST_NAME, JOB_TITLE, DEPARTMENT, EFFECTIVE_DATE, IS_CURRENT

#### 9. DIM_SUPPLIER
- **Purpose**: Supplier/vendor master
- **Grain**: One row per supplier per version
- **SCD Type**: Type 2 (Historical tracking)
- **Key Features**:
  - Supplier type classification
  - Contact information
  - Payment terms
  - Lead time and minimum order quantities
  - Supplier rating
- **Key Columns**: SUPPLIER_KEY (PK), SUPPLIER_ID (Business Key), SUPPLIER_NAME, SUPPLIER_TYPE, PAYMENT_TERMS, LEAD_TIME_DAYS, EFFECTIVE_DATE, IS_CURRENT

---

### Fact Tables (4 tables)

#### 1. FACT_SALES
- **Purpose**: Sales transaction data
- **Grain**: One row per transaction line item
- **Transaction Types**: Sale, Return, Exchange
- **Key Features**:
  - Complete transaction details
  - Quantity and amount metrics
  - Profit calculations
  - Channel attribution (In-Store, Online, Mobile)
  - Promotion tracking
- **Key Metrics**:
  - QUANTITY_SOLD
  - EXTENDED_PRICE (Quantity × Unit Price)
  - DISCOUNT_AMOUNT
  - TAX_AMOUNT
  - NET_SALES_AMOUNT (Extended Price - Discount + Tax)
  - GROSS_PROFIT_AMOUNT
  - GROSS_MARGIN_PERCENT
- **Foreign Keys**: DATE_KEY, TIME_KEY, CUSTOMER_KEY, PRODUCT_KEY, STORE_KEY, PROMOTION_KEY, PAYMENT_METHOD_KEY, EMPLOYEE_KEY
- **Degenerate Dimensions**: TRANSACTION_ID, TRANSACTION_LINE_NUMBER
- **Clustering**: Clustered by DATE_KEY and STORE_KEY

#### 2. FACT_INVENTORY
- **Purpose**: Daily inventory snapshots
- **Grain**: One row per product per store per day
- **Key Features**:
  - Beginning and ending on-hand quantities
  - Inventory movements (receipts, sales, returns, adjustments)
  - Reorder point tracking
  - Inventory valuation
  - Stock status classification
- **Key Metrics**:
  - BEGINNING_ON_HAND_QUANTITY
  - RECEIPTS_QUANTITY
  - SALES_QUANTITY
  - ENDING_ON_HAND_QUANTITY
  - INVENTORY_VALUE
  - DAYS_OF_SUPPLY
- **Foreign Keys**: DATE_KEY, PRODUCT_KEY, STORE_KEY, SUPPLIER_KEY
- **Clustering**: Clustered by SNAPSHOT_DATE, STORE_KEY, and PRODUCT_KEY

#### 3. FACT_PURCHASE_ORDER
- **Purpose**: Purchase orders from suppliers
- **Grain**: One row per purchase order line item
- **Key Features**:
  - Order lifecycle tracking
  - Expected vs. actual delivery dates
  - Quantity ordered vs. received
  - Cost tracking
  - Performance metrics (on-time, completeness)
- **Key Metrics**:
  - ORDER_QUANTITY
  - RECEIVED_QUANTITY
  - REJECTED_QUANTITY
  - EXTENDED_COST
  - TOTAL_COST
  - LEAD_TIME_DAYS
- **Foreign Keys**: ORDER_DATE_KEY, PRODUCT_KEY, STORE_KEY, SUPPLIER_KEY
- **Clustering**: Clustered by ORDER_DATE_KEY and SUPPLIER_KEY

#### 4. FACT_CUSTOMER_INTERACTION
- **Purpose**: Customer service and engagement tracking
- **Grain**: One row per customer interaction
- **Key Features**:
  - Multi-channel interaction tracking
  - Interaction type and reason classification
  - Resolution tracking
  - Customer satisfaction measurement
- **Key Metrics**:
  - RESOLUTION_TIME_MINUTES
  - CUSTOMER_SATISFACTION_SCORE
- **Foreign Keys**: DATE_KEY, TIME_KEY, CUSTOMER_KEY, STORE_KEY, EMPLOYEE_KEY
- **Clustering**: Clustered by DATE_KEY and CUSTOMER_KEY

---

### Bridge Tables (2 tables)

#### 1. BRIDGE_PRODUCT_SUPPLIER
- **Purpose**: Many-to-many relationship between products and suppliers
- **Grain**: One row per product-supplier combination
- **Key Features**:
  - Primary supplier designation
  - Supplier-specific pricing
  - Lead times and minimum order quantities

#### 2. BRIDGE_PROMOTION_PRODUCT
- **Purpose**: Many-to-many relationship between promotions and products
- **Grain**: One row per promotion-product combination
- **Use Case**: Associates products with promotions

---

## Analytical Views (17 views)

The model includes pre-built analytical views for common business questions:

### Sales Analytics
1. **VW_DAILY_SALES_SUMMARY** - Daily sales metrics with calendar attributes
2. **VW_STORE_SALES_PERFORMANCE** - Store-level performance and rankings
3. **VW_PRODUCT_SALES_PERFORMANCE** - Product-level performance and rankings
4. **VW_CATEGORY_SALES_PERFORMANCE** - Sales by category hierarchy
5. **VW_PROMOTION_EFFECTIVENESS** - Promotion ROI and effectiveness
6. **VW_CHANNEL_PERFORMANCE** - Performance by sales channel

### Customer Analytics
7. **VW_CUSTOMER_LIFETIME_VALUE** - Customer LTV and purchase history
8. **VW_CUSTOMER_RFM_ANALYSIS** - RFM segmentation (Recency, Frequency, Monetary)
9. **VW_CUSTOMER_PURCHASE_PATTERNS** - Purchase patterns by time

### Inventory Analytics
10. **VW_CURRENT_INVENTORY_STATUS** - Current inventory with alerts
11. **VW_INVENTORY_TURNOVER** - Turnover ratios and days on hand
12. **VW_STOCKOUT_ANALYSIS** - Stock-out history

### Employee Analytics
13. **VW_EMPLOYEE_SALES_PERFORMANCE** - Employee performance metrics

### Trend Analysis
14. **VW_YOY_SALES_COMPARISON** - Year-over-year comparisons
15. **VW_WEEKLY_SALES_TRENDS** - Weekly trends

### Financial
16. **VW_FINANCIAL_SUMMARY** - Financial summary by period

### Advanced Analytics
17. **VW_PRODUCT_AFFINITY** - Market basket analysis (products bought together)

---

## Sample Data

The model includes sample data generation scripts that create:
- **1,095 days** of calendar data (3 years)
- **96 time slots** (15-minute intervals)
- **1,000 customers** with varied segments
- **500 products** across 5 departments
- **50 stores** across 5 regions
- **20 promotions** (seasonal, clearance, loyalty)
- **10 payment methods**
- **200 employees** across multiple stores
- **30 suppliers**
- **100,000 sales transactions**
- **30 days** of inventory snapshots for 100 products × 10 stores

---

## Installation and Setup

### Prerequisites
- Snowflake account with appropriate permissions
- Access to create databases, schemas, tables, and views

### Step 1: Create Database Schema
```sql
-- Run the DDL script
-- File: retail_data_model.sql
```

This will create:
- Database: `RETAIL_DB`
- Schema: `RETAIL_SCHEMA`
- 9 dimension tables
- 4 fact tables
- 2 bridge tables

### Step 2: Load Sample Data
```sql
-- Run the data generation script
-- File: retail_sample_data.sql
```

This populates all tables with realistic sample data.

### Step 3: Create Analytical Views
```sql
-- Run the views script
-- File: retail_analytics_views.sql
```

This creates 17 pre-built analytical views.

---

## Usage Examples

### Example 1: Daily Sales Summary
```sql
SELECT 
    DATE_ACTUAL,
    DAY_NAME,
    transaction_count,
    unique_customers,
    total_net_sales,
    avg_transaction_value
FROM VW_DAILY_SALES_SUMMARY
WHERE DATE_ACTUAL >= DATEADD(day, -30, CURRENT_DATE())
ORDER BY DATE_ACTUAL DESC;
```

### Example 2: Top 10 Products by Sales
```sql
SELECT 
    PRODUCT_NAME,
    CATEGORY_LEVEL1,
    BRAND,
    total_sales,
    total_quantity_sold,
    sales_rank
FROM VW_PRODUCT_SALES_PERFORMANCE
WHERE sales_rank <= 10
ORDER BY sales_rank;
```

### Example 3: Customer Segmentation (RFM Analysis)
```sql
SELECT 
    customer_segment_rfm,
    COUNT(*) AS customer_count,
    AVG(monetary_value) AS avg_ltv,
    AVG(frequency) AS avg_purchase_frequency
FROM VW_CUSTOMER_RFM_ANALYSIS
GROUP BY customer_segment_rfm
ORDER BY customer_count DESC;
```

### Example 4: Inventory Reorder Alert
```sql
SELECT 
    PRODUCT_NAME,
    STORE_NAME,
    ENDING_ON_HAND_QUANTITY,
    REORDER_POINT,
    inventory_alert
FROM VW_CURRENT_INVENTORY_STATUS
WHERE inventory_alert IN ('Critical', 'Reorder')
ORDER BY 
    CASE inventory_alert 
        WHEN 'Critical' THEN 1 
        WHEN 'Reorder' THEN 2 
    END,
    ENDING_ON_HAND_QUANTITY;
```

### Example 5: Year-over-Year Sales Growth
```sql
SELECT 
    current_year,
    MONTH_NAME,
    current_year_sales,
    prior_year_sales,
    sales_growth_pct
FROM VW_YOY_SALES_COMPARISON
WHERE current_year = 2024
ORDER BY MONTH_NUMBER;
```

### Example 6: Store Performance by Region
```sql
SELECT 
    REGION,
    COUNT(DISTINCT STORE_ID) AS store_count,
    SUM(total_sales) AS regional_sales,
    AVG(total_sales) AS avg_store_sales,
    AVG(sales_per_sqft) AS avg_sales_per_sqft
FROM VW_STORE_SALES_PERFORMANCE
GROUP BY REGION
ORDER BY regional_sales DESC;
```

### Example 7: Promotion Effectiveness
```sql
SELECT 
    PROMOTION_NAME,
    PROMOTION_TYPE,
    transactions_with_promo,
    total_discount_given,
    total_net_sales,
    sales_to_discount_ratio,
    ROUND(total_net_sales / total_discount_given, 2) AS roi
FROM VW_PROMOTION_EFFECTIVENESS
WHERE START_DATE >= '2024-01-01'
ORDER BY total_net_sales DESC;
```

### Example 8: Market Basket Analysis
```sql
SELECT 
    product_1_name,
    product_1_category,
    product_2_name,
    product_2_category,
    times_purchased_together,
    support_percentage
FROM VW_PRODUCT_AFFINITY
WHERE product_1_category != product_2_category  -- Cross-category recommendations
ORDER BY times_purchased_together DESC
LIMIT 20;
```

---

## Key Metrics and KPIs

### Sales Metrics
- **Net Sales Amount**: Total revenue after discounts and including tax
- **Gross Profit**: Sales minus cost of goods sold
- **Gross Margin %**: Gross profit as percentage of sales
- **Average Transaction Value (ATV)**: Total sales / number of transactions
- **Units per Transaction**: Total units sold / number of transactions
- **Sales per Square Foot**: Total sales / store square footage

### Customer Metrics
- **Customer Lifetime Value (LTV)**: Total revenue from a customer
- **Customer Acquisition**: New customers by period
- **Customer Retention Rate**: Repeat customers / total customers
- **RFM Score**: Composite score for customer segmentation
- **Average Order Value (AOV)**: Total sales / number of orders

### Inventory Metrics
- **Inventory Turnover**: COGS / Average inventory
- **Days Inventory on Hand**: (Average inventory / COGS) × 365
- **Stock-Out Rate**: Days out of stock / total days
- **Inventory Value**: Units on hand × unit cost

### Operational Metrics
- **Transactions per Hour**: Transactions by time of day
- **Employee Sales per Hour**: Sales attributed to employee / hours worked
- **Supplier On-Time Delivery**: On-time orders / total orders
- **Supplier Lead Time**: Average days from order to delivery

---

## Data Quality and Validation

The model includes several data quality features:

1. **Primary Keys**: Auto-incrementing surrogate keys on all tables
2. **Foreign Keys**: Enforced referential integrity
3. **Unique Constraints**: Business keys have unique constraints
4. **Default Values**: Sensible defaults for optional fields
5. **Data Types**: Appropriate data types for each column
6. **NOT NULL Constraints**: Required fields enforced
7. **Check Constraints**: Could be added for value validation
8. **Audit Timestamps**: CREATED_TIMESTAMP and UPDATED_TIMESTAMP

---

## Performance Optimization

### Clustering
The fact tables use Snowflake's clustering feature:
- **FACT_SALES**: Clustered by DATE_KEY and STORE_KEY
- **FACT_INVENTORY**: Clustered by SNAPSHOT_DATE, STORE_KEY, PRODUCT_KEY
- **FACT_PURCHASE_ORDER**: Clustered by ORDER_DATE_KEY and SUPPLIER_KEY
- **FACT_CUSTOMER_INTERACTION**: Clustered by DATE_KEY and CUSTOMER_KEY

### Best Practices
1. **Use Views**: Pre-built views optimize common queries
2. **Filter on Clustered Keys**: Filter by date and store for best performance
3. **Avoid SELECT ***: Select only needed columns
4. **Use CURRENT Flag**: Filter on IS_CURRENT = TRUE for dimension lookups
5. **Partition Pruning**: Snowflake automatically prunes micro-partitions

---

## Slowly Changing Dimensions (SCD Type 2)

Several dimensions implement SCD Type 2 for historical tracking:
- DIM_CUSTOMER
- DIM_PRODUCT
- DIM_STORE
- DIM_EMPLOYEE
- DIM_SUPPLIER

### SCD Type 2 Columns
- **EFFECTIVE_DATE**: When this version became effective
- **EXPIRATION_DATE**: When this version expired (NULL for current)
- **IS_CURRENT**: Boolean flag (TRUE for current version)

### Querying Historical Data
```sql
-- Get customer as of a specific date
SELECT *
FROM DIM_CUSTOMER
WHERE CUSTOMER_ID = 'CUST-000001'
  AND '2023-06-15' BETWEEN EFFECTIVE_DATE AND COALESCE(EXPIRATION_DATE, '9999-12-31');

-- Get current version only
SELECT *
FROM DIM_CUSTOMER
WHERE CUSTOMER_ID = 'CUST-000001'
  AND IS_CURRENT = TRUE;
```

---

## Extensions and Customization

### Potential Extensions
1. **Add DIM_PRODUCT_CATEGORY**: Separate table for category hierarchy
2. **Add FACT_WEB_CLICKSTREAM**: Online behavior tracking
3. **Add FACT_RETURNS**: Dedicated returns fact table
4. **Add DIM_SHIPPING_METHOD**: Shipping options
5. **Add FACT_CUSTOMER_SURVEY**: Survey responses
6. **Add BRIDGE_CUSTOMER_HOUSEHOLD**: Household relationships

### Customization Points
- Adjust fiscal calendar logic in DIM_DATE
- Modify category hierarchy levels in DIM_PRODUCT
- Adjust RFM scoring logic in VW_CUSTOMER_RFM_ANALYSIS
- Add industry-specific product attributes
- Customize promotion types for your business
- Add store format classifications

---

## Maintenance

### Regular Tasks
1. **Load New Dates**: Keep DIM_DATE populated with future dates
2. **Update SCD Dimensions**: Process dimension changes
3. **Load Daily Sales**: Daily batch load of FACT_SALES
4. **Snapshot Inventory**: Daily inventory snapshots
5. **Update Aggregates**: Refresh materialized views if used
6. **Monitor Query Performance**: Review query history

### Data Retention
- **Fact Tables**: Typically retain 2-7 years
- **Dimension Tables**: Retain all historical versions (SCD Type 2)
- **Inventory Snapshots**: Retain 1-2 years of daily data

---

## Support and Contact

For questions or issues with this data model:
1. Review the SQL comments in each script
2. Check the analytical views for examples
3. Consult Snowflake documentation for platform-specific features

---

## File Structure

```
retail_data_model/
├── retail_data_model.sql           # DDL for all tables
├── retail_sample_data.sql          # Sample data generation
├── retail_analytics_views.sql      # Analytical views
└── RETAIL_DATA_MODEL_README.md     # This documentation
```

---

## License and Usage

This retail data model is provided as a template and can be freely used, modified, and extended for your specific business needs.

---

## Version History

- **Version 1.0** (2025-10-29)
  - Initial release
  - 9 dimension tables
  - 4 fact tables
  - 2 bridge tables
  - 17 analytical views
  - Sample data generation
  - Comprehensive documentation

---

## Summary

This retail data model provides a comprehensive foundation for retail analytics, supporting:
- ✅ Sales analysis and reporting
- ✅ Customer analytics and segmentation
- ✅ Inventory management and optimization
- ✅ Employee performance tracking
- ✅ Supplier management
- ✅ Promotion effectiveness
- ✅ Financial reporting
- ✅ Trend analysis
- ✅ Market basket analysis

The model is production-ready, scalable, and follows industry best practices for dimensional modeling on Snowflake.



