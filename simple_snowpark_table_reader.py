"""
================================================================================
SIMPLE SNOWPARK TABLE READER
================================================================================
A simple script that demonstrates reading from Snowflake tables using SQL
and displaying results in tabular form using Snowpark Python.

Features:
- Simple connection setup using private key authentication
- Execute SQL queries against Snowflake tables
- Display results in formatted tabular output
- Support for both Snowpark DataFrame methods and raw SQL
- Examples using Snowflake sample data

Prerequisites:
1. Snowpark library: pip install snowflake-snowpark-python
2. Pandas for better table formatting: pip install pandas
3. Private key authentication configured (see snowpark_private_key_connection.py)

Author: Snowflake Solutions Engineering
================================================================================
"""

import os
import pandas as pd
from snowflake.snowpark import Session
from snowflake.snowpark.functions import col
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.serialization import load_pem_private_key
from cryptography.hazmat.backends import default_backend
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# ============================================================================
# CONFIGURATION
# ============================================================================

class SimpleSnowflakeConfig:
    """Simple configuration for Snowflake connection"""
    
    def __init__(self):
        # Update these values for your Snowflake account
        self.account = "your_account_identifier"  # e.g., "abc123.us-east-1"
        self.user = "your_username"
        self.role = "your_role"  # Optional
        self.warehouse = "your_warehouse"  # Optional
        self.database = "SNOWFLAKE_SAMPLE_DATA"  # Using sample data by default
        self.schema = "TPCH_SF1"  # Sample schema
        
        # Private key file path
        self.private_key_path = "/Users/amgupta/Documents/Snowflake/Demo/Interoperability Demo/snowflake_private_key.pem"
        
        # Load from environment variables if available
        self.account = os.getenv("SNOWFLAKE_ACCOUNT", self.account)
        self.user = os.getenv("SNOWFLAKE_USER", self.user)
        self.role = os.getenv("SNOWFLAKE_ROLE", self.role)
        self.warehouse = os.getenv("SNOWFLAKE_WAREHOUSE", self.warehouse)
        self.database = os.getenv("SNOWFLAKE_DATABASE", self.database)
        self.schema = os.getenv("SNOWFLAKE_SCHEMA", self.schema)
        self.private_key_path = os.getenv("SNOWFLAKE_PRIVATE_KEY_PATH", self.private_key_path)

# ============================================================================
# CONNECTION FUNCTIONS
# ============================================================================

