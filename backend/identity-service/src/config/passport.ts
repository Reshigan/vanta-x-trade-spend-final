import { PassportStatic } from 'passport';
import { OIDCStrategy } from 'passport-azure-ad';
import { PrismaClient } from '@prisma/client';
import { config } from './index';
import { logger } from '../utils/logger';

const prisma = new PrismaClient();

export function configurePassport(passport: PassportStatic) {
  // Microsoft Azure AD Strategy
  passport.use(new OIDCStrategy({
    identityMetadata: `https://login.microsoftonline.com/${config.azure.tenantId}/v2.0/.well-known/openid-configuration`,
    clientID: config.azure.clientId,
    clientSecret: config.azure.clientSecret,
    responseType: 'code',
    responseMode: 'form_post',
    redirectUrl: config.azure.redirectUrl,
    allowHttpForRedirectUrl: config.nodeEnv === 'development',
    validateIssuer: true,
    passReqToCallback: false,
    scope: config.azure.scope,
    loggingLevel: 'info',
    nonceLifetime: 3600,
    nonceMaxAmount: 5,
    useCookieInsteadOfSession: false,
    cookieEncryptionKeys: [
      { key: '12345678901234567890123456789012', iv: '123456789012' }
    ]
  }, async (iss, sub, profile, accessToken, refreshToken, done) => {
    try {
      logger.info('Azure AD authentication callback', { profile });
      
      // Extract user information
      const email = profile._json.email || profile._json.preferred_username;
      const firstName = profile._json.given_name || profile.name?.givenName || '';
      const lastName = profile._json.family_name || profile.name?.familyName || '';
      
      if (!email) {
        return done(new Error('No email found in Azure AD profile'), null);
      }
      
      // Find or create user
      let user = await prisma.user.findUnique({
        where: { email },
        include: { company: true }
      });
      
      if (!user) {
        // Check if user's company exists
        const domain = email.split('@')[1];
        let company = await prisma.company.findFirst({
          where: { 
            OR: [
              { domain },
              { email: { endsWith: `@${domain}` } }
            ]
          }
        });
        
        if (!company) {
          // Create a trial company for new domains
          company = await prisma.company.create({
            data: {
              name: domain.split('.')[0].toUpperCase(),
              code: `COMP-${Date.now()}`,
              domain,
              email: `admin@${domain}`,
              licenseType: 'TRIAL',
              licenseCount: 10,
              licenseExpiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days
            }
          });
        }
        
        // Create user
        user = await prisma.user.create({
          data: {
            email,
            firstName,
            lastName,
            azureId: profile.oid,
            role: 'USER',
            companyId: company.id,
            isActive: true,
            lastLoginAt: new Date()
          },
          include: { company: true }
        });
      } else {
        // Update last login
        await prisma.user.update({
          where: { id: user.id },
          data: { 
            lastLoginAt: new Date(),
            azureId: user.azureId || profile.oid
          }
        });
      }
      
      return done(null, user);
    } catch (error) {
      logger.error('Error in Azure AD strategy:', error);
      return done(error, null);
    }
  }));
  
  // Serialize user
  passport.serializeUser((user: any, done) => {
    done(null, user.id);
  });
  
  // Deserialize user
  passport.deserializeUser(async (id: string, done) => {
    try {
      const user = await prisma.user.findUnique({
        where: { id },
        include: { company: true }
      });
      done(null, user);
    } catch (error) {
      done(error, null);
    }
  });
}