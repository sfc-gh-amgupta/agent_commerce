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
    read -p "Enter Snowflake Account (e.g., abc12345.us-east-1 or ORGNAME-ACCOUNTNAME): " SNOWFLAKE_ACCOUNT
fi

# Prompt for Snowflake username
if [ -z "$SNOWFLAKE_USER" ]; then
    read -p "Enter Snowflake Username: " SNOWFLAKE_USER
fi

# Build registry URL (must be lowercase for Docker, underscores become hyphens)
REGISTRY=$(echo "${SNOWFLAKE_ACCOUNT}.registry.snowflakecomputing.com" | tr '[:upper:]' '[:lower:]' | tr '_' '-')

REPO_PATH="agent_commerce/util/agent_commerce_repo"
IMAGE_NAME="agent-commerce-backend"
FULL_IMAGE="${REGISTRY}/${REPO_PATH}/${IMAGE_NAME}:latest"

echo ""
echo "📦 Configuration:"
echo "   Registry: ${REGISTRY}"
echo "   Username: ${SNOWFLAKE_USER}"
echo "   Image: ${FULL_IMAGE}"
echo ""

# Step 1: Build
echo "1️⃣  Building Docker image..."
docker build --platform linux/amd64 -t ${IMAGE_NAME}:latest .
echo "   ✅ Build complete"
echo ""

# Step 2: Login
echo "2️⃣  Logging into Snowflake registry..."
read -s -p "   Enter your Snowflake password: " SNOWFLAKE_PASSWORD
echo ""

# Workaround for Docker Desktop credential helper issues on macOS
# Temporarily backup and modify docker config if credsStore is set
DOCKER_CONFIG_FILE="$HOME/.docker/config.json"
DOCKER_CONFIG_BACKUP="$HOME/.docker/config.json.bak"

if [ -f "$DOCKER_CONFIG_FILE" ] && grep -q "credsStore" "$DOCKER_CONFIG_FILE"; then
    echo "   ⚠️  Temporarily disabling Docker credential helper..."
    cp "$DOCKER_CONFIG_FILE" "$DOCKER_CONFIG_BACKUP"
    # Remove credsStore line temporarily
    sed -i.tmp 's/"credsStore".*,//' "$DOCKER_CONFIG_FILE"
    sed -i.tmp 's/"credsStore".*//' "$DOCKER_CONFIG_FILE"
    rm -f "${DOCKER_CONFIG_FILE}.tmp"
    RESTORE_CONFIG=true
else
    RESTORE_CONFIG=false
fi

# Login with password-stdin
echo "${SNOWFLAKE_PASSWORD}" | docker login ${REGISTRY} -u ${SNOWFLAKE_USER} --password-stdin
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
PUSH_EXIT_CODE=$?
echo ""

# Restore docker config if we modified it
if [ "$RESTORE_CONFIG" = true ] && [ -f "$DOCKER_CONFIG_BACKUP" ]; then
    echo "   Restoring Docker config..."
    mv "$DOCKER_CONFIG_BACKUP" "$DOCKER_CONFIG_FILE"
fi

if [ $PUSH_EXIT_CODE -ne 0 ]; then
    echo "   ❌ Push failed"
    exit 1
fi
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

