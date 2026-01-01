# Agent Commerce - Deployment Guide

## Prerequisites

- [ ] Snowflake account with ACCOUNTADMIN access
- [ ] Docker installed and running
- [ ] SnowSQL CLI installed
- [ ] Python 3.10+ with pandas, Pillow

---

## Deployment Steps

### Step 1: Run SQL Infrastructure Scripts (Snowflake Worksheet)

Run these scripts in order in Snowflake:

```
sql/01_setup_database.sql    ✅ Creates database, schemas, warehouse, compute pool
sql/02_create_tables.sql     ✅ Creates all tables (Products, Customers, Inventory, Social, Cart_OLTP)
sql/03_create_semantic_views.sql  ✅ Creates Cortex Analyst semantic views
sql/04_create_cortex_search.sql   ✅ Creates Cortex Search services
sql/05_create_vector_embedding_proc.sql  ✅ Creates vector search procedures
```

### Step 2: Upload CSV Data to Snowflake

**Option A: Using SnowSQL (Recommended)**
```bash
# Connect to Snowflake
snowsql -a <account> -u <user>

# Create stage and upload files
USE ROLE AGENT_COMMERCE_ROLE;
USE DATABASE AGENT_COMMERCE;
USE SCHEMA UTIL;

# Upload all CSV files
PUT file:///Users/amgupta/Documents/Snowflake/Demo/beauty_analyzer/data/generated/csv/*.csv @DATA_STAGE/csv/ AUTO_COMPRESS=TRUE OVERWRITE=TRUE;
```

**Option B: Using Snowflake UI**
1. Go to Data > Databases > AGENT_COMMERCE > UTIL > Stages > DATA_STAGE
2. Click "Load Data" and upload all CSV files from `data/generated/csv/`

### Step 3: Load Data into Tables

Run in Snowflake worksheet:
```
sql/06_load_sample_data.sql
```

### Step 4: Build and Push Docker Image

```bash
cd beauty_analyzer/backend
chmod +x build_and_push.sh

# Get your repository URL first:
# In Snowflake: SHOW IMAGE REPOSITORIES IN SCHEMA AGENT_COMMERCE.UTIL;

# Build and push (replace with your values)
docker build --platform linux/amd64 -t agent-commerce-backend:latest .
docker login <account>.registry.snowflakecomputing.com
docker tag agent-commerce-backend:latest <repo_url>/agent-commerce-backend:latest
docker push <repo_url>/agent-commerce-backend:latest
```

### Step 5: Deploy SPCS Service

Run in Snowflake worksheet:
```
sql/07_deploy_spcs_backend.sql
```

### Step 6: Upload FairFace Images

```bash
# Using SnowSQL
snowsql -a <account> -u <user> -q "
PUT file:///Users/amgupta/Documents/Snowflake/Demo/beauty_analyzer/sample_images/fairface_data/FairFace/train/*.jpg
    @AGENT_COMMERCE.CUSTOMERS.FACE_IMAGES/fairface/
    PARALLEL=10
    AUTO_COMPRESS=FALSE;
"
```

### Step 7: Extract Face Embeddings

Run in Snowflake worksheet:
```
sql/08_process_face_embeddings.sql
```

---

## Verification Commands

```sql
-- Check table row counts
SELECT 'PRODUCTS' AS schema_name, COUNT(*) FROM PRODUCTS.PRODUCTS
UNION ALL SELECT 'CUSTOMERS', COUNT(*) FROM CUSTOMERS.CUSTOMERS
UNION ALL SELECT 'INVENTORY', COUNT(*) FROM INVENTORY.LOCATIONS
UNION ALL SELECT 'SOCIAL', COUNT(*) FROM SOCIAL.PRODUCT_REVIEWS
UNION ALL SELECT 'CART_OLTP', COUNT(*) FROM CART_OLTP.ORDERS;

-- Check SPCS service status
SELECT SYSTEM$GET_SERVICE_STATUS('UTIL.AGENT_COMMERCE_BACKEND');

-- Check Cortex Search services
SHOW CORTEX SEARCH SERVICES;

-- Test face embedding extraction
SELECT CUSTOMERS.EXTRACT_FACE_EMBEDDING('<base64_image>');
```

---

## Troubleshooting

### Docker build fails
- Ensure Docker Desktop is running
- Try: `docker build --no-cache --platform linux/amd64 -t agent-commerce-backend:latest .`

### SPCS service won't start
- Check compute pool: `SHOW COMPUTE POOLS;`
- Check service logs: `SELECT SYSTEM$GET_SERVICE_LOGS('UTIL.AGENT_COMMERCE_BACKEND', 0, 'backend', 100);`

### Data load fails
- Check file format: `DESCRIBE FILE FORMAT UTIL.CSV_FORMAT;`
- Check stage files: `LIST @UTIL.DATA_STAGE/csv/;`

