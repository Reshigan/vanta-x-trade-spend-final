import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../config';
import { logger } from '../utils/logger';

interface UserPayload {
  id: string;
  email: string;
  companyId: string;
  role: string;
}

declare global {
  namespace Express {
    interface Request {
      user?: UserPayload;
    }
  }
}

export const authMiddleware = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const token = extractToken(req);
    
    if (!token) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'No authentication token provided'
      });
    }
    
    const decoded = jwt.verify(token, config.jwtSecret) as UserPayload;
    req.user = decoded;
    
    // Log request for audit
    logger.info('Authenticated request', {
      userId: decoded.id,
      companyId: decoded.companyId,
      path: req.path,
      method: req.method
    });
    
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        error: 'Token Expired',
        message: 'Your session has expired. Please login again.'
      });
    }
    
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({
        error: 'Invalid Token',
        message: 'The provided token is invalid.'
      });
    }
    
    logger.error('Authentication error:', error);
    return res.status(500).json({
      error: 'Authentication Error',
      message: 'An error occurred during authentication'
    });
  }
};

function extractToken(req: Request): string | null {
  // Check Authorization header
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return authHeader.substring(7);
  }
  
  // Check cookie
  if (req.cookies && req.cookies.token) {
    return req.cookies.token;
  }
  
  // Check query parameter (for download links)
  if (req.query.token && typeof req.query.token === 'string') {
    return req.query.token;
  }
  
  return null;
}