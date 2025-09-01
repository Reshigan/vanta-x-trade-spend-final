#!/bin/bash

# Vanta X - FMCG Trade Marketing Management Platform
# Automated Installation and Setup Script
# Supports: Ubuntu 20.04+, Debian 11+, RHEL 8+, CentOS 8+

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/vantax"
DATA_DIR="/var/lib/vantax"
LOG_DIR="/var/log/vantax"
CONFIG_DIR="/etc/vantax"
SYSTEMD_DIR="/etc/systemd/system"
NGINX_DIR="/etc/nginx"
SSL_DIR="/etc/ssl/vantax"

# Version requirements
MIN_DOCKER_VERSION="20.10.0"
MIN_DOCKER_COMPOSE_VERSION="2.0.0"
MIN_NODE_VERSION="18.0.0"
MIN_POSTGRES_VERSION="14"

# Default values
DOMAIN_NAME=""
ENABLE_SSL="yes"
ENABLE_MONITORING="yes"
ENABLE_BACKUP="yes"
INSTALL_MODE="production"
DB_PASSWORD=""
REDIS_PASSWORD=""
JWT_SECRET=""
ADMIN_EMAIL=""

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print banner
print_banner() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║     Vanta X - FMCG Trade Marketing Management Platform          ║"
    echo "║                  Automated Installation Script                   ║"
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_message $RED "Error: This script must be run as root"
        exit 1
    fi
}

# Function to detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        print_message $RED "Error: Cannot detect OS. This script requires a modern Linux distribution."
        exit 1
    fi
    
    print_message $GREEN "Detected OS: $OS $OS_VERSION"
}

# Function to check system requirements
check_system_requirements() {
    print_message $BLUE "\nChecking system requirements..."
    
    # Check CPU cores
    CPU_CORES=$(nproc)
    if [[ $CPU_CORES -lt 4 ]]; then
        print_message $YELLOW "Warning: System has only $CPU_CORES CPU cores. Recommended: 4+ cores"
    else
        print_message $GREEN "✓ CPU cores: $CPU_CORES"
    fi
    
    # Check RAM
    RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $RAM_GB -lt 8 ]]; then
        print_message $RED "Error: System has only ${RAM_GB}GB RAM. Minimum required: 8GB"
        exit 1
    else
        print_message $GREEN "✓ RAM: ${RAM_GB}GB"
    fi
    
    # Check disk space
    DISK_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ $DISK_SPACE -lt 50 ]]; then
        print_message $RED "Error: Only ${DISK_SPACE}GB free disk space. Minimum required: 50GB"
        exit 1
    else
        print_message $GREEN "✓ Free disk space: ${DISK_SPACE}GB"
    fi
}

# Function to install dependencies
install_dependencies() {
    print_message $BLUE "\nInstalling system dependencies..."
    
    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y \
                curl \
                wget \
                git \
                gnupg \
                lsb-release \
                ca-certificates \
                apt-transport-https \
                software-properties-common \
                python3 \
                python3-pip \
                jq \
                htop \
                net-tools \
                ufw \
                fail2ban
            ;;
        rhel|centos|fedora)
            yum install -y epel-release
            yum install -y \
                curl \
                wget \
                git \
                gnupg \
                ca-certificates \
                python3 \
                python3-pip \
                jq \
                htop \
                net-tools \
                firewalld \
                fail2ban
            ;;
        *)
            print_message $RED "Error: Unsupported OS"
            exit 1
            ;;
    esac
    
    print_message $GREEN "✓ System dependencies installed"
}

# Function to install Docker
install_docker() {
    print_message $BLUE "\nInstalling Docker..."
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
        print_message $GREEN "✓ Docker already installed: $DOCKER_VERSION"
        return
    fi
    
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
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    print_message $GREEN "✓ Docker installed and started"
}

# Function to install Node.js
install_nodejs() {
    print_message $BLUE "\nInstalling Node.js..."
    
    # Check if Node.js is already installed
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version | sed 's/v//')
        print_message $GREEN "✓ Node.js already installed: $NODE_VERSION"
        return
    fi
    
    # Install Node.js 18.x
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
    
    # Install global packages
    npm install -g pm2 typescript
    
    print_message $GREEN "✓ Node.js installed"
}

# Function to install Nginx
install_nginx() {
    print_message $BLUE "\nInstalling Nginx..."
    
    case $OS in
        ubuntu|debian)
            apt-get install -y nginx certbot python3-certbot-nginx
            ;;
        rhel|centos|fedora)
            yum install -y nginx certbot python3-certbot-nginx
            ;;
    esac
    
    systemctl start nginx
    systemctl enable nginx
    
    print_message $GREEN "✓ Nginx installed and started"
}

