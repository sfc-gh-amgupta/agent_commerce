"""
================================================================================
SQL TO SNOWPARK PYTHON CONVERSION
================================================================================
This script converts the provided SQL query into Snowpark Python code.
The query analyzes campaign metrics with date filtering, joins, and aggregations.

Original SQL Query:
- Uses CTEs for campaign data and campaign details
- Performs LEFT OUTER JOIN between campaigns and campaign details
- Aggregates data by month with various metrics
- Filters data for specific date range (2025-05-01 to 2025-06-30)
- Orders results by campaign month descending

Author: Snowflake Solutions Engineering
Last Updated: January 2025
================================================================================
"""

from snowflake.snowpark import Session
from snowflake.snowpark.functions import (
    col, lit, sum as spark_sum, count, avg, max as spark_max, min as spark_min,
    count_distinct, date_trunc, to_date, desc, asc
)
from snowflake.snowpark.types import StructType, StructField, StringType, IntegerType, DoubleType, DateType
import os

# ============================================================================
# SESSION SETUP
# ============================================================================

def create_snowpark_session():
    """
    Create Snowpark session - update with your connection parameters
    """
    connection_parameters = {
        "account": os.getenv("SNOWFLAKE_ACCOUNT", "your_account_identifier"),
        "user": os.getenv("SNOWFLAKE_USER", "your_username"),
        "password": os.getenv("SNOWFLAKE_PASSWORD", "your_password"),  # Or use private key
        "role": os.getenv("SNOWFLAKE_ROLE", "your_role"),
        "warehouse": os.getenv("SNOWFLAKE_WAREHOUSE", "your_warehouse"),
        "database": os.getenv("SNOWFLAKE_DATABASE", "your_database"),
        "schema": os.getenv("SNOWFLAKE_SCHEMA", "your_schema")
    }
    
    try:
        session = Session.builder.configs(connection_parameters).create()
        print("✅ Successfully connected to Snowflake")
        return session
    except Exception as e:
        print(f"❌ Failed to connect to Snowflake: {e}")
        return None

# ============================================================================
# SNOWPARK CONVERSION OF THE SQL QUERY
# ============================================================================

