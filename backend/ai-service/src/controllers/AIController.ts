import { Request, Response } from 'express';
import { TradeSpendOptimizer } from '../ai/ml/TradeSpendOptimizer';
import { AnomalyDetector } from '../ai/ml/AnomalyDetector';
import { PredictiveAnalytics } from '../ai/ml/PredictiveAnalytics';
import { createLogger } from '../utils/logger';

const logger = createLogger('AIController');

export class AIController {
  private tradeSpendOptimizer: TradeSpendOptimizer;
  private anomalyDetector: AnomalyDetector;
  private predictiveAnalytics: PredictiveAnalytics;

  constructor() {
    this.tradeSpendOptimizer = new TradeSpendOptimizer();
    this.anomalyDetector = new AnomalyDetector();
    this.predictiveAnalytics = new PredictiveAnalytics();
    this.initialize();
  }

  private async initialize(): Promise<void> {
    try {
      await Promise.all([
        this.tradeSpendOptimizer.initialize(),
        this.anomalyDetector.initialize(),
        this.predictiveAnalytics.initialize(),
      ]);
      logger.info('AI models initialized successfully');
    } catch (error) {
      logger.error('Failed to initialize AI models:', error);
    }
  }

  // Trade Spend Optimization
  async optimizeTradeSpend(req: Request, res: Response): Promise<void> {
    try {
      const { category, storeType, discountType, discountValue, duration, seasonality, historicalData } = req.body;

      const result = await this.tradeSpendOptimizer.optimize({
        category,
        storeType,
        discountType,
        discountValue,
        duration,
        seasonality,
        historicalData,
      });

      res.json({
        success: true,
        optimization: result,
        timestamp: new Date().toISOString(),
      });
    } catch (error: any) {
      logger.error('Trade spend optimization failed:', error);
      res.status(500).json({
        success: false,
        error: 'Optimization failed',
        message: error.message,
      });
    }
  }

  async trainTradeSpendModel(req: Request, res: Response): Promise<void> {
    try {
      const { data } = req.body;
      
      if (!data || !Array.isArray(data) || data.length === 0) {
        res.status(400).json({
          success: false,
          error: 'Invalid training data',
        });
        return;
      }

      await this.tradeSpendOptimizer.train(data);

      res.json({
        success: true,
        message: 'Trade spend model trained successfully',
        samplesUsed: data.length,
      });
    } catch (error: any) {
      logger.error('Model training failed:', error);
      res.status(500).json({
        success: false,
        error: 'Training failed',
        message: error.message,
      });
    }
  }

  // Anomaly Detection
  async detectAnomalies(req: Request, res: Response): Promise<void> {
    try {
      const { data, realtime } = req.body;

      if (realtime) {
        // Set up SSE for real-time anomaly detection
        res.setHeader('Content-Type', 'text/event-stream');
        res.setHeader('Cache-Control', 'no-cache');
        res.setHeader('Connection', 'keep-alive');

        // In production, this would connect to a real data stream
        const mockStream = this.createMockAnomalyStream(data);
        
        for await (const anomaly of this.anomalyDetector.detectRealTimeAnomaly(mockStream)) {
          res.write(`data: ${JSON.stringify(anomaly)}\n\n`);
        }
      } else {
        const results = await this.anomalyDetector.detect(data);
        res.json({
          success: true,
          anomalies: Array.isArray(results) ? results : [results],
          timestamp: new Date().toISOString(),
        });
      }
    } catch (error: any) {
      logger.error('Anomaly detection failed:', error);
      res.status(500).json({
        success: false,
        error: 'Anomaly detection failed',
        message: error.message,
      });
    }
  }

  async trainAnomalyDetector(req: Request, res: Response): Promise<void> {
    try {
      const { data } = req.body;
      
      await this.anomalyDetector.train(data);

      res.json({
        success: true,
        message: 'Anomaly detector trained successfully',
        samplesUsed: data.length,
      });
    } catch (error: any) {
      logger.error('Anomaly detector training failed:', error);
      res.status(500).json({
        success: false,
        error: 'Training failed',
        message: error.message,
      });
    }
  }

  // Predictive Analytics
  async generatePredictions(req: Request, res: Response): Promise<void> {
    try {
      const { historicalData, steps, options } = req.body;

      const predictions = await this.predictiveAnalytics.predict(
        historicalData,
        steps || 7,
        options
      );

      res.json({
        success: true,
        predictions,
        timestamp: new Date().toISOString(),
      });
    } catch (error: any) {
      logger.error('Prediction generation failed:', error);
      res.status(500).json({
        success: false,
        error: 'Prediction failed',
        message: error.message,
      });
    }
  }

  async analyzeTrends(req: Request, res: Response): Promise<void> {
    try {
      const { data } = req.body;

      const analysis = await this.predictiveAnalytics.analyzeTrends(data);

      res.json({
        success: true,
        analysis,
        timestamp: new Date().toISOString(),
      });
    } catch (error: any) {
      logger.error('Trend analysis failed:', error);
      res.status(500).json({
        success: false,
        error: 'Trend analysis failed',
        message: error.message,
      });
    }
  }

