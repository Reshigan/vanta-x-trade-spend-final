import { OpenAI } from 'openai';
import { Logger } from 'winston';
import { createLogger } from '../../utils/logger';
import { TradeSpendOptimizer } from '../ml/TradeSpendOptimizer';
import { AnomalyDetector } from '../ml/AnomalyDetector';
import { PredictiveAnalytics } from '../ml/PredictiveAnalytics';

export interface ChatMessage {
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp?: Date;
  metadata?: Record<string, any>;
}

export interface ChatContext {
  userId: string;
  companyId: string;
  sessionId: string;
  history: ChatMessage[];
  userData?: {
    name: string;
    role: string;
    department: string;
  };
}

export interface ChatResponse {
  message: string;
  suggestions?: string[];
  actions?: Array<{
    type: string;
    label: string;
    data: any;
  }>;
  visualizations?: Array<{
    type: 'chart' | 'table' | 'metric';
    data: any;
  }>;
}

export class VantaXAssistant {
  private logger: Logger;
  private openai: OpenAI | null = null;
  private tradeSpendOptimizer: TradeSpendOptimizer;
  private anomalyDetector: AnomalyDetector;
  private predictiveAnalytics: PredictiveAnalytics;
  private systemPrompt: string;

  constructor() {
    this.logger = createLogger('VantaXAssistant');
    this.tradeSpendOptimizer = new TradeSpendOptimizer();
    this.anomalyDetector = new AnomalyDetector();
    this.predictiveAnalytics = new PredictiveAnalytics();
    
    // Initialize OpenAI if API key is available
    if (process.env.OPENAI_API_KEY) {
      this.openai = new OpenAI({
        apiKey: process.env.OPENAI_API_KEY,
      });
    }

    this.systemPrompt = `You are Vanta X Assistant, an AI-powered trade spend management expert. 
You help users with:
- Trade spend optimization and ROI analysis
- Promotion planning and performance tracking
- Anomaly detection and alerts
- Predictive analytics and forecasting
- Data insights and recommendations

You have access to real-time data and can perform analyses, generate reports, and provide actionable insights.
Always be professional, concise, and data-driven in your responses.`;
  }

  async initialize(): Promise<void> {
    await Promise.all([
      this.tradeSpendOptimizer.initialize(),
      this.anomalyDetector.initialize(),
      this.predictiveAnalytics.initialize(),
    ]);
    this.logger.info('Vanta X Assistant initialized');
  }

  async processMessage(message: string, context: ChatContext): Promise<ChatResponse> {
    try {
      // Analyze user intent
      const intent = await this.analyzeIntent(message, context);
      
      // Route to appropriate handler
      switch (intent.category) {
        case 'trade_spend':
          return await this.handleTradeSpendQuery(message, intent, context);
        case 'analytics':
          return await this.handleAnalyticsQuery(message, intent, context);
        case 'anomaly':
          return await this.handleAnomalyQuery(message, intent, context);
        case 'prediction':
          return await this.handlePredictionQuery(message, intent, context);
        case 'general':
          return await this.handleGeneralQuery(message, context);
        default:
          return await this.handleGeneralQuery(message, context);
      }
    } catch (error) {
      this.logger.error('Error processing message:', error);
      return {
        message: 'I apologize, but I encountered an error processing your request. Please try again or contact support if the issue persists.',
        suggestions: [
          'Show me trade spend overview',
          'What are the current anomalies?',
          'Predict next month\'s performance',
        ],
      };
    }
  }

  private async analyzeIntent(message: string, context: ChatContext): Promise<any> {
    const lowerMessage = message.toLowerCase();
    
    // Simple intent classification based on keywords
    if (lowerMessage.includes('trade spend') || lowerMessage.includes('roi') || lowerMessage.includes('optimization')) {
      return { category: 'trade_spend', confidence: 0.9 };
    } else if (lowerMessage.includes('anomaly') || lowerMessage.includes('unusual') || lowerMessage.includes('alert')) {
      return { category: 'anomaly', confidence: 0.9 };
    } else if (lowerMessage.includes('predict') || lowerMessage.includes('forecast') || lowerMessage.includes('future')) {
      return { category: 'prediction', confidence: 0.9 };
    } else if (lowerMessage.includes('analyze') || lowerMessage.includes('trend') || lowerMessage.includes('performance')) {
      return { category: 'analytics', confidence: 0.8 };
    }
    
    // Use OpenAI for more complex intent analysis if available
    if (this.openai) {
      try {
        const completion = await this.openai.chat.completions.create({
          model: 'gpt-3.5-turbo',
          messages: [
            {
              role: 'system',
              content: 'Classify the user intent into one of these categories: trade_spend, analytics, anomaly, prediction, general. Respond with just the category name.',
            },
            {
              role: 'user',
              content: message,
            },
          ],
          temperature: 0.3,
          max_tokens: 10,
        });
        
        const category = completion.choices[0].message.content?.trim().toLowerCase() || 'general';
        return { category, confidence: 0.95 };
      } catch (error) {
        this.logger.error('OpenAI intent analysis failed:', error);
      }
    }
    
    return { category: 'general', confidence: 0.5 };
  }

