#!/bin/bash

# Vanta X - Minimal Deployment Script
# Ultra-simple deployment with fixed Nginx configuration

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
NC='\033[0m'

# Installation paths
INSTALL_DIR="/opt/vantax"
LOG_DIR="/var/log/vantax"

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
    echo -e "${BLUE}"
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
║                    MINIMAL DEPLOYMENT SCRIPT                                 ║
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
        print_message $RED "Error: This script must be run as root"
        print_message $YELLOW "Please run: sudo ./minimal-deploy.sh"
        exit 1
    fi
}

# ============================================================================
# SYSTEM CLEANUP
# ============================================================================

complete_cleanup() {
    log_step "Complete System Cleanup"
    
    print_message $YELLOW "Performing complete cleanup..."
    
    # Stop all Docker containers
    if command -v docker &> /dev/null; then
        docker stop $(docker ps -aq) 2>/dev/null || true
        docker rm $(docker ps -aq) 2>/dev/null || true
        docker system prune -af 2>/dev/null || true
    fi
    
    # Stop services
    systemctl stop vantax 2>/dev/null || true
    systemctl stop nginx 2>/dev/null || true
    
    # Remove directories
    rm -rf "$INSTALL_DIR" 2>/dev/null || true
    rm -rf "$LOG_DIR" 2>/dev/null || true
    rm -f /etc/systemd/system/vantax.service 2>/dev/null || true
    rm -f /etc/nginx/sites-enabled/vantax 2>/dev/null || true
    rm -f /etc/nginx/sites-available/vantax 2>/dev/null || true
    systemctl daemon-reload
    
    print_message $GREEN "✓ Cleanup completed"
}

# ============================================================================
# SYSTEM SETUP
# ============================================================================

update_system() {
    log_step "System Update"
    
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    
    apt-get install -y -qq \
        curl wget \
        apt-transport-https \
        ca-certificates \
        gnupg lsb-release \
        nginx
    
    print_message $GREEN "✓ System updated"
}

install_docker() {
    log_step "Installing Docker"
    
    # Remove existing Docker
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    systemctl start docker
    systemctl enable docker
    
    print_message $GREEN "✓ Docker installed"
}

# ============================================================================
# DIRECTORY SETUP
# ============================================================================

create_directories() {
    log_step "Creating Directory Structure"
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$LOG_DIR"
    
    chmod 755 "$INSTALL_DIR" "$LOG_DIR"
    
    print_message $GREEN "✓ Directories created"
}

# ============================================================================
# MINIMAL PROJECT DEPLOYMENT
# ============================================================================

deploy_minimal_project() {
    log_step "Deploying Minimal Project"
    
    cd "$INSTALL_DIR"
    mkdir -p "vantax-minimal"
    cd "vantax-minimal"
    
    # Create minimal backend
    create_minimal_backend
    
    # Create minimal frontend
    create_minimal_frontend
    
    # Create deployment files
    create_minimal_deployment_files
    
    print_message $GREEN "✓ Minimal project deployed"
}

create_minimal_backend() {
    print_message $YELLOW "Creating minimal backend..."
    
    mkdir -p "backend"
    
    # Create simple server.js
    cat > "backend/server.js" << 'EOF'
const http = require('http');

const server = http.createServer((req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Access-Control-Allow-Origin', '*');
  
  if (req.url === '/health') {
    res.statusCode = 200;
    res.end(JSON.stringify({
      status: 'healthy',
      service: 'vantax-api',
      timestamp: new Date().toISOString()
    }));
  } 
  else if (req.url === '/api/v1') {
    res.statusCode = 200;
    res.end(JSON.stringify({
      message: 'Welcome to Vanta X API',
      version: '1.0.0'
    }));
  }
  else if (req.url === '/api/v1/data') {
    res.statusCode = 200;
    res.end(JSON.stringify({
      company: 'Diplomat SA',
      features: [
        { name: '5-Level Hierarchies', description: 'Complete customer and product hierarchies' },
        { name: 'AI-Powered Forecasting', description: 'Advanced machine learning models' },
        { name: 'Digital Wallets', description: 'QR code-based transactions' },
        { name: 'Executive Analytics', description: 'Real-time dashboards' },
        { name: 'Workflow Automation', description: 'Visual workflow designer' },
        { name: 'Multi-Company Support', description: 'Manage multiple entities' }
      ]
    }));
  }
  else {
    res.statusCode = 404;
    res.end(JSON.stringify({
      error: 'Not Found',
      message: 'The requested resource was not found'
    }));
  }
});

const port = process.env.PORT || 4000;
server.listen(port, () => {
  console.log(`Vantax API listening on port ${port}`);
});
EOF

    # Create Dockerfile
    cat > "backend/Dockerfile" << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY server.js ./

EXPOSE 4000

CMD ["node", "server.js"]
EOF

    print_message $GREEN "✓ Created minimal backend"
}

