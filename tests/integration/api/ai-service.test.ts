import request from 'supertest';
import express from 'express';
import { AIController } from '../../../backend/ai-service/src/controllers/AIController';
import { ChatbotController } from '../../../backend/ai-service/src/controllers/ChatbotController';

describe('AI Service Integration Tests', () => {
  let app: express.Application;

  beforeAll(() => {
    app = express();
    app.use(express.json());
    
    const aiController = new AIController();
    const chatbotController = new ChatbotController();
    
    // Set up routes
    app.post('/api/v1/ai/optimize/trade-spend', aiController.optimizeTradeSpend.bind(aiController));
    app.post('/api/v1/ai/anomaly/detect', aiController.detectAnomalies.bind(aiController));
    app.post('/api/v1/ai/predict', aiController.generatePredictions.bind(aiController));
    app.post('/api/v1/ai/insights', aiController.getAIInsights.bind(aiController));
    
    app.post('/api/v1/chatbot/sessions/start', chatbotController.startSession.bind(chatbotController));
    app.post('/api/v1/chatbot/message', chatbotController.sendMessage.bind(chatbotController));
  });

  describe('Trade Spend Optimization API', () => {
    it('should optimize trade spend successfully', async () => {
      const requestBody = {
        category: 'Beverages',
        storeType: 'Supermarket',
        discountType: 'PERCENTAGE',
        discountValue: 15,
        duration: 14,
        seasonality: 0.7,
      };

      const response = await request(app)
        .post('/api/v1/ai/optimize/trade-spend')
        .send(requestBody)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.optimization).toBeDefined();
      expect(response.body.optimization.recommendedSpend).toBeGreaterThan(0);
      expect(response.body.optimization.expectedROI).toBeGreaterThan(0);
    });

    it('should handle invalid optimization requests', async () => {
      const response = await request(app)
        .post('/api/v1/ai/optimize/trade-spend')
        .send({})
        .expect(500);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBeDefined();
    });
  });

  describe('Anomaly Detection API', () => {
    it('should detect anomalies in data', async () => {
      const requestBody = {
        data: [
          {
            timestamp: new Date(),
            storeId: 'ST001',
            productId: 'PRD001',
            metric: 'revenue',
            value: -1000, // Negative revenue anomaly
            expectedValue: 10000,
          },
          {
            timestamp: new Date(),
            storeId: 'ST002',
            productId: 'PRD002',
            metric: 'units',
            value: 5000,
            expectedValue: 5100,
          },
        ],
      };

      const response = await request(app)
        .post('/api/v1/ai/anomaly/detect')
        .send(requestBody)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.anomalies).toBeDefined();
      expect(Array.isArray(response.body.anomalies)).toBe(true);
      expect(response.body.anomalies.some((a: any) => a.isAnomaly)).toBe(true);
    });
  });

  describe('Predictive Analytics API', () => {
    it('should generate predictions for time series data', async () => {
      const historicalData = Array.from({ length: 30 }, (_, i) => ({
        timestamp: new Date(Date.now() - (30 - i) * 24 * 60 * 60 * 1000),
        value: 10000 + Math.random() * 5000,
      }));

      const requestBody = {
        historicalData,
        steps: 7,
        options: {
          includeConfidenceInterval: true,
          model: 'ensemble',
        },
      };

      const response = await request(app)
        .post('/api/v1/ai/predict')
        .send(requestBody)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.predictions).toBeDefined();
      expect(response.body.predictions.length).toBe(7);
      expect(response.body.predictions[0]).toHaveProperty('predictedValue');
      expect(response.body.predictions[0]).toHaveProperty('confidenceInterval');
    });
  });

  describe('AI Insights API', () => {
    it('should generate comprehensive AI insights', async () => {
      const requestBody = {
        companyId: 'test-company-id',
        timeRange: {
          start: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000),
          end: new Date(),
        },
        metrics: ['revenue', 'units', 'roi'],
      };

      const response = await request(app)
        .post('/api/v1/ai/insights')
        .send(requestBody)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.insights).toBeDefined();
      expect(response.body.insights.optimization).toBeDefined();
      expect(response.body.insights.anomalies).toBeDefined();
      expect(response.body.insights.predictions).toBeDefined();
      expect(response.body.insights.trends).toBeDefined();
      expect(response.body.insights.recommendations).toBeDefined();
    });
  });

  describe('Chatbot API', () => {
    let sessionId: string;

    it('should start a chat session', async () => {
      const requestBody = {
        userId: 'test-user-id',
        companyId: 'test-company-id',
        userData: {
          name: 'Test User',
          role: 'Trade Marketing Manager',
          department: 'Trade Marketing',
        },
      };

      const response = await request(app)
        .post('/api/v1/chatbot/sessions/start')
        .send(requestBody)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.sessionId).toBeDefined();
      expect(response.body.response).toBeDefined();
      expect(response.body.response.message).toContain('Hello Test User');
      
      sessionId = response.body.sessionId;
    });

    it('should process chat messages', async () => {
      const requestBody = {
        sessionId,
        message: 'What is the optimal trade spend for beverages in supermarkets?',
      };

      const response = await request(app)
        .post('/api/v1/chatbot/message')
        .send(requestBody)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.response).toBeDefined();
      expect(response.body.response.message).toBeDefined();
      expect(response.body.response.message.length).toBeGreaterThan(0);
    });

    it('should handle invalid session', async () => {
      const requestBody = {
        sessionId: 'invalid-session-id',
        message: 'Test message',
      };

      const response = await request(app)
        .post('/api/v1/chatbot/message')
        .send(requestBody)
        .expect(404);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toBe('Session not found');
    });
  });
});