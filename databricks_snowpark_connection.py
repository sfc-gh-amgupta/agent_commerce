"""
================================================================================
DATABRICKS TO SNOWFLAKE CONNECTION USING SNOWPARK
================================================================================
This notebook demonstrates how to connect from Databricks to Snowflake using
Snowpark for Python. It includes multiple authentication methods and common
data operations.

Prerequisites:
1. Install Snowpark library in Databricks cluster
2. Configure authentication credentials (secrets recommended)
3. Ensure network connectivity between Databricks and Snowflake

Author: Snowflake Solutions Engineering
Last Updated: January 2025
================================================================================
"""

# COMMAND ----------
# MAGIC %md
# MAGIC # Databricks to Snowflake Connection with Snowpark
# MAGIC 
# MAGIC This notebook demonstrates various methods to connect from Databricks to Snowflake using Snowpark.
# MAGIC 
# MAGIC ## Setup Requirements
# MAGIC 1. **Install Snowpark**: Add `snowflake-snowpark-python` to your cluster libraries
# MAGIC 2. **Configure Secrets**: Store credentials in Databricks secrets
# MAGIC 3. **Network Access**: Ensure Databricks can reach Snowflake endpoints

# COMMAND ----------
# MAGIC %md
# MAGIC ## 1. Install Required Libraries
# MAGIC 
# MAGIC Run this cell to install Snowpark if not already installed in your cluster

# COMMAND ----------

# Install Snowpark library (if not installed at cluster level)
%pip install snowflake-snowpark-python[pandas]

# Import required libraries
import os
import pandas as pd
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col, lit, sum as spark_sum
from snowflake.snowpark.types import StructType, StructField, StringType, IntegerType, DoubleType
import json

# COMMAND ----------
# MAGIC %md
# MAGIC ## 2. Authentication Methods
# MAGIC 
# MAGIC ### Method 1: Username/Password Authentication

# COMMAND ----------

def create_snowflake_session_password():
    """
    Create Snowflake session using username/password authentication
    Credentials should be stored in Databricks secrets for security
    """
    
    # Retrieve credentials from Databricks secrets (recommended approach)
    # Replace 'your-secret-scope' with your actual secret scope name
    try:
        connection_parameters = {
            "account": dbutils.secrets.get(scope="snowflake-secrets", key="account"),
            "user": dbutils.secrets.get(scope="snowflake-secrets", key="username"),
            "password": dbutils.secrets.get(scope="snowflake-secrets", key="password"),
            "role": dbutils.secrets.get(scope="snowflake-secrets", key="role"),
            "warehouse": dbutils.secrets.get(scope="snowflake-secrets", key="warehouse"),
            "database": dbutils.secrets.get(scope="snowflake-secrets", key="database"),
            "schema": dbutils.secrets.get(scope="snowflake-secrets", key="schema")
        }
    except Exception as e:
        print(f"Error retrieving secrets: {e}")
        print("Using hardcoded values for demo (NOT RECOMMENDED for production)")
        
        # Fallback to hardcoded values (NOT RECOMMENDED for production)
        connection_parameters = {
            "account": "your_account_identifier",  # e.g., "abc123.us-east-1"
            "user": "your_username",
            "password": "your_password",
            "role": "your_role",
            "warehouse": "your_warehouse",
            "database": "your_database", 
            "schema": "your_schema"
        }
    
    # Create Snowpark session
    session = Session.builder.configs(connection_parameters).create()
    
    print("✅ Successfully connected to Snowflake using username/password")
    print(f"Current role: {session.get_current_role()}")
    print(f"Current warehouse: {session.get_current_warehouse()}")
    print(f"Current database: {session.get_current_database()}")
    print(f"Current schema: {session.get_current_schema()}")
    
    return session

# COMMAND ----------
# MAGIC %md
# MAGIC ### Method 2: Key Pair Authentication (Recommended for Production)

# COMMAND ----------

