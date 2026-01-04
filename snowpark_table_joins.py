"""
================================================================================
SNOWPARK PYTHON: TABLE JOINS AND DATA OPERATIONS
================================================================================
This script demonstrates how to read data from multiple Snowflake tables and
perform various types of joins using Snowpark for Python.

Features:
- Reading data from multiple Snowflake tables
- Inner, Left, Right, and Full Outer joins
- Complex multi-table joins
- Join optimization techniques
- Data validation and quality checks
- Performance monitoring

Author: Snowflake Solutions Engineering
Last Updated: January 2025
================================================================================
"""

import os
import pandas as pd
from snowflake.snowpark import Session
from snowflake.snowpark.functions import (
    col, lit, sum as spark_sum, count, avg, max as spark_max, min as spark_min,
    when, coalesce, isnull, isnotnull, upper, lower, trim, concat,
    current_timestamp, datediff, to_date, year, month, dayofmonth
)
from snowflake.snowpark.types import (
    StructType, StructField, StringType, IntegerType, DoubleType, 
    DateType, TimestampType, BooleanType
)
import time
from datetime import datetime

# ============================================================================
# SESSION SETUP AND CONNECTION
# ============================================================================

def create_snowflake_session():
    """
    Create Snowflake session with connection parameters
    """
    
    # Connection parameters - use environment variables or secrets in production
    connection_parameters = {
        "account": os.getenv("SNOWFLAKE_ACCOUNT", "your_account_identifier"),
        "user": os.getenv("SNOWFLAKE_USER", "your_username"),
        "password": os.getenv("SNOWFLAKE_PASSWORD", "your_password"),
        "role": os.getenv("SNOWFLAKE_ROLE", "your_role"),
        "warehouse": os.getenv("SNOWFLAKE_WAREHOUSE", "your_warehouse"),
        "database": os.getenv("SNOWFLAKE_DATABASE", "your_database"),
        "schema": os.getenv("SNOWFLAKE_SCHEMA", "your_schema")
    }
    
    try:
        session = Session.builder.configs(connection_parameters).create()
        print("✅ Successfully connected to Snowflake")
        print(f"Current database: {session.get_current_database()}")
        print(f"Current schema: {session.get_current_schema()}")
        return session
    except Exception as e:
        print(f"❌ Failed to connect to Snowflake: {e}")
        return None

# ============================================================================
# SAMPLE DATA CREATION (FOR DEMONSTRATION)
# ============================================================================

