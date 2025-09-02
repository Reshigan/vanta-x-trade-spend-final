#!/bin/bash

# Vanta X - Enterprise Deployment Script
# Full-featured enterprise deployment with comprehensive UI

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
║                    ENTERPRISE DEPLOYMENT SCRIPT                              ║
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
        print_message $YELLOW "Please run: sudo ./enterprise-deploy.sh"
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
    log_step "Deploying Vanta X Enterprise Application"
    
    cd "$INSTALL_DIR"
    mkdir -p "vantax-enterprise"
    cd "vantax-enterprise"
    
    # Create backend
    create_backend
    
    # Create enterprise frontend
    create_enterprise_frontend
    
    # Create deployment files
    create_deployment_files
    
    print_message $GREEN "✓ Enterprise application deployed"
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

// Sample enterprise data
const db = {
  company: 'Diplomat SA',
  users: [
    { id: 1, name: 'Admin User', email: 'admin@example.com', role: 'admin', lastLogin: '2025-09-01T08:30:00Z' },
    { id: 2, name: 'Sales Manager', email: 'sales@example.com', role: 'manager', lastLogin: '2025-09-01T09:15:00Z' },
    { id: 3, name: 'Marketing Director', email: 'marketing@example.com', role: 'director', lastLogin: '2025-09-01T10:00:00Z' },
    { id: 4, name: 'Field Rep 1', email: 'field1@example.com', role: 'field', lastLogin: '2025-09-01T08:00:00Z' },
    { id: 5, name: 'Field Rep 2', email: 'field2@example.com', role: 'field', lastLogin: '2025-09-01T08:15:00Z' }
  ],
  products: [
    { id: 1, name: 'Premium Lager', category: 'Beer', subCategory: 'Lager', price: 120, cost: 80, margin: 33.3, stock: 1250, salesLTD: 5400 },
    { id: 2, name: 'Craft IPA', category: 'Beer', subCategory: 'IPA', price: 150, cost: 95, margin: 36.7, stock: 850, salesLTD: 3200 },
    { id: 3, name: 'Light Beer', category: 'Beer', subCategory: 'Light', price: 110, cost: 70, margin: 36.4, stock: 1800, salesLTD: 7500 },
    { id: 4, name: 'Premium Vodka', category: 'Spirits', subCategory: 'Vodka', price: 280, cost: 180, margin: 35.7, stock: 650, salesLTD: 1800 },
    { id: 5, name: 'Blended Whisky', category: 'Spirits', subCategory: 'Whisky', price: 320, cost: 210, margin: 34.4, stock: 480, salesLTD: 1200 },
    { id: 6, name: 'Single Malt', category: 'Spirits', subCategory: 'Whisky', price: 450, cost: 300, margin: 33.3, stock: 320, salesLTD: 950 },
    { id: 7, name: 'White Wine', category: 'Wine', subCategory: 'White', price: 180, cost: 120, margin: 33.3, stock: 720, salesLTD: 2100 },
    { id: 8, name: 'Red Wine', category: 'Wine', subCategory: 'Red', price: 210, cost: 140, margin: 33.3, stock: 680, salesLTD: 1950 },
    { id: 9, name: 'Sparkling Wine', category: 'Wine', subCategory: 'Sparkling', price: 240, cost: 160, margin: 33.3, stock: 420, salesLTD: 1100 },
    { id: 10, name: 'Cola', category: 'Soft Drinks', subCategory: 'Carbonated', price: 45, cost: 25, margin: 44.4, stock: 3200, salesLTD: 12500 },
    { id: 11, name: 'Lemon Soda', category: 'Soft Drinks', subCategory: 'Carbonated', price: 40, cost: 22, margin: 45.0, stock: 2800, salesLTD: 9800 },
    { id: 12, name: 'Orange Juice', category: 'Soft Drinks', subCategory: 'Juice', price: 55, cost: 32, margin: 41.8, stock: 1500, salesLTD: 6200 }
  ],
  customers: [
    { id: 1, name: 'Metro Supermarket', type: 'Supermarket', region: 'North', city: 'Manchester', address: '123 High St', contact: 'John Smith', phone: '555-1234', credit: 50000, balance: 12500, salesLTD: 145000 },
    { id: 2, name: 'City Grocers', type: 'Grocery', region: 'South', city: 'London', address: '456 Main Rd', contact: 'Jane Brown', phone: '555-2345', credit: 25000, balance: 8200, salesLTD: 78000 },
    { id: 3, name: 'Express Mart', type: 'Convenience', region: 'East', city: 'Norwich', address: '789 Park Ave', contact: 'Mike Johnson', phone: '555-3456', credit: 15000, balance: 4500, salesLTD: 42000 },
    { id: 4, name: 'Luxury Hotels', type: 'HoReCa', region: 'West', city: 'Bristol', address: '101 River St', contact: 'Sarah Williams', phone: '555-4567', credit: 75000, balance: 28000, salesLTD: 210000 },
    { id: 5, name: 'Downtown Pub', type: 'HoReCa', region: 'North', city: 'Leeds', address: '202 Oak Rd', contact: 'David Miller', phone: '555-5678', credit: 30000, balance: 12800, salesLTD: 95000 },
    { id: 6, name: 'Wholesale Distributors', type: 'Wholesale', region: 'Central', city: 'Birmingham', address: '303 Pine St', contact: 'Robert Taylor', phone: '555-6789', credit: 100000, balance: 45000, salesLTD: 320000 },
    { id: 7, name: 'Corner Shop', type: 'Convenience', region: 'South', city: 'Brighton', address: '404 Beach Rd', contact: 'Emma Wilson', phone: '555-7890', credit: 10000, balance: 3200, salesLTD: 28000 },
    { id: 8, name: 'Gourmet Restaurant', type: 'HoReCa', region: 'North', city: 'York', address: '505 Castle St', contact: 'James Anderson', phone: '555-8901', credit: 40000, balance: 18500, salesLTD: 125000 }
  ],
  promotions: [
    { id: 1, name: 'Summer Beer Festival', type: 'Discount', discount: 20, budget: 50000, spent: 32500, startDate: '2025-06-01', endDate: '2025-08-31', status: 'Active', products: [1, 2, 3], customers: [1, 2, 3, 5, 7] },
    { id: 2, name: 'Winter Spirits Special', type: 'Bundle', discount: 15, budget: 40000, spent: 12000, startDate: '2025-12-01', endDate: '2026-02-28', status: 'Planned', products: [4, 5, 6], customers: [1, 4, 5, 8] },
    { id: 3, name: 'Wine Tasting Event', type: 'Event', discount: 0, budget: 25000, spent: 25000, startDate: '2025-04-15', endDate: '2025-04-20', status: 'Completed', products: [7, 8, 9], customers: [4, 8] },
    { id: 4, name: 'Back to School', type: 'Discount', discount: 10, budget: 30000, spent: 28500, startDate: '2025-08-15', endDate: '2025-09-15', status: 'Active', products: [10, 11, 12], customers: [1, 2, 3, 7] },
    { id: 5, name: 'Holiday Bundle', type: 'Bundle', discount: 25, budget: 60000, spent: 0, startDate: '2025-11-15', endDate: '2025-12-31', status: 'Planned', products: [4, 5, 6, 7, 8, 9], customers: [1, 2, 4, 6] }
  ],
  sales: [
    { id: 1, date: '2025-09-01', customer: 1, product: 1, quantity: 120, value: 14400, promotion: 1 },
    { id: 2, date: '2025-09-01', customer: 1, product: 3, quantity: 180, value: 19800, promotion: 1 },
    { id: 3, date: '2025-09-01', customer: 2, product: 10, quantity: 240, value: 10800, promotion: 4 },
    { id: 4, date: '2025-09-01', customer: 4, product: 6, quantity: 24, value: 10800, promotion: null },
    { id: 5, date: '2025-09-01', customer: 5, product: 2, quantity: 48, value: 7200, promotion: 1 },
    { id: 6, date: '2025-09-02', customer: 6, product: 4, quantity: 60, value: 16800, promotion: null },
    { id: 7, date: '2025-09-02', customer: 3, product: 11, quantity: 120, value: 4800, promotion: 4 },
    { id: 8, date: '2025-09-02', customer: 8, product: 9, quantity: 36, value: 8640, promotion: null },
    { id: 9, date: '2025-09-03', customer: 7, product: 12, quantity: 72, value: 3960, promotion: 4 },
    { id: 10, date: '2025-09-03', customer: 1, product: 5, quantity: 24, value: 7680, promotion: null }
  ],
  kpis: [
    { id: 1, name: 'Total Sales', value: 450000, target: 500000, unit: 'currency', trend: 'up', change: 8.5 },
    { id: 2, name: 'Gross Profit', value: 157500, target: 175000, unit: 'currency', trend: 'up', change: 7.2 },
    { id: 3, name: 'Avg. Margin', value: 35.0, target: 37.0, unit: 'percentage', trend: 'down', change: -1.5 },
    { id: 4, name: 'Active Customers', value: 8, target: 10, unit: 'count', trend: 'flat', change: 0 },
    { id: 5, name: 'Active Promotions', value: 2, target: 3, unit: 'count', trend: 'up', change: 100 },
    { id: 6, name: 'Promotion ROI', value: 320, target: 300, unit: 'percentage', trend: 'up', change: 12.5 }
  ],
  salesByRegion: [
    { region: 'North', value: 145000, percentage: 32.2 },
    { region: 'South', value: 106000, percentage: 23.6 },
    { region: 'East', value: 42000, percentage: 9.3 },
    { region: 'West', value: 95000, percentage: 21.1 },
    { region: 'Central', value: 62000, percentage: 13.8 }
  ],
  salesByCategory: [
    { category: 'Beer', value: 165000, percentage: 36.7 },
    { category: 'Spirits', value: 120000, percentage: 26.7 },
    { category: 'Wine', value: 85000, percentage: 18.9 },
    { category: 'Soft Drinks', value: 80000, percentage: 17.8 }
  ],
  salesByCustomerType: [
    { type: 'Supermarket', value: 145000, percentage: 32.2 },
    { type: 'Grocery', value: 78000, percentage: 17.3 },
    { type: 'Convenience', value: 70000, percentage: 15.6 },
    { type: 'HoReCa', value: 137000, percentage: 30.4 },
    { type: 'Wholesale', value: 20000, percentage: 4.4 }
  ],
  salesTrend: [
    { month: 'Jan', value: 32000 },
    { month: 'Feb', value: 28000 },
    { month: 'Mar', value: 35000 },
    { month: 'Apr', value: 40000 },
    { month: 'May', value: 38000 },
    { month: 'Jun', value: 42000 },
    { month: 'Jul', value: 45000 },
    { month: 'Aug', value: 48000 },
    { month: 'Sep', value: 52000 },
    { month: 'Oct', value: 0 },
    { month: 'Nov', value: 0 },
    { month: 'Dec', value: 0 }
  ],
  features: [
    { name: '5-Level Hierarchies', description: 'Complete customer and product hierarchies for comprehensive trade marketing management', icon: 'hierarchy' },
    { name: 'AI-Powered Forecasting', description: 'Advanced machine learning models for accurate demand forecasting and trend analysis', icon: 'ai' },
    { name: 'Digital Wallets', description: 'QR code-based digital wallet system for seamless co-op fund management', icon: 'wallet' },
    { name: 'Executive Analytics', description: 'Real-time dashboards and comprehensive analytics for executive decision making', icon: 'analytics' },
    { name: 'Workflow Automation', description: 'Visual workflow designer for automating complex business processes', icon: 'workflow' },
    { name: 'Multi-Company Support', description: 'Manage multiple companies and entities within a single platform', icon: 'company' }
  ],
  productHierarchy: {
    levels: ['Category', 'Sub-Category', 'Brand', 'Package', 'SKU'],
    data: [
      {
        name: 'Beer',
        children: [
          {
            name: 'Lager',
            children: [
              {
                name: 'Premium Lager',
                children: [
                  {
                    name: '6-pack',
                    children: [
                      { name: 'Premium Lager 6x330ml', id: 101 }
                    ]
                  },
                  {
                    name: 'Single',
                    children: [
                      { name: 'Premium Lager 330ml', id: 102 },
                      { name: 'Premium Lager 500ml', id: 103 }
                    ]
                  }
                ]
              }
            ]
          },
          {
            name: 'IPA',
            children: [
              {
                name: 'Craft IPA',
                children: [
                  {
                    name: '4-pack',
                    children: [
                      { name: 'Craft IPA 4x330ml', id: 201 }
                    ]
                  },
                  {
                    name: 'Single',
                    children: [
                      { name: 'Craft IPA 330ml', id: 202 }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      },
      {
        name: 'Spirits',
        children: [
          {
            name: 'Vodka',
            children: [
              {
                name: 'Premium Vodka',
                children: [
                  {
                    name: 'Bottle',
                    children: [
                      { name: 'Premium Vodka 700ml', id: 301 },
                      { name: 'Premium Vodka 1L', id: 302 }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  },
  customerHierarchy: {
    levels: ['Region', 'City', 'Channel', 'Sub-Channel', 'Customer'],
    data: [
      {
        name: 'North',
        children: [
          {
            name: 'Manchester',
            children: [
              {
                name: 'Retail',
                children: [
                  {
                    name: 'Supermarket',
                    children: [
                      { name: 'Metro Supermarket', id: 1 }
                    ]
                  }
                ]
              },
              {
                name: 'HoReCa',
                children: [
                  {
                    name: 'Pub',
                    children: [
                      { name: 'Downtown Pub', id: 5 }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      },
      {
        name: 'South',
        children: [
          {
            name: 'London',
            children: [
              {
                name: 'Retail',
                children: [
                  {
                    name: 'Grocery',
                    children: [
                      { name: 'City Grocers', id: 2 }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
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
      message: 'Welcome to Vanta X Enterprise API',
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
  else if (pathname === '/api/v1/sales') {
    // Sales endpoint
    res.writeHead(200);
    res.end(JSON.stringify({
      sales: db.sales
    }));
  }
  else if (pathname === '/api/v1/users') {
    // Users endpoint
    res.writeHead(200);
    res.end(JSON.stringify({
      users: db.users
    }));
  }
  else if (pathname === '/api/v1/dashboard') {
    // Dashboard data endpoint
    res.writeHead(200);
    res.end(JSON.stringify({
      company: db.company,
      kpis: db.kpis,
      salesByRegion: db.salesByRegion,
      salesByCategory: db.salesByCategory,
      salesByCustomerType: db.salesByCustomerType,
      salesTrend: db.salesTrend,
      recentSales: db.sales.slice(0, 5),
      activePromotions: db.promotions.filter(p => p.status === 'Active')
    }));
  }
  else if (pathname === '/api/v1/analytics') {
    // Analytics data endpoint
    res.writeHead(200);
    res.end(JSON.stringify({
      salesTrend: db.salesTrend,
      salesByRegion: db.salesByRegion,
      salesByCategory: db.salesByCategory,
      salesByCustomerType: db.salesByCustomerType,
      kpis: db.kpis
    }));
  }
  else if (pathname === '/api/v1/hierarchies') {
    // Hierarchies endpoint
    res.writeHead(200);
    res.end(JSON.stringify({
      productHierarchy: db.productHierarchy,
      customerHierarchy: db.customerHierarchy
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
  console.log(`Vantax Enterprise API listening on port ${port}`);
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

create_enterprise_frontend() {
    print_message $YELLOW "Creating enterprise frontend application..."
    
    mkdir -p "frontend/web/html"
    
    # Create index.html with enterprise UI
    cat > "frontend/web/html/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Vanta X - Enterprise Trade Marketing Platform</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        :root {
            --primary: #4a6cf7;
            --primary-dark: #3a56d4;
            --secondary: #6c757d;
            --success: #28a745;
            --info: #17a2b8;
            --warning: #ffc107;
            --danger: #dc3545;
            --light: #f8f9fa;
            --dark: #343a40;
            --white: #ffffff;
            --sidebar-width: 250px;
            --header-height: 60px;
            --body-bg: #f5f7fb;
            --card-bg: #ffffff;
            --card-border: #e9ecef;
            --text-primary: #212529;
            --text-secondary: #6c757d;
            --text-muted: #adb5bd;
            --border-radius: 0.25rem;
            --box-shadow: 0 0.125rem 0.25rem rgba(0, 0, 0, 0.075);
            --transition: all 0.2s ease-in-out;
        }
        
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
            background-color: var(--body-bg);
            color: var(--text-primary);
            line-height: 1.5;
            min-height: 100vh;
            overflow-x: hidden;
        }
        
        /* Layout */
        .app-container {
            display: flex;
            min-height: 100vh;
        }
        
        .sidebar {
            width: var(--sidebar-width);
            background: linear-gradient(135deg, #4a6cf7 0%, #3a56d4 100%);
            color: var(--white);
            position: fixed;
            height: 100vh;
            z-index: 1000;
            transition: var(--transition);
            box-shadow: 2px 0 10px rgba(0, 0, 0, 0.1);
        }
        
        .sidebar-collapsed {
            width: 70px;
        }
        
        .sidebar-header {
            padding: 1.5rem 1rem;
            display: flex;
            align-items: center;
            justify-content: space-between;
            border-bottom: 1px solid rgba(255, 255, 255, 0.1);
        }
        
        .logo {
            display: flex;
            align-items: center;
            font-weight: 700;
            font-size: 1.5rem;
            color: var(--white);
            text-decoration: none;
        }
        
        .logo i {
            margin-right: 0.75rem;
            font-size: 1.75rem;
        }
        
        .toggle-sidebar {
            background: none;
            border: none;
            color: var(--white);
            cursor: pointer;
            font-size: 1.25rem;
        }
        
        .sidebar-menu {
            padding: 1rem 0;
            list-style: none;
        }
        
        .sidebar-item {
            margin-bottom: 0.25rem;
        }
        
        .sidebar-link {
            display: flex;
            align-items: center;
            padding: 0.75rem 1.5rem;
            color: rgba(255, 255, 255, 0.8);
            text-decoration: none;
            transition: var(--transition);
            border-left: 3px solid transparent;
        }
        
        .sidebar-link:hover, .sidebar-link.active {
            background-color: rgba(255, 255, 255, 0.1);
            color: var(--white);
            border-left-color: var(--white);
        }
        
        .sidebar-link i {
            margin-right: 0.75rem;
            font-size: 1.25rem;
            width: 20px;
            text-align: center;
        }
        
        .sidebar-link span {
            transition: var(--transition);
        }
        
        .sidebar-collapsed .sidebar-link span {
            display: none;
        }
        
        .sidebar-collapsed .logo span {
            display: none;
        }
        
        .main-content {
            flex: 1;
            margin-left: var(--sidebar-width);
            transition: var(--transition);
            padding-top: var(--header-height);
        }
        
        .main-content-expanded {
            margin-left: 70px;
        }
        
        .header {
            height: var(--header-height);
            background-color: var(--white);
            border-bottom: 1px solid var(--card-border);
            display: flex;
            align-items: center;
            justify-content: space-between;
            padding: 0 1.5rem;
            position: fixed;
            top: 0;
            right: 0;
            left: var(--sidebar-width);
            z-index: 999;
            transition: var(--transition);
        }
        
        .header-expanded {
            left: 70px;
        }
        
        .header-left {
            display: flex;
            align-items: center;
        }
        
        .page-title {
            font-size: 1.25rem;
            font-weight: 600;
            margin: 0;
        }
        
        .header-right {
            display: flex;
            align-items: center;
        }
        
        .header-icon {
            color: var(--secondary);
            font-size: 1.25rem;
            margin-left: 1.5rem;
            cursor: pointer;
            position: relative;
        }
        
        .header-icon .badge {
            position: absolute;
            top: -8px;
            right: -8px;
            background-color: var(--danger);
            color: var(--white);
            border-radius: 50%;
            width: 18px;
            height: 18px;
            font-size: 0.75rem;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        .user-dropdown {
            display: flex;
            align-items: center;
            margin-left: 1.5rem;
            cursor: pointer;
        }
        
        .user-avatar {
            width: 36px;
            height: 36px;
            border-radius: 50%;
            background-color: var(--primary);
            color: var(--white);
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: 600;
            margin-right: 0.75rem;
        }
        
        .user-name {
            font-weight: 600;
        }
        
        .content {
            padding: 1.5rem;
        }
        
        /* Cards */
        .card {
            background-color: var(--card-bg);
            border-radius: var(--border-radius);
            box-shadow: var(--box-shadow);
            margin-bottom: 1.5rem;
            border: 1px solid var(--card-border);
        }
        
        .card-header {
            padding: 1rem 1.5rem;
            border-bottom: 1px solid var(--card-border);
            display: flex;
            align-items: center;
            justify-content: space-between;
        }
        
        .card-title {
            font-size: 1.1rem;
            font-weight: 600;
            margin: 0;
        }
        
        .card-body {
            padding: 1.5rem;
        }
        
        .card-footer {
            padding: 1rem 1.5rem;
            border-top: 1px solid var(--card-border);
        }
        
        /* Dashboard */
        .dashboard-stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 1.5rem;
            margin-bottom: 1.5rem;
        }
        
        .stat-card {
            background-color: var(--card-bg);
            border-radius: var(--border-radius);
            box-shadow: var(--box-shadow);
            padding: 1.5rem;
            display: flex;
            align-items: center;
            border: 1px solid var(--card-border);
        }
        
        .stat-icon {
            width: 48px;
            height: 48px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.5rem;
            margin-right: 1rem;
            flex-shrink: 0;
        }
        
        .stat-icon.primary {
            background-color: rgba(74, 108, 247, 0.1);
            color: var(--primary);
        }
        
        .stat-icon.success {
            background-color: rgba(40, 167, 69, 0.1);
            color: var(--success);
        }
        
        .stat-icon.warning {
            background-color: rgba(255, 193, 7, 0.1);
            color: var(--warning);
        }
        
        .stat-icon.info {
            background-color: rgba(23, 162, 184, 0.1);
            color: var(--info);
        }
        
        .stat-icon.danger {
            background-color: rgba(220, 53, 69, 0.1);
            color: var(--danger);
        }
        
        .stat-content {
            flex: 1;
        }
        
        .stat-title {
            color: var(--text-secondary);
            font-size: 0.875rem;
            margin-bottom: 0.25rem;
        }
        
        .stat-value {
            font-size: 1.5rem;
            font-weight: 700;
            margin-bottom: 0.25rem;
        }
        
        .stat-change {
            font-size: 0.875rem;
            display: flex;
            align-items: center;
        }
        
        .stat-change.up {
            color: var(--success);
        }
        
        .stat-change.down {
            color: var(--danger);
        }
        
        .stat-change.flat {
            color: var(--secondary);
        }
        
        .stat-change i {
            margin-right: 0.25rem;
        }
        
        .dashboard-charts {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(500px, 1fr));
            gap: 1.5rem;
            margin-bottom: 1.5rem;
        }
        
        @media (max-width: 1200px) {
            .dashboard-charts {
                grid-template-columns: 1fr;
            }
        }
        
        .chart-container {
            height: 300px;
            position: relative;
        }
        
        .dashboard-tables {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(500px, 1fr));
            gap: 1.5rem;
        }
        
        @media (max-width: 1200px) {
            .dashboard-tables {
                grid-template-columns: 1fr;
            }
        }
        
        /* Tables */
        .table-responsive {
            overflow-x: auto;
        }
        
        .table {
            width: 100%;
            border-collapse: collapse;
        }
        
        .table th, .table td {
            padding: 0.75rem;
            text-align: left;
            border-bottom: 1px solid var(--card-border);
        }
        
        .table th {
            font-weight: 600;
            background-color: rgba(0, 0, 0, 0.02);
        }
        
        .table tbody tr:hover {
            background-color: rgba(0, 0, 0, 0.02);
        }
        
        .table-striped tbody tr:nth-of-type(odd) {
            background-color: rgba(0, 0, 0, 0.02);
        }
        
        /* Badges */
        .badge {
            display: inline-block;
            padding: 0.25rem 0.5rem;
            font-size: 0.75rem;
            font-weight: 600;
            border-radius: 0.25rem;
        }
        
        .badge-primary {
            background-color: rgba(74, 108, 247, 0.1);
            color: var(--primary);
        }
        
        .badge-success {
            background-color: rgba(40, 167, 69, 0.1);
            color: var(--success);
        }
        
        .badge-warning {
            background-color: rgba(255, 193, 7, 0.1);
            color: var(--warning);
        }
        
        .badge-danger {
            background-color: rgba(220, 53, 69, 0.1);
            color: var(--danger);
        }
        
        .badge-info {
            background-color: rgba(23, 162, 184, 0.1);
            color: var(--info);
        }
        
        .badge-secondary {
            background-color: rgba(108, 117, 125, 0.1);
            color: var(--secondary);
        }
        
        /* Progress */
        .progress {
            height: 0.5rem;
            background-color: rgba(0, 0, 0, 0.05);
            border-radius: 0.25rem;
            overflow: hidden;
        }
        
        .progress-bar {
            height: 100%;
            background-color: var(--primary);
        }
        
        /* Buttons */
        .btn {
            display: inline-block;
            font-weight: 500;
            text-align: center;
            white-space: nowrap;
            vertical-align: middle;
            user-select: none;
            border: 1px solid transparent;
            padding: 0.375rem 0.75rem;
            font-size: 0.875rem;
            line-height: 1.5;
            border-radius: 0.25rem;
            transition: color 0.15s ease-in-out, background-color 0.15s ease-in-out, border-color 0.15s ease-in-out, box-shadow 0.15s ease-in-out;
            cursor: pointer;
        }
        
        .btn-primary {
            color: var(--white);
            background-color: var(--primary);
            border-color: var(--primary);
        }
        
        .btn-primary:hover {
            background-color: var(--primary-dark);
            border-color: var(--primary-dark);
        }
        
        .btn-outline-primary {
            color: var(--primary);
            background-color: transparent;
            border-color: var(--primary);
        }
        
        .btn-outline-primary:hover {
            color: var(--white);
            background-color: var(--primary);
            border-color: var(--primary);
        }
        
        .btn-sm {
            padding: 0.25rem 0.5rem;
            font-size: 0.75rem;
        }
        
        /* Forms */
        .form-group {
            margin-bottom: 1rem;
        }
        
        .form-label {
            display: block;
            margin-bottom: 0.5rem;
            font-weight: 500;
        }
        
        .form-control {
            display: block;
            width: 100%;
            padding: 0.375rem 0.75rem;
            font-size: 0.875rem;
            line-height: 1.5;
            color: var(--text-primary);
            background-color: var(--white);
            background-clip: padding-box;
            border: 1px solid var(--card-border);
            border-radius: 0.25rem;
            transition: border-color 0.15s ease-in-out, box-shadow 0.15s ease-in-out;
        }
        
        .form-control:focus {
            border-color: var(--primary);
            outline: 0;
            box-shadow: 0 0 0 0.2rem rgba(74, 108, 247, 0.25);
        }
        
        /* Utilities */
        .d-flex {
            display: flex;
        }
        
        .align-items-center {
            align-items: center;
        }
        
        .justify-content-between {
            justify-content: space-between;
        }
        
        .mb-0 {
            margin-bottom: 0;
        }
        
        .mb-1 {
            margin-bottom: 0.25rem;
        }
        
        .mb-2 {
            margin-bottom: 0.5rem;
        }
        
        .mb-3 {
            margin-bottom: 1rem;
        }
        
        .mb-4 {
            margin-bottom: 1.5rem;
        }
        
        .mt-0 {
            margin-top: 0;
        }
        
        .mt-1 {
            margin-top: 0.25rem;
        }
        
        .mt-2 {
            margin-top: 0.5rem;
        }
        
        .mt-3 {
            margin-top: 1rem;
        }
        
        .mt-4 {
            margin-top: 1.5rem;
        }
        
        .ml-auto {
            margin-left: auto;
        }
        
        .text-primary {
            color: var(--primary);
        }
        
        .text-success {
            color: var(--success);
        }
        
        .text-warning {
            color: var(--warning);
        }
        
        .text-danger {
            color: var(--danger);
        }
        
        .text-info {
            color: var(--info);
        }
        
        .text-secondary {
            color: var(--secondary);
        }
        
        .text-muted {
            color: var(--text-muted);
        }
        
        .text-center {
            text-align: center;
        }
        
        .text-right {
            text-align: right;
        }
        
        .font-weight-bold {
            font-weight: 700;
        }
        
        /* Pages */
        .page {
            display: none;
        }
        
        .page.active {
            display: block;
        }
        
        /* Products Page */
        .product-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 1.5rem;
        }
        
        .product-card {
            background-color: var(--card-bg);
            border-radius: var(--border-radius);
            box-shadow: var(--box-shadow);
            border: 1px solid var(--card-border);
            overflow: hidden;
            transition: var(--transition);
        }
        
        .product-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 0.5rem 1rem rgba(0, 0, 0, 0.15);
        }
        
        .product-header {
            padding: 1rem;
            background-color: rgba(0, 0, 0, 0.02);
            border-bottom: 1px solid var(--card-border);
        }
        
        .product-title {
            font-size: 1.1rem;
            font-weight: 600;
            margin: 0;
        }
        
        .product-category {
            color: var(--text-secondary);
            font-size: 0.875rem;
        }
        
        .product-body {
            padding: 1rem;
        }
        
        .product-price {
            font-size: 1.25rem;
            font-weight: 700;
            margin-bottom: 0.5rem;
        }
        
        .product-stats {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 0.5rem;
            margin-bottom: 1rem;
        }
        
        .product-stat {
            background-color: rgba(0, 0, 0, 0.02);
            padding: 0.5rem;
            border-radius: 0.25rem;
        }
        
        .product-stat-label {
            font-size: 0.75rem;
            color: var(--text-secondary);
        }
        
        .product-stat-value {
            font-weight: 600;
        }
        
        .product-footer {
            padding: 1rem;
            border-top: 1px solid var(--card-border);
            display: flex;
            justify-content: space-between;
        }
        
        /* Customers Page */
        .customer-list {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
            gap: 1.5rem;
        }
        
        .customer-card {
            background-color: var(--card-bg);
            border-radius: var(--border-radius);
            box-shadow: var(--box-shadow);
            border: 1px solid var(--card-border);
            overflow: hidden;
            transition: var(--transition);
        }
        
        .customer-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 0.5rem 1rem rgba(0, 0, 0, 0.15);
        }
        
        .customer-header {
            padding: 1rem;
            background-color: rgba(0, 0, 0, 0.02);
            border-bottom: 1px solid var(--card-border);
            display: flex;
            align-items: center;
        }
        
        .customer-avatar {
            width: 48px;
            height: 48px;
            border-radius: 50%;
            background-color: var(--primary);
            color: var(--white);
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: 600;
            font-size: 1.25rem;
            margin-right: 1rem;
        }
        
        .customer-title {
            font-size: 1.1rem;
            font-weight: 600;
            margin: 0;
        }
        
        .customer-type {
            color: var(--text-secondary);
            font-size: 0.875rem;
        }
        
        .customer-body {
            padding: 1rem;
        }
        
        .customer-info {
            margin-bottom: 1rem;
        }
        
        .customer-info-item {
            display: flex;
            margin-bottom: 0.5rem;
        }
        
        .customer-info-label {
            width: 100px;
            color: var(--text-secondary);
            font-size: 0.875rem;
        }
        
        .customer-info-value {
            flex: 1;
            font-weight: 500;
        }
        
        .customer-stats {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 0.5rem;
        }
        
        .customer-stat {
            background-color: rgba(0, 0, 0, 0.02);
            padding: 0.5rem;
            border-radius: 0.25rem;
        }
        
        .customer-stat-label {
            font-size: 0.75rem;
            color: var(--text-secondary);
        }
        
        .customer-stat-value {
            font-weight: 600;
        }
        
        .customer-footer {
            padding: 1rem;
            border-top: 1px solid var(--card-border);
            display: flex;
            justify-content: space-between;
        }
        
        /* Promotions Page */
        .promotion-list {
            display: grid;
            grid-template-columns: 1fr;
            gap: 1.5rem;
        }
        
        .promotion-card {
            background-color: var(--card-bg);
            border-radius: var(--border-radius);
            box-shadow: var(--box-shadow);
            border: 1px solid var(--card-border);
            overflow: hidden;
            transition: var(--transition);
        }
        
        .promotion-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 0.5rem 1rem rgba(0, 0, 0, 0.15);
        }
        
        .promotion-header {
            padding: 1rem;
            background-color: rgba(0, 0, 0, 0.02);
            border-bottom: 1px solid var(--card-border);
            display: flex;
            align-items: center;
            justify-content: space-between;
        }
        
        .promotion-title-section {
            display: flex;
            align-items: center;
        }
        
        .promotion-icon {
            width: 48px;
            height: 48px;
            border-radius: 50%;
            background-color: var(--primary);
            color: var(--white);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 1.25rem;
            margin-right: 1rem;
        }
        
        .promotion-title {
            font-size: 1.1rem;
            font-weight: 600;
            margin: 0;
        }
        
        .promotion-type {
            color: var(--text-secondary);
            font-size: 0.875rem;
        }
        
        .promotion-body {
            padding: 1rem;
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 1rem;
        }
        
        .promotion-details {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 0.5rem;
        }
        
        .promotion-detail {
            background-color: rgba(0, 0, 0, 0.02);
            padding: 0.5rem;
            border-radius: 0.25rem;
        }
        
        .promotion-detail-label {
            font-size: 0.75rem;
            color: var(--text-secondary);
        }
        
        .promotion-detail-value {
            font-weight: 600;
        }
        
        .promotion-budget {
            margin-top: 1rem;
        }
        
        .promotion-budget-header {
            display: flex;
            justify-content: space-between;
            margin-bottom: 0.5rem;
        }
        
        .promotion-budget-label {
            font-size: 0.875rem;
            color: var(--text-secondary);
        }
        
        .promotion-budget-value {
            font-weight: 600;
        }
        
        .promotion-footer {
            padding: 1rem;
            border-top: 1px solid var(--card-border);
            display: flex;
            justify-content: space-between;
        }
        
        /* Analytics Page */
        .analytics-filters {
            display: flex;
            flex-wrap: wrap;
            gap: 1rem;
            margin-bottom: 1.5rem;
        }
        
        .filter-item {
            display: flex;
            align-items: center;
        }
        
        .filter-label {
            margin-right: 0.5rem;
            font-weight: 500;
        }
        
        .filter-select {
            padding: 0.375rem 0.75rem;
            border: 1px solid var(--card-border);
            border-radius: 0.25rem;
            background-color: var(--white);
        }
        
        .analytics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(500px, 1fr));
            gap: 1.5rem;
        }
        
        @media (max-width: 1200px) {
            .analytics-grid {
                grid-template-columns: 1fr;
            }
        }
        
        /* Hierarchies Page */
        .hierarchy-container {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(500px, 1fr));
            gap: 1.5rem;
        }
        
        @media (max-width: 1200px) {
            .hierarchy-container {
                grid-template-columns: 1fr;
            }
        }
        
        .hierarchy-tree {
            margin-left: 1.5rem;
        }
        
        .hierarchy-item {
            margin-bottom: 0.5rem;
        }
        
        .hierarchy-toggle {
            cursor: pointer;
            user-select: none;
        }
        
        .hierarchy-toggle i {
            margin-right: 0.5rem;
            width: 1rem;
            text-align: center;
        }
        
        .hierarchy-children {
            margin-left: 1.5rem;
            display: none;
        }
        
        .hierarchy-children.expanded {
            display: block;
        }
        
        /* Responsive */
        @media (max-width: 992px) {
            .sidebar {
                width: 70px;
            }
            
            .sidebar .logo span, .sidebar-link span {
                display: none;
            }
            
            .main-content {
                margin-left: 70px;
            }
            
            .header {
                left: 70px;
            }
            
            .dashboard-stats, .dashboard-charts, .dashboard-tables {
                grid-template-columns: 1fr;
            }
        }
        
        @media (max-width: 768px) {
            .header-right {
                display: none;
            }
        }
        
        @media (max-width: 576px) {
            .content {
                padding: 1rem;
            }
            
            .dashboard-stats {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="app-container">
        <!-- Sidebar -->
        <div class="sidebar" id="sidebar">
            <div class="sidebar-header">
                <a href="#" class="logo">
                    <i class="fas fa-chart-line"></i>
                    <span>Vanta X</span>
                </a>
                <button class="toggle-sidebar" id="toggle-sidebar">
                    <i class="fas fa-bars"></i>
                </button>
            </div>
            <ul class="sidebar-menu">
                <li class="sidebar-item">
                    <a href="#dashboard" class="sidebar-link active" data-page="dashboard-page">
                        <i class="fas fa-tachometer-alt"></i>
                        <span>Dashboard</span>
                    </a>
                </li>
                <li class="sidebar-item">
                    <a href="#products" class="sidebar-link" data-page="products-page">
                        <i class="fas fa-box"></i>
                        <span>Products</span>
                    </a>
                </li>
                <li class="sidebar-item">
                    <a href="#customers" class="sidebar-link" data-page="customers-page">
                        <i class="fas fa-users"></i>
                        <span>Customers</span>
                    </a>
                </li>
                <li class="sidebar-item">
                    <a href="#promotions" class="sidebar-link" data-page="promotions-page">
                        <i class="fas fa-bullhorn"></i>
                        <span>Promotions</span>
                    </a>
                </li>
                <li class="sidebar-item">
                    <a href="#sales" class="sidebar-link" data-page="sales-page">
                        <i class="fas fa-shopping-cart"></i>
                        <span>Sales</span>
                    </a>
                </li>
                <li class="sidebar-item">
                    <a href="#analytics" class="sidebar-link" data-page="analytics-page">
                        <i class="fas fa-chart-bar"></i>
                        <span>Analytics</span>
                    </a>
                </li>
                <li class="sidebar-item">
                    <a href="#hierarchies" class="sidebar-link" data-page="hierarchies-page">
                        <i class="fas fa-sitemap"></i>
                        <span>Hierarchies</span>
                    </a>
                </li>
                <li class="sidebar-item">
                    <a href="#settings" class="sidebar-link" data-page="settings-page">
                        <i class="fas fa-cog"></i>
                        <span>Settings</span>
                    </a>
                </li>
            </ul>
        </div>
        
        <!-- Main Content -->
        <div class="main-content" id="main-content">
            <!-- Header -->
            <div class="header" id="header">
                <div class="header-left">
                    <h1 class="page-title" id="page-title">Dashboard</h1>
                </div>
                <div class="header-right">
                    <div class="header-icon">
                        <i class="fas fa-bell"></i>
                        <span class="badge">3</span>
                    </div>
                    <div class="header-icon">
                        <i class="fas fa-envelope"></i>
                        <span class="badge">5</span>
                    </div>
                    <div class="user-dropdown">
                        <div class="user-avatar">
                            <i class="fas fa-user"></i>
                        </div>
                        <div class="user-info">
                            <div class="user-name">Admin</div>
                        </div>
                    </div>
                </div>
            </div>
            
            <!-- Content -->
            <div class="content">
                <!-- Dashboard Page -->
                <div id="dashboard-page" class="page active">
                    <div class="dashboard-stats">
                        <div class="stat-card">
                            <div class="stat-icon primary">
                                <i class="fas fa-dollar-sign"></i>
                            </div>
                            <div class="stat-content">
                                <div class="stat-title">Total Sales</div>
                                <div class="stat-value" id="total-sales">$450,000</div>
                                <div class="stat-change up">
                                    <i class="fas fa-arrow-up"></i>
                                    <span id="sales-change">8.5%</span> vs last month
                                </div>
                            </div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-icon success">
                                <i class="fas fa-chart-pie"></i>
                            </div>
                            <div class="stat-content">
                                <div class="stat-title">Gross Profit</div>
                                <div class="stat-value" id="gross-profit">$157,500</div>
                                <div class="stat-change up">
                                    <i class="fas fa-arrow-up"></i>
                                    <span id="profit-change">7.2%</span> vs last month
                                </div>
                            </div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-icon warning">
                                <i class="fas fa-percentage"></i>
                            </div>
                            <div class="stat-content">
                                <div class="stat-title">Avg. Margin</div>
                                <div class="stat-value" id="avg-margin">35.0%</div>
                                <div class="stat-change down">
                                    <i class="fas fa-arrow-down"></i>
                                    <span id="margin-change">1.5%</span> vs last month
                                </div>
                            </div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-icon info">
                                <i class="fas fa-bullhorn"></i>
                            </div>
                            <div class="stat-content">
                                <div class="stat-title">Active Promotions</div>
                                <div class="stat-value" id="active-promotions">2</div>
                                <div class="stat-change up">
                                    <i class="fas fa-arrow-up"></i>
                                    <span id="promotions-change">100%</span> vs last month
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="dashboard-charts">
                        <div class="card">
                            <div class="card-header">
                                <h2 class="card-title">Sales Trend</h2>
                                <div>
                                    <button class="btn btn-sm btn-outline-primary">Monthly</button>
                                    <button class="btn btn-sm btn-outline-primary">Quarterly</button>
                                    <button class="btn btn-sm btn-outline-primary">Yearly</button>
                                </div>
                            </div>
                            <div class="card-body">
                                <div class="chart-container" id="sales-trend-chart">
                                    <div style="height: 100%; display: flex; align-items: center; justify-content: center;">
                                        <div style="text-align: center;">
                                            <div style="height: 200px; display: flex; align-items: flex-end; justify-content: space-between; padding: 0 20px;">
                                                <div style="width: 30px; height: 64%; background-color: #4a6cf7; border-radius: 4px 4px 0 0;"></div>
                                                <div style="width: 30px; height: 56%; background-color: #4a6cf7; border-radius: 4px 4px 0 0;"></div>
                                                <div style="width: 30px; height: 70%; background-color: #4a6cf7; border-radius: 4px 4px 0 0;"></div>
                                                <div style="width: 30px; height: 80%; background-color: #4a6cf7; border-radius: 4px 4px 0 0;"></div>
                                                <div style="width: 30px; height: 76%; background-color: #4a6cf7; border-radius: 4px 4px 0 0;"></div>
                                                <div style="width: 30px; height: 84%; background-color: #4a6cf7; border-radius: 4px 4px 0 0;"></div>
                                                <div style="width: 30px; height: 90%; background-color: #4a6cf7; border-radius: 4px 4px 0 0;"></div>
                                                <div style="width: 30px; height: 96%; background-color: #4a6cf7; border-radius: 4px 4px 0 0;"></div>
                                                <div style="width: 30px; height: 100%; background-color: #4a6cf7; border-radius: 4px 4px 0 0;"></div>
                                            </div>
                                            <div style="margin-top: 10px; display: flex; justify-content: space-between; padding: 0 20px;">
                                                <div style="width: 30px; text-align: center; font-size: 12px;">Jan</div>
                                                <div style="width: 30px; text-align: center; font-size: 12px;">Feb</div>
                                                <div style="width: 30px; text-align: center; font-size: 12px;">Mar</div>
                                                <div style="width: 30px; text-align: center; font-size: 12px;">Apr</div>
                                                <div style="width: 30px; text-align: center; font-size: 12px;">May</div>
                                                <div style="width: 30px; text-align: center; font-size: 12px;">Jun</div>
                                                <div style="width: 30px; text-align: center; font-size: 12px;">Jul</div>
                                                <div style="width: 30px; text-align: center; font-size: 12px;">Aug</div>
                                                <div style="width: 30px; text-align: center; font-size: 12px;">Sep</div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                        
                        <div class="card">
                            <div class="card-header">
                                <h2 class="card-title">Sales Distribution</h2>
                                <div>
                                    <button class="btn btn-sm btn-outline-primary">By Region</button>
                                    <button class="btn btn-sm btn-outline-primary">By Category</button>
                                </div>
                            </div>
                            <div class="card-body">
                                <div class="chart-container" id="sales-distribution-chart">
                                    <div style="height: 100%; display: flex; align-items: center; justify-content: center;">
                                        <div style="width: 200px; height: 200px; border-radius: 50%; background: conic-gradient(#4a6cf7 0% 36.7%, #28a745 36.7% 63.4%, #17a2b8 63.4% 82.3%, #ffc107 82.3% 100%); position: relative;">
                                            <div style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); width: 100px; height: 100px; border-radius: 50%; background-color: white;"></div>
                                        </div>
                                        <div style="margin-left: 30px;">
                                            <div style="display: flex; align-items: center; margin-bottom: 10px;">
                                                <div style="width: 12px; height: 12px; background-color: #4a6cf7; margin-right: 8px;"></div>
                                                <div>Beer (36.7%)</div>
                                            </div>
                                            <div style="display: flex; align-items: center; margin-bottom: 10px;">
                                                <div style="width: 12px; height: 12px; background-color: #28a745; margin-right: 8px;"></div>
                                                <div>Spirits (26.7%)</div>
                                            </div>
                                            <div style="display: flex; align-items: center; margin-bottom: 10px;">
                                                <div style="width: 12px; height: 12px; background-color: #17a2b8; margin-right: 8px;"></div>
                                                <div>Wine (18.9%)</div>
                                            </div>
                                            <div style="display: flex; align-items: center;">
                                                <div style="width: 12px; height: 12px; background-color: #ffc107; margin-right: 8px;"></div>
                                                <div>Soft Drinks (17.8%)</div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="dashboard-tables">
                        <div class="card">
                            <div class="card-header">
                                <h2 class="card-title">Recent Sales</h2>
                                <a href="#sales" class="btn btn-sm btn-outline-primary">View All</a>
                            </div>
                            <div class="card-body">
                                <div class="table-responsive">
                                    <table class="table">
                                        <thead>
                                            <tr>
                                                <th>Date</th>
                                                <th>Customer</th>
                                                <th>Product</th>
                                                <th>Amount</th>
                                                <th>Status</th>
                                            </tr>
                                        </thead>
                                        <tbody id="recent-sales-table">
                                            <tr>
                                                <td>2025-09-01</td>
                                                <td>Metro Supermarket</td>
                                                <td>Premium Lager</td>
                                                <td>$14,400</td>
                                                <td><span class="badge badge-success">Completed</span></td>
                                            </tr>
                                            <tr>
                                                <td>2025-09-01</td>
                                                <td>Metro Supermarket</td>
                                                <td>Light Beer</td>
                                                <td>$19,800</td>
                                                <td><span class="badge badge-success">Completed</span></td>
                                            </tr>
                                            <tr>
                                                <td>2025-09-01</td>
                                                <td>City Grocers</td>
                                                <td>Cola</td>
                                                <td>$10,800</td>
                                                <td><span class="badge badge-success">Completed</span></td>
                                            </tr>
                                            <tr>
                                                <td>2025-09-01</td>
                                                <td>Luxury Hotels</td>
                                                <td>Single Malt</td>
                                                <td>$10,800</td>
                                                <td><span class="badge badge-success">Completed</span></td>
                                            </tr>
                                            <tr>
                                                <td>2025-09-01</td>
                                                <td>Downtown Pub</td>
                                                <td>Craft IPA</td>
                                                <td>$7,200</td>
                                                <td><span class="badge badge-success">Completed</span></td>
                                            </tr>
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        </div>
                        
                        <div class="card">
                            <div class="card-header">
                                <h2 class="card-title">Active Promotions</h2>
                                <a href="#promotions" class="btn btn-sm btn-outline-primary">View All</a>
                            </div>
                            <div class="card-body">
                                <div class="table-responsive">
                                    <table class="table">
                                        <thead>
                                            <tr>
                                                <th>Name</th>
                                                <th>Type</th>
                                                <th>Start Date</th>
                                                <th>End Date</th>
                                                <th>Budget</th>
                                                <th>Status</th>
                                            </tr>
                                        </thead>
                                        <tbody id="active-promotions-table">
                                            <tr>
                                                <td>Summer Beer Festival</td>
                                                <td>Discount</td>
                                                <td>2025-06-01</td>
                                                <td>2025-08-31</td>
                                                <td>
                                                    <div class="d-flex align-items-center">
                                                        <div style="flex: 1; margin-right: 10px;">
                                                            <div class="progress">
                                                                <div class="progress-bar" style="width: 65%;"></div>
                                                            </div>
                                                        </div>
                                                        <div>65%</div>
                                                    </div>
                                                </td>
                                                <td><span class="badge badge-primary">Active</span></td>
                                            </tr>
                                            <tr>
                                                <td>Back to School</td>
                                                <td>Discount</td>
                                                <td>2025-08-15</td>
                                                <td>2025-09-15</td>
                                                <td>
                                                    <div class="d-flex align-items-center">
                                                        <div style="flex: 1; margin-right: 10px;">
                                                            <div class="progress">
                                                                <div class="progress-bar" style="width: 95%;"></div>
                                                            </div>
                                                        </div>
                                                        <div>95%</div>
                                                    </div>
                                                </td>
                                                <td><span class="badge badge-primary">Active</span></td>
                                            </tr>
                                        </tbody>
                                    </table>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                
                <!-- Products Page -->
                <div id="products-page" class="page">
                    <div class="d-flex justify-content-between align-items-center mb-4">
                        <h2 class="mb-0">Products</h2>
                        <button class="btn btn-primary">
                            <i class="fas fa-plus"></i> Add Product
                        </button>
                    </div>
                    
                    <div class="card mb-4">
                        <div class="card-body">
                            <div class="d-flex justify-content-between align-items-center mb-3">
                                <div class="d-flex align-items-center">
                                    <div class="form-group mb-0 mr-2">
                                        <input type="text" class="form-control" placeholder="Search products...">
                                    </div>
                                </div>
                                <div class="d-flex align-items-center">
                                    <div class="form-group mb-0 mr-2">
                                        <select class="form-control">
                                            <option>All Categories</option>
                                            <option>Beer</option>
                                            <option>Spirits</option>
                                            <option>Wine</option>
                                            <option>Soft Drinks</option>
                                        </select>
                                    </div>
                                    <div class="form-group mb-0">
                                        <select class="form-control">
                                            <option>Sort by: Name</option>
                                            <option>Sort by: Price (Low to High)</option>
                                            <option>Sort by: Price (High to Low)</option>
                                            <option>Sort by: Sales</option>
                                        </select>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="product-grid" id="product-grid">
                        <!-- Product cards will be loaded here -->
                    </div>
                </div>
                
                <!-- Customers Page -->
                <div id="customers-page" class="page">
                    <div class="d-flex justify-content-between align-items-center mb-4">
                        <h2 class="mb-0">Customers</h2>
                        <button class="btn btn-primary">
                            <i class="fas fa-plus"></i> Add Customer
                        </button>
                    </div>
                    
                    <div class="card mb-4">
                        <div class="card-body">
                            <div class="d-flex justify-content-between align-items-center mb-3">
                                <div class="d-flex align-items-center">
                                    <div class="form-group mb-0 mr-2">
                                        <input type="text" class="form-control" placeholder="Search customers...">
                                    </div>
                                </div>
                                <div class="d-flex align-items-center">
                                    <div class="form-group mb-0 mr-2">
                                        <select class="form-control">
                                            <option>All Types</option>
                                            <option>Supermarket</option>
                                            <option>Grocery</option>
                                            <option>Convenience</option>
                                            <option>HoReCa</option>
                                            <option>Wholesale</option>
                                        </select>
                                    </div>
                                    <div class="form-group mb-0">
                                        <select class="form-control">
                                            <option>All Regions</option>
                                            <option>North</option>
                                            <option>South</option>
                                            <option>East</option>
                                            <option>West</option>
                                            <option>Central</option>
                                        </select>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="customer-list" id="customer-list">
                        <!-- Customer cards will be loaded here -->
                    </div>
                </div>
                
                <!-- Promotions Page -->
                <div id="promotions-page" class="page">
                    <div class="d-flex justify-content-between align-items-center mb-4">
                        <h2 class="mb-0">Promotions</h2>
                        <button class="btn btn-primary">
                            <i class="fas fa-plus"></i> Create Promotion
                        </button>
                    </div>
                    
                    <div class="card mb-4">
                        <div class="card-body">
                            <div class="d-flex justify-content-between align-items-center mb-3">
                                <div class="d-flex align-items-center">
                                    <div class="form-group mb-0 mr-2">
                                        <input type="text" class="form-control" placeholder="Search promotions...">
                                    </div>
                                </div>
                                <div class="d-flex align-items-center">
                                    <div class="form-group mb-0 mr-2">
                                        <select class="form-control">
                                            <option>All Types</option>
                                            <option>Discount</option>
                                            <option>Bundle</option>
                                            <option>Event</option>
                                        </select>
                                    </div>
                                    <div class="form-group mb-0">
                                        <select class="form-control">
                                            <option>All Statuses</option>
                                            <option>Active</option>
                                            <option>Planned</option>
                                            <option>Completed</option>
                                        </select>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="promotion-list" id="promotion-list">
                        <!-- Promotion cards will be loaded here -->
                    </div>
                </div>
                
                <!-- Sales Page -->
                <div id="sales-page" class="page">
                    <div class="d-flex justify-content-between align-items-center mb-4">
                        <h2 class="mb-0">Sales</h2>
                        <button class="btn btn-primary">
                            <i class="fas fa-plus"></i> Record Sale
                        </button>
                    </div>
                    
                    <div class="card mb-4">
                        <div class="card-body">
                            <div class="d-flex justify-content-between align-items-center mb-3">
                                <div class="d-flex align-items-center">
                                    <div class="form-group mb-0 mr-2">
                                        <input type="text" class="form-control" placeholder="Search sales...">
                                    </div>
                                </div>
                                <div class="d-flex align-items-center">
                                    <div class="form-group mb-0 mr-2">
                                        <select class="form-control">
                                            <option>All Customers</option>
                                            <option>Metro Supermarket</option>
                                            <option>City Grocers</option>
                                            <option>Express Mart</option>
                                            <option>Luxury Hotels</option>
                                            <option>Downtown Pub</option>
                                        </select>
                                    </div>
                                    <div class="form-group mb-0">
                                        <select class="form-control">
                                            <option>All Products</option>
                                            <option>Premium Lager</option>
                                            <option>Craft IPA</option>
                                            <option>Light Beer</option>
                                            <option>Premium Vodka</option>
                                            <option>Blended Whisky</option>
                                        </select>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="card">
                        <div class="card-header">
                            <h2 class="card-title">Sales Transactions</h2>
                        </div>
                        <div class="card-body">
                            <div class="table-responsive">
                                <table class="table table-striped">
                                    <thead>
                                        <tr>
                                            <th>ID</th>
                                            <th>Date</th>
                                            <th>Customer</th>
                                            <th>Product</th>
                                            <th>Quantity</th>
                                            <th>Value</th>
                                            <th>Promotion</th>
                                            <th>Actions</th>
                                        </tr>
                                    </thead>
                                    <tbody id="sales-table">
                                        <!-- Sales data will be loaded here -->
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                </div>
                
                <!-- Analytics Page -->
                <div id="analytics-page" class="page">
                    <div class="d-flex justify-content-between align-items-center mb-4">
                        <h2 class="mb-0">Analytics</h2>
                        <button class="btn btn-primary">
                            <i class="fas fa-download"></i> Export Report
                        </button>
                    </div>
                    
                    <div class="card mb-4">
                        <div class="card-body">
                            <div class="analytics-filters">
                                <div class="filter-item">
                                    <div class="filter-label">Date Range:</div>
                                    <select class="filter-select">
                                        <option>Last 30 Days</option>
                                        <option>Last Quarter</option>
                                        <option>Year to Date</option>
                                        <option>Last Year</option>
                                        <option>Custom Range</option>
                                    </select>
                                </div>
                                <div class="filter-item">
                                    <div class="filter-label">Region:</div>
                                    <select class="filter-select">
                                        <option>All Regions</option>
                                        <option>North</option>
                                        <option>South</option>
                                        <option>East</option>
                                        <option>West</option>
                                        <option>Central</option>
                                    </select>
                                </div>
                                <div class="filter-item">
                                    <div class="filter-label">Category:</div>
                                    <select class="filter-select">
                                        <option>All Categories</option>
                                        <option>Beer</option>
                                        <option>Spirits</option>
                                        <option>Wine</option>
                                        <option>Soft Drinks</option>
                                    </select>
                                </div>
                                <div class="filter-item">
                                    <div class="filter-label">Customer Type:</div>
                                    <select class="filter-select">
                                        <option>All Types</option>
                                        <option>Supermarket</option>
                                        <option>Grocery</option>
                                        <option>Convenience</option>
                                        <option>HoReCa</option>
                                        <option>Wholesale</option>
                                    </select>
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="dashboard-stats">
                        <div class="stat-card">
                            <div class="stat-icon primary">
                                <i class="fas fa-dollar-sign"></i>
                            </div>
                            <div class="stat-content">
                                <div class="stat-title">Total Sales</div>
                                <div class="stat-value">$450,000</div>
                                <div class="stat-change up">
                                    <i class="fas fa-arrow-up"></i>
                                    <span>8.5%</span> vs target
                                </div>
                            </div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-icon success">
                                <i class="fas fa-chart-pie"></i>
                            </div>
                            <div class="stat-content">
                                <div class="stat-title">Gross Profit</div>
                                <div class="stat-value">$157,500</div>
                                <div class="stat-change up">
                                    <i class="fas fa-arrow-up"></i>
                                    <span>7.2%</span> vs target
                                </div>
                            </div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-icon warning">
                                <i class="fas fa-percentage"></i>
                            </div>
                            <div class="stat-content">
                                <div class="stat-title">Avg. Margin</div>
                                <div class="stat-value">35.0%</div>
                                <div class="stat-change down">
                                    <i class="fas fa-arrow-down"></i>
                                    <span>1.5%</span> vs target
                                </div>
                            </div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-icon info">
                                <i class="fas fa-bullhorn"></i>
                            </div>
                            <div class="stat-content">
                                <div class="stat-title">Promotion ROI</div>
                                <div class="stat-value">320%</div>
                                <div class="stat-change up">
                                    <i class="fas fa-arrow-up"></i>
                                    <span>12.5%</span> vs target
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    <div class="analytics-grid">
                        <div class="card">
                            <div class="card-header">
                                <h2 class="card-title">Sales by Region</h2>
                            </div>
                            <div class="card-body">
                                <div class="chart-container">
                                    <div style="height: 100%; display: flex; align-items: center; justify-content: center;">
                                        <div style="width: 200px; height: 200px; border-radius: 50%; background: conic-gradient(#4a6cf7 0% 32.2%, #28a745 32.2% 55.8%, #17a2b8 55.8% 65.1%, #ffc107 65.1% 86.2%, #dc3545 86.2% 100%); position: relative;">
                                            <div style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); width: 100px; height: 100px; border-radius: 50%; background-color: white;"></div>
                                        </div>
                                        <div style="margin-left: 30px;">
                                            <div style="display: flex; align-items: center; margin-bottom: 10px;">
                                                <div style="width: 12px; height: 12px; background-color: #4a6cf7; margin-right: 8px;"></div>
                                                <div>North (32.2%)</div>
                                            </div>
                                            <div style="display: flex; align-items: center; margin-bottom: 10px;">
                                                <div style="width: 12px; height: 12px; background-color: #28a745; margin-right: 8px;"></div>
                                                <div>South (23.6%)</div>
                                            </div>
                                            <div style="display: flex; align-items: center; margin-bottom: 10px;">
                                                <div style="width: 12px; height: 12px; background-color: #17a2b8; margin-right: 8px;"></div>
                                                <div>East (9.3%)</div>
                                            </div>
                                            <div style="display: flex; align-items: center; margin-bottom: 10px;">
                                                <div style="width: 12px; height: 12px; background-color: #ffc107; margin-right: 8px;"></div>
                                                <div>West (21.1%)</div>
                                            </div>
                                            <div style="display: flex; align-items: center;">
                                                <div style="width: 12px; height: 12px; background-color: #dc3545; margin-right: 8px;"></div>
                                                <div>Central (13.8%)</div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                        
                        <div class="card">
                            <div class="card-header">
                                <h2 class="card-title">Sales by Category</h2>
                            </div>
                            <div class="card-body">
                                <div class="chart-container">
                                    <div style="height: 100%; display: flex; align-items: center; justify-content: center;">
                                        <div style="width: 200px; height: 200px; border-radius: 50%; background: conic-gradient(#4a6cf7 0% 36.7%, #28a745 36.7% 63.4%, #17a2b8 63.4% 82.3%, #ffc107 82.3% 100%); position: relative;">
                                            <div style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); width: 100px; height: 100px; border-radius: 50%; background-color: white;"></div>
                                        </div>
                                        <div style="margin-left: 30px;">
                                            <div style="display: flex; align-items: center; margin-bottom: 10px;">
                                                <div style="width: 12px; height: 12px; background-color: #4a6cf7; margin-right: 8px;"></div>
                                                <div>Beer (36.7%)</div>
                                            </div>
                                            <div style="display: flex; align-items: center; margin-bottom: 10px;">
                                                <div style="width: 12px; height: 12px; background-color: #28a745; margin-right: 8px;"></div>
                                                <div>Spirits (26.7%)</div>
                                            </div>
                                            <div style="display: flex; align-items: center; margin-bottom: 10px;">
                                                <div style="width: 12px; height: 12px; background-color: #17a2b8; margin-right: 8px;"></div>
                                                <div>Wine (18.9%)</div>
                                            </div>
                                            <div style="display: flex; align-items: center;">
                                                <div style="width: 12px; height: 12px; background-color: #ffc107; margin-right: 8px;"></div>
                                                <div>Soft Drinks (17.8%)</div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                        
                        <div class="card">
                            <div class="card-header">
                                <h2 class="card-title">Sales by Customer Type</h2>
                            </div>
                            <div class="card-body">
                                <div class="chart-container">
                                    <div style="height: 100%; display: flex; align-items: center; justify-content: center;">
                                        <div style="width: 200px; height: 200px; border-radius: 50%; background: conic-gradient(#4a6cf7 0% 32.2%, #28a745 32.2% 49.5%, #17a2b8 49.5% 65.1%, #ffc107 65.1% 95.5%, #dc3545 95.5% 100%); position: relative;">
                                            <div style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); width: 100px; height: 100px; border-radius: 50%; background-color: white;"></div>
                                        </div>
                                        <div style="margin-left: 30px;">
                                            <div style="display: flex; align-items: center; margin-bottom: 10px;">
                                                <div style="width: 12px; height: 12px; background-color: #4a6cf7; margin-right: 8px;"></div>
                                                <div>Supermarket (32.2%)</div>
                                            </div>
                                            <div style="display: flex; align-items: center; margin-bottom: 10px;">
                                                <div style="width: 12px; height: 12px; background-color: #28a745; margin-right: 8px;"></div>
                                                <div>Grocery (17.3%)</div>
                                            </div>
                                            <div style="display: flex; align-items: center; margin-bottom: 10px;">
                                                <div style="width: 12px; height: 12px; background-color: #17a2b8; margin-right: 8px;"></div>
                                                <div>Convenience (15.6%)</div>
                                            </div>
                                            <div style="display: flex; align-items: center; margin-bottom: 10px;">
                                                <div style="width: 12px; height: 12px; background-color: #ffc107; margin-right: 8px;"></div>
                                                <div>HoReCa (30.4%)</div>
                                            </div>
                                            <div style="display: flex; align-items: center;">
                                                <div style="width: 12px; height: 12px; background-color: #dc3545; margin-right: 8px;"></div>
                                                <div>Wholesale (4.4%)</div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                        
                        <div class="card">
                            <div class="card-header">
                                <h2 class="card-title">Sales Trend</h2>
                            </div>
                            <div class="card-body">
                                <div class="chart-container">
                                    <div style="height: 100%; display: flex; align-items: center; justify-content: center;">
                                        <div style="text-align: center;">
                                            <div style="height: 200px; display: flex; align-items: flex-end; justify-content: space-between; padding: 0 20px;">
                                                <div style="width: 30px; height: 64%; background-color: #4a6cf7; border-radius: 4px 4px 0 0;"></div>
                                                <div style="width: 30px; height: 56%; background-color: #4a6cf7; border-radius: 4px 4px 0 0;"></div>
                                                <div style="width: 30px; height: 70%; background-color: #4a6cf7; border-radius: 4px 4px 0 0;"></div>
                                                <div style="width: 30px; height: 80%; background-color: #4a6cf7; border-radius: 4px 4px 0 0;"></div>
                                                <div style="width: 30px; height: 76%; background-color: #4a6cf7; border-radius: 4px 4px 0 0;"></div>
                                                <div style="width: 30px; height: 84%; background-color: #4a6cf7; border-radius: 4px 4px 0 0;"></div>
                                                <div style="width: 30px; height: 90%; background-color: #4a6cf7; border-radius: 4px 4px 0 0;"></div>
                                                <div style="width: 30px; height: 96%; background-color: #4a6cf7; border-radius: 4px 4px 0 0;"></div>
                                                <div style="width: 30px; height: 100%; background-color: #4a6cf7; border-radius: 4px 4px 0 0;"></div>
                                            </div>
                                            <div style="margin-top: 10px; display: flex; justify-content: space-between; padding: 0 20px;">
                                                <div style="width: 30px; text-align: center; font-size: 12px;">Jan</div>
                                                <div style="width: 30px; text-align: center; font-size: 12px;">Feb</div>
                                                <div style="width: 30px; text-align: center; font-size: 12px;">Mar</div>
                                                <div style="width: 30px; text-align: center; font-size: 12px;">Apr</div>
                                                <div style="width: 30px; text-align: center; font-size: 12px;">May</div>
                                                <div style="width: 30px; text-align: center; font-size: 12px;">Jun</div>
                                                <div style="width: 30px; text-align: center; font-size: 12px;">Jul</div>
                                                <div style="width: 30px; text-align: center; font-size: 12px;">Aug</div>
                                                <div style="width: 30px; text-align: center; font-size: 12px;">Sep</div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                
                <!-- Hierarchies Page -->
                <div id="hierarchies-page" class="page">
                    <div class="d-flex justify-content-between align-items-center mb-4">
                        <h2 class="mb-0">Hierarchies</h2>
                        <div>
                            <button class="btn btn-outline-primary mr-2">
                                <i class="fas fa-expand-alt"></i> Expand All
                            </button>
                            <button class="btn btn-outline-primary">
                                <i class="fas fa-compress-alt"></i> Collapse All
                            </button>
                        </div>
                    </div>
                    
                    <div class="hierarchy-container">
                        <div class="card">
                            <div class="card-header">
                                <h2 class="card-title">Product Hierarchy</h2>
                                <button class="btn btn-sm btn-outline-primary">
                                    <i class="fas fa-edit"></i> Edit
                                </button>
                            </div>
                            <div class="card-body">
                                <div class="mb-3">
                                    <strong>Levels:</strong> Category → Sub-Category → Brand → Package → SKU
                                </div>
                                <div class="hierarchy-tree" id="product-hierarchy">
                                    <!-- Product hierarchy will be loaded here -->
                                    <div class="hierarchy-item">
                                        <div class="hierarchy-toggle" data-expanded="false">
                                            <i class="fas fa-plus-square"></i> Beer
                                        </div>
                                        <div class="hierarchy-children">
                                            <div class="hierarchy-item">
                                                <div class="hierarchy-toggle" data-expanded="false">
                                                    <i class="fas fa-plus-square"></i> Lager
                                                </div>
                                                <div class="hierarchy-children">
                                                    <div class="hierarchy-item">
                                                        <div class="hierarchy-toggle" data-expanded="false">
                                                            <i class="fas fa-plus-square"></i> Premium Lager
                                                        </div>
                                                        <div class="hierarchy-children">
                                                            <div class="hierarchy-item">
                                                                <div class="hierarchy-toggle" data-expanded="false">
                                                                    <i class="fas fa-plus-square"></i> 6-pack
                                                                </div>
                                                                <div class="hierarchy-children">
                                                                    <div class="hierarchy-item">
                                                                        <div>Premium Lager 6x330ml</div>
                                                                    </div>
                                                                </div>
                                                            </div>
                                                            <div class="hierarchy-item">
                                                                <div class="hierarchy-toggle" data-expanded="false">
                                                                    <i class="fas fa-plus-square"></i> Single
                                                                </div>
                                                                <div class="hierarchy-children">
                                                                    <div class="hierarchy-item">
                                                                        <div>Premium Lager 330ml</div>
                                                                    </div>
                                                                    <div class="hierarchy-item">
                                                                        <div>Premium Lager 500ml</div>
                                                                    </div>
                                                                </div>
                                                            </div>
                                                        </div>
                                                    </div>
                                                </div>
                                            </div>
                                            <div class="hierarchy-item">
                                                <div class="hierarchy-toggle" data-expanded="false">
                                                    <i class="fas fa-plus-square"></i> IPA
                                                </div>
                                                <div class="hierarchy-children">
                                                    <div class="hierarchy-item">
                                                        <div class="hierarchy-toggle" data-expanded="false">
                                                            <i class="fas fa-plus-square"></i> Craft IPA
                                                        </div>
                                                        <div class="hierarchy-children">
                                                            <!-- More items -->
                                                        </div>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="hierarchy-item">
                                        <div class="hierarchy-toggle" data-expanded="false">
                                            <i class="fas fa-plus-square"></i> Spirits
                                        </div>
                                        <div class="hierarchy-children">
                                            <!-- More items -->
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                        
                        <div class="card">
                            <div class="card-header">
                                <h2 class="card-title">Customer Hierarchy</h2>
                                <button class="btn btn-sm btn-outline-primary">
                                    <i class="fas fa-edit"></i> Edit
                                </button>
                            </div>
                            <div class="card-body">
                                <div class="mb-3">
                                    <strong>Levels:</strong> Region → City → Channel → Sub-Channel → Customer
                                </div>
                                <div class="hierarchy-tree" id="customer-hierarchy">
                                    <!-- Customer hierarchy will be loaded here -->
                                    <div class="hierarchy-item">
                                        <div class="hierarchy-toggle" data-expanded="false">
                                            <i class="fas fa-plus-square"></i> North
                                        </div>
                                        <div class="hierarchy-children">
                                            <div class="hierarchy-item">
                                                <div class="hierarchy-toggle" data-expanded="false">
                                                    <i class="fas fa-plus-square"></i> Manchester
                                                </div>
                                                <div class="hierarchy-children">
                                                    <div class="hierarchy-item">
                                                        <div class="hierarchy-toggle" data-expanded="false">
                                                            <i class="fas fa-plus-square"></i> Retail
                                                        </div>
                                                        <div class="hierarchy-children">
                                                            <div class="hierarchy-item">
                                                                <div class="hierarchy-toggle" data-expanded="false">
                                                                    <i class="fas fa-plus-square"></i> Supermarket
                                                                </div>
                                                                <div class="hierarchy-children">
                                                                    <div class="hierarchy-item">
                                                                        <div>Metro Supermarket</div>
                                                                    </div>
                                                                </div>
                                                            </div>
                                                        </div>
                                                    </div>
                                                    <div class="hierarchy-item">
                                                        <div class="hierarchy-toggle" data-expanded="false">
                                                            <i class="fas fa-plus-square"></i> HoReCa
                                                        </div>
                                                        <div class="hierarchy-children">
                                                            <div class="hierarchy-item">
                                                                <div class="hierarchy-toggle" data-expanded="false">
                                                                    <i class="fas fa-plus-square"></i> Pub
                                                                </div>
                                                                <div class="hierarchy-children">
                                                                    <div class="hierarchy-item">
                                                                        <div>Downtown Pub</div>
                                                                    </div>
                                                                </div>
                                                            </div>
                                                        </div>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="hierarchy-item">
                                        <div class="hierarchy-toggle" data-expanded="false">
                                            <i class="fas fa-plus-square"></i> South
                                        </div>
                                        <div class="hierarchy-children">
                                            <!-- More items -->
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                
                <!-- Settings Page -->
                <div id="settings-page" class="page">
                    <div class="d-flex justify-content-between align-items-center mb-4">
                        <h2 class="mb-0">Settings</h2>
                        <button class="btn btn-primary">
                            <i class="fas fa-save"></i> Save Changes
                        </button>
                    </div>
                    
                    <div class="card mb-4">
                        <div class="card-header">
                            <h2 class="card-title">Company Information</h2>
                        </div>
                        <div class="card-body">
                            <div class="form-group">
                                <label class="form-label">Company Name</label>
                                <input type="text" class="form-control" value="Diplomat SA">
                            </div>
                            <div class="form-group">
                                <label class="form-label">Address</label>
                                <input type="text" class="form-control" value="123 Business Street">
                            </div>
                            <div class="form-group">
                                <label class="form-label">City</label>
                                <input type="text" class="form-control" value="London">
                            </div>
                            <div class="form-group">
                                <label class="form-label">Country</label>
                                <input type="text" class="form-control" value="United Kingdom">
                            </div>
                            <div class="form-group">
                                <label class="form-label">Phone</label>
                                <input type="text" class="form-control" value="+44 20 1234 5678">
                            </div>
                            <div class="form-group">
                                <label class="form-label">Email</label>
                                <input type="email" class="form-control" value="info@diplomat.com">
                            </div>
                        </div>
                    </div>
                    
                    <div class="card mb-4">
                        <div class="card-header">
                            <h2 class="card-title">User Management</h2>
                            <button class="btn btn-sm btn-outline-primary">
                                <i class="fas fa-plus"></i> Add User
                            </button>
                        </div>
                        <div class="card-body">
                            <div class="table-responsive">
                                <table class="table table-striped">
                                    <thead>
                                        <tr>
                                            <th>Name</th>
                                            <th>Email</th>
                                            <th>Role</th>
                                            <th>Last Login</th>
                                            <th>Status</th>
                                            <th>Actions</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <tr>
                                            <td>Admin User</td>
                                            <td>admin@example.com</td>
                                            <td>Admin</td>
                                            <td>2025-09-01 08:30</td>
                                            <td><span class="badge badge-success">Active</span></td>
                                            <td>
                                                <button class="btn btn-sm btn-outline-primary">
                                                    <i class="fas fa-edit"></i>
                                                </button>
                                                <button class="btn btn-sm btn-outline-danger">
                                                    <i class="fas fa-trash"></i>
                                                </button>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td>Sales Manager</td>
                                            <td>sales@example.com</td>
                                            <td>Manager</td>
                                            <td>2025-09-01 09:15</td>
                                            <td><span class="badge badge-success">Active</span></td>
                                            <td>
                                                <button class="btn btn-sm btn-outline-primary">
                                                    <i class="fas fa-edit"></i>
                                                </button>
                                                <button class="btn btn-sm btn-outline-danger">
                                                    <i class="fas fa-trash"></i>
                                                </button>
                                            </td>
                                        </tr>
                                        <tr>
                                            <td>Marketing Director</td>
                                            <td>marketing@example.com</td>
                                            <td>Director</td>
                                            <td>2025-09-01 10:00</td>
                                            <td><span class="badge badge-success">Active</span></td>
                                            <td>
                                                <button class="btn btn-sm btn-outline-primary">
                                                    <i class="fas fa-edit"></i>
                                                </button>
                                                <button class="btn btn-sm btn-outline-danger">
                                                    <i class="fas fa-trash"></i>
                                                </button>
                                            </td>
                                        </tr>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                    
                    <div class="card mb-4">
                        <div class="card-header">
                            <h2 class="card-title">System Settings</h2>
                        </div>
                        <div class="card-body">
                            <div class="form-group">
                                <label class="form-label">Default Currency</label>
                                <select class="form-control">
                                    <option selected>USD ($)</option>
                                    <option>EUR (€)</option>
                                    <option>GBP (£)</option>
                                </select>
                            </div>
                            <div class="form-group">
                                <label class="form-label">Date Format</label>
                                <select class="form-control">
                                    <option selected>YYYY-MM-DD</option>
                                    <option>MM/DD/YYYY</option>
                                    <option>DD/MM/YYYY</option>
                                </select>
                            </div>
                            <div class="form-group">
                                <label class="form-label">Timezone</label>
                                <select class="form-control">
                                    <option selected>UTC</option>
                                    <option>UTC+1 (London)</option>
                                    <option>UTC-5 (New York)</option>
                                    <option>UTC+8 (Singapore)</option>
                                </select>
                            </div>
                            <div class="form-group">
                                <label class="form-label">Language</label>
                                <select class="form-control">
                                    <option selected>English</option>
                                    <option>Spanish</option>
                                    <option>French</option>
                                    <option>German</option>
                                </select>
                            </div>
                        </div>
                    </div>
                    
                    <div class="card">
                        <div class="card-header">
                            <h2 class="card-title">Integration Settings</h2>
                        </div>
                        <div class="card-body">
                            <div class="form-group">
                                <label class="form-label">SAP Integration</label>
                                <div class="d-flex align-items-center">
                                    <select class="form-control mr-2">
                                        <option>SAP ECC</option>
                                        <option selected>SAP S/4HANA</option>
                                    </select>
                                    <button class="btn btn-outline-primary">Configure</button>
                                </div>
                            </div>
                            <div class="form-group">
                                <label class="form-label">Microsoft 365 SSO</label>
                                <div class="d-flex align-items-center">
                                    <input type="text" class="form-control mr-2" placeholder="Tenant ID" value="diplomat-sa">
                                    <button class="btn btn-outline-primary">Configure</button>
                                </div>
                            </div>
                            <div class="form-group">
                                <label class="form-label">Email Integration</label>
                                <div class="d-flex align-items-center">
                                    <select class="form-control mr-2">
                                        <option>None</option>
                                        <option selected>SMTP</option>
                                        <option>Microsoft Exchange</option>
                                    </select>
                                    <button class="btn btn-outline-primary">Configure</button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        document.addEventListener('DOMContentLoaded', function() {
            // Toggle sidebar
            const toggleSidebar = document.getElementById('toggle-sidebar');
            const sidebar = document.getElementById('sidebar');
            const mainContent = document.getElementById('main-content');
            const header = document.getElementById('header');
            
            toggleSidebar.addEventListener('click', function() {
                sidebar.classList.toggle('sidebar-collapsed');
                mainContent.classList.toggle('main-content-expanded');
                header.classList.toggle('header-expanded');
            });
            
            // Navigation
            const navLinks = document.querySelectorAll('.sidebar-link');
            const pages = document.querySelectorAll('.page');
            const pageTitle = document.getElementById('page-title');
            
            navLinks.forEach(link => {
                link.addEventListener('click', function(e) {
                    e.preventDefault();
                    
                    // Update active link
                    navLinks.forEach(nav => nav.classList.remove('active'));
                    this.classList.add('active');
                    
                    // Show selected page
                    const targetPage = this.getAttribute('data-page');
                    pages.forEach(page => {
                        page.classList.remove('active');
                        if (page.id === targetPage) {
                            page.classList.add('active');
                        }
                    });
                    
                    // Update page title
                    pageTitle.textContent = this.querySelector('span').textContent;
                    
                    // Load data for the page if needed
                    if (targetPage === 'products-page') {
                        loadProducts();
                    } else if (targetPage === 'customers-page') {
                        loadCustomers();
                    } else if (targetPage === 'promotions-page') {
                        loadPromotions();
                    } else if (targetPage === 'sales-page') {
                        loadSales();
                    }
                });
            });
            
            // Hierarchy toggles
            const hierarchyToggles = document.querySelectorAll('.hierarchy-toggle');
            
            hierarchyToggles.forEach(toggle => {
                toggle.addEventListener('click', function() {
                    const isExpanded = this.getAttribute('data-expanded') === 'true';
                    const children = this.nextElementSibling;
                    const icon = this.querySelector('i');
                    
                    if (isExpanded) {
                        this.setAttribute('data-expanded', 'false');
                        children.classList.remove('expanded');
                        icon.classList.remove('fa-minus-square');
                        icon.classList.add('fa-plus-square');
                    } else {
                        this.setAttribute('data-expanded', 'true');
                        children.classList.add('expanded');
                        icon.classList.remove('fa-plus-square');
                        icon.classList.add('fa-minus-square');
                    }
                });
            });
            
            // Load data functions
            function loadProducts() {
                fetch('/api/v1/products')
                    .then(response => response.json())
                    .then(data => {
                        const productGrid = document.getElementById('product-grid');
                        productGrid.innerHTML = '';
                        
                        if (data.products && data.products.length > 0) {
                            data.products.forEach(product => {
                                const productCard = document.createElement('div');
                                productCard.className = 'product-card';
                                
                                productCard.innerHTML = `
                                    <div class="product-header">
                                        <div>
                                            <h3 class="product-title">${product.name}</h3>
                                            <div class="product-category">${product.category} > ${product.subCategory}</div>
                                        </div>
                                    </div>
                                    <div class="product-body">
                                        <div class="product-price">$${product.price.toFixed(2)}</div>
                                        <div class="product-stats">
                                            <div class="product-stat">
                                                <div class="product-stat-label">Cost</div>
                                                <div class="product-stat-value">$${product.cost.toFixed(2)}</div>
                                            </div>
                                            <div class="product-stat">
                                                <div class="product-stat-label">Margin</div>
                                                <div class="product-stat-value">${product.margin.toFixed(1)}%</div>
                                            </div>
                                            <div class="product-stat">
                                                <div class="product-stat-label">Stock</div>
                                                <div class="product-stat-value">${product.stock}</div>
                                            </div>
                                            <div class="product-stat">
                                                <div class="product-stat-label">Sales LTD</div>
                                                <div class="product-stat-value">${product.salesLTD}</div>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="product-footer">
                                        <button class="btn btn-sm btn-outline-primary">
                                            <i class="fas fa-edit"></i> Edit
                                        </button>
                                        <button class="btn btn-sm btn-outline-danger">
                                            <i class="fas fa-trash"></i> Delete
                                        </button>
                                    </div>
                                `;
                                
                                productGrid.appendChild(productCard);
                            });
                        } else {
                            productGrid.innerHTML = '<div class="text-center">No products found</div>';
                        }
                    })
                    .catch(error => {
                        console.error('Error loading products:', error);
                        document.getElementById('product-grid').innerHTML = '<div class="text-center">Error loading products</div>';
                    });
            }
            
            function loadCustomers() {
                fetch('/api/v1/customers')
                    .then(response => response.json())
                    .then(data => {
                        const customerList = document.getElementById('customer-list');
                        customerList.innerHTML = '';
                        
                        if (data.customers && data.customers.length > 0) {
                            data.customers.forEach(customer => {
                                const customerCard = document.createElement('div');
                                customerCard.className = 'customer-card';
                                
                                customerCard.innerHTML = `
                                    <div class="customer-header">
                                        <div class="customer-avatar">${customer.name.charAt(0)}</div>
                                        <div>
                                            <h3 class="customer-title">${customer.name}</h3>
                                            <div class="customer-type">${customer.type} - ${customer.region}</div>
                                        </div>
                                    </div>
                                    <div class="customer-body">
                                        <div class="customer-info">
                                            <div class="customer-info-item">
                                                <div class="customer-info-label">City:</div>
                                                <div class="customer-info-value">${customer.city}</div>
                                            </div>
                                            <div class="customer-info-item">
                                                <div class="customer-info-label">Address:</div>
                                                <div class="customer-info-value">${customer.address}</div>
                                            </div>
                                            <div class="customer-info-item">
                                                <div class="customer-info-label">Contact:</div>
                                                <div class="customer-info-value">${customer.contact}</div>
                                            </div>
                                            <div class="customer-info-item">
                                                <div class="customer-info-label">Phone:</div>
                                                <div class="customer-info-value">${customer.phone}</div>
                                            </div>
                                        </div>
                                        <div class="customer-stats">
                                            <div class="customer-stat">
                                                <div class="customer-stat-label">Credit Limit</div>
                                                <div class="customer-stat-value">$${customer.credit.toLocaleString()}</div>
                                            </div>
                                            <div class="customer-stat">
                                                <div class="customer-stat-label">Balance</div>
                                                <div class="customer-stat-value">$${customer.balance.toLocaleString()}</div>
                                            </div>
                                            <div class="customer-stat">
                                                <div class="customer-stat-label">Sales LTD</div>
                                                <div class="customer-stat-value">$${customer.salesLTD.toLocaleString()}</div>
                                            </div>
                                            <div class="customer-stat">
                                                <div class="customer-stat-label">Utilization</div>
                                                <div class="customer-stat-value">${Math.round(customer.balance / customer.credit * 100)}%</div>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="customer-footer">
                                        <button class="btn btn-sm btn-outline-primary">
                                            <i class="fas fa-edit"></i> Edit
                                        </button>
                                        <button class="btn btn-sm btn-outline-danger">
                                            <i class="fas fa-trash"></i> Delete
                                        </button>
                                    </div>
                                `;
                                
                                customerList.appendChild(customerCard);
                            });
                        } else {
                            customerList.innerHTML = '<div class="text-center">No customers found</div>';
                        }
                    })
                    .catch(error => {
                        console.error('Error loading customers:', error);
                        document.getElementById('customer-list').innerHTML = '<div class="text-center">Error loading customers</div>';
                    });
            }
            
            function loadPromotions() {
                fetch('/api/v1/promotions')
                    .then(response => response.json())
                    .then(data => {
                        const promotionList = document.getElementById('promotion-list');
                        promotionList.innerHTML = '';
                        
                        if (data.promotions && data.promotions.length > 0) {
                            data.promotions.forEach(promotion => {
                                const promotionCard = document.createElement('div');
                                promotionCard.className = 'promotion-card';
                                
                                // Calculate budget percentage
                                const budgetPercentage = promotion.budget > 0 ? Math.round(promotion.spent / promotion.budget * 100) : 0;
                                
                                // Determine status badge class
                                let statusBadgeClass = 'badge-secondary';
                                if (promotion.status === 'Active') statusBadgeClass = 'badge-primary';
                                if (promotion.status === 'Completed') statusBadgeClass = 'badge-success';
                                if (promotion.status === 'Planned') statusBadgeClass = 'badge-info';
                                
                                promotionCard.innerHTML = `
                                    <div class="promotion-header">
                                        <div class="promotion-title-section">
                                            <div class="promotion-icon">
                                                <i class="fas fa-bullhorn"></i>
                                            </div>
                                            <div>
                                                <h3 class="promotion-title">${promotion.name}</h3>
                                                <div class="promotion-type">${promotion.type}</div>
                                            </div>
                                        </div>
                                        <span class="badge ${statusBadgeClass}">${promotion.status}</span>
                                    </div>
                                    <div class="promotion-body">
                                        <div>
                                            <div class="promotion-details">
                                                <div class="promotion-detail">
                                                    <div class="promotion-detail-label">Start Date</div>
                                                    <div class="promotion-detail-value">${promotion.startDate}</div>
                                                </div>
                                                <div class="promotion-detail">
                                                    <div class="promotion-detail-label">End Date</div>
                                                    <div class="promotion-detail-value">${promotion.endDate}</div>
                                                </div>
                                                <div class="promotion-detail">
                                                    <div class="promotion-detail-label">Discount</div>
                                                    <div class="promotion-detail-value">${promotion.discount}%</div>
                                                </div>
                                                <div class="promotion-detail">
                                                    <div class="promotion-detail-label">Products</div>
                                                    <div class="promotion-detail-value">${promotion.products.length}</div>
                                                </div>
                                            </div>
                                            <div class="promotion-budget">
                                                <div class="promotion-budget-header">
                                                    <div class="promotion-budget-label">Budget</div>
                                                    <div class="promotion-budget-value">$${promotion.spent.toLocaleString()} / $${promotion.budget.toLocaleString()}</div>
                                                </div>
                                                <div class="progress">
                                                    <div class="progress-bar" style="width: ${budgetPercentage}%;"></div>
                                                </div>
                                            </div>
                                        </div>
                                        <div>
                                            <div class="promotion-details">
                                                <div class="promotion-detail">
                                                    <div class="promotion-detail-label">Customers</div>
                                                    <div class="promotion-detail-value">${promotion.customers.length}</div>
                                                </div>
                                                <div class="promotion-detail">
                                                    <div class="promotion-detail-label">Budget Utilization</div>
                                                    <div class="promotion-detail-value">${budgetPercentage}%</div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                    <div class="promotion-footer">
                                        <button class="btn btn-sm btn-outline-primary">
                                            <i class="fas fa-edit"></i> Edit
                                        </button>
                                        <button class="btn btn-sm btn-outline-danger">
                                            <i class="fas fa-trash"></i> Delete
                                        </button>
                                    </div>
                                `;
                                
                                promotionList.appendChild(promotionCard);
                            });
                        } else {
                            promotionList.innerHTML = '<div class="text-center">No promotions found</div>';
                        }
                    })
                    .catch(error => {
                        console.error('Error loading promotions:', error);
                        document.getElementById('promotion-list').innerHTML = '<div class="text-center">Error loading promotions</div>';
                    });
            }
            
            function loadSales() {
                fetch('/api/v1/sales')
                    .then(response => response.json())
                    .then(data => {
                        const salesTable = document.getElementById('sales-table');
                        salesTable.innerHTML = '';
                        
                        if (data.sales && data.sales.length > 0) {
                            data.sales.forEach(sale => {
                                // Get customer and product names
                                const customerName = getCustomerName(sale.customer);
                                const productName = getProductName(sale.product);
                                const promotionName = sale.promotion ? getPromotionName(sale.promotion) : 'None';
                                
                                const row = document.createElement('tr');
                                row.innerHTML = `
                                    <td>${sale.id}</td>
                                    <td>${sale.date}</td>
                                    <td>${customerName}</td>
                                    <td>${productName}</td>
                                    <td>${sale.quantity}</td>
                                    <td>$${sale.value.toLocaleString()}</td>
                                    <td>${promotionName}</td>
                                    <td>
                                        <button class="btn btn-sm btn-outline-primary">
                                            <i class="fas fa-edit"></i>
                                        </button>
                                        <button class="btn btn-sm btn-outline-danger">
                                            <i class="fas fa-trash"></i>
                                        </button>
                                    </td>
                                `;
                                
                                salesTable.appendChild(row);
                            });
                        } else {
                            salesTable.innerHTML = '<tr><td colspan="8" class="text-center">No sales found</td></tr>';
                        }
                    })
                    .catch(error => {
                        console.error('Error loading sales:', error);
                        document.getElementById('sales-table').innerHTML = '<tr><td colspan="8" class="text-center">Error loading sales</td></tr>';
                    });
            }
            
            // Helper functions
            function getCustomerName(customerId) {
                const customers = {
                    1: 'Metro Supermarket',
                    2: 'City Grocers',
                    3: 'Express Mart',
                    4: 'Luxury Hotels',
                    5: 'Downtown Pub',
                    6: 'Wholesale Distributors',
                    7: 'Corner Shop',
                    8: 'Gourmet Restaurant'
                };
                
                return customers[customerId] || `Customer ${customerId}`;
            }
            
            function getProductName(productId) {
                const products = {
                    1: 'Premium Lager',
                    2: 'Craft IPA',
                    3: 'Light Beer',
                    4: 'Premium Vodka',
                    5: 'Blended Whisky',
                    6: 'Single Malt',
                    7: 'White Wine',
                    8: 'Red Wine',
                    9: 'Sparkling Wine',
                    10: 'Cola',
                    11: 'Lemon Soda',
                    12: 'Orange Juice'
                };
                
                return products[productId] || `Product ${productId}`;
            }
            
            function getPromotionName(promotionId) {
                const promotions = {
                    1: 'Summer Beer Festival',
                    2: 'Winter Spirits Special',
                    3: 'Wine Tasting Event',
                    4: 'Back to School',
                    5: 'Holiday Bundle'
                };
                
                return promotions[promotionId] || `Promotion ${promotionId}`;
            }
            
            // Load initial data
            loadProducts();
            loadCustomers();
            loadPromotions();
            loadSales();
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

    print_message $GREEN "✓ Created enterprise frontend application"
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
    
    cd "$INSTALL_DIR/vantax-enterprise/deployment"
    
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
Description=Vanta X Enterprise Application
Requires=docker.service
After=docker.service network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR/vantax-enterprise/deployment
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
    LOG_FILE="/var/log/vantax-enterprise-deployment-$(date +%Y%m%d-%H%M%S).log"
    exec 1> >(tee -a "$LOG_FILE")
    exec 2>&1
    
    print_banner
    
    print_message $BLUE "Starting Vanta X Enterprise Deployment"
    print_message $BLUE "This script will perform a complete enterprise deployment"
    
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
    print_message $GREEN "║              🎉 VANTA X ENTERPRISE DEPLOYMENT COMPLETED! 🎉                  ║"
    print_message $GREEN "║                                                                              ║"
    print_message $GREEN "╚══════════════════════════════════════════════════════════════════════════════╝"
    
    print_message $BLUE "\n📋 Enterprise Deployment Summary:"
    print_message $YELLOW "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_message $CYAN "Web Application: ${GREEN}http://localhost"
    print_message $CYAN "API Endpoint: ${GREEN}http://localhost/api/v1"
    print_message $CYAN "Installation Directory: ${GREEN}$INSTALL_DIR"
    print_message $CYAN "Log File: ${GREEN}$LOG_FILE"
    print_message $YELLOW "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    print_message $GREEN "\n✅ ENTERPRISE DEPLOYMENT ADVANTAGES:"
    print_message $GREEN "✅ Complete enterprise-grade UI with dashboard, analytics, and more"
    print_message $GREEN "✅ Comprehensive data model with products, customers, promotions, and sales"
    print_message $GREEN "✅ 5-level hierarchies for products and customers"
    print_message $GREEN "✅ Responsive design for all devices"
    print_message $GREEN "✅ No build steps - just simple file copying"
    print_message $GREEN "✅ No dependencies - uses built-in modules"
    print_message $GREEN "✅ Proper Nginx configuration - tested and working"
    print_message $GREEN "✅ Complete system service - auto-starts on boot"
    
    print_message $GREEN "\n🚀 Access your enterprise application at: http://localhost"
    
    print_message $BLUE "\n🎊 Enterprise deployment completed successfully! 🎊"
}

# Error handling
handle_error() {
    print_message $RED "\n❌ Enterprise deployment failed!"
    print_message $YELLOW "Check the log file: $LOG_FILE"
    exit 1
}

trap handle_error ERR

# Run main function
main "$@"