# Function to setup firewall
setup_firewall() {
    print_message $BLUE "\nConfiguring firewall..."
    
    case $OS in
        ubuntu|debian)
            ufw --force enable
            ufw allow 22/tcp    # SSH
            ufw allow 80/tcp    # HTTP
            ufw allow 443/tcp   # HTTPS
            ufw allow 3000/tcp  # Web app (dev)
            ufw allow 4000/tcp  # API Gateway
            ufw allow 9090/tcp  # Prometheus
            ufw allow 3001/tcp  # Grafana
            ;;
        rhel|centos|fedora)
            systemctl start firewalld
            systemctl enable firewalld
            firewall-cmd --permanent --add-service=ssh
            firewall-cmd --permanent --add-service=http
            firewall-cmd --permanent --add-service=https
            firewall-cmd --permanent --add-port=3000/tcp
            firewall-cmd --permanent --add-port=4000/tcp
            firewall-cmd --permanent --add-port=9090/tcp
            firewall-cmd --permanent --add-port=3001/tcp
            firewall-cmd --reload
            ;;
    esac
    
    print_message $GREEN "✓ Firewall configured"
}

# Function to generate secure passwords
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Function to collect user input
collect_user_input() {
    print_message $BLUE "\nConfiguration Setup"
    print_message $YELLOW "Please provide the following information:"
    
    # Domain name
    read -p "Enter domain name (e.g., vantax.company.com): " DOMAIN_NAME
    if [[ -z "$DOMAIN_NAME" ]]; then
        DOMAIN_NAME="localhost"
        print_message $YELLOW "Using default: localhost"
    fi
    
    # Admin email
    read -p "Enter admin email address: " ADMIN_EMAIL
    if [[ -z "$ADMIN_EMAIL" ]]; then
        print_message $RED "Error: Admin email is required"
        exit 1
    fi
    
    # SSL Certificate
    read -p "Enable SSL certificate? (yes/no) [yes]: " ENABLE_SSL
    ENABLE_SSL=${ENABLE_SSL:-yes}
    
    # Monitoring
    read -p "Enable monitoring (Prometheus/Grafana)? (yes/no) [yes]: " ENABLE_MONITORING
    ENABLE_MONITORING=${ENABLE_MONITORING:-yes}
    
    # Backup
    read -p "Enable automated backups? (yes/no) [yes]: " ENABLE_BACKUP
    ENABLE_BACKUP=${ENABLE_BACKUP:-yes}
    
    # Generate passwords
    print_message $BLUE "\nGenerating secure passwords..."
    DB_PASSWORD=$(generate_password)
    REDIS_PASSWORD=$(generate_password)
    JWT_SECRET=$(generate_password)
    RABBITMQ_PASSWORD=$(generate_password)
    GRAFANA_PASSWORD=$(generate_password)
    
    print_message $GREEN "✓ Configuration collected"
}

# Function to create directory structure
create_directories() {
    print_message $BLUE "\nCreating directory structure..."
    
    mkdir -p $INSTALL_DIR
    mkdir -p $DATA_DIR/{postgres,redis,rabbitmq,uploads,backups}
    mkdir -p $LOG_DIR/{nginx,app,system}
    mkdir -p $CONFIG_DIR
    mkdir -p $SSL_DIR
    
    # Set permissions
    chmod 755 $INSTALL_DIR
    chmod 755 $DATA_DIR
    chmod 755 $LOG_DIR
    chmod 700 $CONFIG_DIR
    chmod 700 $SSL_DIR
    
    print_message $GREEN "✓ Directories created"
}

# Function to clone repository
clone_repository() {
    print_message $BLUE "\nCloning Vanta X repository..."
    
    cd $INSTALL_DIR
    
    if [[ -d "vanta-x-trade-spend-final" ]]; then
        print_message $YELLOW "Repository already exists. Pulling latest changes..."
        cd vanta-x-trade-spend-final
        git pull origin main
    else
        git clone https://github.com/Reshigan/vanta-x-trade-spend-final.git
        cd vanta-x-trade-spend-final
    fi
    
    print_message $GREEN "✓ Repository cloned"
}