def convert_sql_to_snowpark(session: Session):
    """
    Convert the SQL query to Snowpark Python code
    
    Original SQL structure:
    1. CTE __campaigns: Select campaign data with date filtering
    2. CTE __campaign_details: Select campaign details
    3. CTE campaign_metrics: Join and aggregate data by month
    4. Final SELECT: Return aggregated results ordered by month
    """
    
    if not session:
        print("❌ No Snowpark session available")
        return None
    
    try:
        print("🔄 Converting SQL to Snowpark Python...")
        
        # ====================================================================
        # STEP 1: CREATE __campaigns CTE EQUIVALENT
        # ====================================================================
        print("\n1. Creating campaigns DataFrame (equivalent to __campaigns CTE)")
        
        campaigns_df = session.table("shared_iceberg_xregion_marketing.iceberg_data.marketing_campaign_fact") \
            .select(
                col("date").alias("campaign_date"),
                col("campaign_key"),
                col("spend").alias("campaign_spend"),
                col("impressions")
            )
        
        print("✅ Campaigns DataFrame created")
        print("Sample data from campaigns:")
        campaigns_df.limit(3).show()
        
        # ====================================================================
        # STEP 2: CREATE __campaign_details CTE EQUIVALENT
        # ====================================================================
        print("\n2. Creating campaign details DataFrame (equivalent to __campaign_details CTE)")
        
        campaign_details_df = session.table("shared_iceberg_xregion_marketing.iceberg_data.campaign_dim") \
            .select(
                col("campaign_key"),
                col("campaign_name")
            )
        
        print("✅ Campaign details DataFrame created")
        print("Sample data from campaign details:")
        campaign_details_df.limit(3).show()
        
        # ====================================================================
        # STEP 3: CREATE campaign_metrics CTE EQUIVALENT
        # ====================================================================
        print("\n3. Creating campaign metrics DataFrame (equivalent to campaign_metrics CTE)")
        
        # Join campaigns with campaign details (LEFT OUTER JOIN)
        joined_df = campaigns_df.join(
            campaign_details_df,
            campaigns_df.col("campaign_key") == campaign_details_df.col("campaign_key"),
            "left"
        )
        
        # Apply date filter (WHERE clause)
        filtered_df = joined_df.filter(
            (col("campaign_date") >= lit("2025-05-01")) & 
            (col("campaign_date") <= lit("2025-06-30"))
        )
        
        # Group by month and calculate aggregations
        campaign_metrics_df = filtered_df.group_by(
            date_trunc("MONTH", col("campaign_date")).alias("campaign_month")
        ).agg(
            spark_min(col("campaign_date")).alias("min_date"),
            spark_max(col("campaign_date")).alias("max_date"),
            count_distinct(campaign_details_df.col("campaign_name")).alias("num_campaigns"),
            spark_sum(col("impressions")).alias("total_impressions"),
            spark_sum(col("campaign_spend")).alias("total_spend"),
            spark_min(col("campaign_spend")).alias("min_spend"),
            spark_max(col("campaign_spend")).alias("max_spend"),
            avg(col("campaign_spend")).alias("avg_spend")
        )
        
        print("✅ Campaign metrics DataFrame created with aggregations")
        
        # ====================================================================
        # STEP 4: FINAL SELECT WITH ORDERING
        # ====================================================================
        print("\n4. Creating final result with ordering")
        
        # Final select with ordering (ORDER BY campaign_month DESC NULLS LAST)
        final_result_df = campaign_metrics_df.select(
            col("campaign_month"),
            col("min_date"),
            col("max_date"),
            col("num_campaigns"),
            col("total_impressions"),
            col("total_spend"),
            col("min_spend"),
            col("max_spend"),
            col("avg_spend")
        ).order_by(col("campaign_month").desc())
        
        print("✅ Final result DataFrame created with ordering")
        
        # ====================================================================
        # DISPLAY RESULTS
        # ====================================================================
        print("\n=== FINAL RESULTS ===")
        final_result_df.show()
        
        # Get row count
        result_count = final_result_df.count()
        print(f"\n📊 Total rows returned: {result_count}")
        
        return final_result_df
        
    except Exception as e:
        print(f"❌ Error in Snowpark conversion: {e}")
        return None

# ============================================================================
# ALTERNATIVE: MORE PYTHONIC APPROACH WITH METHOD CHAINING
# ============================================================================

def convert_sql_to_snowpark_chained(session: Session):
    """
    Alternative approach using method chaining for more concise code
    """
    
    if not session:
        print("❌ No Snowpark session available")
        return None
    
    try:
        print("\n🔄 Alternative approach: Method chaining...")
        
        # Create the entire query using method chaining
        result_df = session.table("shared_iceberg_xregion_marketing.iceberg_data.marketing_campaign_fact") \
            .select(
                col("date").alias("campaign_date"),
                col("campaign_key"),
                col("spend").alias("campaign_spend"),
                col("impressions")
            ) \
            .join(
                session.table("shared_iceberg_xregion_marketing.iceberg_data.campaign_dim")
                .select(col("campaign_key"), col("campaign_name")),
                "campaign_key",
                "left"
            ) \
            .filter(
                (col("campaign_date") >= lit("2025-05-01")) & 
                (col("campaign_date") <= lit("2025-06-30"))
            ) \
            .group_by(
                date_trunc("MONTH", col("campaign_date")).alias("campaign_month")
            ) \
            .agg(
                spark_min(col("campaign_date")).alias("min_date"),
                spark_max(col("campaign_date")).alias("max_date"),
                count_distinct(col("campaign_name")).alias("num_campaigns"),
                spark_sum(col("impressions")).alias("total_impressions"),
                spark_sum(col("campaign_spend")).alias("total_spend"),
                spark_min(col("campaign_spend")).alias("min_spend"),
                spark_max(col("campaign_spend")).alias("max_spend"),
                avg(col("campaign_spend")).alias("avg_spend")
            ) \
            .select(
                col("campaign_month"),
                col("min_date"),
                col("max_date"),
                col("num_campaigns"),
                col("total_impressions"),
                col("total_spend"),
                col("min_spend"),
                col("max_spend"),
                col("avg_spend")
            ) \
            .order_by(col("campaign_month").desc())
        
        print("✅ Chained query created successfully")
        print("\n=== CHAINED QUERY RESULTS ===")
        result_df.show()
        
        return result_df
        
    except Exception as e:
        print(f"❌ Error in chained conversion: {e}")
        return None

