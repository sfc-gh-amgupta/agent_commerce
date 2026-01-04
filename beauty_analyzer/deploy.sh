#!/bin/bash
# ============================================================================
# AGENT COMMERCE - ONE-STEP DEPLOYMENT
# ============================================================================
#
# This script deploys the entire Agent Commerce demo:
#   1. Builds React frontend
#   2. Builds Docker image for SPCS backend
#   3. Pushes to Snowflake Container Registry
#   4. Runs Snowflake deployment (model, stage, agent, services)
#
# Prerequisites:
#   - Node.js and npm installed
#   - Docker installed and running
#   - Python 3.10+ with snowflake-ml-python installed
#   - Environment variables set (see below)
#
# Environment Variables Required:
#   SNOWFLAKE_ACCOUNT   - Your Snowflake account (e.g., xy12345.us-east-1)
#   SNOWFLAKE_USER      - Your Snowflake username
#   SNOWFLAKE_PASSWORD  - Your Snowflake password
#
# Optional (defaults provided):
#   SNOWFLAKE_ROLE      - Default: AGENT_COMMERCE_ROLE
#   SNOWFLAKE_WAREHOUSE - Default: AGENT_COMMERCE_WH
#   SNOWFLAKE_DATABASE  - Default: AGENT_COMMERCE
#
# Usage:
#   export SNOWFLAKE_USER="your_user"
#   export SNOWFLAKE_PASSWORD="your_password"
#   ./deploy.sh
#
# ============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND_DIR="${SCRIPT_DIR}/frontend"
BACKEND_DIR="${SCRIPT_DIR}/backend"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"

# Configuration
SNOWFLAKE_ACCOUNT="${SNOWFLAKE_ACCOUNT:-sfsehol-si-ae-enablement-retail-kvldzi}"
SNOWFLAKE_REGISTRY="${SNOWFLAKE_ACCOUNT}.registry.snowflakecomputing.com"
IMAGE_NAME="agent_commerce/util/agent_commerce_repo/agent-commerce-backend"
IMAGE_TAG="latest"

# ============================================================================
# Helper Functions
# ============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo ""
}

print_step() {
    echo -e "${YELLOW}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "  ℹ️  $1"
}

check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 is required but not installed."
        exit 1
    fi
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

print_header "AGENT COMMERCE - ONE-STEP DEPLOYMENT"

print_step "Checking prerequisites..."

# Check required commands
check_command node
check_command npm
check_command docker
check_command python3

# Check environment variables
if [ -z "$SNOWFLAKE_USER" ]; then
    print_error "SNOWFLAKE_USER environment variable is not set"
    echo "  Run: export SNOWFLAKE_USER='your_username'"
    exit 1
fi

if [ -z "$SNOWFLAKE_PASSWORD" ]; then
    print_error "SNOWFLAKE_PASSWORD environment variable is not set"
    echo "  Run: export SNOWFLAKE_PASSWORD='your_password'"
    exit 1
fi

# Check Docker is running
if ! docker info &> /dev/null; then
    print_error "Docker is not running. Please start Docker."
    exit 1
fi

print_success "All prerequisites met"
echo ""
echo "  Account:   $SNOWFLAKE_ACCOUNT"
echo "  User:      $SNOWFLAKE_USER"
echo "  Registry:  $SNOWFLAKE_REGISTRY"
echo ""

# ============================================================================
# Step 1: Build Frontend
# ============================================================================

print_header "Step 1/5: Building Frontend"

cd "$FRONTEND_DIR"

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    print_step "Installing npm dependencies..."
    npm install
fi

# Build production bundle
print_step "Building production bundle..."
npm run build

# Copy to backend static folder
print_step "Copying to backend/static..."
rm -rf "${BACKEND_DIR}/static"
cp -r dist "${BACKEND_DIR}/static"

print_success "Frontend built successfully"

# ============================================================================
# Step 2: Build Docker Image
# ============================================================================

print_header "Step 2/5: Building Docker Image"

cd "$BACKEND_DIR"

print_step "Building Docker image..."
docker build \
    --platform linux/amd64 \
    --build-arg BUILD_DATE=$(date +%Y%m%d%H%M%S) \
    -t "${IMAGE_NAME}:${IMAGE_TAG}" \
    -f Dockerfile \
    .

