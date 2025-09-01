#!/bin/bash

# Vanta X - Quick Start Script for Development/Testing
# This script provides a simplified installation for development environments

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_message() {
    echo -e "${2}${1}${NC}"
}

print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║          Vanta X - Quick Start for Development                   ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_requirements() {
    print_message "Checking requirements..." $BLUE
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_message "Error: Docker is not installed. Please install Docker first." $RED
        print_message "Visit: https://docs.docker.com/get-docker/" $YELLOW
        exit 1
    fi
    
    # Check Docker Compose
    if ! docker compose version &> /dev/null; then
        print_message "Error: Docker Compose is not installed." $RED
        exit 1
    fi
    
    # Check Git
    if ! command -v git &> /dev/null; then
        print_message "Error: Git is not installed." $RED
        exit 1
    fi
    
    print_message "✓ All requirements met" $GREEN
}

setup_environment() {
    print_message "\nSetting up environment..." $BLUE
    
    # Check if .env exists
    if [ ! -f .env ]; then
        print_message "Creating .env file..." $YELLOW
        
        # Generate random passwords
        DB_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-16)
        REDIS_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-16)
        JWT_SECRET=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
        
        cat > .env << EOF
# Vanta X Development Environment
NODE_ENV=development

# Database
DB_USER=vantax_user
DB_PASSWORD=${DB_PASSWORD}
DATABASE_URL=postgresql://vantax_user:${DB_PASSWORD}@localhost:5432/vantax

# Redis
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_URL=redis://:${REDIS_PASSWORD}@localhost:6379

# RabbitMQ
RABBITMQ_USER=vantax
RABBITMQ_PASSWORD=vantax123

# JWT
JWT_SECRET=${JWT_SECRET}

# Azure AD (Configure these with your Azure AD app)
AZURE_AD_CLIENT_ID=your-client-id
AZURE_AD_CLIENT_SECRET=your-client-secret
AZURE_AD_TENANT_ID=your-tenant-id

# OpenAI (Optional - for AI features)
OPENAI_API_KEY=your-openai-api-key

# SAP (Optional - for SAP integration)
SAP_BASE_URL=https://your-sap-system.com
SAP_CLIENT_ID=your-sap-client
SAP_CLIENT_SECRET=your-sap-secret

# Email (Optional - for notifications)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password

# Monitoring
GRAFANA_USER=admin
GRAFANA_PASSWORD=admin123

# API URL
API_URL=http://localhost:4000
REACT_APP_API_URL=http://localhost:4000
EOF
        
        print_message "✓ Environment file created" $GREEN
        print_message "  Database Password: ${DB_PASSWORD}" $YELLOW
        print_message "  Redis Password: ${REDIS_PASSWORD}" $YELLOW
        print_message "  Please save these passwords!" $RED
    else
        print_message "✓ Using existing .env file" $GREEN
    fi
}

start_infrastructure() {
    print_message "\nStarting infrastructure services..." $BLUE
    
    # Create docker-compose for development
    cat > docker-compose.dev.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: vantax-postgres-dev
    environment:
      POSTGRES_DB: vantax
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: vantax-redis-dev
    command: redis-server --requirepass ${REDIS_PASSWORD}
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  rabbitmq:
    image: rabbitmq:3-management-alpine
    container_name: vantax-rabbitmq-dev
    environment:
      RABBITMQ_DEFAULT_USER: ${RABBITMQ_USER}
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASSWORD}
    ports:
      - "5672:5672"
      - "15672:15672"
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq

volumes:
  postgres_data:
  redis_data:
  rabbitmq_data:
EOF
    
    # Start services
    docker compose -f docker-compose.dev.yml up -d
    
    print_message "✓ Infrastructure services started" $GREEN
}

wait_for_services() {
    print_message "\nWaiting for services to be ready..." $BLUE
    
    # Wait for PostgreSQL
    echo -n "Waiting for PostgreSQL..."
    until docker exec vantax-postgres-dev pg_isready -U vantax_user > /dev/null 2>&1; do
        echo -n "."
        sleep 1
    done
    echo " Ready!"
    
    # Wait for Redis
    echo -n "Waiting for Redis..."
    until docker exec vantax-redis-dev redis-cli ping > /dev/null 2>&1; do
        echo -n "."
        sleep 1
    done
    echo " Ready!"
    
    print_message "✓ All services are ready" $GREEN
}

