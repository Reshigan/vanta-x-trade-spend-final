# 🚀 VANTA X - AWS PRODUCTION DEPLOYMENT GUIDE

## ✅ COMPLETE AUTOMATION FOR AWS UBUNTU INSTANCES

This guide provides **complete automation** for deploying Vanta X on a fresh AWS Ubuntu instance with **zero build errors guaranteed**.

---

## 🎯 WHAT THIS SCRIPT DOES

### **Complete Fresh Installation:**
- ✅ **Complete cleanup** of any previous installations
- ✅ **Fresh system update** and package installation
- ✅ **Docker installation** from official repository
- ✅ **Node.js 18 LTS** installation
- ✅ **Nginx installation** and configuration
- ✅ **SSL certificate** setup (if domain provided)
- ✅ **AWS security** configuration with UFW firewall
- ✅ **Complete project structure** creation
- ✅ **All 11 microservices** deployment
- ✅ **React frontend** deployment
- ✅ **Infrastructure services** (PostgreSQL, Redis, RabbitMQ)
- ✅ **System service** creation for auto-start
- ✅ **Management scripts** for operations

---

## 🏗️ AWS INSTANCE REQUIREMENTS

### **Minimum Requirements:**
- **Instance Type**: t3.medium or larger
- **RAM**: 4GB minimum (8GB recommended)
- **Storage**: 20GB minimum (50GB recommended)
- **OS**: Ubuntu 20.04 LTS or 22.04 LTS
- **Network**: Public IP address

### **Recommended Instance Types:**
- **Development**: t3.medium (2 vCPU, 4GB RAM)
- **Production**: t3.large (2 vCPU, 8GB RAM)
- **High Performance**: m5.large (2 vCPU, 8GB RAM)
- **Enterprise**: m5.xlarge (4 vCPU, 16GB RAM)

---

## 🚀 DEPLOYMENT STEPS

### **Step 1: Launch AWS EC2 Instance**

1. **Launch Ubuntu Instance:**
   ```bash
   # In AWS Console:
   # - Choose Ubuntu Server 22.04 LTS
   # - Select t3.medium or larger
   # - Configure Security Group (see below)
   # - Create or select Key Pair
   # - Launch instance
   ```

2. **Configure Security Group:**
   ```bash
   # Required ports:
   Port 22   (SSH)     - Your IP only
   Port 80   (HTTP)    - 0.0.0.0/0
   Port 443  (HTTPS)   - 0.0.0.0/0
   Port 15672 (RabbitMQ) - Your IP only (optional)
   ```

### **Step 2: Connect to Instance**

```bash
# Connect via SSH
ssh -i your-key.pem ubuntu@your-instance-ip

# Switch to root (required for deployment)
sudo su -
```

### **Step 3: Download and Run Deployment Script**

```bash
# Download the deployment script
curl -O https://raw.githubusercontent.com/Reshigan/vanta-x-trade-spend-final/main/aws-production-deploy.sh

# Make it executable
chmod +x aws-production-deploy.sh

# Run the deployment (this will take 10-15 minutes)
./aws-production-deploy.sh
```

### **Step 4: Follow Interactive Setup**

The script will ask for:
- **Domain name** (or press Enter to use IP address)
- **Admin email address** (required)
- **SSL email** (optional, defaults to admin email)
- **Company name** (optional, defaults to "Diplomat SA")

---

## 🔧 WHAT GETS INSTALLED

### **Infrastructure Services:**
- ✅ **PostgreSQL 15** - Primary database
- ✅ **Redis 7** - Caching and session storage
- ✅ **RabbitMQ 3** - Message queue with management UI
- ✅ **Nginx** - Reverse proxy and web server

### **Application Services:**
- ✅ **API Gateway** (Port 4000) - Central routing
- ✅ **Identity Service** (Port 4001) - Authentication
- ✅ **Operations Service** (Port 4002) - Promotions management
- ✅ **Analytics Service** (Port 4003) - Data analysis
- ✅ **AI Service** (Port 4004) - Machine learning
- ✅ **Integration Service** (Port 4005) - External systems
- ✅ **Co-op Service** (Port 4006) - Digital wallets
- ✅ **Notification Service** (Port 4007) - Communications
- ✅ **Reporting Service** (Port 4008) - Report generation
- ✅ **Workflow Service** (Port 4009) - Process automation
- ✅ **Audit Service** (Port 4010) - Compliance tracking

### **Frontend Application:**
- ✅ **React Web App** (Port 3000) - User interface
- ✅ **Responsive Design** - Mobile and desktop
- ✅ **AWS Integration** - Instance information display

---

## 🎯 POST-DEPLOYMENT ACCESS

### **Web Application:**
- **With Domain**: https://your-domain.com
- **With IP**: http://your-ip-address

### **Admin Access:**
- **Email**: As provided during setup
- **Password**: Generated automatically (saved in credentials file)

### **Management Interfaces:**
- **RabbitMQ**: http://your-domain:15672
  - Username: `vantax`
  - Password: Generated automatically

### **Management Commands:**
```bash
# Check system status
vantax-status

# View service logs
vantax-logs [service-name]

# Health check
vantax-health

# Create backup
vantax-backup

# Service control
systemctl start vantax
systemctl stop vantax
systemctl restart vantax
```

---

## 🔒 SECURITY FEATURES

### **Automatic Security Configuration:**
- ✅ **UFW Firewall** - Configured with minimal required ports
- ✅ **SSL Certificate** - Automatic Let's Encrypt setup (if domain provided)
- ✅ **Secure Passwords** - Generated automatically
- ✅ **Docker Security** - Non-root containers
- ✅ **Nginx Security** - Security headers configured

