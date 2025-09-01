import { TradeSpendOptimizer, TradeSpendData } from '../../../backend/ai-service/src/ai/ml/TradeSpendOptimizer';

describe('TradeSpendOptimizer', () => {
  let optimizer: TradeSpendOptimizer;

  beforeEach(() => {
    optimizer = new TradeSpendOptimizer();
  });

  describe('initialization', () => {
    it('should initialize without errors', async () => {
      await expect(optimizer.initialize()).resolves.not.toThrow();
    });
  });

  describe('optimization', () => {
    it('should optimize trade spend with valid parameters', async () => {
      const params = {
        category: 'Beverages',
        storeType: 'Supermarket',
        discountType: 'PERCENTAGE',
        discountValue: 15,
        duration: 14,
        seasonality: 0.7,
      };

      const result = await optimizer.optimize(params);

      expect(result).toHaveProperty('recommendedSpend');
      expect(result).toHaveProperty('expectedROI');
      expect(result).toHaveProperty('confidenceScore');
      expect(result).toHaveProperty('insights');
      expect(result).toHaveProperty('riskFactors');
      
      expect(result.recommendedSpend).toBeGreaterThan(0);
      expect(result.expectedROI).toBeGreaterThan(0);
      expect(result.confidenceScore).toBeGreaterThanOrEqual(0);
      expect(result.confidenceScore).toBeLessThanOrEqual(1);
      expect(Array.isArray(result.insights)).toBe(true);
      expect(Array.isArray(result.riskFactors)).toBe(true);
    });

    it('should provide insights for high ROI scenarios', async () => {
      const params = {
        category: 'Beverages',
        storeType: 'Hypermarket',
        discountType: 'PERCENTAGE',
        discountValue: 10,
        duration: 7,
        seasonality: 0.9,
      };

      const result = await optimizer.optimize(params);
      
      expect(result.insights.length).toBeGreaterThan(0);
    });

    it('should identify risk factors for deep discounts', async () => {
      const params = {
        category: 'Snacks',
        storeType: 'Convenience',
        discountType: 'PERCENTAGE',
        discountValue: 35,
        duration: 30,
        seasonality: 0.5,
      };

      const result = await optimizer.optimize(params);
      
      expect(result.riskFactors.length).toBeGreaterThan(0);
      expect(result.riskFactors.some(risk => risk.includes('Deep discount'))).toBe(true);
    });
  });

  describe('anomaly detection', () => {
    it('should detect anomalies in trade spend data', async () => {
      const testData: TradeSpendData[] = [
        {
          promotionId: 'PROMO-001',
          plannedSpend: 50000,
          actualSpend: 48000,
          revenue: 150000,
          units: 5000,
          roi: 2.1,
          category: 'Beverages',
          storeType: 'Supermarket',
          discountType: 'PERCENTAGE',
          discountValue: 15,
          duration: 14,
          seasonality: 0.7,
        },
        {
          promotionId: 'PROMO-002',
          plannedSpend: 50000,
          actualSpend: 150000, // Anomaly: 3x overspend
          revenue: 160000,
          units: 5200,
          roi: 0.07, // Anomaly: Very low ROI
          category: 'Beverages',
          storeType: 'Supermarket',
          discountType: 'PERCENTAGE',
          discountValue: 15,
          duration: 14,
          seasonality: 0.7,
        },
      ];

      const result = await optimizer.detectAnomalies(testData);
      
      expect(result.anomalies).toBeDefined();
      expect(result.anomalies.length).toBeGreaterThan(0);
      expect(result.anomalies[0]).toHaveProperty('index');
      expect(result.anomalies[0]).toHaveProperty('score');
      expect(result.anomalies[0]).toHaveProperty('reason');
    });
  });

  describe('performance forecasting', () => {
    it('should forecast performance for future promotions', async () => {
      const historicalData: TradeSpendData[] = generateMockHistoricalData(30);
      
      const futurePromotions = [
        {
          category: 'Beverages',
          storeType: 'Supermarket',
          plannedSpend: 60000,
          discountType: 'PERCENTAGE',
          discountValue: 20,
          duration: 14,
        },
      ];

      const forecasts = await optimizer.forecastPerformance({
        historicalData,
        futurePromotions,
      });

      expect(forecasts).toBeDefined();
      expect(forecasts.length).toBe(1);
      expect(forecasts[0]).toHaveProperty('promotion');
      expect(forecasts[0]).toHaveProperty('forecast');
      expect(forecasts[0].forecast).toHaveProperty('expectedRevenue');
      expect(forecasts[0].forecast).toHaveProperty('expectedUnits');
      expect(forecasts[0].forecast).toHaveProperty('expectedROI');
      expect(forecasts[0].forecast).toHaveProperty('confidenceInterval');
    });
  });

  describe('model training', () => {
    it('should train the model with historical data', async () => {
      const trainingData: TradeSpendData[] = generateMockHistoricalData(100);
      
      await expect(optimizer.train(trainingData)).resolves.not.toThrow();
    });
  });
});

// Helper function to generate mock historical data
function generateMockHistoricalData(count: number): TradeSpendData[] {
  const data: TradeSpendData[] = [];
  const categories = ['Beverages', 'Snacks', 'Dairy', 'Bakery'];
  const storeTypes = ['Hypermarket', 'Supermarket', 'Convenience', 'Wholesale'];
  const discountTypes = ['PERCENTAGE', 'FIXED_AMOUNT', 'BOGO', 'VOLUME_DISCOUNT'];

  for (let i = 0; i < count; i++) {
    const plannedSpend = 30000 + Math.random() * 70000;
    const actualSpend = plannedSpend * (0.8 + Math.random() * 0.4);
    const revenue = actualSpend * (2 + Math.random() * 3);
    
    data.push({
      promotionId: `PROMO-${String(i + 1).padStart(3, '0')}`,
      plannedSpend,
      actualSpend,
      revenue,
      units: Math.round(revenue / 30),
      roi: revenue / actualSpend,
      category: categories[Math.floor(Math.random() * categories.length)],
      storeType: storeTypes[Math.floor(Math.random() * storeTypes.length)],
      discountType: discountTypes[Math.floor(Math.random() * discountTypes.length)],
      discountValue: 10 + Math.random() * 20,
      duration: 7 + Math.floor(Math.random() * 21),
      seasonality: Math.random(),
    });
  }

  return data;
}