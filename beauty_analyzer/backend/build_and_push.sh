#!/bin/bash
# ============================================================================
# Agent Commerce Backend - Build and Push to Snowflake
# ============================================================================
# Usage: ./build_and_push.sh <snowflake_account> <registry_url>
#
# Example:
#   ./build_and_push.sh sfsenorthamerica-demo \
#     sfsenorthamerica-demo.registry.snowflakecomputing.com/agent_commerce/util/agent_commerce_repo
#
# ============================================================================

set -e

# Configuration
ACCOUNT=${1:-"your_account"}
REGISTRY_URL=${2:-"your_registry_url"}
IMAGE_NAME="agent-commerce-backend"
IMAGE_TAG="latest"

echo "=============================================="
echo "Agent Commerce Backend - Build and Push"
echo "=============================================="
echo "Account: $ACCOUNT"
echo "Registry: $REGISTRY_URL"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Navigate to backend directory
cd "$(dirname "$0")"

echo "1️⃣  Building Docker image..."
docker build --platform linux/amd64 -t ${IMAGE_NAME}:${IMAGE_TAG} .

echo ""
echo "2️⃣  Logging into Snowflake registry..."
echo "    (You will be prompted for your Snowflake credentials)"
docker login ${ACCOUNT}.registry.snowflakecomputing.com

echo ""
echo "3️⃣  Tagging image for Snowflake..."
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${REGISTRY_URL}/${IMAGE_NAME}:${IMAGE_TAG}

echo ""
echo "4️⃣  Pushing image to Snowflake..."
docker push ${REGISTRY_URL}/${IMAGE_NAME}:${IMAGE_TAG}

echo ""
echo "=============================================="
echo "✅ Build and push complete!"
echo "=============================================="
echo ""
echo "Next steps:"
echo "  1. Run 07_deploy_spcs_backend.sql in Snowflake to create the service"
echo "  2. Check service status: SELECT SYSTEM\$GET_SERVICE_STATUS('UTIL.AGENT_COMMERCE_BACKEND');"
echo "  3. Test the API: SELECT SYSTEM\$CALL_SPCS_SERVICE(...);"
echo ""