def create_snowflake_session_keypair():
    """
    Create Snowflake session using RSA key pair authentication
    This is the recommended method for production environments
    """
    
    # Read private key from Databricks secrets or DBFS
    try:
        # Option 1: Private key stored as secret (recommended)
        private_key_content = dbutils.secrets.get(scope="snowflake-secrets", key="private-key")
        
        # Option 2: Private key file stored in DBFS
        # private_key_path = "/dbfs/mnt/secrets/snowflake_private_key.pem"
        # with open(private_key_path, 'r') as key_file:
        #     private_key_content = key_file.read()
        
    except Exception as e:
        print(f"Error retrieving private key: {e}")
        return None
    
    # Parse the private key
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.serialization import load_pem_private_key
    
    try:
        private_key = load_pem_private_key(
            private_key_content.encode(),
            password=None,  # Assuming no passphrase
        )
        
        # Get private key in the format Snowpark expects
        private_key_bytes = private_key.private_bytes(
            encoding=serialization.Encoding.DER,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption()
        )
        
    except Exception as e:
        print(f"Error parsing private key: {e}")
        return None
    
    # Connection parameters for key pair authentication
    connection_parameters = {
        "account": dbutils.secrets.get(scope="snowflake-secrets", key="account"),
        "user": dbutils.secrets.get(scope="snowflake-secrets", key="username"),
        "private_key": private_key_bytes,
        "role": dbutils.secrets.get(scope="snowflake-secrets", key="role"),
        "warehouse": dbutils.secrets.get(scope="snowflake-secrets", key="warehouse"),
        "database": dbutils.secrets.get(scope="snowflake-secrets", key="database"),
        "schema": dbutils.secrets.get(scope="snowflake-secrets", key="schema")
    }
    
    # Create Snowpark session
    session = Session.builder.configs(connection_parameters).create()
    
    print("✅ Successfully connected to Snowflake using key pair authentication")
    print(f"Current role: {session.get_current_role()}")
    print(f"Current warehouse: {session.get_current_warehouse()}")
    
    return session

# COMMAND ----------
# MAGIC %md
# MAGIC ### Method 3: OAuth Authentication

# COMMAND ----------

def create_snowflake_session_oauth():
    """
    Create Snowflake session using OAuth authentication
    Requires OAuth token to be obtained through Snowflake OAuth flow
    """
    
    # OAuth token should be obtained through proper OAuth flow
    # This is a simplified example
    try:
        oauth_token = dbutils.secrets.get(scope="snowflake-secrets", key="oauth-token")
        
        connection_parameters = {
            "account": dbutils.secrets.get(scope="snowflake-secrets", key="account"),
            "token": oauth_token,
            "authenticator": "oauth",
            "role": dbutils.secrets.get(scope="snowflake-secrets", key="role"),
            "warehouse": dbutils.secrets.get(scope="snowflake-secrets", key="warehouse"),
            "database": dbutils.secrets.get(scope="snowflake-secrets", key="database"),
            "schema": dbutils.secrets.get(scope="snowflake-secrets", key="schema")
        }
        
        session = Session.builder.configs(connection_parameters).create()
        
        print("✅ Successfully connected to Snowflake using OAuth")
        return session
        
    except Exception as e:
        print(f"Error with OAuth authentication: {e}")
        return None

# COMMAND ----------
# MAGIC %md
# MAGIC ## 3. Establish Connection
# MAGIC 
# MAGIC Choose your preferred authentication method

# COMMAND ----------

# Create Snowflake session (choose your preferred method)
# Method 1: Username/Password
snowflake_session = create_snowflake_session_password()

# Method 2: Key Pair (uncomment to use)
# snowflake_session = create_snowflake_session_keypair()

# Method 3: OAuth (uncomment to use)
# snowflake_session = create_snowflake_session_oauth()

# COMMAND ----------
# MAGIC %md
# MAGIC ## 4. Basic Snowpark Operations

# COMMAND ----------