  private async handleTradeSpendQuery(message: string, intent: any, context: ChatContext): Promise<ChatResponse> {
    // Extract parameters from the message
    const params = this.extractTradeSpendParams(message);
    
    // Perform optimization
    const optimization = await this.tradeSpendOptimizer.optimize({
      category: params.category || 'Beverages',
      storeType: params.storeType || 'Supermarket',
      discountType: params.discountType || 'PERCENTAGE',
      discountValue: params.discountValue || 15,
      duration: params.duration || 14,
      seasonality: params.seasonality || 0.7,
    });

    const response: ChatResponse = {
      message: `Based on my analysis, here's the trade spend optimization recommendation:

💰 **Recommended Spend**: ${this.formatCurrency(optimization.recommendedSpend)}
📈 **Expected ROI**: ${optimization.expectedROI.toFixed(2)}x
🎯 **Confidence Score**: ${(optimization.confidenceScore * 100).toFixed(0)}%

**Key Insights:**
${optimization.insights.map(insight => `• ${insight}`).join('\n')}

${optimization.riskFactors.length > 0 ? `\n**Risk Factors to Consider:**\n${optimization.riskFactors.map(risk => `⚠️ ${risk}`).join('\n')}` : ''}`,
      suggestions: [
        'Show me historical performance for similar promotions',
        'What if we increase the discount to 20%?',
        'Compare with competitor promotions',
      ],
      actions: [
        {
          type: 'create_promotion',
          label: 'Create Promotion with These Parameters',
          data: {
            plannedSpend: optimization.recommendedSpend,
            expectedROI: optimization.expectedROI,
          },
        },
      ],
      visualizations: [
        {
          type: 'metric',
          data: {
            title: 'Optimization Summary',
            metrics: [
              { label: 'Recommended Spend', value: optimization.recommendedSpend, format: 'currency' },
              { label: 'Expected ROI', value: optimization.expectedROI, format: 'percentage' },
              { label: 'Confidence', value: optimization.confidenceScore, format: 'percentage' },
            ],
          },
        },
      ],
    };

    return response;
  }

  private async handleAnalyticsQuery(message: string, intent: any, context: ChatContext): Promise<ChatResponse> {
    // Generate mock analytics data
    const mockData = this.generateMockTimeSeriesData();
    
    // Analyze trends
    const trendAnalysis = await this.predictiveAnalytics.analyzeTrends(mockData);
    
    const response: ChatResponse = {
      message: `Here's the analytics summary for your query:

📊 **Trend Analysis**
• Direction: ${trendAnalysis.trend.charAt(0).toUpperCase() + trendAnalysis.trend.slice(1)}
• Strength: ${(trendAnalysis.trendStrength * 100).toFixed(0)}%
${trendAnalysis.seasonality.detected ? `• Seasonality: Detected with ${trendAnalysis.seasonality.period}-day cycle` : '• Seasonality: Not detected'}

${trendAnalysis.changePoints.length > 0 ? `\n**Significant Changes Detected:**\n${trendAnalysis.changePoints.slice(0, 3).map(cp => 
  `• ${cp.timestamp.toLocaleDateString()}: ${cp.type === 'increase' ? '📈' : '📉'} ${cp.type} of ${this.formatNumber(cp.magnitude)}`
).join('\n')}` : ''}

Would you like me to generate predictions or dive deeper into specific metrics?`,
      suggestions: [
        'Generate 30-day forecast',
        'Show me year-over-year comparison',
        'Identify top performing categories',
      ],
      visualizations: [
        {
          type: 'chart',
          data: {
            type: 'line',
            title: 'Performance Trend',
            series: [
              {
                name: 'Actual',
                data: mockData.slice(-30).map(d => ({
                  x: d.timestamp,
                  y: d.value,
                })),
              },
            ],
          },
        },
      ],
    };

    return response;
  }

