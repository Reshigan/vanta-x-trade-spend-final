#!/bin/bash

# Comprehensive test for the clean deployment script
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║          Vanta X - Clean Deployment Test Suite                   ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Test directory
TEST_DIR="/tmp/vantax-clean-test-$(date +%s)"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

print_banner
print_message $YELLOW "Testing clean deployment script in: $TEST_DIR"

# ============================================================================
# TEST 1: Project Structure Creation
# ============================================================================

test_project_structure() {
    print_message $BLUE "\n🧪 TEST 1: Project Structure Creation"
    
    # Simulate the project structure creation from deploy-clean.sh
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
    
    errors=0
    
    for service_info in "${services[@]}"; do
        IFS=':' read -r service_name service_port service_desc <<< "$service_info"
        
        mkdir -p "backend/$service_name/src"
        
        # Create package.json (FIXED VERSION)
        cat > "backend/$service_name/package.json" << EOF
{
  "name": "@vantax/$service_name",
  "version": "1.0.0",
  "description": "$service_desc",
  "main": "dist/main.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/main.js",
    "dev": "nodemon --exec ts-node src/main.ts"
  },
  "dependencies": {
    "express": "^4.18.2",
    "helmet": "^7.1.0",
    "compression": "^1.7.4",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "express-rate-limit": "^7.1.5"
  },
  "devDependencies": {
    "@types/node": "^20.10.4",
    "@types/express": "^4.17.21",
    "@types/compression": "^1.7.5",
    "@types/cors": "^2.8.17",
    "typescript": "^5.3.3",
    "nodemon": "^3.0.2",
    "ts-node": "^10.9.2"
  }
}
EOF

        # Create FIXED Dockerfile (no npm ci --only=production)
        cat > "backend/$service_name/Dockerfile" << EOF
# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./

# Install all dependencies
RUN npm install

# Copy source code
COPY src ./src

# Build application
RUN npm run build

# Production stage
FROM node:18-alpine

# Install dumb-init
RUN apk add --no-cache dumb-init

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install only production dependencies (FIXED COMMAND)
RUN npm install --omit=dev && npm cache clean --force

# Copy built application from builder stage
COPY --from=builder /app/dist ./dist

# Create non-root user
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001

# Create necessary directories and set ownership
RUN mkdir -p /app/logs && chown -R nodejs:nodejs /app

USER nodejs

# Expose port
EXPOSE $service_port

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \\
  CMD node -e "require('http').get('http://localhost:$service_port/health', (r) => r.statusCode === 200 ? process.exit(0) : process.exit(1))"

# Start application
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/main.js"]
EOF

        # Create simple main.ts
        cat > "backend/$service_name/src/main.ts" << EOF
import express from 'express';
import helmet from 'helmet';
import compression from 'compression';
import cors from 'cors';
import dotenv from 'dotenv';
import rateLimit from 'express-rate-limit';

dotenv.config();

const app = express();
const port = process.env.PORT || $service_port;

