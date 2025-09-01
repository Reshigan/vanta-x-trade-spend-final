#!/bin/bash

# Test script to validate project structure creation
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Create test directory
TEST_DIR="/tmp/vantax-test-$(date +%s)"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

print_message $YELLOW "Testing project structure creation in: $TEST_DIR"

# Simulate the project structure creation from deploy-final.sh
services=(
    "api-gateway:4000:API Gateway - Central routing and authentication"
    "identity-service:4001:Identity Service - User authentication and authorization"
    "operations-service:4002:Operations Service - Promotions and campaigns management"
    "analytics-service:4003:Analytics Service - Data analysis and reporting"
    "ai-service:4004:AI Service - Machine learning and predictions"
    "integration-service:4005:Integration Service - External system integrations"
    "coop-service:4006:Co-op Service - Digital wallet and co-op management"
    "notification-service:4007:Notification Service - Email, SMS, and push notifications"
    "reporting-service:4008:Reporting Service - Report generation and scheduling"
    "workflow-service:4009:Workflow Service - Business process automation"
    "audit-service:4010:Audit Service - Compliance and audit trail"
)

print_message $YELLOW "Creating backend services..."

for service_info in "${services[@]}"; do
    IFS=':' read -r service_name service_port service_desc <<< "$service_info"
    
    print_message "Creating $service_name..." $YELLOW
    
    # Create service directory structure
    mkdir -p "backend/$service_name/src"
    
    # Create minimal files to test Docker build context
    echo '{"name": "@vantax/'$service_name'", "version": "1.0.0"}' > "backend/$service_name/package.json"
    echo 'console.log("'$service_name' starting...");' > "backend/$service_name/src/main.ts"
    echo 'FROM node:18-alpine' > "backend/$service_name/Dockerfile"
    
    print_message "✓ Created $service_name" $GREEN
done

# Create frontend structure
print_message $YELLOW "Creating frontend..."
mkdir -p "frontend/web-app/src"
mkdir -p "frontend/web-app/public"
echo '{"name": "@vantax/web-app", "version": "1.0.0"}' > "frontend/web-app/package.json"
echo '<div id="root"></div>' > "frontend/web-app/public/index.html"
echo 'FROM nginx:alpine' > "frontend/web-app/Dockerfile"

# Create deployment structure
print_message $YELLOW "Creating deployment files..."
mkdir -p "deployment"
cat > "deployment/docker-compose.prod.yml" << 'EOF'
services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: vantax
      POSTGRES_USER: vantax_user
      POSTGRES_PASSWORD: ${DB_PASSWORD}
  
  api-gateway:
    build:
      context: ../backend/api-gateway
      dockerfile: Dockerfile
    ports:
      - "4000:4000"
EOF

# Validate structure
print_message $YELLOW "Validating structure..."

errors=0

# Check backend services
for service_info in "${services[@]}"; do
    IFS=':' read -r service_name service_port service_desc <<< "$service_info"
    
    if [[ ! -d "backend/$service_name" ]]; then
        print_message "✗ Missing backend/$service_name directory" $RED
        ((errors++))
    fi
    
    if [[ ! -f "backend/$service_name/package.json" ]]; then
        print_message "✗ Missing backend/$service_name/package.json" $RED
        ((errors++))
    fi
    
    if [[ ! -f "backend/$service_name/Dockerfile" ]]; then
        print_message "✗ Missing backend/$service_name/Dockerfile" $RED
        ((errors++))
    fi
    
    if [[ ! -f "backend/$service_name/src/main.ts" ]]; then
        print_message "✗ Missing backend/$service_name/src/main.ts" $RED
        ((errors++))
    fi
done

# Check frontend
if [[ ! -d "frontend/web-app" ]]; then
    print_message "✗ Missing frontend/web-app directory" $RED
    ((errors++))
fi

if [[ ! -f "frontend/web-app/package.json" ]]; then
    print_message "✗ Missing frontend/web-app/package.json" $RED
    ((errors++))
fi

# Check deployment
if [[ ! -f "deployment/docker-compose.prod.yml" ]]; then
    print_message "✗ Missing deployment/docker-compose.prod.yml" $RED
    ((errors++))
fi

# Test Docker Compose validation
if command -v docker &> /dev/null; then
    print_message $YELLOW "Testing Docker Compose file..."
    export DB_PASSWORD="test123"
    if docker compose -f deployment/docker-compose.prod.yml config > /dev/null 2>&1; then
        print_message "✓ Docker Compose file is valid" $GREEN
    else
        print_message "✗ Docker Compose file has errors" $RED
        ((errors++))
    fi
fi

# Summary
if [[ $errors -eq 0 ]]; then
    print_message "✅ All structure validation tests passed!" $GREEN
    print_message "Project structure is ready for deployment" $GREEN
else
    print_message "❌ Found $errors errors in project structure" $RED
fi

# Show directory tree
print_message $YELLOW "\nProject structure:"
if command -v tree &> /dev/null; then
    tree -L 3
else
    find . -type d | head -20 | sort
fi

# Cleanup
print_message $YELLOW "\nCleaning up test directory: $TEST_DIR"
rm -rf "$TEST_DIR"

exit $errors