def create_sample_tables(session):
    """
    Create sample tables for demonstration purposes
    """
    
    print("=== Creating Sample Tables ===")
    
    try:
        # Create Customers table
        customers_data = [
            (1, "Alice Johnson", "alice@email.com", "New York", "2020-01-15", "Premium"),
            (2, "Bob Smith", "bob@email.com", "California", "2019-03-20", "Standard"),
            (3, "Charlie Brown", "charlie@email.com", "Texas", "2021-06-10", "Premium"),
            (4, "Diana Prince", "diana@email.com", "Florida", "2018-11-05", "Standard"),
            (5, "Eve Wilson", "eve@email.com", "Washington", "2022-02-28", "Premium"),
            (6, "Frank Miller", "frank@email.com", "Oregon", "2020-08-12", "Standard")
        ]
        
        customers_schema = StructType([
            StructField("customer_id", IntegerType()),
            StructField("customer_name", StringType()),
            StructField("email", StringType()),
            StructField("state", StringType()),
            StructField("registration_date", StringType()),
            StructField("tier", StringType())
        ])
        
        customers_df = session.create_dataframe(customers_data, customers_schema)
        customers_df.write.mode("overwrite").save_as_table("CUSTOMERS")
        print("✅ Created CUSTOMERS table")
        
        # Create Orders table
        orders_data = [
            (101, 1, "2023-01-15", 250.00, "Completed"),
            (102, 2, "2023-01-16", 175.50, "Completed"),
            (103, 1, "2023-02-01", 320.75, "Completed"),
            (104, 3, "2023-02-05", 89.99, "Pending"),
            (105, 4, "2023-02-10", 445.20, "Completed"),
            (106, 2, "2023-02-15", 199.99, "Cancelled"),
            (107, 5, "2023-03-01", 567.80, "Completed"),
            (108, 1, "2023-03-05", 123.45, "Pending"),
            (109, 6, "2023-03-10", 299.99, "Completed"),
            (110, 7, "2023-03-15", 89.50, "Completed")  # Customer 7 doesn't exist in customers
        ]
        
        orders_schema = StructType([
            StructField("order_id", IntegerType()),
            StructField("customer_id", IntegerType()),
            StructField("order_date", StringType()),
            StructField("order_amount", DoubleType()),
            StructField("status", StringType())
        ])
        
        orders_df = session.create_dataframe(orders_data, orders_schema)
        orders_df.write.mode("overwrite").save_as_table("ORDERS")
        print("✅ Created ORDERS table")
        
        # Create Products table
        products_data = [
            (201, "Laptop Pro", "Electronics", 1299.99, "Active"),
            (202, "Wireless Mouse", "Electronics", 29.99, "Active"),
            (203, "Office Chair", "Furniture", 199.99, "Active"),
            (204, "Desk Lamp", "Furniture", 45.50, "Discontinued"),
            (205, "Keyboard", "Electronics", 79.99, "Active"),
            (206, "Monitor Stand", "Furniture", 89.99, "Active")
        ]
        
        products_schema = StructType([
            StructField("product_id", IntegerType()),
            StructField("product_name", StringType()),
            StructField("category", StringType()),
            StructField("price", DoubleType()),
            StructField("status", StringType())
        ])
        
        products_df = session.create_dataframe(products_data, products_schema)
        products_df.write.mode("overwrite").save_as_table("PRODUCTS")
        print("✅ Created PRODUCTS table")
        
        # Create Order Items table
        order_items_data = [
            (101, 201, 1, 1299.99),
            (102, 202, 2, 29.99),
            (102, 205, 1, 79.99),
            (103, 203, 1, 199.99),
            (103, 204, 2, 45.50),
            (104, 202, 3, 29.99),
            (105, 201, 1, 1299.99),
            (105, 206, 2, 89.99),
            (107, 201, 1, 1299.99),
            (107, 203, 1, 199.99),
            (109, 205, 2, 79.99),
            (109, 206, 1, 89.99)
        ]
        
        order_items_schema = StructType([
            StructField("order_id", IntegerType()),
            StructField("product_id", IntegerType()),
            StructField("quantity", IntegerType()),
            StructField("unit_price", DoubleType())
        ])
        
        order_items_df = session.create_dataframe(order_items_data, order_items_schema)
        order_items_df.write.mode("overwrite").save_as_table("ORDER_ITEMS")
        print("✅ Created ORDER_ITEMS table")
        
        print("\n🎉 All sample tables created successfully!")
        
    except Exception as e:
        print(f"❌ Error creating sample tables: {e}")

# ============================================================================
# READ DATA FROM TABLES
# ============================================================================

def read_tables(session):
    """
    Read data from Snowflake tables and return DataFrames
    """
    
    print("=== Reading Data from Tables ===")
    
    try:
        # Read customers table
        customers_df = session.table("CUSTOMERS")
        print(f"📊 CUSTOMERS table: {customers_df.count()} rows")
        
        # Read orders table
        orders_df = session.table("ORDERS")
        print(f"📊 ORDERS table: {orders_df.count()} rows")
        
        # Read products table
        products_df = session.table("PRODUCTS")
        print(f"📊 PRODUCTS table: {products_df.count()} rows")
        
        # Read order items table
        order_items_df = session.table("ORDER_ITEMS")
        print(f"📊 ORDER_ITEMS table: {order_items_df.count()} rows")
        
        # Display sample data from each table
        print("\n--- Sample Data Preview ---")
        
        print("\nCUSTOMERS (first 3 rows):")
        customers_df.limit(3).show()
        
        print("\nORDERS (first 3 rows):")
        orders_df.limit(3).show()
        
        print("\nPRODUCTS (first 3 rows):")
        products_df.limit(3).show()
        
        print("\nORDER_ITEMS (first 3 rows):")
        order_items_df.limit(3).show()
        
        return customers_df, orders_df, products_df, order_items_df
        
    except Exception as e:
        print(f"❌ Error reading tables: {e}")
        return None, None, None, None

# ============================================================================
# BASIC JOIN OPERATIONS
# ============================================================================