  private async handleAnomalyQuery(message: string, intent: any, context: ChatContext): Promise<ChatResponse> {
    // Generate mock anomaly data
    const mockAnomalies = this.generateMockAnomalies();
    
    // Detect anomalies
    const results = await this.anomalyDetector.detect(mockAnomalies);
    const anomalies = Array.isArray(results) ? results : [results];
    const detectedAnomalies = anomalies.filter(a => a.isAnomaly);
    
    const response: ChatResponse = {
      message: `🔍 **Anomaly Detection Results**

I've detected ${detectedAnomalies.length} anomalies in your data:

${detectedAnomalies.slice(0, 5).map((anomaly, index) => `
**Anomaly ${index + 1}**
• Type: ${anomaly.type}
• Severity: ${anomaly.severity.toUpperCase()} ${this.getSeverityEmoji(anomaly.severity)}
• Description: ${anomaly.description}
• Recommendation: ${anomaly.recommendation}
`).join('\n')}

${detectedAnomalies.length > 5 ? `\n... and ${detectedAnomalies.length - 5} more anomalies detected.` : ''}

Would you like me to investigate any specific anomaly in detail?`,
      suggestions: [
        'Show me critical anomalies only',
        'Analyze anomaly patterns over time',
        'Set up automated alerts',
      ],
      actions: detectedAnomalies.filter(a => a.severity === 'critical').map((anomaly, index) => ({
        type: 'investigate_anomaly',
        label: `Investigate ${anomaly.type}`,
        data: { anomaly },
      })),
    };

    return response;
  }

  private async handlePredictionQuery(message: string, intent: any, context: ChatContext): Promise<ChatResponse> {
    // Extract prediction parameters
    const steps = this.extractNumber(message, 'days|weeks|months') || 7;
    
    // Generate predictions
    const historicalData = this.generateMockTimeSeriesData();
    const predictions = await this.predictiveAnalytics.predict(historicalData, steps, {
      includeConfidenceInterval: true,
      model: 'ensemble',
    });
    
    const response: ChatResponse = {
      message: `🔮 **${steps}-Day Forecast**

Based on historical patterns and current trends, here are my predictions:

${predictions.slice(0, 3).map(pred => `
📅 **${pred.timestamp.toLocaleDateString()}**
• Predicted Value: ${this.formatNumber(pred.predictedValue)}
• Confidence Range: ${this.formatNumber(pred.confidenceInterval.lower)} - ${this.formatNumber(pred.confidenceInterval.upper)}
• Model Accuracy: ${(pred.accuracy * 100).toFixed(0)}%
`).join('\n')}

**Key Insights:**
${predictions[0].insights.map(insight => `• ${insight}`).join('\n')}

The forecast uses an ensemble model combining LSTM neural networks, ARIMA, and exponential smoothing for optimal accuracy.`,
      suggestions: [
        'Show me different scenarios',
        'What factors influence these predictions?',
        'Compare with last year\'s performance',
      ],
      visualizations: [
        {
          type: 'chart',
          data: {
            type: 'line',
            title: 'Forecast with Confidence Intervals',
            series: [
              {
                name: 'Historical',
                data: historicalData.slice(-30).map(d => ({
                  x: d.timestamp,
                  y: d.value,
                })),
              },
              {
                name: 'Forecast',
                data: predictions.map(p => ({
                  x: p.timestamp,
                  y: p.predictedValue,
                })),
              },
              {
                name: 'Upper Bound',
                data: predictions.map(p => ({
                  x: p.timestamp,
                  y: p.confidenceInterval.upper,
                })),
                dashStyle: 'dash',
              },
              {
                name: 'Lower Bound',
                data: predictions.map(p => ({
                  x: p.timestamp,
                  y: p.confidenceInterval.lower,
                })),
                dashStyle: 'dash',
              },
            ],
          },
        },
      ],
    };

    return response;
  }

  private async handleGeneralQuery(message: string, context: ChatContext): Promise<ChatResponse> {
    // Use OpenAI for general queries if available
    if (this.openai) {
      try {
        const completion = await this.openai.chat.completions.create({
          model: 'gpt-3.5-turbo',
          messages: [
            { role: 'system', content: this.systemPrompt },
            ...context.history.slice(-5).map(msg => ({
              role: msg.role as 'user' | 'assistant',
              content: msg.content,
            })),
            { role: 'user', content: message },
          ],
          temperature: 0.7,
          max_tokens: 500,
        });
        
        return {
          message: completion.choices[0].message.content || 'I apologize, but I couldn\'t generate a response.',
          suggestions: this.generateContextualSuggestions(message),
        };
      } catch (error) {
        this.logger.error('OpenAI query failed:', error);
      }
    }
    
    // Fallback response
    return {
      message: `I understand you're asking about "${message}". As your Vanta X Assistant, I can help you with:

• **Trade Spend Optimization**: Analyze and optimize your promotional spending
• **Anomaly Detection**: Identify unusual patterns in your data
• **Predictive Analytics**: Forecast future performance and trends
• **Performance Analysis**: Deep dive into your metrics and KPIs

How can I assist you specifically today?`,
      suggestions: [
        'Optimize my next promotion',
        'Show me current anomalies',
        'Predict next month\'s sales',
        'Analyze category performance',
      ],
    };
  }

