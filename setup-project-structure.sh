#!/bin/bash

# Vanta X - Project Structure Setup Script
# This script creates the complete project structure needed for deployment

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_message() {
    echo -e "${2}${1}${NC}"
}

print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║          Vanta X - Project Structure Setup                       ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

create_backend_service() {
    local service_name=$1
    local service_port=$2
    local service_desc=$3
    
    print_message "Creating $service_name..." $YELLOW
    
    mkdir -p "backend/$service_name/src"
    
    # Create package.json
    cat > "backend/$service_name/package.json" << EOF
{
  "name": "@vantax/$service_name",
  "version": "1.0.0",
  "description": "$service_desc",
  "main": "dist/main.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/main.js",
    "dev": "nodemon --exec ts-node src/main.ts",
    "test": "jest",
    "migrate:dev": "prisma migrate dev",
    "migrate:deploy": "prisma migrate deploy"
  },
  "dependencies": {
    "@nestjs/common": "^10.0.0",
    "@nestjs/core": "^10.0.0",
    "@nestjs/platform-express": "^10.0.0",
    "@nestjs/microservices": "^10.0.0",
    "@nestjs/swagger": "^7.0.0",
    "@prisma/client": "^5.0.0",
    "express": "^4.18.2",
    "helmet": "^7.0.0",
    "compression": "^1.7.4",
    "cors": "^2.8.5",
    "dotenv": "^16.0.3",
    "joi": "^17.9.2",
    "winston": "^3.9.0",
    "bull": "^4.10.4",
    "ioredis": "^5.3.2",
    "amqplib": "^0.10.3"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "@types/express": "^4.17.17",
    "typescript": "^5.0.0",
    "nodemon": "^3.0.0",
    "ts-node": "^10.9.1",
    "jest": "^29.5.0",
    "@types/jest": "^29.5.0",
    "prisma": "^5.0.0"
  }
}
EOF

    # Create tsconfig.json
    cat > "backend/$service_name/tsconfig.json" << EOF
{
  "compilerOptions": {
    "module": "commonjs",
    "declaration": true,
    "removeComments": true,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "allowSyntheticDefaultImports": true,
    "target": "ES2021",
    "sourceMap": true,
    "outDir": "./dist",
    "baseUrl": "./",
    "incremental": true,
    "skipLibCheck": true,
    "strictNullChecks": false,
    "noImplicitAny": false,
    "strictBindCallApply": false,
    "forceConsistentCasingInFileNames": false,
    "noFallthroughCasesInSwitch": false,
    "resolveJsonModule": true
  }
}
EOF

    # Create Dockerfile
    cat > "backend/$service_name/Dockerfile" << EOF
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY src ./src
COPY prisma ./prisma 2>/dev/null || true

# Build application
RUN npm run build

# Production stage
FROM node:18-alpine

WORKDIR /app

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Copy package files
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production && npm cache clean --force

# Copy built application
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma 2>/dev/null || true

# Create non-root user
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
USER nodejs

# Expose port
EXPOSE $service_port

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:$service_port/health', (r) => r.statusCode === 200 ? process.exit(0) : process.exit(1))"

# Start application
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/main.js"]
EOF

    # Create main.ts
    cat > "backend/$service_name/src/main.ts" << EOF
import express from 'express';
import helmet from 'helmet';
import compression from 'compression';
import cors from 'cors';
import { createLogger } from 'winston';
import * as dotenv from 'dotenv';

dotenv.config();

const app = express();
const port = process.env.PORT || $service_port;

// Logger setup
const logger = createLogger({
  level: 'info',
  format: winston.format.json(),
  transports: [
    new winston.transports.Console({
      format: winston.format.simple(),
    }),
  ],
});

// Middleware
app.use(helmet());
app.use(compression());
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: '$service_name',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  });
});

// Metrics endpoint
app.get('/metrics', (req, res) => {
  res.json({
    memory: process.memoryUsage(),
    cpu: process.cpuUsage(),
    uptime: process.uptime(),
  });
});

