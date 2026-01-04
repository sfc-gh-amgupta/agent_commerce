# Retail Data Model - Entity Relationship Diagram

## Visual Overview

This document provides a textual representation of the Entity Relationship Diagram (ERD) for the Retail Data Model. Use this to understand the relationships between tables.

---

## Star Schema Structure

```
                    DIM_DATE                    DIM_TIME
                        |                           |
                        |                           |
                        +------------+  +-----------+
                                     |  |
        DIM_CUSTOMER ----+           |  |           +---- DIM_PROMOTION
                         |           |  |           |
        DIM_PRODUCT  ----+           |  |           +---- DIM_PAYMENT_METHOD
                         |           |  |           |
        DIM_STORE    ----+-----> FACT_SALES <------+---- DIM_EMPLOYEE
                         |
                         |
        DIM_SUPPLIER ----+
```

---

## Detailed Table Relationships

### FACT_SALES (Sales Transaction Fact)
**Central fact table for sales transactions**

**Foreign Key Relationships:**
- `DATE_KEY` → `DIM_DATE.DATE_KEY` (Required)
- `TIME_KEY` → `DIM_TIME.TIME_KEY` (Required)
- `CUSTOMER_KEY` → `DIM_CUSTOMER.CUSTOMER_KEY` (Optional - anonymous purchases)
- `PRODUCT_KEY` → `DIM_PRODUCT.PRODUCT_KEY` (Required)
- `STORE_KEY` → `DIM_STORE.STORE_KEY` (Required)
- `PROMOTION_KEY` → `DIM_PROMOTION.PROMOTION_KEY` (Optional)
- `PAYMENT_METHOD_KEY` → `DIM_PAYMENT_METHOD.PAYMENT_METHOD_KEY` (Optional)
- `EMPLOYEE_KEY` → `DIM_EMPLOYEE.EMPLOYEE_KEY` (Optional - assisted sales)

**Grain:** One row per transaction line item

---

### FACT_INVENTORY (Inventory Snapshot Fact)
**Daily inventory positions**

```
        DIM_DATE -------+
                        |
        DIM_PRODUCT ----+--> FACT_INVENTORY
                        |
        DIM_STORE ------+
                        |
        DIM_SUPPLIER ---+
```

**Foreign Key Relationships:**
- `DATE_KEY` → `DIM_DATE.DATE_KEY` (Required)
- `PRODUCT_KEY` → `DIM_PRODUCT.PRODUCT_KEY` (Required)
- `STORE_KEY` → `DIM_STORE.STORE_KEY` (Required)
- `SUPPLIER_KEY` → `DIM_SUPPLIER.SUPPLIER_KEY` (Optional)

**Grain:** One row per product per store per day

---

### FACT_PURCHASE_ORDER (Purchase Order Fact)
**Supplier purchase orders**

```
        DIM_DATE (3x) --+
                        |
        DIM_PRODUCT ----+--> FACT_PURCHASE_ORDER
                        |
        DIM_STORE ------+
                        |
        DIM_SUPPLIER ---+
```

**Foreign Key Relationships:**
- `ORDER_DATE_KEY` → `DIM_DATE.DATE_KEY` (Required)
- `EXPECTED_DELIVERY_DATE_KEY` → `DIM_DATE.DATE_KEY` (Optional)
- `ACTUAL_DELIVERY_DATE_KEY` → `DIM_DATE.DATE_KEY` (Optional)
- `PRODUCT_KEY` → `DIM_PRODUCT.PRODUCT_KEY` (Required)
- `STORE_KEY` → `DIM_STORE.STORE_KEY` (Required)
- `SUPPLIER_KEY` → `DIM_SUPPLIER.SUPPLIER_KEY` (Required)

**Grain:** One row per purchase order line item

---

### FACT_CUSTOMER_INTERACTION (Customer Service Fact)
**Customer service interactions**

```
        DIM_DATE -------+
                        |
        DIM_TIME -------+
                        |
        DIM_CUSTOMER ---+--> FACT_CUSTOMER_INTERACTION
                        |
        DIM_STORE ------+
                        |
        DIM_EMPLOYEE ---+
```

**Foreign Key Relationships:**
- `DATE_KEY` → `DIM_DATE.DATE_KEY` (Required)
- `TIME_KEY` → `DIM_TIME.TIME_KEY` (Required)
- `CUSTOMER_KEY` → `DIM_CUSTOMER.CUSTOMER_KEY` (Required)
- `STORE_KEY` → `DIM_STORE.STORE_KEY` (Optional)
- `EMPLOYEE_KEY` → `DIM_EMPLOYEE.EMPLOYEE_KEY` (Optional)