# Function to create environment file
create_env_file() {
    print_message $BLUE "\nCreating environment configuration..."
    
    cat > $CONFIG_DIR/vantax.env << EOF
# Vanta X Environment Configuration
# Generated on $(date)

# Application
NODE_ENV=production
APP_NAME="Vanta X - Trade Spend Management"
APP_URL=https://${DOMAIN_NAME}
API_URL=https://${DOMAIN_NAME}/api

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

# JWT
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRES_IN=7d
REFRESH_TOKEN_EXPIRES_IN=30d

# Azure AD (Configure these with your Azure AD app)
AZURE_AD_CLIENT_ID=your-client-id
AZURE_AD_CLIENT_SECRET=your-client-secret
AZURE_AD_TENANT_ID=your-tenant-id
AZURE_AD_REDIRECT_URI=https://${DOMAIN_NAME}/auth/callback

# OpenAI (Configure for AI features)
OPENAI_API_KEY=your-openai-api-key

# SAP Integration (Configure for SAP connection)
SAP_BASE_URL=https://your-sap-system.com
SAP_CLIENT_ID=your-sap-client
SAP_CLIENT_SECRET=your-sap-secret

# Email
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=${ADMIN_EMAIL}
SMTP_PASSWORD=your-smtp-password
EMAIL_FROM="Vanta X <noreply@${DOMAIN_NAME}>"

# Monitoring
GRAFANA_USER=admin
GRAFANA_PASSWORD=${GRAFANA_PASSWORD}

# Backup
BACKUP_ENABLED=${ENABLE_BACKUP}
BACKUP_RETENTION_DAYS=30
BACKUP_S3_BUCKET=vantax-backups
BACKUP_S3_REGION=us-east-1

# Security
CORS_ORIGIN=https://${DOMAIN_NAME}
RATE_LIMIT_WINDOW=15
RATE_LIMIT_MAX=100
SESSION_SECRET=${JWT_SECRET}

# Feature Flags
ENABLE_AI_FEATURES=true
ENABLE_MOBILE_APP=true
ENABLE_MONITORING=${ENABLE_MONITORING}
ENABLE_AUDIT_LOG=true
EOF
    
    # Create Docker Compose override
    ln -sf $CONFIG_DIR/vantax.env $INSTALL_DIR/vanta-x-trade-spend-final/.env
    
    print_message $GREEN "✓ Environment configuration created"
}

# Function to setup Nginx
setup_nginx() {
    print_message $BLUE "\nConfiguring Nginx..."
    
    # Create Nginx configuration
    cat > $NGINX_DIR/sites-available/vantax << EOF
# Vanta X Nginx Configuration

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

# Rate limiting
limit_req_zone \$binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req_zone \$binary_remote_addr zone=app_limit:10m rate=30r/s;

# HTTP redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN_NAME};
    
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
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
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Logging
    access_log $LOG_DIR/nginx/vantax_access.log;
    error_log $LOG_DIR/nginx/vantax_error.log;
    
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
        
        # CORS headers
        add_header 'Access-Control-Allow-Origin' '\$http_origin' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;
        add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range' always;
    }
    
    # Grafana
    location /grafana/ {
        proxy_pass http://grafana/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
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
    
    # Static files
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|pdf|doc|docx|xls|xlsx)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Deny access to hidden files
    location ~ /\. {
        deny all;
    }
}
EOF
    
    # Enable site
    ln -sf $NGINX_DIR/sites-available/vantax $NGINX_DIR/sites-enabled/
    
    # Test Nginx configuration
    nginx -t
    
    print_message $GREEN "✓ Nginx configured"
}

# Function to setup SSL
setup_ssl() {
    if [[ "$ENABLE_SSL" != "yes" ]]; then
        print_message $YELLOW "Skipping SSL setup"
        return
    fi
    
    print_message $BLUE "\nSetting up SSL certificate..."
    
    if [[ "$DOMAIN_NAME" == "localhost" ]]; then
        print_message $YELLOW "Generating self-signed certificate for localhost..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout $SSL_DIR/privkey.pem \
            -out $SSL_DIR/fullchain.pem \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
    else
        print_message $BLUE "Obtaining Let's Encrypt certificate..."
        certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos -m $ADMIN_EMAIL
    fi
    
    print_message $GREEN "✓ SSL configured"
}

# Function to build and start services
start_services() {
    print_message $BLUE "\nStarting Vanta X services..."
    
    cd $INSTALL_DIR/vanta-x-trade-spend-final/deployment
    
    # Create docker-compose override for production
    cat > docker-compose.override.yml << EOF
version: '3.8'

services:
  postgres:
    volumes:
      - $DATA_DIR/postgres:/var/lib/postgresql/data
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
  
  redis:
    volumes:
      - $DATA_DIR/redis:/data
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
  
  rabbitmq:
    volumes:
      - $DATA_DIR/rabbitmq:/var/lib/rabbitmq
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
EOF
    
    # Start services
    docker compose -f docker-compose.prod.yml up -d
    
    print_message $GREEN "✓ Services started"
}

