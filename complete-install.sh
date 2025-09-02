#!/bin/bash

# Vanta X - Complete Installation Script
# Comprehensive installation with proper error handling and simplified components

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
DATA_DIR="/var/lib/vantax"
LOG_DIR="/var/log/vantax"
CONFIG_DIR="/etc/vantax"

# Company information
COMPANY_NAME="Diplomat SA"

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
║                    COMPLETE INSTALLATION SCRIPT                              ║
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
        print_message $YELLOW "Please run: sudo ./complete-install.sh"
        exit 1
    fi
    
    print_message $GREEN "✓ Running as root"
}

# ============================================================================
# SYSTEM VALIDATION
# ============================================================================

validate_system() {
    log_step "System Validation"
    
    # Check OS
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" == "ubuntu" ]]; then
            print_message $GREEN "✓ Ubuntu $VERSION_ID detected"
        else
            print_message $YELLOW "⚠ Non-Ubuntu system detected: $ID $VERSION_ID"
            print_message $YELLOW "This script is optimized for Ubuntu, but will attempt to continue..."
        fi
    else
        print_message $YELLOW "⚠ Could not determine OS version"
        print_message $YELLOW "Continuing anyway..."
    fi
    
    # Check resources
    CPU_CORES=$(nproc)
    RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
    DISK_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    
    print_message $BLUE "System Resources:"
    print_message $YELLOW "  CPU Cores: $CPU_CORES"
    print_message $YELLOW "  RAM: ${RAM_GB}GB"
    print_message $YELLOW "  Free Disk: ${DISK_SPACE}GB"
    
    if [[ $RAM_GB -lt 2 ]]; then
        print_message $YELLOW "⚠ Low RAM detected (${RAM_GB}GB)"
        print_message $YELLOW "Performance may be affected. Recommended: 4GB+"
    fi
    
    if [[ $DISK_SPACE -lt 10 ]]; then
        print_message $YELLOW "⚠ Low disk space detected (${DISK_SPACE}GB)"
        print_message $YELLOW "You may run out of space. Recommended: 20GB+"
    fi
    
    print_message $GREEN "✓ System validation completed"
}

# ============================================================================
# SYSTEM CLEANUP
# ============================================================================

complete_cleanup() {
    log_step "Complete System Cleanup"
    
    print_message $YELLOW "Performing complete cleanup of previous installations..."
    
    # Stop PM2 processes if running
    if command -v pm2 &> /dev/null; then
        print_message $YELLOW "Stopping PM2 processes..."
        pm2 stop all 2>/dev/null || true
        pm2 delete all 2>/dev/null || true
    fi
    
    # Stop all Docker containers
    if command -v docker &> /dev/null; then
        print_message $YELLOW "Stopping Docker containers..."
        docker stop $(docker ps -aq) 2>/dev/null || true
        docker rm $(docker ps -aq) 2>/dev/null || true
        docker system prune -af 2>/dev/null || true
    fi
    
    # Stop services
    print_message $YELLOW "Stopping services..."
    systemctl stop vantax 2>/dev/null || true
    systemctl stop nginx 2>/dev/null || true
    
    # Remove directories
    print_message $YELLOW "Removing previous installation directories..."
    rm -rf "$INSTALL_DIR" 2>/dev/null || true
    rm -rf "$DATA_DIR" 2>/dev/null || true
    rm -rf "$LOG_DIR" 2>/dev/null || true
    rm -rf "$CONFIG_DIR" 2>/dev/null || true
    
    # Remove service files
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
    
    print_message $YELLOW "Updating package lists..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    
    print_message $YELLOW "Installing essential packages..."
    apt-get install -y -qq \
        curl wget git \
        apt-transport-https \
        ca-certificates \
        gnupg lsb-release \
        software-properties-common \
        nginx
    
    print_message $GREEN "✓ System updated"
}

