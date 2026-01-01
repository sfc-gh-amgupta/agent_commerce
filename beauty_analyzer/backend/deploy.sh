#!/bin/bash
# ============================================================================
# Agent Commerce - Full Stack Deploy Script
# ============================================================================
# Builds frontend + backend and pushes to Snowflake Container Registry
#
# Usage: ./deploy.sh
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRONTEND_DIR="${SCRIPT_DIR}/../frontend"
BACKEND_DIR="${SCRIPT_DIR}"

echo "=============================================="
echo "  Agent Commerce - Full Stack Deployment"
echo "=============================================="
echo ""

# =============================================================================
# Step 0: Build Frontend
# =============================================================================
echo "0️⃣  Building Frontend..."

if [ ! -d "$FRONTEND_DIR" ]; then
    echo "   ❌ Frontend directory not found: $FRONTEND_DIR"
    exit 1
fi

cd "$FRONTEND_DIR"

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "   Installing npm dependencies..."
    npm install
fi

# Build production bundle
echo "   Running npm build..."
npm run build

# Copy dist to backend/static
echo "   Copying build to backend/static..."
rm -rf "${BACKEND_DIR}/static"
cp -r dist "${BACKEND_DIR}/static"

echo "   ✅ Frontend build complete"
echo ""

# =============================================================================
# Step 1: Get Snowflake credentials
# =============================================================================
cd "$BACKEND_DIR"

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

# =============================================================================
# Step 2: Build Docker Image
# =============================================================================
echo "1️⃣  Building Docker image (this may take 5-10 minutes)..."
docker build --platform linux/amd64 -t ${IMAGE_NAME}:latest .
echo "   ✅ Build complete"
echo ""

# =============================================================================
# Step 3: Login to Snowflake Registry
# =============================================================================
echo "2️⃣  Logging into Snowflake registry..."
read -s -p "   Enter your Snowflake password: " SNOWFLAKE_PASSWORD
echo ""

# Workaround for Docker Desktop credential helper issues on macOS
DOCKER_CONFIG_FILE="$HOME/.docker/config.json"
DOCKER_CONFIG_BACKUP="$HOME/.docker/config.json.bak"

if [ -f "$DOCKER_CONFIG_FILE" ] && grep -q "credsStore" "$DOCKER_CONFIG_FILE"; then
    echo "   ⚠️  Temporarily disabling Docker credential helper..."
    cp "$DOCKER_CONFIG_FILE" "$DOCKER_CONFIG_BACKUP"
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

# =============================================================================
# Step 4: Tag and Push
# =============================================================================
echo "3️⃣  Tagging image..."
docker tag ${IMAGE_NAME}:latest ${FULL_IMAGE}
echo "   ✅ Tagged as ${FULL_IMAGE}"
echo ""

echo "4️⃣  Pushing to Snowflake (this may take a few minutes)..."
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

# =============================================================================
# Cleanup
# =============================================================================
echo "5️⃣  Cleaning up..."
rm -rf "${BACKEND_DIR}/static"
echo "   ✅ Cleanup complete"
echo ""

echo "=============================================="
echo "  ✅ Deployment Complete!"
echo "=============================================="
echo ""
echo "Your frontend + backend is now in Snowflake!"
echo ""
echo "Next: Run the SPCS service creation in Snowsight:"
echo ""
echo "  ALTER GIT REPOSITORY AGENT_COMMERCE.UTIL.AGENT_COMMERCE_GIT FETCH;"
echo "  EXECUTE IMMEDIATE FROM @AGENT_COMMERCE.UTIL.AGENT_COMMERCE_GIT/branches/main/beauty_analyzer/sql/00_deploy_from_github_complete.sql;"
echo ""
