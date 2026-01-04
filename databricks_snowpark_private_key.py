"""
================================================================================
DATABRICKS TO SNOWFLAKE CONNECTION USING SNOWPARK WITH PRIVATE KEY
================================================================================
This notebook code demonstrates how to connect from Databricks to Snowflake using
Snowpark with RSA private key authentication. The private key can be stored in
Databricks secrets or uploaded to DBFS.

Features:
- Multiple methods to handle private keys in Databricks
- Secure connection using RSA key pair authentication
- Integration between Databricks and Snowpark DataFrames
- Error handling and connection validation
- Performance optimization techniques

Prerequisites:
1. RSA private key generated on your Mac
2. Public key configured in Snowflake user profile
3. Snowpark library installed in Databricks cluster
4. Private key securely stored in Databricks (secrets or DBFS)

Author: Snowflake Solutions Engineering
Last Updated: January 2025
================================================================================
"""

# COMMAND ----------
# MAGIC %md
# MAGIC # Databricks to Snowflake Connection with Snowpark (Private Key Auth)
# MAGIC 
# MAGIC This notebook demonstrates how to connect from Databricks to Snowflake using Snowpark with private key authentication.
# MAGIC 
# MAGIC ## Setup Methods
# MAGIC 1. **Databricks Secrets** (Recommended for production)
# MAGIC 2. **DBFS File Upload** (Good for development/testing)
# MAGIC 3. **Direct Key Content** (Not recommended for production)

# COMMAND ----------
# MAGIC %md
# MAGIC ## 1. Install Required Libraries

# COMMAND ----------

# Install Snowpark and cryptography libraries
%pip install snowflake-snowpark-python[pandas] cryptography

# Import required libraries
import os
import base64
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col, lit, sum as spark_sum, count, avg
from snowflake.snowpark.types import StructType, StructField, StringType, IntegerType, DoubleType
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.serialization import load_pem_private_key
from cryptography.hazmat.backends import default_backend
import pandas as pd
import json
from typing import Optional, Dict, Any

print("✅ Libraries imported successfully")

# COMMAND ----------
# MAGIC %md
# MAGIC ## 2. Configuration Class

# COMMAND ----------

class DatabricksSnowflakeConfig:
    """
    Configuration class for Databricks to Snowflake connection
    """
    
    def __init__(self):
        # Snowflake connection parameters
        # Update these values according to your Snowflake account
        self.account = "your_account_identifier"  # e.g., "abc123.us-east-1"
        self.user = "your_username"
        self.role = "your_role"  # Optional
        self.warehouse = "your_warehouse"  # Optional
        self.database = "your_database"  # Optional
        self.schema = "your_schema"  # Optional
        
        # Databricks secrets configuration
        self.secret_scope = "snowflake-secrets"  # Your secret scope name
        self.private_key_secret = "private-key"  # Secret key name for private key
        
        # DBFS paths for private key (alternative to secrets)
        self.dbfs_key_paths = [
            "/dbfs/mnt/secrets/snowflake_private_key.pem",
            "/dbfs/FileStore/shared_uploads/snowflake_private_key.pem",
            "/dbfs/tmp/snowflake_private_key.pem"
        ]
        
        # Load from environment if available
        self.load_from_environment()
    
    def load_from_environment(self):
        """Load configuration from environment variables if available"""
        self.account = os.getenv("SNOWFLAKE_ACCOUNT", self.account)
        self.user = os.getenv("SNOWFLAKE_USER", self.user)
        self.role = os.getenv("SNOWFLAKE_ROLE", self.role)
        self.warehouse = os.getenv("SNOWFLAKE_WAREHOUSE", self.warehouse)
        self.database = os.getenv("SNOWFLAKE_DATABASE", self.database)
        self.schema = os.getenv("SNOWFLAKE_SCHEMA", self.schema)

# Initialize configuration
config = DatabricksSnowflakeConfig()
print("✅ Configuration initialized")

# COMMAND ----------
# MAGIC %md
# MAGIC ## 3. Private Key Handling Methods

# COMMAND ----------