# ============================================================================
# FUNCTION-BASED APPROACH FOR REUSABILITY
# ============================================================================

def get_campaign_metrics(session: Session, start_date: str = "2025-05-01", end_date: str = "2025-06-30"):
    """
    Reusable function to get campaign metrics for any date range
    
    Args:
        session: Snowpark session
        start_date: Start date for filtering (YYYY-MM-DD format)
        end_date: End date for filtering (YYYY-MM-DD format)
    
    Returns:
        Snowpark DataFrame with campaign metrics
    """
    
    if not session:
        print("❌ No Snowpark session available")
        return None
    
    try:
        print(f"📊 Getting campaign metrics from {start_date} to {end_date}")
        
        # Build the query
        result_df = session.table("shared_iceberg_xregion_marketing.iceberg_data.marketing_campaign_fact") \
            .select(
                col("date").alias("campaign_date"),
                col("campaign_key"),
                col("spend").alias("campaign_spend"),
                col("impressions")
            ) \
            .join(
                session.table("shared_iceberg_xregion_marketing.iceberg_data.campaign_dim")
                .select(col("campaign_key"), col("campaign_name")),
                "campaign_key",
                "left"
            ) \
            .filter(
                (col("campaign_date") >= lit(start_date)) & 
                (col("campaign_date") <= lit(end_date))
            ) \
            .group_by(
                date_trunc("MONTH", col("campaign_date")).alias("campaign_month")
            ) \
            .agg(
                spark_min(col("campaign_date")).alias("min_date"),
                spark_max(col("campaign_date")).alias("max_date"),
                count_distinct(col("campaign_name")).alias("num_campaigns"),
                spark_sum(col("impressions")).alias("total_impressions"),
                spark_sum(col("campaign_spend")).alias("total_spend"),
                spark_min(col("campaign_spend")).alias("min_spend"),
                spark_max(col("campaign_spend")).alias("max_spend"),
                avg(col("campaign_spend")).alias("avg_spend")
            ) \
            .order_by(col("campaign_month").desc())
        
        return result_df
        
    except Exception as e:
        print(f"❌ Error getting campaign metrics: {e}")
        return None

# ============================================================================
# QUERY OPTIMIZATION TECHNIQUES
# ============================================================================

def optimized_campaign_metrics(session: Session):
    """
    Optimized version with performance considerations
    """
    
    if not session:
        print("❌ No Snowpark session available")
        return None
    
    try:
        print("⚡ Creating optimized version...")
        
        # 1. Filter early to reduce data volume
        campaigns_filtered = session.table("shared_iceberg_xregion_marketing.iceberg_data.marketing_campaign_fact") \
            .filter(
                (col("date") >= lit("2025-05-01")) & 
                (col("date") <= lit("2025-06-30"))
            ) \
            .select(
                col("date").alias("campaign_date"),
                col("campaign_key"),
                col("spend").alias("campaign_spend"),
                col("impressions")
            )
        
        # 2. Select only needed columns from dimension table
        campaign_details = session.table("shared_iceberg_xregion_marketing.iceberg_data.campaign_dim") \
            .select(col("campaign_key"), col("campaign_name"))
        
        # 3. Perform join and aggregation
        result_df = campaigns_filtered \
            .join(campaign_details, "campaign_key", "left") \
            .group_by(
                date_trunc("MONTH", col("campaign_date")).alias("campaign_month")
            ) \
            .agg(
                spark_min(col("campaign_date")).alias("min_date"),
                spark_max(col("campaign_date")).alias("max_date"),
                count_distinct(col("campaign_name")).alias("num_campaigns"),
                spark_sum(col("impressions")).alias("total_impressions"),
                spark_sum(col("campaign_spend")).alias("total_spend"),
                spark_min(col("campaign_spend")).alias("min_spend"),
                spark_max(col("campaign_spend")).alias("max_spend"),
                avg(col("campaign_spend")).alias("avg_spend")
            ) \
            .order_by(col("campaign_month").desc())
        
        print("✅ Optimized query created")
        return result_df
        
    except Exception as e:
        print(f"❌ Error in optimized query: {e}")
        return None

