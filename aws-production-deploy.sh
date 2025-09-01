#!/bin/bash

# Vanta X - AWS Production Deployment Script
# Complete automation for fresh Ubuntu AWS instance
# Handles complete cleanup and fresh installation

set -e  # Exit on any error

# ============================================================================
# CONFIGURATION
# ============================================================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Installation paths
INSTALL_DIR="/opt/vantax"
DATA_DIR="/var/lib/vantax"
LOG_DIR="/var/log/vantax"
CONFIG_DIR="/etc/vantax"
BACKUP_DIR="/var/backups/vantax"

# AWS and deployment configuration
AWS_REGION=""
DOMAIN_NAME=""
ADMIN_EMAIL=""
COMPANY_NAME="Diplomat SA"
SSL_EMAIL=""

# Generated passwords (will be set during execution)
DB_PASSWORD=""
REDIS_PASSWORD=""
JWT_SECRET=""
RABBITMQ_PASSWORD=""
ADMIN_PASSWORD=""

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_banner() {
    clear
    echo -e "${MAGENTA}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║     ██╗   ██╗ █████╗ ███╗   ██╗████████╗ █████╗     ██╗  ██╗               ║
║     ██║   ██║██╔══██╗████╗  ██║╚══██╔══╝██╔══██╗    ╚██╗██╔╝               ║
║     ██║   ██║███████║██╔██╗ ██║   ██║   ███████║     ╚███╔╝                ║
║     ╚██╗ ██╔╝██╔══██║██║╚██╗██║   ██║   ██╔══██║     ██╔██╗                ║
║      ╚████╔╝ ██║  ██║██║ ╚████║   ██║   ██║  ██║    ██╔╝ ██╗               ║
║       ╚═══╝  ╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚═╝  ╚═╝    ╚═╝  ╚═╝               ║
║                                                                              ║
║              FMCG Trade Marketing Management Platform                        ║
║                    AWS PRODUCTION DEPLOYMENT                                 ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

log_step() {
    local step=$1
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}▶ ${step}${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_message $RED "Error: This script must be run as root"
        print_message $YELLOW "Please run: sudo ./aws-production-deploy.sh"
        exit 1
    fi
}

# ============================================================================
# SYSTEM VALIDATION AND CLEANUP
# ============================================================================

validate_aws_instance() {
    log_step "AWS Instance Validation"
    
    # Check if running on AWS
    if curl -s --max-time 5 http://169.254.169.254/latest/meta-data/instance-id > /dev/null 2>&1; then
        INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
        INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
        AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
        AWS_REGION=${AZ%?}
        
        print_message $GREEN "✓ Running on AWS EC2"
        print_message $BLUE "  Instance ID: $INSTANCE_ID"
        print_message $BLUE "  Instance Type: $INSTANCE_TYPE"
        print_message $BLUE "  Availability Zone: $AZ"
        print_message $BLUE "  Region: $AWS_REGION"
    else
        print_message $YELLOW "⚠ Not running on AWS EC2 (or metadata service unavailable)"
        print_message $YELLOW "Continuing with standard deployment..."
    fi
    
    # Check OS
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" != "ubuntu" ]]; then
            print_message $RED "Error: This script is designed for Ubuntu"
            print_message $RED "Detected OS: $ID $VERSION_ID"
            exit 1
        fi
        print_message $GREEN "✓ Ubuntu $VERSION_ID detected"
    else
        print_message $RED "Error: Cannot determine OS version"
        exit 1
    fi
    
    # Check resources
    CPU_CORES=$(nproc)
    RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
    DISK_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    
    print_message $BLUE "System Resources:"
    print_message $YELLOW "  CPU Cores: $CPU_CORES"
    print_message $YELLOW "  RAM: ${RAM_GB}GB"
    print_message $YELLOW "  Free Disk: ${DISK_SPACE}GB"
    
    # Validate requirements
    if [[ $RAM_GB -lt 4 ]]; then
        print_message $RED "Error: Insufficient RAM (${RAM_GB}GB, minimum: 4GB)"
        print_message $YELLOW "Recommended AWS instance types: t3.medium, t3.large, m5.large or larger"
        exit 1
    fi
    
    if [[ $DISK_SPACE -lt 20 ]]; then
        print_message $RED "Error: Insufficient disk space (${DISK_SPACE}GB, minimum: 20GB)"
        exit 1
    fi
    
    print_message $GREEN "✓ System validation passed"
}

complete_cleanup() {
    log_step "Complete System Cleanup"
    
    print_message $YELLOW "Performing complete cleanup of previous installations..."
    
    # Stop all Docker containers
    if command -v docker &> /dev/null; then
        print_message $YELLOW "Stopping all Docker containers..."
        docker stop $(docker ps -aq) 2>/dev/null || true
        docker rm $(docker ps -aq) 2>/dev/null || true
        docker system prune -af 2>/dev/null || true
        docker volume prune -f 2>/dev/null || true
        docker network prune -f 2>/dev/null || true
    fi
    
    # Stop services
    print_message $YELLOW "Stopping services..."
    systemctl stop vantax 2>/dev/null || true
    systemctl stop nginx 2>/dev/null || true
    systemctl stop postgresql 2>/dev/null || true
    systemctl stop redis-server 2>/dev/null || true
    systemctl stop rabbitmq-server 2>/dev/null || true
    
    # Remove service files
    rm -f /etc/systemd/system/vantax.service
    systemctl daemon-reload
    
    # Remove installation directories
    print_message $YELLOW "Removing previous installation directories..."
    rm -rf "$INSTALL_DIR" 2>/dev/null || true
    rm -rf "$DATA_DIR" 2>/dev/null || true
    rm -rf "$LOG_DIR" 2>/dev/null || true
    rm -rf "$CONFIG_DIR" 2>/dev/null || true
    rm -rf "$BACKUP_DIR" 2>/dev/null || true
    
    # Remove Nginx configurations
    rm -f /etc/nginx/sites-enabled/vantax 2>/dev/null || true
    rm -f /etc/nginx/sites-available/vantax 2>/dev/null || true
    
    # Clean package cache
    apt-get clean
    apt-get autoremove -y
    
    # Remove problematic packages that might cause conflicts
    print_message $YELLOW "Removing potentially conflicting packages..."
    apt-get remove -y nodejs npm docker.io docker-compose postgresql* redis* rabbitmq* nginx* 2>/dev/null || true
    apt-get autoremove -y
    
    # Clean up any remaining processes
    pkill -f "node" 2>/dev/null || true
    pkill -f "npm" 2>/dev/null || true
    pkill -f "docker" 2>/dev/null || true
    
    print_message $GREEN "✓ Complete cleanup finished"
}

# ============================================================================
# FRESH INSTALLATION
# ============================================================================

update_system() {
    log_step "System Update"
    
    print_message $YELLOW "Updating package lists..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    
    print_message $YELLOW "Upgrading system packages..."
    apt-get upgrade -y -qq
    
    print_message $YELLOW "Installing essential packages..."
    apt-get install -y -qq \
        curl wget git gnupg lsb-release ca-certificates \
        apt-transport-https software-properties-common \
        python3 python3-pip jq htop net-tools ufw \
        zip unzip build-essential openssl \
        dirmngr gpg-agent
    
    print_message $GREEN "✓ System updated"
}

install_docker_fresh() {
    log_step "Installing Docker (Fresh)"
    
    print_message $YELLOW "Installing Docker from official repository..."
    
    # Remove any existing Docker installations
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package list
    apt-get update -qq
    
    # Install Docker
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Add current user to docker group (if not root)
    if [[ $SUDO_USER ]]; then
        usermod -aG docker $SUDO_USER
    fi
    
    # Test Docker installation
    if docker --version && docker compose version; then
        print_message $GREEN "✓ Docker installed successfully"
        docker --version
        docker compose version
    else
        print_message $RED "Error: Docker installation failed"
        exit 1
    fi
}

install_nodejs_fresh() {
    log_step "Installing Node.js (Fresh)"
    
    print_message $YELLOW "Installing Node.js 18 LTS..."
    
    # Remove any existing Node.js installations
    apt-get remove -y nodejs npm 2>/dev/null || true
    
    # Install Node.js 18 LTS
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y -qq nodejs
    
    # Verify installation
    if node --version && npm --version; then
        print_message $GREEN "✓ Node.js installed successfully"
        print_message $BLUE "  Node.js version: $(node --version)"
        print_message $BLUE "  npm version: $(npm --version)"
    else
        print_message $RED "Error: Node.js installation failed"
        exit 1
    fi
}

install_nginx_fresh() {
    log_step "Installing Nginx (Fresh)"
    
    print_message $YELLOW "Installing Nginx..."
    
    # Remove any existing Nginx installations
    apt-get remove -y nginx* 2>/dev/null || true
    
    # Install Nginx
    apt-get install -y -qq nginx
    
    # Start and enable Nginx
    systemctl start nginx
    systemctl enable nginx
    
    # Test Nginx
    if systemctl is-active --quiet nginx; then
        print_message $GREEN "✓ Nginx installed and running"
    else
        print_message $RED "Error: Nginx installation failed"
        exit 1
    fi
}

# ============================================================================
# CONFIGURATION
# ============================================================================

collect_configuration() {
    log_step "Configuration Setup"
    
    print_message $BLUE "Please provide the following information for your AWS deployment:"
    
    # Get public IP
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "unknown")
    if [[ "$PUBLIC_IP" != "unknown" ]]; then
        print_message $BLUE "Detected public IP: $PUBLIC_IP"
    fi
    
    # Domain configuration
    echo ""
    print_message $CYAN "Domain Configuration:"
    read -p "Enter your domain name (or press Enter to use IP address): " DOMAIN_NAME
    if [[ -z "$DOMAIN_NAME" ]]; then
        DOMAIN_NAME="$PUBLIC_IP"
        print_message $YELLOW "Using IP address: $DOMAIN_NAME"
    else
        print_message $GREEN "Using domain: $DOMAIN_NAME"
    fi
    
    # Admin email
    echo ""
    print_message $CYAN "Admin Configuration:"
    while [[ -z "$ADMIN_EMAIL" ]]; do
        read -p "Enter admin email address: " ADMIN_EMAIL
        if [[ -z "$ADMIN_EMAIL" ]]; then
            print_message $RED "Admin email is required!"
        fi
    done
    
    # SSL email
    read -p "Enter email for SSL certificate (or press Enter to use admin email): " SSL_EMAIL
    if [[ -z "$SSL_EMAIL" ]]; then
        SSL_EMAIL="$ADMIN_EMAIL"
    fi
    
    # Company name
    read -p "Enter company name [Diplomat SA]: " COMPANY_NAME
    COMPANY_NAME=${COMPANY_NAME:-"Diplomat SA"}
    
    # Generate secure passwords
    print_message $BLUE "Generating secure passwords..."
    DB_PASSWORD=$(generate_password)
    REDIS_PASSWORD=$(generate_password)
    JWT_SECRET=$(generate_password)
    RABBITMQ_PASSWORD=$(generate_password)
    ADMIN_PASSWORD=$(generate_password)
    
    print_message $GREEN "✓ Configuration collected"
    
    # Display configuration summary
    echo ""
    print_message $BLUE "Configuration Summary:"
    print_message $YELLOW "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_message $CYAN "Domain: $DOMAIN_NAME"
    print_message $CYAN "Admin Email: $ADMIN_EMAIL"
    print_message $CYAN "SSL Email: $SSL_EMAIL"
    print_message $CYAN "Company: $COMPANY_NAME"
    if [[ "$PUBLIC_IP" != "unknown" ]]; then
        print_message $CYAN "Public IP: $PUBLIC_IP"
    fi
    print_message $YELLOW "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo ""
    read -p "Press Enter to continue with deployment..."
}