def load_private_key(key_file_path: str) -> bytes:
    """Load private key from file and return in DER format"""
    
    try:
        with open(key_file_path, 'rb') as key_file:
            key_data = key_file.read()
        
        # Load PEM private key
        private_key = load_pem_private_key(
            key_data,
            password=None,  # Assuming no passphrase for simplicity
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

def create_snowpark_session(config: SimpleSnowflakeConfig) -> Session:
    """Create and return a Snowpark session"""
    
    # Load private key
    private_key_der = load_private_key(config.private_key_path)
    
    # Connection parameters
    connection_parameters = {
        "account": config.account,
        "user": config.user,
        "private_key": private_key_der,
    }
    
    # Add optional parameters
    if config.role:
        connection_parameters["role"] = config.role
    if config.warehouse:
        connection_parameters["warehouse"] = config.warehouse
    if config.database:
        connection_parameters["database"] = config.database
    if config.schema:
        connection_parameters["schema"] = config.schema
    
    # Create session
    try:
        session = Session.builder.configs(connection_parameters).create()
        logger.info("✅ Successfully connected to Snowflake")
        return session
    except Exception as e:
        logger.error(f"❌ Failed to create session: {e}")
        raise

# ============================================================================
# TABLE READING FUNCTIONS
# ============================================================================

def display_table_info(session: Session, table_name: str):
    """Display basic information about a table"""
    
    print(f"\n{'='*60}")
    print(f"TABLE INFORMATION: {table_name}")
    print(f"{'='*60}")
    
    try:
        # Get table description
        desc_query = f"DESCRIBE TABLE {table_name}"
        desc_result = session.sql(desc_query).collect()
        
        print(f"\nTable Schema:")
        print("-" * 40)
        for row in desc_result:
            print(f"{row['name']:<20} {row['type']:<15} {row['null?']}")
        
        # Get row count
        count_query = f"SELECT COUNT(*) as row_count FROM {table_name}"
        count_result = session.sql(count_query).collect()
        row_count = count_result[0]['ROW_COUNT']
        print(f"\nTotal Rows: {row_count:,}")
        
    except Exception as e:
        logger.error(f"Error getting table info: {e}")

def read_table_with_sql(session: Session, sql_query: str, limit: int = 10) -> pd.DataFrame:
    """Execute SQL query and return results as pandas DataFrame"""
    
    try:
        logger.info(f"Executing SQL: {sql_query}")
        
        # Execute query and collect results
        snowpark_df = session.sql(sql_query)
        results = snowpark_df.collect()
        
        # Convert to pandas DataFrame for better display
        if results:
            # Get column names from the first row
            columns = list(results[0].as_dict().keys())
            
            # Convert rows to list of dictionaries
            data = [row.as_dict() for row in results]
            
            # Create pandas DataFrame
            pandas_df = pd.DataFrame(data, columns=columns)
            
            logger.info(f"Query returned {len(results)} rows")
            return pandas_df
        else:
            logger.info("Query returned no results")
            return pd.DataFrame()
            
    except Exception as e:
        logger.error(f"Error executing query: {e}")
        raise

def read_table_with_snowpark_df(session: Session, table_name: str, limit: int = 10) -> pd.DataFrame:
    """Read table using Snowpark DataFrame methods"""
    
    try:
        logger.info(f"Reading table {table_name} using Snowpark DataFrame")
        
        # Create Snowpark DataFrame from table
        snowpark_df = session.table(table_name)
        
        # Apply limit and collect
        results = snowpark_df.limit(limit).collect()
        
        # Convert to pandas DataFrame
        if results:
            columns = list(results[0].as_dict().keys())
            data = [row.as_dict() for row in results]
            pandas_df = pd.DataFrame(data, columns=columns)
            
            logger.info(f"Retrieved {len(results)} rows from {table_name}")
            return pandas_df
        else:
            logger.info(f"No data found in {table_name}")
            return pd.DataFrame()
            
    except Exception as e:
        logger.error(f"Error reading table {table_name}: {e}")
        raise

def display_dataframe(df: pd.DataFrame, title: str = "Query Results"):
    """Display pandas DataFrame in a formatted way"""
    
    print(f"\n{'='*80}")
    print(f"{title}")
    print(f"{'='*80}")
    
    if df.empty:
        print("No data to display")
        return
    
    # Set pandas display options for better formatting
    pd.set_option('display.max_columns', None)
    pd.set_option('display.width', None)
    pd.set_option('display.max_colwidth', 30)
    
    print(f"\nShape: {df.shape[0]} rows × {df.shape[1]} columns")
    print("\nData:")
    print("-" * 80)
    print(df.to_string(index=False))
    print("-" * 80)

# ============================================================================
# EXAMPLE QUERIES
# ============================================================================

def run_example_queries(session: Session):
    """Run example queries against Snowflake sample data"""
    
    print(f"\n{'='*80}")
    print("RUNNING EXAMPLE QUERIES")
    print(f"{'='*80}")
    
    # Example 1: Simple SELECT from CUSTOMER table
    print("\n1. Simple SELECT from CUSTOMER table (first 5 rows)")
    query1 = """
    SELECT 
        C_CUSTKEY,
        C_NAME,
        C_ADDRESS,
        C_NATIONKEY,
        C_PHONE,
        C_MKTSEGMENT
    FROM CUSTOMER 
    LIMIT 5
    """
    
    df1 = read_table_with_sql(session, query1)
    display_dataframe(df1, "Customer Data Sample")
    
    # Example 2: Aggregation query
    print("\n2. Customer count by market segment")
    query2 = """
    SELECT 
        C_MKTSEGMENT,
        COUNT(*) as CUSTOMER_COUNT
    FROM CUSTOMER 
    GROUP BY C_MKTSEGMENT
    ORDER BY CUSTOMER_COUNT DESC
    """
    
    df2 = read_table_with_sql(session, query2)
    display_dataframe(df2, "Customers by Market Segment")
    
    # Example 3: JOIN query
    print("\n3. Customer orders with nation information")
    query3 = """
    SELECT 
        c.C_NAME as CUSTOMER_NAME,
        n.N_NAME as NATION,
        COUNT(o.O_ORDERKEY) as ORDER_COUNT,
        SUM(o.O_TOTALPRICE) as TOTAL_SPENT
    FROM CUSTOMER c
    JOIN NATION n ON c.C_NATIONKEY = n.N_NATIONKEY
    JOIN ORDERS o ON c.C_CUSTKEY = o.O_CUSTKEY
    GROUP BY c.C_NAME, n.N_NAME
    ORDER BY TOTAL_SPENT DESC
    LIMIT 10
    """
    
    df3 = read_table_with_sql(session, query3)
    display_dataframe(df3, "Top Customers by Total Spent")
    
    # Example 4: Using Snowpark DataFrame methods
    print("\n4. Using Snowpark DataFrame methods - LINEITEM sample")
    df4 = read_table_with_snowpark_df(session, "LINEITEM", limit=5)
    display_dataframe(df4, "LINEITEM Sample (Snowpark DataFrame)")

def run_custom_query(session: Session):
    """Allow user to run a custom query"""
    
    print(f"\n{'='*80}")
    print("CUSTOM QUERY EXECUTION")
    print(f"{'='*80}")
    
    print("\nEnter your SQL query (or press Enter to skip):")
    print("Example: SELECT * FROM REGION")
    
    query = input("SQL> ").strip()
    
    if query:
        try:
            df = read_table_with_sql(session, query)
            display_dataframe(df, "Custom Query Results")
        except Exception as e:
            print(f"Error executing custom query: {e}")
    else:
        print("Skipping custom query")

# ============================================================================
# MAIN FUNCTION
# ============================================================================

def main():
    """Main function to demonstrate table reading with Snowpark"""
    
    print("🔍 Simple Snowpark Table Reader")
    print("=" * 60)
    
    # Load configuration
    config = SimpleSnowflakeConfig()
    
    print(f"Connecting to: {config.account}")
    print(f"Database: {config.database}")
    print(f"Schema: {config.schema}")
    
    # Create session
    try:
        session = create_snowpark_session(config)
        
        # Display current session info
        print(f"\n✅ Connected successfully!")
        print(f"Current User: {session.get_current_user()}")
        print(f"Current Role: {session.get_current_role()}")
        print(f"Current Warehouse: {session.get_current_warehouse()}")
        print(f"Current Database: {session.get_current_database()}")
        print(f"Current Schema: {session.get_current_schema()}")
        
        # Show available tables in current schema
        print(f"\n📋 Available tables in {config.database}.{config.schema}:")
        tables_query = f"SHOW TABLES IN SCHEMA {config.database}.{config.schema}"
        tables_result = session.sql(tables_query).collect()
        
        for i, table in enumerate(tables_result[:10], 1):  # Show first 10 tables
            print(f"{i:2d}. {table['name']}")
        
        if len(tables_result) > 10:
            print(f"    ... and {len(tables_result) - 10} more tables")
        
        # Run example queries
        run_example_queries(session)
        
        # Optional: Run custom query
        run_custom_query(session)
        
    except Exception as e:
        logger.error(f"Error in main execution: {e}")
        print(f"\n❌ Error: {e}")
        print("\nPlease check your configuration and ensure:")
        print("1. Your Snowflake account details are correct")
        print("2. Private key file exists and is readable")
        print("3. Public key is configured in your Snowflake user profile")
        print("4. You have access to the SNOWFLAKE_SAMPLE_DATA database")
        
    finally:
        # Clean up
        try:
            if 'session' in locals():
                session.close()
                logger.info("Session closed successfully")
        except Exception as e:
            logger.warning(f"Error closing session: {e}")

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

def list_available_databases(session: Session):
    """List all available databases"""
    
    try:
        databases = session.sql("SHOW DATABASES").collect()
        print(f"\n📚 Available Databases ({len(databases)}):")
        for db in databases:
            print(f"  - {db['name']}")
    except Exception as e:
        logger.error(f"Error listing databases: {e}")

def list_tables_in_schema(session: Session, database: str, schema: str):
    """List all tables in a specific schema"""
    
    try:
        query = f"SHOW TABLES IN SCHEMA {database}.{schema}"
        tables = session.sql(query).collect()
        print(f"\n📋 Tables in {database}.{schema} ({len(tables)}):")
        for table in tables:
            print(f"  - {table['name']}")
    except Exception as e:
        logger.error(f"Error listing tables: {e}")

# ============================================================================
# COMMAND LINE INTERFACE
# ============================================================================

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Simple Snowpark Table Reader")
    parser.add_argument("--query", "-q", help="Execute a specific SQL query")
    parser.add_argument("--table", "-t", help="Read from a specific table")
    parser.add_argument("--limit", "-l", type=int, default=10, help="Limit number of rows (default: 10)")
    parser.add_argument("--list-databases", action="store_true", help="List available databases")
    parser.add_argument("--list-tables", help="List tables in specified schema (format: database.schema)")
    
    args = parser.parse_args()
    
    if args.query or args.table or args.list_databases or args.list_tables:
        # Command line mode
        config = SimpleSnowflakeConfig()
        
        try:
            session = create_snowpark_session(config)
            
            if args.list_databases:
                list_available_databases(session)
            
            elif args.list_tables:
                db_schema = args.list_tables.split('.')
                if len(db_schema) == 2:
                    list_tables_in_schema(session, db_schema[0], db_schema[1])
                else:
                    print("Error: Please specify schema as database.schema")
            
            elif args.query:
                df = read_table_with_sql(session, args.query, args.limit)
                display_dataframe(df, "Query Results")
            
            elif args.table:
                df = read_table_with_snowpark_df(session, args.table, args.limit)
                display_dataframe(df, f"Table: {args.table}")
            
            session.close()
            
        except Exception as e:
            print(f"Error: {e}")
    
    else:
        # Interactive mode
        main()
