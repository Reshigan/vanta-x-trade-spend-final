import * as tf from '@tensorflow/tfjs-node';
import { logger } from '../../utils/logger';

interface SimulationInput {
  type: 'PROMOTION_IMPACT' | 'PRICE_OPTIMIZATION' | 'BUDGET_ALLOCATION' | 'MARKET_SCENARIO' | 'COMPETITIVE_RESPONSE';
  parameters: {
    baseValue: number;
    variables: Array<{
      name: string;
      distribution: 'normal' | 'uniform' | 'exponential' | 'lognormal';
      params: {
        mean?: number;
        std?: number;
        min?: number;
        max?: number;
        lambda?: number;
      };
      impact: number; // Impact factor on base value
    }>;
    constraints?: Array<{
      type: 'min' | 'max' | 'equal';
      value: number;
      variable?: string;
    }>;
    iterations?: number;
    confidenceLevel?: number;
  };
  historicalData?: any[];
  competitorData?: any[];
}

interface SimulationOutput {
  results: {
    mean: number;
    median: number;
    std: number;
    min: number;
    max: number;
    percentiles: {
      p5: number;
      p25: number;
      p50: number;
      p75: number;
      p95: number;
    };
    confidenceInterval: [number, number];
    probabilityDistribution: Array<{
      value: number;
      probability: number;
    }>;
  };
  scenarios: {
    best: {
      value: number;
      conditions: Record<string, number>;
      probability: number;
    };
    worst: {
      value: number;
      conditions: Record<string, number>;
      probability: number;
    };
    mostLikely: {
      value: number;
      conditions: Record<string, number>;
      probability: number;
    };
  };
  sensitivities: Array<{
    variable: string;
    sensitivity: number;
    correlation: number;
  }>;
  recommendations: string[];
}

export class MonteCarloEngine {
  private random: any;

  constructor() {
    this.random = tf.randomNormal;
  }

  async runSimulation(input: SimulationInput): Promise<SimulationOutput> {
    try {
      const { type, parameters, historicalData, competitorData } = input;
      const iterations = parameters.iterations || 10000;

      logger.info(`Running Monte Carlo simulation: ${type}`, { iterations });

      // Run simulations based on type
      let simulationResults: number[];
      let variableResults: Record<string, number[]> = {};

      switch (type) {
        case 'PROMOTION_IMPACT':
          ({ simulationResults, variableResults } = await this.simulatePromotionImpact(parameters, iterations));
          break;
        case 'PRICE_OPTIMIZATION':
          ({ simulationResults, variableResults } = await this.simulatePriceOptimization(parameters, iterations));
          break;
        case 'BUDGET_ALLOCATION':
          ({ simulationResults, variableResults } = await this.simulateBudgetAllocation(parameters, iterations));
          break;
        case 'MARKET_SCENARIO':
          ({ simulationResults, variableResults } = await this.simulateMarketScenario(parameters, iterations, historicalData));
          break;
        case 'COMPETITIVE_RESPONSE':
          ({ simulationResults, variableResults } = await this.simulateCompetitiveResponse(parameters, iterations, competitorData));
          break;
        default:
          throw new Error(`Unknown simulation type: ${type}`);
      }

      // Calculate statistics
      const results = this.calculateStatistics(simulationResults, parameters.confidenceLevel || 95);

      // Identify scenarios
      const scenarios = this.identifyScenarios(simulationResults, variableResults);

      // Calculate sensitivities
      const sensitivities = this.calculateSensitivities(simulationResults, variableResults);

      // Generate recommendations
      const recommendations = this.generateRecommendations(type, results, scenarios, sensitivities);

      return {
        results,
        scenarios,
        sensitivities,
        recommendations
      };
    } catch (error) {
      logger.error('Monte Carlo simulation error:', error);
      throw error;
    }
  }