def load_private_key_from_secrets(scope: str, key_name: str, passphrase: Optional[str] = None) -> Optional[bytes]:
    """
    Load private key from Databricks secrets
    
    Args:
        scope: Databricks secret scope name
        key_name: Secret key name containing the private key
        passphrase: Optional passphrase for encrypted keys
        
    Returns:
        Private key in DER format (bytes) or None if failed
    """
    
    try:
        # Get private key content from Databricks secrets
        private_key_content = dbutils.secrets.get(scope=scope, key=key_name)
        
        # Convert to bytes if it's a string
        if isinstance(private_key_content, str):
            private_key_content = private_key_content.encode()
        
        # Load the private key
        passphrase_bytes = passphrase.encode() if passphrase else None
        
        private_key = load_pem_private_key(
            private_key_content,
            password=passphrase_bytes,
            backend=default_backend()
        )
        
        # Convert to DER format for Snowpark
        private_key_der = private_key.private_bytes(
            encoding=serialization.Encoding.DER,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption()
        )
        
        print("✅ Private key loaded from Databricks secrets")
        return private_key_der
        
    except Exception as e:
        print(f"❌ Error loading private key from secrets: {e}")
        return None

def load_private_key_from_dbfs(file_path: str, passphrase: Optional[str] = None) -> Optional[bytes]:
    """
    Load private key from DBFS file
    
    Args:
        file_path: Path to private key file in DBFS
        passphrase: Optional passphrase for encrypted keys
        
    Returns:
        Private key in DER format (bytes) or None if failed
    """
    
    try:
        # Read private key file from DBFS
        with open(file_path, 'rb') as key_file:
            private_key_content = key_file.read()
        
        # Load the private key
        passphrase_bytes = passphrase.encode() if passphrase else None
        
        private_key = load_pem_private_key(
            private_key_content,
            password=passphrase_bytes,
            backend=default_backend()
        )
        
        # Convert to DER format for Snowpark
        private_key_der = private_key.private_bytes(
            encoding=serialization.Encoding.DER,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption()
        )
        
        print(f"✅ Private key loaded from DBFS: {file_path}")
        return private_key_der
        
    except FileNotFoundError:
        print(f"❌ Private key file not found: {file_path}")
        return None
    except Exception as e:
        print(f"❌ Error loading private key from DBFS: {e}")
        return None

def load_private_key_from_content(private_key_content: str, passphrase: Optional[str] = None) -> Optional[bytes]:
    """
    Load private key from direct content (not recommended for production)
    
    Args:
        private_key_content: Private key content as string
        passphrase: Optional passphrase for encrypted keys
        
    Returns:
        Private key in DER format (bytes) or None if failed
    """
    
    try:
        # Convert to bytes
        private_key_bytes = private_key_content.encode()
        
        # Load the private key
        passphrase_bytes = passphrase.encode() if passphrase else None
        
        private_key = load_pem_private_key(
            private_key_bytes,
            password=passphrase_bytes,
            backend=default_backend()
        )
        
        # Convert to DER format for Snowpark
        private_key_der = private_key.private_bytes(
            encoding=serialization.Encoding.DER,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption()
        )
        
        print("✅ Private key loaded from content")
        return private_key_der
        
    except Exception as e:
        print(f"❌ Error loading private key from content: {e}")
        return None

def find_and_load_private_key(config: DatabricksSnowflakeConfig) -> Optional[bytes]:
    """
    Try multiple methods to find and load the private key
    
    Args:
        config: Configuration object
        
    Returns:
        Private key in DER format (bytes) or None if failed
    """
    
    print("🔍 Searching for private key...")
    
    # Method 1: Try Databricks secrets first (recommended)
    try:
        private_key_der = load_private_key_from_secrets(
            config.secret_scope, 
            config.private_key_secret
        )
        if private_key_der:
            return private_key_der
    except Exception as e:
        print(f"⚠️  Secrets method failed: {e}")
    
    # Method 2: Try DBFS file paths
    for dbfs_path in config.dbfs_key_paths:
        if os.path.exists(dbfs_path):
            private_key_der = load_private_key_from_dbfs(dbfs_path)
            if private_key_der:
                return private_key_der
    
    print("❌ Could not find private key using any method")
    return None

print("✅ Private key handling functions defined")

# COMMAND ----------
# MAGIC %md
# MAGIC ## 4. Snowpark Session Creation

# COMMAND ----------

