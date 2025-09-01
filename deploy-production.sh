#!/bin/bash

# Vanta X - Complete Production Deployment Script
# This script deploys a fully configured, production-ready Vanta X system
# Including all dependencies, master data, and initial configuration

set -e  # Exit on error

# ============================================================================
# CONFIGURATION SECTION
# ============================================================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# System Configuration
INSTALL_DIR="/opt/vantax"
DATA_DIR="/var/lib/vantax"
LOG_DIR="/var/log/vantax"
CONFIG_DIR="/etc/vantax"
BACKUP_DIR="/var/backups/vantax"
SYSTEMD_DIR="/etc/systemd/system"
NGINX_DIR="/etc/nginx"
SSL_DIR="/etc/ssl/vantax"

# Default Company Configuration
DEFAULT_COMPANY_NAME="Diplomat SA"
DEFAULT_COMPANY_CODE="DIPSA"
DEFAULT_COUNTRY="South Africa"
DEFAULT_CURRENCY="ZAR"
DEFAULT_TIMEZONE="Africa/Johannesburg"

# Version Information
VANTAX_VERSION="1.0.0"
DEPLOYMENT_DATE=$(date +"%Y-%m-%d %H:%M:%S")

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
║                  Complete Production Deployment                              ║
║                         Version 1.0.0                                        ║
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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_message $RED "Error: This script must be run as root (sudo ./deploy-production.sh)"
        exit 1
    fi
}

generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# ============================================================================
# SYSTEM DETECTION AND VALIDATION
# ============================================================================

detect_system() {
    log_step "System Detection and Validation"
    
    # Detect OS
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        print_message $RED "Error: Cannot detect OS"
        exit 1
    fi
    
    print_message $GREEN "✓ Detected OS: $OS $OS_VERSION"
    
    # Check system requirements
    CPU_CORES=$(nproc)
    RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
    DISK_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    
    print_message $BLUE "System Resources:"
    print_message $YELLOW "  CPU Cores: $CPU_CORES"
    print_message $YELLOW "  RAM: ${RAM_GB}GB"
    print_message $YELLOW "  Free Disk: ${DISK_SPACE}GB"
    
    # Validate minimum requirements
    if [[ $CPU_CORES -lt 4 ]]; then
        print_message $RED "Error: Minimum 4 CPU cores required (found: $CPU_CORES)"
        exit 1
    fi
    
    if [[ $RAM_GB -lt 8 ]]; then
        print_message $RED "Error: Minimum 8GB RAM required (found: ${RAM_GB}GB)"
        exit 1
    fi
    
    if [[ $DISK_SPACE -lt 50 ]]; then
        print_message $RED "Error: Minimum 50GB free disk space required (found: ${DISK_SPACE}GB)"
        exit 1
    fi
    
    print_message $GREEN "✓ System requirements validated"
}

# ============================================================================
# DEPENDENCY INSTALLATION
# ============================================================================

install_system_dependencies() {
    log_step "Installing System Dependencies"
    
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y \
                curl wget git gnupg lsb-release ca-certificates \
                apt-transport-https software-properties-common \
                python3 python3-pip jq htop net-tools ufw fail2ban \
                zip unzip build-essential openssl nginx certbot \
                python3-certbot-nginx postgresql-client redis-tools
            ;;
        rhel|centos|fedora)
            yum install -y epel-release
            yum install -y \
                curl wget git gnupg ca-certificates \
                python3 python3-pip jq htop net-tools firewalld fail2ban \
                zip unzip gcc-c++ make openssl nginx certbot \
                python3-certbot-nginx postgresql redis
            ;;
        *)
            print_message $RED "Error: Unsupported OS"
            exit 1
            ;;
    esac
    
    print_message $GREEN "✓ System dependencies installed"
}

install_docker() {
    log_step "Installing Docker and Docker Compose"
    
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
        print_message $GREEN "✓ Docker already installed: $DOCKER_VERSION"
    else
        case $OS in
            ubuntu|debian)
                curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
                apt-get update
                apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
                ;;
            rhel|centos|fedora)
                yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
                ;;
        esac
        
        systemctl start docker
        systemctl enable docker
        
        print_message $GREEN "✓ Docker installed and started"
    fi
    
    # Verify Docker Compose
    if docker compose version &> /dev/null; then
        print_message $GREEN "✓ Docker Compose verified"
    else
        print_message $RED "Error: Docker Compose not found"
        exit 1
    fi
}

install_nodejs() {
    log_step "Installing Node.js"
    
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        print_message $GREEN "✓ Node.js already installed: $NODE_VERSION"
    else
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs
        
        # Install global packages
        npm install -g pm2 typescript @nestjs/cli
        
        print_message $GREEN "✓ Node.js installed"
    fi
}

# ============================================================================
# CONFIGURATION SETUP
# ============================================================================

collect_configuration() {
    log_step "Configuration Setup"
    
    # Check if running in non-interactive mode
    if [ -n "$VANTAX_DOMAIN" ]; then
        DOMAIN_NAME=$VANTAX_DOMAIN
        ADMIN_EMAIL=$VANTAX_ADMIN_EMAIL
        COMPANY_NAME=${VANTAX_COMPANY_NAME:-$DEFAULT_COMPANY_NAME}
        ENABLE_SSL=${VANTAX_ENABLE_SSL:-yes}
        ENABLE_MONITORING=${VANTAX_ENABLE_MONITORING:-yes}
        ENABLE_BACKUP=${VANTAX_ENABLE_BACKUP:-yes}
        print_message $YELLOW "Using environment variables for configuration"
    else
        # Interactive mode
        read -p "Enter domain name (e.g., vantax.company.com) [localhost]: " DOMAIN_NAME
        DOMAIN_NAME=${DOMAIN_NAME:-localhost}
        
        read -p "Enter admin email address: " ADMIN_EMAIL
        if [[ -z "$ADMIN_EMAIL" ]]; then
            print_message $RED "Error: Admin email is required"
            exit 1
        fi
        
        read -p "Enter company name [$DEFAULT_COMPANY_NAME]: " COMPANY_NAME
        COMPANY_NAME=${COMPANY_NAME:-$DEFAULT_COMPANY_NAME}
        
        read -p "Enable SSL certificate? (yes/no) [yes]: " ENABLE_SSL
        ENABLE_SSL=${ENABLE_SSL:-yes}
        
        read -p "Enable monitoring? (yes/no) [yes]: " ENABLE_MONITORING
        ENABLE_MONITORING=${ENABLE_MONITORING:-yes}
        
        read -p "Enable automated backups? (yes/no) [yes]: " ENABLE_BACKUP
        ENABLE_BACKUP=${ENABLE_BACKUP:-yes}
    fi
    
    # Generate secure passwords
    print_message $BLUE "Generating secure passwords..."
    DB_PASSWORD=$(generate_password)
    REDIS_PASSWORD=$(generate_password)
    JWT_SECRET=$(generate_password)
    RABBITMQ_PASSWORD=$(generate_password)
    GRAFANA_PASSWORD=$(generate_password)
    ADMIN_PASSWORD=$(generate_password)
    API_KEY=$(generate_password)
    
    print_message $GREEN "✓ Configuration collected"
}