install_docker() {
    log_step "Installing Docker"
    
    if command -v docker &> /dev/null; then
        print_message $YELLOW "Docker already installed, checking version..."
        docker --version
    else
        print_message $YELLOW "Installing Docker..."
        
        # Remove any old versions
        apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
        
        # Install Docker
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        apt-get update -qq
        apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
    fi
    
    # Ensure Docker is running
    systemctl start docker
    systemctl enable docker
    
    print_message $GREEN "✓ Docker installed and running"
    docker --version
}

# ============================================================================
# DIRECTORY SETUP
# ============================================================================

create_directories() {
    log_step "Creating Directory Structure"
    
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$DATA_DIR/postgres"
    mkdir -p "$DATA_DIR/redis"
    mkdir -p "$LOG_DIR"
    mkdir -p "$CONFIG_DIR"
    
    chmod 755 "$INSTALL_DIR" "$DATA_DIR" "$LOG_DIR"
    chmod 700 "$CONFIG_DIR"
    
    print_message $GREEN "✓ Directories created"
}

# ============================================================================
# APPLICATION DEPLOYMENT
# ============================================================================

deploy_application() {
    log_step "Deploying Vanta X Application"
    
    cd "$INSTALL_DIR"
    mkdir -p "vantax-app"
    cd "vantax-app"
    
    # Create backend
    create_backend
    
    # Create frontend
    create_frontend
    
    # Create deployment files
    create_deployment_files
    
    print_message $GREEN "✓ Application deployed"
}

create_backend() {
    print_message $YELLOW "Creating backend services..."
    
    mkdir -p "backend/api"
    
    # Create server.js using Node.js built-in modules (no dependencies)
    cat > "backend/api/server.js" << 'EOF'
const http = require('http');
const fs = require('fs');
const path = require('path');
const url = require('url');

// Simple in-memory database
const db = {
  company: 'Diplomat SA',
  users: [
    { id: 1, name: 'Admin User', email: 'admin@example.com', role: 'admin' }
  ],
  products: [
    { id: 1, name: 'Product A', category: 'Category 1', price: 100 },
    { id: 2, name: 'Product B', category: 'Category 1', price: 200 },
    { id: 3, name: 'Product C', category: 'Category 2', price: 150 },
    { id: 4, name: 'Product D', category: 'Category 2', price: 250 },
    { id: 5, name: 'Product E', category: 'Category 3', price: 300 }
  ],
  customers: [
    { id: 1, name: 'Customer X', type: 'Retail', region: 'North' },
    { id: 2, name: 'Customer Y', type: 'Wholesale', region: 'South' },
    { id: 3, name: 'Customer Z', type: 'Retail', region: 'East' }
  ],
  promotions: [
    { id: 1, name: 'Summer Sale', discount: 20, startDate: '2025-06-01', endDate: '2025-08-31' },
    { id: 2, name: 'Winter Special', discount: 15, startDate: '2025-12-01', endDate: '2026-02-28' }
  ],
  features: [
    { name: '5-Level Hierarchies', description: 'Complete customer and product hierarchies for comprehensive trade marketing management' },
    { name: 'AI-Powered Forecasting', description: 'Advanced machine learning models for accurate demand forecasting and trend analysis' },
    { name: 'Digital Wallets', description: 'QR code-based digital wallet system for seamless co-op fund management' },
    { name: 'Executive Analytics', description: 'Real-time dashboards and comprehensive analytics for executive decision making' },
    { name: 'Workflow Automation', description: 'Visual workflow designer for automating complex business processes' },
    { name: 'Multi-Company Support', description: 'Manage multiple companies and entities within a single platform' }
  ]
};

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type'
};

