import { Router } from 'express';
import passport from 'passport';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import { body, validationResult } from 'express-validator';
import { PrismaClient } from '@prisma/client';
import { config } from '../config';
import { logger } from '../utils/logger';

const router = Router();
const prisma = new PrismaClient();

// Microsoft SSO login
router.get('/microsoft', passport.authenticate('azuread-openidconnect', {
  failureRedirect: '/auth/login/failed'
}));

// Microsoft SSO callback
router.post('/microsoft/callback',
  passport.authenticate('azuread-openidconnect', {
    failureRedirect: '/auth/login/failed'
  }),
  (req, res) => {
    // Generate JWT token
    const user = req.user as any;
    const token = jwt.sign(
      {
        id: user.id,
        email: user.email,
        companyId: user.companyId,
        role: user.role
      },
      config.jwtSecret,
      { expiresIn: config.jwtExpiresIn }
    );
    
    // Redirect to frontend with token
    res.redirect(`${config.frontendUrl}/auth/callback?token=${token}`);
  }
);

// Traditional login
router.post('/login', [
  body('email').isEmail().normalizeEmail(),
  body('password').notEmpty()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    
    const { email, password } = req.body;
    
    // Find user
    const user = await prisma.user.findUnique({
      where: { email },
      include: { company: true }
    });
    
    if (!user || !user.password) {
      return res.status(401).json({
        error: 'Invalid credentials',
        message: 'Email or password is incorrect'
      });
    }
    
    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.password);
    if (!isValidPassword) {
      return res.status(401).json({
        error: 'Invalid credentials',
        message: 'Email or password is incorrect'
      });
    }
    
    // Check if user is active
    if (!user.isActive) {
      return res.status(403).json({
        error: 'Account disabled',
        message: 'Your account has been disabled. Please contact support.'
      });
    }
    
    // Update last login
    await prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() }
    });
    
    // Generate tokens
    const accessToken = jwt.sign(
      {
        id: user.id,
        email: user.email,
        companyId: user.companyId,
        role: user.role
      },
      config.jwtSecret,
      { expiresIn: config.jwtExpiresIn }
    );
    
    const refreshToken = jwt.sign(
      { id: user.id },
      config.jwtSecret,
      { expiresIn: '7d' }
    );
    
    // Store refresh token
    await prisma.refreshToken.create({
      data: {
        token: refreshToken,
        userId: user.id,
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
      }
    });
    
    logger.info('User logged in', { userId: user.id, email: user.email });
    
    res.json({
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
        role: user.role,
        company: user.company
      }
    });
  } catch (error) {
    logger.error('Login error:', error);
    res.status(500).json({
      error: 'Login failed',
      message: 'An error occurred during login'
    });
  }
});

// Refresh token
router.post('/refresh', async (req, res) => {
  try {
    const { refreshToken } = req.body;
    
    if (!refreshToken) {
      return res.status(400).json({
        error: 'Missing token',
        message: 'Refresh token is required'
      });
    }
    
    // Verify refresh token
    const decoded = jwt.verify(refreshToken, config.jwtSecret) as any;
    
    // Check if token exists in database
    const storedToken = await prisma.refreshToken.findFirst({
      where: {
        token: refreshToken,
        userId: decoded.id,
        expiresAt: { gt: new Date() }
      }
    });
    
    if (!storedToken) {
      return res.status(401).json({
        error: 'Invalid token',
        message: 'Refresh token is invalid or expired'
      });
    }
    
    // Get user
    const user = await prisma.user.findUnique({
      where: { id: decoded.id },
      include: { company: true }
    });
    
    if (!user || !user.isActive) {
      return res.status(403).json({
        error: 'Account disabled',
        message: 'Your account has been disabled'
      });
    }
    
    // Generate new access token
    const accessToken = jwt.sign(
      {
        id: user.id,
        email: user.email,
        companyId: user.companyId,
        role: user.role
      },
      config.jwtSecret,
      { expiresIn: config.jwtExpiresIn }
    );
    
    res.json({ accessToken });
  } catch (error) {
    logger.error('Token refresh error:', error);
    res.status(401).json({
      error: 'Token refresh failed',
      message: 'Failed to refresh token'
    });
  }
});

// Logout
router.post('/logout', async (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    
    if (token) {
      const decoded = jwt.verify(token, config.jwtSecret) as any;
      
      // Remove all refresh tokens for user
      await prisma.refreshToken.deleteMany({
        where: { userId: decoded.id }
      });
    }
    
    req.logout((err) => {
      if (err) {
        logger.error('Logout error:', err);
      }
    });
    
    res.json({ message: 'Logged out successfully' });
  } catch (error) {
    // Still logout even if token is invalid
    res.json({ message: 'Logged out successfully' });
  }
});

// Login failed
router.get('/login/failed', (req, res) => {
  res.status(401).json({
    error: 'Authentication failed',
    message: 'Failed to authenticate with Microsoft'
  });
});

export { router as authRouter };