**Grain:** One row per customer interaction

---

## Bridge Tables (Many-to-Many Relationships)

### BRIDGE_PRODUCT_SUPPLIER
**Links products to their suppliers (many-to-many)**

```
        DIM_PRODUCT ----+
                        |
                        +--> BRIDGE_PRODUCT_SUPPLIER
                        |
        DIM_SUPPLIER ---+
```

**Relationships:**
- `PRODUCT_KEY` → `DIM_PRODUCT.PRODUCT_KEY`
- `SUPPLIER_KEY` → `DIM_SUPPLIER.SUPPLIER_KEY`

**Purpose:** A product can have multiple suppliers; a supplier can supply multiple products

---

### BRIDGE_PROMOTION_PRODUCT
**Links promotions to eligible products (many-to-many)**

```
        DIM_PROMOTION --+
                        |
                        +--> BRIDGE_PROMOTION_PRODUCT
                        |
        DIM_PRODUCT ----+
```

**Relationships:**
- `PROMOTION_KEY` → `DIM_PROMOTION.PROMOTION_KEY`
- `PRODUCT_KEY` → `DIM_PRODUCT.PRODUCT_KEY`

**Purpose:** A promotion can apply to multiple products; a product can be in multiple promotions

---

## Dimension Table Details

### DIM_DATE (Date Dimension)
- **Type:** Conformed dimension
- **SCD Type:** Type 1 (static)
- **Grain:** One row per day
- **Key:** `DATE_KEY` (YYYYMMDD format)
- **Business Key:** `DATE_ACTUAL`

### DIM_TIME (Time Dimension)
- **Type:** Conformed dimension
- **SCD Type:** Type 1 (static)
- **Grain:** One row per 15-minute interval
- **Key:** `TIME_KEY` (sequence number)
- **Business Key:** `TIME_ACTUAL`

### DIM_CUSTOMER (Customer Dimension)
- **Type:** Slowly Changing Dimension
- **SCD Type:** Type 2 (track history)
- **Grain:** One row per customer per version
- **Key:** `CUSTOMER_KEY` (surrogate)
- **Business Key:** `CUSTOMER_ID`
- **Version Fields:** `EFFECTIVE_DATE`, `EXPIRATION_DATE`, `IS_CURRENT`

### DIM_PRODUCT (Product Dimension)
- **Type:** Slowly Changing Dimension
- **SCD Type:** Type 2 (track history)
- **Grain:** One row per product per version
- **Key:** `PRODUCT_KEY` (surrogate)
- **Business Key:** `PRODUCT_ID`, `SKU`
- **Version Fields:** `EFFECTIVE_DATE`, `EXPIRATION_DATE`, `IS_CURRENT`
- **Hierarchy:** `CATEGORY_LEVEL1` → `CATEGORY_LEVEL2` → `CATEGORY_LEVEL3`

### DIM_STORE (Store/Location Dimension)
- **Type:** Slowly Changing Dimension
- **SCD Type:** Type 2 (track history)
- **Grain:** One row per store per version
- **Key:** `STORE_KEY` (surrogate)
- **Business Key:** `STORE_ID`
- **Version Fields:** `EFFECTIVE_DATE`, `EXPIRATION_DATE`, `IS_CURRENT`
- **Hierarchy:** `REGION` → `DISTRICT` → `TERRITORY`

### DIM_PROMOTION (Promotion Dimension)
- **Type:** Standard dimension
- **SCD Type:** Type 1 (overwrite)
- **Grain:** One row per promotion
- **Key:** `PROMOTION_KEY` (surrogate)
- **Business Key:** `PROMOTION_ID`

### DIM_PAYMENT_METHOD (Payment Method Dimension)
- **Type:** Standard dimension
- **SCD Type:** Type 1 (overwrite)
- **Grain:** One row per payment method
- **Key:** `PAYMENT_METHOD_KEY` (surrogate)
- **Business Key:** `PAYMENT_METHOD_ID`

### DIM_EMPLOYEE (Employee Dimension)
- **Type:** Slowly Changing Dimension
- **SCD Type:** Type 2 (track history)
- **Grain:** One row per employee per version
- **Key:** `EMPLOYEE_KEY` (surrogate)
- **Business Key:** `EMPLOYEE_ID`
- **Version Fields:** `EFFECTIVE_DATE`, `EXPIRATION_DATE`, `IS_CURRENT`
- **Self-Reference:** `MANAGER_EMPLOYEE_KEY` → `DIM_EMPLOYEE.EMPLOYEE_KEY`

