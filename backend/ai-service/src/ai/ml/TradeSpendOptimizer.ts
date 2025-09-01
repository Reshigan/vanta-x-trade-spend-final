import * as tf from '@tensorflow/tfjs-node';
import { Logger } from 'winston';
import { createLogger } from '../../utils/logger';

export interface TradeSpendData {
  promotionId: string;
  plannedSpend: number;
  actualSpend: number;
  revenue: number;
  units: number;
  roi: number;
  category: string;
  storeType: string;
  discountType: string;
  discountValue: number;
  duration: number;
  seasonality: number;
}

export interface OptimizationResult {
  recommendedSpend: number;
  expectedROI: number;
  confidenceScore: number;
  insights: string[];
  riskFactors: string[];
}

export class TradeSpendOptimizer {
  private model: tf.LayersModel | null = null;
  private logger: Logger;
  private scaler: { mean: number[]; std: number[] } | null = null;

  constructor() {
    this.logger = createLogger('TradeSpendOptimizer');
  }

  async initialize(): Promise<void> {
    try {
      // Try to load existing model
      await this.loadModel();
    } catch (error) {
      this.logger.info('No existing model found, creating new model');
      this.createModel();
    }
  }

  private createModel(): void {
    // Create a neural network for trade spend optimization
    this.model = tf.sequential({
      layers: [
        tf.layers.dense({
          inputShape: [12], // Input features
          units: 64,
          activation: 'relu',
          kernelInitializer: 'glorotUniform',
        }),
        tf.layers.dropout({ rate: 0.2 }),
        tf.layers.dense({
          units: 32,
          activation: 'relu',
          kernelInitializer: 'glorotUniform',
        }),
        tf.layers.dropout({ rate: 0.2 }),
        tf.layers.dense({
          units: 16,
          activation: 'relu',
          kernelInitializer: 'glorotUniform',
        }),
        tf.layers.dense({
          units: 3, // Output: recommended spend, expected ROI, confidence
          activation: 'linear',
        }),
      ],
    });

    this.model.compile({
      optimizer: tf.train.adam(0.001),
      loss: 'meanSquaredError',
      metrics: ['mae'],
    });

    this.logger.info('Trade spend optimization model created');
  }

  async train(data: TradeSpendData[]): Promise<void> {
    if (!this.model) {
      throw new Error('Model not initialized');
    }

    this.logger.info(`Training model with ${data.length} samples`);

    // Prepare training data
    const { features, labels, scaler } = this.prepareTrainingData(data);
    this.scaler = scaler;

    // Convert to tensors
    const xTrain = tf.tensor2d(features);
    const yTrain = tf.tensor2d(labels);

    // Train the model
    const history = await this.model.fit(xTrain, yTrain, {
      epochs: 100,
      batchSize: 32,
      validationSplit: 0.2,
      callbacks: {
        onEpochEnd: (epoch, logs) => {
          if (epoch % 10 === 0) {
            this.logger.info(`Epoch ${epoch}: loss = ${logs?.loss?.toFixed(4)}, val_loss = ${logs?.val_loss?.toFixed(4)}`);
          }
        },
      },
    });

    // Clean up tensors
    xTrain.dispose();
    yTrain.dispose();

    // Save the model
    await this.saveModel();

    this.logger.info('Model training completed');
  }

  private prepareTrainingData(data: TradeSpendData[]): {
    features: number[][];
    labels: number[][];
    scaler: { mean: number[]; std: number[] };
  } {
    // Extract features
    const features = data.map(d => [
      d.plannedSpend,
      d.discountValue,
      d.duration,
      d.seasonality,
      this.encodeCategoryType(d.category),
      this.encodeStoreType(d.storeType),
      this.encodeDiscountType(d.discountType),
      d.units,
      d.revenue,
      d.actualSpend,
      d.roi,
      this.calculateEfficiency(d),
    ]);

    // Extract labels (what we want to predict/optimize)
    const labels = data.map(d => [
      d.actualSpend, // Optimal spend
      d.roi, // Expected ROI
      this.calculateConfidence(d), // Confidence score
    ]);

    // Normalize features
    const scaler = this.fitScaler(features);
    const normalizedFeatures = this.transform(features, scaler);

    return { features: normalizedFeatures, labels, scaler };
  }

  private fitScaler(data: number[][]): { mean: number[]; std: number[] } {
    const numFeatures = data[0].length;
    const mean = new Array(numFeatures).fill(0);
    const std = new Array(numFeatures).fill(0);

    // Calculate mean
    for (const row of data) {
      for (let i = 0; i < numFeatures; i++) {
        mean[i] += row[i];
      }
    }
    for (let i = 0; i < numFeatures; i++) {
      mean[i] /= data.length;
    }

    // Calculate standard deviation
    for (const row of data) {
      for (let i = 0; i < numFeatures; i++) {
        std[i] += Math.pow(row[i] - mean[i], 2);
      }
    }
    for (let i = 0; i < numFeatures; i++) {
      std[i] = Math.sqrt(std[i] / data.length);
      if (std[i] === 0) std[i] = 1; // Avoid division by zero
    }

    return { mean, std };
  }

