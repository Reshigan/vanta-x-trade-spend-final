# Vanta X - Final Production Deployment

## 🚀 One-Command Enterprise Deployment

This repository contains a **tested, error-free** deployment script for the complete Vanta X FMCG Trade Marketing Management Platform.

### ✅ What's Fixed

- **No more "path not found" errors** - Project structure is created automatically
- **No Docker build context issues** - All directories and files are generated before build
- **No environment variable warnings** - All variables properly configured
- **Tested deployment sequence** - Each step validated and error-handled
- **Complete error handling** - Graceful failure recovery and detailed logging

## 📋 System Requirements

### Minimum Requirements
- **OS**: Ubuntu 20.04+, Debian 11+, RHEL 8+, CentOS 8+
- **RAM**: 4GB (8GB recommended)
- **CPU**: 2 cores (4 cores recommended)  
- **Disk**: 20GB free space (50GB recommended)
- **Access**: Root or sudo privileges

### Supported Platforms
- ✅ Ubuntu 20.04 LTS / 22.04 LTS
- ✅ Debian 11 / 12
- ✅ RHEL 8 / 9
- ✅ CentOS 8 / 9
- ✅ Amazon Linux 2
- ✅ Cloud platforms (AWS, GCP, Azure)

## 🎯 Quick Start

### Step 1: Clone Repository
```bash
git clone https://github.com/Reshigan/vanta-x-trade-spend-final.git
cd vanta-x-trade-spend-final
```

### Step 2: Run Final Deployment
```bash
sudo ./deploy-final.sh
```

### Step 3: Follow Interactive Setup
The script will prompt for:
- Domain name (use `localhost` for testing)
- Admin email address
- Company name (defaults to "Diplomat SA")
- SSL certificate setup (yes/no)
- Monitoring setup (yes/no)
- Automated backups (yes/no)

### Step 4: Access Your System
After successful deployment:
- **Web App**: http://your-domain
- **Admin Login**: Credentials provided during installation
- **RabbitMQ Management**: http://your-domain:15672

## 🏗️ What Gets Deployed

### Infrastructure (Automatically Installed)
- **Docker & Docker Compose** - Container orchestration
- **PostgreSQL 15** - Primary database
- **Redis 7** - Caching and sessions
- **RabbitMQ 3** - Message queue with management UI
- **Nginx** - Reverse proxy and load balancer
- **Node.js 18** - Runtime environment

### Application Stack (11 Microservices)
1. **API Gateway** (4000) - Central routing, authentication, rate limiting
2. **Identity Service** (4001) - User management, Microsoft 365 SSO ready
3. **Operations Service** (4002) - Promotions, campaigns, trade marketing
4. **Analytics Service** (4003) - Real-time analytics, dashboards, KPIs
5. **AI Service** (4004) - Machine learning, forecasting, recommendations
6. **Integration Service** (4005) - SAP ECC/S4, Excel import/export
7. **Co-op Service** (4006) - Digital wallets, QR codes, geo-fencing
8. **Notification Service** (4007) - Email, SMS, push notifications
9. **Reporting Service** (4008) - Report generation, scheduling, templates
10. **Workflow Service** (4009) - Business process automation, approvals
11. **Audit Service** (4010) - Compliance, audit trails, data governance

### Frontend Application
- **React 18** with TypeScript
- **Material-UI** responsive design
- **Progressive Web App** capabilities
- **Mobile-optimized** interface

## 📊 Master Data Included

### Company Setup
- **Default Company**: Diplomat SA (configurable)
- **Admin User**: Created with secure password
- **10 System Roles**: Super Admin to Viewer with proper permissions

### 5-Level Customer Hierarchy
```
Global Account (5)
├── Region (3)
│   ├── Country (1)
│   │   ├── Channel (3)
│   │   │   └── Store (45 total)
```
- **Global Accounts**: Shoprite, Pick n Pay, Spar, Woolworths, Massmart
- **Regions**: Western Cape, Gauteng, KwaZulu-Natal
- **Channels**: Hypermarket, Supermarket, Convenience

### 5-Level Product Hierarchy
```
Category (5)
├── Subcategory (20)
│   ├── Brand (15)
│   │   ├── Product Line (25)
│   │   │   └── SKU (375 total)
```
- **Categories**: Beverages, Snacks, Personal Care, Home Care, Food
- **Complete SKU data**: Barcodes, pricing, specifications

### Sample Data (1 Year)
- **50 Promotions** across all types and channels
- **20 Digital Wallets** with transaction history
- **7 Vendors** (multinational and local suppliers)
- **AI Insights** and recommendations
- **Workflow Templates** for approval processes
- **Budget Categories** and allocations

## 🔧 Key Features

### AI & Machine Learning
- **Ensemble Forecasting**: ARIMA, Prophet, XGBoost, Neural Networks
- **Monte Carlo Simulations** for risk analysis
- **Natural Language Processing** for insights
- **Computer Vision** for compliance monitoring

### Digital Wallet System
- **QR Code Generation** for promotions
- **Geo-fencing Validation** for location-based offers
- **Offline Transaction Support** with sync
- **Multi-currency Support** for international operations

### Analytics & Reporting
- **Executive Dashboards** with real-time KPIs
- **Profitability Heat Maps** by region/product
- **Custom Report Builder** with drag-drop interface
- **Automated Report Scheduling** and distribution

### Integration Capabilities
- **SAP ECC/S4 Integration** ready (configuration required)
- **Excel Import/Export** with templates
- **Microsoft 365 SSO** integration ready
- **REST API** for third-party integrations

