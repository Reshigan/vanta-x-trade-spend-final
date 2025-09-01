# Vanta X - Complete Deployment Guide

## 🚀 One-Command Production Deployment

This guide provides a complete, automated deployment solution for the Vanta X FMCG Trade Marketing Management Platform.

## 📋 Prerequisites

### System Requirements
- **Operating System**: Ubuntu 20.04+, Debian 11+, RHEL 8+, or CentOS 8+
- **Hardware**: Minimum 8GB RAM, 4 CPU cores, 50GB free disk space
- **Access**: Root or sudo privileges
- **Network**: Internet connection for downloading dependencies

### Supported Platforms
- ✅ Ubuntu 20.04 LTS / 22.04 LTS
- ✅ Debian 11 / 12
- ✅ RHEL 8 / 9
- ✅ CentOS 8 / 9
- ✅ Amazon Linux 2
- ✅ Google Cloud Platform
- ✅ Microsoft Azure
- ✅ AWS EC2

## 🎯 Quick Deployment

### Step 1: Clone Repository
```bash
git clone https://github.com/Reshigan/vanta-x-trade-spend-final.git
cd vanta-x-trade-spend-final
```

### Step 2: Run Deployment Script
```bash
sudo ./deploy-production.sh
```

### Step 3: Follow Interactive Setup
The script will prompt for:
- Domain name (or use localhost for testing)
- Admin email address
- Company name (defaults to Diplomat SA)
- SSL certificate setup (yes/no)
- Monitoring setup (yes/no)
- Automated backups (yes/no)

### Step 4: Access Your System
After deployment completes:
- **Web Application**: https://your-domain.com
- **Admin Login**: Use credentials provided during installation
- **Monitoring**: https://your-domain.com/grafana (if enabled)

## 🔧 What Gets Deployed

### Infrastructure Components
- **PostgreSQL 15** - Primary database
- **Redis 7** - Caching and session storage
- **RabbitMQ 3** - Message queue
- **Nginx** - Reverse proxy with SSL
- **Docker** - Container orchestration

### Application Services (11 Microservices)
1. **API Gateway** (Port 4000) - Central routing and authentication
2. **Identity Service** (Port 4001) - User management and Microsoft 365 SSO
3. **Operations Service** (Port 4002) - Promotions and campaigns
4. **Analytics Service** (Port 4003) - Real-time analytics and reporting
5. **AI Service** (Port 4004) - Machine learning and forecasting
6. **Integration Service** (Port 4005) - SAP and external system integration
7. **Co-op Service** (Port 4006) - Digital wallets and QR codes
8. **Notification Service** (Port 4007) - Email, SMS, and push notifications
9. **Reporting Service** (Port 4008) - Report generation and scheduling
10. **Workflow Service** (Port 4009) - Business process automation
11. **Audit Service** (Port 4010) - Compliance and audit trails

### Frontend Application
- **React 18** with Material-UI
- **Responsive Design** for desktop and mobile
- **Progressive Web App** capabilities

### Monitoring Stack (Optional)
- **Prometheus** - Metrics collection
- **Grafana** - Dashboards and visualization
- **Loki** - Log aggregation
- **Alert Manager** - Alerting system

## 📊 Master Data Included

### Company Setup
- **Default Company**: Diplomat SA
- **Admin User**: Created with secure password
- **10 System Roles**: From Super Admin to Viewer

### 5-Level Customer Hierarchy
- **Global Accounts**: Shoprite, Pick n Pay, Spar, Woolworths, Massmart
- **Regions**: Western Cape, Gauteng, KwaZulu-Natal
- **Channels**: Hypermarket, Supermarket, Convenience
- **Stores**: 45 sample stores across all channels

### 5-Level Product Hierarchy
- **Categories**: Beverages, Snacks, Personal Care, Home Care, Food
- **Subcategories**: 20 subcategories
- **Brands**: Premium, Value, and Own brands
- **Product Lines**: Complete product lines
- **SKUs**: 375 individual SKUs with barcodes

### Sample Data (1 Year)
- **50 Promotions** across all types
- **20 Digital Wallets** with transaction history
- **7 Vendors** (multinational and local)
- **AI Insights** and recommendations
- **Workflow Templates** for approvals
- **Budget Categories** and allocations

## 🔐 Security Features

### Automatic Security Setup
- **SSL Certificates** - Let's Encrypt or self-signed
- **Firewall Configuration** - UFW/firewalld with proper rules
- **Fail2ban** - Intrusion prevention
- **Security Headers** - HSTS, CSP, XSS protection
- **Rate Limiting** - API and web application protection

### Access Control
- **Role-Based Access Control** (RBAC)
- **Microsoft 365 SSO** integration ready
- **JWT Authentication** with secure tokens
- **Password Policies** and secure storage

## 📈 Monitoring & Maintenance

### Health Monitoring
```bash
# Check system status
vantax-status

# View service logs
vantax-logs [service-name]

# Run health check
vantax-health

# View system metrics
curl http://localhost:4000/metrics
```

### Backup System
- **Automated Daily Backups** at 2 AM
- **30-Day Retention** policy
- **Database, Files, and Configuration** included
- **S3 Upload** support (optional)

### Log Management
- **Centralized Logging** with Loki
- **Log Rotation** and retention
- **Error Tracking** and alerting
- **Performance Monitoring**

## 🔧 Configuration

### Post-Deployment Configuration

