import { describe, test, expect, beforeAll, afterAll } from '@jest/globals';
import { PrismaClient } from '@prisma/client';
import axios from 'axios';
import { faker } from '@faker-js/faker';

const prisma = new PrismaClient();
const API_BASE_URL = process.env.API_URL || 'http://localhost:4000/api/v1';

let authToken: string;
let companyId: string;
let userId: string;
let walletId: string;
let workflowId: string;

describe('Vanta X - FMCG Trade Marketing Management System - Comprehensive Test', () => {
  
  beforeAll(async () => {
    console.log('🧪 Starting comprehensive FMCG system test...');
  });
  
  afterAll(async () => {
    await prisma.$disconnect();
  });
  
  describe('1. Master Data Management & 5-Level Hierarchies', () => {
    let globalAccountId: string;
    let regionId: string;
    let countryId: string;
    let channelId: string;
    let storeId: string;
    
    test('Should create 5-level customer hierarchy', async () => {
      // Create Global Account
      const globalAccount = await axios.post(`${API_BASE_URL}/master-data/customer-hierarchy/global-account`, {
        code: 'GA-TEST-001',
        name: 'Test Global Account',
        description: 'Test global account for comprehensive testing'
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(globalAccount.status).toBe(201);
      globalAccountId = globalAccount.data.id;
      
      // Create Region
      const region = await axios.post(`${API_BASE_URL}/master-data/customer-hierarchy/region`, {
        code: 'REG-MIDDLE-EAST',
        name: 'Middle East Region',
        globalAccountId
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(region.status).toBe(201);
      regionId = region.data.id;
      
      // Create Country
      const country = await axios.post(`${API_BASE_URL}/master-data/customer-hierarchy/country`, {
        code: 'SA',
        name: 'Saudi Arabia',
        isoCode: 'SA',
        regionId
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(country.status).toBe(201);
      countryId = country.data.id;
      
      // Create Channel
      const channel = await axios.post(`${API_BASE_URL}/master-data/customer-hierarchy/channel`, {
        code: 'RETAIL-SA',
        name: 'Saudi Retail Channel',
        type: 'RETAIL',
        countryId
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(channel.status).toBe(201);
      channelId = channel.data.id;
      
      // Create Store with geofencing
      const store = await axios.post(`${API_BASE_URL}/master-data/customer-hierarchy/store`, {
        code: 'STR-RYD-001',
        name: 'Riyadh Flagship Store',
        type: 'HYPERMARKET',
        format: 'Large Format',
        latitude: 24.7136,
        longitude: 46.6753,
        geoFence: {
          radius: 500,
          type: 'circle'
        },
        channelId
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(store.status).toBe(201);
      expect(store.data).toHaveProperty('geoFence');
      storeId = store.data.id;
    });
    
    test('Should create 5-level product hierarchy', async () => {
      // Create Category
      const category = await axios.post(`${API_BASE_URL}/master-data/product-hierarchy/category`, {
        code: 'BEVERAGES',
        name: 'Beverages',
        description: 'All beverage products'
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(category.status).toBe(201);
      
      // Create Subcategory
      const subcategory = await axios.post(`${API_BASE_URL}/master-data/product-hierarchy/subcategory`, {
        code: 'CARBONATED',
        name: 'Carbonated Drinks',
        categoryId: category.data.id
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(subcategory.status).toBe(201);
      
      // Create Brand
      const brand = await axios.post(`${API_BASE_URL}/master-data/product-hierarchy/brand`, {
        code: 'BRAND-X',
        name: 'Brand X',
        subcategoryId: subcategory.data.id,
        isOwnBrand: true
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(brand.status).toBe(201);
      
      // Create Product Line
      const productLine = await axios.post(`${API_BASE_URL}/master-data/product-hierarchy/product-line`, {
        code: 'ZERO-SUGAR',
        name: 'Zero Sugar Line',
        brandId: brand.data.id
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(productLine.status).toBe(201);
      
      // Create Product (SKU)
      const product = await axios.post(`${API_BASE_URL}/master-data/product-hierarchy/product`, {
        sku: 'BX-ZS-330ML',
        name: 'Brand X Zero Sugar 330ml',
        barcode: '1234567890123',
        unitPrice: 2.5,
        cost: 1.2,
        packSize: '330ml',
        productLineId: productLine.data.id,
        lifecycle: 'ACTIVE'
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(product.status).toBe(201);
      expect(product.data).toHaveProperty('lifecycle');
    });
    
    test('Should create dynamic customer groups', async () => {
      const response = await axios.post(`${API_BASE_URL}/master-data/customer-groups`, {
        name: 'High Volume Stores',
        type: 'DYNAMIC',
        rules: {
          conditions: [
            {
              field: 'monthlyRevenue',
              operator: 'gte',
              value: 1000000
            },
            {
              field: 'storeType',
              operator: 'in',
              value: ['HYPERMARKET', 'SUPERMARKET']
            }
          ],
          logic: 'AND'
        }
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(201);
      expect(response.data.type).toBe('DYNAMIC');
      expect(response.data.rules).toBeDefined();
    });
  });
  
  describe('2. AI-Powered Forecasting & Budgeting', () => {
    test('Should generate ensemble forecast with multiple models', async () => {
      const response = await axios.post(`${API_BASE_URL}/ai/forecast/ensemble`, {
        historicalData: Array.from({ length: 365 }, (_, i) => ({
          timestamp: new Date(Date.now() - (365 - i) * 24 * 60 * 60 * 1000),
          value: 100000 + Math.sin(i / 30) * 20000 + Math.random() * 10000
        })),
        externalFactors: {
          weather: Array.from({ length: 365 }, () => 20 + Math.random() * 15),
          economicIndicators: {
            gdpGrowth: 0.03,
            inflation: 0.02,
            consumerConfidence: 0.75
          },
          seasonality: 0.8
        },
        horizon: 30,
        confidence: 95
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(response.data.predictions).toHaveLength(120); // 4 models x 30 days
      expect(response.data.ensemblePrediction).toHaveLength(30);
      expect(response.data.modelWeights).toHaveProperty('arima');
      expect(response.data.modelWeights).toHaveProperty('prophet');
      expect(response.data.modelWeights).toHaveProperty('xgboost');
      expect(response.data.modelWeights).toHaveProperty('neural');
      expect(response.data.accuracy).toHaveProperty('mape');
      expect(response.data.accuracy).toHaveProperty('rmse');
    });
    
    test('Should create and lock budget with AI suggestions', async () => {
      // Get AI budget suggestions
      const suggestions = await axios.get(`${API_BASE_URL}/ai/budget/suggestions`, {
        params: {
          year: 2024,
          type: 'MARKETING',
          historicalPerformance: true
        },
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(suggestions.status).toBe(200);
      expect(suggestions.data).toHaveProperty('suggestedAmount');
      expect(suggestions.data).toHaveProperty('allocation');
      
      // Create budget
      const budget = await axios.post(`${API_BASE_URL}/budgets`, {
        name: 'Marketing Budget 2024',
        type: 'MARKETING',
        year: 2024,
        period: 'ANNUAL',
        amount: suggestions.data.suggestedAmount,
        status: 'DRAFT'
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(budget.status).toBe(201);
      
      // KAM adjusts budget
      const adjusted = await axios.patch(`${API_BASE_URL}/budgets/${budget.data.id}/adjust`, {
        amount: suggestions.data.suggestedAmount * 1.1,
        justification: 'Increased for new product launches'
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(adjusted.status).toBe(200);
      
      // Lock budget
      const locked = await axios.post(`${API_BASE_URL}/budgets/${budget.data.id}/lock`, {}, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(locked.status).toBe(200);
      expect(locked.data.status).toBe('LOCKED');
      expect(locked.data.lockedBy).toBeDefined();
    });
  });
  
  describe('3. Marketing Spend Management', () => {
    test('Should create multi-dimensional campaign with AI caption', async () => {
      const response = await axios.post(`${API_BASE_URL}/campaigns`, {
        code: 'CAMP-2024-001',
        name: 'Summer Refresh Campaign',
        type: 'INTEGRATED',
        objective: 'Increase market share by 5%',
        startDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        endDate: new Date(Date.now() + 60 * 24 * 60 * 60 * 1000),
        plannedSpend: 500000,
        generateAICaption: true,
        creativeAssets: {
          images: ['campaign-hero.jpg', 'product-shots.jpg'],
          videos: ['tv-commercial.mp4'],
          copy: 'Refresh your summer with our cool beverages'
        }
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(201);
      expect(response.data.aiCaption).toBeDefined();
      expect(response.data.aiCaption).toContain('summer');
      
      // Add customer hierarchy overlay
      const customerOverlay = await axios.post(`${API_BASE_URL}/campaigns/${response.data.id}/customer-overlay`, {
        globalAccounts: ['GA-TEST-001'],
        regions: ['REG-MIDDLE-EAST'],
        channels: ['RETAIL-SA'],
        excludeStores: []
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(customerOverlay.status).toBe(200);
      
      // Add product hierarchy overlay
      const productOverlay = await axios.post(`${API_BASE_URL}/campaigns/${response.data.id}/product-overlay`, {
        categories: ['BEVERAGES'],
        brands: ['BRAND-X'],
        productLines: ['ZERO-SUGAR'],
        excludeProducts: []
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(productOverlay.status).toBe(200);
    });
    
    test('Should analyze campaign performance with computer vision', async () => {
      const formData = new FormData();
      formData.append('campaignId', 'CAMP-2024-001');
      formData.append('image', new Blob(['fake-image-data'], { type: 'image/jpeg' }), 'store-display.jpg');
      
      const response = await axios.post(`${API_BASE_URL}/ai/campaign/analyze-display`, formData, {
        headers: {
          Authorization: `Bearer ${authToken}`,
          'Content-Type': 'multipart/form-data'
        }
      });
      
      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('displayCompliance');
      expect(response.data).toHaveProperty('brandVisibility');
      expect(response.data).toHaveProperty('recommendations');
    });
  });
  
  describe('4. Cash Co-op Management with Digital Wallets', () => {
    test('Should create co-op budget with criteria', async () => {
      const response = await axios.post(`${API_BASE_URL}/coop/budgets`, {
        name: 'Q1 2024 Co-op Fund',
        totalAmount: 1000000,
        criteria: {
          qualificationRules: [
            {
              type: 'MINIMUM_PURCHASE',
              value: 50000,
              period: 'MONTHLY'
            },
            {
              type: 'GROWTH_TARGET',
              value: 0.1,
              baseline: 'PREVIOUS_YEAR'
            }
          ],
          documentationRequired: ['INVOICE', 'PROOF_OF_DISPLAY', 'SALES_REPORT']
        },
        startDate: new Date(),
        endDate: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000)
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(201);
      expect(response.data.criteria).toBeDefined();
    });
    
    test('Should create digital wallet with QR code', async () => {
      const response = await axios.post(`${API_BASE_URL}/coop/wallets`, {
        userId,
        storeId: 'STR-RYD-001',
        coopBudgetId: 'coop-budget-id',
        creditLimit: 50000,
        pin: '1234'
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(201);
      expect(response.data.walletNumber).toMatch(/^VXW-/);
      expect(response.data.qrCode).toContain('data:image/png;base64');
      walletId = response.data.id;
    });
    
    test('Should process geo-fenced transaction', async () => {
      const response = await axios.post(`${API_BASE_URL}/coop/wallets/${walletId}/transaction`, {
        amount: 5000,
        type: 'DEBIT',
        storeId: 'STR-RYD-001',
        description: 'In-store promotion materials',
        reasonCode: 'PROMO_MATERIALS',
        location: {
          latitude: 24.7136,
          longitude: 46.6753
        }
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(response.data.transactionId).toMatch(/^TXN-/);
      expect(response.data.balance).toBe(45000);
    });
    
    test('Should reject transaction outside geofence', async () => {
      const response = await axios.post(`${API_BASE_URL}/coop/wallets/${walletId}/transaction`, {
        amount: 1000,
        type: 'DEBIT',
        storeId: 'STR-RYD-001',
        description: 'Test transaction',
        location: {
          latitude: 25.0000, // Outside geofence
          longitude: 47.0000
        }
      }, {
        headers: { Authorization: `Bearer ${authToken}` },
        validateStatus: () => true
      });
      
      expect(response.status).toBe(400);
      expect(response.data.error).toContain('geofence');
    });
  });
  
  describe('5. Trading Terms & Dynamic Promotions', () => {
    test('Should create flexible trading terms', async () => {
      const response = await axios.post(`${API_BASE_URL}/trading-terms`, {
        code: 'TT-2024-001',
        name: 'Volume Discount Agreement',
        type: 'VOLUME_DISCOUNT',
        storeId: 'STR-RYD-001',
        startDate: new Date(),
        terms: {
          tiers: [
            { minVolume: 0, maxVolume: 10000, discount: 0.05 },
            { minVolume: 10001, maxVolume: 50000, discount: 0.08 },
            { minVolume: 50001, maxVolume: null, discount: 0.12 }
          ],
          paymentTerms: {
            days: 30,
            earlyPaymentDiscount: 0.02,
            earlyPaymentDays: 10
          },
          rebates: {
            quarterly: true,
            annual: true,
            growthBonus: 0.03
          }
        }
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(201);
      expect(response.data.terms.tiers).toHaveLength(3);
    });
    
    test('Should create dynamic promotion with profitability analysis', async () => {
      const response = await axios.post(`${API_BASE_URL}/promotions/dynamic`, {
        name: 'Smart Summer Promo',
        type: 'PRICE_REDUCTION',
        mechanism: 'PERCENTAGE_OFF',
        baselineWindow: {
          before: 6,
          after: 6,
          unit: 'WEEKS'
        },
        discountType: 'DYNAMIC',
        discountRules: {
          base: 0.15,
          modifiers: [
            {
              condition: 'VOLUME_THRESHOLD',
              threshold: 1000,
              adjustment: 0.05
            },
            {
              condition: 'TIME_OF_DAY',
              hours: [10, 14],
              adjustment: 0.03
            }
          ]
        },
        budget: 100000,
        targetRevenue: 500000,
        startDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        endDate: new Date(Date.now() + 21 * 24 * 60 * 60 * 1000)
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(201);
      
      // Get profitability analysis
      const profitability = await axios.get(`${API_BASE_URL}/promotions/${response.data.id}/profitability`, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(profitability.status).toBe(200);
      expect(profitability.data).toHaveProperty('netProfitability');
      expect(profitability.data).toHaveProperty('cannibalization');
      expect(profitability.data).toHaveProperty('incrementalSales');
      expect(profitability.data).toHaveProperty('breakeven');
      expect(profitability.data).toHaveProperty('profitWaterfall');
    });
  });
  
  describe('6. AI Assistant & Monte Carlo Simulations', () => {
    test('Should run promotion impact simulation', async () => {
      const response = await axios.post(`${API_BASE_URL}/ai/simulate`, {
        type: 'PROMOTION_IMPACT',
        parameters: {
          baseValue: 1000000,
          variables: [
            {
              name: 'discount',
              distribution: 'uniform',
              params: { min: 0.1, max: 0.3 },
              impact: -2.5
            },
            {
              name: 'marketGrowth',
              distribution: 'normal',
              params: { mean: 0.05, std: 0.02 },
              impact: 1.0
            },
            {
              name: 'competitorResponse',
              distribution: 'exponential',
              params: { lambda: 2 },
              impact: -0.5
            }
          ],
          constraints: [
            { type: 'min', value: 800000 },
            { type: 'max', value: 1500000 }
          ],
          iterations: 10000,
          confidenceLevel: 95
        }
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(response.data.results).toHaveProperty('mean');
      expect(response.data.results).toHaveProperty('percentiles');
      expect(response.data.results.confidenceInterval).toHaveLength(2);
      expect(response.data.scenarios).toHaveProperty('best');
      expect(response.data.scenarios).toHaveProperty('worst');
      expect(response.data.scenarios).toHaveProperty('mostLikely');
      expect(response.data.sensitivities).toBeInstanceOf(Array);
      expect(response.data.recommendations).toBeInstanceOf(Array);
    });
    
    test('Should interact with AI assistant for recommendations', async () => {
      const session = await axios.post(`${API_BASE_URL}/ai/assistant/session`, {
        userId,
        context: {
          role: 'KAM',
          currentPromotion: 'PROMO-2024-001',
          region: 'Middle East'
        }
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(session.status).toBe(200);
      const sessionId = session.data.sessionId;
      
      // Ask for recommendations
      const response = await axios.post(`${API_BASE_URL}/ai/assistant/message`, {
        sessionId,
        message: 'What is the optimal discount level for beverages in hypermarkets to maximize ROI?'
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(response.data.response).toHaveProperty('message');
      expect(response.data.response).toHaveProperty('data');
      expect(response.data.response).toHaveProperty('actions');
      expect(response.data.response.message).toContain('ROI');
      expect(response.data.response.data).toHaveProperty('optimalDiscount');
      expect(response.data.response.data).toHaveProperty('expectedROI');
    });
  });
  
  describe('7. Executive Analytics & Reporting', () => {
    test('Should generate profitability heat map', async () => {
      const response = await axios.get(`${API_BASE_URL}/analytics/executive/heatmap`, {
        params: {
          view: 'vendor',
          metric: 'profit',
          period: 'quarter'
        },
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('dimension');
      expect(response.data).toHaveProperty('categories');
      expect(response.data).toHaveProperty('data');
      expect(response.data).toHaveProperty('metadata');
      expect(response.data.metadata).toHaveProperty('min');
      expect(response.data.metadata).toHaveProperty('max');
      expect(response.data.metadata).toHaveProperty('average');
    });
    
    test('Should identify opportunities with AI', async () => {
      const response = await axios.get(`${API_BASE_URL}/analytics/opportunities`, {
        params: {
          minImpact: 100000,
          maxEffort: 'medium'
        },
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(response.data).toBeInstanceOf(Array);
      expect(response.data[0]).toHaveProperty('id');
      expect(response.data[0]).toHaveProperty('title');
      expect(response.data[0]).toHaveProperty('impact');
      expect(response.data[0]).toHaveProperty('effort');
      expect(response.data[0]).toHaveProperty('actions');
    });
    
    test('Should generate self-service report', async () => {
      const response = await axios.post(`${API_BASE_URL}/reports/generate`, {
        name: 'Executive Monthly Report',
        type: 'EXECUTIVE_SUMMARY',
        parameters: {
          period: 'LAST_MONTH',
          metrics: ['revenue', 'profit', 'roi', 'spend'],
          dimensions: ['vendor', 'product', 'customer'],
          includeAIInsights: true,
          includeForecasts: true
        },
        format: 'PDF',
        recipients: ['executive@diplomat.sa']
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('reportId');
      expect(response.data).toHaveProperty('status');
      expect(response.data).toHaveProperty('downloadUrl');
    });
  });
  
  describe('8. Workflow Management & Governance', () => {
    test('Should create visual workflow', async () => {
      const response = await axios.post(`${API_BASE_URL}/workflows`, {
        name: 'Promotion Approval Workflow',
        type: 'PROMOTION_APPROVAL',
        nodes: [
          {
            id: 'node-1',
            type: 'approval',
            data: {
              label: 'Manager Approval',
              approver: 'MANAGER',
              sla: '24h'
            }
          },
          {
            id: 'node-2',
            type: 'condition',
            data: {
              label: 'Budget Check',
              condition: 'promotion.budget > 100000'
            }
          },
          {
            id: 'node-3',
            type: 'approval',
            data: {
              label: 'Director Approval',
              approver: 'DIRECTOR',
              sla: '48h'
            }
          },
          {
            id: 'node-4',
            type: 'notification',
            data: {
              label: 'Notify Team',
              recipients: ['Requester', 'Finance', 'Marketing']
            }
          }
        ],
        edges: [
          { source: 'node-1', target: 'node-2' },
          { source: 'node-2', sourceHandle: 'yes', target: 'node-3' },
          { source: 'node-2', sourceHandle: 'no', target: 'node-4' },
          { source: 'node-3', target: 'node-4' }
        ]
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(201);
      expect(response.data.nodes).toHaveLength(4);
      expect(response.data.edges).toHaveLength(4);
      workflowId = response.data.id;
    });
    
    test('Should process approval with delegation', async () => {
      // Create delegation
      const delegation = await axios.post(`${API_BASE_URL}/delegations`, {
        toUserId: 'delegate-user-id',
        startDate: new Date(),
        endDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        scope: {
          workflows: ['PROMOTION_APPROVAL'],
          maxAmount: 500000
        }
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(delegation.status).toBe(201);
      
      // Process approval
      const approval = await axios.post(`${API_BASE_URL}/approvals/process`, {
        workflowId,
        entityType: 'PROMOTION',
        entityId: 'PROMO-2024-001',
        action: 'APPROVE',
        comments: 'Approved with conditions'
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(approval.status).toBe(200);
      expect(approval.data.status).toBe('APPROVED');
      expect(approval.data.delegatedTo).toBeDefined();
    });
  });
  
  describe('9. Security & Compliance', () => {
    test('Should enforce GDPR compliance', async () => {
      // Request data export
      const exportRequest = await axios.post(`${API_BASE_URL}/gdpr/export`, {
        userId,
        format: 'JSON'
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(exportRequest.status).toBe(200);
      expect(exportRequest.data).toHaveProperty('requestId');
      
      // Request data deletion
      const deleteRequest = await axios.post(`${API_BASE_URL}/gdpr/delete`, {
        userId: 'test-user-to-delete',
        reason: 'User request'
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(deleteRequest.status).toBe(200);
      expect(deleteRequest.data).toHaveProperty('scheduledDate');
    });
    
    test('Should generate SOX compliance audit trail', async () => {
      const response = await axios.get(`${API_BASE_URL}/audit/sox-report`, {
        params: {
          startDate: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000),
          endDate: new Date(),
          includeFinancialTransactions: true,
          includeApprovals: true,
          includeSystemAccess: true
        },
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('transactions');
      expect(response.data).toHaveProperty('approvals');
      expect(response.data).toHaveProperty('accessLogs');
      expect(response.data).toHaveProperty('summary');
    });
  });
  
  describe('10. Integration Testing', () => {
    test('Should sync with SAP S/4HANA', async () => {
      const response = await axios.post(`${API_BASE_URL}/integration/sap/sync`, {
        type: 'S4HANA',
        entities: ['CUSTOMERS', 'PRODUCTS', 'SALES_ORDERS'],
        mode: 'INCREMENTAL',
        lastSyncTimestamp: new Date(Date.now() - 24 * 60 * 60 * 1000)
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('recordsProcessed');
      expect(response.data).toHaveProperty('recordsSuccess');
      expect(response.data).toHaveProperty('recordsFailed');
      expect(response.data).toHaveProperty('nextSyncTimestamp');
    });
    
    test('Should import Excel with validation', async () => {
      const formData = new FormData();
      const excelContent = 'mock excel content'; // In real test, use actual Excel file
      formData.append('file', new Blob([excelContent], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }), 'trade_spend_import.xlsx');
      formData.append('type', 'TRADE_SPEND');
      formData.append('validateOnly', 'true');
      
      const response = await axios.post(`${API_BASE_URL}/integration/excel/import`, formData, {
        headers: {
          Authorization: `Bearer ${authToken}`,
          'Content-Type': 'multipart/form-data'
        }
      });
      
      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('validationResults');
      expect(response.data.validationResults).toHaveProperty('errors');
      expect(response.data.validationResults).toHaveProperty('warnings');
      expect(response.data.validationResults).toHaveProperty('summary');
    });
  });
  
  describe('11. Performance & Scalability', () => {
    test('Should handle high-volume concurrent requests', async () => {
      const requests = Array.from({ length: 100 }, (_, i) => 
        axios.get(`${API_BASE_URL}/analytics/performance`, {
          params: {
            storeId: `STORE-${i % 10}`,
            period: 'LAST_MONTH'
          },
          headers: { Authorization: `Bearer ${authToken}` }
        })
      );
      
      const start = Date.now();
      const responses = await Promise.all(requests);
      const duration = Date.now() - start;
      
      expect(responses.every(r => r.status === 200)).toBe(true);
      expect(duration).toBeLessThan(10000); // All requests complete within 10 seconds
      
      // Check response times
      const responseTimes = responses.map(r => r.headers['x-response-time']);
      const avgResponseTime = responseTimes.reduce((a, b) => a + parseInt(b), 0) / responseTimes.length;
      expect(avgResponseTime).toBeLessThan(500); // Average response time under 500ms
    });
    
    test('Should efficiently query large datasets', async () => {
      const response = await axios.get(`${API_BASE_URL}/analytics/big-data`, {
        params: {
          aggregation: 'DAILY',
          metrics: ['revenue', 'volume', 'tradeSpend'],
          dimensions: ['store', 'product', 'promotion'],
          dateRange: 'LAST_YEAR',
          limit: 10000
        },
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(response.data.data).toBeInstanceOf(Array);
      expect(response.data.pagination).toHaveProperty('total');
      expect(response.data.pagination).toHaveProperty('pages');
      expect(parseInt(response.headers['x-query-time'])).toBeLessThan(2000); // Query completes in under 2 seconds
    });
  });
  
  describe('12. Mobile & Offline Capabilities', () => {
    test('Should sync offline transactions', async () => {
      const offlineTransactions = [
        {
          localId: 'offline-txn-1',
          walletId,
          amount: 1000,
          type: 'DEBIT',
          timestamp: new Date(Date.now() - 2 * 60 * 60 * 1000),
          location: { latitude: 24.7136, longitude: 46.6753 }
        },
        {
          localId: 'offline-txn-2',
          walletId,
          amount: 500,
          type: 'DEBIT',
          timestamp: new Date(Date.now() - 1 * 60 * 60 * 1000),
          location: { latitude: 24.7136, longitude: 46.6753 }
        }
      ];
      
      const response = await axios.post(`${API_BASE_URL}/mobile/sync/transactions`, {
        transactions: offlineTransactions,
        deviceId: 'mobile-device-001'
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(response.data.synced).toBe(2);
      expect(response.data.conflicts).toHaveLength(0);
      expect(response.data.serverTransactionIds).toHaveLength(2);
    });
  });
});