print_success "Docker image built: ${IMAGE_NAME}:${IMAGE_TAG}"

# ============================================================================
# Step 3: Push to Snowflake Registry
# ============================================================================

print_header "Step 3/5: Pushing to Snowflake Registry"

FULL_IMAGE_NAME="${SNOWFLAKE_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

# Login to registry
print_step "Logging into Snowflake Container Registry..."
echo "$SNOWFLAKE_PASSWORD" | docker login "$SNOWFLAKE_REGISTRY" \
    --username "$SNOWFLAKE_USER" \
    --password-stdin

# Tag image
print_step "Tagging image..."
docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "$FULL_IMAGE_NAME"

# Push image
print_step "Pushing image to registry..."
docker push "$FULL_IMAGE_NAME"

print_success "Image pushed: $FULL_IMAGE_NAME"

# ============================================================================
# Step 4: Cleanup Static Files
# ============================================================================

print_step "Cleaning up temporary files..."
rm -rf "${BACKEND_DIR}/static"
print_success "Cleanup complete"

# ============================================================================
# Step 5: Run Snowflake Deployment
# ============================================================================

print_header "Step 4/5: Running Snowflake Deployment"

cd "$SCRIPTS_DIR"

# Check for virtual environment with snowpark
print_step "Checking Python environment..."

VENV_PYTHON="${SCRIPT_DIR}/.venv/bin/python"

if [ -f "$VENV_PYTHON" ]; then
    print_info "Using virtual environment: ${SCRIPT_DIR}/.venv"
    PYTHON_CMD="$VENV_PYTHON"
elif python3 -c "import snowflake.snowpark" 2>/dev/null; then
    print_info "Using system Python with snowpark"
    PYTHON_CMD="python3"
else
    print_info "snowflake-snowpark-python not found."
    print_info "Skipping Snowflake deployment (stage, service, agent)."
    echo ""
    print_success "Docker image pushed successfully!"
    print_info "Run SQL manually in Snowsight to complete deployment:"
    echo ""
    echo "  -- Recreate service"
    echo "  DROP SERVICE IF EXISTS UTIL.AGENT_COMMERCE_BACKEND;"
    echo "  CREATE SERVICE UTIL.AGENT_COMMERCE_BACKEND ..."
    echo ""
    exit 0
fi

# Export environment variables for the Python script
export SNOWFLAKE_ACCOUNT
export SNOWFLAKE_USER
export SNOWFLAKE_PASSWORD
export SNOWFLAKE_ROLE="${SNOWFLAKE_ROLE:-AGENT_COMMERCE_ROLE}"
export SNOWFLAKE_WAREHOUSE="${SNOWFLAKE_WAREHOUSE:-AGENT_COMMERCE_WH}"
export SNOWFLAKE_DATABASE="${SNOWFLAKE_DATABASE:-AGENT_COMMERCE}"

# Run deployment script
print_step "Running Snowflake deployment..."
$PYTHON_CMD deploy_snowflake.py

# ============================================================================
# Complete
# ============================================================================

print_header "DEPLOYMENT COMPLETE! 🎉"

echo -e "${GREEN}"
echo "  ┌────────────────────────────────────────────────────────────┐"
echo "  │                    DEPLOYMENT SUMMARY                      │"
echo "  ├────────────────────────────────────────────────────────────┤"
echo "  │  ✅ Frontend built and bundled                             │"
echo "  │  ✅ Docker image built and pushed                          │"
echo "  │  ✅ Face Analysis Model deployed to SPCS                   │"
echo "  │  ✅ Cortex Agent updated                                   │"
echo "  │  ✅ Backend service recreated                              │"
echo "  └────────────────────────────────────────────────────────────┘"
echo -e "${NC}"

echo ""
echo "  📋 Next Steps:"
echo "  1. Check service status:"
echo "     SHOW SERVICES IN COMPUTE POOL AGENT_COMMERCE_POOL;"
echo ""
echo "  2. Get the widget URL:"
echo "     SHOW ENDPOINTS IN SERVICE UTIL.AGENT_COMMERCE_BACKEND;"
echo ""
echo "  3. Test the demo!"
echo ""

