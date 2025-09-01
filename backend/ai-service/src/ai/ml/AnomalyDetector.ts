import * as tf from '@tensorflow/tfjs-node';
import { Logger } from 'winston';
import { createLogger } from '../../utils/logger';
import { IsolationForest } from 'isolation-forest';

export interface AnomalyData {
  timestamp: Date;
  storeId: string;
  productId: string;
  metric: string;
  value: number;
  expectedValue?: number;
  context?: Record<string, any>;
}

export interface AnomalyResult {
  isAnomaly: boolean;
  anomalyScore: number;
  severity: 'low' | 'medium' | 'high' | 'critical';
  type: string;
  description: string;
  recommendation: string;
  relatedData?: any[];
}

export class AnomalyDetector {
  private logger: Logger;
  private autoencoder: tf.LayersModel | null = null;
  private isolationForest: any = null;
  private thresholds: Map<string, { mean: number; std: number }> = new Map();

  constructor() {
    this.logger = createLogger('AnomalyDetector');
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
    // Create autoencoder for deep anomaly detection
    const encoder = tf.sequential({
      layers: [
        tf.layers.dense({
          inputShape: [10],
          units: 8,
          activation: 'relu',
        }),
        tf.layers.dense({
          units: 4,
          activation: 'relu',
        }),
        tf.layers.dense({
          units: 2,
          activation: 'relu',
        }),
      ],
    });

    const decoder = tf.sequential({
      layers: [
        tf.layers.dense({
          inputShape: [2],
          units: 4,
          activation: 'relu',
        }),
        tf.layers.dense({
          units: 8,
          activation: 'relu',
        }),
        tf.layers.dense({
          units: 10,
          activation: 'sigmoid',
        }),
      ],
    });

    const input = tf.input({ shape: [10] });
    const encoded = encoder.apply(input) as tf.SymbolicTensor;
    const decoded = decoder.apply(encoded) as tf.SymbolicTensor;

    this.autoencoder = tf.model({ inputs: input, outputs: decoded });
    this.autoencoder.compile({
      optimizer: 'adam',
      loss: 'meanSquaredError',
    });

    // Initialize Isolation Forest
    this.isolationForest = new IsolationForest({
      nTrees: 100,
      sampleSize: 256,
      contamination: 0.1,
    });

    this.logger.info('Anomaly detection models created');
  }

  async train(data: AnomalyData[]): Promise<void> {
    this.logger.info(`Training anomaly detector with ${data.length} samples`);

    // Calculate thresholds for different metrics
    this.calculateThresholds(data);

    // Prepare data for autoencoder
    const features = this.extractFeatures(data);
    const normalizedFeatures = this.normalizeFeatures(features);

    // Train autoencoder
    if (this.autoencoder) {
      const tensorData = tf.tensor2d(normalizedFeatures);
      
      await this.autoencoder.fit(tensorData, tensorData, {
        epochs: 50,
        batchSize: 32,
        validationSplit: 0.1,
        callbacks: {
          onEpochEnd: (epoch, logs) => {
            if (epoch % 10 === 0) {
              this.logger.info(`Epoch ${epoch}: loss = ${logs?.loss?.toFixed(4)}`);
            }
          },
        },
      });

      tensorData.dispose();
    }

    // Train Isolation Forest
    if (this.isolationForest) {
      this.isolationForest.fit(features);
    }

    await this.saveModels();
    this.logger.info('Anomaly detector training completed');
  }

  async detect(data: AnomalyData | AnomalyData[]): Promise<AnomalyResult | AnomalyResult[]> {
    const isArray = Array.isArray(data);
    const dataArray = isArray ? data : [data];
    const results: AnomalyResult[] = [];

    for (const item of dataArray) {
      const result = await this.detectSingle(item);
      results.push(result);
    }

    return isArray ? results : results[0];
  }

