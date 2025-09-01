import dotenv from 'dotenv';

dotenv.config();

export const config = {
  port: process.env.PORT || 4000,
  nodeEnv: process.env.NODE_ENV || 'development',
  corsOrigins: process.env.CORS_ORIGINS?.split(',') || ['http://localhost:3000', 'http://localhost:3001'],
  jwtSecret: process.env.JWT_SECRET || 'your-secret-key',
  redisUrl: process.env.REDIS_URL || 'redis://localhost:6379',
  services: {
    identity: process.env.IDENTITY_SERVICE_URL || 'http://identity-service:4001',
    company: process.env.COMPANY_SERVICE_URL || 'http://company-service:4002',
    tradeMarketing: process.env.TRADE_MARKETING_SERVICE_URL || 'http://trade-marketing-service:4003',
    analytics: process.env.ANALYTICS_SERVICE_URL || 'http://analytics-service:4004',
    notification: process.env.NOTIFICATION_SERVICE_URL || 'http://notification-service:4005',
    integration: process.env.INTEGRATION_SERVICE_URL || 'http://integration-service:4006',
    ai: process.env.AI_SERVICE_URL || 'http://ai-service:4007',
    admin: process.env.ADMIN_SERVICE_URL || 'http://admin-service:4008'
  },
  rateLimit: {
    windowMs: 60 * 1000, // 1 minute
    max: parseInt(process.env.RATE_LIMIT_MAX || '100')
  }
};