def test_snowflake_connection(session):
    """
    Test the Snowflake connection with basic operations
    """
    
    if session is None:
        print("❌ No valid session available")
        return
    
    try:
        # Test 1: Get current session information
        print("=== Session Information ===")
        print(f"Account: {session.get_current_account()}")
        print(f"User: {session.get_current_user()}")
        print(f"Role: {session.get_current_role()}")
        print(f"Warehouse: {session.get_current_warehouse()}")
        print(f"Database: {session.get_current_database()}")
        print(f"Schema: {session.get_current_schema()}")
        
        # Test 2: Simple query
        print("\n=== Simple Query Test ===")
        result = session.sql("SELECT CURRENT_TIMESTAMP() as current_time").collect()
        print(f"Current Snowflake time: {result[0]['CURRENT_TIME']}")
        
        # Test 3: Show tables in current schema
        print("\n=== Available Tables ===")
        tables_df = session.sql("SHOW TABLES").collect()
        if tables_df:
            for table in tables_df[:5]:  # Show first 5 tables
                print(f"- {table['name']}")
        else:
            print("No tables found in current schema")
            
        print("\n✅ Connection test completed successfully!")
        
    except Exception as e:
        print(f"❌ Connection test failed: {e}")

# Run connection test
test_snowflake_connection(snowflake_session)

# COMMAND ----------
# MAGIC %md
# MAGIC ## 5. Data Operations Examples

# COMMAND ----------

def demonstrate_snowpark_operations(session):
    """
    Demonstrate common Snowpark operations for data analysis
    """
    
    if session is None:
        print("❌ No valid session available")
        return
    
    try:
        # Example 1: Create a sample DataFrame
        print("=== Creating Sample Data ===")
        
        # Create sample data
        sample_data = [
            ("Alice", "Engineering", 75000, "2020-01-15"),
            ("Bob", "Marketing", 65000, "2019-03-20"),
            ("Charlie", "Sales", 70000, "2021-06-10"),
            ("Diana", "Engineering", 80000, "2018-11-05"),
            ("Eve", "Marketing", 68000, "2022-02-28")
        ]
        
        # Define schema
        schema = StructType([
            StructField("name", StringType()),
            StructField("department", StringType()),
            StructField("salary", IntegerType()),
            StructField("hire_date", StringType())
        ])
        
        # Create Snowpark DataFrame
        df = session.create_dataframe(sample_data, schema)
        
        # Show the data
        print("Sample employee data:")
        df.show()
        
        # Example 2: Data transformations
        print("\n=== Data Transformations ===")
        
        # Filter and select
        high_earners = df.filter(col("salary") > 70000).select("name", "department", "salary")
        print("Employees earning > $70,000:")
        high_earners.show()
        
        # Group by and aggregate
        dept_stats = df.group_by("department").agg(
            spark_sum("salary").alias("total_salary"),
            col("salary").count().alias("employee_count")
        )
        print("Department statistics:")
        dept_stats.show()
        
        # Example 3: Write to Snowflake table (optional)
        print("\n=== Writing to Snowflake ===")
        
        # Uncomment to actually write data
        # table_name = "SAMPLE_EMPLOYEES"
        # df.write.mode("overwrite").save_as_table(table_name)
        # print(f"Data written to table: {table_name}")
        
        print("✅ Snowpark operations completed successfully!")
        
    except Exception as e:
        print(f"❌ Snowpark operations failed: {e}")

# Run Snowpark operations demo
demonstrate_snowpark_operations(snowflake_session)

# COMMAND ----------
# MAGIC %md
# MAGIC ## 6. Reading Data from Snowflake Tables

# COMMAND ----------

