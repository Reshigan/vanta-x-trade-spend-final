# Vanta X - Trade Spend Management Platform

![Vanta X Logo](./docs/images/vanta-x-logo.png)

## 🚀 Enterprise Trade Marketing Platform

A comprehensive, AI-powered trade spend management platform designed for multi-company retail and distribution enterprises.

### 🌟 Key Features

- **🏢 Multi-Company Architecture**: Support for multiple companies with isolated data
- **🔐 Microsoft 365 SSO**: Enterprise-grade authentication
- **🔌 SAP Integration**: Seamless connection with SAP ECC and S/4HANA
- **📊 Excel Import/Export**: User-friendly data management with templates
- **🤖 AI/ML Analytics**: Advanced optimization and predictions
- **💬 AI Assistant**: Natural language chatbot for insights
- **📱 Responsive Design**: Mobile, tablet, and desktop support
- **🎯 Real-time Analytics**: Live dashboards and monitoring

### 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Frontend                              │
├─────────────────────┬───────────────────────────────────────┤
│     Web App         │          Admin Portal                  │
└─────────────────────┴───────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      API Gateway                             │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┴─────────────────────┐
        ▼                                           ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│   Identity    │  │   Company     │  │Trade Marketing│
│   Service     │  │   Service     │  │   Service     │
└───────────────┘  └───────────────┘  └───────────────┘
        │                  │                  │
        ▼                  ▼                  ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│  Analytics    │  │ Notification  │  │ Integration   │
│   Service     │  │   Service     │  │   Service     │
└───────────────┘  └───────────────┘  └───────────────┘
        │                  │                  │
        ▼                  ▼                  ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│      AI       │  │    Admin      │  │   Database    │
│   Service     │  │   Service     │  │  PostgreSQL   │
└───────────────┘  └───────────────┘  └───────────────┘
```

### 🚀 Quick Start

#### Prerequisites
- Node.js 18+
- Docker & Docker Compose
- PostgreSQL 14+
- Redis 7+

#### Installation

```bash
# Clone the repository
git clone https://github.com/your-org/vanta-x-trade-spend.git
cd vanta-x-trade-spend

# Install dependencies
npm run install:all

# Set up environment variables
cp .env.example .env
# Edit .env with your configuration

# Start with Docker Compose
docker-compose up -d

# Run database migrations
npm run migrate

# Seed test data
npm run seed
```

#### Development

```bash
# Start all services in development mode
npm run dev

# Start specific service
npm run dev:web-app
npm run dev:api-gateway
npm run dev:ai-service
```

### 📦 Services

| Service | Port | Description |
|---------|------|-------------|
| Web App | 3000 | Main user interface |
| Admin Portal | 3001 | Administrative interface |
| API Gateway | 4000 | Central API entry point |
| Identity Service | 4001 | Authentication & authorization |
| Company Service | 4002 | Multi-company management |
| Trade Marketing | 4003 | Promotions & trade spend |
| Analytics Service | 4004 | Data analytics & reporting |
| Notification Service | 4005 | Email & push notifications |
| Integration Service | 4006 | SAP & Excel integration |
| AI Service | 4007 | ML models & chatbot |
| Admin Service | 4008 | System administration |

### 🧪 Testing

```bash
# Run all tests
npm test

# Run specific test suites
npm run test:unit
npm run test:integration
npm run test:e2e
npm run test:performance

# Generate coverage report
npm run test:coverage
```

### 📚 Documentation

- [API Documentation](./docs/api/README.md)
- [User Guide](./docs/user/README.md)
- [Admin Guide](./docs/admin/README.md)
- [Developer Guide](./docs/developer/README.md)

### 🚀 Deployment

See [Deployment Guide](./docs/deployment/README.md) for detailed instructions.

```bash
# Build for production
npm run build

# Deploy with Kubernetes
kubectl apply -f infrastructure/kubernetes/

# Deploy with Docker Swarm
docker stack deploy -c docker-compose.prod.yml vanta-x
```

### 🔒 Security

- OAuth 2.0 / OpenID Connect authentication
- Role-based access control (RBAC)
- Data encryption at rest and in transit
- Regular security audits
- GDPR compliant

### 📊 Performance

- < 200ms average response time
- Supports 1000+ concurrent users
- 99.9% uptime SLA
- Horizontal scaling ready

### 🤝 Contributing

Please read [CONTRIBUTING.md](./CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

### 📄 License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.

### 👥 Team

- **Product Owner**: Trade Marketing Team
- **Tech Lead**: Engineering Team
- **AI/ML**: Data Science Team
- **DevOps**: Infrastructure Team

### 📞 Support

- **Email**: support@vantax.com
- **Documentation**: https://docs.vantax.com
- **Issues**: GitHub Issues

---

**Vanta X** - Empowering Trade Marketing Excellence 🚀