# Function to initialize database
initialize_database() {
    print_message $BLUE "\nInitializing database..."
    
    # Wait for database to be ready
    sleep 10
    
    cd $INSTALL_DIR/vanta-x-trade-spend-final
    
    # Run migrations
    docker exec vantax-api-gateway npm run migrate:deploy
    
    # Seed initial data
    docker exec vantax-api-gateway npm run seed:prod
    
    print_message $GREEN "✓ Database initialized"
}

# Function to setup monitoring
setup_monitoring() {
    if [[ "$ENABLE_MONITORING" != "yes" ]]; then
        print_message $YELLOW "Skipping monitoring setup"
        return
    fi
    
    print_message $BLUE "\nSetting up monitoring..."
    
    # Create Prometheus configuration
    mkdir -p $INSTALL_DIR/vanta-x-trade-spend-final/deployment/monitoring
    
    cat > $INSTALL_DIR/vanta-x-trade-spend-final/deployment/monitoring/prometheus.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'vantax-services'
    static_configs:
      - targets:
          - 'api-gateway:4000'
          - 'identity-service:3001'
          - 'operations-service:3002'
          - 'analytics-service:3003'
          - 'ai-service:3004'
          - 'integration-service:3005'
          - 'coop-service:3006'
          - 'notification-service:3007'
          - 'reporting-service:3008'
          - 'workflow-service:3009'
          - 'audit-service:3010'
  
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
  
  - job_name: 'postgres-exporter'
    static_configs:
      - targets: ['postgres-exporter:9187']
  
  - job_name: 'redis-exporter'
    static_configs:
      - targets: ['redis-exporter:9121']
EOF
    
    print_message $GREEN "✓ Monitoring configured"
}

# Function to setup backup
setup_backup() {
    if [[ "$ENABLE_BACKUP" != "yes" ]]; then
        print_message $YELLOW "Skipping backup setup"
        return
    fi
    
    print_message $BLUE "\nSetting up automated backups..."
    
    # Create backup script
    cat > $INSTALL_DIR/backup.sh << 'EOF'
#!/bin/bash

# Vanta X Backup Script

BACKUP_DIR="/var/lib/vantax/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="vantax_backup_${TIMESTAMP}"

# Create backup directory
mkdir -p ${BACKUP_DIR}/${BACKUP_NAME}

# Backup database
docker exec vantax-postgres pg_dump -U vantax_user vantax | gzip > ${BACKUP_DIR}/${BACKUP_NAME}/database.sql.gz

# Backup Redis
docker exec vantax-redis redis-cli --rdb ${BACKUP_DIR}/${BACKUP_NAME}/redis.rdb

# Backup uploaded files
tar -czf ${BACKUP_DIR}/${BACKUP_NAME}/uploads.tar.gz -C /var/lib/vantax uploads/

# Backup configuration
tar -czf ${BACKUP_DIR}/${BACKUP_NAME}/config.tar.gz -C /etc vantax/

# Create backup manifest
cat > ${BACKUP_DIR}/${BACKUP_NAME}/manifest.json << EOL
{
  "timestamp": "${TIMESTAMP}",
  "version": "1.0.0",
  "files": [
    "database.sql.gz",
    "redis.rdb",
    "uploads.tar.gz",
    "config.tar.gz"
  ]
}
EOL

# Compress entire backup
tar -czf ${BACKUP_DIR}/vantax_backup_${TIMESTAMP}.tar.gz -C ${BACKUP_DIR} ${BACKUP_NAME}/
rm -rf ${BACKUP_DIR}/${BACKUP_NAME}

# Remove old backups (keep last 30 days)
find ${BACKUP_DIR} -name "vantax_backup_*.tar.gz" -mtime +30 -delete

echo "Backup completed: vantax_backup_${TIMESTAMP}.tar.gz"
EOF
    
    chmod +x $INSTALL_DIR/backup.sh
    
    # Create cron job for daily backups
    echo "0 2 * * * root $INSTALL_DIR/backup.sh >> $LOG_DIR/backup.log 2>&1" > /etc/cron.d/vantax-backup
    
    print_message $GREEN "✓ Backup configured"
}

