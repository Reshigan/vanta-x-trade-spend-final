import dotenv from 'dotenv';

dotenv.config();

export const config = {
  port: process.env.PORT || 4001,
  nodeEnv: process.env.NODE_ENV || 'development',
  databaseUrl: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/vantax',
  redisUrl: process.env.REDIS_URL || 'redis://localhost:6379',
  jwtSecret: process.env.JWT_SECRET || 'your-secret-key',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '24h',
  sessionSecret: process.env.SESSION_SECRET || 'your-session-secret',
  
  // Microsoft Azure AD Configuration
  azure: {
    clientId: process.env.AZURE_AD_CLIENT_ID || '',
    clientSecret: process.env.AZURE_AD_CLIENT_SECRET || '',
    tenantId: process.env.AZURE_AD_TENANT_ID || 'common',
    redirectUrl: process.env.AZURE_AD_REDIRECT_URL || 'http://localhost:4001/auth/microsoft/callback',
    scope: ['user.read', 'profile', 'email', 'openid']
  },
  
  // Frontend URLs
  frontendUrl: process.env.FRONTEND_URL || 'http://localhost:3000',
  adminUrl: process.env.ADMIN_URL || 'http://localhost:3001'
};