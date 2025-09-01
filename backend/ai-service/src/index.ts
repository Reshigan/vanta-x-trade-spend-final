import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import morgan from 'morgan';
import dotenv from 'dotenv';
import aiRoutes from './routes/aiRoutes';
import chatbotRoutes from './routes/chatbotRoutes';
import { createLogger } from './utils/logger';

dotenv.config();

const app = express();
const logger = createLogger('AIService');
const PORT = process.env.PORT || 3007;

// Middleware
app.use(helmet());
app.use(cors());
app.use(compression());
app.use(morgan('combined'));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    service: 'ai-service',
    timestamp: new Date().toISOString(),
    features: {
      tradeSpendOptimization: true,
      anomalyDetection: true,
      predictiveAnalytics: true,
      aiChatbot: true,
    },
  });
});

// Routes
app.use('/api/v1/ai', aiRoutes);
app.use('/api/v1/chatbot', chatbotRoutes);

// Error handling middleware
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  logger.error('Unhandled error:', err);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal server error',
    error: process.env.NODE_ENV === 'development' ? err : undefined,
  });
});

// Start server
app.listen(PORT, () => {
  logger.info(`AI Service running on port ${PORT}`);
  logger.info('AI features enabled: Trade Spend Optimization, Anomaly Detection, Predictive Analytics');
});