def create_snowpark_session(config: DatabricksSnowflakeConfig) -> Optional[Session]:
    """
    Create Snowpark session using private key authentication
    
    Args:
        config: Configuration object
        
    Returns:
        Snowpark Session object or None if failed
    """
    
    print("🚀 Creating Snowpark session with private key authentication...")
    
    # Load private key
    private_key_der = find_and_load_private_key(config)
    if not private_key_der:
        print("❌ Cannot create session without private key")
        return None
    
    # Build connection parameters
    connection_parameters = {
        "account": config.account,
        "user": config.user,
        "private_key": private_key_der,
    }
    
    # Add optional parameters if specified
    if config.role:
        connection_parameters["role"] = config.role
    if config.warehouse:
        connection_parameters["warehouse"] = config.warehouse
    if config.database:
        connection_parameters["database"] = config.database
    if config.schema:
        connection_parameters["schema"] = config.schema
    
    # Create Snowpark session
    try:
        session = Session.builder.configs(connection_parameters).create()
        
        print("✅ Successfully connected to Snowflake using private key authentication")
        print(f"📊 Current database: {session.get_current_database()}")
        print(f"📊 Current schema: {session.get_current_schema()}")
        print(f"👤 Current user: {session.get_current_user()}")
        print(f"🏢 Current role: {session.get_current_role()}")
        
        return session
        
    except Exception as e:
        print(f"❌ Failed to create Snowpark session: {e}")
        return None

def test_snowpark_connection(session: Session) -> bool:
    """
    Test the Snowpark connection with basic operations
    
    Args:
        session: Snowpark Session object
        
    Returns:
        True if test passed, False otherwise
    """
    
    if not session:
        print("❌ No session provided for testing")
        return False
    
    try:
        print("\n=== Testing Snowpark Connection ===")
        
        # Test 1: Simple query
        result = session.sql("SELECT CURRENT_TIMESTAMP() as current_time, CURRENT_VERSION() as version").collect()
        print(f"✅ Current Snowflake time: {result[0]['CURRENT_TIME']}")
        print(f"✅ Snowflake version: {result[0]['VERSION']}")
        
        # Test 2: Create and query a simple DataFrame
        sample_data = [("Alice", 25), ("Bob", 30), ("Charlie", 35)]
        df = session.create_dataframe(sample_data, schema=["name", "age"])
        
        print(f"✅ Created DataFrame with {df.count()} rows")
        df.show()
        
        # Test 3: Basic aggregation
        avg_age = df.agg({"age": "avg"}).collect()[0][0]
        print(f"✅ Average age: {avg_age}")
        
        return True
        
    except Exception as e:
        print(f"❌ Connection test failed: {e}")
        return False

# Create Snowpark session
snowpark_session = create_snowpark_session(config)

# Test the connection
if snowpark_session:
    connection_ok = test_snowpark_connection(snowpark_session)
else:
    connection_ok = False
    print("❌ Could not establish Snowpark session")

# COMMAND ----------
# MAGIC %md
# MAGIC ## 5. Setup Instructions for Private Key

# COMMAND ----------

def print_setup_instructions():
    """
    Print detailed setup instructions for private key configuration
    """
    
    print("""
=== SETUP INSTRUCTIONS FOR PRIVATE KEY ===

🔑 STEP 1: PREPARE YOUR PRIVATE KEY ON MAC
   You already have the private key at:
   /Users/amgupta/Documents/Snowflake/Demo/Interoperability Demo/snowflake_private_key.pem

🔐 STEP 2: SECURE STORAGE IN DATABRICKS (Choose one method)

   METHOD A: DATABRICKS SECRETS (RECOMMENDED)
   1. Create a secret scope:
      databricks secrets create-scope --scope snowflake-secrets
   
   2. Upload your private key content:
      databricks secrets put --scope snowflake-secrets --key private-key
      (Paste the entire private key content including headers)
   
   3. Verify the secret:
      databricks secrets list --scope snowflake-secrets

   METHOD B: DBFS FILE UPLOAD
   1. Upload via Databricks UI:
      - Go to Data > DBFS > FileStore > shared_uploads
      - Upload your snowflake_private_key.pem file
   
   2. Or use Databricks CLI:
      databricks fs cp /path/to/snowflake_private_key.pem dbfs:/FileStore/shared_uploads/

📋 STEP 3: UPDATE CONFIGURATION
   Update the DatabricksSnowflakeConfig class with your actual values:
   - account: Your Snowflake account identifier
   - user: Your Snowflake username
   - role, warehouse, database, schema: Your Snowflake resources

❄️ STEP 4: VERIFY PUBLIC KEY IN SNOWFLAKE
   Ensure your public key is configured in Snowflake:
   ALTER USER your_username SET RSA_PUBLIC_KEY='<your_public_key_content>';

🚀 STEP 5: RUN THE CONNECTION
   Execute the cells above to test the connection!
""")

