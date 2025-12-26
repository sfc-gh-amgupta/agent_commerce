#!/bin/bash
# ============================================================================
# Agent Commerce Backend - Simplified Deploy Script
# ============================================================================
# Usage: ./deploy.sh
# ============================================================================

set -e

echo "=============================================="
echo "  Agent Commerce - SPCS Deployment"
echo "=============================================="
echo ""

# Prompt for account if not set
if [ -z "$SNOWFLAKE_ACCOUNT" ]; then
    read -p "Enter Snowflake Account (e.g., abc12345.us-east-1): " SNOWFLAKE_ACCOUNT
fi

# Prompt for org if not set
if [ -z "$SNOWFLAKE_ORG" ]; then
    read -p "Enter Snowflake Org Name (or press Enter to skip): " SNOWFLAKE_ORG
fi

# Build registry URL
if [ -n "$SNOWFLAKE_ORG" ]; then
    REGISTRY="${SNOWFLAKE_ORG}-${SNOWFLAKE_ACCOUNT}.registry.snowflakecomputing.com"
else
    REGISTRY="${SNOWFLAKE_ACCOUNT}.registry.snowflakecomputing.com"
fi

REPO_PATH="agent_commerce/util/agent_commerce_repo"
IMAGE_NAME="agent-commerce-backend"
FULL_IMAGE="${REGISTRY}/${REPO_PATH}/${IMAGE_NAME}:latest"

echo ""
echo "📦 Configuration:"
echo "   Registry: ${REGISTRY}"
echo "   Image: ${FULL_IMAGE}"
echo ""

# Step 1: Build
echo "1️⃣  Building Docker image..."
docker build --platform linux/amd64 -t ${IMAGE_NAME}:latest .
echo "   ✅ Build complete"
echo ""

# Step 2: Login
echo "2️⃣  Logging into Snowflake registry..."
echo "   (Enter your Snowflake username and password)"
docker login ${REGISTRY}
echo "   ✅ Login successful"
echo ""

# Step 3: Tag
echo "3️⃣  Tagging image..."
docker tag ${IMAGE_NAME}:latest ${FULL_IMAGE}
echo "   ✅ Tagged as ${FULL_IMAGE}"
echo ""

# Step 4: Push
echo "4️⃣  Pushing to Snowflake..."
docker push ${FULL_IMAGE}
echo "   ✅ Push complete"
echo ""

echo "=============================================="
echo "  ✅ Deployment Complete!"
echo "=============================================="
echo ""
echo "Next steps in Snowflake Worksheet:"
echo ""
echo "  -- Verify image"
echo "  SHOW IMAGES IN IMAGE REPOSITORY AGENT_COMMERCE.UTIL.AGENT_COMMERCE_REPO;"
echo ""
echo "  -- Create service"
echo "  Run: sql/07_deploy_spcs_backend.sql"
echo ""