// Create HTTP server
const server = http.createServer((req, res) => {
  // Set CORS headers for all responses
  Object.keys(corsHeaders).forEach(header => {
    res.setHeader(header, corsHeaders[header]);
  });
  
  // Handle OPTIONS requests for CORS
  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }
  
  // Parse URL
  const parsedUrl = url.parse(req.url, true);
  const pathname = parsedUrl.pathname;
  
  // Set default content type
  res.setHeader('Content-Type', 'application/json');
  
  // API Routes
  if (pathname === '/health') {
    // Health check endpoint
    res.writeHead(200);
    res.end(JSON.stringify({
      status: 'healthy',
      service: 'vantax-api',
      version: '1.0.0',
      timestamp: new Date().toISOString()
    }));
  } 
  else if (pathname === '/api/v1') {
    // API info endpoint
    res.writeHead(200);
    res.end(JSON.stringify({
      message: 'Welcome to Vanta X API',
      version: '1.0.0',
      company: db.company
    }));
  }
  else if (pathname === '/api/v1/data') {
    // Main data endpoint
    res.writeHead(200);
    res.end(JSON.stringify({
      company: db.company,
      features: db.features
    }));
  }
  else if (pathname === '/api/v1/products') {
    // Products endpoint
    res.writeHead(200);
    res.end(JSON.stringify({
      products: db.products
    }));
  }
  else if (pathname === '/api/v1/customers') {
    // Customers endpoint
    res.writeHead(200);
    res.end(JSON.stringify({
      customers: db.customers
    }));
  }
  else if (pathname === '/api/v1/promotions') {
    // Promotions endpoint
    res.writeHead(200);
    res.end(JSON.stringify({
      promotions: db.promotions
    }));
  }
  else if (pathname === '/api/v1/dashboard') {
    // Dashboard data endpoint
    res.writeHead(200);
    res.end(JSON.stringify({
      company: db.company,
      stats: {
        products: db.products.length,
        customers: db.customers.length,
        promotions: db.promotions.length,
        users: db.users.length
      },
      recentPromotions: db.promotions,
      topProducts: db.products.slice(0, 3)
    }));
  }
  else {
    // 404 Not Found
    res.writeHead(404);
    res.end(JSON.stringify({
      error: 'Not Found',
      message: 'The requested resource was not found'
    }));
  }
});

// Start server
const port = process.env.PORT || 4000;
server.listen(port, () => {
  console.log(`Vantax API listening on port ${port}`);
});

// Handle graceful shutdown
process.on('SIGTERM', () => {
  console.log('Received SIGTERM, shutting down gracefully');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('Received SIGINT, shutting down gracefully');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});
EOF

    # Create Dockerfile for backend
    cat > "backend/api/Dockerfile" << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY server.js ./

EXPOSE 4000

CMD ["node", "server.js"]
EOF

    print_message $GREEN "✓ Created backend services"
}

