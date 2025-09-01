import { Router } from 'express';
import { AIController } from '../controllers/AIController';

const router = Router();
const aiController = new AIController();

// Trade Spend Optimization
router.post('/optimize/trade-spend', aiController.optimizeTradeSpend.bind(aiController));
router.post('/train/trade-spend', aiController.trainTradeSpendModel.bind(aiController));

// Anomaly Detection
router.post('/anomaly/detect', aiController.detectAnomalies.bind(aiController));
router.post('/anomaly/train', aiController.trainAnomalyDetector.bind(aiController));

// Predictive Analytics
router.post('/predict', aiController.generatePredictions.bind(aiController));
router.post('/analyze/trends', aiController.analyzeTrends.bind(aiController));
router.post('/forecast/scenarios', aiController.forecastScenarios.bind(aiController));

// Combined AI Insights
router.post('/insights', aiController.getAIInsights.bind(aiController));

// Model Management
router.get('/models/status', aiController.getModelStatus.bind(aiController));

export default router;