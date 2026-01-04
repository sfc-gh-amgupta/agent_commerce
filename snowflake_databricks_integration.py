# Databricks notebook source
# MAGIC %md
# MAGIC # Snowflake + Databricks Data Integration
# MAGIC 
# MAGIC This notebook demonstrates how to:
# MAGIC 1. Connect to Snowflake using Snowpark
# MAGIC 2. Read data from Snowflake tables
# MAGIC 3. Read data from local Databricks tables
# MAGIC 4. Join the datasets and display results
# MAGIC 
# MAGIC ## Prerequisites
# MAGIC - Snowflake account with private key authentication configured
# MAGIC - Databricks cluster with appropriate libraries installed
# MAGIC - Network connectivity between Databricks and Snowflake

# COMMAND ----------

# MAGIC %md
# MAGIC ## 1. Install Required Libraries
# MAGIC 
# MAGIC First, let's install the necessary libraries for Snowpark integration.

# COMMAND ----------

# MAGIC %pip install snowflake-snowpark-python cryptography pandas

# COMMAND ----------

# MAGIC %md
# MAGIC ## 2. Import Libraries and Setup

# COMMAND ----------

import pandas as pd
import pyspark.sql.functions as F
from pyspark.sql.types import *
from pyspark.sql import SparkSession
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col as snow_col
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.serialization import load_pem_private_key
from cryptography.hazmat.backends import default_backend
import os
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

print("✅ Libraries imported successfully")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 3. Configuration Setup
# MAGIC 
# MAGIC Configure connection parameters for Snowflake. In production, use Databricks secrets for secure credential management.

# COMMAND ----------

class SnowflakeDatabricksConfig:
    """Configuration for Snowflake connection in Databricks"""
    
    def __init__(self):
        # Snowflake connection parameters
        # In production, use dbutils.secrets.get() for secure credential management
        self.snowflake_account = "your_account_identifier"  # e.g., "abc123.us-east-1"
        self.snowflake_user = "your_username"
        self.snowflake_role = "your_role"
        self.snowflake_warehouse = "your_warehouse"
        self.snowflake_database = "SNOWFLAKE_SAMPLE_DATA"
        self.snowflake_schema = "TPCH_SF1"
        
        # Private key content (in production, store in Databricks secrets)
        # For demo purposes, we'll use a placeholder
        self.private_key_content = """-----BEGIN PRIVATE KEY-----
YOUR_PRIVATE_KEY_CONTENT_HERE
-----END PRIVATE KEY-----"""
        
        # Databricks configuration
        self.databricks_database = "default"
        self.databricks_table = "local_customers"

# Initialize configuration
config = SnowflakeDatabricksConfig()
print("✅ Configuration initialized")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 4. Snowflake Connection Functions

# COMMAND ----------

def load_private_key_from_string(private_key_string: str) -> bytes:
    """Load private key from string and return in DER format"""
    
    try:
        # Convert string to bytes
        key_data = private_key_string.encode('utf-8')
        
        # Load PEM private key
        private_key = load_pem_private_key(
            key_data,
            password=None,  # Assuming no passphrase
            backend=default_backend()
        )
        
        # Convert to DER format for Snowpark
        private_key_der = private_key.private_bytes(
            encoding=serialization.Encoding.DER,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption()
        )
        
        logger.info("Private key loaded successfully")
        return private_key_der
        
    except Exception as e:
        logger.error(f"Failed to load private key: {e}")
        raise

def create_snowpark_session(config: SnowflakeDatabricksConfig) -> Session:
    """Create Snowpark session in Databricks environment"""
    
    try:
        # Load private key
        private_key_der = load_private_key_from_string(config.private_key_content)
        
        # Connection parameters
        connection_parameters = {
            "account": config.snowflake_account,
            "user": config.snowflake_user,
            "private_key": private_key_der,
            "role": config.snowflake_role,
            "warehouse": config.snowflake_warehouse,
            "database": config.snowflake_database,
            "schema": config.snowflake_schema
        }
        
        # Create session
        session = Session.builder.configs(connection_parameters).create()
        logger.info("✅ Successfully connected to Snowflake")
        
        # Display connection info
        print(f"Connected to Snowflake:")
        print(f"  Account: {session.get_current_account()}")
        print(f"  User: {session.get_current_user()}")
        print(f"  Role: {session.get_current_role()}")
        print(f"  Warehouse: {session.get_current_warehouse()}")
        print(f"  Database: {session.get_current_database()}")
        print(f"  Schema: {session.get_current_schema()}")
        
        return session
        
    except Exception as e:
        logger.error(f"❌ Failed to create Snowpark session: {e}")
        raise