### **AWS Security Recommendations:**
- ✅ **Security Groups** - Restrict access to required ports only
- ✅ **IAM Roles** - Use for service access instead of keys
- ✅ **VPC Configuration** - Deploy in private subnets if possible
- ✅ **CloudWatch** - Enable monitoring and alerting
- ✅ **AWS WAF** - Consider for web application protection

---

## 📊 MONITORING AND MAINTENANCE

### **Built-in Monitoring:**
- ✅ **Health Checks** - All services have health endpoints
- ✅ **Docker Health Checks** - Container-level monitoring
- ✅ **System Monitoring** - Resource usage tracking
- ✅ **Log Management** - Centralized logging

### **Backup Strategy:**
```bash
# Automatic backup script included
vantax-backup

# Backups include:
# - Database dump
# - Configuration files
# - Docker volumes
# - SSL certificates
```

### **AWS Integration:**
- ✅ **Instance Metadata** - Automatic AWS information detection
- ✅ **CloudWatch Ready** - Logs can be forwarded to CloudWatch
- ✅ **Auto Scaling Ready** - Can be used in Auto Scaling Groups
- ✅ **Load Balancer Ready** - Works with AWS Application Load Balancer

---

## 🚨 TROUBLESHOOTING

### **Common Issues and Solutions:**

#### **1. Insufficient Resources**
```bash
# Check system resources
free -h
df -h
htop

# Solution: Upgrade to larger instance type
```

#### **2. Security Group Issues**
```bash
# Check if ports are accessible
telnet your-domain 80
telnet your-domain 443

# Solution: Update AWS Security Group rules
```

#### **3. Domain/DNS Issues**
```bash
# Check DNS resolution
nslookup your-domain
dig your-domain

# Solution: Update DNS records to point to instance IP
```

#### **4. SSL Certificate Issues**
```bash
# Check SSL certificate
openssl s_client -connect your-domain:443

# Manual SSL setup if needed
certbot --nginx -d your-domain
```

#### **5. Service Issues**
```bash
# Check service status
vantax-status
docker ps
systemctl status vantax

# Restart services if needed
systemctl restart vantax
```

---

## 🔄 UPDATES AND MAINTENANCE

### **Updating the Application:**
```bash
# Pull latest changes
cd /opt/vantax/vanta-x-trade-spend-final
git pull origin main

# Rebuild and restart services
systemctl restart vantax
```

### **System Updates:**
```bash
# Update system packages
apt update && apt upgrade -y

# Update Docker images
docker compose -f /opt/vantax/vanta-x-trade-spend-final/deployment/docker-compose.prod.yml pull
systemctl restart vantax
```

### **SSL Certificate Renewal:**
```bash
# Certificates auto-renew, but to check:
certbot certificates

# Manual renewal if needed:
certbot renew
```

---

## 📋 DEPLOYMENT CHECKLIST

### **Pre-Deployment:**
- [ ] AWS EC2 instance launched (t3.medium or larger)
- [ ] Security Group configured (ports 22, 80, 443)
- [ ] SSH key pair available
- [ ] Domain name configured (optional)
- [ ] DNS records pointing to instance (if using domain)

### **During Deployment:**
- [ ] Connected to instance as root
- [ ] Downloaded deployment script
- [ ] Provided required information (domain, email)
- [ ] Deployment completed successfully

### **Post-Deployment:**
- [ ] Web application accessible
- [ ] Admin login working
- [ ] All services healthy (vantax-health)
- [ ] SSL certificate working (if domain used)
- [ ] Credentials saved securely
- [ ] Backup strategy implemented

---

## 🎉 SUCCESS INDICATORS

After successful deployment, you should see:

✅ **Web Application**: Accessible at your domain/IP  
✅ **All Services**: 14 Docker containers running  
✅ **Health Checks**: All services reporting healthy  
✅ **SSL Certificate**: Valid and working (if domain used)  
✅ **Database**: Connected and operational  
✅ **Admin Access**: Login working with generated credentials  
✅ **Management Tools**: All commands working  

---

## 📞 SUPPORT

### **Getting Help:**
- **GitHub Issues**: https://github.com/Reshigan/vanta-x-trade-spend-final/issues
- **Documentation**: Complete guides in repository
- **Logs**: Check deployment logs for specific errors

### **Enterprise Support:**
- **Professional Services**: Available for enterprise deployments
- **Custom Configuration**: Tailored AWS architectures
- **24/7 Support**: Available for production environments

---

## 🏆 DEPLOYMENT GUARANTEE

**This AWS deployment script provides:**

✅ **ZERO Build Errors** - All npm and TypeScript issues resolved  
✅ **Complete Automation** - No manual configuration required  
✅ **Production Ready** - SSL, security, monitoring included  
✅ **AWS Optimized** - Designed specifically for AWS EC2  
✅ **Enterprise Grade** - Suitable for production workloads  

---

## 🚀 QUICK START SUMMARY

```bash
# 1. Launch Ubuntu EC2 instance (t3.medium+)
# 2. Configure Security Group (ports 22, 80, 443)
# 3. SSH to instance and become root
ssh -i key.pem ubuntu@instance-ip
sudo su -

# 4. Run deployment script
curl -O https://raw.githubusercontent.com/Reshigan/vanta-x-trade-spend-final/main/aws-production-deploy.sh
chmod +x aws-production-deploy.sh
./aws-production-deploy.sh

# 5. Access your application
# https://your-domain or http://your-ip
```

**🎊 Your Vanta X FMCG Trade Marketing Platform will be ready in 10-15 minutes! 🎊**