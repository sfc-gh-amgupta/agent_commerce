-- ============================================================================
-- AGENT COMMERCE - Deploy SPCS Backend from Docker Hub
-- ============================================================================
-- The backend image is pre-built and hosted on Docker Hub (PUBLIC, no auth required):
--   amitgupta392/agent-commerce-backend:latest
--
-- SPCS REQUIREMENT: Images must be in Snowflake's internal registry.
-- This script guides you through pulling from Docker Hub and pushing to Snowflake.
--
-- PREREQUISITES:
--   1. Run 01_setup_database.sql first
--   2. Docker Desktop installed and running
--
-- ============================================================================

-- ============================================================================
-- STEP 1: PULL FROM DOCKER HUB AND PUSH TO SNOWFLAKE (Terminal)
-- ============================================================================
-- Run these commands in your terminal:
--
-- # Pull the pre-built image from Docker Hub (no auth required!)
-- docker pull amitgupta392/agent-commerce-backend:latest
--
-- # Get your Snowflake account info
-- # Format: <orgname>-<account_name> or <account_locator>.<region>
-- # Example: sfsenorthamerica-myaccount or abc12345.us-east-1
--
-- # Set your registry URL (replace with your account)
-- export REGISTRY="<your-account>.registry.snowflakecomputing.com"
--
-- # Login to Snowflake registry
-- docker login $REGISTRY
--
-- # Tag the image for Snowflake
-- docker tag amitgupta392/agent-commerce-backend:latest \
--   $REGISTRY/agent_commerce/util/agent_commerce_repo/agent-commerce-backend:latest
--
-- # Push to Snowflake
-- docker push $REGISTRY/agent_commerce/util/agent_commerce_repo/agent-commerce-backend:latest
--
-- ============================================================================

-- ============================================================================
-- STEP 2: VERIFY IMAGE IN SNOWFLAKE (Run in Snowsight)
-- ============================================================================

USE ROLE AGENT_COMMERCE_ROLE;
USE DATABASE AGENT_COMMERCE;
USE WAREHOUSE AGENT_COMMERCE_WH;
USE SCHEMA UTIL;

-- Verify image repository exists
SHOW IMAGE REPOSITORIES IN SCHEMA UTIL;

-- List images in repository (should see agent-commerce-backend)
SHOW IMAGES IN IMAGE REPOSITORY UTIL.AGENT_COMMERCE_REPO;

-- ============================================================================
-- STEP 3: CREATE SPCS SERVICE
-- ============================================================================

CREATE SERVICE IF NOT EXISTS UTIL.AGENT_COMMERCE_BACKEND
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
    COMMENT = 'Face recognition and skin analysis backend service';

-- ============================================================================
-- STEP 4: VERIFY SERVICE STATUS
-- ============================================================================

-- Check service status (wait for READY)
SELECT SYSTEM$GET_SERVICE_STATUS('UTIL.AGENT_COMMERCE_BACKEND');

-- Get service logs (useful for debugging)
SELECT SYSTEM$GET_SERVICE_LOGS('UTIL.AGENT_COMMERCE_BACKEND', 0, 'backend', 50);

-- Get public endpoint URL
SHOW ENDPOINTS IN SERVICE UTIL.AGENT_COMMERCE_BACKEND;

-- ============================================================================
-- TEST THE SERVICE
-- ============================================================================

-- Test health endpoint (after service is READY)
-- Replace <endpoint_url> with the URL from SHOW ENDPOINTS
-- curl https://<endpoint_url>/health

-- ============================================================================
-- SERVICE MANAGEMENT
-- ============================================================================

-- Suspend service (save costs when not in use)
-- ALTER SERVICE UTIL.AGENT_COMMERCE_BACKEND SUSPEND;

-- Resume service
-- ALTER SERVICE UTIL.AGENT_COMMERCE_BACKEND RESUME;

-- Drop service
-- DROP SERVICE IF EXISTS UTIL.AGENT_COMMERCE_BACKEND;

-- ============================================================================
-- QUICK REFERENCE: Docker Hub Image Details
-- ============================================================================
-- 
-- Image: amitgupta392/agent-commerce-backend:latest (PUBLIC)
-- Size: ~2GB (includes dlib, MediaPipe, OpenCV)
-- Endpoints:
--   - GET  /health           - Health check
--   - POST /extract-embedding - Extract face embedding from base64 image
--   - POST /analyze-skin     - Analyze skin tone from base64 image
--
-- ============================================================================