# Display setup instructions
print_setup_instructions()

# COMMAND ----------
# MAGIC %md
# MAGIC ## 6. Alternative: Direct Key Content Method (Development Only)

# COMMAND ----------

def setup_private_key_direct():
    """
    Alternative method: Use private key content directly
    WARNING: Only for development/testing - not recommended for production
    """
    
    # IMPORTANT: Replace this with your actual private key content
    # This is just an example format
    private_key_content = """-----BEGIN PRIVATE KEY-----
YOUR_PRIVATE_KEY_CONTENT_HERE
Replace this entire block with your actual private key content
from /Users/amgupta/Documents/Snowflake/Demo/Interoperability Demo/snowflake_private_key.pem
-----END PRIVATE KEY-----"""
    
    print("⚠️  WARNING: Using direct private key content")
    print("⚠️  This method is NOT recommended for production use")
    print("⚠️  Consider using Databricks secrets instead")
    
    # Load private key from content
    private_key_der = load_private_key_from_content(private_key_content)
    
    if private_key_der:
        # Create session with direct key
        connection_parameters = {
            "account": config.account,
            "user": config.user,
            "private_key": private_key_der,
            "role": config.role,
            "warehouse": config.warehouse,
            "database": config.database,
            "schema": config.schema
        }
        
        try:
            session = Session.builder.configs(connection_parameters).create()
            print("✅ Connected using direct private key content")
            return session
        except Exception as e:
            print(f"❌ Failed to connect: {e}")
            return None
    else:
        print("❌ Failed to load private key from content")
        return None

# Uncomment the following lines to use direct key content method
# print("=== DIRECT KEY CONTENT METHOD ===")
# direct_session = setup_private_key_direct()

# COMMAND ----------
# MAGIC %md
# MAGIC ## 7. Data Operations and Integration

# COMMAND ----------

def demonstrate_databricks_snowpark_integration(snowpark_session: Session):
    """
    Demonstrate integration between Databricks and Snowpark DataFrames
    """
    
    if not snowpark_session:
        print("❌ No Snowpark session available")
        return
    
    print("=== DATABRICKS-SNOWPARK INTEGRATION ===")
    
    try:
        # 1. Create sample data in Databricks
        print("\n1. Creating sample data in Databricks:")
        databricks_data = [
            ("Product A", "Electronics", 100, 25.50),
            ("Product B", "Books", 150, 12.99),
            ("Product C", "Clothing", 75, 45.00),
            ("Product D", "Electronics", 200, 89.99),
            ("Product E", "Books", 120, 18.50)
        ]
        
        # Create Databricks DataFrame
        databricks_df = spark.createDataFrame(
            databricks_data, 
            ["product_name", "category", "quantity", "price"]
        )
        
        print("Databricks DataFrame:")
        databricks_df.show()
        
        # 2. Convert to Pandas and then to Snowpark
        print("\n2. Converting Databricks → Pandas → Snowpark:")
        pandas_df = databricks_df.toPandas()
        
        # Create Snowpark DataFrame from Pandas
        snowpark_df = snowpark_session.create_dataframe(pandas_df)
        
        print("Snowpark DataFrame:")
        snowpark_df.show()
        
        # 3. Perform operations in Snowpark
        print("\n3. Performing operations in Snowpark:")
        
        # Add calculated column
        enriched_df = snowpark_df.select(
            "*",
            (col("quantity") * col("price")).alias("total_value")
        )
        
        # Group by category
        category_summary = enriched_df.group_by("category").agg(
            spark_sum("total_value").alias("total_revenue"),
            spark_sum("quantity").alias("total_quantity"),
            avg("price").alias("avg_price")
        ).order_by(col("total_revenue").desc())
        
        print("Category Summary:")
        category_summary.show()
        
        # 4. Convert back to Databricks
        print("\n4. Converting Snowpark → Pandas → Databricks:")
        result_pandas = category_summary.to_pandas()
        result_databricks = spark.createDataFrame(result_pandas)
        
        print("Final result in Databricks:")
        result_databricks.show()
        
        # 5. Save to Snowflake table (optional)
        print("\n5. Saving to Snowflake table:")
        table_name = "DATABRICKS_INTEGRATION_DEMO"
        
        # Uncomment to actually save
        # enriched_df.write.mode("overwrite").save_as_table(table_name)
        # print(f"✅ Data saved to Snowflake table: {table_name}")
        
        print("✅ Databricks-Snowpark integration demo completed!")
        
    except Exception as e:
        print(f"❌ Error in integration demo: {e}")

