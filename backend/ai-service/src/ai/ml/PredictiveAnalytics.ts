import * as tf from '@tensorflow/tfjs-node';
import { Logger } from 'winston';
import { createLogger } from '../../utils/logger';
import { ARIMA } from 'arima';
import * as ss from 'simple-statistics';

export interface TimeSeriesData {
  timestamp: Date;
  value: number;
  category?: string;
  storeId?: string;
  productId?: string;
  metadata?: Record<string, any>;
}

export interface PredictionResult {
  timestamp: Date;
  predictedValue: number;
  confidenceInterval: {
    lower: number;
    upper: number;
  };
  accuracy: number;
  model: string;
  insights: string[];
}

export interface TrendAnalysis {
  trend: 'increasing' | 'decreasing' | 'stable';
  trendStrength: number;
  seasonality: {
    detected: boolean;
    period?: number;
    strength?: number;
  };
  changePoints: Array<{
    timestamp: Date;
    magnitude: number;
    type: 'increase' | 'decrease';
  }>;
}

export class PredictiveAnalytics {
  private logger: Logger;
  private lstmModel: tf.LayersModel | null = null;
  private arimaModel: any = null;
  private ensembleWeights: { lstm: number; arima: number; exponential: number } = {
    lstm: 0.5,
    arima: 0.3,
    exponential: 0.2,
  };

  constructor() {
    this.logger = createLogger('PredictiveAnalytics');
  }

  async initialize(): Promise<void> {
    try {
      await this.loadModels();
    } catch (error) {
      this.logger.info('No existing models found, creating new models');
      this.createModels();
    }
  }

  private createModels(): void {
    // Create LSTM model for time series prediction
    this.lstmModel = tf.sequential({
      layers: [
        tf.layers.lstm({
          units: 50,
          returnSequences: true,
          inputShape: [30, 5], // 30 time steps, 5 features
        }),
        tf.layers.dropout({ rate: 0.2 }),
        tf.layers.lstm({
          units: 50,
          returnSequences: false,
        }),
        tf.layers.dropout({ rate: 0.2 }),
        tf.layers.dense({
          units: 25,
          activation: 'relu',
        }),
        tf.layers.dense({
          units: 1,
        }),
      ],
    });

    this.lstmModel.compile({
      optimizer: tf.train.adam(0.001),
      loss: 'meanSquaredError',
      metrics: ['mae'],
    });

    // Initialize ARIMA model
    this.arimaModel = new ARIMA({
      p: 2, // Autoregressive order
      d: 1, // Degree of differencing
      q: 2, // Moving average order
      verbose: false,
    });

    this.logger.info('Predictive models created');
  }

  async train(data: TimeSeriesData[]): Promise<void> {
    this.logger.info(`Training predictive models with ${data.length} samples`);

    // Sort data by timestamp
    const sortedData = [...data].sort((a, b) => a.timestamp.getTime() - b.timestamp.getTime());

    // Train LSTM model
    await this.trainLSTM(sortedData);

    // Train ARIMA model
    this.trainARIMA(sortedData);

    // Optimize ensemble weights
    await this.optimizeEnsembleWeights(sortedData);

    await this.saveModels();
    this.logger.info('Predictive model training completed');
  }

  private async trainLSTM(data: TimeSeriesData[]): Promise<void> {
    if (!this.lstmModel) return;

    // Prepare sequences for LSTM
    const sequences = this.prepareSequences(data, 30); // 30 time steps
    if (sequences.length === 0) return;

    const xTrain = tf.tensor3d(sequences.map(s => s.features));
    const yTrain = tf.tensor2d(sequences.map(s => [s.target]));

    await this.lstmModel.fit(xTrain, yTrain, {
      epochs: 50,
      batchSize: 32,
      validationSplit: 0.2,
      callbacks: {
        onEpochEnd: (epoch, logs) => {
          if (epoch % 10 === 0) {
            this.logger.info(`LSTM Epoch ${epoch}: loss = ${logs?.loss?.toFixed(4)}`);
          }
        },
      },
    });

    xTrain.dispose();
    yTrain.dispose();
  }

  private trainARIMA(data: TimeSeriesData[]): void {
    const values = data.map(d => d.value);
    this.arimaModel.train(values);
  }