  private transform(data: number[][], scaler: { mean: number[]; std: number[] }): number[][] {
    return data.map(row =>
      row.map((val, i) => (val - scaler.mean[i]) / scaler.std[i])
    );
  }

  async optimize(params: {
    category: string;
    storeType: string;
    discountType: string;
    discountValue: number;
    duration: number;
    seasonality: number;
    historicalData?: TradeSpendData[];
  }): Promise<OptimizationResult> {
    if (!this.model || !this.scaler) {
      throw new Error('Model not trained');
    }

    // Prepare input features
    const avgMetrics = this.calculateAverageMetrics(params.historicalData || []);
    
    const features = [[
      avgMetrics.avgSpend,
      params.discountValue,
      params.duration,
      params.seasonality,
      this.encodeCategoryType(params.category),
      this.encodeStoreType(params.storeType),
      this.encodeDiscountType(params.discountType),
      avgMetrics.avgUnits,
      avgMetrics.avgRevenue,
      avgMetrics.avgSpend,
      avgMetrics.avgROI,
      avgMetrics.efficiency,
    ]];

    // Normalize features
    const normalizedFeatures = this.transform(features, this.scaler);
    const inputTensor = tf.tensor2d(normalizedFeatures);

    // Make prediction
    const prediction = this.model.predict(inputTensor) as tf.Tensor;
    const results = await prediction.array() as number[][];

    // Clean up
    inputTensor.dispose();
    prediction.dispose();

    const [recommendedSpend, expectedROI, confidenceScore] = results[0];

    // Generate insights and risk factors
    const insights = this.generateInsights(params, recommendedSpend, expectedROI);
    const riskFactors = this.identifyRiskFactors(params, confidenceScore);

    return {
      recommendedSpend: Math.max(0, recommendedSpend),
      expectedROI: Math.max(0, expectedROI),
      confidenceScore: Math.min(1, Math.max(0, confidenceScore)),
      insights,
      riskFactors,
    };
  }

  private generateInsights(params: any, recommendedSpend: number, expectedROI: number): string[] {
    const insights: string[] = [];

    if (expectedROI > 2) {
      insights.push('High ROI expected - consider increasing investment');
    } else if (expectedROI < 1) {
      insights.push('Low ROI expected - review promotion mechanics');
    }

    if (params.discountValue > 25) {
      insights.push('Deep discount may erode margins - monitor profitability');
    }

    if (params.duration > 30) {
      insights.push('Long promotion duration - consider shorter bursts for urgency');
    }

    if (params.seasonality > 0.8) {
      insights.push('High seasonality period - leverage seasonal demand');
    }

    return insights;
  }

  private identifyRiskFactors(params: any, confidenceScore: number): string[] {
    const risks: string[] = [];

    if (confidenceScore < 0.6) {
      risks.push('Low confidence - limited historical data for this scenario');
    }

    if (params.discountValue > 30) {
      risks.push('Deep discounts may train customers to wait for promotions');
    }

    if (params.duration < 7) {
      risks.push('Short duration may limit reach and awareness');
    }

    return risks;
  }

  async detectAnomalies(data: TradeSpendData[]): Promise<{
    anomalies: Array<{ index: number; score: number; reason: string }>;
  }> {
    const anomalies: Array<{ index: number; score: number; reason: string }> = [];

    // Calculate statistical thresholds
    const roiValues = data.map(d => d.roi);
    const spendValues = data.map(d => d.actualSpend / d.plannedSpend);
    
    const roiMean = this.mean(roiValues);
    const roiStd = this.std(roiValues);
    const spendMean = this.mean(spendValues);
    const spendStd = this.std(spendValues);

    data.forEach((item, index) => {
      const roiZScore = Math.abs((item.roi - roiMean) / roiStd);
      const spendZScore = Math.abs((item.actualSpend / item.plannedSpend - spendMean) / spendStd);
      
      if (roiZScore > 3) {
        anomalies.push({
          index,
          score: roiZScore,
          reason: `Unusual ROI: ${item.roi.toFixed(2)} (${roiZScore.toFixed(2)} std devs from mean)`,
        });
      }
      
      if (spendZScore > 3) {
        anomalies.push({
          index,
          score: spendZScore,
          reason: `Unusual spend variance: ${((item.actualSpend / item.plannedSpend - 1) * 100).toFixed(1)}%`,
        });
      }
      
      if (item.roi < 0.5 && item.actualSpend > item.plannedSpend * 1.2) {
        anomalies.push({
          index,
          score: 0.8,
          reason: 'High spend with low ROI - potential inefficiency',
        });
      }
    });

    return { anomalies };
  }