print("✅ Snowflake connection functions defined")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 5. Create Sample Data in Databricks
# MAGIC 
# MAGIC Let's create a sample table in Databricks that we can join with Snowflake data.

# COMMAND ----------

# Create sample customer data in Databricks
sample_databricks_data = [
    (1, "Premium", "2023-01-15", 95.5, "Active"),
    (2, "Standard", "2023-02-20", 78.2, "Active"),
    (3, "Premium", "2023-01-10", 88.7, "Inactive"),
    (4, "Basic", "2023-03-05", 65.3, "Active"),
    (5, "Premium", "2023-01-25", 92.1, "Active"),
    (10, "Standard", "2023-02-15", 81.4, "Active"),
    (15, "Premium", "2023-01-30", 97.8, "Active"),
    (20, "Basic", "2023-03-10", 72.6, "Inactive"),
    (25, "Standard", "2023-02-25", 85.9, "Active"),
    (30, "Premium", "2023-01-20", 94.3, "Active")
]

# Define schema
databricks_schema = StructType([
    StructField("customer_id", IntegerType(), True),
    StructField("subscription_type", StringType(), True),
    StructField("signup_date", StringType(), True),
    StructField("satisfaction_score", DoubleType(), True),
    StructField("status", StringType(), True)
])

# Create DataFrame
databricks_df = spark.createDataFrame(sample_databricks_data, databricks_schema)

# Create or replace table
databricks_df.write.mode("overwrite").saveAsTable(f"{config.databricks_database}.{config.databricks_table}")

print("✅ Sample Databricks table created")
print(f"Table: {config.databricks_database}.{config.databricks_table}")
print(f"Rows: {databricks_df.count()}")

# Display sample data
print("\nSample Databricks Data:")
display(databricks_df)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 6. Read Data from Snowflake
# MAGIC 
# MAGIC Now let's connect to Snowflake and read customer data.

# COMMAND ----------

# Create Snowpark session
# Note: In a real scenario, update the config with your actual Snowflake credentials
try:
    # For demo purposes, we'll simulate the Snowflake connection
    # In practice, you would use your actual credentials here
    
    print("🔄 Connecting to Snowflake...")
    
    # Simulated Snowflake data (replace with actual Snowpark connection)
    # snowflake_session = create_snowpark_session(config)
    
    # For demonstration, let's create sample Snowflake-like data
    snowflake_sample_data = [
        (1, "Customer#000000001", "Building Supplies", "UNITED STATES", "25-989-741-2988"),
        (2, "Customer#000000002", "Automotive", "CANADA", "23-768-687-3665"),
        (3, "Customer#000000003", "Machinery", "UNITED KINGDOM", "44-123-456-7890"),
        (4, "Customer#000000004", "Furniture", "GERMANY", "49-987-654-3210"),
        (5, "Customer#000000005", "Electronics", "FRANCE", "33-555-123-4567"),
        (10, "Customer#000000010", "Household", "JAPAN", "81-333-444-5555"),
        (15, "Customer#000000015", "Sports", "AUSTRALIA", "61-777-888-9999"),
        (20, "Customer#000000020", "Fashion", "BRAZIL", "55-111-222-3333"),
        (25, "Customer#000000025", "Books", "INDIA", "91-444-555-6666"),
        (30, "Customer#000000030", "Garden", "SOUTH KOREA", "82-666-777-8888")
    ]
    
    snowflake_schema = StructType([
        StructField("c_custkey", IntegerType(), True),
        StructField("c_name", StringType(), True),
        StructField("c_mktsegment", StringType(), True),
        StructField("c_nation", StringType(), True),
        StructField("c_phone", StringType(), True)
    ])
    
    # Create DataFrame to simulate Snowflake data
    snowflake_df = spark.createDataFrame(snowflake_sample_data, snowflake_schema)
    
    print("✅ Snowflake data loaded (simulated)")
    print(f"Rows: {snowflake_df.count()}")
    
    print("\nSample Snowflake Data:")
    display(snowflake_df)
    
except Exception as e:
    print(f"❌ Error connecting to Snowflake: {e}")
    print("Using simulated data for demonstration")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 7. Alternative: Real Snowflake Connection
# MAGIC 
# MAGIC Here's how you would actually connect to Snowflake with real credentials:

