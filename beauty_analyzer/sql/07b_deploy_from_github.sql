-- ============================================================================
-- AGENT COMMERCE - Deploy SPCS Backend from GitHub Repository
-- ============================================================================
-- This script builds and deploys the backend directly from GitHub source code.
-- NO local Docker required - NO GitHub Actions required - everything in Snowsight!
--
-- PREREQUISITES:
--   1. Run 01_setup_database.sql first (creates database, schemas, compute pool)
--   2. Run 00_deploy_from_github_complete.sql PART 2 (creates Git integration)
--
-- HOW IT WORKS:
--   Snowflake clones the Git repo and builds the Docker image internally.
--   Build time: ~5-10 minutes (dlib compilation)
--
-- SOURCE:
--   https://github.com/sfc-gh-amgupta/agent_commerce
--   Path: beauty_analyzer/backend/
--
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE AGENT_COMMERCE;
USE WAREHOUSE AGENT_COMMERCE_WH;
USE SCHEMA UTIL;

-- ============================================================================
-- STEP 1: CREATE GIT INTEGRATION (if not already created)
-- ============================================================================

-- Create API integration for GitHub
CREATE OR REPLACE API INTEGRATION github_api_integration
    API_PROVIDER = GIT_HTTPS_API
    API_ALLOWED_PREFIXES = ('https://github.com/sfc-gh-amgupta/')
    ENABLED = TRUE
    COMMENT = 'Integration for Agent Commerce GitHub repository';

-- Create Git repository connection
CREATE OR REPLACE GIT REPOSITORY UTIL.AGENT_COMMERCE_GIT
    API_INTEGRATION = github_api_integration
    ORIGIN = 'https://github.com/sfc-gh-amgupta/agent_commerce.git'
    COMMENT = 'Agent Commerce source code and data';

-- Fetch latest from repository
ALTER GIT REPOSITORY UTIL.AGENT_COMMERCE_GIT FETCH;

-- Verify connection - should show Dockerfile and app/ folder
LIST @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/backend/;

-- ============================================================================
-- STEP 2: VERIFY IMAGE REPOSITORY EXISTS
-- ============================================================================

USE ROLE AGENT_COMMERCE_ROLE;

CREATE IMAGE REPOSITORY IF NOT EXISTS AGENT_COMMERCE_REPO
    COMMENT = 'Container images for Agent Commerce';

SHOW IMAGE REPOSITORIES IN SCHEMA UTIL;

-- ============================================================================
-- STEP 3: BUILD IMAGE DIRECTLY FROM GIT REPOSITORY
-- ============================================================================
-- No GitHub Actions needed! Snowflake builds the image from source.
-- Build time: ~5-10 minutes (dlib compilation)

-- First, create Git repository connection (if not already created)
-- Note: Requires github_api_integration from 00_deploy_from_github_complete.sql

-- Build image directly from Git repository
ALTER IMAGE REPOSITORY UTIL.AGENT_COMMERCE_REPO 
    BUILD 
    IMAGE 'agent-commerce-backend'
    TAG 'latest'
    FROM @UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/backend/
    DOCKERFILE_PATH = 'Dockerfile';

-- Monitor build progress (run periodically):
-- SELECT SYSTEM$GET_BUILD_STATUS('/AGENT_COMMERCE/UTIL/AGENT_COMMERCE_REPO/agent-commerce-backend:latest');

-- ============================================================================
-- STEP 4: VERIFY IMAGE WAS BUILT
-- ============================================================================

SHOW IMAGES IN IMAGE REPOSITORY UTIL.AGENT_COMMERCE_REPO;

-- ============================================================================
-- STEP 5: CREATE SPCS SERVICE
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
-- STEP 6: VERIFY SERVICE STATUS
-- ============================================================================

-- Check service status
SELECT SYSTEM$GET_SERVICE_STATUS('UTIL.AGENT_COMMERCE_BACKEND');

-- Wait for service to be ready (may take 1-2 minutes)
-- Status should show "READY" 

-- Get service logs
SELECT SYSTEM$GET_SERVICE_LOGS('UTIL.AGENT_COMMERCE_BACKEND', 0, 'backend', 50);

-- Get public endpoint URL
SHOW ENDPOINTS IN SERVICE UTIL.AGENT_COMMERCE_BACKEND;

-- ============================================================================
-- TEST THE SERVICE
-- ============================================================================

-- Test health endpoint
SELECT SYSTEM$CALL_SPCS_SERVICE(
    '/AGENT_COMMERCE/UTIL/AGENT_COMMERCE_BACKEND',
    'api',
    'POST',
    '/health',
    NULL
) AS health_check;

-- ============================================================================
-- SERVICE MANAGEMENT COMMANDS
-- ============================================================================

-- Suspend service (save costs when not in use)
-- ALTER SERVICE UTIL.AGENT_COMMERCE_BACKEND SUSPEND;

-- Resume service
-- ALTER SERVICE UTIL.AGENT_COMMERCE_BACKEND RESUME;

-- Update to new image version (after GitHub Actions pushes new version)
-- ALTER SERVICE UTIL.AGENT_COMMERCE_BACKEND 
--     FROM SPECIFICATION $$
--     spec:
--       containers:
--         - name: backend
--           image: /AGENT_COMMERCE/UTIL/AGENT_COMMERCE_REPO/agent-commerce-backend:latest
--           ...
--     $$;

-- Drop service
-- DROP SERVICE IF EXISTS UTIL.AGENT_COMMERCE_BACKEND;

-- ============================================================================
-- SUMMARY
-- ============================================================================
-- 
-- This workflow enables Snowsight-only deployment:
--   1. Developer pushes code to GitHub
--   2. GitHub Actions automatically builds and pushes image to ghcr.io
--   3. User runs this SQL script in Snowsight
--   4. Snowflake pulls image from ghcr.io and starts service
--
-- No local Docker installation required for end users!
--
-- ============================================================================