  private async simulatePromotionImpact(parameters: any, iterations: number) {
    const simulationResults: number[] = [];
    const variableResults: Record<string, number[]> = {};

    // Initialize variable result arrays
    parameters.variables.forEach((v: any) => {
      variableResults[v.name] = [];
    });

    for (let i = 0; i < iterations; i++) {
      let value = parameters.baseValue;
      const iterationVariables: Record<string, number> = {};

      // Generate random values for each variable
      for (const variable of parameters.variables) {
        const randomValue = this.generateRandomValue(variable.distribution, variable.params);
        iterationVariables[variable.name] = randomValue;
        variableResults[variable.name].push(randomValue);

        // Apply impact
        value *= (1 + (randomValue * variable.impact));
      }

      // Apply constraints
      if (parameters.constraints) {
        value = this.applyConstraints(value, parameters.constraints);
      }

      // Additional promotion-specific calculations
      // Consider cannibalization
      const cannibalizationFactor = 0.1 + Math.random() * 0.2;
      value *= (1 - cannibalizationFactor);

      // Consider competitive response
      const competitiveResponse = Math.random() * 0.15;
      value *= (1 - competitiveResponse);

      simulationResults.push(value);
    }

    return { simulationResults, variableResults };
  }

  private async simulatePriceOptimization(parameters: any, iterations: number) {
    const simulationResults: number[] = [];
    const variableResults: Record<string, number[]> = {};

    // Price elasticity model
    const baseElasticity = -1.5; // Default price elasticity

    parameters.variables.forEach((v: any) => {
      variableResults[v.name] = [];
    });

    for (let i = 0; i < iterations; i++) {
      let revenue = parameters.baseValue;
      
      // Generate price change
      const priceChange = this.generateRandomValue('normal', { mean: 0, std: 0.1 });
      variableResults['priceChange'] = variableResults['priceChange'] || [];
      variableResults['priceChange'].push(priceChange);

      // Calculate volume impact using elasticity
      const elasticity = baseElasticity + this.generateRandomValue('normal', { mean: 0, std: 0.2 });
      const volumeImpact = 1 + (priceChange * elasticity);

      // Calculate revenue impact
      revenue *= (1 + priceChange) * volumeImpact;

      // Apply other variables
      for (const variable of parameters.variables) {
        if (variable.name !== 'priceChange') {
          const randomValue = this.generateRandomValue(variable.distribution, variable.params);
          variableResults[variable.name].push(randomValue);
          revenue *= (1 + (randomValue * variable.impact));
        }
      }

      simulationResults.push(revenue);
    }

    return { simulationResults, variableResults };
  }

  private async simulateBudgetAllocation(parameters: any, iterations: number) {
    const simulationResults: number[] = [];
    const variableResults: Record<string, number[]> = {};

    parameters.variables.forEach((v: any) => {
      variableResults[v.name] = [];
    });

    for (let i = 0; i < iterations; i++) {
      let totalROI = 0;
      const totalBudget = parameters.baseValue;
      
      // Allocate budget across channels/categories
      const allocations: number[] = [];
      let remainingBudget = totalBudget;

      for (let j = 0; j < parameters.variables.length - 1; j++) {
        const allocation = Math.random() * remainingBudget * 0.5;
        allocations.push(allocation);
        remainingBudget -= allocation;
      }
      allocations.push(remainingBudget);

      // Calculate ROI for each allocation
      parameters.variables.forEach((variable: any, index: number) => {
        const allocation = allocations[index];
        const efficiency = this.generateRandomValue(variable.distribution, variable.params);
        const roi = allocation * efficiency * variable.impact;
        
        variableResults[variable.name].push(efficiency);
        totalROI += roi;
      });

      simulationResults.push(totalROI);
    }

    return { simulationResults, variableResults };
  }