## 🔐 Security Features

### Automatic Security Setup
- **SSL Certificates** - Let's Encrypt or self-signed
- **Firewall Configuration** - Proper port management
- **Rate Limiting** - API and web protection
- **Security Headers** - HSTS, CSP, XSS protection
- **Password Policies** - Secure credential generation

### Access Control
- **Role-Based Access Control** (RBAC) with 10 predefined roles
- **JWT Authentication** with secure token management
- **Session Management** with Redis backend
- **Audit Logging** for all user actions

## 📈 Monitoring & Management

### Built-in Management Commands
```bash
# System status
vantax-status

# View logs (all services or specific)
vantax-logs [service-name]

# Health check
vantax-health

# Service control
systemctl start|stop|restart vantax
```

### Automatic Features
- **Health Checks** - All services monitored
- **Log Rotation** - Prevents disk space issues
- **Graceful Shutdown** - Proper service termination
- **Auto-restart** - Services restart on failure

## 🚨 Troubleshooting

### Common Issues & Solutions

#### 1. "Path not found" errors
**Fixed in deploy-final.sh** - Project structure created before Docker build

#### 2. Environment variable warnings
**Fixed in deploy-final.sh** - All variables properly configured

#### 3. Docker build failures
```bash
# Check Docker status
sudo systemctl status docker

# Restart if needed
sudo systemctl restart docker

# Clean cache if needed
sudo docker system prune -a
```

#### 4. Service startup issues
```bash
# Check specific service
vantax-logs [service-name]

# Restart all services
sudo systemctl restart vantax

# Check system resources
vantax-health
```

#### 5. Database connection issues
```bash
# Check PostgreSQL
docker logs vantax-postgres

# Verify credentials
sudo cat /etc/vantax/vantax.env | grep DB_
```

## 📝 Post-Deployment Configuration

### 1. Microsoft 365 SSO (Optional)
```bash
# Edit environment file
sudo nano /etc/vantax/vantax.env

# Add Azure AD configuration
AZURE_AD_CLIENT_ID=your-client-id
AZURE_AD_CLIENT_SECRET=your-client-secret
AZURE_AD_TENANT_ID=your-tenant-id

# Restart services
sudo systemctl restart vantax
```

### 2. SAP Integration (Optional)
```bash
# Configure SAP connection
SAP_BASE_URL=https://your-sap-system.com
SAP_CLIENT_ID=your-sap-client
SAP_CLIENT_SECRET=your-sap-secret
ENABLE_SAP_INTEGRATION=true
```

### 3. Email Notifications
```bash
# Configure SMTP
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
```

### 4. AI Features (Optional)
```bash
# Add OpenAI API key
OPENAI_API_KEY=your-openai-api-key
ENABLE_AI_FEATURES=true
```

## 🔄 Updates & Maintenance

### Automatic Updates
```bash
# Update to latest version
cd /opt/vantax/vanta-x-trade-spend-final
sudo git pull origin main
sudo systemctl restart vantax
```

### Backup & Restore
- **Automatic daily backups** at 2 AM
- **30-day retention** policy
- **Database, files, and configuration** included
- **Restore scripts** provided

### Monitoring
- **System resource monitoring**
- **Service health checks**
- **Performance metrics**
- **Error alerting**

## 📞 Support

### Getting Help
1. **Check logs**: `vantax-logs` for service-specific issues
2. **System status**: `vantax-health` for overall health
3. **Documentation**: Full deployment guide included
4. **GitHub Issues**: Report bugs and feature requests

### Enterprise Support
- **Email**: support@vantax.com
- **Documentation**: Complete API and user guides
- **Training**: Available for enterprise customers
- **Custom Development**: Available on request

## 🎉 Success Indicators

After successful deployment, you should see:

✅ **All services running**: `vantax-status` shows all services healthy  
✅ **Web app accessible**: http://your-domain loads the application  
✅ **API responding**: http://your-domain/api/health returns status  
✅ **Database connected**: No connection errors in logs  
✅ **Admin login works**: Can log in with provided credentials  

## 📋 Deployment Checklist

### Pre-Deployment
- [ ] Server meets minimum requirements
- [ ] Domain name configured (if using custom domain)
- [ ] Firewall allows ports 80, 443, 22
- [ ] Root/sudo access available

### During Deployment
- [ ] Run `sudo ./deploy-final.sh`
- [ ] Provide configuration details when prompted
- [ ] Monitor deployment progress
- [ ] Note generated passwords

### Post-Deployment
- [ ] Access web application successfully
- [ ] Save credentials securely
- [ ] Configure additional integrations (optional)
- [ ] Set up monitoring alerts
- [ ] Test backup procedures

## 🏆 What Makes This Final

This deployment script is **production-ready** and **enterprise-tested**:

- ✅ **Zero Docker build errors** - All paths and contexts validated
- ✅ **Complete error handling** - Graceful failure recovery
- ✅ **Comprehensive logging** - Full deployment audit trail
- ✅ **Security hardened** - Production security standards
- ✅ **Performance optimized** - Efficient resource utilization
- ✅ **Monitoring included** - Built-in health checks and metrics
- ✅ **Backup automated** - Data protection from day one
- ✅ **Documentation complete** - Everything you need to succeed

---

**🚀 Ready for Enterprise Deployment!**

This is the **final, tested, production-ready** version of Vanta X.  
No more errors, no more issues - just a working, enterprise-grade FMCG Trade Marketing Platform.

**Version**: 1.0.0-FINAL  
**Last Updated**: December 2024  
**Status**: Production Ready ✅