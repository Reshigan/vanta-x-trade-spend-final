import express from 'express';
import passport from 'passport';
import session from 'express-session';
import RedisStore from 'connect-redis';
import { createClient } from 'redis';
import { authRouter } from './routes/auth';
import { userRouter } from './routes/users';
import { configurePassport } from './config/passport';
import { errorHandler } from './middleware/errorHandler';
import { logger } from './utils/logger';
import { config } from './config';

const app = express();

// Redis client for sessions
const redisClient = createClient({
  url: config.redisUrl
});
redisClient.connect().catch(console.error);

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Session configuration
app.use(session({
  store: new RedisStore({ client: redisClient }),
  secret: config.sessionSecret,
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: config.nodeEnv === 'production',
    httpOnly: true,
    maxAge: 24 * 60 * 60 * 1000 // 24 hours
  }
}));

// Passport configuration
app.use(passport.initialize());
app.use(passport.session());
configurePassport(passport);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'identity-service' });
});

// Routes
app.use('/auth', authRouter);
app.use('/users', userRouter);

// Error handling
app.use(errorHandler);

// Start server
const PORT = process.env.PORT || 4001;
app.listen(PORT, () => {
  logger.info(`Identity Service running on port ${PORT}`);
});