  private async simulateMarketScenario(parameters: any, iterations: number, historicalData?: any[]) {
    const simulationResults: number[] = [];
    const variableResults: Record<string, number[]> = {};

    // Extract historical patterns if available
    const seasonality = historicalData ? this.extractSeasonality(historicalData) : 1;
    const trend = historicalData ? this.extractTrend(historicalData) : 0;

    parameters.variables.forEach((v: any) => {
      variableResults[v.name] = [];
    });

    for (let i = 0; i < iterations; i++) {
      let marketValue = parameters.baseValue;

      // Apply historical patterns
      marketValue *= seasonality;
      marketValue *= (1 + trend);

      // Apply market variables
      for (const variable of parameters.variables) {
        const randomValue = this.generateRandomValue(variable.distribution, variable.params);
        variableResults[variable.name].push(randomValue);

        switch (variable.name) {
          case 'economicGrowth':
            marketValue *= (1 + randomValue * 0.3);
            break;
          case 'competitorActivity':
            marketValue *= (1 - randomValue * 0.2);
            break;
          case 'consumerSentiment':
            marketValue *= (1 + randomValue * 0.15);
            break;
          default:
            marketValue *= (1 + (randomValue * variable.impact));
        }
      }

      // Add market volatility
      const volatility = this.generateRandomValue('normal', { mean: 0, std: 0.05 });
      marketValue *= (1 + volatility);

      simulationResults.push(marketValue);
    }

    return { simulationResults, variableResults };
  }

  private async simulateCompetitiveResponse(parameters: any, iterations: number, competitorData?: any[]) {
    const simulationResults: number[] = [];
    const variableResults: Record<string, number[]> = {};

    // Game theory parameters
    const reactionProbability = 0.7;
    const reactionStrength = competitorData ? this.analyzeCompetitorAggressiveness(competitorData) : 0.5;

    parameters.variables.forEach((v: any) => {
      variableResults[v.name] = [];
    });

    for (let i = 0; i < iterations; i++) {
      let outcome = parameters.baseValue;

      // Simulate our action
      const ourAction = this.generateRandomValue('uniform', { min: 0, max: 1 });
      variableResults['ourAction'] = variableResults['ourAction'] || [];
      variableResults['ourAction'].push(ourAction);

      // Simulate competitor response
      if (Math.random() < reactionProbability) {
        const competitorResponse = ourAction * reactionStrength * this.generateRandomValue('normal', { mean: 1, std: 0.2 });
        variableResults['competitorResponse'] = variableResults['competitorResponse'] || [];
        variableResults['competitorResponse'].push(competitorResponse);

        // Calculate market share impact
        const marketShareChange = (ourAction - competitorResponse) * 0.1;
        outcome *= (1 + marketShareChange);
      }

      // Apply other variables
      for (const variable of parameters.variables) {
        if (!['ourAction', 'competitorResponse'].includes(variable.name)) {
          const randomValue = this.generateRandomValue(variable.distribution, variable.params);
          variableResults[variable.name].push(randomValue);
          outcome *= (1 + (randomValue * variable.impact));
        }
      }

      simulationResults.push(outcome);
    }

    return { simulationResults, variableResults };
  }

  private generateRandomValue(distribution: string, params: any): number {
    switch (distribution) {
      case 'normal':
        return tf.randomNormal([1], params.mean || 0, params.std || 1).dataSync()[0];
      
      case 'uniform':
        return tf.randomUniform([1], params.min || 0, params.max || 1).dataSync()[0];
      
      case 'exponential':
        const u = Math.random();
        return -Math.log(1 - u) / (params.lambda || 1);
      
      case 'lognormal':
        const normal = tf.randomNormal([1], params.mean || 0, params.std || 1).dataSync()[0];
        return Math.exp(normal);
      
      default:
        return tf.randomNormal([1], 0, 1).dataSync()[0];
    }
  }

  private applyConstraints(value: number, constraints: any[]): number {
    for (const constraint of constraints) {
      switch (constraint.type) {
        case 'min':
          value = Math.max(value, constraint.value);
          break;
        case 'max':
          value = Math.min(value, constraint.value);
          break;
        case 'equal':
          // This would typically be handled differently
          break;
      }
    }
    return value;
  }