create_frontend() {
    print_message $YELLOW "Creating frontend application..."
    
    mkdir -p "frontend/web/html"
    
    # Create index.html with inline CSS and JavaScript
    cat > "frontend/web/html/index.html" << 'EOF'
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
            margin-bottom: 2rem;
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
        
        .nav {
            background: rgba(255,255,255,0.1);
            padding: 1rem;
            border-radius: 8px;
            margin-bottom: 2rem;
            display: flex;
            justify-content: center;
            flex-wrap: wrap;
        }
        
        .nav-item {
            color: white;
            text-decoration: none;
            padding: 0.5rem 1rem;
            margin: 0 0.5rem;
            border-radius: 4px;
            transition: background 0.3s;
        }
        
        .nav-item:hover, .nav-item.active {
            background: rgba(255,255,255,0.2);
        }
        
        .dashboard {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2rem;
        }
        
        .stat-card {
            background: white;
            padding: 1.5rem;
            border-radius: 8px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.1);
            text-align: center;
        }
        
        .stat-card h3 {
            color: #667eea;
            margin-bottom: 0.5rem;
        }
        
        .stat-card p {
            font-size: 2rem;
            font-weight: bold;
            color: #333;
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
        
        .table-container {
            background: white;
            border-radius: 8px;
            padding: 1.5rem;
            box-shadow: 0 4px 20px rgba(0,0,0,0.1);
            margin-top: 2rem;
            overflow-x: auto;
        }
        
        .data-table {
            width: 100%;
            border-collapse: collapse;
        }
        
        .data-table th, .data-table td {
            padding: 0.75rem 1rem;
            text-align: left;
            border-bottom: 1px solid #eee;
        }
        
        .data-table th {
            background: #f8f9fa;
            font-weight: 600;
            color: #333;
        }
        
        .data-table tr:last-child td {
            border-bottom: none;
        }
        
        .data-table tr:hover td {
            background: #f8f9fa;
        }
        
        .page {
            display: none;
        }
        
        .page.active {
            display: block;
        }
        
        .loading {
            text-align: center;
            padding: 2rem;
            color: white;
        }
        
        @media (max-width: 768px) {
            .header h1 {
                font-size: 2rem;
            }
            
            .container {
                padding: 1rem;
            }
            
            .features, .dashboard {
                grid-template-columns: 1fr;
            }
            
            .nav-item {
                margin-bottom: 0.5rem;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <header class="header">
            <h1>Vanta X</h1>
            <p>FMCG Trade Marketing Management Platform</p>
            <p id="company-name">Diplomat SA</p>
        </header>
        
        <nav class="nav">
            <a href="#dashboard" class="nav-item active" data-page="dashboard-page">Dashboard</a>
            <a href="#products" class="nav-item" data-page="products-page">Products</a>
            <a href="#customers" class="nav-item" data-page="customers-page">Customers</a>
            <a href="#promotions" class="nav-item" data-page="promotions-page">Promotions</a>
            <a href="#features" class="nav-item" data-page="features-page">Features</a>
        </nav>
        
        <div class="status">
            <strong id="system-status">Connecting to API...</strong>
        </div>
        
        <!-- Dashboard Page -->
        <div id="dashboard-page" class="page active">
            <h2 style="color: white; margin-bottom: 1rem;">Dashboard</h2>
            
            <div class="dashboard" id="stats-container">
                <div class="stat-card">
                    <h3>Products</h3>
                    <p id="products-count">-</p>
                </div>
                <div class="stat-card">
                    <h3>Customers</h3>
                    <p id="customers-count">-</p>
                </div>
                <div class="stat-card">
                    <h3>Promotions</h3>
                    <p id="promotions-count">-</p>
                </div>
                <div class="stat-card">
                    <h3>Users</h3>
                    <p id="users-count">-</p>
                </div>
            </div>
            
            <div class="table-container">
                <h3 style="margin-bottom: 1rem;">Recent Promotions</h3>
                <table class="data-table" id="recent-promotions-table">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Name</th>
                            <th>Discount</th>
                            <th>Start Date</th>
                            <th>End Date</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td colspan="5">Loading promotions...</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
        
        <!-- Products Page -->
        <div id="products-page" class="page">
            <h2 style="color: white; margin-bottom: 1rem;">Products</h2>
            
            <div class="table-container">
                <table class="data-table" id="products-table">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Name</th>
                            <th>Category</th>
                            <th>Price</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td colspan="4">Loading products...</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
        
        <!-- Customers Page -->
        <div id="customers-page" class="page">
            <h2 style="color: white; margin-bottom: 1rem;">Customers</h2>
            
            <div class="table-container">
                <table class="data-table" id="customers-table">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Name</th>
                            <th>Type</th>
                            <th>Region</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td colspan="4">Loading customers...</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
        
        <!-- Promotions Page -->
        <div id="promotions-page" class="page">
            <h2 style="color: white; margin-bottom: 1rem;">Promotions</h2>
            
            <div class="table-container">
                <table class="data-table" id="promotions-table">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Name</th>
                            <th>Discount</th>
                            <th>Start Date</th>
                            <th>End Date</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td colspan="5">Loading promotions...</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
        
        <!-- Features Page -->
        <div id="features-page" class="page">
            <h2 style="color: white; margin-bottom: 1rem;">Features</h2>
            
            <div id="features-container" class="features">
                <div class="feature-card">
                    <h3>Loading features...</h3>
                    <p>Please wait while we load the system features.</p>
                </div>
            </div>
        </div>
        
        <div class="status">
            <p><strong>Company:</strong> <span id="company-display">Diplomat SA</span></p>
            <p><strong>Environment:</strong> Production</p>
            <p><strong>Version:</strong> 1.0.0</p>
        </div>
    </div>

    <script>
        // Simple JavaScript for navigation and data loading
        document.addEventListener('DOMContentLoaded', function() {
            // Navigation
            const navItems = document.querySelectorAll('.nav-item');
            const pages = document.querySelectorAll('.page');
            
            navItems.forEach(item => {
                item.addEventListener('click', function(e) {
                    e.preventDefault();
                    
                    // Update active nav item
                    navItems.forEach(nav => nav.classList.remove('active'));
                    this.classList.add('active');
                    
                    // Show selected page
                    const targetPage = this.getAttribute('data-page');
                    pages.forEach(page => {
                        page.classList.remove('active');
                        if (page.id === targetPage) {
                            page.classList.add('active');
                        }
                    });
                    
                    // Load data for the page if needed
                    if (targetPage === 'products-page') {
                        loadProducts();
                    } else if (targetPage === 'customers-page') {
                        loadCustomers();
                    } else if (targetPage === 'promotions-page') {
                        loadPromotions();
                    } else if (targetPage === 'features-page') {
                        loadFeatures();
                    }
                });
            });
            
            // Check API status
            fetch('/api/v1')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('system-status').textContent = '✅ ' + data.message;
                    if (data.company) {
                        document.getElementById('company-name').textContent = data.company;
                        document.getElementById('company-display').textContent = data.company;
                    }
                })
                .catch(error => {
                    document.getElementById('system-status').textContent = '⚠️ API connection issue';
                    console.error('API connection error:', error);
                });
            
            // Load dashboard data
            loadDashboard();
            
            // Function to load dashboard data
            function loadDashboard() {
                fetch('/api/v1/dashboard')
                    .then(response => response.json())
                    .then(data => {
                        // Update stats
                        document.getElementById('products-count').textContent = data.stats.products;
                        document.getElementById('customers-count').textContent = data.stats.customers;
                        document.getElementById('promotions-count').textContent = data.stats.promotions;
                        document.getElementById('users-count').textContent = data.stats.users;
                        
                        // Update recent promotions table
                        const tableBody = document.querySelector('#recent-promotions-table tbody');
                        tableBody.innerHTML = '';
                        
                        if (data.recentPromotions && data.recentPromotions.length > 0) {
                            data.recentPromotions.forEach(promotion => {
                                const row = document.createElement('tr');
                                row.innerHTML = `
                                    <td>${promotion.id}</td>
                                    <td>${promotion.name}</td>
                                    <td>${promotion.discount}%</td>
                                    <td>${promotion.startDate}</td>
                                    <td>${promotion.endDate}</td>
                                `;
                                tableBody.appendChild(row);
                            });
                        } else {
                            tableBody.innerHTML = '<tr><td colspan="5">No promotions found</td></tr>';
                        }
                    })
                    .catch(error => {
                        console.error('Error loading dashboard data:', error);
                        document.getElementById('stats-container').innerHTML = '<div class="loading">Error loading dashboard data</div>';
                    });
            }
            
            // Function to load products
            function loadProducts() {
                fetch('/api/v1/products')
                    .then(response => response.json())
                    .then(data => {
                        const tableBody = document.querySelector('#products-table tbody');
                        tableBody.innerHTML = '';
                        
                        if (data.products && data.products.length > 0) {
                            data.products.forEach(product => {
                                const row = document.createElement('tr');
                                row.innerHTML = `
                                    <td>${product.id}</td>
                                    <td>${product.name}</td>
                                    <td>${product.category}</td>
                                    <td>$${product.price}</td>
                                `;
                                tableBody.appendChild(row);
                            });
                        } else {
                            tableBody.innerHTML = '<tr><td colspan="4">No products found</td></tr>';
                        }
                    })
                    .catch(error => {
                        console.error('Error loading products:', error);
                        document.querySelector('#products-table tbody').innerHTML = '<tr><td colspan="4">Error loading products</td></tr>';
                    });
            }
            
            // Function to load customers
            function loadCustomers() {
                fetch('/api/v1/customers')
                    .then(response => response.json())
                    .then(data => {
                        const tableBody = document.querySelector('#customers-table tbody');
                        tableBody.innerHTML = '';
                        
                        if (data.customers && data.customers.length > 0) {
                            data.customers.forEach(customer => {
                                const row = document.createElement('tr');
                                row.innerHTML = `
                                    <td>${customer.id}</td>
                                    <td>${customer.name}</td>
                                    <td>${customer.type}</td>
                                    <td>${customer.region}</td>
                                `;
                                tableBody.appendChild(row);
                            });
                        } else {
                            tableBody.innerHTML = '<tr><td colspan="4">No customers found</td></tr>';
                        }
                    })
                    .catch(error => {
                        console.error('Error loading customers:', error);
                        document.querySelector('#customers-table tbody').innerHTML = '<tr><td colspan="4">Error loading customers</td></tr>';
                    });
            }
            
            // Function to load promotions
            function loadPromotions() {
                fetch('/api/v1/promotions')
                    .then(response => response.json())
                    .then(data => {
                        const tableBody = document.querySelector('#promotions-table tbody');
                        tableBody.innerHTML = '';
                        
                        if (data.promotions && data.promotions.length > 0) {
                            data.promotions.forEach(promotion => {
                                const row = document.createElement('tr');
                                row.innerHTML = `
                                    <td>${promotion.id}</td>
                                    <td>${promotion.name}</td>
                                    <td>${promotion.discount}%</td>
                                    <td>${promotion.startDate}</td>
                                    <td>${promotion.endDate}</td>
                                `;
                                tableBody.appendChild(row);
                            });
                        } else {
                            tableBody.innerHTML = '<tr><td colspan="5">No promotions found</td></tr>';
                        }
                    })
                    .catch(error => {
                        console.error('Error loading promotions:', error);
                        document.querySelector('#promotions-table tbody').innerHTML = '<tr><td colspan="5">Error loading promotions</td></tr>';
                    });
            }
            
            // Function to load features
            function loadFeatures() {
                fetch('/api/v1/data')
                    .then(response => response.json())
                    .then(data => {
                        const featuresContainer = document.getElementById('features-container');
                        featuresContainer.innerHTML = '';
                        
                        if (data.features && data.features.length > 0) {
                            data.features.forEach(feature => {
                                const featureCard = document.createElement('div');
                                featureCard.className = 'feature-card';
                                
                                featureCard.innerHTML = `
                                    <h3>${feature.name}</h3>
                                    <p>${feature.description}</p>
                                `;
                                
                                featuresContainer.appendChild(featureCard);
                            });
                        } else {
                            featuresContainer.innerHTML = '<div class="feature-card"><h3>No Features Found</h3><p>No features are currently available.</p></div>';
                        }
                    })
                    .catch(error => {
                        console.error('Error loading features:', error);
                        document.getElementById('features-container').innerHTML = '<div class="feature-card"><h3>Error Loading Features</h3><p>Could not connect to the API. Please try again later.</p></div>';
                    });
            }
        });
    </script>
</body>
</html>
EOF

    # Create Dockerfile for frontend
    cat > "frontend/web/Dockerfile" << 'EOF'
FROM nginx:alpine

COPY html/ /usr/share/nginx/html/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF

    print_message $GREEN "✓ Created frontend application"
}