  // Helper methods
  private extractTradeSpendParams(message: string): any {
    const params: any = {};
    
    // Extract category
    const categories = ['beverages', 'snacks', 'dairy', 'bakery'];
    for (const category of categories) {
      if (message.toLowerCase().includes(category)) {
        params.category = category.charAt(0).toUpperCase() + category.slice(1);
        break;
      }
    }
    
    // Extract discount value
    const discountMatch = message.match(/(\d+)%/);
    if (discountMatch) {
      params.discountValue = parseInt(discountMatch[1]);
    }
    
    // Extract duration
    const durationMatch = message.match(/(\d+)\s*(days?|weeks?)/i);
    if (durationMatch) {
      const value = parseInt(durationMatch[1]);
      const unit = durationMatch[2].toLowerCase();
      params.duration = unit.startsWith('week') ? value * 7 : value;
    }
    
    return params;
  }

  private extractNumber(message: string, pattern: string): number | null {
    const regex = new RegExp(`(\\d+)\\s*(${pattern})`, 'i');
    const match = message.match(regex);
    return match ? parseInt(match[1]) : null;
  }

  private generateMockTimeSeriesData(): any[] {
    const data = [];
    const now = new Date();
    
    for (let i = 90; i >= 0; i--) {
      const date = new Date(now.getTime() - i * 24 * 60 * 60 * 1000);
      data.push({
        timestamp: date,
        value: 10000 + Math.random() * 5000 + (90 - i) * 50 + Math.sin(i / 7) * 1000,
      });
    }
    
    return data;
  }

  private generateMockAnomalies(): any[] {
    const anomalies = [];
    const now = new Date();
    
    for (let i = 0; i < 10; i++) {
      anomalies.push({
        timestamp: new Date(now.getTime() - i * 24 * 60 * 60 * 1000),
        storeId: `ST00${i + 1}`,
        productId: `PRD00${i + 1}`,
        metric: ['revenue', 'units', 'transactions'][i % 3],
        value: i % 3 === 0 ? -100 : 10000 + Math.random() * 20000,
        expectedValue: 12000,
      });
    }
    
    return anomalies;
  }

  private generateContextualSuggestions(message: string): string[] {
    const suggestions = [
      'Show me trade spend optimization options',
      'What are the current performance trends?',
      'Detect anomalies in recent data',
      'Generate sales forecast for next month',
    ];
    
    // Add context-specific suggestions
    if (message.toLowerCase().includes('promotion')) {
      suggestions.unshift('Compare promotion performance across stores');
    }
    if (message.toLowerCase().includes('category')) {
      suggestions.unshift('Show top performing categories');
    }
    
    return suggestions.slice(0, 4);
  }

  private formatCurrency(value: number): string {
    return new Intl.NumberFormat('en-ZA', {
      style: 'currency',
      currency: 'ZAR',
    }).format(value);
  }

  private formatNumber(value: number): string {
    return new Intl.NumberFormat('en-ZA').format(Math.round(value));
  }

  private getSeverityEmoji(severity: string): string {
    const emojis: Record<string, string> = {
      low: '🟢',
      medium: '🟡',
      high: '🟠',
      critical: '🔴',
    };
    return emojis[severity] || '⚪';
  }

  // Conversation management
  async startConversation(context: ChatContext): Promise<ChatResponse> {
    const greeting = context.userData 
      ? `Hello ${context.userData.name}! I'm your Vanta X Assistant.`
      : `Hello! I'm your Vanta X Assistant.`;
    
    return {
      message: `${greeting} I'm here to help you optimize your trade spend, analyze performance, and provide AI-powered insights.

What would you like to explore today?`,
      suggestions: [
        'Show me trade spend overview',
        'Optimize my next promotion',
        'What anomalies should I be aware of?',
        'Predict next month\'s performance',
      ],
    };
  }

  async endConversation(context: ChatContext): Promise<ChatResponse> {
    return {
      message: `Thank you for using Vanta X Assistant! I hope I was able to help you today. 

Remember, I'm always here to help you:
• Optimize trade spend and maximize ROI
• Detect anomalies and prevent issues
• Forecast performance and plan ahead
• Analyze trends and gain insights

Have a great day!`,
      actions: [
        {
          type: 'export_conversation',
          label: 'Export Conversation',
          data: { sessionId: context.sessionId },
        },
      ],
    };
  }
}