# Run integration demo if session is available
if snowpark_session and connection_ok:
    demonstrate_databricks_snowpark_integration(snowpark_session)

# COMMAND ----------
# MAGIC %md
# MAGIC ## 8. Reading Data from Snowflake Tables

# COMMAND ----------

def read_snowflake_tables(session: Session):
    """
    Demonstrate reading data from Snowflake tables
    """
    
    if not session:
        print("❌ No Snowpark session available")
        return
    
    print("=== READING DATA FROM SNOWFLAKE ===")
    
    try:
        # 1. List available tables
        print("\n1. Available tables in current schema:")
        try:
            tables_result = session.sql("SHOW TABLES").collect()
            if tables_result:
                for table in tables_result[:5]:  # Show first 5 tables
                    print(f"   - {table['name']} ({table['rows']} rows)")
            else:
                print("   No tables found in current schema")
        except Exception as e:
            print(f"   Could not list tables: {e}")
        
        # 2. Example: Read from a table (if it exists)
        print("\n2. Example table read:")
        
        # Try to read from common table names
        sample_tables = ["CUSTOMERS", "ORDERS", "PRODUCTS", "EMPLOYEES"]
        
        for table_name in sample_tables:
            try:
                df = session.table(table_name)
                count = df.count()
                print(f"✅ Found table {table_name} with {count} rows")
                
                # Show sample data
                print(f"Sample data from {table_name}:")
                df.limit(3).show()
                break
                
            except Exception:
                continue
        else:
            print("   No sample tables found - creating demo data")
            
            # Create sample data if no tables exist
            demo_data = [
                (1, "Alice Johnson", "alice@email.com"),
                (2, "Bob Smith", "bob@email.com"),
                (3, "Charlie Brown", "charlie@email.com")
            ]
            
            demo_df = session.create_dataframe(
                demo_data,
                schema=["id", "name", "email"]
            )
            
            print("Demo DataFrame:")
            demo_df.show()
        
        # 3. SQL query example
        print("\n3. SQL query example:")
        sql_result = session.sql("""
            SELECT 
                CURRENT_DATABASE() as current_db,
                CURRENT_SCHEMA() as current_schema,
                CURRENT_USER() as current_user,
                CURRENT_ROLE() as current_role
        """).collect()
        
        for row in sql_result:
            print(f"   Database: {row['CURRENT_DB']}")
            print(f"   Schema: {row['CURRENT_SCHEMA']}")
            print(f"   User: {row['CURRENT_USER']}")
            print(f"   Role: {row['CURRENT_ROLE']}")
        
    except Exception as e:
        print(f"❌ Error reading Snowflake data: {e}")

# Read Snowflake data if session is available
if snowpark_session and connection_ok:
    read_snowflake_tables(snowpark_session)

# COMMAND ----------
# MAGIC %md
# MAGIC ## 9. Performance Optimization Tips

# COMMAND ----------