def read_snowflake_data(session, table_name):
    """
    Read data from a Snowflake table and convert to Pandas DataFrame
    """
    
    if session is None:
        print("❌ No valid session available")
        return None
    
    try:
        # Read data using Snowpark
        print(f"=== Reading data from {table_name} ===")
        
        # Method 1: Using table() function
        snowpark_df = session.table(table_name)
        
        # Show basic info
        print(f"Table schema:")
        snowpark_df.print_schema()
        
        print(f"\nFirst 10 rows:")
        snowpark_df.limit(10).show()
        
        # Method 2: Using SQL
        sql_df = session.sql(f"SELECT * FROM {table_name} LIMIT 100")
        
        # Convert to Pandas DataFrame for local analysis
        pandas_df = sql_df.to_pandas()
        
        print(f"\nDataFrame shape: {pandas_df.shape}")
        print(f"Columns: {list(pandas_df.columns)}")
        
        return pandas_df
        
    except Exception as e:
        print(f"❌ Error reading data from {table_name}: {e}")
        return None

# Example usage (replace with your actual table name)
# df = read_snowflake_data(snowflake_session, "YOUR_TABLE_NAME")

# COMMAND ----------
# MAGIC %md
# MAGIC ## 7. Advanced Snowpark Features

# COMMAND ----------

def advanced_snowpark_features(session):
    """
    Demonstrate advanced Snowpark features
    """
    
    if session is None:
        print("❌ No valid session available")
        return
    
    try:
        print("=== Advanced Snowpark Features ===")
        
        # Feature 1: User Defined Functions (UDFs)
        from snowflake.snowpark.functions import udf
        from snowflake.snowpark.types import IntegerType
        
        @udf(return_type=IntegerType(), input_types=[IntegerType()])
        def square_udf(x):
            return x * x
        
        # Create sample data to test UDF
        sample_numbers = session.create_dataframe([[1], [2], [3], [4], [5]], ["number"])
        
        # Apply UDF
        result = sample_numbers.select(
            col("number"),
            square_udf(col("number")).alias("squared")
        )
        
        print("UDF Example - Square function:")
        result.show()
        
        # Feature 2: Window functions
        from snowflake.snowpark.window import Window
        from snowflake.snowpark.functions import row_number, rank
        
        # Create sample sales data
        sales_data = [
            ("Alice", "Q1", 1000),
            ("Bob", "Q1", 1200),
            ("Alice", "Q2", 1100),
            ("Bob", "Q2", 1300),
            ("Charlie", "Q1", 900),
            ("Charlie", "Q2", 1050)
        ]
        
        sales_df = session.create_dataframe(
            sales_data, 
            ["salesperson", "quarter", "sales_amount"]
        )
        
        # Define window specification
        window_spec = Window.partition_by("quarter").order_by(col("sales_amount").desc())
        
        # Apply window functions
        ranked_sales = sales_df.select(
            "*",
            row_number().over(window_spec).alias("row_num"),
            rank().over(window_spec).alias("rank")
        )
        
        print("\nWindow Function Example - Sales Ranking:")
        ranked_sales.show()
        
        # Feature 3: Joins between DataFrames
        # Create department data
        dept_data = [
            ("Alice", "Engineering"),
            ("Bob", "Sales"),
            ("Charlie", "Marketing")
        ]
        
        dept_df = session.create_dataframe(dept_data, ["salesperson", "department"])
        
        # Join sales and department data
        joined_df = sales_df.join(
            dept_df, 
            sales_df["salesperson"] == dept_df["salesperson"]
        ).select(
            sales_df["salesperson"],
            dept_df["department"],
            sales_df["quarter"],
            sales_df["sales_amount"]
        )
        
        print("\nJoin Example - Sales with Departments:")
        joined_df.show()
        
        print("✅ Advanced features demonstration completed!")
        
    except Exception as e:
        print(f"❌ Advanced features demonstration failed: {e}")

# Run advanced features demo
advanced_snowpark_features(snowflake_session)

# COMMAND ----------
# MAGIC %md
# MAGIC ## 8. Integration with Databricks DataFrames

# COMMAND ----------