  private async detectSingle(data: AnomalyData): Promise<AnomalyResult> {
    // Statistical anomaly detection
    const statisticalAnomaly = this.detectStatisticalAnomaly(data);
    
    // Pattern-based anomaly detection
    const patternAnomaly = await this.detectPatternAnomaly(data);
    
    // Contextual anomaly detection
    const contextualAnomaly = this.detectContextualAnomaly(data);

    // Combine results
    const anomalyScores = [
      statisticalAnomaly.score,
      patternAnomaly.score,
      contextualAnomaly.score,
    ];
    
    const maxScore = Math.max(...anomalyScores);
    const avgScore = anomalyScores.reduce((a, b) => a + b, 0) / anomalyScores.length;
    
    const isAnomaly = maxScore > 0.7 || avgScore > 0.5;
    const severity = this.calculateSeverity(maxScore, data);
    
    // Determine anomaly type and description
    let type = 'unknown';
    let description = 'Anomaly detected';
    let recommendation = 'Review the data point';

    if (statisticalAnomaly.score === maxScore) {
      type = statisticalAnomaly.type;
      description = statisticalAnomaly.description;
      recommendation = statisticalAnomaly.recommendation;
    } else if (patternAnomaly.score === maxScore) {
      type = patternAnomaly.type;
      description = patternAnomaly.description;
      recommendation = patternAnomaly.recommendation;
    } else if (contextualAnomaly.score === maxScore) {
      type = contextualAnomaly.type;
      description = contextualAnomaly.description;
      recommendation = contextualAnomaly.recommendation;
    }

    return {
      isAnomaly,
      anomalyScore: avgScore,
      severity,
      type,
      description,
      recommendation,
      relatedData: this.findRelatedAnomalies(data),
    };
  }

  private detectStatisticalAnomaly(data: AnomalyData): {
    score: number;
    type: string;
    description: string;
    recommendation: string;
  } {
    const threshold = this.thresholds.get(data.metric);
    if (!threshold) {
      return {
        score: 0,
        type: 'statistical',
        description: 'No baseline available',
        recommendation: 'Collect more data to establish baseline',
      };
    }

    const zScore = Math.abs((data.value - threshold.mean) / threshold.std);
    const score = Math.min(1, zScore / 4); // Normalize to 0-1

    let description = '';
    let recommendation = '';

    if (zScore > 3) {
      description = `Value ${data.value} is ${zScore.toFixed(1)} standard deviations from mean`;
      recommendation = 'Investigate unusual spike or drop in metrics';
    } else if (zScore > 2) {
      description = `Value ${data.value} shows moderate deviation from normal`;
      recommendation = 'Monitor for continued deviation';
    }

    return {
      score,
      type: 'statistical_outlier',
      description,
      recommendation,
    };
  }

  private async detectPatternAnomaly(data: AnomalyData): Promise<{
    score: number;
    type: string;
    description: string;
    recommendation: string;
  }> {
    if (!this.autoencoder) {
      return {
        score: 0,
        type: 'pattern',
        description: 'Pattern detection not available',
        recommendation: 'Train model with historical data',
      };
    }

    const features = this.extractFeatures([data]);
    const normalized = this.normalizeFeatures(features);
    const input = tf.tensor2d(normalized);
    
    const reconstructed = this.autoencoder.predict(input) as tf.Tensor;
    const reconstructionError = tf.losses.meanSquaredError(input, reconstructed);
    const errorValue = await reconstructionError.data();
    
    input.dispose();
    reconstructed.dispose();
    reconstructionError.dispose();

    const score = Math.min(1, errorValue[0] * 10); // Normalize

    let description = '';
    let recommendation = '';

    if (score > 0.7) {
      description = 'Unusual pattern detected in data';
      recommendation = 'Review recent changes in business operations';
    } else if (score > 0.5) {
      description = 'Moderate pattern deviation detected';
      recommendation = 'Monitor for pattern persistence';
    }

    return {
      score,
      type: 'pattern_anomaly',
      description,
      recommendation,
    };
  }

  private detectContextualAnomaly(data: AnomalyData): {
    score: number;
    type: string;
    description: string;
    recommendation: string;
  } {
    let score = 0;
    let description = '';
    let recommendation = '';
    let type = 'contextual';

    // Check for business rule violations
    if (data.metric === 'revenue' && data.value < 0) {
      score = 1;
      type = 'business_rule_violation';
      description = 'Negative revenue detected';
      recommendation = 'Check for data entry errors or system issues';
    } else if (data.metric === 'units' && data.value % 1 !== 0) {
      score = 0.8;
      type = 'data_quality_issue';
      description = 'Fractional units detected';
      recommendation = 'Verify unit counting methodology';
    } else if (data.expectedValue && Math.abs(data.value - data.expectedValue) / data.expectedValue > 0.5) {
      score = 0.7;
      type = 'expectation_violation';
      description = `Value deviates ${((Math.abs(data.value - data.expectedValue) / data.expectedValue) * 100).toFixed(1)}% from expected`;
      recommendation = 'Review forecast assumptions and actual conditions';
    }

    // Time-based anomalies
    const hour = data.timestamp.getHours();
    if (data.metric === 'transactions' && data.value > 0 && (hour < 6 || hour > 22)) {
      score = Math.max(score, 0.6);
      type = 'temporal_anomaly';
      description = 'Unusual activity during off-hours';
      recommendation = 'Verify store operating hours and transaction timing';
    }

    return { score, type, description, recommendation };
  }