### DIM_SUPPLIER (Supplier Dimension)
- **Type:** Slowly Changing Dimension
- **SCD Type:** Type 2 (track history)
- **Grain:** One row per supplier per version
- **Key:** `SUPPLIER_KEY` (surrogate)
- **Business Key:** `SUPPLIER_ID`
- **Version Fields:** `EFFECTIVE_DATE`, `EXPIRATION_DATE`, `IS_CURRENT`

---

## Cardinality Summary

| Relationship | From Table | To Table | Cardinality | Optionality |
|-------------|-----------|----------|-------------|-------------|
| Sales to Date | FACT_SALES | DIM_DATE | Many:1 | Mandatory |
| Sales to Time | FACT_SALES | DIM_TIME | Many:1 | Mandatory |
| Sales to Customer | FACT_SALES | DIM_CUSTOMER | Many:1 | Optional |
| Sales to Product | FACT_SALES | DIM_PRODUCT | Many:1 | Mandatory |
| Sales to Store | FACT_SALES | DIM_STORE | Many:1 | Mandatory |
| Sales to Promotion | FACT_SALES | DIM_PROMOTION | Many:1 | Optional |
| Sales to Payment | FACT_SALES | DIM_PAYMENT_METHOD | Many:1 | Optional |
| Sales to Employee | FACT_SALES | DIM_EMPLOYEE | Many:1 | Optional |
| Inventory to Date | FACT_INVENTORY | DIM_DATE | Many:1 | Mandatory |
| Inventory to Product | FACT_INVENTORY | DIM_PRODUCT | Many:1 | Mandatory |
| Inventory to Store | FACT_INVENTORY | DIM_STORE | Many:1 | Mandatory |
| Inventory to Supplier | FACT_INVENTORY | DIM_SUPPLIER | Many:1 | Optional |
| PO to Date | FACT_PURCHASE_ORDER | DIM_DATE | Many:1 | Mandatory |
| PO to Product | FACT_PURCHASE_ORDER | DIM_PRODUCT | Many:1 | Mandatory |
| PO to Store | FACT_PURCHASE_ORDER | DIM_STORE | Many:1 | Mandatory |
| PO to Supplier | FACT_PURCHASE_ORDER | DIM_SUPPLIER | Many:1 | Mandatory |
| Interaction to Date | FACT_CUSTOMER_INTERACTION | DIM_DATE | Many:1 | Mandatory |
| Interaction to Time | FACT_CUSTOMER_INTERACTION | DIM_TIME | Many:1 | Mandatory |
| Interaction to Customer | FACT_CUSTOMER_INTERACTION | DIM_CUSTOMER | Many:1 | Mandatory |
| Interaction to Store | FACT_CUSTOMER_INTERACTION | DIM_STORE | Many:1 | Optional |
| Interaction to Employee | FACT_CUSTOMER_INTERACTION | DIM_EMPLOYEE | Many:1 | Optional |
| Product-Supplier Bridge | BRIDGE_PRODUCT_SUPPLIER | DIM_PRODUCT | Many:1 | Mandatory |
| Product-Supplier Bridge | BRIDGE_PRODUCT_SUPPLIER | DIM_SUPPLIER | Many:1 | Mandatory |
| Promotion-Product Bridge | BRIDGE_PROMOTION_PRODUCT | DIM_PROMOTION | Many:1 | Mandatory |
| Promotion-Product Bridge | BRIDGE_PROMOTION_PRODUCT | DIM_PRODUCT | Many:1 | Mandatory |

---

## Table Size Estimates (with sample data)

| Table | Sample Row Count | Production Estimate (Annual) |
|-------|------------------|------------------------------|
| DIM_DATE | 1,095 (3 years) | 3,650 (10 years) |
| DIM_TIME | 96 | 96 |
| DIM_CUSTOMER | 1,000 | 100K - 10M |
| DIM_PRODUCT | 500 | 10K - 100K |
| DIM_STORE | 50 | 100 - 10K |
| DIM_PROMOTION | 20 | 50 - 500 |
| DIM_PAYMENT_METHOD | 10 | 10 - 50 |
| DIM_EMPLOYEE | 200 | 1K - 100K |
| DIM_SUPPLIER | 30 | 100 - 10K |
| **FACT_SALES** | 100,000 | **100M - 1B+** |
| **FACT_INVENTORY** | 30,000 | **10M - 100M** |
| FACT_PURCHASE_ORDER | 0 (template) | 1M - 10M |
| FACT_CUSTOMER_INTERACTION | 0 (template) | 1M - 50M |
| BRIDGE_PRODUCT_SUPPLIER | ~150 | 10K - 100K |
| BRIDGE_PROMOTION_PRODUCT | 0 (template) | 1K - 50K |