def demonstrate_basic_joins(customers_df, orders_df):
    """
    Demonstrate basic join operations between customers and orders
    """
    
    print("\n=== BASIC JOIN OPERATIONS ===")
    
    try:
        # 1. INNER JOIN - Only customers who have orders
        print("\n1. INNER JOIN - Customers with Orders:")
        inner_join = customers_df.join(
            orders_df,
            customers_df.col("customer_id") == orders_df.col("customer_id"),
            "inner"
        ).select(
            customers_df.col("customer_id"),
            customers_df.col("customer_name"),
            customers_df.col("tier"),
            orders_df.col("order_id"),
            orders_df.col("order_date"),
            orders_df.col("order_amount"),
            orders_df.col("status")
        )
        
        print(f"Result: {inner_join.count()} rows")
        inner_join.limit(5).show()
        
        # 2. LEFT JOIN - All customers, with their orders if any
        print("\n2. LEFT JOIN - All Customers with Optional Orders:")
        left_join = customers_df.join(
            orders_df,
            customers_df.col("customer_id") == orders_df.col("customer_id"),
            "left"
        ).select(
            customers_df.col("customer_id"),
            customers_df.col("customer_name"),
            customers_df.col("tier"),
            orders_df.col("order_id"),
            orders_df.col("order_amount"),
            orders_df.col("status")
        )
        
        print(f"Result: {left_join.count()} rows")
        left_join.limit(8).show()
        
        # 3. RIGHT JOIN - All orders, with customer info if available
        print("\n3. RIGHT JOIN - All Orders with Optional Customer Info:")
        right_join = customers_df.join(
            orders_df,
            customers_df.col("customer_id") == orders_df.col("customer_id"),
            "right"
        ).select(
            orders_df.col("order_id"),
            orders_df.col("customer_id").alias("order_customer_id"),
            customers_df.col("customer_name"),
            orders_df.col("order_amount"),
            orders_df.col("status")
        )
        
        print(f"Result: {right_join.count()} rows")
        right_join.show()
        
        # 4. FULL OUTER JOIN - All customers and all orders
        print("\n4. FULL OUTER JOIN - All Customers and All Orders:")
        full_join = customers_df.join(
            orders_df,
            customers_df.col("customer_id") == orders_df.col("customer_id"),
            "outer"
        ).select(
            coalesce(customers_df.col("customer_id"), orders_df.col("customer_id")).alias("customer_id"),
            customers_df.col("customer_name"),
            orders_df.col("order_id"),
            orders_df.col("order_amount")
        )
        
        print(f"Result: {full_join.count()} rows")
        full_join.show()
        
    except Exception as e:
        print(f"❌ Error in basic joins: {e}")

# ============================================================================
# COMPLEX MULTI-TABLE JOINS
# ============================================================================

def demonstrate_complex_joins(customers_df, orders_df, products_df, order_items_df):
    """
    Demonstrate complex multi-table joins
    """
    
    print("\n=== COMPLEX MULTI-TABLE JOINS ===")
    
    try:
        # 1. Three-table join: Customers -> Orders -> Order Items
        print("\n1. Customer Order Details (3-table join):")
        customer_order_details = customers_df.join(
            orders_df,
            customers_df.col("customer_id") == orders_df.col("customer_id"),
            "inner"
        ).join(
            order_items_df,
            orders_df.col("order_id") == order_items_df.col("order_id"),
            "inner"
        ).select(
            customers_df.col("customer_name"),
            customers_df.col("tier"),
            orders_df.col("order_id"),
            orders_df.col("order_date"),
            order_items_df.col("product_id"),
            order_items_df.col("quantity"),
            order_items_df.col("unit_price"),
            (order_items_df.col("quantity") * order_items_df.col("unit_price")).alias("line_total")
        )
        
        print(f"Result: {customer_order_details.count()} rows")
        customer_order_details.limit(8).show()
        
        # 2. Four-table join: Complete order information
        print("\n2. Complete Order Information (4-table join):")
        complete_orders = customers_df.join(
            orders_df,
            customers_df.col("customer_id") == orders_df.col("customer_id"),
            "inner"
        ).join(
            order_items_df,
            orders_df.col("order_id") == order_items_df.col("order_id"),
            "inner"
        ).join(
            products_df,
            order_items_df.col("product_id") == products_df.col("product_id"),
            "inner"
        ).select(
            customers_df.col("customer_name"),
            customers_df.col("state"),
            customers_df.col("tier"),
            orders_df.col("order_id"),
            orders_df.col("order_date"),
            orders_df.col("status").alias("order_status"),
            products_df.col("product_name"),
            products_df.col("category"),
            order_items_df.col("quantity"),
            order_items_df.col("unit_price"),
            (order_items_df.col("quantity") * order_items_df.col("unit_price")).alias("line_total")
        )
        
        print(f"Result: {complete_orders.count()} rows")
        complete_orders.limit(10).show()
        
        # 3. Aggregated join with grouping
        print("\n3. Customer Summary with Aggregations:")
        customer_summary = customers_df.join(
            orders_df,
            customers_df.col("customer_id") == orders_df.col("customer_id"),
            "left"
        ).join(
            order_items_df,
            orders_df.col("order_id") == order_items_df.col("order_id"),
            "left"
        ).group_by(
            customers_df.col("customer_id"),
            customers_df.col("customer_name"),
            customers_df.col("tier"),
            customers_df.col("state")
        ).agg(
            count(orders_df.col("order_id")).alias("total_orders"),
            coalesce(spark_sum(orders_df.col("order_amount")), lit(0)).alias("total_spent"),
            coalesce(spark_sum(order_items_df.col("quantity")), lit(0)).alias("total_items"),
            coalesce(avg(orders_df.col("order_amount")), lit(0)).alias("avg_order_value")
        ).order_by(col("total_spent").desc())
        
        print(f"Result: {customer_summary.count()} rows")
        customer_summary.show()
        
        return complete_orders, customer_summary
        
    except Exception as e:
        print(f"❌ Error in complex joins: {e}")
        return None, None