// Start server
app.listen(port, () => {
  logger.info(\`$service_name listening on port \${port}\`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM signal received: closing HTTP server');
  app.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
});
EOF

    # Create .env.example
    cat > "backend/$service_name/.env.example" << EOF
NODE_ENV=development
PORT=$service_port
DATABASE_URL=postgresql://user:password@localhost:5432/vantax
REDIS_URL=redis://localhost:6379
RABBITMQ_URL=amqp://localhost:5672
JWT_SECRET=your-secret-key
EOF

    print_message "✓ Created $service_name" $GREEN
}

create_frontend_structure() {
    print_message "Creating frontend structure..." $YELLOW
    
    mkdir -p frontend/web-app/{src,public}
    
    # Create package.json
    cat > "frontend/web-app/package.json" << EOF
{
  "name": "@vantax/web-app",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.14.0",
    "@mui/material": "^5.14.0",
    "@emotion/react": "^11.11.0",
    "@emotion/styled": "^11.11.0",
    "@tanstack/react-query": "^4.29.0",
    "axios": "^1.4.0",
    "recharts": "^2.7.0",
    "date-fns": "^2.30.0",
    "react-hook-form": "^7.45.0",
    "zustand": "^4.3.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "@vitejs/plugin-react": "^4.0.0",
    "typescript": "^5.0.0",
    "vite": "^4.4.0",
    "eslint": "^8.45.0",
    "@typescript-eslint/eslint-plugin": "^5.61.0",
    "@typescript-eslint/parser": "^5.61.0"
  },
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview",
    "lint": "eslint src --ext ts,tsx --report-unused-disable-directives --max-warnings 0"
  }
}
EOF

    # Create vite.config.ts
    cat > "frontend/web-app/vite.config.ts" << EOF
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    host: true,
    proxy: {
      '/api': {
        target: 'http://localhost:4000',
        changeOrigin: true,
      },
    },
  },
});
EOF

    # Create Dockerfile
    cat > "frontend/web-app/Dockerfile" << EOF
# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Build application
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy built files
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
EOF

    # Create nginx.conf
    cat > "frontend/web-app/nginx.conf" << EOF
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;

    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # React Router support
    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
EOF

    # Create index.html
    cat > "frontend/web-app/public/index.html" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Vanta X - Trade Spend Management</title>
    <link rel="icon" type="image/x-icon" href="/favicon.ico">
</head>
<body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
</body>
</html>
EOF

    # Create main.tsx
    mkdir -p frontend/web-app/src
    cat > "frontend/web-app/src/main.tsx" << EOF
import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ThemeProvider, createTheme } from '@mui/material/styles';
import CssBaseline from '@mui/material/CssBaseline';
import App from './App';

const queryClient = new QueryClient();
const theme = createTheme({
  palette: {
    primary: {
      main: '#1976d2',
    },
    secondary: {
      main: '#dc004e',
    },
  },
});

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <BrowserRouter>
      <QueryClientProvider client={queryClient}>
        <ThemeProvider theme={theme}>
          <CssBaseline />
          <App />
        </ThemeProvider>
      </QueryClientProvider>
    </BrowserRouter>
  </React.StrictMode>
);
EOF

    # Create App.tsx
    cat > "frontend/web-app/src/App.tsx" << EOF
import React from 'react';
import { Container, Typography, Box } from '@mui/material';

function App() {
  return (
    <Container maxWidth="lg">
      <Box sx={{ my: 4 }}>
        <Typography variant="h2" component="h1" gutterBottom>
          Vanta X - Trade Spend Management
        </Typography>
        <Typography variant="h5" component="h2" gutterBottom>
          Welcome to your FMCG Trade Marketing Platform
        </Typography>
      </Box>
    </Container>
  );
}

export default App;
EOF

    print_message "✓ Created frontend structure" $GREEN
}

create_shared_components() {
    print_message "Creating shared components..." $YELLOW
    
    # Create shared Prisma schema
    mkdir -p backend/shared/prisma
    cat > "backend/shared/prisma/schema.prisma" << EOF
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model Company {
  id        String   @id @default(cuid())
  name      String
  code      String   @unique
  type      String
  status    String
  country   String
  currency  String
  timezone  String
  settings  Json?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}

model User {
  id            String   @id @default(cuid())
  email         String   @unique
  password      String
  firstName     String
  lastName      String
  status        String
  emailVerified Boolean  @default(false)
  companyId     String
  roleId        String
  preferences   Json?
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt
}

model Role {
  id          String   @id @default(cuid())
  name        String
  code        String   @unique
  description String?
  level       Int
  permissions Json?
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
}
EOF

    # Create deployment nginx config
    mkdir -p deployment/nginx
    cat > "deployment/nginx/nginx.conf" << EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/json application/xml+rss;

    # Include server configurations
    include /etc/nginx/conf.d/*.conf;
}
EOF

    # Create monitoring configs
    mkdir -p deployment/monitoring
    cat > "deployment/monitoring/promtail.yml" << EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: containers
    static_configs:
      - targets:
          - localhost
        labels:
          job: vantax-containers
          __path__: /var/lib/docker/containers/*/*log
    pipeline_stages:
      - json:
          expressions:
            output: log
            stream: stream
            attrs:
      - json:
          expressions:
            tag:
          source: attrs
      - regex:
          expression: '(?P<container_name>(?:[^|]*))\|(?P<image_name>(?:[^|]*))\|(?P<image_id>(?:[^|]*))\|(?P<container_id>(?:[^|]*))'
          source: tag
      - timestamp:
          format: RFC3339Nano
          source: time
      - labels:
          stream:
          container_name:
          image_name:
          image_id:
          container_id:
      - output:
          source: output
EOF

    print_message "✓ Created shared components" $GREEN
}

create_scripts_directory() {
    print_message "Creating scripts directory..." $YELLOW
    
    mkdir -p scripts
    
    # Create database seed script
    cat > "scripts/seed-database.ts" << EOF
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding database...');
  
  // Seed logic will be added by deploy-production.sh
  
  console.log('Database seeded successfully!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.\$disconnect();
  });
EOF

    print_message "✓ Created scripts directory" $GREEN
}

main() {
    print_banner
    
    print_message "Setting up Vanta X project structure..." $BLUE
    
    # Backend services
    print_message "\nCreating backend services..." $BLUE
    create_backend_service "api-gateway" "4000" "API Gateway for Vanta X"
    create_backend_service "identity-service" "4001" "Identity and Authentication Service"
    create_backend_service "operations-service" "4002" "Operations Management Service"
    create_backend_service "analytics-service" "4003" "Analytics and Reporting Service"
    create_backend_service "ai-service" "4004" "AI and Machine Learning Service"
    create_backend_service "integration-service" "4005" "External Integration Service"
    create_backend_service "coop-service" "4006" "Co-op Management Service"
    create_backend_service "notification-service" "4007" "Notification Service"
    create_backend_service "reporting-service" "4008" "Report Generation Service"
    create_backend_service "workflow-service" "4009" "Workflow Engine Service"
    create_backend_service "audit-service" "4010" "Audit and Compliance Service"
    
    # Frontend
    print_message "\nCreating frontend application..." $BLUE
    create_frontend_structure
    
    # Shared components
    print_message "\nCreating shared components..." $BLUE
    create_shared_components
    
    # Scripts
    print_message "\nCreating scripts..." $BLUE
    create_scripts_directory
    
    # Create .gitignore
    cat > ".gitignore" << EOF
# Dependencies
node_modules/
.pnp
.pnp.js

# Testing
coverage/
.nyc_output/

# Production
dist/
build/

# Misc
.DS_Store
.env
.env.local
.env.development.local
.env.test.local
.env.production.local
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
lerna-debug.log*

# IDE
.idea/
.vscode/
*.swp
*.swo
*~

# OS
Thumbs.db

# Docker
.docker/

# Prisma
*.db
*.db-journal
migrations/
EOF

    print_message "\n✅ Project structure created successfully!" $GREEN
    print_message "\nYou can now run the deployment script:" $YELLOW
    print_message "  sudo ./deploy-production.sh" $CYAN
}

# Run main function
main "$@"