setup_database() {
    print_message "\nSetting up database..." $BLUE
    
    # Install dependencies
    cd backend/api-gateway
    npm install
    
    # Run migrations
    npm run migrate:dev
    
    # Seed data
    npm run seed:dev
    
    cd ../..
    
    print_message "✓ Database setup complete" $GREEN
}

install_dependencies() {
    print_message "\nInstalling dependencies..." $BLUE
    
    # Backend services
    for service in api-gateway identity-service operations-service analytics-service ai-service integration-service coop-service notification-service reporting-service workflow-service audit-service; do
        if [ -d "backend/$service" ]; then
            print_message "Installing $service dependencies..." $YELLOW
            (cd backend/$service && npm install)
        fi
    done
    
    # Frontend
    print_message "Installing frontend dependencies..." $YELLOW
    (cd frontend/web-app && npm install)
    
    # Mobile (optional)
    if [ -d "mobile/vanta-x-mobile" ]; then
        print_message "Installing mobile dependencies..." $YELLOW
        (cd mobile/vanta-x-mobile && npm install)
    fi
    
    print_message "✓ All dependencies installed" $GREEN
}

start_development() {
    print_message "\nStarting development servers..." $BLUE
    
    cat > start-dev.sh << 'EOF'
#!/bin/bash

# Start all services in development mode
echo "Starting Vanta X development servers..."

# Function to start service in new terminal
start_service() {
    service_name=$1
    service_path=$2
    port=$3
    
    if command -v gnome-terminal &> /dev/null; then
        gnome-terminal --tab --title="$service_name" -- bash -c "cd $service_path && npm run dev; exec bash"
    elif command -v xterm &> /dev/null; then
        xterm -title "$service_name" -e "cd $service_path && npm run dev" &
    else
        echo "Starting $service_name on port $port..."
        (cd $service_path && npm run dev) &
    fi
}

# Start backend services
start_service "API Gateway" "backend/api-gateway" 4000
sleep 2
start_service "Identity Service" "backend/identity-service" 4001
start_service "Operations Service" "backend/operations-service" 4002
start_service "Analytics Service" "backend/analytics-service" 4003
start_service "AI Service" "backend/ai-service" 4004

# Start frontend
start_service "Web App" "frontend/web-app" 3000

echo ""
echo "Services are starting..."
echo ""
echo "Access the application at:"
echo "  Web App: http://localhost:3000"
echo "  API Gateway: http://localhost:4000"
echo "  API Docs: http://localhost:4000/api-docs"
echo "  RabbitMQ: http://localhost:15672 (guest/guest)"
echo ""
echo "Press Ctrl+C to stop all services"

# Wait for interrupt
wait
EOF
    
    chmod +x start-dev.sh
    
    print_message "✓ Development start script created" $GREEN
    print_message "\nTo start all services, run: ./start-dev.sh" $YELLOW
}

display_info() {
    print_message "\n╔══════════════════════════════════════════════════════════════════╗" $GREEN
    print_message "║            Vanta X Quick Start Completed!                        ║" $GREEN
    print_message "╚══════════════════════════════════════════════════════════════════╝" $GREEN
    
    print_message "\nServices Status:" $BLUE
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep vantax
    
    print_message "\nAccess Points:" $BLUE
    print_message "  PostgreSQL: localhost:5432" $YELLOW
    print_message "  Redis: localhost:6379" $YELLOW
    print_message "  RabbitMQ Management: http://localhost:15672" $YELLOW
    print_message "    Username: vantax" $YELLOW
    print_message "    Password: vantax123" $YELLOW
    
    print_message "\nNext Steps:" $BLUE
    print_message "1. Update .env file with your Azure AD credentials" $YELLOW
    print_message "2. Run ./start-dev.sh to start all application services" $YELLOW
    print_message "3. Access the web app at http://localhost:3000" $YELLOW
    print_message "4. Check API documentation at http://localhost:4000/api-docs" $YELLOW
    
    print_message "\nUseful Commands:" $BLUE
    print_message "  View logs: docker compose -f docker-compose.dev.yml logs -f" $YELLOW
    print_message "  Stop services: docker compose -f docker-compose.dev.yml down" $YELLOW
    print_message "  Reset database: docker compose -f docker-compose.dev.yml down -v" $YELLOW
    
    print_message "\nFor production deployment, use: sudo ./install.sh" $GREEN
}

# Main execution
main() {
    print_banner
    check_requirements
    setup_environment
    start_infrastructure
    wait_for_services
    setup_database
    install_dependencies
    start_development
    display_info
}

# Run main function
main "$@"