# ============================================================================
# ADVANCED JOIN TECHNIQUES
# ============================================================================

def demonstrate_advanced_joins(customers_df, orders_df, products_df):
    """
    Demonstrate advanced join techniques and optimizations
    """
    
    print("\n=== ADVANCED JOIN TECHNIQUES ===")
    
    try:
        # 1. Self Join - Find customers from the same state
        print("\n1. Self Join - Customers from Same State:")
        same_state_customers = customers_df.alias("c1").join(
            customers_df.alias("c2"),
            (col("c1.state") == col("c2.state")) & (col("c1.customer_id") != col("c2.customer_id")),
            "inner"
        ).select(
            col("c1.customer_name").alias("customer_1"),
            col("c2.customer_name").alias("customer_2"),
            col("c1.state")
        ).distinct()
        
        print(f"Result: {same_state_customers.count()} rows")
        same_state_customers.show()
        
        # 2. Conditional Join with CASE statements
        print("\n2. Conditional Join with Customer Segmentation:")
        customer_segments = customers_df.join(
            orders_df,
            customers_df.col("customer_id") == orders_df.col("customer_id"),
            "left"
        ).group_by(
            customers_df.col("customer_id"),
            customers_df.col("customer_name"),
            customers_df.col("tier")
        ).agg(
            coalesce(spark_sum(orders_df.col("order_amount")), lit(0)).alias("total_spent"),
            count(orders_df.col("order_id")).alias("order_count")
        ).select(
            "*",
            when(col("total_spent") > 500, "High Value")
            .when(col("total_spent") > 200, "Medium Value")
            .otherwise("Low Value").alias("value_segment"),
            
            when(col("order_count") > 2, "Frequent")
            .when(col("order_count") > 0, "Occasional")
            .otherwise("New").alias("frequency_segment")
        )
        
        print(f"Result: {customer_segments.count()} rows")
        customer_segments.show()
        
        # 3. Anti-join - Find customers without orders
        print("\n3. Anti-Join - Customers Without Orders:")
        customers_without_orders = customers_df.join(
            orders_df,
            customers_df.col("customer_id") == orders_df.col("customer_id"),
            "left_anti"
        ).select(
            customers_df.col("customer_id"),
            customers_df.col("customer_name"),
            customers_df.col("tier"),
            customers_df.col("registration_date")
        )
        
        print(f"Result: {customers_without_orders.count()} rows")
        customers_without_orders.show()
        
        # 4. Semi-join - Customers who have placed orders
        print("\n4. Semi-Join - Customers Who Have Orders:")
        customers_with_orders = customers_df.join(
            orders_df,
            customers_df.col("customer_id") == orders_df.col("customer_id"),
            "left_semi"
        ).select(
            customers_df.col("customer_id"),
            customers_df.col("customer_name"),
            customers_df.col("tier")
        )
        
        print(f"Result: {customers_with_orders.count()} rows")
        customers_with_orders.show()
        
    except Exception as e:
        print(f"❌ Error in advanced joins: {e}")

# ============================================================================
# JOIN PERFORMANCE OPTIMIZATION
# ============================================================================