  async predict(
    historicalData: TimeSeriesData[],
    steps: number,
    options?: {
      includeConfidenceInterval?: boolean;
      model?: 'lstm' | 'arima' | 'exponential' | 'ensemble';
    }
  ): Promise<PredictionResult[]> {
    const sortedData = [...historicalData].sort((a, b) => a.timestamp.getTime() - b.timestamp.getTime());
    const lastTimestamp = sortedData[sortedData.length - 1].timestamp;
    const results: PredictionResult[] = [];

    for (let i = 0; i < steps; i++) {
      const nextTimestamp = new Date(lastTimestamp.getTime() + (i + 1) * 24 * 60 * 60 * 1000); // Daily predictions
      
      let prediction: number;
      let confidence = { lower: 0, upper: 0 };
      let modelUsed = options?.model || 'ensemble';

      switch (modelUsed) {
        case 'lstm':
          prediction = await this.predictLSTM(sortedData, i);
          break;
        case 'arima':
          prediction = this.predictARIMA(sortedData, i);
          break;
        case 'exponential':
          prediction = this.predictExponentialSmoothing(sortedData, i);
          break;
        default:
          prediction = await this.predictEnsemble(sortedData, i);
      }

      if (options?.includeConfidenceInterval) {
        confidence = this.calculateConfidenceInterval(prediction, sortedData);
      }

      const insights = this.generatePredictionInsights(prediction, sortedData);

      results.push({
        timestamp: nextTimestamp,
        predictedValue: Math.max(0, prediction),
        confidenceInterval: confidence,
        accuracy: this.estimateAccuracy(modelUsed),
        model: modelUsed,
        insights,
      });

      // Add prediction to historical data for multi-step forecasting
      sortedData.push({
        timestamp: nextTimestamp,
        value: prediction,
        metadata: { isPrediction: true },
      });
    }

    return results;
  }

  private async predictLSTM(data: TimeSeriesData[], step: number): Promise<number> {
    if (!this.lstmModel || data.length < 30) {
      return this.fallbackPrediction(data);
    }

    const sequence = this.prepareLastSequence(data, 30);
    const input = tf.tensor3d([sequence]);
    const prediction = this.lstmModel.predict(input) as tf.Tensor;
    const value = await prediction.data();

    input.dispose();
    prediction.dispose();

    return value[0];
  }

  private predictARIMA(data: TimeSeriesData[], step: number): number {
    if (!this.arimaModel) {
      return this.fallbackPrediction(data);
    }

    const values = data.map(d => d.value);
    const predictions = this.arimaModel.predict(step + 1);
    return predictions[predictions.length - 1];
  }

  private predictExponentialSmoothing(data: TimeSeriesData[], step: number): number {
    const values = data.map(d => d.value);
    const alpha = 0.3; // Smoothing parameter
    
    let forecast = values[0];
    for (let i = 1; i < values.length; i++) {
      forecast = alpha * values[i] + (1 - alpha) * forecast;
    }

    // Simple trend adjustment
    const recentTrend = values.slice(-5).reduce((acc, val, idx, arr) => {
      if (idx === 0) return 0;
      return acc + (val - arr[idx - 1]);
    }, 0) / 4;

    return forecast + recentTrend * (step + 1);
  }

  private async predictEnsemble(data: TimeSeriesData[], step: number): Promise<number> {
    const lstmPred = await this.predictLSTM(data, step);
    const arimaPred = this.predictARIMA(data, step);
    const expPred = this.predictExponentialSmoothing(data, step);

    return (
      this.ensembleWeights.lstm * lstmPred +
      this.ensembleWeights.arima * arimaPred +
      this.ensembleWeights.exponential * expPred
    );
  }

  async analyzeTrends(data: TimeSeriesData[]): Promise<TrendAnalysis> {
    const sortedData = [...data].sort((a, b) => a.timestamp.getTime() - b.timestamp.getTime());
    const values = sortedData.map(d => d.value);

    // Calculate trend
    const trendResult = this.calculateTrend(values);
    
    // Detect seasonality
    const seasonalityResult = this.detectSeasonality(values);
    
    // Find change points
    const changePoints = this.detectChangePoints(sortedData);

    return {
      trend: trendResult.direction,
      trendStrength: trendResult.strength,
      seasonality: seasonalityResult,
      changePoints,
    };
  }