def demonstrate_performance_tips(session: Session):
    """
    Demonstrate performance optimization techniques
    """
    
    if not session:
        print("❌ No Snowpark session available")
        return
    
    print("=== PERFORMANCE OPTIMIZATION TIPS ===")
    
    try:
        # 1. Use appropriate data types
        print("\n1. Use appropriate data types:")
        
        # Create DataFrame with proper types
        typed_data = [
            (1, "Product A", 100.50, True),
            (2, "Product B", 200.75, False),
            (3, "Product C", 150.25, True)
        ]
        
        schema = StructType([
            StructField("id", IntegerType()),
            StructField("name", StringType()),
            StructField("price", DoubleType()),
            StructField("active", StringType())  # Should be BooleanType for better performance
        ])
        
        df = session.create_dataframe(typed_data, schema)
        print("✅ Use proper data types in schema definition")
        
        # 2. Filter early
        print("\n2. Filter data early to reduce processing:")
        filtered_df = df.filter(col("price") > 120)
        print(f"✅ Filtered DataFrame: {filtered_df.count()} rows")
        
        # 3. Select only needed columns
        print("\n3. Select only required columns:")
        selected_df = df.select("name", "price")
        print("✅ Column pruning reduces data transfer")
        selected_df.show()
        
        # 4. Use caching for repeated operations
        print("\n4. Cache DataFrames for repeated use:")
        # Note: Snowpark automatically optimizes queries
        cached_df = df.cache_result()
        print("✅ DataFrame cached for repeated operations")
        
        # 5. Batch operations
        print("\n5. Batch operations when possible:")
        batch_operations = df.select(
            "*",
            (col("price") * 1.1).alias("price_with_tax"),
            (col("price") * 0.9).alias("discounted_price")
        )
        print("✅ Multiple calculations in single operation")
        batch_operations.show()
        
    except Exception as e:
        print(f"❌ Error in performance demo: {e}")

# Run performance tips if session is available
if snowpark_session and connection_ok:
    demonstrate_performance_tips(snowpark_session)

# COMMAND ----------
# MAGIC %md
# MAGIC ## 10. Cleanup and Best Practices

# COMMAND ----------

def cleanup_and_best_practices(session: Optional[Session]):
    """
    Cleanup resources and display best practices
    """
    
    print("=== CLEANUP AND BEST PRACTICES ===")
    
    # Cleanup session
    if session:
        try:
            session.close()
            print("✅ Snowpark session closed successfully")
        except Exception as e:
            print(f"⚠️  Error closing session: {e}")
    
    # Best practices
    print("""
🔐 SECURITY BEST PRACTICES:
   • Store private keys in Databricks secrets, not in code
   • Use least-privilege roles in Snowflake
   • Regularly rotate private keys
   • Monitor access logs and usage

📊 PERFORMANCE BEST PRACTICES:
   • Filter data early in your transformations
   • Use appropriate data types
   • Leverage Snowpark's pushdown optimizations
   • Cache results for repeated operations
   • Use column pruning to reduce data transfer

💰 COST OPTIMIZATION:
   • Use auto-suspend warehouses
   • Right-size your Snowflake warehouses
   • Monitor query performance and costs
   • Use clustering keys for large tables
   • Leverage result caching

🛠️ OPERATIONAL BEST PRACTICES:
   • Implement proper error handling
   • Use logging for debugging
   • Test connections before running operations
   • Document your data transformations
   • Use version control for notebooks

🔍 TROUBLESHOOTING:
   • Check private key format and permissions
   • Verify Snowflake user configuration
   • Monitor network connectivity
   • Use query history for debugging
   • Check Databricks cluster logs
""")

# Run cleanup
cleanup_and_best_practices(snowpark_session)

# COMMAND ----------
# MAGIC %md
# MAGIC ## 11. Troubleshooting Guide

# COMMAND ----------

print("""
=== TROUBLESHOOTING COMMON ISSUES ===

❌ "Private key file not found":
   • Check DBFS file paths
   • Verify file upload to Databricks
   • Ensure correct secret scope and key names

❌ "Failed to load private key":
   • Verify private key format (PEM)
   • Check if key is encrypted (needs passphrase)
   • Ensure key file is not corrupted

❌ "Authentication failed":
   • Verify public key is set in Snowflake user profile
   • Check Snowflake username matches exactly
   • Confirm account identifier is correct

❌ "Permission denied":
   • Check Databricks cluster permissions
   • Verify secret scope access
   • Ensure DBFS file permissions

❌ "Connection timeout":
   • Check network connectivity from Databricks
   • Verify Snowflake account identifier
   • Confirm firewall/security group settings

❌ "Library import errors":
   • Install snowflake-snowpark-python in cluster
   • Install cryptography library
   • Restart cluster after library installation

📞 SUPPORT RESOURCES:
   • Snowflake Documentation: docs.snowflake.com
   • Databricks Documentation: docs.databricks.com
   • Snowpark Python Guide: docs.snowflake.com/en/developer-guide/snowpark/python
   • Community Forums: community.snowflake.com
""")

print("🎉 Databricks to Snowflake connection setup complete!")
print("📝 Remember to update the configuration with your actual Snowflake details")
print("🔑 Ensure your private key is securely stored in Databricks secrets or DBFS")