#### 1. Microsoft 365 SSO Setup
```bash
# Edit environment file
sudo nano /etc/vantax/vantax.env

# Update these variables:
AZURE_AD_CLIENT_ID=your-client-id
AZURE_AD_CLIENT_SECRET=your-client-secret
AZURE_AD_TENANT_ID=your-tenant-id

# Restart services
sudo systemctl restart vantax
```

#### 2. SAP Integration (Optional)
```bash
# Update SAP configuration
SAP_BASE_URL=https://your-sap-system.com
SAP_CLIENT_ID=your-sap-client
SAP_CLIENT_SECRET=your-sap-secret
ENABLE_SAP_INTEGRATION=true
```

#### 3. AI Features (Optional)
```bash
# Add OpenAI API key for AI features
OPENAI_API_KEY=your-openai-api-key
ENABLE_AI_FEATURES=true
```

#### 4. Email Configuration
```bash
# Configure SMTP for notifications
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Docker Build Failures
```bash
# Check Docker status
sudo systemctl status docker

# Restart Docker if needed
sudo systemctl restart docker

# Clean Docker cache
sudo docker system prune -a
```

#### 2. Database Connection Issues
```bash
# Check PostgreSQL status
sudo docker logs vantax-postgres

# Verify database credentials
sudo cat /etc/vantax/vantax.env | grep DB_
```

#### 3. SSL Certificate Issues
```bash
# Check certificate status
sudo certbot certificates

# Renew certificates manually
sudo certbot renew

# Check Nginx configuration
sudo nginx -t
```

#### 4. Service Health Issues
```bash
# Check all services
sudo docker ps

# Restart specific service
sudo docker restart vantax-[service-name]

# View service logs
sudo docker logs vantax-[service-name]
```

### Performance Optimization

#### 1. Database Tuning
```bash
# Monitor database performance
sudo docker exec vantax-postgres psql -U vantax_user -d vantax -c "
SELECT query, calls, total_time, mean_time 
FROM pg_stat_statements 
ORDER BY total_time DESC LIMIT 10;"
```

#### 2. Memory Usage
```bash
# Check memory usage
free -h
sudo docker stats

# Adjust service memory limits if needed
```

#### 3. Disk Space Management
```bash
# Check disk usage
df -h

# Clean old Docker images
sudo docker image prune -a

# Clean old backups
sudo find /var/backups/vantax -name "*.tar.gz" -mtime +30 -delete
```

## 📞 Support & Maintenance

### Regular Maintenance Tasks

#### Weekly
- Review system logs for errors
- Check backup completion
- Monitor disk space usage
- Review security alerts

#### Monthly
- Update system packages
- Review user access and permissions
- Analyze performance metrics
- Test backup restoration

#### Quarterly
- Security audit and penetration testing
- Performance optimization review
- Capacity planning assessment
- Disaster recovery testing

### Getting Help

1. **Documentation**: Check the [Wiki](https://github.com/Reshigan/vanta-x-trade-spend-final/wiki)
2. **Issues**: Report bugs on [GitHub Issues](https://github.com/Reshigan/vanta-x-trade-spend-final/issues)
3. **Community**: Join our [Discord Server](https://discord.gg/vantax)
4. **Enterprise Support**: Contact support@vantax.com

## 🔄 Updates and Upgrades

### Automatic Updates
```bash
# Update to latest version
sudo vantax-update

# This will:
# - Pull latest code from GitHub
# - Update Docker images
# - Restart services
# - Run database migrations
```

### Manual Updates
```bash
# Pull latest changes
cd /opt/vantax/vanta-x-trade-spend-final
sudo git pull origin main

# Rebuild and restart services
sudo docker compose -f deployment/docker-compose.prod.yml up -d --build
```

## 📋 Deployment Checklist

### Pre-Deployment
- [ ] Server meets minimum requirements
- [ ] Domain name configured (if using custom domain)
- [ ] DNS records pointing to server
- [ ] Firewall ports opened (80, 443, 22)
- [ ] Backup strategy planned

### During Deployment
- [ ] Run deployment script as root/sudo
- [ ] Provide required configuration details
- [ ] Monitor deployment progress
- [ ] Note generated passwords and credentials

### Post-Deployment
- [ ] Access web application successfully
- [ ] Configure Microsoft 365 SSO (if needed)
- [ ] Set up email notifications
- [ ] Configure monitoring alerts
- [ ] Test backup and restore procedures
- [ ] Train users on the system

### Production Readiness
- [ ] SSL certificate installed and working
- [ ] Monitoring dashboards configured
- [ ] Backup system tested
- [ ] Security scan completed
- [ ] Performance baseline established
- [ ] Documentation updated
- [ ] Support contacts established

## 🎉 Success!

Once deployment is complete, you'll have a fully functional, enterprise-ready FMCG Trade Marketing Management Platform with:

- ✅ Complete microservices architecture
- ✅ AI-powered forecasting and analytics
- ✅ Digital wallet system with QR codes
- ✅ 5-level hierarchies for customers and products
- ✅ Comprehensive master data
- ✅ Security and compliance features
- ✅ Monitoring and alerting
- ✅ Automated backups
- ✅ Mobile-ready interface

**Welcome to Vanta X - Your Complete Trade Marketing Solution!**

---

**Version**: 1.0.0  
**Last Updated**: December 2024  
**Support**: support@vantax.com