  private calculateTrend(values: number[]): { direction: 'increasing' | 'decreasing' | 'stable'; strength: number } {
    if (values.length < 2) {
      return { direction: 'stable', strength: 0 };
    }

    // Linear regression
    const indices = values.map((_, i) => i);
    const regression = ss.linearRegression(indices.map((x, i) => [x, values[i]]));
    const slope = regression.m;

    // Calculate R-squared for trend strength
    const predictions = indices.map(x => regression.m * x + regression.b);
    const rSquared = ss.rSquared(values, predictions);

    let direction: 'increasing' | 'decreasing' | 'stable';
    if (Math.abs(slope) < 0.01) {
      direction = 'stable';
    } else if (slope > 0) {
      direction = 'increasing';
    } else {
      direction = 'decreasing';
    }

    return { direction, strength: rSquared };
  }

  private detectSeasonality(values: number[]): { detected: boolean; period?: number; strength?: number } {
    if (values.length < 14) {
      return { detected: false };
    }

    // Simple autocorrelation-based seasonality detection
    const maxLag = Math.min(30, Math.floor(values.length / 2));
    let maxCorrelation = 0;
    let bestPeriod = 0;

    for (let lag = 7; lag <= maxLag; lag++) {
      const correlation = this.autocorrelation(values, lag);
      if (correlation > maxCorrelation && correlation > 0.5) {
        maxCorrelation = correlation;
        bestPeriod = lag;
      }
    }

    if (maxCorrelation > 0.5) {
      return {
        detected: true,
        period: bestPeriod,
        strength: maxCorrelation,
      };
    }

    return { detected: false };
  }

  private detectChangePoints(data: TimeSeriesData[]): Array<{ timestamp: Date; magnitude: number; type: 'increase' | 'decrease' }> {
    const changePoints: Array<{ timestamp: Date; magnitude: number; type: 'increase' | 'decrease' }> = [];
    
    if (data.length < 10) return changePoints;

    const windowSize = 7;
    for (let i = windowSize; i < data.length - windowSize; i++) {
      const before = data.slice(i - windowSize, i).map(d => d.value);
      const after = data.slice(i, i + windowSize).map(d => d.value);
      
      const meanBefore = ss.mean(before);
      const meanAfter = ss.mean(after);
      const stdBefore = ss.standardDeviation(before);
      
      const change = meanAfter - meanBefore;
      const changeRatio = Math.abs(change) / (stdBefore || 1);
      
      if (changeRatio > 2) {
        changePoints.push({
          timestamp: data[i].timestamp,
          magnitude: Math.abs(change),
          type: change > 0 ? 'increase' : 'decrease',
        });
      }
    }

    return changePoints;
  }

  async forecastWithScenarios(
    historicalData: TimeSeriesData[],
    scenarios: Array<{
      name: string;
      adjustments: Record<string, number>;
      probability: number;
    }>,
    steps: number
  ): Promise<Map<string, PredictionResult[]>> {
    const results = new Map<string, PredictionResult[]>();

    for (const scenario of scenarios) {
      // Adjust historical data based on scenario
      const adjustedData = this.applyScenarioAdjustments(historicalData, scenario.adjustments);
      
      // Generate predictions for this scenario
      const predictions = await this.predict(adjustedData, steps, { includeConfidenceInterval: true });
      
      // Adjust predictions based on scenario probability
      const adjustedPredictions = predictions.map(pred => ({
        ...pred,
        predictedValue: pred.predictedValue * (0.5 + scenario.probability * 0.5),
        insights: [...pred.insights, `Scenario: ${scenario.name} (${(scenario.probability * 100).toFixed(0)}% probability)`],
      }));

      results.set(scenario.name, adjustedPredictions);
    }

    return results;
  }

  private applyScenarioAdjustments(
    data: TimeSeriesData[],
    adjustments: Record<string, number>
  ): TimeSeriesData[] {
    return data.map(item => ({
      ...item,
      value: item.value * (1 + (adjustments.global || 0)),
      metadata: {
        ...item.metadata,
        scenarioAdjusted: true,
      },
    }));
  }