  async forecastPerformance(params: {
    historicalData: TradeSpendData[];
    futurePromotions: Array<{
      category: string;
      storeType: string;
      plannedSpend: number;
      discountType: string;
      discountValue: number;
      duration: number;
    }>;
  }): Promise<Array<{
    promotion: any;
    forecast: {
      expectedRevenue: number;
      expectedUnits: number;
      expectedROI: number;
      confidenceInterval: { lower: number; upper: number };
    };
  }>> {
    const forecasts = [];

    for (const promotion of params.futurePromotions) {
      // Simple time series based forecasting
      const similarPromotions = params.historicalData.filter(
        d => d.category === promotion.category && 
             d.storeType === promotion.storeType &&
             Math.abs(d.discountValue - promotion.discountValue) < 5
      );

      if (similarPromotions.length > 0) {
        const avgRevenue = this.mean(similarPromotions.map(d => d.revenue));
        const avgUnits = this.mean(similarPromotions.map(d => d.units));
        const avgROI = this.mean(similarPromotions.map(d => d.roi));
        const stdROI = this.std(similarPromotions.map(d => d.roi));

        forecasts.push({
          promotion,
          forecast: {
            expectedRevenue: avgRevenue * (1 + promotion.discountValue / 100),
            expectedUnits: avgUnits * (1 + promotion.discountValue / 50),
            expectedROI: avgROI,
            confidenceInterval: {
              lower: Math.max(0, avgROI - 1.96 * stdROI),
              upper: avgROI + 1.96 * stdROI,
            },
          },
        });
      } else {
        // Use general averages if no similar promotions found
        const generalAvg = this.calculateAverageMetrics(params.historicalData);
        
        forecasts.push({
          promotion,
          forecast: {
            expectedRevenue: promotion.plannedSpend * 2.5,
            expectedUnits: promotion.plannedSpend / 10,
            expectedROI: 1.5,
            confidenceInterval: {
              lower: 0.8,
              upper: 2.2,
            },
          },
        });
      }
    }

    return forecasts;
  }

  private calculateAverageMetrics(data: TradeSpendData[]): any {
    if (data.length === 0) {
      return {
        avgSpend: 100000,
        avgUnits: 5000,
        avgRevenue: 250000,
        avgROI: 1.5,
        efficiency: 0.7,
      };
    }

    return {
      avgSpend: this.mean(data.map(d => d.actualSpend)),
      avgUnits: this.mean(data.map(d => d.units)),
      avgRevenue: this.mean(data.map(d => d.revenue)),
      avgROI: this.mean(data.map(d => d.roi)),
      efficiency: this.mean(data.map(d => this.calculateEfficiency(d))),
    };
  }

  private calculateEfficiency(data: TradeSpendData): number {
    return data.roi * (data.actualSpend / data.plannedSpend);
  }

  private calculateConfidence(data: TradeSpendData): number {
    // Simple confidence calculation based on spend variance and ROI
    const spendVariance = Math.abs(1 - data.actualSpend / data.plannedSpend);
    const roiScore = Math.min(1, data.roi / 2);
    return (1 - spendVariance) * roiScore;
  }

  private encodeCategoryType(category: string): number {
    const categories: { [key: string]: number } = {
      'Beverages': 1,
      'Snacks': 2,
      'Dairy': 3,
      'Bakery': 4,
      'Frozen Foods': 5,
      'Personal Care': 6,
      'Household': 7,
      'Health & Beauty': 8,
    };
    return categories[category] || 0;
  }

  private encodeStoreType(storeType: string): number {
    const types: { [key: string]: number } = {
      'Hypermarket': 1,
      'Supermarket': 2,
      'Convenience': 3,
      'Wholesale': 4,
    };
    return types[storeType] || 0;
  }

  private encodeDiscountType(discountType: string): number {
    const types: { [key: string]: number } = {
      'PERCENTAGE': 1,
      'FIXED_AMOUNT': 2,
      'BOGO': 3,
      'VOLUME_DISCOUNT': 4,
    };
    return types[discountType] || 0;
  }

  private mean(values: number[]): number {
    return values.reduce((a, b) => a + b, 0) / values.length;
  }

  private std(values: number[]): number {
    const avg = this.mean(values);
    const squareDiffs = values.map(value => Math.pow(value - avg, 2));
    return Math.sqrt(this.mean(squareDiffs));
  }

  async saveModel(): Promise<void> {
    if (!this.model) {
      throw new Error('No model to save');
    }
    
    await this.model.save('file://./models/trade-spend-optimizer');
    
    // Save scaler
    if (this.scaler) {
      const fs = require('fs').promises;
      await fs.writeFile(
        './models/trade-spend-optimizer/scaler.json',
        JSON.stringify(this.scaler)
      );
    }
    
    this.logger.info('Model saved successfully');
  }

  async loadModel(): Promise<void> {
    this.model = await tf.loadLayersModel('file://./models/trade-spend-optimizer/model.json');
    
    // Load scaler
    const fs = require('fs').promises;
    const scalerData = await fs.readFile('./models/trade-spend-optimizer/scaler.json', 'utf-8');
    this.scaler = JSON.parse(scalerData);
    
    this.logger.info('Model loaded successfully');
  }
}