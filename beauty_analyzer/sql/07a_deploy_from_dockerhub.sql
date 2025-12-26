-- ============================================================================
-- AGENT COMMERCE - Deploy SPCS Backend from Docker Hub
-- ============================================================================
-- This script deploys the backend WITHOUT requiring local Docker.
-- The image is pre-built and hosted on Docker Hub.
--
-- REQUIREMENTS:
--   1. Run 01_setup_database.sql first (creates database, schemas, compute pool)
--   2. Network access to Docker Hub from your Snowflake account
--
-- ============================================================================

USE ROLE AGENT_COMMERCE_ROLE;
USE DATABASE AGENT_COMMERCE;
USE WAREHOUSE AGENT_COMMERCE_WH;
USE SCHEMA UTIL;

-- ============================================================================
-- STEP 1: VERIFY IMAGE REPOSITORY EXISTS
-- ============================================================================

SHOW IMAGE REPOSITORIES IN SCHEMA UTIL;

-- If not exists, create it:
CREATE IMAGE REPOSITORY IF NOT EXISTS AGENT_COMMERCE_REPO
    COMMENT = 'Container images for Agent Commerce';

-- ============================================================================
-- STEP 2: PULL IMAGE FROM DOCKER HUB
-- ============================================================================
-- NOTE: Replace 'agentcommerce/backend' with the actual Docker Hub image
-- This is a placeholder - the actual image would be published to Docker Hub

-- Option A: If using public Docker Hub image
-- CALL SYSTEM$REGISTRY_COPY_IMAGE(
--     'docker.io/agentcommerce/backend:latest',
--     '/AGENT_COMMERCE/UTIL/AGENT_COMMERCE_REPO/agent-commerce-backend:latest'
-- );

-- ============================================================================
-- ALTERNATIVE: BUILD FROM S3 STAGE
-- ============================================================================
-- If you have the Docker context in S3, you can build directly:

-- Step 1: Create storage integration (ACCOUNTADMIN required)
-- CREATE OR REPLACE STORAGE INTEGRATION agent_commerce_s3_int
--     TYPE = EXTERNAL_STAGE
--     STORAGE_PROVIDER = 'S3'
--     ENABLED = TRUE
--     STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<account>:role/<role>'
--     STORAGE_ALLOWED_LOCATIONS = ('s3://<bucket>/agent-commerce/');

-- Step 2: Create external stage
-- CREATE OR REPLACE STAGE UTIL.DOCKER_BUILD_STAGE
--     STORAGE_INTEGRATION = agent_commerce_s3_int
--     URL = 's3://<bucket>/agent-commerce/docker/';

-- Step 3: Build from stage
-- ALTER IMAGE REPOSITORY UTIL.AGENT_COMMERCE_REPO 
--     ADD IMAGE 'agent-commerce-backend:latest'
--     FROM STAGE @UTIL.DOCKER_BUILD_STAGE;

-- ============================================================================
-- STEP 3: VERIFY IMAGE
-- ============================================================================

-- List images in repository
SHOW IMAGES IN IMAGE REPOSITORY UTIL.AGENT_COMMERCE_REPO;

-- ============================================================================
-- STEP 4: CREATE SPCS SERVICE
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
-- STEP 5: VERIFY SERVICE
-- ============================================================================

-- Check service status
SELECT SYSTEM$GET_SERVICE_STATUS('UTIL.AGENT_COMMERCE_BACKEND');

-- Get service logs
SELECT SYSTEM$GET_SERVICE_LOGS('UTIL.AGENT_COMMERCE_BACKEND', 0, 'backend', 50);

-- Get public endpoint
SHOW ENDPOINTS IN SERVICE UTIL.AGENT_COMMERCE_BACKEND;

-- ============================================================================
-- SERVICE MANAGEMENT
-- ============================================================================

-- Suspend service (save costs)
-- ALTER SERVICE UTIL.AGENT_COMMERCE_BACKEND SUSPEND;

-- Resume service
-- ALTER SERVICE UTIL.AGENT_COMMERCE_BACKEND RESUME;

-- Drop service
-- DROP SERVICE IF EXISTS UTIL.AGENT_COMMERCE_BACKEND;

