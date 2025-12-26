#!/bin/bash
# ============================================================================
# Agent Commerce - Pull from Docker Hub and Push to Snowflake
# ============================================================================
# This script pulls the pre-built image from Docker Hub (no auth required)
# and pushes it to your Snowflake image repository.
#
# PREREQUISITES:
#   - Docker Desktop installed and running
#   - Snowflake account with AGENT_COMMERCE database created
#     (run 01_setup_database.sql first)
#
# USAGE:
#   ./pull_and_push.sh
#
# ============================================================================

set -e

echo ""
echo "=============================================="
echo "  Agent Commerce - Image Deployment"
echo "=============================================="
echo ""

# Docker Hub image (public, no auth required)
DOCKERHUB_IMAGE="amitgupta392/agent-commerce-backend:latest"

# ============================================================================
# STEP 1: Collect Snowflake Account Info
# ============================================================================

echo "📝 Enter your Snowflake account details:"
echo ""

read -p "Snowflake Account Locator (e.g., abc12345): " ACCOUNT_LOCATOR
read -p "Snowflake Region (e.g., us-east-1, or press Enter if included in locator): " REGION

# Build registry URL
if [ -n "$REGION" ]; then
    REGISTRY="${ACCOUNT_LOCATOR}.${REGION}.snowflakecomputing.com"
else
    REGISTRY="${ACCOUNT_LOCATOR}.snowflakecomputing.com"
fi

SNOWFLAKE_IMAGE="${REGISTRY}/agent_commerce/util/agent_commerce_repo/agent-commerce-backend:latest"

echo ""
echo "📦 Configuration:"
echo "   Source: ${DOCKERHUB_IMAGE}"
echo "   Target: ${SNOWFLAKE_IMAGE}"
echo ""

# ============================================================================
# STEP 2: Pull from Docker Hub (No Auth Required)
# ============================================================================

echo "1️⃣  Pulling image from Docker Hub..."
echo "   (This may take a few minutes - image is ~2GB)"
docker pull --platform linux/amd64 ${DOCKERHUB_IMAGE}
echo "   ✅ Pull complete"
echo ""

# ============================================================================
# STEP 3: Login to Snowflake Registry
# ============================================================================

echo "2️⃣  Logging into Snowflake registry..."
echo "   (Enter your Snowflake username and password)"
echo ""
docker login ${REGISTRY}
echo "   ✅ Login successful"
echo ""

# ============================================================================
# STEP 4: Tag for Snowflake
# ============================================================================

echo "3️⃣  Tagging image for Snowflake..."
docker tag ${DOCKERHUB_IMAGE} ${SNOWFLAKE_IMAGE}
echo "   ✅ Tagged as ${SNOWFLAKE_IMAGE}"
echo ""

# ============================================================================
# STEP 5: Push to Snowflake
# ============================================================================

echo "4️⃣  Pushing to Snowflake..."
echo "   (This may take a few minutes)"
docker push ${SNOWFLAKE_IMAGE}
echo "   ✅ Push complete"
echo ""

# ============================================================================
# Done!
# ============================================================================

echo "=============================================="
echo "  ✅ Image Deployment Complete!"
echo "=============================================="
echo ""
echo "Next steps in Snowflake Worksheet:"
echo ""
echo "  -- Verify image was uploaded"
echo "  SHOW IMAGES IN IMAGE REPOSITORY AGENT_COMMERCE.UTIL.AGENT_COMMERCE_REPO;"
echo ""
echo "  -- Create the SPCS service"
echo "  -- Run: sql/07a_deploy_from_dockerhub.sql (STEP 3 onwards)"
echo ""
echo "=============================================="