# COMMAND ----------

def read_from_snowflake_real(config: SnowflakeDatabricksConfig):
    """
    Real Snowflake connection example (uncomment and configure for actual use)
    """
    
    # Uncomment and configure this section for real Snowflake connection
    """
    try:
        # Create Snowpark session
        snowflake_session = create_snowpark_session(config)
        
        # Query Snowflake data
        snowflake_query = '''
        SELECT 
            C_CUSTKEY,
            C_NAME,
            C_MKTSEGMENT,
            N.N_NAME as C_NATION,
            C_PHONE
        FROM CUSTOMER C
        JOIN NATION N ON C.C_NATIONKEY = N.N_NATIONKEY
        LIMIT 100
        '''
        
        # Execute query and get results
        snowflake_snowpark_df = snowflake_session.sql(snowflake_query)
        snowflake_pandas_df = snowflake_snowpark_df.to_pandas()
        
        # Convert to Spark DataFrame for joining
        snowflake_spark_df = spark.createDataFrame(snowflake_pandas_df)
        
        print("✅ Real Snowflake data loaded")
        return snowflake_spark_df
        
    except Exception as e:
        print(f"❌ Error reading from Snowflake: {e}")
        return None
    finally:
        if 'snowflake_session' in locals():
            snowflake_session.close()
    """
    
    print("💡 Real Snowflake connection code is commented out")
    print("   Update configuration and uncomment to use real Snowflake data")
    return None

# For demonstration, we'll continue with simulated data
real_snowflake_df = read_from_snowflake_real(config)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 8. Read Data from Databricks Table

# COMMAND ----------

# Read the local Databricks table we created earlier
print("🔄 Reading data from Databricks table...")

databricks_table_df = spark.table(f"{config.databricks_database}.{config.databricks_table}")

print("✅ Databricks table data loaded")
print(f"Rows: {databricks_table_df.count()}")

print("\nDatabricks Table Data:")
display(databricks_table_df)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 9. Join Snowflake and Databricks Data
# MAGIC 
# MAGIC Now let's join the data from both sources and display the results.

# COMMAND ----------

print("🔄 Joining Snowflake and Databricks data...")

# Perform inner join on customer_id/c_custkey
joined_df = snowflake_df.alias("sf").join(
    databricks_table_df.alias("db"),
    F.col("sf.c_custkey") == F.col("db.customer_id"),
    "inner"
)

# Select and rename columns for better readability
final_df = joined_df.select(
    F.col("sf.c_custkey").alias("customer_id"),
    F.col("sf.c_name").alias("customer_name"),
    F.col("sf.c_mktsegment").alias("market_segment"),
    F.col("sf.c_nation").alias("country"),
    F.col("sf.c_phone").alias("phone"),
    F.col("db.subscription_type"),
    F.col("db.signup_date"),
    F.col("db.satisfaction_score"),
    F.col("db.status")
).orderBy("customer_id")

print("✅ Data joined successfully")
print(f"Joined rows: {final_df.count()}")

print("\n🎯 Final Joined Results:")
display(final_df)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 10. Advanced Analysis and Visualizations

# COMMAND ----------

# Perform some analysis on the joined data
print("📊 Performing analysis on joined data...")

# Analysis 1: Customer distribution by market segment and subscription type
segment_analysis = final_df.groupBy("market_segment", "subscription_type").agg(
    F.count("*").alias("customer_count"),
    F.avg("satisfaction_score").alias("avg_satisfaction"),
    F.sum(F.when(F.col("status") == "Active", 1).otherwise(0)).alias("active_customers")
).orderBy("market_segment", "subscription_type")

print("\n📈 Customer Distribution by Market Segment and Subscription Type:")
display(segment_analysis)

# Analysis 2: Country-wise subscription analysis
country_analysis = final_df.groupBy("country").agg(
    F.count("*").alias("total_customers"),
    F.avg("satisfaction_score").alias("avg_satisfaction"),
    F.countDistinct("subscription_type").alias("subscription_types"),
    F.sum(F.when(F.col("status") == "Active", 1).otherwise(0)).alias("active_customers")
).orderBy(F.desc("total_customers"))

print("\n🌍 Country-wise Analysis:")
display(country_analysis)

# Analysis 3: Satisfaction score distribution
satisfaction_buckets = final_df.select(
    "*",
    F.when(F.col("satisfaction_score") >= 90, "High (90+)")
     .when(F.col("satisfaction_score") >= 80, "Medium (80-89)")
     .otherwise("Low (<80)").alias("satisfaction_bucket")
)