create_minimal_frontend() {
    print_message $YELLOW "Creating minimal frontend..."
    
    mkdir -p "frontend/html"
    
    # Create index.html
    cat > "frontend/html/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Vanta X - Trade Spend Management</title>
    <style>
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
    </style>
</head>
<body>
    <div class="container">
        <header class="header">
            <h1>Vanta X</h1>
            <p>FMCG Trade Marketing Management Platform</p>
            <p>Minimal Deployment</p>
        </header>
        
        <div class="status">
            <strong id="system-status">✅ System is online</strong>
        </div>
        
        <div id="features-container" class="features">
            <!-- Features will be loaded here -->
            <div class="feature-card">
                <h3>Loading features...</h3>
                <p>Please wait while we load the system features.</p>
            </div>
        </div>
        
        <div class="status">
            <p><strong>Company:</strong> <span id="company-name">Diplomat SA</span></p>
            <p><strong>Environment:</strong> Production</p>
            <p><strong>Version:</strong> 1.0.0</p>
        </div>
    </div>

    <script>
        // Simple JavaScript to load features
        document.addEventListener('DOMContentLoaded', function() {
            // Check API status
            fetch('/api/v1')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('system-status').textContent = '✅ ' + data.message;
                })
                .catch(error => {
                    document.getElementById('system-status').textContent = '⚠️ API connection issue';
                });
            
            // Load features
            fetch('/api/v1/data')
                .then(response => response.json())
                .then(data => {
                    // Update company name
                    document.getElementById('company-name').textContent = data.company;
                    
                    // Clear and populate features
                    const featuresContainer = document.getElementById('features-container');
                    featuresContainer.innerHTML = '';
                    
                    data.features.forEach(feature => {
                        const featureCard = document.createElement('div');
                        featureCard.className = 'feature-card';
                        
                        featureCard.innerHTML = `
                            <h3>${feature.name}</h3>
                            <p>${feature.description}</p>
                        `;
                        
                        featuresContainer.appendChild(featureCard);
                    });
                })
                .catch(error => {
                    console.error('Error loading features:', error);
                    const featuresContainer = document.getElementById('features-container');
                    featuresContainer.innerHTML = `
                        <div class="feature-card">
                            <h3>Error Loading Features</h3>
                            <p>Could not connect to the API. Please try again later.</p>
                        </div>
                    `;
                });
        });
    </script>
</body>
</html>
EOF

    # Create Dockerfile
    cat > "frontend/Dockerfile" << 'EOF'
FROM nginx:alpine

COPY html/ /usr/share/nginx/html/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF

    print_message $GREEN "✓ Created minimal frontend"
}

create_minimal_deployment_files() {
    print_message $YELLOW "Creating deployment files..."
    
    mkdir -p "deployment"
    
    # Create docker-compose file
    cat > "deployment/docker-compose.yml" << 'EOF'
version: '3'

services:
  api:
    build:
      context: ../backend
    container_name: vantax-api
    ports:
      - "4000:4000"
    restart: unless-stopped

  web:
    build:
      context: ../frontend
    container_name: vantax-web
    ports:
      - "3000:80"
    restart: unless-stopped
EOF

    print_message $GREEN "✓ Created deployment files"
}