  private calculateStatistics(results: number[], confidenceLevel: number) {
    const sorted = results.sort((a, b) => a - b);
    const n = results.length;

    const mean = results.reduce((a, b) => a + b) / n;
    const median = sorted[Math.floor(n / 2)];
    
    const variance = results.reduce((sum, x) => sum + Math.pow(x - mean, 2), 0) / n;
    const std = Math.sqrt(variance);

    const percentiles = {
      p5: sorted[Math.floor(n * 0.05)],
      p25: sorted[Math.floor(n * 0.25)],
      p50: median,
      p75: sorted[Math.floor(n * 0.75)],
      p95: sorted[Math.floor(n * 0.95)]
    };

    // Calculate confidence interval
    const alpha = 1 - confidenceLevel / 100;
    const lowerIndex = Math.floor(n * alpha / 2);
    const upperIndex = Math.floor(n * (1 - alpha / 2));
    const confidenceInterval: [number, number] = [sorted[lowerIndex], sorted[upperIndex]];

    // Create probability distribution
    const bins = 50;
    const min = sorted[0];
    const max = sorted[n - 1];
    const binWidth = (max - min) / bins;
    
    const probabilityDistribution = [];
    for (let i = 0; i < bins; i++) {
      const binMin = min + i * binWidth;
      const binMax = binMin + binWidth;
      const count = results.filter(r => r >= binMin && r < binMax).length;
      probabilityDistribution.push({
        value: (binMin + binMax) / 2,
        probability: count / n
      });
    }

    return {
      mean,
      median,
      std,
      min: sorted[0],
      max: sorted[n - 1],
      percentiles,
      confidenceInterval,
      probabilityDistribution
    };
  }

  private identifyScenarios(results: number[], variableResults: Record<string, number[]>) {
    const n = results.length;
    const sortedIndices = results
      .map((value, index) => ({ value, index }))
      .sort((a, b) => a.value - b.value)
      .map(item => item.index);

    // Best case scenario (95th percentile)
    const bestIndex = sortedIndices[Math.floor(n * 0.95)];
    const bestConditions: Record<string, number> = {};
    Object.keys(variableResults).forEach(key => {
      bestConditions[key] = variableResults[key][bestIndex];
    });

    // Worst case scenario (5th percentile)
    const worstIndex = sortedIndices[Math.floor(n * 0.05)];
    const worstConditions: Record<string, number> = {};
    Object.keys(variableResults).forEach(key => {
      worstConditions[key] = variableResults[key][worstIndex];
    });

    // Most likely scenario (around median)
    const medianIndex = sortedIndices[Math.floor(n * 0.5)];
    const mostLikelyConditions: Record<string, number> = {};
    Object.keys(variableResults).forEach(key => {
      mostLikelyConditions[key] = variableResults[key][medianIndex];
    });

    return {
      best: {
        value: results[bestIndex],
        conditions: bestConditions,
        probability: 0.05
      },
      worst: {
        value: results[worstIndex],
        conditions: worstConditions,
        probability: 0.05
      },
      mostLikely: {
        value: results[medianIndex],
        conditions: mostLikelyConditions,
        probability: 0.5
      }
    };
  }

  private calculateSensitivities(results: number[], variableResults: Record<string, number[]>) {
    const sensitivities = [];

    for (const [variable, values] of Object.entries(variableResults)) {
      // Calculate correlation
      const correlation = this.calculateCorrelation(results, values);
      
      // Calculate sensitivity (elasticity)
      const sensitivity = this.calculateElasticity(results, values);

      sensitivities.push({
        variable,
        sensitivity,
        correlation
      });
    }

    return sensitivities.sort((a, b) => Math.abs(b.sensitivity) - Math.abs(a.sensitivity));
  }