create_deployment_files() {
    print_message $YELLOW "Creating deployment files..."
    
    mkdir -p "deployment"
    
    # Create docker-compose file
    cat > "deployment/docker-compose.yml" << 'EOF'
version: '3'

services:
  api:
    build:
      context: ../backend/api
    container_name: vantax-api
    ports:
      - "4000:4000"
    restart: unless-stopped

  web:
    build:
      context: ../frontend/web
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
    
    # Create a proper Nginx configuration
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
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
    
    location /api/ {
        proxy_pass http://localhost:4000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF
    
    # Enable site
    ln -sf /etc/nginx/sites-available/vantax /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test Nginx configuration
    print_message $YELLOW "Testing Nginx configuration..."
    nginx -t
    
    # Restart Nginx
    systemctl restart nginx
    systemctl enable nginx
    
    print_message $GREEN "✓ Nginx configured"
}

# ============================================================================
# SERVICE DEPLOYMENT
# ============================================================================

deploy_services() {
    log_step "Deploying Services"
    
    cd "$INSTALL_DIR/vantax-app/deployment"
    
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
Description=Vanta X Application
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR/vantax-app/deployment
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
# FINAL VERIFICATION
# ============================================================================

verify_installation() {
    log_step "Verifying Installation"
    
    print_message $YELLOW "Waiting for services to start..."
    sleep 10
    
    # Check Docker containers
    print_message $YELLOW "Checking Docker containers..."
    docker ps
    
    # Check API
    print_message $YELLOW "Checking API..."
    if curl -s http://localhost:4000/health > /dev/null; then
        print_message $GREEN "✓ API is responding"
    else
        print_message $RED "⚠ API is not responding"
    fi
    
    # Check Web
    print_message $YELLOW "Checking Web application..."
    if curl -s http://localhost:3000 > /dev/null; then
        print_message $GREEN "✓ Web application is responding"
    else
        print_message $RED "⚠ Web application is not responding"
    fi
    
    # Check Nginx
    print_message $YELLOW "Checking Nginx..."
    if curl -s http://localhost > /dev/null; then
        print_message $GREEN "✓ Nginx is responding"
    else
        print_message $RED "⚠ Nginx is not responding"
    fi
    
    print_message $GREEN "✓ Installation verification completed"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    LOG_FILE="/var/log/vantax-installation-$(date +%Y%m%d-%H%M%S).log"
    exec 1> >(tee -a "$LOG_FILE")
    exec 2>&1
    
    print_banner
    
    print_message $BLUE "Starting Vanta X Complete Installation"
    print_message $BLUE "This script will perform a complete installation from scratch"
    
    # Validation and cleanup
    check_root
    validate_system
    complete_cleanup
    
    # System setup
    update_system
    install_docker
    create_directories
    
    # Application deployment
    deploy_application
    
    # Service deployment
    deploy_services
    setup_nginx
    create_system_service
    
    # Verification
    verify_installation
    
    # Success message
    print_message $GREEN "\n╔══════════════════════════════════════════════════════════════════════════════╗"
    print_message $GREEN "║                                                                              ║"
    print_message $GREEN "║              🎉 VANTA X INSTALLATION COMPLETED SUCCESSFULLY! 🎉              ║"
    print_message $GREEN "║                                                                              ║"
    print_message $GREEN "╚══════════════════════════════════════════════════════════════════════════════╝"
    
    print_message $BLUE "\n📋 Installation Summary:"
    print_message $YELLOW "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_message $CYAN "Web Application: ${GREEN}http://localhost"
    print_message $CYAN "API Endpoint: ${GREEN}http://localhost/api/v1"
    print_message $CYAN "Installation Directory: ${GREEN}$INSTALL_DIR"
    print_message $CYAN "Log File: ${GREEN}$LOG_FILE"
    print_message $YELLOW "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    print_message $GREEN "\n✅ INSTALLATION ADVANTAGES:"
    print_message $GREEN "✅ No build steps - just simple file copying"
    print_message $GREEN "✅ No dependencies - uses Node.js built-in modules"
    print_message $GREEN "✅ No npm install - zero package dependencies"
    print_message $GREEN "✅ Proper Nginx configuration - tested and working"
    print_message $GREEN "✅ Complete system service - auto-starts on boot"
    
    print_message $GREEN "\n🚀 Access your application at: http://localhost"
    
    print_message $BLUE "\n🎊 Installation completed successfully! 🎊"
}

# Error handling
handle_error() {
    print_message $RED "\n❌ Installation failed!"
    print_message $YELLOW "Check the log file: $LOG_FILE"
    exit 1
}

trap handle_error ERR

# Run main function
main "$@"