satisfaction_summary = satisfaction_buckets.groupBy("satisfaction_bucket", "subscription_type").agg(
    F.count("*").alias("customer_count")
).orderBy("satisfaction_bucket", "subscription_type")

print("\n😊 Satisfaction Score Distribution:")
display(satisfaction_summary)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 11. Export Results

# COMMAND ----------

# Save the joined results to a new Databricks table
output_table = "snowflake_databricks_joined"

print(f"💾 Saving joined results to table: {output_table}")

final_df.write.mode("overwrite").saveAsTable(f"{config.databricks_database}.{output_table}")

print("✅ Results saved successfully")

# Also save as Parquet for external use
output_path = "/tmp/snowflake_databricks_joined"
final_df.write.mode("overwrite").parquet(output_path)

print(f"✅ Results also saved as Parquet to: {output_path}")

# Display final summary
print("\n📋 Final Summary:")
print(f"  • Snowflake records processed: {snowflake_df.count()}")
print(f"  • Databricks records processed: {databricks_table_df.count()}")
print(f"  • Successfully joined records: {final_df.count()}")
print(f"  • Output table: {config.databricks_database}.{output_table}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 12. Cleanup and Best Practices

# COMMAND ----------

print("🧹 Cleanup and Best Practices:")

print("""
✅ COMPLETED SUCCESSFULLY!

📝 What we accomplished:
1. ✅ Connected to Snowflake using Snowpark (simulated)
2. ✅ Read data from local Databricks table
3. ✅ Joined datasets from both platforms
4. ✅ Performed advanced analysis
5. ✅ Saved results to new table and Parquet

🔒 Security Best Practices for Production:
1. Use Databricks Secrets for storing Snowflake credentials
2. Implement proper error handling and logging
3. Use connection pooling for better performance
4. Implement data validation and quality checks
5. Set up monitoring and alerting

💡 Performance Optimization Tips:
1. Use appropriate partitioning for large datasets
2. Implement caching for frequently accessed data
3. Consider using Delta Lake for better performance
4. Optimize join strategies based on data size
5. Use broadcast joins for small lookup tables

🔄 Next Steps:
1. Configure real Snowflake credentials
2. Implement automated data pipeline
3. Add data quality validation
4. Set up scheduling with Databricks Jobs
5. Create dashboards for monitoring
""")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 13. Real Snowflake Configuration Template
# MAGIC 
# MAGIC For production use, here's how to properly configure Snowflake credentials:

# COMMAND ----------

# MAGIC %md
# MAGIC ```python
# MAGIC # Production Configuration Template
# MAGIC 
# MAGIC class ProductionSnowflakeConfig:
# MAGIC     def __init__(self):
# MAGIC         # Use Databricks secrets for secure credential management
# MAGIC         self.snowflake_account = dbutils.secrets.get("snowflake", "account")
# MAGIC         self.snowflake_user = dbutils.secrets.get("snowflake", "user")
# MAGIC         self.snowflake_role = dbutils.secrets.get("snowflake", "role")
# MAGIC         self.snowflake_warehouse = dbutils.secrets.get("snowflake", "warehouse")
# MAGIC         self.snowflake_database = dbutils.secrets.get("snowflake", "database")
# MAGIC         self.snowflake_schema = dbutils.secrets.get("snowflake", "schema")
# MAGIC         
# MAGIC         # Private key from secrets
# MAGIC         self.private_key_content = dbutils.secrets.get("snowflake", "private_key")
# MAGIC 
# MAGIC # Setup Databricks secrets (run these commands in Databricks CLI):
# MAGIC # databricks secrets create-scope --scope snowflake
# MAGIC # databricks secrets put --scope snowflake --key account
# MAGIC # databricks secrets put --scope snowflake --key user
# MAGIC # databricks secrets put --scope snowflake --key role
# MAGIC # databricks secrets put --scope snowflake --key warehouse
# MAGIC # databricks secrets put --scope snowflake --key database
# MAGIC # databricks secrets put --scope snowflake --key schema
# MAGIC # databricks secrets put --scope snowflake --key private_key
# MAGIC ```

# COMMAND ----------

print("🎉 Notebook execution completed successfully!")
print("All tasks have been demonstrated with sample data.")
print("Update the configuration section with your real credentials to use with actual Snowflake data.")