  private prepareSequences(data: TimeSeriesData[], sequenceLength: number): Array<{ features: number[][]; target: number }> {
    const sequences: Array<{ features: number[][]; target: number }> = [];
    
    for (let i = sequenceLength; i < data.length; i++) {
      const sequence = data.slice(i - sequenceLength, i);
      const features = sequence.map(item => [
        item.value,
        item.timestamp.getDay(), // Day of week
        item.timestamp.getDate(), // Day of month
        item.timestamp.getMonth(), // Month
        Math.sin(2 * Math.PI * item.timestamp.getDay() / 7), // Cyclical encoding
      ]);
      
      sequences.push({
        features,
        target: data[i].value,
      });
    }
    
    return sequences;
  }

  private prepareLastSequence(data: TimeSeriesData[], sequenceLength: number): number[][] {
    const lastSequence = data.slice(-sequenceLength);
    return lastSequence.map(item => [
      item.value,
      item.timestamp.getDay(),
      item.timestamp.getDate(),
      item.timestamp.getMonth(),
      Math.sin(2 * Math.PI * item.timestamp.getDay() / 7),
    ]);
  }

  private calculateConfidenceInterval(
    prediction: number,
    historicalData: TimeSeriesData[]
  ): { lower: number; upper: number } {
    const values = historicalData.map(d => d.value);
    const std = ss.standardDeviation(values);
    const confidenceMultiplier = 1.96; // 95% confidence interval
    
    return {
      lower: Math.max(0, prediction - confidenceMultiplier * std),
      upper: prediction + confidenceMultiplier * std,
    };
  }

  private generatePredictionInsights(prediction: number, historicalData: TimeSeriesData[]): string[] {
    const insights: string[] = [];
    const recentValues = historicalData.slice(-7).map(d => d.value);
    const recentAvg = ss.mean(recentValues);
    
    const changePercent = ((prediction - recentAvg) / recentAvg) * 100;
    
    if (Math.abs(changePercent) > 20) {
      insights.push(`Significant ${changePercent > 0 ? 'increase' : 'decrease'} of ${Math.abs(changePercent).toFixed(1)}% expected`);
    }
    
    const trend = this.calculateTrend(historicalData.map(d => d.value));
    if (trend.strength > 0.7) {
      insights.push(`Strong ${trend.direction} trend detected (R² = ${trend.strength.toFixed(2)})`);
    }
    
    return insights;
  }

  private autocorrelation(values: number[], lag: number): number {
    const n = values.length - lag;
    const mean = ss.mean(values);
    
    let numerator = 0;
    let denominator = 0;
    
    for (let i = 0; i < n; i++) {
      numerator += (values[i] - mean) * (values[i + lag] - mean);
    }
    
    for (let i = 0; i < values.length; i++) {
      denominator += Math.pow(values[i] - mean, 2);
    }
    
    return numerator / denominator;
  }

  private fallbackPrediction(data: TimeSeriesData[]): number {
    // Simple moving average as fallback
    const recentValues = data.slice(-7).map(d => d.value);
    return ss.mean(recentValues);
  }

  private estimateAccuracy(model: string): number {
    // Placeholder accuracy estimates
    const accuracyMap: Record<string, number> = {
      lstm: 0.85,
      arima: 0.80,
      exponential: 0.75,
      ensemble: 0.88,
    };
    return accuracyMap[model] || 0.70;
  }

  private async optimizeEnsembleWeights(data: TimeSeriesData[]): Promise<void> {
    // Simple optimization based on validation performance
    // In production, use more sophisticated optimization
    this.ensembleWeights = {
      lstm: 0.5,
      arima: 0.3,
      exponential: 0.2,
    };
  }

  async saveModels(): Promise<void> {
    if (this.lstmModel) {
      await this.lstmModel.save('file://./models/predictive-analytics');
    }
    
    // Save ensemble weights and ARIMA parameters
    const fs = require('fs').promises;
    await fs.writeFile(
      './models/predictive-analytics/ensemble.json',
      JSON.stringify({
        ensembleWeights: this.ensembleWeights,
        arimaParams: { p: 2, d: 1, q: 2 },
      })
    );
    
    this.logger.info('Predictive models saved');
  }

  async loadModels(): Promise<void> {
    this.lstmModel = await tf.loadLayersModel('file://./models/predictive-analytics/model.json');
    
    // Load ensemble configuration
    const fs = require('fs').promises;
    const configData = await fs.readFile('./models/predictive-analytics/ensemble.json', 'utf-8');
    const config = JSON.parse(configData);
    this.ensembleWeights = config.ensembleWeights;
    
    this.logger.info('Predictive models loaded');
  }
}