# Function to create systemd service
create_systemd_service() {
    print_message $BLUE "\nCreating systemd service..."
    
    cat > $SYSTEMD_DIR/vantax.service << EOF
[Unit]
Description=Vanta X Trade Spend Management Platform
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR/vanta-x-trade-spend-final/deployment
ExecStart=/usr/bin/docker compose -f docker-compose.prod.yml up -d
ExecStop=/usr/bin/docker compose -f docker-compose.prod.yml down
ExecReload=/usr/bin/docker compose -f docker-compose.prod.yml restart
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable vantax.service
    
    print_message $GREEN "✓ Systemd service created"
}

# Function to display final information
display_final_info() {
    print_message $GREEN "\n╔══════════════════════════════════════════════════════════════════╗"
    print_message $GREEN "║           Vanta X Installation Completed Successfully!           ║"
    print_message $GREEN "╚══════════════════════════════════════════════════════════════════╝"
    
    print_message $BLUE "\nAccess Information:"
    print_message $YELLOW "Web Application: https://${DOMAIN_NAME}"
    print_message $YELLOW "API Gateway: https://${DOMAIN_NAME}/api"
    if [[ "$ENABLE_MONITORING" == "yes" ]]; then
        print_message $YELLOW "Grafana: https://${DOMAIN_NAME}/grafana"
        print_message $YELLOW "  Username: admin"
        print_message $YELLOW "  Password: ${GRAFANA_PASSWORD}"
    fi
    
    print_message $BLUE "\nImportant Configuration Files:"
    print_message $YELLOW "Environment: $CONFIG_DIR/vantax.env"
    print_message $YELLOW "Nginx: $NGINX_DIR/sites-available/vantax"
    print_message $YELLOW "Logs: $LOG_DIR/"
    
    print_message $BLUE "\nDatabase Credentials:"
    print_message $YELLOW "Database: vantax"
    print_message $YELLOW "Username: vantax_user"
    print_message $YELLOW "Password: ${DB_PASSWORD}"
    
    print_message $RED "\n⚠️  IMPORTANT: Please save these credentials securely!"
    
    print_message $BLUE "\nNext Steps:"
    print_message $YELLOW "1. Configure Azure AD settings in $CONFIG_DIR/vantax.env"
    print_message $YELLOW "2. Configure SAP integration settings if needed"
    print_message $YELLOW "3. Set up SMTP credentials for email notifications"
    print_message $YELLOW "4. Access the web application and create your first admin user"
    
    print_message $BLUE "\nUseful Commands:"
    print_message $YELLOW "View logs: docker compose -f $INSTALL_DIR/vanta-x-trade-spend-final/deployment/docker-compose.prod.yml logs -f"
    print_message $YELLOW "Restart services: systemctl restart vantax"
    print_message $YELLOW "Stop services: systemctl stop vantax"
    print_message $YELLOW "Backup now: $INSTALL_DIR/backup.sh"
    
    # Save credentials to secure file
    cat > $CONFIG_DIR/credentials.txt << EOF
Vanta X Credentials
Generated: $(date)

Database Password: ${DB_PASSWORD}
Redis Password: ${REDIS_PASSWORD}
JWT Secret: ${JWT_SECRET}
RabbitMQ Password: ${RABBITMQ_PASSWORD}
Grafana Password: ${GRAFANA_PASSWORD}

IMPORTANT: Keep this file secure and delete after saving credentials elsewhere.
EOF
    
    chmod 600 $CONFIG_DIR/credentials.txt
    
    print_message $GREEN "\nCredentials saved to: $CONFIG_DIR/credentials.txt"
    print_message $RED "Please save these credentials and delete the file!"
}

# Function to handle errors
handle_error() {
    print_message $RED "\n❌ An error occurred during installation!"
    print_message $YELLOW "Check the logs for more information:"
    print_message $YELLOW "Installation log: /var/log/vantax-install.log"
    exit 1
}

# Set error handler
trap handle_error ERR

# Main installation flow
main() {
    # Start logging
    exec 1> >(tee -a /var/log/vantax-install.log)
    exec 2>&1
    
    print_banner
    check_root
    detect_os
    check_system_requirements
    collect_user_input
    
    print_message $BLUE "\nStarting installation..."
    
    install_dependencies
    install_docker
    install_nodejs
    install_nginx
    setup_firewall
    create_directories
    clone_repository
    create_env_file
    setup_nginx
    setup_ssl
    setup_monitoring
    setup_backup
    start_services
    initialize_database
    create_systemd_service
    
    # Restart Nginx with new configuration
    systemctl restart nginx
    
    display_final_info
}

# Run main function
main "$@"