  private calculateCorrelation(x: number[], y: number[]): number {
    const n = x.length;
    const sumX = x.reduce((a, b) => a + b);
    const sumY = y.reduce((a, b) => a + b);
    const sumXY = x.reduce((total, xi, i) => total + xi * y[i], 0);
    const sumX2 = x.reduce((total, xi) => total + xi * xi, 0);
    const sumY2 = y.reduce((total, yi) => total + yi * yi, 0);

    const correlation = (n * sumXY - sumX * sumY) / 
      Math.sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY));

    return correlation;
  }

  private calculateElasticity(results: number[], variable: number[]): number {
    // Simple elasticity calculation
    const meanResult = results.reduce((a, b) => a + b) / results.length;
    const meanVariable = variable.reduce((a, b) => a + b) / variable.length;

    let elasticity = 0;
    for (let i = 0; i < results.length; i++) {
      const resultChange = (results[i] - meanResult) / meanResult;
      const variableChange = (variable[i] - meanVariable) / meanVariable;
      if (variableChange !== 0) {
        elasticity += resultChange / variableChange;
      }
    }

    return elasticity / results.length;
  }

  private generateRecommendations(
    type: string,
    results: any,
    scenarios: any,
    sensitivities: any[]
  ): string[] {
    const recommendations: string[] = [];

    // General recommendations based on results
    if (results.std / results.mean > 0.3) {
      recommendations.push('High variability detected. Consider risk mitigation strategies.');
    }

    if (scenarios.best.value / scenarios.worst.value > 3) {
      recommendations.push('Wide range of potential outcomes. Focus on factors that drive best-case scenarios.');
    }

    // Type-specific recommendations
    switch (type) {
      case 'PROMOTION_IMPACT':
        if (results.mean < 1.2) {
          recommendations.push('Expected ROI is below 20%. Consider adjusting promotion parameters.');
        }
        if (sensitivities[0].variable === 'discount' && sensitivities[0].sensitivity < -2) {
          recommendations.push('High price sensitivity detected. Smaller discounts may be more profitable.');
        }
        break;

      case 'PRICE_OPTIMIZATION':
        const optimalPrice = scenarios.mostLikely.conditions.priceChange || 0;
        if (Math.abs(optimalPrice) > 0.05) {
          recommendations.push(`Consider ${optimalPrice > 0 ? 'increasing' : 'decreasing'} price by ${Math.abs(optimalPrice * 100).toFixed(1)}%`);
        }
        break;

      case 'BUDGET_ALLOCATION':
        const topChannel = sensitivities[0].variable;
        recommendations.push(`Prioritize budget allocation to ${topChannel} for maximum ROI.`);
        break;

      case 'MARKET_SCENARIO':
        if (scenarios.worst.value < 0.8 * results.mean) {
          recommendations.push('Prepare contingency plans for adverse market conditions.');
        }
        break;

      case 'COMPETITIVE_RESPONSE':
        if (sensitivities.find(s => s.variable === 'competitorResponse')?.correlation < -0.5) {
          recommendations.push('Strong negative correlation with competitor actions. Consider differentiation strategies.');
        }
        break;
    }

    // Sensitivity-based recommendations
    const topSensitivities = sensitivities.slice(0, 3);
    recommendations.push(
      `Focus on optimizing: ${topSensitivities.map(s => s.variable).join(', ')} for maximum impact.`
    );

    return recommendations;
  }

  private extractSeasonality(historicalData: any[]): number {
    // Simplified seasonality extraction
    return 1 + (Math.sin(Date.now() / (365 * 24 * 60 * 60 * 1000) * 2 * Math.PI) * 0.2);
  }

  private extractTrend(historicalData: any[]): number {
    // Simplified trend extraction
    return 0.02; // 2% growth trend
  }

  private analyzeCompetitorAggressiveness(competitorData: any[]): number {
    // Analyze historical competitor behavior
    return 0.6; // 60% reaction strength
  }
}