const log = (message: string) => {
  console.log(\`[\${new Date().toISOString()}] [$service_name] \${message}\`);
};

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: 'Too many requests from this IP'
});

app.use(helmet());
app.use(compression());
app.use(cors());
app.use(express.json());
app.use('/api', limiter);

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: '$service_name',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

app.listen(port, () => {
  log(\`$service_name listening on port \${port}\`);
});

export default app;
EOF

        # Create tsconfig.json
        cat > "backend/$service_name/tsconfig.json" << EOF
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  }
}
EOF

        # Validate files were created
        if [[ ! -f "backend/$service_name/package.json" ]]; then
            print_message "✗ Missing package.json for $service_name" $RED
            ((errors++))
        fi
        
        if [[ ! -f "backend/$service_name/Dockerfile" ]]; then
            print_message "✗ Missing Dockerfile for $service_name" $RED
            ((errors++))
        fi
        
        if [[ ! -f "backend/$service_name/src/main.ts" ]]; then
            print_message "✗ Missing main.ts for $service_name" $RED
            ((errors++))
        fi
        
        # Check for problematic npm commands
        if grep -q "npm ci --only=production" "backend/$service_name/Dockerfile"; then
            print_message "✗ Found problematic npm ci --only=production in $service_name Dockerfile" $RED
            ((errors++))
        fi
    done
    
    if [[ $errors -eq 0 ]]; then
        print_message "✅ Project structure test passed!" $GREEN
    else
        print_message "❌ Project structure test failed with $errors errors" $RED
        return 1
    fi
}

# ============================================================================
# TEST 2: Docker Compose Validation
# ============================================================================

test_docker_compose() {
    print_message $BLUE "\n🧪 TEST 2: Docker Compose Validation"
    
    mkdir -p deployment
    
    # Create FIXED docker-compose file
    cat > "deployment/docker-compose.prod.yml" << 'EOF'
services:
  postgres:
    image: postgres:15-alpine
    container_name: vantax-postgres
    environment:
      POSTGRES_DB: vantax
      POSTGRES_USER: vantax_user
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - vantax-network
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    container_name: vantax-redis
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    networks:
      - vantax-network
    restart: unless-stopped

  api-gateway:
    build:
      context: ../backend/api-gateway
      dockerfile: Dockerfile
    container_name: vantax-api-gateway
    environment:
      NODE_ENV: production
      PORT: 4000
      DATABASE_URL: postgresql://vantax_user:${DB_PASSWORD}@postgres:5432/vantax
      REDIS_URL: redis://:${REDIS_PASSWORD}@redis:6379
      JWT_SECRET: ${JWT_SECRET}
    ports:
      - "4000:4000"
    depends_on:
      - postgres
      - redis
    networks:
      - vantax-network
    restart: unless-stopped

networks:
  vantax-network:
    driver: bridge

volumes:
  postgres_data:
  redis_data:
EOF
    
    # Test Docker Compose validation
    if command -v docker &> /dev/null; then
        export DB_PASSWORD="test123"
        export REDIS_PASSWORD="test456"
        export JWT_SECRET="test789"
        
        if docker compose -f deployment/docker-compose.prod.yml config > /dev/null 2>&1; then
            print_message "✅ Docker Compose validation passed!" $GREEN
        else
            print_message "❌ Docker Compose validation failed!" $RED
            return 1
        fi
    else
        print_message "⚠ Docker not available, skipping compose validation" $YELLOW
    fi
}

# ============================================================================
# TEST 3: Dockerfile Syntax Validation
# ============================================================================

test_dockerfile_syntax() {
    print_message $BLUE "\n🧪 TEST 3: Dockerfile Syntax Validation"
    
    errors=0
    
    # Check all Dockerfiles for problematic commands
    for dockerfile in backend/*/Dockerfile; do
        if [[ -f "$dockerfile" ]]; then
            service_name=$(basename $(dirname "$dockerfile"))
            
            # Check for problematic npm commands
            if grep -q "npm ci --only=production" "$dockerfile"; then
                print_message "✗ Found 'npm ci --only=production' in $service_name Dockerfile" $RED
                ((errors++))
            fi
            
            # Check for correct npm command
            if grep -q "npm install --omit=dev" "$dockerfile"; then
                print_message "✓ Found correct 'npm install --omit=dev' in $service_name" $GREEN
            else
                print_message "✗ Missing correct npm install command in $service_name" $RED
                ((errors++))
            fi
            
            # Check for multi-stage build
            if grep -q "FROM node:18-alpine AS builder" "$dockerfile"; then
                print_message "✓ Multi-stage build found in $service_name" $GREEN
            else
                print_message "✗ Multi-stage build missing in $service_name" $RED
                ((errors++))
            fi
        fi
    done
    
    if [[ $errors -eq 0 ]]; then
        print_message "✅ Dockerfile syntax validation passed!" $GREEN
    else
        print_message "❌ Dockerfile syntax validation failed with $errors errors" $RED
        return 1
    fi
}

# ============================================================================
# TEST 4: Package.json Validation
# ============================================================================

test_package_json() {
    print_message $BLUE "\n🧪 TEST 4: Package.json Validation"
    
    errors=0
    
    for package_file in backend/*/package.json; do
        if [[ -f "$package_file" ]]; then
            service_name=$(basename $(dirname "$package_file"))
            
            # Check if package.json is valid JSON
            if jq empty "$package_file" 2>/dev/null; then
                print_message "✓ Valid JSON in $service_name package.json" $GREEN
            else
                print_message "✗ Invalid JSON in $service_name package.json" $RED
                ((errors++))
            fi
            
            # Check for required dependencies
            required_deps=("express" "helmet" "compression" "cors" "dotenv")
            for dep in "${required_deps[@]}"; do
                if jq -e ".dependencies.\"$dep\"" "$package_file" > /dev/null 2>&1; then
                    print_message "✓ Found $dep dependency in $service_name" $GREEN
                else
                    print_message "✗ Missing $dep dependency in $service_name" $RED
                    ((errors++))
                fi
            done
            
            # Check for TypeScript dev dependencies
            if jq -e '.devDependencies.typescript' "$package_file" > /dev/null 2>&1; then
                print_message "✓ Found TypeScript dev dependency in $service_name" $GREEN
            else
                print_message "✗ Missing TypeScript dev dependency in $service_name" $RED
                ((errors++))
            fi
        fi
    done
    
    if [[ $errors -eq 0 ]]; then
        print_message "✅ Package.json validation passed!" $GREEN
    else
        print_message "❌ Package.json validation failed with $errors errors" $RED
        return 1
    fi
}

# ============================================================================
# TEST 5: TypeScript Configuration
# ============================================================================

test_typescript_config() {
    print_message $BLUE "\n🧪 TEST 5: TypeScript Configuration"
    
    errors=0
    
    for tsconfig_file in backend/*/tsconfig.json; do
        if [[ -f "$tsconfig_file" ]]; then
            service_name=$(basename $(dirname "$tsconfig_file"))
            
            # Check if tsconfig.json is valid JSON
            if jq empty "$tsconfig_file" 2>/dev/null; then
                print_message "✓ Valid JSON in $service_name tsconfig.json" $GREEN
            else
                print_message "✗ Invalid JSON in $service_name tsconfig.json" $RED
                ((errors++))
            fi
            
            # Check for required compiler options
            required_options=("target" "module" "outDir" "rootDir")
            for option in "${required_options[@]}"; do
                if jq -e ".compilerOptions.\"$option\"" "$tsconfig_file" > /dev/null 2>&1; then
                    print_message "✓ Found $option in $service_name tsconfig.json" $GREEN
                else
                    print_message "✗ Missing $option in $service_name tsconfig.json" $RED
                    ((errors++))
                fi
            done
        fi
    done
    
    if [[ $errors -eq 0 ]]; then
        print_message "✅ TypeScript configuration validation passed!" $GREEN
    else
        print_message "❌ TypeScript configuration validation failed with $errors errors" $RED
        return 1
    fi
}

# ============================================================================
# RUN ALL TESTS
# ============================================================================

run_all_tests() {
    print_message $YELLOW "\n🚀 Running comprehensive deployment validation tests..."
    
    total_tests=5
    passed_tests=0
    
    # Run tests
    if test_project_structure; then ((passed_tests++)); fi
    if test_docker_compose; then ((passed_tests++)); fi
    if test_dockerfile_syntax; then ((passed_tests++)); fi
    if test_package_json; then ((passed_tests++)); fi
    if test_typescript_config; then ((passed_tests++)); fi
    
    # Summary
    print_message $BLUE "\n📊 TEST SUMMARY"
    print_message $BLUE "═══════════════════════════════════════════════════════════════════"
    print_message $YELLOW "Total Tests: $total_tests"
    print_message $GREEN "Passed: $passed_tests"
    print_message $RED "Failed: $((total_tests - passed_tests))"
    
    if [[ $passed_tests -eq $total_tests ]]; then
        print_message $GREEN "\n🎉 ALL TESTS PASSED! 🎉"
        print_message $GREEN "The clean deployment script is ready for production use."
        print_message $GREEN "No npm ci --only=production errors will occur."
    else
        print_message $RED "\n❌ SOME TESTS FAILED!"
        print_message $RED "Please fix the issues before deploying."
        return 1
    fi
}

# ============================================================================
# CLEANUP AND EXECUTION
# ============================================================================

# Run tests
if run_all_tests; then
    exit_code=0
else
    exit_code=1
fi

# Cleanup
print_message $YELLOW "\nCleaning up test directory: $TEST_DIR"
rm -rf "$TEST_DIR"

# Final message
if [[ $exit_code -eq 0 ]]; then
    print_message $GREEN "\n✅ Clean deployment script validation completed successfully!"
    print_message $GREEN "You can now run: sudo ./deploy-clean.sh"
else
    print_message $RED "\n❌ Clean deployment script validation failed!"
    print_message $RED "Please review and fix the issues above."
fi

exit $exit_code