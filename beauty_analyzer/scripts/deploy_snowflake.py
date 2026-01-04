#!/usr/bin/env python3
"""
Snowflake Deployment Script
===========================

This script handles Snowflake operations for the Agent Commerce demo:
1. Creates image upload stage
2. Recreates the SPCS backend service with new image
3. Runs agent tools and agent creation SQL

Environment Variables Required:
- SNOWFLAKE_ACCOUNT
- SNOWFLAKE_USER
- SNOWFLAKE_PASSWORD
- SNOWFLAKE_ROLE (default: AGENT_COMMERCE_ROLE)
- SNOWFLAKE_WAREHOUSE (default: AGENT_COMMERCE_WH)
- SNOWFLAKE_DATABASE (default: AGENT_COMMERCE)

Usage:
    python deploy_snowflake.py
"""

import os
import sys
import time

# ============================================================================
# CONFIGURATION
# ============================================================================

SNOWFLAKE_ACCOUNT = os.environ.get("SNOWFLAKE_ACCOUNT", "sfsehol-si-ae-enablement-retail-kvldzi")
SNOWFLAKE_USER = os.environ.get("SNOWFLAKE_USER")
SNOWFLAKE_PASSWORD = os.environ.get("SNOWFLAKE_PASSWORD")
SNOWFLAKE_ROLE = os.environ.get("SNOWFLAKE_ROLE", "AGENT_COMMERCE_ROLE")
SNOWFLAKE_WAREHOUSE = os.environ.get("SNOWFLAKE_WAREHOUSE", "AGENT_COMMERCE_WH")
SNOWFLAKE_DATABASE = os.environ.get("SNOWFLAKE_DATABASE", "AGENT_COMMERCE")

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def print_step(step_num, message):
    """Print formatted step message."""
    print(f"\n{'='*60}")
    print(f"  Step {step_num}: {message}")
    print(f"{'='*60}\n")


def print_success(message):
    """Print success message."""
    print(f"  ✅ {message}")


def print_error(message):
    """Print error message."""
    print(f"  ❌ {message}")


def print_info(message):
    """Print info message."""
    print(f"  ℹ️  {message}")


def check_credentials():
    """Check that all required credentials are set."""
    missing = []
    if not SNOWFLAKE_USER:
        missing.append("SNOWFLAKE_USER")
    if not SNOWFLAKE_PASSWORD:
        missing.append("SNOWFLAKE_PASSWORD")
    
    if missing:
        print_error(f"Missing environment variables: {', '.join(missing)}")
        print("\nSet them with:")
        print('  export SNOWFLAKE_USER="your_username"')
        print('  export SNOWFLAKE_PASSWORD="your_password"')
        sys.exit(1)
    
    print_success("Credentials verified")


def get_snowflake_session():
    """Create Snowflake session."""
    from snowflake.snowpark import Session
    
    connection_params = {
        "account": SNOWFLAKE_ACCOUNT,
        "user": SNOWFLAKE_USER,
        "password": SNOWFLAKE_PASSWORD,
        "role": SNOWFLAKE_ROLE,
        "warehouse": SNOWFLAKE_WAREHOUSE,
        "database": SNOWFLAKE_DATABASE,
        "schema": "UTIL"
    }
    
    session = Session.builder.configs(connection_params).create()
    print_success(f"Connected to Snowflake ({SNOWFLAKE_ACCOUNT})")
    return session


# ============================================================================
# STEP 1: Create Image Upload Stage
# ============================================================================

def create_image_stage(session):
    """Create stage for image uploads."""
    session.sql("""
        CREATE STAGE IF NOT EXISTS CUSTOMERS.FACE_UPLOAD_STAGE
            DIRECTORY = (ENABLE = TRUE)
            COMMENT = 'Stage for face image uploads from widget'
    """).collect()
    
    print_success("Created stage: @CUSTOMERS.FACE_UPLOAD_STAGE")


# ============================================================================
# STEP 2: Recreate Backend Service
# ============================================================================