---

## Query Patterns

### Pattern 1: Simple Sales by Date
```
FACT_SALES → DIM_DATE
```
Filter by date, aggregate sales metrics

### Pattern 2: Customer Purchase Analysis
```
FACT_SALES → DIM_CUSTOMER → DIM_DATE → DIM_PRODUCT
```
Join customer to sales, analyze purchase patterns

### Pattern 3: Store Performance
```
FACT_SALES → DIM_STORE → DIM_DATE
```
Aggregate sales by store and region

### Pattern 4: Product Sales with Category
```
FACT_SALES → DIM_PRODUCT → DIM_DATE
```
Category hierarchy drill-down analysis

### Pattern 5: Promotion Effectiveness
```
FACT_SALES → DIM_PROMOTION → DIM_PRODUCT → DIM_DATE
```
Measure promotion impact on sales

### Pattern 6: Inventory Status
```
FACT_INVENTORY → DIM_PRODUCT → DIM_STORE → DIM_DATE
```
Current inventory positions and alerts

### Pattern 7: Supplier Performance
```
FACT_PURCHASE_ORDER → DIM_SUPPLIER → DIM_DATE
```
Supplier delivery metrics

### Pattern 8: Cross-Sell Analysis (Market Basket)
```
FACT_SALES (self-join) → DIM_PRODUCT
```
Products purchased together

---

## Indexing and Clustering Strategy

### Fact Tables
- **FACT_SALES**: Clustered on `(DATE_KEY, STORE_KEY)`
  - Optimizes date-based queries and store-level analysis
- **FACT_INVENTORY**: Clustered on `(SNAPSHOT_DATE, STORE_KEY, PRODUCT_KEY)`
  - Optimizes inventory snapshots by date and location
- **FACT_PURCHASE_ORDER**: Clustered on `(ORDER_DATE_KEY, SUPPLIER_KEY)`
  - Optimizes supplier order tracking
- **FACT_CUSTOMER_INTERACTION**: Clustered on `(DATE_KEY, CUSTOMER_KEY)`
  - Optimizes customer history queries

### Dimension Tables
- Snowflake automatically optimizes dimension tables
- Primary keys are indexed automatically
- Consider clustering large SCD Type 2 dimensions on `IS_CURRENT` if needed

---

## Data Flow

### Typical ETL/ELT Flow

```
Source Systems
    |
    v
[ Staging Area ]
    |
    +---> Dimension Load (SCD processing)
    |         |
    |         v
    |     DIM_* Tables
    |
    +---> Fact Load (with lookups)
              |
              v
          FACT_* Tables
              |
              v
        Analytical Views
              |
              v
        BI Tools / Reports
```

### Load Frequency
- **Dimensions**: Daily or change-driven
- **FACT_SALES**: Real-time, micro-batch, or daily
- **FACT_INVENTORY**: Daily snapshot
- **FACT_PURCHASE_ORDER**: As orders occur
- **FACT_CUSTOMER_INTERACTION**: Real-time or hourly

---

## Best Practices for Querying

1. **Always filter on clustered keys** for best performance
2. **Use IS_CURRENT = TRUE** when querying SCD Type 2 dimensions
3. **Use views** for complex joins (pre-built views provided)
4. **Aggregate in the database** rather than in application layer
5. **Use date partitioning** for large historical analyses
6. **Avoid SELECT *** - specify only needed columns
7. **Use QUALIFY** for window function filtering in Snowflake

---

## Diagram Notation

- **→** : Foreign Key relationship (Many-to-One)
- **←→** : Bridge table (Many-to-Many)
- **(Required)** : NOT NULL foreign key
- **(Optional)** : Nullable foreign key

---

## Summary

This retail data model implements a **star schema** with:
- ✅ **4 Fact Tables** (transactional and snapshot grains)
- ✅ **9 Dimension Tables** (with SCD Type 2 where needed)
- ✅ **2 Bridge Tables** (for many-to-many relationships)
- ✅ **Optimized for analytics** (clustering, partitioning)
- ✅ **Production-ready** (constraints, audit fields, documentation)

The model supports a wide range of retail analytics use cases while maintaining performance and data integrity.