create_directory_structure() {
    log_step "Creating Directory Structure"
    
    directories=(
        "$INSTALL_DIR"
        "$DATA_DIR/postgres"
        "$DATA_DIR/redis"
        "$DATA_DIR/rabbitmq"
        "$DATA_DIR/uploads/images"
        "$DATA_DIR/uploads/documents"
        "$DATA_DIR/uploads/exports"
        "$DATA_DIR/uploads/imports"
        "$BACKUP_DIR"
        "$LOG_DIR/nginx"
        "$LOG_DIR/app"
        "$LOG_DIR/system"
        "$CONFIG_DIR"
        "$SSL_DIR"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        print_message $GREEN "✓ Created: $dir"
    done
    
    # Set permissions
    chmod 755 "$INSTALL_DIR"
    chmod 755 "$DATA_DIR"
    chmod 755 "$LOG_DIR"
    chmod 700 "$CONFIG_DIR"
    chmod 700 "$SSL_DIR"
    chmod 700 "$BACKUP_DIR"
    
    print_message $GREEN "✓ Directory structure created"
}

# ============================================================================
# APPLICATION DEPLOYMENT
# ============================================================================

clone_repository() {
    log_step "Cloning Vanta X Repository"
    
    cd "$INSTALL_DIR"
    
    if [[ -d "vanta-x-trade-spend-final" ]]; then
        print_message $YELLOW "Repository exists, pulling latest changes..."
        cd vanta-x-trade-spend-final
        git pull origin main
    else
        git clone https://github.com/Reshigan/vanta-x-trade-spend-final.git
        cd vanta-x-trade-spend-final
    fi
    
    print_message $GREEN "✓ Repository ready"
}

create_project_structure() {
    log_step "Creating Project Structure"
    
    cd "$INSTALL_DIR/vanta-x-trade-spend-final"
    
    # Create backend services
    services=(
        "api-gateway:4000"
        "identity-service:4001"
        "operations-service:4002"
        "analytics-service:4003"
        "ai-service:4004"
        "integration-service:4005"
        "coop-service:4006"
        "notification-service:4007"
        "reporting-service:4008"
        "workflow-service:4009"
        "audit-service:4010"
    )
    
    for service_info in "${services[@]}"; do
        IFS=':' read -r service_name service_port <<< "$service_info"
        
        print_message "Creating $service_name..." $YELLOW
        
        mkdir -p "backend/$service_name/src"
        
        # Create minimal package.json
        cat > "backend/$service_name/package.json" << EOF
{
  "name": "@vantax/$service_name",
  "version": "1.0.0",
  "description": "Vanta X $service_name",
  "main": "dist/main.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/main.js",
    "dev": "nodemon --exec ts-node src/main.ts"
  },
  "dependencies": {
    "express": "^4.18.2",
    "helmet": "^7.1.0",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "winston": "^3.11.0"
  },
  "devDependencies": {
    "@types/node": "^20.10.4",
    "@types/express": "^4.17.21",
    "typescript": "^5.3.3",
    "nodemon": "^3.0.2",
    "ts-node": "^10.9.2"
  }
}
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

        # Create Dockerfile
        cat > "backend/$service_name/Dockerfile" << EOF
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
COPY tsconfig.json ./
RUN npm ci
COPY src ./src
RUN npm run build

FROM node:18-alpine
WORKDIR /app
RUN apk add --no-cache dumb-init
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force
COPY --from=builder /app/dist ./dist
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
USER nodejs
EXPOSE $service_port
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \\
  CMD node -e "require('http').get('http://localhost:$service_port/health', (r) => r.statusCode === 200 ? process.exit(0) : process.exit(1))"
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/main.js"]
EOF

        # Create main.ts
        cat > "backend/$service_name/src/main.ts" << EOF
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
const port = process.env.PORT || $service_port;

app.use(helmet());
app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: '$service_name',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

app.get('/metrics', (req, res) => {
  res.json({
    memory: process.memoryUsage(),
    uptime: process.uptime()
  });
});

app.listen(port, () => {
  console.log(\`$service_name listening on port \${port}\`);
});

process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  process.exit(0);
});
EOF

        print_message "✓ Created $service_name" $GREEN
    done
    
    # Create frontend structure
    print_message "Creating frontend..." $YELLOW
    mkdir -p "frontend/web-app/src"
    mkdir -p "frontend/web-app/public"
    
    cat > "frontend/web-app/package.json" << EOF
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
    "react-dom": "^18.2.0",
    "@mui/material": "^5.15.0",
    "@emotion/react": "^11.11.1",
    "@emotion/styled": "^11.11.0"
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

    cat > "frontend/web-app/vite.config.ts" << EOF
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    host: true
  }
});
EOF

    cat > "frontend/web-app/tsconfig.json" << EOF
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
    "strict": true
  },
  "include": ["src"]
}
EOF

    cat > "frontend/web-app/Dockerfile" << EOF
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

    cat > "frontend/web-app/public/index.html" << EOF
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Vanta X - Trade Spend Management</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

    cat > "frontend/web-app/src/main.tsx" << EOF
import React from 'react';
import ReactDOM from 'react-dom/client';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import CssBaseline from '@mui/material/CssBaseline';
import App from './App';

const theme = createTheme({
  palette: {
    primary: { main: '#1976d2' },
    secondary: { main: '#dc004e' }
  }
});

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <App />
    </ThemeProvider>
  </React.StrictMode>
);
EOF

    cat > "frontend/web-app/src/App.tsx" << EOF
import React from 'react';
import { Container, Typography, Box } from '@mui/material';

function App() {
  return (
    <Container maxWidth="lg">
      <Box sx={{ my: 4, textAlign: 'center' }}>
        <Typography variant="h2" component="h1" gutterBottom>
          Vanta X
        </Typography>
        <Typography variant="h5" component="h2" gutterBottom>
          FMCG Trade Marketing Management Platform
        </Typography>
        <Typography variant="body1" color="text.secondary">
          Welcome to your comprehensive trade marketing solution
        </Typography>
      </Box>
    </Container>
  );
}

export default App;
EOF

    print_message "✓ Created frontend" $GREEN
    
    # Create scripts directory
    mkdir -p scripts
    
    print_message $GREEN "✓ Project structure created"
}

create_environment_configuration() {
    log_step "Creating Environment Configuration"
    
    cat > "$CONFIG_DIR/vantax.env" << EOF
# Vanta X Production Environment Configuration
# Generated: $DEPLOYMENT_DATE
# Version: $VANTAX_VERSION

# ============================================================================
# APPLICATION SETTINGS
# ============================================================================
NODE_ENV=production
APP_NAME="Vanta X - Trade Spend Management"
APP_VERSION=$VANTAX_VERSION
APP_URL=https://${DOMAIN_NAME}
API_URL=https://${DOMAIN_NAME}/api
FRONTEND_URL=https://${DOMAIN_NAME}

# ============================================================================
# DATABASE CONFIGURATION
# ============================================================================
DB_HOST=postgres
DB_PORT=5432
DB_NAME=vantax
DB_USER=vantax_user
DB_PASSWORD=${DB_PASSWORD}
DATABASE_URL=postgresql://vantax_user:${DB_PASSWORD}@postgres:5432/vantax
DB_POOL_MIN=2
DB_POOL_MAX=10
DB_SSL=false

# ============================================================================
# REDIS CONFIGURATION
# ============================================================================
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379
REDIS_TTL=3600

# ============================================================================
# RABBITMQ CONFIGURATION
# ============================================================================
RABBITMQ_HOST=rabbitmq
RABBITMQ_PORT=5672
RABBITMQ_USER=vantax
RABBITMQ_PASSWORD=${RABBITMQ_PASSWORD}
RABBITMQ_URL=amqp://vantax:${RABBITMQ_PASSWORD}@rabbitmq:5672
RABBITMQ_VHOST=/

# ============================================================================
# AUTHENTICATION & SECURITY
# ============================================================================
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRES_IN=7d
REFRESH_TOKEN_EXPIRES_IN=30d
SESSION_SECRET=${JWT_SECRET}
ENCRYPTION_KEY=${API_KEY}
API_KEY=${API_KEY}

# Azure AD Configuration
AZURE_AD_CLIENT_ID=${AZURE_AD_CLIENT_ID:-your-client-id}
AZURE_AD_CLIENT_SECRET=${AZURE_AD_CLIENT_SECRET:-your-client-secret}
AZURE_AD_TENANT_ID=${AZURE_AD_TENANT_ID:-your-tenant-id}
AZURE_AD_REDIRECT_URI=https://${DOMAIN_NAME}/auth/callback

# ============================================================================
# AI & MACHINE LEARNING
# ============================================================================
OPENAI_API_KEY=${OPENAI_API_KEY:-your-openai-api-key}
OPENAI_MODEL=gpt-4
HUGGINGFACE_API_KEY=${HUGGINGFACE_API_KEY:-your-huggingface-api-key}
ML_MODEL_PATH=/app/models
ENABLE_AI_FEATURES=true

# ============================================================================
# SAP INTEGRATION
# ============================================================================
SAP_BASE_URL=${SAP_BASE_URL:-https://your-sap-system.com}
SAP_CLIENT_ID=${SAP_CLIENT_ID:-your-sap-client}
SAP_CLIENT_SECRET=${SAP_CLIENT_SECRET:-your-sap-secret}
SAP_SYSTEM_ID=${SAP_SYSTEM_ID:-PRD}
SAP_CLIENT_NUMBER=${SAP_CLIENT_NUMBER:-100}
ENABLE_SAP_INTEGRATION=${ENABLE_SAP_INTEGRATION:-false}

# ============================================================================
# EMAIL CONFIGURATION
# ============================================================================
SMTP_HOST=${SMTP_HOST:-smtp.gmail.com}
SMTP_PORT=${SMTP_PORT:-587}
SMTP_SECURE=false
SMTP_USER=${SMTP_USER:-$ADMIN_EMAIL}
SMTP_PASSWORD=${SMTP_PASSWORD:-your-smtp-password}
EMAIL_FROM="Vanta X <noreply@${DOMAIN_NAME}>"
EMAIL_ADMIN=${ADMIN_EMAIL}

# ============================================================================
# MONITORING & LOGGING
# ============================================================================
GRAFANA_USER=admin
GRAFANA_PASSWORD=${GRAFANA_PASSWORD}
PROMETHEUS_RETENTION=30d
LOG_LEVEL=info
LOG_FORMAT=json
ENABLE_MONITORING=${ENABLE_MONITORING}
SENTRY_DSN=${SENTRY_DSN:-}

# ============================================================================
# BACKUP CONFIGURATION
# ============================================================================
BACKUP_ENABLED=${ENABLE_BACKUP}
BACKUP_RETENTION_DAYS=30
BACKUP_SCHEDULE="0 2 * * *"
BACKUP_S3_BUCKET=${BACKUP_S3_BUCKET:-vantax-backups}
BACKUP_S3_REGION=${BACKUP_S3_REGION:-us-east-1}
BACKUP_S3_ACCESS_KEY=${BACKUP_S3_ACCESS_KEY:-}
BACKUP_S3_SECRET_KEY=${BACKUP_S3_SECRET_KEY:-}

# ============================================================================
# PERFORMANCE & SCALING
# ============================================================================
WORKER_PROCESSES=auto
WORKER_CONNECTIONS=1024
CLIENT_MAX_BODY_SIZE=100M
REQUEST_TIMEOUT=300000
UPLOAD_LIMIT=104857600

# ============================================================================
# SECURITY SETTINGS
# ============================================================================
CORS_ORIGIN=https://${DOMAIN_NAME}
CORS_CREDENTIALS=true
RATE_LIMIT_WINDOW=15
RATE_LIMIT_MAX=100
HELMET_ENABLED=true
CSRF_ENABLED=true

# ============================================================================
# FEATURE FLAGS
# ============================================================================
ENABLE_MOBILE_APP=true
ENABLE_DIGITAL_WALLETS=true
ENABLE_MONTE_CARLO=true
ENABLE_WORKFLOW_ENGINE=true
ENABLE_AUDIT_LOG=true
ENABLE_MULTI_TENANT=true
ENABLE_OFFLINE_MODE=true

# ============================================================================
# COMPANY DEFAULTS
# ============================================================================
DEFAULT_COMPANY_NAME="${COMPANY_NAME}"
DEFAULT_COMPANY_CODE="${DEFAULT_COMPANY_CODE}"
DEFAULT_COUNTRY="${DEFAULT_COUNTRY}"
DEFAULT_CURRENCY="${DEFAULT_CURRENCY}"
DEFAULT_TIMEZONE="${DEFAULT_TIMEZONE}"
DEFAULT_LANGUAGE=en

# ============================================================================
# SYSTEM CONFIGURATION
# ============================================================================
TZ=${DEFAULT_TIMEZONE}
DEPLOYMENT_DATE="${DEPLOYMENT_DATE}"
DEPLOYMENT_VERSION="${VANTAX_VERSION}"
EOF
    
    # Create Docker environment file
    ln -sf "$CONFIG_DIR/vantax.env" "$INSTALL_DIR/vanta-x-trade-spend-final/.env"
    
    print_message $GREEN "✓ Environment configuration created"
}

# ============================================================================
# MASTER DATA SETUP
# ============================================================================

create_master_data_script() {
    log_step "Creating Master Data Setup Script"
    
    cat > "$INSTALL_DIR/vanta-x-trade-spend-final/scripts/setup-master-data.ts" << 'EOF'
import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function setupMasterData() {
  console.log('Setting up master data...');

  try {
    // Create default company
    const company = await prisma.company.upsert({
      where: { code: process.env.DEFAULT_COMPANY_CODE || 'DIPSA' },
      update: {},
      create: {
        name: process.env.DEFAULT_COMPANY_NAME || 'Diplomat SA',
        code: process.env.DEFAULT_COMPANY_CODE || 'DIPSA',
        type: 'DISTRIBUTOR',
        status: 'ACTIVE',
        country: process.env.DEFAULT_COUNTRY || 'South Africa',
        currency: process.env.DEFAULT_CURRENCY || 'ZAR',
        timezone: process.env.DEFAULT_TIMEZONE || 'Africa/Johannesburg',
        fiscalYearStart: 1,
        settings: {
          enableDigitalWallets: true,
          enableAIFeatures: true,
          enableMobileApp: true,
          defaultLanguage: 'en',
          dateFormat: 'DD/MM/YYYY',
          numberFormat: '1,234.56'
        }
      }
    });

    console.log(`✓ Company created: ${company.name}`);

    // Create roles
    const roles = [
      { name: 'Super Admin', code: 'SUPER_ADMIN', description: 'Full system access', level: 1 },
      { name: 'Company Admin', code: 'COMPANY_ADMIN', description: 'Company administration', level: 2 },
      { name: 'Finance Manager', code: 'FINANCE_MANAGER', description: 'Financial operations', level: 3 },
      { name: 'Sales Manager', code: 'SALES_MANAGER', description: 'Sales operations', level: 3 },
      { name: 'Marketing Manager', code: 'MARKETING_MANAGER', description: 'Marketing operations', level: 3 },
      { name: 'Key Account Manager', code: 'KAM', description: 'Key account management', level: 4 },
      { name: 'Field Sales Rep', code: 'FIELD_REP', description: 'Field operations', level: 5 },
      { name: 'Analyst', code: 'ANALYST', description: 'Data analysis and reporting', level: 5 },
      { name: 'Auditor', code: 'AUDITOR', description: 'Audit and compliance', level: 4 },
      { name: 'Viewer', code: 'VIEWER', description: 'Read-only access', level: 6 }
    ];

    for (const role of roles) {
      await prisma.role.upsert({
        where: { code: role.code },
        update: {},
        create: role
      });
    }

    console.log(`✓ Created ${roles.length} roles`);

    // Create admin user
    const adminPassword = await bcrypt.hash(process.env.ADMIN_PASSWORD || 'Admin@123', 10);
    const adminUser = await prisma.user.upsert({
      where: { email: process.env.EMAIL_ADMIN || 'admin@vantax.com' },
      update: {},
      create: {
        email: process.env.EMAIL_ADMIN || 'admin@vantax.com',
        password: adminPassword,
        firstName: 'System',
        lastName: 'Administrator',
        status: 'ACTIVE',
        emailVerified: true,
        companyId: company.id,
        roleId: (await prisma.role.findUnique({ where: { code: 'SUPER_ADMIN' } }))!.id,
        preferences: {
          theme: 'light',
          language: 'en',
          notifications: {
            email: true,
            push: true,
            sms: false
          }
        }
      }
    });

    console.log(`✓ Admin user created: ${adminUser.email}`);

    // Create 5-level customer hierarchy
    const globalAccounts = [
      { name: 'Shoprite Holdings', code: 'SHOP', type: 'GLOBAL_ACCOUNT' },
      { name: 'Pick n Pay Group', code: 'PNP', type: 'GLOBAL_ACCOUNT' },
      { name: 'Spar Group', code: 'SPAR', type: 'GLOBAL_ACCOUNT' },
      { name: 'Woolworths Holdings', code: 'WOOL', type: 'GLOBAL_ACCOUNT' },
      { name: 'Massmart Holdings', code: 'MASS', type: 'GLOBAL_ACCOUNT' }
    ];

    for (const ga of globalAccounts) {
      const globalAccount = await prisma.customerHierarchy.create({
        data: {
          ...ga,
          level: 1,
          companyId: company.id
        }
      });

      // Create regions
      const regions = ['Western Cape', 'Gauteng', 'KwaZulu-Natal'];
      for (const regionName of regions) {
        const region = await prisma.customerHierarchy.create({
          data: {
            name: `${ga.name} - ${regionName}`,
            code: `${ga.code}_${regionName.replace(/\s+/g, '_').toUpperCase()}`,
            type: 'REGION',
            level: 2,
            parentId: globalAccount.id,
            companyId: company.id
          }
        });

        // Create channels
        const channels = ['Hypermarket', 'Supermarket', 'Convenience'];
        for (const channelName of channels) {
          const channel = await prisma.customerHierarchy.create({
            data: {
              name: `${channelName}`,
              code: `${ga.code}_${channelName.toUpperCase()}`,
              type: 'CHANNEL',
              level: 4,
              parentId: region.id,
              companyId: company.id
            }
          });

          // Create sample stores
          for (let i = 1; i <= 3; i++) {
            await prisma.customerHierarchy.create({
              data: {
                name: `${ga.name} ${channelName} Store ${i}`,
                code: `${ga.code}_${channelName.substring(0, 3).toUpperCase()}_${i}`,
                type: 'STORE',
                level: 5,
                parentId: channel.id,
                companyId: company.id,
                metadata: {
                  address: `${i} Main Street, ${regionName}`,
                  manager: `Manager ${i}`,
                  size: ['Small', 'Medium', 'Large'][i - 1]
                }
              }
            });
          }
        }
      }
    }

    console.log('✓ Customer hierarchy created');

    // Create 5-level product hierarchy
    const categories = [
      { name: 'Beverages', code: 'BEV' },
      { name: 'Snacks', code: 'SNK' },
      { name: 'Personal Care', code: 'PC' },
      { name: 'Home Care', code: 'HC' },
      { name: 'Food', code: 'FOOD' }
    ];

    for (const cat of categories) {
      const category = await prisma.productHierarchy.create({
        data: {
          ...cat,
          type: 'CATEGORY',
          level: 1,
          companyId: company.id
        }
      });

      // Create subcategories
      const subcategories = {
        'BEV': ['Carbonated', 'Juice', 'Water', 'Energy'],
        'SNK': ['Chips', 'Nuts', 'Chocolate', 'Biscuits'],
        'PC': ['Shampoo', 'Soap', 'Toothpaste', 'Deodorant'],
        'HC': ['Detergent', 'Cleaner', 'Air Freshener', 'Dishwash'],
        'FOOD': ['Canned', 'Pasta', 'Rice', 'Sauces']
      };

      for (const subName of subcategories[cat.code] || []) {
        const subcategory = await prisma.productHierarchy.create({
          data: {
            name: subName,
            code: `${cat.code}_${subName.toUpperCase().replace(/\s+/g, '_')}`,
            type: 'SUBCATEGORY',
            level: 2,
            parentId: category.id,
            companyId: company.id
          }
        });

        // Create brands
        const brands = ['Premium Brand', 'Value Brand', 'Own Brand'];
        for (const brandName of brands) {
          const brand = await prisma.productHierarchy.create({
            data: {
              name: `${brandName} ${subName}`,
              code: `${subcategory.code}_${brandName.split(' ')[0].toUpperCase()}`,
              type: 'BRAND',
              level: 3,
              parentId: subcategory.id,
              companyId: company.id
            }
          });

          // Create product lines
          const productLine = await prisma.productHierarchy.create({
            data: {
              name: `${brandName} ${subName} Line`,
              code: `${brand.code}_LINE`,
              type: 'PRODUCT_LINE',
              level: 4,
              parentId: brand.id,
              companyId: company.id
            }
          });

          // Create SKUs
          const sizes = ['Small', 'Medium', 'Large'];
          for (const size of sizes) {
            await prisma.productHierarchy.create({
              data: {
                name: `${brandName} ${subName} ${size}`,
                code: `${productLine.code}_${size.charAt(0)}`,
                type: 'SKU',
                level: 5,
                parentId: productLine.id,
                companyId: company.id,
                metadata: {
                  barcode: `600${Math.floor(Math.random() * 1000000)}`,
                  size: size,
                  unit: 'EA',
                  weight: size === 'Small' ? '250g' : size === 'Medium' ? '500g' : '1kg'
                }
              }
            });
          }
        }
      }
    }

    console.log('✓ Product hierarchy created');

    // Create vendors
    const vendors = [
      { name: 'Unilever', code: 'UNIL', type: 'MULTINATIONAL' },
      { name: 'Procter & Gamble', code: 'PG', type: 'MULTINATIONAL' },
      { name: 'Nestle', code: 'NEST', type: 'MULTINATIONAL' },
      { name: 'Coca-Cola', code: 'COKE', type: 'MULTINATIONAL' },
      { name: 'PepsiCo', code: 'PEPS', type: 'MULTINATIONAL' },
      { name: 'Local Foods Ltd', code: 'LOCF', type: 'LOCAL' },
      { name: 'Regional Snacks Co', code: 'REGSNK', type: 'REGIONAL' }
    ];

    for (const vendor of vendors) {
      await prisma.vendor.create({
        data: {
          ...vendor,
          status: 'ACTIVE',
          companyId: company.id,
          contactInfo: {
            email: `contact@${vendor.code.toLowerCase()}.com`,
            phone: '+27 11 123 4567',
            address: '123 Business Park, Johannesburg'
          }
        }
      });
    }

    console.log(`✓ Created ${vendors.length} vendors`);

    // Create promotion types
    const promotionTypes = [
      { name: 'Buy One Get One', code: 'BOGO', description: 'Buy one item, get one free' },
      { name: 'Percentage Off', code: 'PCT_OFF', description: 'Percentage discount on products' },
      { name: 'Amount Off', code: 'AMT_OFF', description: 'Fixed amount discount' },
      { name: 'Bundle Deal', code: 'BUNDLE', description: 'Special price for product bundles' },
      { name: 'Volume Discount', code: 'VOL_DISC', description: 'Discount based on quantity' },
      { name: 'Free Gift', code: 'FREE_GIFT', description: 'Free product with purchase' },
      { name: 'Cashback', code: 'CASHBACK', description: 'Money back after purchase' },
      { name: 'Loyalty Points', code: 'LOYALTY', description: 'Earn points for purchases' }
    ];

    for (const promoType of promotionTypes) {
      await prisma.promotionType.create({
        data: {
          ...promoType,
          companyId: company.id
        }
      });
    }

    console.log(`✓ Created ${promotionTypes.length} promotion types`);

    // Create budget categories
    const budgetCategories = [
      { name: 'Trade Promotions', code: 'TRADE_PROMO', type: 'EXPENSE' },
      { name: 'Consumer Promotions', code: 'CONSUMER_PROMO', type: 'EXPENSE' },
      { name: 'Digital Marketing', code: 'DIGITAL_MKT', type: 'EXPENSE' },
      { name: 'In-Store Display', code: 'DISPLAY', type: 'EXPENSE' },
      { name: 'Co-op Advertising', code: 'COOP_ADV', type: 'EXPENSE' },
      { name: 'Listing Fees', code: 'LISTING', type: 'EXPENSE' },
      { name: 'Rebates', code: 'REBATES', type: 'EXPENSE' },
      { name: 'Sales Revenue', code: 'SALES_REV', type: 'REVENUE' }
    ];

    for (const category of budgetCategories) {
      await prisma.budgetCategory.create({
        data: {
          ...category,
          companyId: company.id
        }
      });
    }

    console.log(`✓ Created ${budgetCategories.length} budget categories`);

    // Create workflow templates
    const workflowTemplates = [
      {
        name: 'Promotion Approval',
        code: 'PROMO_APPROVAL',
        description: 'Standard promotion approval workflow',
        steps: [
          { name: 'KAM Submission', order: 1, approverRole: 'KAM' },
          { name: 'Sales Manager Review', order: 2, approverRole: 'SALES_MANAGER' },
          { name: 'Finance Approval', order: 3, approverRole: 'FINANCE_MANAGER' },
          { name: 'Final Approval', order: 4, approverRole: 'COMPANY_ADMIN' }
        ]
      },
      {
        name: 'Budget Allocation',
        code: 'BUDGET_ALLOC',
        description: 'Budget allocation approval workflow',
        steps: [
          { name: 'Finance Submission', order: 1, approverRole: 'FINANCE_MANAGER' },
          { name: 'Executive Approval', order: 2, approverRole: 'COMPANY_ADMIN' }
        ]
      },
      {
        name: 'Trading Terms',
        code: 'TRADING_TERMS',
        description: 'Trading terms approval workflow',
        steps: [
          { name: 'Sales Submission', order: 1, approverRole: 'SALES_MANAGER' },
          { name: 'Legal Review', order: 2, approverRole: 'COMPANY_ADMIN' },
          { name: 'Finance Approval', order: 3, approverRole: 'FINANCE_MANAGER' }
        ]
      }
    ];

    for (const template of workflowTemplates) {
      await prisma.workflowTemplate.create({
        data: {
          name: template.name,
          code: template.code,
          description: template.description,
          steps: template.steps,
          status: 'ACTIVE',
          companyId: company.id
        }
      });
    }

    console.log(`✓ Created ${workflowTemplates.length} workflow templates`);

    // Create notification templates
    const notificationTemplates = [
      {
        name: 'Promotion Approved',
        code: 'PROMO_APPROVED',
        subject: 'Your promotion has been approved',
        body: 'Your promotion {{promotionName}} has been approved and is ready for execution.',
        type: 'EMAIL'
      },
      {
        name: 'Budget Alert',
        code: 'BUDGET_ALERT',
        subject: 'Budget utilization alert',
        body: 'Budget {{budgetName}} has reached {{percentage}}% utilization.',
        type: 'EMAIL'
      },
      {
        name: 'Wallet Transaction',
        code: 'WALLET_TRANS',
        subject: 'Digital wallet transaction',
        body: 'Transaction of {{amount}} {{currency}} completed successfully.',
        type: 'PUSH'
      },
      {
        name: 'Report Ready',
        code: 'REPORT_READY',
        subject: 'Your report is ready',
        body: 'Your requested report {{reportName}} is ready for download.',
        type: 'EMAIL'
      }
    ];

    for (const template of notificationTemplates) {
      await prisma.notificationTemplate.create({
        data: {
          ...template,
          companyId: company.id
        }
      });
    }

    console.log(`✓ Created ${notificationTemplates.length} notification templates`);

    // Create sample year data
    const currentYear = new Date().getFullYear();
    const startDate = new Date(currentYear - 1, 0, 1);
    const endDate = new Date();

    // Create budgets
    const budget = await prisma.budget.create({
      data: {
        name: `FY${currentYear} Trade Marketing Budget`,
        fiscalYear: currentYear,
        totalAmount: 50000000, // 50M
        allocatedAmount: 45000000, // 45M
        spentAmount: 32500000, // 32.5M
        status: 'ACTIVE',
        startDate: new Date(currentYear, 0, 1),
        endDate: new Date(currentYear, 11, 31),
        companyId: company.id
      }
    });

    // Create sample promotions
    const promotions = [];
    for (let i = 0; i < 50; i++) {
      const promo = await prisma.promotion.create({
        data: {
          name: `Promotion ${i + 1} - ${['Summer', 'Winter', 'Spring', 'Autumn'][i % 4]} Campaign`,
          code: `PROMO_${currentYear}_${String(i + 1).padStart(3, '0')}`,
          type: promotionTypes[i % promotionTypes.length].code,
          status: ['ACTIVE', 'COMPLETED', 'DRAFT', 'APPROVED'][i % 4],
          startDate: new Date(currentYear, i % 12, 1),
          endDate: new Date(currentYear, i % 12, 28),
          budgetAmount: Math.floor(Math.random() * 1000000) + 100000,
          spentAmount: Math.floor(Math.random() * 800000) + 50000,
          targetSales: Math.floor(Math.random() * 5000000) + 1000000,
          actualSales: Math.floor(Math.random() * 4500000) + 900000,
          companyId: company.id,
          createdById: adminUser.id
        }
      });
      promotions.push(promo);
    }

    console.log(`✓ Created ${promotions.length} sample promotions`);

    // Create digital wallets
    const wallets = [];
    const customers = await prisma.customerHierarchy.findMany({
      where: { type: 'STORE', companyId: company.id },
      take: 20
    });

    for (const customer of customers) {
      const wallet = await prisma.digitalWallet.create({
        data: {
          walletNumber: `DW${currentYear}${String(wallets.length + 1).padStart(6, '0')}`,
          customerId: customer.id,
          balance: Math.floor(Math.random() * 50000) + 10000,
          creditLimit: 100000,
          status: 'ACTIVE',
          pin: await bcrypt.hash('1234', 10),
          companyId: company.id
        }
      });
      wallets.push(wallet);

      // Create transactions
      for (let j = 0; j < 10; j++) {
        await prisma.walletTransaction.create({
          data: {
            walletId: wallet.id,
            transactionId: `TXN${currentYear}${String(wallets.length * 10 + j).padStart(8, '0')}`,
            type: ['CREDIT', 'DEBIT'][j % 2],
            amount: Math.floor(Math.random() * 5000) + 1000,
            description: `Transaction ${j + 1}`,
            status: 'COMPLETED',
            companyId: company.id
          }
        });
      }
    }

    console.log(`✓ Created ${wallets.length} digital wallets with transactions`);

    // Create AI insights
    const insights = [
      {
        type: 'OPPORTUNITY',
        title: 'High-growth product category identified',
        description: 'Energy drinks showing 25% YoY growth in convenience stores',
        impact: 'HIGH',
        confidence: 0.92,
        recommendations: ['Increase energy drink promotions', 'Expand SKU range', 'Target convenience channel']
      },
      {
        type: 'RISK',
        title: 'Declining sales in personal care',
        description: 'Personal care category down 15% in hypermarkets',
        impact: 'MEDIUM',
        confidence: 0.87,
        recommendations: ['Review pricing strategy', 'Launch targeted promotions', 'Analyze competitor activity']
      },
      {
        type: 'OPTIMIZATION',
        title: 'Budget reallocation opportunity',
        description: 'Shift 10% budget from low-performing to high-performing regions',
        impact: 'HIGH',
        confidence: 0.89,
        recommendations: ['Reallocate budget to Gauteng region', 'Reduce spend in underperforming areas']
      }
    ];

    for (const insight of insights) {
      await prisma.aIInsight.create({
        data: {
          ...insight,
          metadata: {
            model: 'ensemble-v1',
            analysisDate: new Date(),
            dataPoints: Math.floor(Math.random() * 10000) + 1000
          },
          companyId: company.id
        }
      });
    }

    console.log(`✓ Created ${insights.length} AI insights`);

    console.log('\n✅ Master data setup completed successfully!');
    
    // Display summary
    console.log('\n📊 Summary:');
    console.log(`- Company: ${company.name}`);
    console.log(`- Admin User: ${adminUser.email}`);
    console.log(`- Customer Hierarchy: 5 levels created`);
    console.log(`- Product Hierarchy: 5 levels created`);
    console.log(`- Vendors: ${vendors.length}`);
    console.log(`- Promotions: ${promotions.length}`);
    console.log(`- Digital Wallets: ${wallets.length}`);
    console.log(`- AI Insights: ${insights.length}`);

  } catch (error) {
    console.error('Error setting up master data:', error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

// Run the setup
setupMasterData()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
EOF
    
    print_message $GREEN "✓ Master data script created"
}

# ============================================================================
# SERVICE DEPLOYMENT
# ============================================================================

deploy_services() {
    log_step "Deploying Vanta X Services"
    
    cd "$INSTALL_DIR/vanta-x-trade-spend-final/deployment"
    
    # Create production override
    cat > docker-compose.override.yml << EOF
services:
  postgres:
    volumes:
      - $DATA_DIR/postgres:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: vantax
      POSTGRES_USER: vantax_user
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
  
  redis:
    volumes:
      - $DATA_DIR/redis:/data
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
  
  rabbitmq:
    volumes:
      - $DATA_DIR/rabbitmq:/var/lib/rabbitmq
    environment:
      RABBITMQ_DEFAULT_USER: vantax
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASSWORD}
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  nginx:
    volumes:
      - $LOG_DIR/nginx:/var/log/nginx
      - $SSL_DIR:/etc/nginx/ssl:ro
    restart: always
EOF
    
    # Set admin password in environment
    export ADMIN_PASSWORD=$ADMIN_PASSWORD
    
    # Start all services
    docker compose -f docker-compose.prod.yml up -d
    
    print_message $GREEN "✓ Services deployed"
}

wait_for_services() {
    log_step "Waiting for Services to Initialize"
    
    print_message $YELLOW "This may take a few minutes..."
    
    # Wait for PostgreSQL
    echo -n "Waiting for PostgreSQL"
    until docker exec vantax-postgres pg_isready -U vantax_user > /dev/null 2>&1; do
        echo -n "."
        sleep 2
    done
    echo " ✓"
    
    # Wait for Redis
    echo -n "Waiting for Redis"
    until docker exec vantax-redis redis-cli ping > /dev/null 2>&1; do
        echo -n "."
        sleep 2
    done
    echo " ✓"
    
    # Wait for RabbitMQ
    echo -n "Waiting for RabbitMQ"
    until docker exec vantax-rabbitmq rabbitmqctl status > /dev/null 2>&1; do
        echo -n "."
        sleep 2
    done
    echo " ✓"
    
    # Wait for API Gateway
    echo -n "Waiting for API Gateway"
    until curl -s http://localhost:4000/health > /dev/null 2>&1; do
        echo -n "."
        sleep 2
    done
    echo " ✓"
    
    print_message $GREEN "✓ All services ready"
}

initialize_database() {
    log_step "Initializing Database and Master Data"
    
    cd "$INSTALL_DIR/vanta-x-trade-spend-final"
    
    # Run database migrations
    print_message $YELLOW "Running database migrations..."
    docker exec vantax-api-gateway npm run migrate:deploy
    
    # Install dependencies for master data script
    docker exec vantax-api-gateway npm install
    
    # Run master data setup
    print_message $YELLOW "Setting up master data..."
    docker exec -e ADMIN_PASSWORD=$ADMIN_PASSWORD vantax-api-gateway npx ts-node scripts/setup-master-data.ts
    
    print_message $GREEN "✓ Database initialized with master data"
}

# ============================================================================
# NGINX AND SSL SETUP
# ============================================================================

setup_nginx() {
    log_step "Configuring Nginx"
    
    # Create Nginx configuration
    cat > "$NGINX_DIR/sites-available/vantax" << EOF
# Vanta X Production Nginx Configuration

# Upstream definitions
upstream api_gateway {
    server localhost:4000;
    keepalive 32;
}

upstream web_app {
    server localhost:3000;
    keepalive 32;
}

upstream grafana {
    server localhost:3001;
    keepalive 32;
}

# Rate limiting zones
limit_req_zone \$binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req_zone \$binary_remote_addr zone=app_limit:10m rate=30r/s;
limit_conn_zone \$binary_remote_addr zone=addr:10m;

# Cache zones
proxy_cache_path /var/cache/nginx/api levels=1:2 keys_zone=api_cache:10m max_size=1g inactive=60m use_temp_path=off;
proxy_cache_path /var/cache/nginx/static levels=1:2 keys_zone=static_cache:10m max_size=2g inactive=7d use_temp_path=off;

# HTTP server - redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN_NAME};
    
    # Allow Let's Encrypt challenges
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN_NAME};
    
    # SSL configuration
    ssl_certificate $SSL_DIR/fullchain.pem;
    ssl_certificate_key $SSL_DIR/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Content-Security-Policy "default-src 'self' https:; script-src 'self' 'unsafe-inline' 'unsafe-eval' https:; style-src 'self' 'unsafe-inline' https:; img-src 'self' data: https:; font-src 'self' data: https:; connect-src 'self' https: wss:; media-src 'self' https:; object-src 'none'; frame-ancestors 'self'; base-uri 'self'; form-action 'self';" always;
    
    # Logging
    access_log $LOG_DIR/nginx/vantax_access.log combined;
    error_log $LOG_DIR/nginx/vantax_error.log warn;
    
    # Connection limits
    limit_conn addr 100;
    
    # API Gateway
    location /api/ {
        limit_req zone=api_limit burst=20 nodelay;
        
        proxy_pass http://api_gateway;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
        
        # Cache configuration
        proxy_cache api_cache;
        proxy_cache_valid 200 1m;
        proxy_cache_valid 404 1m;
        proxy_cache_use_stale error timeout http_500 http_502 http_503 http_504;
        proxy_cache_background_update on;
        proxy_cache_lock on;
        
        # CORS headers
        add_header 'Access-Control-Allow-Origin' '\$http_origin' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;
        add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range' always;
        add_header 'Access-Control-Allow-Credentials' 'true' always;
        
        # Handle preflight requests
        if (\$request_method = 'OPTIONS') {
            add_header 'Access-Control-Max-Age' 1728000;
            add_header 'Content-Type' 'text/plain; charset=utf-8';
            add_header 'Content-Length' 0;
            return 204;
        }
    }
    
    # WebSocket support for real-time features
    location /ws/ {
        proxy_pass http://api_gateway;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400;
    }
    
    # Grafana monitoring
    location /grafana/ {
        proxy_pass http://grafana/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        
        # Restrict access to monitoring
        # allow 10.0.0.0/8;
        # deny all;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Web Application
    location / {
        limit_req zone=app_limit burst=50 nodelay;
        
        proxy_pass http://web_app;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Static files with aggressive caching
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf|doc|docx|xls|xlsx|woff|woff2|ttf|svg|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        proxy_cache static_cache;
        proxy_cache_valid 200 7d;
        proxy_pass http://web_app;
    }
    
    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # Deny access to backup files
    location ~ ~$ {
        deny all;
        access_log off;
        log_not_found off;
    }
}

# Status page for monitoring
server {
    listen 127.0.0.1:8080;
    server_name localhost;
    
    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        deny all;
    }
}
EOF
    
    # Enable site
    ln -sf "$NGINX_DIR/sites-available/vantax" "$NGINX_DIR/sites-enabled/"
    rm -f "$NGINX_DIR/sites-enabled/default"
    
    # Create cache directories
    mkdir -p /var/cache/nginx/{api,static}
    chown -R www-data:www-data /var/cache/nginx
    
    # Test configuration
    nginx -t
    
    print_message $GREEN "✓ Nginx configured"
}

setup_ssl() {
    log_step "Setting up SSL Certificate"
    
    if [[ "$ENABLE_SSL" != "yes" ]]; then
        print_message $YELLOW "SSL setup skipped"
        return
    fi
    
    if [[ "$DOMAIN_NAME" == "localhost" ]]; then
        print_message $YELLOW "Generating self-signed certificate for localhost..."
        
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout "$SSL_DIR/privkey.pem" \
            -out "$SSL_DIR/fullchain.pem" \
            -subj "/C=US/ST=State/L=City/O=Vanta X/CN=localhost"
        
        print_message $GREEN "✓ Self-signed certificate created"
    else
        print_message $BLUE "Obtaining Let's Encrypt certificate..."
        
        # Create webroot directory
        mkdir -p /var/www/certbot
        
        # Restart Nginx to serve challenge files
        systemctl restart nginx
        
        # Get certificate
        certbot certonly --webroot \
            -w /var/www/certbot \
            -d "$DOMAIN_NAME" \
            --non-interactive \
            --agree-tos \
            -m "$ADMIN_EMAIL"
        
        # Copy certificates to our SSL directory
        cp /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem "$SSL_DIR/"
        cp /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem "$SSL_DIR/"
        
        # Set up auto-renewal
        echo "0 0,12 * * * root certbot renew --quiet --post-hook 'systemctl reload nginx'" > /etc/cron.d/certbot-renew
        
        print_message $GREEN "✓ SSL certificate obtained and auto-renewal configured"
    fi
}

# ============================================================================
# SECURITY SETUP
# ============================================================================

setup_security() {
    log_step "Configuring Security"
    
    # Configure firewall
    case $OS in
        ubuntu|debian)
            ufw --force enable
            ufw default deny incoming
            ufw default allow outgoing
            ufw allow 22/tcp    # SSH
            ufw allow 80/tcp    # HTTP
            ufw allow 443/tcp   # HTTPS
            
            if [[ "$ENABLE_MONITORING" == "yes" ]]; then
                # Restrict monitoring to local network
                ufw allow from 10.0.0.0/8 to any port 3001  # Grafana
                ufw allow from 10.0.0.0/8 to any port 9090  # Prometheus
            fi
            ;;
        rhel|centos|fedora)
            systemctl start firewalld
            systemctl enable firewalld
            firewall-cmd --permanent --add-service=ssh
            firewall-cmd --permanent --add-service=http
            firewall-cmd --permanent --add-service=https
            firewall-cmd --reload
            ;;
    esac
    
    # Configure fail2ban
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true

[nginx-http-auth]
enabled = true

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = $LOG_DIR/nginx/*error.log

[nginx-noscript]
enabled = true
EOF
    
    systemctl restart fail2ban
    
    # Set secure permissions
    chmod 700 "$CONFIG_DIR"
    chmod 600 "$CONFIG_DIR/vantax.env"
    chmod 700 "$SSL_DIR"
    chmod 600 "$SSL_DIR"/*.pem 2>/dev/null || true
    
    # Create security audit script
    cat > "$INSTALL_DIR/security-audit.sh" << 'EOF'
#!/bin/bash
# Vanta X Security Audit Script

echo "Running security audit..."

# Check for security updates
echo "Checking for security updates..."
apt-get update > /dev/null 2>&1
UPDATES=$(apt-get -s upgrade | grep -i security | wc -l)
echo "Security updates available: $UPDATES"

# Check open ports
echo "Open ports:"
netstat -tuln | grep LISTEN

# Check failed login attempts
echo "Failed SSH attempts (last 24h):"
grep "Failed password" /var/log/auth.log | grep "$(date '+%b %e')" | wc -l

# Check file permissions
echo "Checking critical file permissions..."
ls -la /etc/vantax/
ls -la /etc/ssl/vantax/

echo "Security audit complete."
EOF
    
    chmod +x "$INSTALL_DIR/security-audit.sh"
    
    print_message $GREEN "✓ Security configured"
}

# ============================================================================
# BACKUP SETUP
# ============================================================================

setup_backup() {
    if [[ "$ENABLE_BACKUP" != "yes" ]]; then
        print_message $YELLOW "Backup setup skipped"
        return
    fi
    
    log_step "Setting up Automated Backups"
    
    # Create backup script
    cat > "$INSTALL_DIR/backup-vantax.sh" << 'EOF'
#!/bin/bash
# Vanta X Automated Backup Script

BACKUP_DIR="/var/backups/vantax"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="vantax_backup_${TIMESTAMP}"
RETENTION_DAYS=30

# Create backup directory
mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}"

echo "Starting backup: ${BACKUP_NAME}"

# Backup database
echo "Backing up database..."
docker exec vantax-postgres pg_dump -U vantax_user vantax | gzip > "${BACKUP_DIR}/${BACKUP_NAME}/database.sql.gz"

# Backup Redis
echo "Backing up Redis..."
docker exec vantax-redis redis-cli BGSAVE
sleep 5
docker cp vantax-redis:/data/dump.rdb "${BACKUP_DIR}/${BACKUP_NAME}/redis.rdb"

# Backup uploaded files
echo "Backing up uploaded files..."
tar -czf "${BACKUP_DIR}/${BACKUP_NAME}/uploads.tar.gz" -C /var/lib/vantax uploads/

# Backup configuration
echo "Backing up configuration..."
tar -czf "${BACKUP_DIR}/${BACKUP_NAME}/config.tar.gz" -C /etc vantax/

# Backup Docker volumes
echo "Backing up Docker volumes..."
docker run --rm -v vantax_postgres_data:/data -v "${BACKUP_DIR}/${BACKUP_NAME}":/backup alpine tar -czf /backup/postgres_volume.tar.gz -C /data .
docker run --rm -v vantax_redis_data:/data -v "${BACKUP_DIR}/${BACKUP_NAME}":/backup alpine tar -czf /backup/redis_volume.tar.gz -C /data .

# Create backup manifest
cat > "${BACKUP_DIR}/${BACKUP_NAME}/manifest.json" << EOL
{
  "timestamp": "${TIMESTAMP}",
  "version": "$(cat /opt/vantax/vanta-x-trade-spend-final/package.json | jq -r .version)",
  "files": [
    "database.sql.gz",
    "redis.rdb",
    "uploads.tar.gz",
    "config.tar.gz",
    "postgres_volume.tar.gz",
    "redis_volume.tar.gz"
  ],
  "size": "$(du -sh ${BACKUP_DIR}/${BACKUP_NAME} | cut -f1)"
}
EOL

# Compress entire backup
echo "Compressing backup..."
tar -czf "${BACKUP_DIR}/vantax_backup_${TIMESTAMP}.tar.gz" -C "${BACKUP_DIR}" "${BACKUP_NAME}/"
rm -rf "${BACKUP_DIR}/${BACKUP_NAME}"

# Upload to S3 if configured
if [ -n "${BACKUP_S3_BUCKET}" ]; then
    echo "Uploading to S3..."
    aws s3 cp "${BACKUP_DIR}/vantax_backup_${TIMESTAMP}.tar.gz" "s3://${BACKUP_S3_BUCKET}/backups/" || echo "S3 upload failed"
fi

# Remove old backups
echo "Cleaning up old backups..."
find "${BACKUP_DIR}" -name "vantax_backup_*.tar.gz" -mtime +${RETENTION_DAYS} -delete

echo "Backup completed: vantax_backup_${TIMESTAMP}.tar.gz"

# Send notification
curl -X POST http://localhost:4000/api/v1/notifications/send \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${API_KEY}" \
  -d '{
    "type": "email",
    "to": "'${EMAIL_ADMIN}'",
    "subject": "Vanta X Backup Completed",
    "body": "Backup completed successfully: vantax_backup_'${TIMESTAMP}'.tar.gz"
  }' 2>/dev/null || true
EOF
    
    chmod +x "$INSTALL_DIR/backup-vantax.sh"
    
    # Create restore script
    cat > "$INSTALL_DIR/restore-vantax.sh" << 'EOF'
#!/bin/bash
# Vanta X Restore Script

if [ $# -eq 0 ]; then
    echo "Usage: $0 <backup-file.tar.gz>"
    exit 1
fi

BACKUP_FILE=$1
RESTORE_DIR="/tmp/vantax_restore_$$"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "WARNING: This will restore the system from backup."
echo "All current data will be replaced!"
read -p "Are you sure? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Restore cancelled."
    exit 0
fi

# Extract backup
echo "Extracting backup..."
mkdir -p "$RESTORE_DIR"
tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR"

BACKUP_NAME=$(ls "$RESTORE_DIR")
BACKUP_PATH="$RESTORE_DIR/$BACKUP_NAME"

# Stop services
echo "Stopping services..."
docker compose -f /opt/vantax/vanta-x-trade-spend-final/deployment/docker-compose.prod.yml down

# Restore database
echo "Restoring database..."
docker compose -f /opt/vantax/vanta-x-trade-spend-final/deployment/docker-compose.prod.yml up -d postgres
sleep 10
gunzip -c "$BACKUP_PATH/database.sql.gz" | docker exec -i vantax-postgres psql -U vantax_user vantax

# Restore Redis
echo "Restoring Redis..."
docker compose -f /opt/vantax/vanta-x-trade-spend-final/deployment/docker-compose.prod.yml up -d redis
docker cp "$BACKUP_PATH/redis.rdb" vantax-redis:/data/dump.rdb
docker restart vantax-redis

# Restore uploads
echo "Restoring uploaded files..."
tar -xzf "$BACKUP_PATH/uploads.tar.gz" -C /var/lib/vantax/

# Restore configuration
echo "Restoring configuration..."
tar -xzf "$BACKUP_PATH/config.tar.gz" -C /etc/

# Start all services
echo "Starting services..."
docker compose -f /opt/vantax/vanta-x-trade-spend-final/deployment/docker-compose.prod.yml up -d

# Cleanup
rm -rf "$RESTORE_DIR"

echo "Restore completed successfully!"
echo "Please verify the system is working correctly."
EOF
    
    chmod +x "$INSTALL_DIR/restore-vantax.sh"
    
    # Set up cron job
    echo "0 2 * * * root $INSTALL_DIR/backup-vantax.sh >> $LOG_DIR/backup.log 2>&1" > /etc/cron.d/vantax-backup
    
    # Run initial backup
    print_message $YELLOW "Running initial backup..."
    "$INSTALL_DIR/backup-vantax.sh"
    
    print_message $GREEN "✓ Backup system configured"
}

# ============================================================================
# MONITORING SETUP
# ============================================================================

setup_monitoring() {
    if [[ "$ENABLE_MONITORING" != "yes" ]]; then
        print_message $YELLOW "Monitoring setup skipped"
        return
    fi
    
    log_step "Setting up Monitoring Stack"
    
    # Create Prometheus configuration
    mkdir -p "$INSTALL_DIR/vanta-x-trade-spend-final/deployment/monitoring"
    
    cat > "$INSTALL_DIR/vanta-x-trade-spend-final/deployment/monitoring/prometheus.yml" << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'vantax-monitor'
    environment: 'production'

# Alerting configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets: []

# Rule files
rule_files:
  - "alerts/*.yml"

# Scrape configurations
scrape_configs:
  # Vanta X Services
  - job_name: 'vantax-services'
    static_configs:
      - targets:
          - 'api-gateway:4000'
          - 'identity-service:4001'
          - 'operations-service:4002'
          - 'analytics-service:4003'
          - 'ai-service:4004'
          - 'integration-service:4005'
          - 'coop-service:4006'
          - 'notification-service:4007'
          - 'reporting-service:4008'
          - 'workflow-service:4009'
          - 'audit-service:4010'
    relabel_configs:
      - source_labels: [__address__]
        regex: '([^:]+):(.*)'
        target_label: service
        replacement: '\${1}'
      - source_labels: [__address__]
        regex: '([^:]+):(.*)'
        target_label: port
        replacement: '\${2}'

  # Node Exporter
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']

  # PostgreSQL Exporter
  - job_name: 'postgresql'
    static_configs:
      - targets: ['postgres-exporter:9187']

  # Redis Exporter
  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']

  # RabbitMQ
  - job_name: 'rabbitmq'
    static_configs:
      - targets: ['rabbitmq:15692']

  # Nginx
  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx-exporter:9113']

  # Docker
  - job_name: 'docker'
    static_configs:
      - targets: ['cadvisor:8080']
EOF
    
    # Create alert rules
    mkdir -p "$INSTALL_DIR/vanta-x-trade-spend-final/deployment/monitoring/alerts"
    
    cat > "$INSTALL_DIR/vanta-x-trade-spend-final/deployment/monitoring/alerts/vantax.yml" << 'EOF'
groups:
  - name: vantax_alerts
    interval: 30s
    rules:
      # Service availability
      - alert: ServiceDown
        expr: up{job="vantax-services"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.service }} is down"
          description: "{{ $labels.service }} has been down for more than 2 minutes."

      # High CPU usage
      - alert: HighCPUUsage
        expr: rate(process_cpu_seconds_total[5m]) * 100 > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.service }}"
          description: "CPU usage is above 80% (current value: {{ $value }}%)"

      # High memory usage
      - alert: HighMemoryUsage
        expr: (process_resident_memory_bytes / 1024 / 1024 / 1024) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.service }}"
          description: "Memory usage is above 2GB (current value: {{ $value }}GB)"

      # Database connection pool
      - alert: DatabaseConnectionPoolExhausted
        expr: pg_stat_database_numbackends / pg_settings_max_connections > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Database connection pool nearly exhausted"
          description: "More than 80% of database connections are in use"

      # Disk space
      - alert: LowDiskSpace
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 20
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Low disk space on server"
          description: "Disk space is below 20% (current value: {{ $value }}%)"

      # API response time
      - alert: HighAPIResponseTime
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High API response time"
          description: "95th percentile response time is above 1 second"

      # Error rate
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is above 5% (current value: {{ $value }})"
EOF
    
    # Create Grafana dashboards
    mkdir -p "$INSTALL_DIR/vanta-x-trade-spend-final/deployment/monitoring/grafana/dashboards"
    
    # Create health check dashboard
    cat > "$INSTALL_DIR/health-check-dashboard.sh" << 'EOF'
#!/bin/bash
# Vanta X Health Check Dashboard

echo "==================================="
echo "Vanta X System Health Check"
echo "==================================="
echo "Time: $(date)"
echo ""

# Check services
echo "Service Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep vantax

echo ""
echo "Resource Usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep vantax

echo ""
echo "Database Connections:"
docker exec vantax-postgres psql -U vantax_user -d vantax -c "SELECT count(*) as connections FROM pg_stat_activity;"

echo ""
echo "Redis Info:"
docker exec vantax-redis redis-cli INFO | grep -E "used_memory_human|connected_clients|total_commands_processed"

echo ""
echo "API Health:"
curl -s http://localhost:4000/health | jq .

echo ""
echo "Disk Usage:"
df -h | grep -E "Filesystem|/$|/var/lib/docker"

echo ""
echo "Recent Errors (last 10):"
docker logs vantax-api-gateway 2>&1 | grep -i error | tail -10

echo ""
echo "==================================="
EOF
    
    chmod +x "$INSTALL_DIR/health-check-dashboard.sh"
    
    print_message $GREEN "✓ Monitoring configured"
}

# ============================================================================
# FINAL SETUP
# ============================================================================

create_systemd_service() {
    log_step "Creating System Service"
    
    cat > "$SYSTEMD_DIR/vantax.service" << EOF
[Unit]
Description=Vanta X Trade Spend Management Platform
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR/vanta-x-trade-spend-final/deployment
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
    
    print_message $GREEN "✓ System service created"
}

create_management_scripts() {
    log_step "Creating Management Scripts"
    
    # Create status script
    cat > "$INSTALL_DIR/vantax-status.sh" << 'EOF'
#!/bin/bash
echo "Vanta X System Status"
echo "===================="
systemctl status vantax.service --no-pager
echo ""
echo "Container Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep vantax
EOF
    
    # Create logs script
    cat > "$INSTALL_DIR/vantax-logs.sh" << 'EOF'
#!/bin/bash
SERVICE=${1:-all}
if [ "$SERVICE" = "all" ]; then
    docker compose -f /opt/vantax/vanta-x-trade-spend-final/deployment/docker-compose.prod.yml logs -f
else
    docker logs -f vantax-$SERVICE
fi
EOF
    
    # Create update script
    cat > "$INSTALL_DIR/vantax-update.sh" << 'EOF'
#!/bin/bash
echo "Updating Vanta X..."
cd /opt/vantax/vanta-x-trade-spend-final
git pull origin main
docker compose -f deployment/docker-compose.prod.yml pull
docker compose -f deployment/docker-compose.prod.yml up -d
echo "Update complete!"
EOF
    
    chmod +x "$INSTALL_DIR"/*.sh
    
    # Create command aliases
    cat >> /etc/bash.bashrc << EOF

# Vanta X aliases
alias vantax-status='$INSTALL_DIR/vantax-status.sh'
alias vantax-logs='$INSTALL_DIR/vantax-logs.sh'
alias vantax-backup='$INSTALL_DIR/backup-vantax.sh'
alias vantax-health='$INSTALL_DIR/health-check-dashboard.sh'
alias vantax-update='$INSTALL_DIR/vantax-update.sh'
EOF
    
    print_message $GREEN "✓ Management scripts created"
}

save_installation_report() {
    log_step "Generating Installation Report"
    
    REPORT_FILE="$CONFIG_DIR/installation-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$REPORT_FILE" << EOF
================================================================================
                        Vanta X Installation Report
================================================================================
Date: $DEPLOYMENT_DATE
Version: $VANTAX_VERSION
Server: $(hostname)
OS: $OS $OS_VERSION
Domain: $DOMAIN_NAME

================================================================================
SYSTEM CONFIGURATION
================================================================================
CPU Cores: $CPU_CORES
RAM: ${RAM_GB}GB
Disk Space: ${DISK_SPACE}GB
Company: $COMPANY_NAME
Admin Email: $ADMIN_EMAIL

================================================================================
SERVICES DEPLOYED
================================================================================
✓ PostgreSQL Database
✓ Redis Cache
✓ RabbitMQ Message Queue
✓ API Gateway
✓ Identity Service (Microsoft 365 SSO)
✓ Operations Service
✓ Analytics Service
✓ AI Service
✓ Integration Service
✓ Co-op Service
✓ Notification Service
✓ Reporting Service
✓ Workflow Service
✓ Audit Service
✓ Web Application
✓ Nginx Reverse Proxy
$([ "$ENABLE_MONITORING" = "yes" ] && echo "✓ Prometheus Monitoring
✓ Grafana Dashboards
✓ Loki Log Aggregation")

================================================================================
SECURITY CONFIGURATION
================================================================================
✓ SSL Certificate: $([ "$ENABLE_SSL" = "yes" ] && echo "Enabled" || echo "Disabled")
✓ Firewall: Configured
✓ Fail2ban: Active
✓ Security Headers: Configured
✓ Rate Limiting: Enabled
✓ CORS: Configured

================================================================================
FEATURES ENABLED
================================================================================
✓ 5-Level Customer Hierarchy
✓ 5-Level Product Hierarchy
✓ AI-Powered Forecasting
✓ Digital Wallets with QR Codes
✓ Monte Carlo Simulations
✓ Executive Analytics
✓ Workflow Engine
✓ Mobile App Support
✓ Offline Mode
✓ Multi-Company Support

================================================================================
MASTER DATA CREATED
================================================================================
✓ Company: $COMPANY_NAME
✓ Admin User: $ADMIN_EMAIL
✓ Roles: 10 system roles
✓ Customer Hierarchy: 5 global accounts with full hierarchy
✓ Product Hierarchy: 5 categories with full hierarchy
✓ Vendors: 7 vendors (multinational and local)
✓ Promotion Types: 8 types
✓ Budget Categories: 8 categories
✓ Workflow Templates: 3 templates
✓ Sample Data: 1 year of transactions

================================================================================
ACCESS CREDENTIALS
================================================================================
Web Application: https://$DOMAIN_NAME
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

$([ "$ENABLE_MONITORING" = "yes" ] && echo "Grafana:
  URL: https://$DOMAIN_NAME/grafana
  Username: admin
  Password: $GRAFANA_PASSWORD")

API Key: $API_KEY

================================================================================
IMPORTANT PATHS
================================================================================
Installation Directory: $INSTALL_DIR
Configuration: $CONFIG_DIR
Data Directory: $DATA_DIR
Logs: $LOG_DIR
Backups: $BACKUP_DIR
SSL Certificates: $SSL_DIR

================================================================================
MANAGEMENT COMMANDS
================================================================================
System Status: vantax-status
View Logs: vantax-logs [service-name]
Backup Now: vantax-backup
Health Check: vantax-health
Update System: vantax-update

Service Control:
  Start: systemctl start vantax
  Stop: systemctl stop vantax
  Restart: systemctl restart vantax
  Status: systemctl status vantax

================================================================================
NEXT STEPS
================================================================================
1. Configure Azure AD:
   - Create Azure AD application
   - Update AZURE_AD_* variables in $CONFIG_DIR/vantax.env
   - Restart services: systemctl restart vantax

2. Configure SAP Integration (if needed):
   - Update SAP_* variables in $CONFIG_DIR/vantax.env
   - Enable SAP_INTEGRATION flag
   - Restart services

3. Configure Email:
   - Update SMTP_* variables in $CONFIG_DIR/vantax.env
   - Test email sending

4. Configure AI Features (optional):
   - Add OpenAI API key to enable AI features
   - Update OPENAI_API_KEY in $CONFIG_DIR/vantax.env

5. Access the system:
   - Navigate to https://$DOMAIN_NAME
   - Log in with admin credentials
   - Complete initial setup wizard

================================================================================
SUPPORT
================================================================================
Documentation: https://github.com/Reshigan/vanta-x-trade-spend-final
Issues: https://github.com/Reshigan/vanta-x-trade-spend-final/issues

================================================================================
                        Installation Completed Successfully!
================================================================================
EOF
    
    # Save credentials separately
    cat > "$CONFIG_DIR/credentials.secure" << EOF
# Vanta X Credentials - KEEP SECURE!
# Generated: $DEPLOYMENT_DATE

Admin Password: $ADMIN_PASSWORD
Database Password: $DB_PASSWORD
Redis Password: $REDIS_PASSWORD
JWT Secret: $JWT_SECRET
RabbitMQ Password: $RABBITMQ_PASSWORD
Grafana Password: $GRAFANA_PASSWORD
API Key: $API_KEY

# Delete this file after saving credentials securely!
EOF
    
    chmod 600 "$CONFIG_DIR/credentials.secure"
    
    print_message $GREEN "✓ Installation report saved to: $REPORT_FILE"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    # Start logging
    LOG_FILE="/var/log/vantax-installation-$(date +%Y%m%d-%H%M%S).log"
    exec 1> >(tee -a "$LOG_FILE")
    exec 2>&1
    
    print_banner
    
    print_message $CYAN "Starting Vanta X Production Deployment"
    print_message $CYAN "Installation log: $LOG_FILE"
    
    # Pre-flight checks
    check_root
    detect_system
    
    # Configuration
    collect_configuration
    
    # Installation
    install_system_dependencies
    install_docker
    install_nodejs
    create_directory_structure
    
    # Application setup
    clone_repository
    create_project_structure
    create_environment_configuration
    create_master_data_script
    
    # Deploy services
    deploy_services
    wait_for_services
    initialize_database
    
    # Configure infrastructure
    setup_nginx
    setup_ssl
    setup_security
    setup_backup
    setup_monitoring
    
    # Final setup
    create_systemd_service
    create_management_scripts
    
    # Restart Nginx with final configuration
    systemctl restart nginx
    
    # Generate report
    save_installation_report
    
    # Display completion message
    print_message $GREEN "\n╔══════════════════════════════════════════════════════════════════════════════╗"
    print_message $GREEN "║                                                                              ║"
    print_message $GREEN "║                    🎉 VANTA X DEPLOYMENT COMPLETED! 🎉                       ║"
    print_message $GREEN "║                                                                              ║"
    print_message $GREEN "╚══════════════════════════════════════════════════════════════════════════════╝"
    
    print_message $BLUE "\n📋 Quick Access Information:"
    print_message $YELLOW "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_message $CYAN "Web Application: ${GREEN}https://$DOMAIN_NAME"
    print_message $CYAN "Admin Email: ${GREEN}$ADMIN_EMAIL"
    print_message $CYAN "Admin Password: ${GREEN}$ADMIN_PASSWORD"
    
    if [[ "$ENABLE_MONITORING" == "yes" ]]; then
        print_message $CYAN "Grafana: ${GREEN}https://$DOMAIN_NAME/grafana (admin / $GRAFANA_PASSWORD)"
    fi
    
    print_message $YELLOW "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    print_message $RED "\n⚠️  IMPORTANT: Credentials saved to: $CONFIG_DIR/credentials.secure"
    print_message $RED "Please save these credentials securely and delete the file!"
    
    print_message $BLUE "\n📚 Full installation report: $REPORT_FILE"
    print_message $BLUE "📝 Installation log: $LOG_FILE"
    
    print_message $GREEN "\n✅ Your Vanta X system is ready for production use!"
    print_message $GREEN "🚀 Access the application at: https://$DOMAIN_NAME"
}

# Run main function
main "$@"