  private calculateSeverity(score: number, data: AnomalyData): 'low' | 'medium' | 'high' | 'critical' {
    // Consider both anomaly score and business impact
    const impactMultiplier = this.getImpactMultiplier(data);
    const adjustedScore = score * impactMultiplier;

    if (adjustedScore > 0.9) return 'critical';
    if (adjustedScore > 0.7) return 'high';
    if (adjustedScore > 0.5) return 'medium';
    return 'low';
  }

  private getImpactMultiplier(data: AnomalyData): number {
    // Higher multiplier for metrics with greater business impact
    const impactMap: Record<string, number> = {
      revenue: 1.5,
      profit: 1.5,
      units: 1.2,
      transactions: 1.0,
      cost: 1.3,
      waste: 1.4,
    };

    return impactMap[data.metric] || 1.0;
  }

  private findRelatedAnomalies(data: AnomalyData): any[] {
    // In a real implementation, this would query for related anomalies
    // For now, return empty array
    return [];
  }

  private calculateThresholds(data: AnomalyData[]): void {
    const metricGroups = new Map<string, number[]>();

    // Group data by metric
    for (const item of data) {
      if (!metricGroups.has(item.metric)) {
        metricGroups.set(item.metric, []);
      }
      metricGroups.get(item.metric)!.push(item.value);
    }

    // Calculate thresholds for each metric
    for (const [metric, values] of metricGroups) {
      const mean = values.reduce((a, b) => a + b, 0) / values.length;
      const variance = values.reduce((a, b) => a + Math.pow(b - mean, 2), 0) / values.length;
      const std = Math.sqrt(variance);

      this.thresholds.set(metric, { mean, std });
    }
  }

  private extractFeatures(data: AnomalyData[]): number[][] {
    return data.map(item => {
      const hour = item.timestamp.getHours();
      const dayOfWeek = item.timestamp.getDay();
      const dayOfMonth = item.timestamp.getDate();
      const month = item.timestamp.getMonth();
      
      return [
        item.value,
        hour,
        dayOfWeek,
        dayOfMonth,
        month,
        item.expectedValue || item.value,
        this.encodeMetric(item.metric),
        Math.log1p(item.value), // Log transform
        item.value > 0 ? 1 : 0, // Binary indicator
        hour >= 9 && hour <= 17 ? 1 : 0, // Business hours indicator
      ];
    });
  }

  private normalizeFeatures(features: number[][]): number[][] {
    const numFeatures = features[0].length;
    const mins = new Array(numFeatures).fill(Infinity);
    const maxs = new Array(numFeatures).fill(-Infinity);

    // Find min and max for each feature
    for (const row of features) {
      for (let i = 0; i < numFeatures; i++) {
        mins[i] = Math.min(mins[i], row[i]);
        maxs[i] = Math.max(maxs[i], row[i]);
      }
    }

    // Normalize to 0-1 range
    return features.map(row =>
      row.map((val, i) => {
        const range = maxs[i] - mins[i];
        return range > 0 ? (val - mins[i]) / range : 0;
      })
    );
  }

  private encodeMetric(metric: string): number {
    const metricMap: Record<string, number> = {
      revenue: 1,
      units: 2,
      transactions: 3,
      cost: 4,
      profit: 5,
      waste: 6,
    };
    return metricMap[metric] || 0;
  }

  async detectRealTimeAnomaly(stream: AsyncIterable<AnomalyData>): AsyncGenerator<AnomalyResult> {
    const buffer: AnomalyData[] = [];
    const bufferSize = 100;

    for await (const data of stream) {
      buffer.push(data);
      
      if (buffer.length > bufferSize) {
        buffer.shift();
      }

      // Detect anomaly with context from buffer
      const result = await this.detect(data);
      
      if (result.isAnomaly) {
        yield result;
      }
    }
  }

  async saveModels(): Promise<void> {
    if (this.autoencoder) {
      await this.autoencoder.save('file://./models/anomaly-detector');
    }
    
    // Save thresholds
    const fs = require('fs').promises;
    await fs.writeFile(
      './models/anomaly-detector/thresholds.json',
      JSON.stringify(Array.from(this.thresholds.entries()))
    );
    
    this.logger.info('Anomaly detection models saved');
  }

  async loadModels(): Promise<void> {
    this.autoencoder = await tf.loadLayersModel('file://./models/anomaly-detector/model.json');
    
    // Load thresholds
    const fs = require('fs').promises;
    const thresholdData = await fs.readFile('./models/anomaly-detector/thresholds.json', 'utf-8');
    this.thresholds = new Map(JSON.parse(thresholdData));
    
    this.logger.info('Anomaly detection models loaded');
  }
}