def demonstrate_join_optimization(session, customers_df, orders_df):
    """
    Demonstrate join performance optimization techniques
    """
    
    print("\n=== JOIN PERFORMANCE OPTIMIZATION ===")
    
    try:
        # 1. Broadcast join for small tables
        print("\n1. Broadcast Join Optimization:")
        
        # Force broadcast of smaller table (customers)
        start_time = time.time()
        
        broadcast_join = customers_df.join(
            orders_df,
            customers_df.col("customer_id") == orders_df.col("customer_id"),
            "inner"
        )
        
        result_count = broadcast_join.count()
        end_time = time.time()
        
        print(f"Broadcast join completed: {result_count} rows in {end_time - start_time:.2f} seconds")
        
        # 2. Filter before join to reduce data volume
        print("\n2. Filter Before Join:")
        
        start_time = time.time()
        
        # Filter customers to only Premium tier
        premium_customers = customers_df.filter(col("tier") == "Premium")
        
        # Filter orders to only completed orders
        completed_orders = orders_df.filter(col("status") == "Completed")
        
        # Join filtered datasets
        filtered_join = premium_customers.join(
            completed_orders,
            premium_customers.col("customer_id") == completed_orders.col("customer_id"),
            "inner"
        )
        
        result_count = filtered_join.count()
        end_time = time.time()
        
        print(f"Filtered join completed: {result_count} rows in {end_time - start_time:.2f} seconds")
        filtered_join.show()
        
        # 3. Column pruning - select only needed columns
        print("\n3. Column Pruning Optimization:")
        
        start_time = time.time()
        
        # Select only necessary columns before join
        customers_slim = customers_df.select("customer_id", "customer_name", "tier")
        orders_slim = orders_df.select("customer_id", "order_id", "order_amount", "status")
        
        pruned_join = customers_slim.join(
            orders_slim,
            customers_slim.col("customer_id") == orders_slim.col("customer_id"),
            "inner"
        )
        
        result_count = pruned_join.count()
        end_time = time.time()
        
        print(f"Pruned join completed: {result_count} rows in {end_time - start_time:.2f} seconds")
        
        # 4. Show execution plan
        print("\n4. Query Execution Plan:")
        print("Use session.sql().explain() to see execution plans:")
        
        explain_query = """
        SELECT c.customer_name, c.tier, o.order_id, o.order_amount
        FROM CUSTOMERS c
        INNER JOIN ORDERS o ON c.customer_id = o.customer_id
        WHERE c.tier = 'Premium' AND o.status = 'Completed'
        """
        
        session.sql(explain_query).explain()
        
    except Exception as e:
        print(f"❌ Error in join optimization: {e}")

# ============================================================================
# DATA QUALITY AND VALIDATION
# ============================================================================

def validate_join_results(complete_orders, customer_summary):
    """
    Validate join results and check data quality
    """
    
    print("\n=== DATA QUALITY VALIDATION ===")
    
    try:
        if complete_orders is not None:
            # 1. Check for null values in key columns
            print("\n1. Null Value Check:")
            null_customers = complete_orders.filter(isnull(col("customer_name"))).count()
            null_products = complete_orders.filter(isnull(col("product_name"))).count()
            
            print(f"Orders with null customer names: {null_customers}")
            print(f"Orders with null product names: {null_products}")
            
            # 2. Data consistency checks
            print("\n2. Data Consistency Check:")
            total_line_items = complete_orders.count()
            unique_orders = complete_orders.select("order_id").distinct().count()
            
            print(f"Total line items: {total_line_items}")
            print(f"Unique orders: {unique_orders}")
            print(f"Average items per order: {total_line_items / unique_orders:.2f}")
            
            # 3. Business logic validation
            print("\n3. Business Logic Validation:")
            negative_quantities = complete_orders.filter(col("quantity") <= 0).count()
            zero_prices = complete_orders.filter(col("unit_price") <= 0).count()
            
            print(f"Items with negative/zero quantities: {negative_quantities}")
            print(f"Items with zero/negative prices: {zero_prices}")
            
        if customer_summary is not None:
            # 4. Summary statistics validation
            print("\n4. Summary Statistics:")
            summary_stats = customer_summary.agg(
                spark_sum("total_orders").alias("total_orders_sum"),
                spark_sum("total_spent").alias("total_revenue"),
                avg("avg_order_value").alias("overall_avg_order"),
                spark_max("total_spent").alias("highest_spender"),
                spark_min("total_spent").alias("lowest_spender")
            ).collect()[0]
            
            print(f"Total orders across all customers: {summary_stats['TOTAL_ORDERS_SUM']}")
            print(f"Total revenue: ${summary_stats['TOTAL_REVENUE']:.2f}")
            print(f"Overall average order value: ${summary_stats['OVERALL_AVG_ORDER']:.2f}")
            print(f"Highest customer spend: ${summary_stats['HIGHEST_SPENDER']:.2f}")
            print(f"Lowest customer spend: ${summary_stats['LOWEST_SPENDER']:.2f}")
            
    except Exception as e:
        print(f"❌ Error in data validation: {e}")