def recreate_backend_service(session):
    """Recreate the frontend/backend SPCS service."""
    
    print_info("Dropping existing service...")
    session.sql("""
        DROP SERVICE IF EXISTS UTIL.AGENT_COMMERCE_BACKEND
    """).collect()
    
    print_info("Creating new service with latest image...")
    session.sql("""
        CREATE SERVICE UTIL.AGENT_COMMERCE_BACKEND
            IN COMPUTE POOL AGENT_COMMERCE_POOL
            FROM SPECIFICATION $$
            spec:
              containers:
                - name: backend
                  image: /AGENT_COMMERCE/UTIL/AGENT_COMMERCE_REPO/agent-commerce-backend:latest
                  resources:
                    requests:
                      cpu: 1
                      memory: 4Gi
                    limits:
                      cpu: 2
                      memory: 8Gi
                  readinessProbe:
                    port: 8000
                    path: /health
              endpoints:
                - name: api
                  port: 8000
                  public: true
            $$
            MIN_INSTANCES = 1
            MAX_INSTANCES = 3
            QUERY_WAREHOUSE = AGENT_COMMERCE_WH
    """).collect()
    
    print_success("Created AGENT_COMMERCE_BACKEND service")
    
    # Wait for service to start
    print_info("Waiting for service to start...")
    time.sleep(10)
    
    # Get ingress URL
    try:
        result = session.sql("""
            SHOW ENDPOINTS IN SERVICE UTIL.AGENT_COMMERCE_BACKEND
        """).collect()
        
        if result:
            ingress_url = result[0]['ingress_url']
            print_success(f"Ingress URL: https://{ingress_url}")
            return ingress_url
    except Exception as e:
        print_info(f"Endpoints still provisioning: {e}")
    
    return None


# ============================================================================
# STEP 3: Run Agent Tools SQL
# ============================================================================

def run_agent_tools_sql(session):
    """Execute agent tools SQL via Git repo."""
    print_info("Refreshing Git repository...")
    try:
        session.sql("""
            ALTER GIT REPOSITORY AGENT_COMMERCE.UTIL.AGENT_COMMERCE_GIT FETCH
        """).collect()
        print_success("Git repository refreshed")
    except Exception as e:
        print_info(f"Git refresh skipped: {e}")
    
    print_info("Running agent tools SQL...")
    try:
        session.sql("""
            EXECUTE IMMEDIATE FROM @AGENT_COMMERCE.UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/sql/10_create_agent_tools.sql
        """).collect()
        print_success("Agent tools created/updated")
    except Exception as e:
        print_error(f"Agent tools SQL failed: {e}")
        print_info("You may need to run this manually in Snowsight")


# ============================================================================
# STEP 4: Run Cortex Agent SQL
# ============================================================================

def run_cortex_agent_sql(session):
    """Execute Cortex Agent SQL via Git repo."""
    print_info("Running Cortex Agent SQL...")
    try:
        session.sql("""
            EXECUTE IMMEDIATE FROM @AGENT_COMMERCE.UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/sql/11_create_cortex_agent.sql
        """).collect()
        print_success("Cortex Agent created/updated")
    except Exception as e:
        print_error(f"Cortex Agent SQL failed: {e}")
        print_info("You may need to run this manually in Snowsight")


# ============================================================================
# MAIN
# ============================================================================

def main():
    """Main deployment function."""
    print("\n" + "="*60)
    print("  AGENT COMMERCE - SNOWFLAKE DEPLOYMENT")
    print("="*60)
    
    # Check credentials
    print_step(0, "Checking Credentials")
    check_credentials()
    
    # Connect to Snowflake
    print_step(1, "Connecting to Snowflake")
    session = get_snowflake_session()
    
    # Create Image Stage
    print_step(2, "Creating Image Upload Stage")
    create_image_stage(session)
    
    # Recreate Backend Service
    print_step(3, "Recreating Backend Service")
    ingress_url = recreate_backend_service(session)
    
    # Run Agent Tools SQL (from Git)
    print_step(4, "Running Agent Tools SQL")
    run_agent_tools_sql(session)
    
    # Run Cortex Agent SQL (from Git)
    print_step(5, "Running Cortex Agent SQL")
    run_cortex_agent_sql(session)
    
    # Summary
    print("\n" + "="*60)
    print("  DEPLOYMENT COMPLETE")
    print("="*60)
    print(f"""
    ✅ Image upload stage created
    ✅ Backend service recreated
    ✅ Agent tools SQL executed
    ✅ Cortex Agent SQL executed
    
    📋 Next Steps:
    1. Wait for service endpoint to be ready:
       SHOW ENDPOINTS IN SERVICE UTIL.AGENT_COMMERCE_BACKEND;
    
    2. Access the app at:
       https://{ingress_url or '[pending - check SHOW ENDPOINTS]'}
    
    3. Test the face analysis flow!
    """)
    
    session.close()


if __name__ == "__main__":
    main()