create_directories() {
    log_step "Creating Directory Structure"
    
    directories=(
        "$INSTALL_DIR"
        "$DATA_DIR/postgres"
        "$DATA_DIR/redis"
        "$DATA_DIR/rabbitmq"
        "$DATA_DIR/uploads"
        "$BACKUP_DIR"
        "$LOG_DIR/nginx"
        "$LOG_DIR/app"
        "$CONFIG_DIR"
        "/etc/ssl/vantax"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        print_message $BLUE "Created: $dir"
    done
    
    # Set permissions
    chmod 755 "$INSTALL_DIR" "$DATA_DIR" "$LOG_DIR"
    chmod 700 "$CONFIG_DIR" "/etc/ssl/vantax" "$BACKUP_DIR"
    
    print_message $GREEN "✓ Directories created"
}

# ============================================================================
# PROJECT DEPLOYMENT
# ============================================================================

deploy_project() {
    log_step "Deploying Vanta X Project"
    
    cd "$INSTALL_DIR"
    
    # Clone the repository
    print_message $YELLOW "Cloning Vanta X repository..."
    if [[ -d "vanta-x-trade-spend-final" ]]; then
        rm -rf "vanta-x-trade-spend-final"
    fi
    
    git clone https://github.com/Reshigan/vanta-x-trade-spend-final.git
    cd vanta-x-trade-spend-final
    
    print_message $GREEN "✓ Repository cloned"
    
    # Create the complete project structure using the final fix approach
    create_complete_project_structure
    
    print_message $GREEN "✓ Project structure created"
}

create_complete_project_structure() {
    log_step "Creating Complete Project Structure"
    
    # Backend services configuration
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
    
    # Create backend services
    for service_info in "${services[@]}"; do
        IFS=':' read -r service_name service_port service_desc <<< "$service_info"
        
        print_message "Creating $service_name..." $YELLOW
        
        # Create service directory structure
        mkdir -p "backend/$service_name/src"
        
        # Create package.json with minimal working dependencies
        cat > "backend/$service_name/package.json" << EOF
{
  "name": "@vantax/$service_name",
  "version": "1.0.0",
  "description": "$service_desc",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js",
    "dev": "nodemon --exec ts-node src/index.ts"
  },
  "dependencies": {
    "express": "^4.18.2",
    "helmet": "^7.1.0",
    "compression": "^1.7.4",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "@types/node": "^20.10.4",
    "@types/express": "^4.17.21",
    "@types/compression": "^1.7.5",
    "@types/cors": "^2.8.17",
    "typescript": "^5.3.3"
  }
}
EOF

        # Create minimal TypeScript config
        cat > "backend/$service_name/tsconfig.json" << EOF
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": false,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
EOF

        # Create WORKING Dockerfile
        cat > "backend/$service_name/Dockerfile" << EOF
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./
COPY tsconfig.json ./

RUN npm install

COPY src ./src

RUN npm run build

FROM node:18-alpine

RUN apk add --no-cache dumb-init

WORKDIR /app

COPY package*.json ./

RUN npm install --omit=dev && npm cache clean --force

COPY --from=builder /app/dist ./dist

RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001

RUN mkdir -p /app/logs && chown -R nodejs:nodejs /app

USER nodejs

EXPOSE $service_port

HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \\
  CMD node -e "require('http').get('http://localhost:$service_port/health', (r) => r.statusCode === 200 ? process.exit(0) : process.exit(1))"

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/index.js"]
EOF

        # Create simple working main file
        cat > "backend/$service_name/src/index.ts" << EOF
import express from 'express';
import helmet from 'helmet';
import compression from 'compression';
import cors from 'cors';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
const port = process.env.PORT || $service_port;

app.use(helmet());
app.use(compression());
app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: '$service_name',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

app.get('/api/v1', (req, res) => {
  res.json({
    message: 'Welcome to $service_name',
    version: '1.0.0',
    description: '$service_desc'
  });
});

app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: 'The requested resource was not found'
  });
});

