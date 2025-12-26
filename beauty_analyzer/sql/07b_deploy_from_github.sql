-- ============================================================================
-- AGENT COMMERCE - Deploy SPCS Backend from GitHub Container Registry
-- ============================================================================
-- This script deploys the backend using an image hosted on GitHub (ghcr.io).
-- NO local Docker required - everything runs in Snowsight!
--
-- PREREQUISITES:
--   1. Run 01_setup_database.sql first
--   2. GitHub Actions has pushed image to ghcr.io (automatic on push to main)
--
-- IMAGE LOCATION:
--   ghcr.io/sfc-gh-amgupta/agent_commerce/agent-commerce-backend:latest
--
-- ============================================================================

USE ROLE ACCOUNTADMIN;  -- Required for external access integration
USE DATABASE AGENT_COMMERCE;
USE WAREHOUSE AGENT_COMMERCE_WH;
USE SCHEMA UTIL;

-- ============================================================================
-- STEP 1: CREATE EXTERNAL ACCESS INTEGRATION FOR GHCR.IO
-- ============================================================================
-- This allows Snowflake to pull images from GitHub Container Registry

-- Create network rule for GitHub Container Registry
CREATE OR REPLACE NETWORK RULE ghcr_network_rule
    TYPE = HOST_PORT
    VALUE_LIST = ('ghcr.io:443', 'pkg-containers.githubusercontent.com:443')
    MODE = EGRESS
    COMMENT = 'Allow access to GitHub Container Registry';

-- Create external access integration
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION ghcr_access_integration
    ALLOWED_NETWORK_RULES = (ghcr_network_rule)
    ENABLED = TRUE
    COMMENT = 'Integration for pulling images from GitHub Container Registry';

-- Grant usage to our role
GRANT USAGE ON INTEGRATION ghcr_access_integration TO ROLE AGENT_COMMERCE_ROLE;

-- ============================================================================
-- STEP 2: CREATE SECRET FOR PRIVATE GITHUB REPOS (Optional)
-- ============================================================================
-- If your GitHub repo is PRIVATE, you need a Personal Access Token (PAT)
-- Skip this if your repo/package is PUBLIC

-- CREATE OR REPLACE SECRET ghcr_credentials
--     TYPE = USERNAME_PASSWORD
--     USERNAME = 'sfc-gh-amgupta'
--     PASSWORD = 'ghp_xxxxxxxxxxxxxxxxxxxx'  -- GitHub PAT with packages:read
--     COMMENT = 'GitHub PAT for pulling container images';

-- ============================================================================
-- STEP 3: VERIFY IMAGE REPOSITORY EXISTS
-- ============================================================================

USE ROLE AGENT_COMMERCE_ROLE;

CREATE IMAGE REPOSITORY IF NOT EXISTS AGENT_COMMERCE_REPO
    COMMENT = 'Container images for Agent Commerce';

SHOW IMAGE REPOSITORIES IN SCHEMA UTIL;

-- ============================================================================
-- STEP 4: COPY IMAGE FROM GHCR.IO TO SNOWFLAKE
-- ============================================================================
-- This pulls the image from GitHub Container Registry into Snowflake's registry

-- For PUBLIC packages:
CALL SYSTEM$REGISTRY_COPY_IMAGE(
    'ghcr.io/sfc-gh-amgupta/agent_commerce/agent-commerce-backend:latest',
    '/AGENT_COMMERCE/UTIL/AGENT_COMMERCE_REPO/agent-commerce-backend:latest'
);

-- For PRIVATE packages (requires secret):
-- CALL SYSTEM$REGISTRY_COPY_IMAGE(
--     'ghcr.io/sfc-gh-amgupta/agent_commerce/agent-commerce-backend:latest',
--     '/AGENT_COMMERCE/UTIL/AGENT_COMMERCE_REPO/agent-commerce-backend:latest',
--     OBJECT_CONSTRUCT('secret', 'UTIL.ghcr_credentials')
-- );

-- ============================================================================
-- STEP 5: VERIFY IMAGE WAS COPIED
-- ============================================================================

SHOW IMAGES IN IMAGE REPOSITORY UTIL.AGENT_COMMERCE_REPO;

-- ============================================================================
-- STEP 6: CREATE SPCS SERVICE
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
-- STEP 7: VERIFY SERVICE STATUS
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