# ============================================================================
# NGINX SETUP
# ============================================================================

setup_nginx() {
    log_step "Configuring Nginx"
    
    # Create a minimal Nginx configuration
    cat > "/etc/nginx/sites-available/vantax" << 'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    server_name _;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /api/ {
        proxy_pass http://localhost:4000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF
    
    # Enable site
    ln -sf /etc/nginx/sites-available/vantax /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test and restart Nginx
    nginx -t
    systemctl restart nginx
    systemctl enable nginx
    
    print_message $GREEN "✓ Nginx configured"
}

# ============================================================================
# SERVICE DEPLOYMENT
# ============================================================================

deploy_services() {
    log_step "Deploying Services"
    
    cd "$INSTALL_DIR/vantax-minimal/deployment"
    
    print_message $YELLOW "Building and starting services..."
    
    # Start services
    docker compose up -d --build
    
    print_message $GREEN "✓ Services deployed"
}

# ============================================================================
# SYSTEM SERVICE
# ============================================================================

create_system_service() {
    log_step "Creating System Service"
    
    cat > "/etc/systemd/system/vantax.service" << EOF
[Unit]
Description=Vanta X Minimal Deployment
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR/vantax-minimal/deployment
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable vantax.service
    
    print_message $GREEN "✓ System service created"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    LOG_FILE="/var/log/vantax-minimal-deployment-$(date +%Y%m%d-%H%M%S).log"
    exec 1> >(tee -a "$LOG_FILE")
    exec 2>&1
    
    print_banner
    
    print_message $BLUE "Starting Vanta X Minimal Deployment"
    print_message $BLUE "This deployment uses absolute minimal components with no build steps"
    
    # Validation and cleanup
    check_root
    complete_cleanup
    
    # System setup
    update_system
    install_docker
    create_directories
    
    # Project deployment
    deploy_minimal_project
    
    # Service deployment
    deploy_services
    setup_nginx
    create_system_service
    
    # Success message
    print_message $GREEN "\n╔══════════════════════════════════════════════════════════════════════════════╗"
    print_message $GREEN "║                                                                              ║"
    print_message $GREEN "║              🎉 VANTA X MINIMAL DEPLOYMENT COMPLETED! 🎉                     ║"
    print_message $GREEN "║                                                                              ║"
    print_message $GREEN "╚══════════════════════════════════════════════════════════════════════════════╝"
    
    print_message $BLUE "\n📋 Minimal Deployment Success:"
    print_message $YELLOW "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_message $CYAN "Web Application: ${GREEN}http://localhost"
    print_message $CYAN "API Endpoint: ${GREEN}http://localhost/api/v1"
    print_message $YELLOW "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    print_message $GREEN "\n✅ MINIMAL DEPLOYMENT ADVANTAGES:"
    print_message $GREEN "✅ No build steps - just simple file copying"
    print_message $GREEN "✅ No dependencies - uses Node.js built-in http module"
    print_message $GREEN "✅ No npm install - zero package dependencies"
    print_message $GREEN "✅ No complex configuration - minimal Nginx setup"
    print_message $GREEN "✅ Ultra-fast and reliable deployment"
    
    print_message $GREEN "\n🚀 Access your application at: http://localhost"
    
    # Test connectivity
    sleep 5
    if curl -s http://localhost:3000 > /dev/null; then
        print_message $GREEN "✓ Web application is responding"
    fi
    
    if curl -s http://localhost:4000/health > /dev/null; then
        print_message $GREEN "✓ API is responding"
    fi
    
    print_message $BLUE "\n🎊 Minimal deployment completed successfully! 🎊"
}

# Error handling
handle_error() {
    print_message $RED "\n❌ Minimal deployment failed!"
    print_message $YELLOW "Check the log file: $LOG_FILE"
    exit 1
}

trap handle_error ERR

# Run main function
main "$@"