# ============================================================================
# MAIN EXECUTION FUNCTION
# ============================================================================

def main():
    """
    Main function to execute all join demonstrations
    """
    
    print("🚀 Starting Snowpark Table Joins Demonstration")
    print("=" * 60)
    
    # Create Snowflake session
    session = create_snowflake_session()
    if session is None:
        print("❌ Cannot proceed without Snowflake connection")
        return
    
    try:
        # Create sample tables
        create_sample_tables(session)
        
        # Read data from tables
        customers_df, orders_df, products_df, order_items_df = read_tables(session)
        
        if all([customers_df, orders_df, products_df, order_items_df]):
            # Demonstrate basic joins
            demonstrate_basic_joins(customers_df, orders_df)
            
            # Demonstrate complex multi-table joins
            complete_orders, customer_summary = demonstrate_complex_joins(
                customers_df, orders_df, products_df, order_items_df
            )
            
            # Demonstrate advanced join techniques
            demonstrate_advanced_joins(customers_df, orders_df, products_df)
            
            # Demonstrate join optimization
            demonstrate_join_optimization(session, customers_df, orders_df)
            
            # Validate results
            validate_join_results(complete_orders, customer_summary)
            
            print("\n🎉 All join demonstrations completed successfully!")
            
        else:
            print("❌ Could not read all required tables")
            
    except Exception as e:
        print(f"❌ Error in main execution: {e}")
        
    finally:
        # Clean up session
        if session:
            session.close()
            print("\n✅ Snowflake session closed")

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

def export_results_to_pandas(snowpark_df, limit=1000):
    """
    Convert Snowpark DataFrame to Pandas for further analysis
    """
    
    try:
        pandas_df = snowpark_df.limit(limit).to_pandas()
        print(f"✅ Exported {len(pandas_df)} rows to Pandas DataFrame")
        return pandas_df
    except Exception as e:
        print(f"❌ Error exporting to Pandas: {e}")
        return None

def save_results_to_table(session, snowpark_df, table_name):
    """
    Save join results to a new Snowflake table
    """
    
    try:
        snowpark_df.write.mode("overwrite").save_as_table(table_name)
        print(f"✅ Results saved to table: {table_name}")
    except Exception as e:
        print(f"❌ Error saving to table {table_name}: {e}")

# ============================================================================
# BEST PRACTICES SUMMARY
# ============================================================================

def print_best_practices():
    """
    Print best practices for Snowpark joins
    """
    
    print("""
=== SNOWPARK JOIN BEST PRACTICES ===

🔧 PERFORMANCE OPTIMIZATION:
   • Filter data before joining to reduce volume
   • Use column pruning - select only needed columns
   • Consider broadcast joins for small tables
   • Use appropriate join types (inner vs outer)
   • Leverage Snowflake's automatic query optimization

📊 DATA QUALITY:
   • Always validate join results
   • Check for null values in key columns
   • Verify business logic constraints
   • Monitor data consistency across joins
   • Use data profiling to understand join cardinality

🛡️ BEST PRACTICES:
   • Use meaningful aliases for tables
   • Document complex join logic
   • Test joins with sample data first
   • Monitor query performance and costs
   • Use appropriate data types for join keys

💰 COST OPTIMIZATION:
   • Avoid unnecessary full table scans
   • Use clustering keys for large tables
   • Consider materialized views for repeated joins
   • Monitor warehouse usage during join operations
   • Use result caching when appropriate

🔍 DEBUGGING TIPS:
   • Use .explain() to understand execution plans
   • Check join cardinality with .count()
   • Validate join keys for data quality issues
   • Use .show() to inspect intermediate results
   • Monitor query history in Snowflake console
""")

# ============================================================================
# EXECUTION
# ============================================================================

if __name__ == "__main__":
    main()
    print_best_practices()


