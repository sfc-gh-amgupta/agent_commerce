"""
================================================================================
DATABRICKS NOTEBOOK: SNOWFLAKE INTEROPERABILITY DEMO
================================================================================
Purpose: Demonstrate Snowflake and Databricks data interoperability with cross-platform analytics
Description: This Databricks notebook showcases seamless integration between Databricks and Snowflake
             using Snowpark Python. It demonstrates private key authentication, cross-cloud data access,
             local/remote data joins, and Snowflake security policy enforcement within the Databricks
             environment.

Contents:
  1. Environment Setup - Install dependencies and import libraries
  2. Authentication - Configure private key authentication for Snowflake
  3. Cross-Cloud Data Access - Read Snowflake data products from Databricks
  4. Local Data Access - Read Databricks Unity Catalog tables
  5. Cross-Platform Joins - Combine data from both platforms
  6. Security Policy Demo - Snowflake projection policies enforced in Databricks

Author: Amit Gupta
Last Updated: October 18, 2025
Demo: Available at Interoperable Data Mesh Webinar - https://www.snowflake.com/en/webinars/demo/unlocking-ai-with-an-interoperable-data-mesh-2025-10-16/
 
================================================================================
"""


################################################################################
# SECTION 1: INSTALL DEPENDENCIES
################################################################################

# Install Snowpark Python library (specific version for compatibility)
!pip install snowflake-snowpark-python==1.39.0 


################################################################################
# SECTION 2: IMPORT REQUIRED LIBRARIES
################################################################################

# Snowflake Snowpark imports
from snowflake.snowpark.session import Session
from snowflake.snowpark import functions as F
from snowflake.snowpark.types import *

# PySpark imports for Databricks
from pyspark.sql import SparkSession

# Data manipulation libraries
import pandas as pd
import numpy as np
import os

# Cryptography libraries for private key authentication
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.asymmetric import dsa
from cryptography.hazmat.primitives import serialization


################################################################################
# SECTION 3: LOAD PRIVATE KEY FOR SNOWFLAKE AUTHENTICATION
# 
# This uses key-pair authentication instead of username/password for better
# security. The private key is stored in a Databricks Unity Catalog Volume.
################################################################################

# Read the private key file from Unity Catalog Volume
with open("/Volumes/amgupta_interop_dbrix_local_hr/default/privatekey/snowflake_private_key.pem", "rb") as key:
  p_key = serialization.load_pem_private_key(
    key.read(),
    password=None,  # No password protection on this key
    backend=default_backend()
  )

# Convert private key to DER format (binary) for Snowpark
pkb = p_key.private_bytes(
  encoding=serialization.Encoding.DER,
  format=serialization.PrivateFormat.PKCS8,
  encryption_algorithm=serialization.NoEncryption()
)


################################################################################
# SECTION 4: CONFIGURE SNOWFLAKE CONNECTION PARAMETERS
# 
# Using private key authentication with the HR_DOMAIN_ROLE which has access
# to multiple data products across regions and clouds.
################################################################################

connection_parameters = {
  "account": "SFSENORTHAMERICA-AMGUPTA_SNOW_AWS_USEAST",
  "user": "INTEROP_USER",
  "private_key": pkb,  # Binary private key for authentication
  "role": "HR_DOMAIN_ROLE",  # Role with access to shared data products
  "warehouse": "HR_WH"  # Compute warehouse for query execution
}


################################################################################
# SECTION 5: READ CROSS-CLOUD FINANCE DATA FROM SNOWFLAKE
# 
# This demonstrates accessing Snowflake data from a different cloud provider
# (cross-cloud sharing) while running in Databricks.
# 
# Data Source: Finance domain data product (cross-cloud, cross-region)
################################################################################

# Create Snowpark session
session = Session.builder.configs(connection_parameters).create()

# Query the finance transactions table
query = "Select * from shared_snow_xcloud_finance.snow_data.finance_transactions"
snowpark_snowflake_df = session.sql(query)

# Convert to Pandas DataFrame for display in Databricks
pandas_snowflake_df = snowpark_snowflake_df.to_pandas()
pandas_snowflake_df.display()


################################################################################
# SECTION 6: READ LOCAL DATABRICKS DATA
# 
# Access data stored locally in Databricks Unity Catalog to demonstrate
# joining local and remote data.
################################################################################

# Get Spark session
spark = SparkSession.builder.getOrCreate()

# Read local HR department dimension table from Databricks
databricks_df = spark.table("amgupta_interop_dbrix_local_hr.default.department_dim")

# Convert to Pandas for easier joining
pandas_databricks_df = databricks_df.toPandas()
pandas_databricks_df.display()


################################################################################
# SECTION 7: JOIN LOCAL DATABRICKS DATA WITH REMOTE SNOWFLAKE DATA
# 
# This demonstrates a key interoperability capability: combining data from
# both platforms in a single analysis. The join happens in Databricks memory
# on the Pandas DataFrames.
# 
# Join Key: DEPARTMENT_KEY (common field between HR and Finance data)
################################################################################

# Perform inner join on department key
joined_df = pd.merge(
  pandas_databricks_df, 
  pandas_snowflake_df, 
  on='DEPARTMENT_KEY', 
  how='inner'
)
joined_df.display()


################################################################################
# SECTION 8: DEMONSTRATE PROJECTION POLICY ENFORCEMENT - ERROR CASE
# 
# This demonstrates that Snowflake security policies (projection policies) are
# enforced even when data is accessed from Databricks.
# 
# Projection Policy: Restricts access to CUSTOMER_NAME column
# Expected Result: ERROR because SELECT * includes the restricted column
################################################################################

# Attempt to select all columns (including restricted CUSTOMER_NAME)
query = "Select * from shared_snow_xcloud_finance.snow_data.customer_dim"
snowpark_snowflake_df = session.sql(query)
pandas_snowflake_df = snowpark_snowflake_df.to_pandas()
pandas_snowflake_df.display()
# Expected: Error due to projection policy on CUSTOMER_NAME column


################################################################################
# SECTION 9: DEMONSTRATE PROJECTION POLICY ENFORCEMENT - SUCCESS CASE
# 
# By explicitly selecting only the allowed columns (excluding CUSTOMER_NAME),
# the query succeeds. This proves that Snowflake's column-level security
# works seamlessly across platforms.
################################################################################

# Select only allowed columns (excluding CUSTOMER_NAME)
query = "Select customer_key, vertical from shared_snow_xcloud_finance.snow_data.customer_dim"
snowpark_snowflake_df = session.sql(query)
pandas_snowflake_df = snowpark_snowflake_df.to_pandas()
pandas_snowflake_df.display()
# Success: Projection policy allows these specific columns


################################################################################
# KEY TAKEAWAYS
# 
# 1. Seamless Connectivity: Snowpark enables easy Snowflake access from Databricks
# 2. Cross-Platform Security: Snowflake policies enforced in Databricks environment
# 3. Unified Analytics: Join data across platforms without complex ETL
# 4. Secure Authentication: Private key auth provides enterprise-grade security
# 5. Data Governance: Column-level security (projection policies) maintained
#    across cloud boundaries
################################################################################

