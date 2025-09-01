import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import { createProxyMiddleware } from 'http-proxy-middleware';
import rateLimit from 'express-rate-limit';
import swaggerUi from 'swagger-ui-express';
import YAML from 'yamljs';
import path from 'path';
import { logger } from './utils/logger';
import { authMiddleware } from './middleware/auth';
import { errorHandler } from './middleware/errorHandler';
import { config } from './config';

const app = express();

// Security middleware
app.use(helmet());
app.use(cors({
  origin: config.corsOrigins,
  credentials: true
}));
app.use(compression());

// Rate limiting
const limiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 minute
  max: 100, // 100 requests per minute
  message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', limiter);

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Ready check
app.get('/ready', async (req, res) => {
  try {
    // Check all service connections
    const services = await checkServiceHealth();
    const allHealthy = services.every(s => s.healthy);
    
    if (allHealthy) {
      res.json({ status: 'ready', services });
    } else {
      res.status(503).json({ status: 'not ready', services });
    }
  } catch (error) {
    res.status(503).json({ status: 'error', error: error.message });
  }
});

// API Documentation
const swaggerDocument = YAML.load(path.join(__dirname, '../../../docs/api/openapi.yaml'));
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument));

// Service routes with authentication
const services = [
  { path: '/api/v1/auth', target: 'http://identity-service:4001', auth: false },
  { path: '/api/v1/companies', target: 'http://company-service:4002', auth: true },
  { path: '/api/v1/promotions', target: 'http://trade-marketing-service:4003', auth: true },
  { path: '/api/v1/trade-spend', target: 'http://trade-marketing-service:4003', auth: true },
  { path: '/api/v1/analytics', target: 'http://analytics-service:4004', auth: true },
  { path: '/api/v1/notifications', target: 'http://notification-service:4005', auth: true },
  { path: '/api/v1/integration', target: 'http://integration-service:4006', auth: true },
  { path: '/api/v1/ai', target: 'http://ai-service:4007', auth: true },
  { path: '/api/v1/chatbot', target: 'http://ai-service:4007', auth: true },
  { path: '/api/v1/admin', target: 'http://admin-service:4008', auth: true }
];

// Setup proxy routes
services.forEach(service => {
  const middlewares = [];
  
  if (service.auth) {
    middlewares.push(authMiddleware);
  }
  
  middlewares.push(createProxyMiddleware({
    target: service.target,
    changeOrigin: true,
    pathRewrite: {
      [`^${service.path}`]: ''
    },
    onError: (err, req, res) => {
      logger.error(`Proxy error for ${service.path}:`, err);
      res.status(502).json({
        error: 'Service unavailable',
        message: 'The requested service is temporarily unavailable'
      });
    },
    onProxyReq: (proxyReq, req) => {
      // Forward user context
      if (req.user) {
        proxyReq.setHeader('X-User-Id', req.user.id);
        proxyReq.setHeader('X-Company-Id', req.user.companyId);
        proxyReq.setHeader('X-User-Role', req.user.role);
      }
    }
  }));
  
  app.use(service.path, ...middlewares);
});

// Error handling
app.use(errorHandler);

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: 'The requested resource was not found'
  });
});

// Service health check function
async function checkServiceHealth(): Promise<any[]> {
  const serviceChecks = [
    { name: 'identity-service', url: 'http://identity-service:4001/health' },
    { name: 'company-service', url: 'http://company-service:4002/health' },
    { name: 'trade-marketing-service', url: 'http://trade-marketing-service:4003/health' },
    { name: 'analytics-service', url: 'http://analytics-service:4004/health' },
    { name: 'ai-service', url: 'http://ai-service:4007/health' }
  ];
  
  const results = await Promise.all(
    serviceChecks.map(async service => {
      try {
        const response = await fetch(service.url);
        return {
          name: service.name,
          healthy: response.ok,
          status: response.status
        };
      } catch (error) {
        return {
          name: service.name,
          healthy: false,
          error: error.message
        };
      }
    })
  );
  
  return results;
}

// Start server
const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  logger.info(`API Gateway running on port ${PORT}`);
  logger.info(`API Documentation available at http://localhost:${PORT}/api-docs`);
});