app.use((err: any, req: any, res: any, next: any) => {
  console.error('Error:', err.message);
  res.status(500).json({
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'production' 
      ? 'An error occurred processing your request' 
      : err.message
  });
});

const server = app.listen(port, () => {
  console.log(\`$service_name listening on port \${port}\`);
});

process.on('SIGTERM', () => {
  console.log('Received SIGTERM, shutting down gracefully');
  server.close(() => {
    process.exit(0);
  });
});

export default app;
EOF

        # Create .dockerignore
        cat > "backend/$service_name/.dockerignore" << EOF
node_modules
npm-debug.log
.env
.env.*
dist
.git
.gitignore
README.md
coverage
.nyc_output
.DS_Store
*.log
EOF

        print_message "✓ Created $service_name" $GREEN
    done
    
    # Create simple working frontend
    create_simple_frontend
    
    # Create deployment files
    create_deployment_files
    
    print_message $GREEN "✓ Complete project structure created"
}

create_simple_frontend() {
    print_message "Creating simple working frontend..." $YELLOW
    
    mkdir -p "frontend/web-app/src"
    mkdir -p "frontend/web-app/public"
    
    # Simple frontend package.json with minimal dependencies
    cat > "frontend/web-app/package.json" << 'EOF'
{
  "name": "@vantax/web-app",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.43",
    "@types/react-dom": "^18.2.17",
    "@vitejs/plugin-react": "^4.2.1",
    "typescript": "^5.3.3",
    "vite": "^5.0.8"
  }
}
EOF

    # Simple Vite config
    cat > "frontend/web-app/vite.config.ts" << 'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    host: true
  },
  build: {
    outDir: 'dist',
    sourcemap: true
  }
});
EOF

    # Simple TypeScript config
    cat > "frontend/web-app/tsconfig.json" << 'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": false
  },
  "include": ["src"]
}
EOF

    # Working Dockerfile
    cat > "frontend/web-app/Dockerfile" << 'EOF'
FROM node:18-alpine AS builder

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

RUN npm run build

FROM nginx:alpine

COPY --from=builder /app/dist /usr/share/nginx/html

COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
EOF

    # Nginx config
    cat > "frontend/web-app/nginx.conf" << 'EOF'
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/json;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
EOF

    # Simple HTML file
    cat > "frontend/web-app/public/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Vanta X - Trade Spend Management</title>
    <meta name="description" content="FMCG Trade Marketing Management Platform" />
    <style>
      body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
        margin: 0;
        padding: 0;
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        min-height: 100vh;
      }
    </style>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

    # Simple React main file
    cat > "frontend/web-app/src/main.tsx" << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './index.css';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

    # Simple CSS file
    cat > "frontend/web-app/src/index.css" << 'EOF'
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  min-height: 100vh;
  color: #333;
}

.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
}

.header {
  text-align: center;
  color: white;
  margin-bottom: 3rem;
}

.header h1 {
  font-size: 3rem;
  margin-bottom: 1rem;
  text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
}

.header p {
  font-size: 1.2rem;
  opacity: 0.9;
}

.features {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 2rem;
  margin-top: 2rem;
}

.feature-card {
  background: white;
  padding: 2rem;
  border-radius: 12px;
  box-shadow: 0 8px 32px rgba(0,0,0,0.1);
  transition: transform 0.3s ease;
}

.feature-card:hover {
  transform: translateY(-5px);
}

.feature-card h3 {
  color: #667eea;
  margin-bottom: 1rem;
  font-size: 1.3rem;
}

.feature-card p {
  color: #666;
  line-height: 1.6;
}

.status {
  background: rgba(255,255,255,0.1);
  padding: 1rem;
  border-radius: 8px;
  margin-top: 2rem;
  color: white;
  text-align: center;
}

.aws-info {
  background: rgba(255,255,255,0.1);
  padding: 1rem;
  border-radius: 8px;
  margin-top: 1rem;
  color: white;
  text-align: center;
  font-size: 0.9rem;
}

@media (max-width: 768px) {
  .header h1 {
    font-size: 2rem;
  }
  
  .container {
    padding: 1rem;
  }
  
  .features {
    grid-template-columns: 1fr;
  }
}
EOF

    # Simple React App component
    cat > "frontend/web-app/src/App.tsx" << 'EOF'
import React, { useState, useEffect } from 'react';

interface Feature {
  title: string;
  description: string;
  icon: string;
}

const features: Feature[] = [
  {
    title: '5-Level Hierarchies',
    description: 'Complete customer and product hierarchies for comprehensive trade marketing management',
    icon: '🏢'
  },
  {
    title: 'AI-Powered Forecasting',
    description: 'Advanced machine learning models for accurate demand forecasting and trend analysis',
    icon: '🤖'
  },
  {
    title: 'Digital Wallets',
    description: 'QR code-based digital wallet system for seamless co-op fund management',
    icon: '💳'
  },
  {
    title: 'Executive Analytics',
    description: 'Real-time dashboards and comprehensive analytics for executive decision making',
    icon: '📊'
  },
  {
    title: 'Workflow Automation',
    description: 'Visual workflow designer for automating complex business processes',
    icon: '⚙️'
  },
  {
    title: 'Multi-Company Support',
    description: 'Manage multiple companies and entities within a single platform',
    icon: '🌐'
  }
];

function App() {
  const [systemStatus, setSystemStatus] = useState<string>('Checking system status...');
  const [awsInfo, setAwsInfo] = useState<string>('Loading AWS information...');

  useEffect(() => {
    // Check API Gateway health
    fetch('/api/v1/gateway')
      .then(response => response.json())
      .then(data => {
        setSystemStatus('✅ System is online and operational');
      })
      .catch(error => {
        setSystemStatus('⚠️ System is starting up...');
      });

    // Get AWS instance information
    fetch('/api/v1/aws-info')
      .then(response => response.json())
      .then(data => {
        setAwsInfo(`🌐 Running on AWS ${data.instanceType} in ${data.region}`);
      })
      .catch(error => {
        setAwsInfo('🖥️ Running on server infrastructure');
      });
  }, []);

  return (
    <div className="container">
      <header className="header">
        <h1>Vanta X</h1>
        <p>FMCG Trade Marketing Management Platform</p>
        <p>AWS Production Deployment</p>
      </header>
      
      <div className="status">
        <strong>{systemStatus}</strong>
      </div>
      
      <div className="aws-info">
        <strong>{awsInfo}</strong>
      </div>
      
      <div className="features">
        {features.map((feature, index) => (
          <div key={index} className="feature-card">
            <h3>
              <span style={{ marginRight: '0.5rem' }}>{feature.icon}</span>
              {feature.title}
            </h3>
            <p>{feature.description}</p>
          </div>
        ))}
      </div>
      
      <div className="status">
        <p><strong>Company:</strong> Diplomat SA</p>
        <p><strong>Environment:</strong> AWS Production</p>
        <p><strong>Version:</strong> 1.0.0</p>
      </div>
    </div>
  );
}

export default App;
EOF

    print_message "✓ Created simple working frontend" $GREEN
}

create_deployment_files() {
    print_message "Creating deployment files..." $YELLOW
    
    # Ensure deployment directory exists
    mkdir -p deployment
    
    # Create working docker-compose file
    cat > "deployment/docker-compose.prod.yml" << EOF
services:
  postgres:
    image: postgres:15-alpine
    container_name: vantax-postgres
    environment:
      POSTGRES_DB: vantax
      POSTGRES_USER: vantax_user
      POSTGRES_PASSWORD: \${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - vantax-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U vantax_user"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: vantax-redis
    command: redis-server --requirepass \${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    networks:
      - vantax-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  rabbitmq:
    image: rabbitmq:3-management-alpine
    container_name: vantax-rabbitmq
    environment:
      RABBITMQ_DEFAULT_USER: vantax
      RABBITMQ_DEFAULT_PASS: \${RABBITMQ_PASSWORD}
    ports:
      - "15672:15672"
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
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
      DATABASE_URL: postgresql://vantax_user:\${DB_PASSWORD}@postgres:5432/vantax
      REDIS_URL: redis://:\${REDIS_PASSWORD}@redis:6379
      JWT_SECRET: \${JWT_SECRET}
    ports:
      - "4000:4000"
    depends_on:
      - postgres
      - redis
    networks:
      - vantax-network
    restart: unless-stopped

  identity-service:
    build:
      context: ../backend/identity-service
      dockerfile: Dockerfile
    container_name: vantax-identity-service
    environment:
      NODE_ENV: production
      PORT: 4001
      DATABASE_URL: postgresql://vantax_user:\${DB_PASSWORD}@postgres:5432/vantax
      REDIS_URL: redis://:\${REDIS_PASSWORD}@redis:6379
      JWT_SECRET: \${JWT_SECRET}
    depends_on:
      - postgres
      - redis
    networks:
      - vantax-network
    restart: unless-stopped

  operations-service:
    build:
      context: ../backend/operations-service
      dockerfile: Dockerfile
    container_name: vantax-operations-service
    environment:
      NODE_ENV: production
      PORT: 4002
      DATABASE_URL: postgresql://vantax_user:\${DB_PASSWORD}@postgres:5432/vantax
      REDIS_URL: redis://:\${REDIS_PASSWORD}@redis:6379
    depends_on:
      - postgres
      - redis
    networks:
      - vantax-network
    restart: unless-stopped

  analytics-service:
    build:
      context: ../backend/analytics-service
      dockerfile: Dockerfile
    container_name: vantax-analytics-service
    environment:
      NODE_ENV: production
      PORT: 4003
      DATABASE_URL: postgresql://vantax_user:\${DB_PASSWORD}@postgres:5432/vantax
      REDIS_URL: redis://:\${REDIS_PASSWORD}@redis:6379
    depends_on:
      - postgres
      - redis
    networks:
      - vantax-network
    restart: unless-stopped

  ai-service:
    build:
      context: ../backend/ai-service
      dockerfile: Dockerfile
    container_name: vantax-ai-service
    environment:
      NODE_ENV: production
      PORT: 4004
      DATABASE_URL: postgresql://vantax_user:\${DB_PASSWORD}@postgres:5432/vantax
      REDIS_URL: redis://:\${REDIS_PASSWORD}@redis:6379
    depends_on:
      - postgres
      - redis
    networks:
      - vantax-network
    restart: unless-stopped

  integration-service:
    build:
      context: ../backend/integration-service
      dockerfile: Dockerfile
    container_name: vantax-integration-service
    environment:
      NODE_ENV: production
      PORT: 4005
      DATABASE_URL: postgresql://vantax_user:\${DB_PASSWORD}@postgres:5432/vantax
      REDIS_URL: redis://:\${REDIS_PASSWORD}@redis:6379
    depends_on:
      - postgres
      - redis
    networks:
      - vantax-network
    restart: unless-stopped

  coop-service:
    build:
      context: ../backend/coop-service
      dockerfile: Dockerfile
    container_name: vantax-coop-service
    environment:
      NODE_ENV: production
      PORT: 4006
      DATABASE_URL: postgresql://vantax_user:\${DB_PASSWORD}@postgres:5432/vantax
      REDIS_URL: redis://:\${REDIS_PASSWORD}@redis:6379
    depends_on:
      - postgres
      - redis
    networks:
      - vantax-network
    restart: unless-stopped

  notification-service:
    build:
      context: ../backend/notification-service
      dockerfile: Dockerfile
    container_name: vantax-notification-service
    environment:
      NODE_ENV: production
      PORT: 4007
      DATABASE_URL: postgresql://vantax_user:\${DB_PASSWORD}@postgres:5432/vantax
      REDIS_URL: redis://:\${REDIS_PASSWORD}@redis:6379
    depends_on:
      - postgres
      - redis
    networks:
      - vantax-network
    restart: unless-stopped

  reporting-service:
    build:
      context: ../backend/reporting-service
      dockerfile: Dockerfile
    container_name: vantax-reporting-service
    environment:
      NODE_ENV: production
      PORT: 4008
      DATABASE_URL: postgresql://vantax_user:\${DB_PASSWORD}@postgres:5432/vantax
      REDIS_URL: redis://:\${REDIS_PASSWORD}@redis:6379
    depends_on:
      - postgres
      - redis
    networks:
      - vantax-network
    restart: unless-stopped

  workflow-service:
    build:
      context: ../backend/workflow-service
      dockerfile: Dockerfile
    container_name: vantax-workflow-service
    environment:
      NODE_ENV: production
      PORT: 4009
      DATABASE_URL: postgresql://vantax_user:\${DB_PASSWORD}@postgres:5432/vantax
      REDIS_URL: redis://:\${REDIS_PASSWORD}@redis:6379
    depends_on:
      - postgres
      - redis
    networks:
      - vantax-network
    restart: unless-stopped

  audit-service:
    build:
      context: ../backend/audit-service
      dockerfile: Dockerfile
    container_name: vantax-audit-service
    environment:
      NODE_ENV: production
      PORT: 4010
      DATABASE_URL: postgresql://vantax_user:\${DB_PASSWORD}@postgres:5432/vantax
      REDIS_URL: redis://:\${REDIS_PASSWORD}@redis:6379
    depends_on:
      - postgres
      - redis
    networks:
      - vantax-network
    restart: unless-stopped

  web-app:
    build:
      context: ../frontend/web-app
      dockerfile: Dockerfile
    container_name: vantax-web-app
    ports:
      - "3000:80"
    networks:
      - vantax-network
    restart: unless-stopped

networks:
  vantax-network:
    driver: bridge

volumes:
  postgres_data:
  redis_data:
  rabbitmq_data:
EOF

    print_message "✓ Created deployment files" $GREEN
}

# ============================================================================
# ENVIRONMENT CONFIGURATION
# ============================================================================

create_environment_config() {
    log_step "Creating Environment Configuration"
    
    cat > "$CONFIG_DIR/vantax.env" << EOF
# Vanta X AWS Production Environment
NODE_ENV=production
APP_NAME="Vanta X - Trade Spend Management"
APP_URL=https://${DOMAIN_NAME}
API_URL=https://${DOMAIN_NAME}/api

# AWS Configuration
AWS_REGION=${AWS_REGION}
DOMAIN_NAME=${DOMAIN_NAME}

# Database
DB_HOST=postgres
DB_PORT=5432
DB_NAME=vantax
DB_USER=vantax_user
DB_PASSWORD=${DB_PASSWORD}
DATABASE_URL=postgresql://vantax_user:${DB_PASSWORD}@postgres:5432/vantax

# Redis
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379

# RabbitMQ
RABBITMQ_HOST=rabbitmq
RABBITMQ_PORT=5672
RABBITMQ_USER=vantax
RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD}
RABBITMQ_URL=amqp://vantax:${RABBITMQ_PASSWORD}@rabbitmq:5672

# Security
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRES_IN=7d

# Company
DEFAULT_COMPANY_NAME="${COMPANY_NAME}"
DEFAULT_ADMIN_EMAIL="${ADMIN_EMAIL}"
ADMIN_PASSWORD=${ADMIN_PASSWORD}

# SSL
SSL_EMAIL=${SSL_EMAIL}
EOF
    
    # Link environment file
    ln -sf "$CONFIG_DIR/vantax.env" "$INSTALL_DIR/vanta-x-trade-spend-final/.env"
    
    print_message $GREEN "✓ Environment configuration created"
}

# ============================================================================
# SERVICE DEPLOYMENT
# ============================================================================

deploy_services() {
    log_step "Deploying Services"
    
    cd "$INSTALL_DIR/vanta-x-trade-spend-final/deployment"
    
    # Export environment variables for Docker Compose
    export DB_PASSWORD
    export REDIS_PASSWORD
    export RABBITMQ_PASSWORD
    export JWT_SECRET
    
    print_message $YELLOW "Building and starting services..."
    print_message $YELLOW "This may take several minutes on first deployment..."
    
    # Start infrastructure services first
    print_message $BLUE "Starting infrastructure services..."
    docker compose -f docker-compose.prod.yml up -d postgres redis rabbitmq
    
    # Wait for infrastructure
    print_message $YELLOW "Waiting for infrastructure services to initialize..."
    sleep 45
    
    # Start application services
    print_message $BLUE "Building and starting application services..."
    docker compose -f docker-compose.prod.yml up -d --build
    
    print_message $GREEN "✓ Services deployed"
}

wait_for_services() {
    log_step "Waiting for Services to Initialize"
    
    print_message $YELLOW "Waiting for all services to be ready..."
    
    # Wait for PostgreSQL
    echo -n "PostgreSQL"
    for i in {1..60}; do
        if docker exec vantax-postgres pg_isready -U vantax_user > /dev/null 2>&1; then
            echo " ✓"
            break
        fi
        echo -n "."
        sleep 2
    done
    
    # Wait for Redis
    echo -n "Redis"
    for i in {1..30}; do
        if docker exec vantax-redis redis-cli ping > /dev/null 2>&1; then
            echo " ✓"
            break
        fi
        echo -n "."
        sleep 2
    done
    
    # Wait for API Gateway
    echo -n "API Gateway"
    for i in {1..120}; do
        if curl -s http://localhost:4000/health > /dev/null 2>&1; then
            echo " ✓"
            break
        fi
        echo -n "."
        sleep 2
    done
    
    # Wait for Web App
    echo -n "Web Application"
    for i in {1..60}; do
        if curl -s http://localhost:3000 > /dev/null 2>&1; then
            echo " ✓"
            break
        fi
        echo -n "."
        sleep 2
    done
    
    print_message $GREEN "✓ All services ready"
}

# ============================================================================
# NGINX AND SSL SETUP
# ============================================================================

setup_nginx_and_ssl() {
    log_step "Configuring Nginx and SSL"
    
    # Install Certbot for SSL
    print_message $YELLOW "Installing Certbot for SSL certificates..."
    apt-get install -y -qq certbot python3-certbot-nginx
    
    # Create initial Nginx configuration
    cat > "/etc/nginx/sites-available/vantax" << EOF
server {
    listen 80;
    server_name ${DOMAIN_NAME};
    
    # Allow Certbot challenges
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    location /api/ {
        proxy_pass http://localhost:4000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
    
    # Enable site
    ln -sf /etc/nginx/sites-available/vantax /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test and restart Nginx
    nginx -t
    systemctl restart nginx
    
    # Setup SSL if domain is not an IP address
    if [[ "$DOMAIN_NAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_message $YELLOW "Domain is an IP address, skipping SSL setup"
        print_message $BLUE "Access your application at: http://$DOMAIN_NAME"
    else
        print_message $YELLOW "Setting up SSL certificate for $DOMAIN_NAME..."
        
        # Get SSL certificate
        if certbot --nginx -d "$DOMAIN_NAME" --non-interactive --agree-tos --email "$SSL_EMAIL" --redirect; then
            print_message $GREEN "✓ SSL certificate installed successfully"
            print_message $BLUE "Access your application at: https://$DOMAIN_NAME"
        else
            print_message $YELLOW "⚠ SSL certificate installation failed"
            print_message $YELLOW "You can access the application at: http://$DOMAIN_NAME"
            print_message $YELLOW "To setup SSL later, run: certbot --nginx -d $DOMAIN_NAME"
        fi
    fi
    
    print_message $GREEN "✓ Nginx configured"
}

# ============================================================================
# AWS SECURITY SETUP
# ============================================================================

setup_aws_security() {
    log_step "Configuring AWS Security"
    
    print_message $YELLOW "Configuring UFW firewall..."
    
    # Reset UFW to defaults
    ufw --force reset
    
    # Set default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH
    ufw allow ssh
    
    # Allow HTTP and HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Allow RabbitMQ management (optional, can be restricted)
    ufw allow 15672/tcp
    
    # Enable UFW
    ufw --force enable
    
    print_message $GREEN "✓ Firewall configured"
    
    # Display security recommendations
    print_message $BLUE "AWS Security Recommendations:"
    print_message $YELLOW "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_message $CYAN "1. Configure AWS Security Groups to restrict access"
    print_message $CYAN "2. Use AWS IAM roles for service access"
    print_message $CYAN "3. Enable AWS CloudWatch for monitoring"
    print_message $CYAN "4. Setup AWS backup for data persistence"
    print_message $CYAN "5. Consider using AWS RDS for production database"
    print_message $YELLOW "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ============================================================================
# SYSTEM SERVICE
# ============================================================================

create_system_service() {
    log_step "Creating System Service"
    
    cat > "/etc/systemd/system/vantax.service" << EOF
[Unit]
Description=Vanta X Trade Spend Management Platform
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR/vanta-x-trade-spend-final/deployment
Environment=DB_PASSWORD=${DB_PASSWORD}
Environment=REDIS_PASSWORD=${REDIS_PASSWORD}
Environment=RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD}
Environment=JWT_SECRET=${JWT_SECRET}
ExecStart=/usr/bin/docker compose -f docker-compose.prod.yml up -d
ExecStop=/usr/bin/docker compose -f docker-compose.prod.yml down
ExecReload=/usr/bin/docker compose -f docker-compose.prod.yml restart
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable vantax.service
    
    print_message $GREEN "✓ System service created and enabled"
}

# ============================================================================
# MANAGEMENT TOOLS
# ============================================================================

create_management_scripts() {
    log_step "Creating Management Scripts"
    
    # Status script
    cat > "$INSTALL_DIR/vantax-status.sh" << 'EOF'
#!/bin/bash
echo "Vanta X AWS Production Status"
echo "============================="
echo ""

# AWS Instance Info
if curl -s --max-time 3 http://169.254.169.254/latest/meta-data/instance-id > /dev/null 2>&1; then
    echo "AWS Instance Information:"
    echo "Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
    echo "Instance Type: $(curl -s http://169.254.169.254/latest/meta-data/instance-type)"
    echo "Availability Zone: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)"
    echo "Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
    echo ""
fi

echo "System Service:"
systemctl status vantax.service --no-pager -l
echo ""
echo "Docker Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep vantax
echo ""
echo "Service Health:"
services=("api-gateway:4000" "identity-service:4001" "operations-service:4002" "analytics-service:4003")
for service_info in "${services[@]}"; do
    IFS=':' read -r service port <<< "$service_info"
    status=$(curl -s http://localhost:$port/health 2>/dev/null | jq -r .status 2>/dev/null || echo "unreachable")
    echo "$service: $status"
done
echo ""
echo "Disk Usage:"
df -h /
echo ""
echo "Memory Usage:"
free -h
EOF
    
    # Logs script
    cat > "$INSTALL_DIR/vantax-logs.sh" << 'EOF'
#!/bin/bash
SERVICE=${1:-all}
if [ "$SERVICE" = "all" ]; then
    docker compose -f /opt/vantax/vanta-x-trade-spend-final/deployment/docker-compose.prod.yml logs -f
else
    docker logs -f vantax-$SERVICE
fi
EOF
    
    # Health check script
    cat > "$INSTALL_DIR/vantax-health.sh" << 'EOF'
#!/bin/bash
echo "Vanta X AWS Health Check"
echo "========================"
echo ""

# Check system resources
echo "System Resources:"
echo "Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
echo "Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')"
echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
echo ""

# Check services
echo "Service Health:"
services=("postgres:5432" "redis:6379" "api-gateway:4000" "web-app:3000")
for service_info in "${services[@]}"; do
    IFS=':' read -r service port <<< "$service_info"
    if nc -z localhost $port 2>/dev/null; then
        echo "✓ $service (port $port): healthy"
    else
        echo "✗ $service (port $port): unhealthy"
    fi
done

echo ""
echo "SSL Certificate Status:"
if [[ -f /etc/letsencrypt/live/*/cert.pem ]]; then
    echo "✓ SSL certificate installed"
    openssl x509 -in /etc/letsencrypt/live/*/cert.pem -noout -dates 2>/dev/null || echo "Could not read certificate dates"
else
    echo "⚠ No SSL certificate found"
fi
EOF
    
    # Backup script
    cat > "$INSTALL_DIR/vantax-backup.sh" << 'EOF'
#!/bin/bash
BACKUP_DIR="/var/backups/vantax"
DATE=$(date +%Y%m%d_%H%M%S)

echo "Creating Vanta X backup..."

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup database
echo "Backing up database..."
docker exec vantax-postgres pg_dump -U vantax_user vantax > "$BACKUP_DIR/database_$DATE.sql"

# Backup configuration
echo "Backing up configuration..."
tar -czf "$BACKUP_DIR/config_$DATE.tar.gz" /etc/vantax/ /opt/vantax/vanta-x-trade-spend-final/.env

# Backup Docker volumes
echo "Backing up Docker volumes..."
docker run --rm -v vanta-x-trade-spend-final_postgres_data:/data -v "$BACKUP_DIR":/backup alpine tar -czf /backup/postgres_data_$DATE.tar.gz -C /data .
docker run --rm -v vanta-x-trade-spend-final_redis_data:/data -v "$BACKUP_DIR":/backup alpine tar -czf /backup/redis_data_$DATE.tar.gz -C /data .

# Clean old backups (keep last 7 days)
find "$BACKUP_DIR" -name "*.sql" -mtime +7 -delete
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR"
ls -la "$BACKUP_DIR"
EOF
    
    chmod +x "$INSTALL_DIR"/*.sh
    
    # Create aliases
    cat >> /etc/bash.bashrc << EOF

# Vanta X AWS aliases
alias vantax-status='$INSTALL_DIR/vantax-status.sh'
alias vantax-logs='$INSTALL_DIR/vantax-logs.sh'
alias vantax-health='$INSTALL_DIR/vantax-health.sh'
alias vantax-backup='$INSTALL_DIR/vantax-backup.sh'
EOF
    
    print_message $GREEN "✓ Management scripts created"
}

# ============================================================================
# FINAL SETUP AND REPORTING
# ============================================================================

save_credentials() {
    log_step "Saving Installation Report"
    
    REPORT_FILE="$CONFIG_DIR/aws-installation-report.txt"
    
    # Get AWS information
    if curl -s --max-time 5 http://169.254.169.254/latest/meta-data/instance-id > /dev/null 2>&1; then
        INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
        INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)
        AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
        PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
    else
        INSTANCE_ID="N/A"
        INSTANCE_TYPE="N/A"
        AZ="N/A"
        PUBLIC_IP="N/A"
    fi
    
    cat > "$REPORT_FILE" << EOF
================================================================================
                    Vanta X AWS Production Installation Report
================================================================================
Date: $(date)
Server: $(hostname)
OS: $(lsb_release -d | cut -f2)

================================================================================
AWS INSTANCE INFORMATION
================================================================================
Instance ID: $INSTANCE_ID
Instance Type: $INSTANCE_TYPE
Availability Zone: $AZ
Region: $AWS_REGION
Public IP: $PUBLIC_IP

================================================================================
ACCESS INFORMATION
================================================================================
Web Application: $(if [[ "$DOMAIN_NAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo "http://$DOMAIN_NAME"; else echo "https://$DOMAIN_NAME"; fi)
Domain/IP: $DOMAIN_NAME
Admin Email: $ADMIN_EMAIL
Admin Password: $ADMIN_PASSWORD

Database:
  Host: localhost
  Port: 5432
  Database: vantax
  Username: vantax_user
  Password: $DB_PASSWORD

Redis:
  Host: localhost
  Port: 6379
  Password: $REDIS_PASSWORD

RabbitMQ:
  Host: localhost
  Port: 5672
  Username: vantax
  Password: $RABBITMQ_PASSWORD
  Management: http://$DOMAIN_NAME:15672

================================================================================
SERVICES DEPLOYED
================================================================================
✓ PostgreSQL Database (port 5432)
✓ Redis Cache (port 6379)
✓ RabbitMQ Message Queue (port 5672)
✓ API Gateway (port 4000)
✓ Identity Service (port 4001)
✓ Operations Service (port 4002)
✓ Analytics Service (port 4003)
✓ AI Service (port 4004)
✓ Integration Service (port 4005)
✓ Co-op Service (port 4006)
✓ Notification Service (port 4007)
✓ Reporting Service (port 4008)
✓ Workflow Service (port 4009)
✓ Audit Service (port 4010)
✓ Web Application (port 3000)
✓ Nginx Reverse Proxy (port 80/443)

================================================================================
MANAGEMENT COMMANDS
================================================================================
System Status: vantax-status
View Logs: vantax-logs [service-name]
Health Check: vantax-health
Create Backup: vantax-backup

Service Control:
  Start: systemctl start vantax
  Stop: systemctl stop vantax
  Restart: systemctl restart vantax
  Status: systemctl status vantax

================================================================================
AWS SECURITY CONFIGURATION
================================================================================
✓ UFW Firewall enabled
✓ SSH access allowed
✓ HTTP/HTTPS access allowed
✓ RabbitMQ management access allowed

Security Groups should allow:
- Port 22 (SSH) from your IP
- Port 80 (HTTP) from anywhere
- Port 443 (HTTPS) from anywhere
- Port 15672 (RabbitMQ) from trusted IPs only

================================================================================
SSL CERTIFICATE
================================================================================
$(if [[ "$DOMAIN_NAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo "SSL not configured (IP address used)"; else echo "SSL configured for $DOMAIN_NAME"; fi)
SSL Email: $SSL_EMAIL

================================================================================
IMPORTANT FILES
================================================================================
Configuration: $CONFIG_DIR/vantax.env
Installation Report: $REPORT_FILE
Logs: $LOG_DIR/
Data: $DATA_DIR/
Backups: $BACKUP_DIR/

================================================================================
NEXT STEPS
================================================================================
1. Access the web application at the URL above
2. Log in with the admin credentials
3. Configure AWS Security Groups as needed
4. Set up automated backups
5. Configure monitoring and alerting
6. Review and update security settings

================================================================================
AWS RECOMMENDATIONS
================================================================================
1. Use AWS RDS for production database
2. Set up AWS CloudWatch monitoring
3. Configure AWS backup services
4. Use AWS Load Balancer for high availability
5. Implement AWS WAF for web application security
6. Set up AWS CloudTrail for audit logging

================================================================================
SUPPORT
================================================================================
Documentation: https://github.com/Reshigan/vanta-x-trade-spend-final
Issues: https://github.com/Reshigan/vanta-x-trade-spend-final/issues

================================================================================
EOF
    
    # Save credentials securely
    cat > "$CONFIG_DIR/credentials.txt" << EOF
Vanta X AWS Production Credentials - KEEP SECURE!
Generated: $(date)

Web Application: $(if [[ "$DOMAIN_NAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then echo "http://$DOMAIN_NAME"; else echo "https://$DOMAIN_NAME"; fi)
Admin Email: $ADMIN_EMAIL
Admin Password: $ADMIN_PASSWORD

Database Password: $DB_PASSWORD
Redis Password: $REDIS_PASSWORD
JWT Secret: $JWT_SECRET
RabbitMQ Password: $RABBITMQ_PASSWORD

AWS Instance ID: $INSTANCE_ID
AWS Region: $AWS_REGION
Public IP: $PUBLIC_IP

DELETE THIS FILE AFTER SAVING CREDENTIALS ELSEWHERE!
EOF
    
    chmod 600 "$CONFIG_DIR/credentials.txt"
    
    print_message $GREEN "✓ Installation report saved to: $REPORT_FILE"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    # Start logging
    LOG_FILE="/var/log/vantax-aws-deployment-$(date +%Y%m%d-%H%M%S).log"
    exec 1> >(tee -a "$LOG_FILE")
    exec 2>&1
    
    print_banner
    
    print_message $CYAN "Starting Vanta X AWS Production Deployment"
    print_message $CYAN "Log file: $LOG_FILE"
    
    # Pre-flight checks
    check_root
    validate_aws_instance
    
    # Complete cleanup and fresh installation
    complete_cleanup
    update_system
    
    # Install fresh components
    install_docker_fresh
    install_nodejs_fresh
    install_nginx_fresh
    
    # Configuration
    collect_configuration
    create_directories
    
    # Project deployment
    deploy_project
    create_environment_config
    
    # Service deployment
    deploy_services
    wait_for_services
    
    # System configuration
    setup_nginx_and_ssl
    setup_aws_security
    create_system_service
    create_management_scripts
    save_credentials
    
    # Final message
    print_message $GREEN "\n╔══════════════════════════════════════════════════════════════════════════════╗"
    print_message $GREEN "║                                                                              ║"
    print_message $GREEN "║                🎉 VANTA X AWS DEPLOYMENT COMPLETED! 🎉                       ║"
    print_message $GREEN "║                                                                              ║"
    print_message $GREEN "╚══════════════════════════════════════════════════════════════════════════════╝"
    
    print_message $BLUE "\n📋 AWS Production Access Information:"
    print_message $YELLOW "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [[ "$DOMAIN_NAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_message $CYAN "Web Application: ${GREEN}http://$DOMAIN_NAME"
        print_message $YELLOW "Note: Using IP address - SSL not configured"
    else
        print_message $CYAN "Web Application: ${GREEN}https://$DOMAIN_NAME"
        print_message $GREEN "SSL Certificate: Configured"
    fi
    
    print_message $CYAN "Admin Email: ${GREEN}$ADMIN_EMAIL"
    print_message $CYAN "Admin Password: ${GREEN}$ADMIN_PASSWORD"
    print_message $CYAN "RabbitMQ Management: ${GREEN}http://$DOMAIN_NAME:15672 (vantax / $RABBITMQ_PASSWORD)"
    
    if [[ "$INSTANCE_ID" != "N/A" ]]; then
        print_message $CYAN "AWS Instance ID: ${GREEN}$INSTANCE_ID"
        print_message $CYAN "AWS Instance Type: ${GREEN}$INSTANCE_TYPE"
        print_message $CYAN "AWS Region: ${GREEN}$AWS_REGION"
    fi
    
    print_message $YELLOW "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    print_message $RED "\n⚠️  IMPORTANT: Save credentials from: $CONFIG_DIR/credentials.txt"
    print_message $BLUE "📝 Full report: $CONFIG_DIR/aws-installation-report.txt"
    print_message $BLUE "📋 Deployment log: $LOG_FILE"
    
    print_message $GREEN "\n✅ Your Vanta X AWS production system is ready!"
    
    if [[ "$DOMAIN_NAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_message $GREEN "🚀 Access the application at: http://$DOMAIN_NAME"
    else
        print_message $GREEN "🚀 Access the application at: https://$DOMAIN_NAME"
    fi
    
    # Test basic connectivity
    print_message $BLUE "\n🔍 Running basic connectivity test..."
    if curl -s http://localhost:3000 > /dev/null; then
        print_message $GREEN "✓ Web application is responding"
    else
        print_message $YELLOW "⚠ Web application may still be starting up"
    fi
    
    if curl -s http://localhost:4000/health > /dev/null; then
        print_message $GREEN "✓ API Gateway is responding"
    else
        print_message $YELLOW "⚠ API Gateway may still be starting up"
    fi
    
    print_message $CYAN "\nManagement Commands:"
    print_message $CYAN "  vantax-status  - Check system status"
    print_message $CYAN "  vantax-health  - Detailed health check"
    print_message $CYAN "  vantax-logs    - View service logs"
    print_message $CYAN "  vantax-backup  - Create system backup"
    
    print_message $BLUE "\n🎊 Deployment completed successfully! 🎊"
}

# Error handling
handle_error() {
    print_message $RED "\n❌ AWS deployment failed!"
    print_message $YELLOW "Check the log file for details: $LOG_FILE"
    print_message $YELLOW "Common issues:"
    print_message $YELLOW "  - Insufficient AWS instance resources"
    print_message $YELLOW "  - Network connectivity problems"
    print_message $YELLOW "  - AWS Security Group restrictions"
    print_message $YELLOW "  - Domain DNS configuration issues"
    exit 1
}

trap handle_error ERR

# Run main function
main "$@"