# ============================================================================
# MAIN EXECUTION FUNCTION
# ============================================================================

def main():
    """
    Main function to demonstrate SQL to Snowpark conversion
    """
    
    print("🚀 SQL to Snowpark Python Conversion Demo")
    print("=" * 60)
    
    # Create Snowpark session
    session = create_snowpark_session()
    if not session:
        print("❌ Cannot proceed without Snowflake connection")
        return
    
    try:
        print("\n" + "=" * 60)
        print("APPROACH 1: STEP-BY-STEP CONVERSION")
        print("=" * 60)
        
        # Step-by-step conversion
        result1 = convert_sql_to_snowpark(session)
        
        print("\n" + "=" * 60)
        print("APPROACH 2: METHOD CHAINING")
        print("=" * 60)
        
        # Method chaining approach
        result2 = convert_sql_to_snowpark_chained(session)
        
        print("\n" + "=" * 60)
        print("APPROACH 3: REUSABLE FUNCTION")
        print("=" * 60)
        
        # Reusable function approach
        result3 = get_campaign_metrics(session, "2025-05-01", "2025-06-30")
        if result3:
            print("Reusable function results:")
            result3.show()
        
        print("\n" + "=" * 60)
        print("APPROACH 4: OPTIMIZED VERSION")
        print("=" * 60)
        
        # Optimized version
        result4 = optimized_campaign_metrics(session)
        if result4:
            print("Optimized query results:")
            result4.show()
        
        # Export results to Pandas for further analysis (optional)
        if result1:
            print("\n📊 Exporting results to Pandas DataFrame...")
            pandas_df = result1.to_pandas()
            print(f"✅ Exported {len(pandas_df)} rows to Pandas")
            print("\nPandas DataFrame info:")
            print(pandas_df.info())
        
    except Exception as e:
        print(f"❌ Error in main execution: {e}")
        
    finally:
        # Clean up session
        if session:
            session.close()
            print("\n✅ Snowpark session closed")

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

def explain_query_plan(session: Session, dataframe):
    """
    Show the execution plan for the Snowpark DataFrame
    """
    
    if session and dataframe:
        try:
            print("\n=== QUERY EXECUTION PLAN ===")
            dataframe.explain()
        except Exception as e:
            print(f"❌ Error showing execution plan: {e}")

def save_results_to_table(session: Session, dataframe, table_name: str):
    """
    Save results to a Snowflake table
    """
    
    if session and dataframe:
        try:
            dataframe.write.mode("overwrite").save_as_table(table_name)
            print(f"✅ Results saved to table: {table_name}")
        except Exception as e:
            print(f"❌ Error saving to table: {e}")

# ============================================================================
# COMPARISON: SQL vs SNOWPARK
# ============================================================================

def print_sql_vs_snowpark_comparison():
    """
    Print a comparison between SQL and Snowpark approaches
    """
    
    print("""
=== SQL vs SNOWPARK COMPARISON ===

📊 ORIGINAL SQL:
   • Uses CTEs for intermediate results
   • Declarative syntax
   • Familiar to SQL developers
   • Static query structure

🐍 SNOWPARK PYTHON:
   • Uses DataFrames for intermediate results
   • Programmatic approach
   • Familiar to Python developers
   • Dynamic query building
   • Better integration with Python ecosystem
   • Type safety and IDE support

⚡ PERFORMANCE:
   • Both approaches generate similar execution plans
   • Snowpark provides lazy evaluation
   • Query pushdown optimization in both cases
   • Snowpark allows for dynamic optimization

🔧 MAINTAINABILITY:
   • Snowpark allows for better code reuse
   • Function-based approach for modularity
   • Better error handling in Python
   • Version control friendly

💡 WHEN TO USE EACH:
   • SQL: Simple, static queries; SQL-first teams
   • Snowpark: Complex logic; Python-first teams; Dynamic queries
""")

# ============================================================================
# EXECUTION
# ============================================================================

if __name__ == "__main__":
    main()
    print_sql_vs_snowpark_comparison()