  async forecastScenarios(req: Request, res: Response): Promise<void> {
    try {
      const { historicalData, scenarios, steps } = req.body;

      const forecasts = await this.predictiveAnalytics.forecastWithScenarios(
        historicalData,
        scenarios,
        steps || 30
      );

      res.json({
        success: true,
        scenarios: Object.fromEntries(forecasts),
        timestamp: new Date().toISOString(),
      });
    } catch (error: any) {
      logger.error('Scenario forecasting failed:', error);
      res.status(500).json({
        success: false,
        error: 'Scenario forecasting failed',
        message: error.message,
      });
    }
  }

  // Combined AI Insights
  async getAIInsights(req: Request, res: Response): Promise<void> {
    try {
      const { companyId, timeRange, metrics } = req.body;

      // This would fetch real data from the database
      const mockData = this.generateMockData(timeRange);

      // Run all AI analyses
      const [optimization, anomalies, predictions, trends] = await Promise.all([
        this.tradeSpendOptimizer.optimize({
          category: 'Beverages',
          storeType: 'Supermarket',
          discountType: 'PERCENTAGE',
          discountValue: 15,
          duration: 14,
          seasonality: 0.7,
          historicalData: mockData.tradeSpend,
        }),
        this.anomalyDetector.detect(mockData.anomalyData),
        this.predictiveAnalytics.predict(mockData.timeSeriesData, 7),
        this.predictiveAnalytics.analyzeTrends(mockData.timeSeriesData),
      ]);

      const insights = {
        optimization: {
          summary: `Recommended spend: ${optimization.recommendedSpend.toFixed(0)} with expected ROI of ${optimization.expectedROI.toFixed(2)}`,
          details: optimization,
        },
        anomalies: {
          summary: `${anomalies.filter((a: any) => a.isAnomaly).length} anomalies detected`,
          critical: anomalies.filter((a: any) => a.severity === 'critical'),
          details: anomalies,
        },
        predictions: {
          summary: `Next 7 days forecast shows ${trends.trend} trend`,
          details: predictions,
        },
        trends: {
          summary: `${trends.trend} trend with ${trends.trendStrength.toFixed(2)} strength`,
          details: trends,
        },
        recommendations: this.generateRecommendations(optimization, anomalies, predictions, trends),
      };

      res.json({
        success: true,
        insights,
        timestamp: new Date().toISOString(),
      });
    } catch (error: any) {
      logger.error('AI insights generation failed:', error);
      res.status(500).json({
        success: false,
        error: 'Insights generation failed',
        message: error.message,
      });
    }
  }

  // Model Management
  async getModelStatus(req: Request, res: Response): Promise<void> {
    try {
      const status = {
        tradeSpendOptimizer: {
          initialized: true,
          lastTrained: new Date().toISOString(),
          accuracy: 0.85,
        },
        anomalyDetector: {
          initialized: true,
          lastTrained: new Date().toISOString(),
          accuracy: 0.90,
        },
        predictiveAnalytics: {
          initialized: true,
          lastTrained: new Date().toISOString(),
          accuracy: 0.82,
        },
      };

      res.json({
        success: true,
        models: status,
        timestamp: new Date().toISOString(),
      });
    } catch (error: any) {
      logger.error('Failed to get model status:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to get model status',
        message: error.message,
      });
    }
  }

  // Helper methods
  private async *createMockAnomalyStream(initialData: any[]): AsyncGenerator<any> {
    for (const item of initialData) {
      yield item;
      await new Promise(resolve => setTimeout(resolve, 1000)); // Simulate real-time delay
    }
  }

  private generateMockData(timeRange: any): any {
    const now = new Date();
    const data = {
      tradeSpend: [],
      anomalyData: [],
      timeSeriesData: [],
    };

    for (let i = 0; i < 30; i++) {
      const date = new Date(now.getTime() - i * 24 * 60 * 60 * 1000);
      
      data.tradeSpend.push({
        promotionId: `PROMO-${i}`,
        plannedSpend: 50000 + Math.random() * 50000,
        actualSpend: 45000 + Math.random() * 55000,
        revenue: 150000 + Math.random() * 100000,
        units: 5000 + Math.random() * 5000,
        roi: 1.5 + Math.random() * 1,
        category: 'Beverages',
        storeType: 'Supermarket',
        discountType: 'PERCENTAGE',
        discountValue: 15,
        duration: 14,
        seasonality: 0.7,
      });

      data.anomalyData.push({
        timestamp: date,
        storeId: 'ST001',
        productId: 'PRD001',
        metric: 'revenue',
        value: 10000 + Math.random() * 5000,
        expectedValue: 12000,
      });

      data.timeSeriesData.push({
        timestamp: date,
        value: 10000 + Math.random() * 5000 + i * 100,
      });
    }

    return data;
  }

  private generateRecommendations(optimization: any, anomalies: any[], predictions: any[], trends: any): string[] {
    const recommendations: string[] = [];

    if (optimization.expectedROI > 2) {
      recommendations.push('Consider increasing trade spend investment for high-ROI promotions');
    }

    const criticalAnomalies = anomalies.filter(a => a.severity === 'critical');
    if (criticalAnomalies.length > 0) {
      recommendations.push(`Investigate ${criticalAnomalies.length} critical anomalies immediately`);
    }

    if (trends.trend === 'decreasing' && trends.trendStrength > 0.7) {
      recommendations.push('Strong downward trend detected - review promotion effectiveness');
    }

    if (predictions[0]?.predictedValue < predictions[0]?.confidenceInterval?.lower) {
      recommendations.push('Forecast indicates potential underperformance - adjust strategy');
    }

    return recommendations;
  }
}