def integrate_with_databricks(session, spark):
    """
    Demonstrate integration between Snowpark and Databricks Spark DataFrames
    """
    
    if session is None:
        print("❌ No valid session available")
        return
    
    try:
        print("=== Databricks Integration ===")
        
        # Create a Databricks DataFrame
        databricks_data = [
            ("Product A", 100, 25.50),
            ("Product B", 150, 30.00),
            ("Product C", 75, 45.25),
            ("Product D", 200, 15.75)
        ]
        
        databricks_df = spark.createDataFrame(
            databricks_data, 
            ["product_name", "quantity", "price"]
        )
        
        print("Databricks DataFrame:")
        databricks_df.show()
        
        # Convert Databricks DataFrame to Pandas
        pandas_df = databricks_df.toPandas()
        
        # Create Snowpark DataFrame from Pandas
        snowpark_df = session.create_dataframe(pandas_df)
        
        print("Converted to Snowpark DataFrame:")
        snowpark_df.show()
        
        # Perform calculations in Snowpark
        enriched_df = snowpark_df.select(
            "*",
            (col("quantity") * col("price")).alias("total_value")
        )
        
        print("Enriched with calculations:")
        enriched_df.show()
        
        # Convert back to Pandas and then to Databricks DataFrame
        result_pandas = enriched_df.to_pandas()
        result_databricks = spark.createDataFrame(result_pandas)
        
        print("Final result in Databricks:")
        result_databricks.show()
        
        print("✅ Databricks integration completed successfully!")
        
    except Exception as e:
        print(f"❌ Databricks integration failed: {e}")

# Run Databricks integration demo
integrate_with_databricks(snowflake_session, spark)

# COMMAND ----------
# MAGIC %md
# MAGIC ## 9. Cleanup and Best Practices

# COMMAND ----------

def cleanup_session(session):
    """
    Properly close Snowflake session and cleanup resources
    """
    
    if session is not None:
        try:
            session.close()
            print("✅ Snowflake session closed successfully")
        except Exception as e:
            print(f"⚠️  Error closing session: {e}")
    else:
        print("ℹ️  No session to close")

# Best Practices Summary
print("""
=== BEST PRACTICES FOR DATABRICKS-SNOWFLAKE INTEGRATION ===

1. 🔐 SECURITY
   - Use Databricks secrets for credentials
   - Prefer key-pair authentication over passwords
   - Implement proper IAM roles and policies
   - Never hardcode credentials in notebooks

2. 📊 PERFORMANCE
   - Use appropriate warehouse sizes in Snowflake
   - Leverage Snowpark pushdown optimizations
   - Consider data locality and transfer costs
   - Use columnar operations when possible

3. 🔄 DATA MANAGEMENT
   - Implement proper error handling
   - Use transactions for data consistency
   - Monitor data freshness and quality
   - Document data lineage and transformations

4. 💰 COST OPTIMIZATION
   - Auto-suspend warehouses when not in use
   - Right-size compute resources
   - Use result caching effectively
   - Monitor and optimize query performance

5. 🛠️ OPERATIONAL
   - Implement proper logging and monitoring
   - Use version control for notebooks
   - Test in development environments first
   - Have rollback procedures ready
""")

# Cleanup (uncomment when done)
# cleanup_session(snowflake_session)

# COMMAND ----------
# MAGIC %md
# MAGIC ## 10. Troubleshooting Guide

# COMMAND ----------

print("""
=== TROUBLESHOOTING COMMON ISSUES ===

❌ CONNECTION ISSUES:
   - Check account identifier format
   - Verify network connectivity
   - Confirm user permissions
   - Validate warehouse is running

❌ AUTHENTICATION ERRORS:
   - Verify credentials in secrets
   - Check private key format
   - Confirm user exists in Snowflake
   - Validate role assignments

❌ PERFORMANCE PROBLEMS:
   - Check warehouse size
   - Monitor query execution plans
   - Optimize data transfer patterns
   - Use appropriate data types

❌ LIBRARY ISSUES:
   - Ensure Snowpark is installed
   - Check Python version compatibility
   - Verify all dependencies
   - Restart cluster if needed

📞 SUPPORT RESOURCES:
   - Snowflake Documentation: docs.snowflake.com
   - Databricks Documentation: docs.databricks.com
   - Community Forums and Stack Overflow
   - Snowflake Support Portal
""")


