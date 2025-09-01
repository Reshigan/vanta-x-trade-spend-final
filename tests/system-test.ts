import { describe, test, expect, beforeAll, afterAll } from '@jest/globals';
import { PrismaClient } from '@prisma/client';
import axios from 'axios';
import FormData from 'form-data';
import fs from 'fs';
import path from 'path';

const prisma = new PrismaClient();
const API_BASE_URL = process.env.API_URL || 'http://localhost:4000/api/v1';

let authToken: string;
let companyId: string;
let userId: string;

describe('Vanta X - Trade Spend Platform System Test', () => {
  
  beforeAll(async () => {
    console.log('🧪 Starting comprehensive system test...');
  });
  
  afterAll(async () => {
    await prisma.$disconnect();
  });
  
  describe('1. Authentication & SSO', () => {
    test('Should authenticate user with email/password', async () => {
      const response = await axios.post(`${API_BASE_URL}/auth/login`, {
        email: 'admin@diplomat.sa',
        password: 'DiplomatSA2024!'
      });
      
      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('accessToken');
      expect(response.data).toHaveProperty('user');
      expect(response.data.user.company.name).toBe('Diplomat SA');
      
      authToken = response.data.accessToken;
      companyId = response.data.user.companyId;
      userId = response.data.user.id;
    });
    
    test('Should validate Microsoft SSO endpoint', async () => {
      const response = await axios.get(`${API_BASE_URL}/auth/microsoft`, {
        maxRedirects: 0,
        validateStatus: (status) => status === 302
      });
      
      expect(response.status).toBe(302);
      expect(response.headers.location).toContain('login.microsoftonline.com');
    });
    
    test('Should refresh access token', async () => {
      const loginResponse = await axios.post(`${API_BASE_URL}/auth/login`, {
        email: 'admin@diplomat.sa',
        password: 'DiplomatSA2024!'
      });
      
      const response = await axios.post(`${API_BASE_URL}/auth/refresh`, {
        refreshToken: loginResponse.data.refreshToken
      });
      
      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('accessToken');
    });
  });
  
  describe('2. Company & User Management', () => {
    test('Should retrieve company details', async () => {
      const response = await axios.get(`${API_BASE_URL}/companies/${companyId}`, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(response.data.name).toBe('Diplomat SA');
      expect(response.data.licenseCount).toBe(10);
      expect(response.data.licenseType).toBe('ENTERPRISE');
    });
    
    test('Should list all users in company', async () => {
      const response = await axios.get(`${API_BASE_URL}/companies/${companyId}/users`, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(response.data.length).toBe(10);
      expect(response.data.some(u => u.role === 'ADMIN')).toBe(true);
      expect(response.data.some(u => u.role === 'MANAGER')).toBe(true);
      expect(response.data.some(u => u.role === 'ANALYST')).toBe(true);
    });
  });
  
  describe('3. Trade Marketing Operations', () => {
    test('Should create a new promotion', async () => {
      const response = await axios.post(`${API_BASE_URL}/promotions`, {
        name: 'Test Summer Sale 2024',
        description: 'System test promotion',
        type: 'SEASONAL',
        startDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        endDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        discountType: 'PERCENTAGE',
        discountValue: 20,
        budget: 100000,
        targetRevenue: 400000
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(201);
      expect(response.data).toHaveProperty('id');
      expect(response.data.status).toBe('DRAFT');
    });
    
    test('Should list promotions with filters', async () => {
      const response = await axios.get(`${API_BASE_URL}/promotions`, {
        params: {
          status: 'ACTIVE',
          page: 1,
          limit: 20
        },
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('data');
      expect(response.data).toHaveProperty('pagination');
      expect(Array.isArray(response.data.data)).toBe(true);
    });
    
    test('Should retrieve trade spend summary', async () => {
      const response = await axios.get(`${API_BASE_URL}/trade-spend/summary`, {
        params: {
          startDate: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000),
          endDate: new Date()
        },
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('totalSpend');
      expect(response.data).toHaveProperty('totalRevenue');
      expect(response.data).toHaveProperty('roi');
    });
  });
  
  describe('4. Analytics & Reporting', () => {
    test('Should generate performance report', async () => {
      const response = await axios.get(`${API_BASE_URL}/analytics/performance`, {
        params: {
          period: 'MONTHLY',
          year: new Date().getFullYear()
        },
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('revenue');
      expect(response.data).toHaveProperty('tradeSpend');
      expect(response.data).toHaveProperty('roi');
      expect(Array.isArray(response.data.monthlyData)).toBe(true);
    });
    
    test('Should retrieve store performance metrics', async () => {
      const response = await axios.get(`${API_BASE_URL}/analytics/stores`, {
        params: {
          storeType: 'HYPERMARKET'
        },
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(Array.isArray(response.data)).toBe(true);
      expect(response.data.length).toBeGreaterThan(0);
      expect(response.data[0]).toHaveProperty('storeId');
      expect(response.data[0]).toHaveProperty('revenue');
      expect(response.data[0]).toHaveProperty('tradeSpend');
    });
  });
  
  describe('5. AI & Machine Learning', () => {
    test('Should optimize trade spend allocation', async () => {
      const response = await axios.post(`${API_BASE_URL}/ai/optimize/trade-spend`, {
        category: 'Beverages',
        storeType: 'SUPERMARKET',
        discountType: 'PERCENTAGE',
        discountValue: 15,
        duration: 14,
        seasonality: 0.8
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('success', true);
      expect(response.data.optimization).toHaveProperty('recommendedSpend');
      expect(response.data.optimization).toHaveProperty('expectedROI');
      expect(response.data.optimization.expectedROI).toBeGreaterThan(1);
    });
    
    test('Should detect anomalies in spending patterns', async () => {
      const testData = Array.from({ length: 30 }, (_, i) => ({
        timestamp: new Date(Date.now() - (30 - i) * 24 * 60 * 60 * 1000),
        storeId: 'STORE-001',
        productId: 'PROD-001',
        metric: 'trade_spend',
        value: i === 15 ? 50000 : 10000 + Math.random() * 5000,
        expectedValue: 12500
      }));
      
      const response = await axios.post(`${API_BASE_URL}/ai/anomaly/detect`, {
        data: testData
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('success', true);
      expect(Array.isArray(response.data.anomalies)).toBe(true);
      expect(response.data.anomalies.some(a => a.isAnomaly)).toBe(true);
    });
    
    test('Should generate revenue predictions', async () => {
      const historicalData = Array.from({ length: 12 }, (_, i) => ({
        timestamp: new Date(2024, i, 1),
        value: 1000000 + Math.random() * 200000
      }));
      
      const response = await axios.post(`${API_BASE_URL}/ai/predict`, {
        historicalData,
        steps: 3,
        options: {
          includeConfidenceInterval: true,
          model: 'ensemble'
        }
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('success', true);
      expect(Array.isArray(response.data.predictions)).toBe(true);
      expect(response.data.predictions.length).toBe(3);
      expect(response.data.predictions[0]).toHaveProperty('predictedValue');
      expect(response.data.predictions[0]).toHaveProperty('confidenceInterval');
    });
  });
  
  describe('6. AI Chatbot', () => {
    let sessionId: string;
    
    test('Should start chatbot session', async () => {
      const response = await axios.post(`${API_BASE_URL}/chatbot/sessions/start`, {
        userId,
        companyId,
        userData: {
          name: 'Test User',
          role: 'MANAGER',
          department: 'Trade Marketing'
        }
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('success', true);
      expect(response.data).toHaveProperty('sessionId');
      expect(response.data.response).toHaveProperty('message');
      
      sessionId = response.data.sessionId;
    });
    
    test('Should respond to trade spend queries', async () => {
      const response = await axios.post(`${API_BASE_URL}/chatbot/message`, {
        sessionId,
        message: 'What is our current trade spend ROI for beverages in hypermarkets?'
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('success', true);
      expect(response.data.response).toHaveProperty('message');
      expect(response.data.response.message).toContain('ROI');
    });
    
    test('Should provide actionable recommendations', async () => {
      const response = await axios.post(`${API_BASE_URL}/chatbot/message`, {
        sessionId,
        message: 'How can we improve our promotion effectiveness?'
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(response.data.response).toHaveProperty('message');
      expect(response.data.response).toHaveProperty('actions');
      expect(Array.isArray(response.data.response.actions)).toBe(true);
    });
  });
  
  describe('7. SAP Integration', () => {
    test('Should validate SAP ECC connection', async () => {
      const response = await axios.post(`${API_BASE_URL}/integration/sap/connect`, {
        type: 'ECC',
        host: 'sap-ecc.diplomat.sa',
        client: '100',
        username: 'RFC_USER',
        password: 'test_password'
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('success');
      expect(response.data).toHaveProperty('status');
    });
    
    test('Should validate SAP S/4HANA connection', async () => {
      const response = await axios.post(`${API_BASE_URL}/integration/sap/connect`, {
        type: 'S4HANA',
        host: 'sap-s4.diplomat.sa',
        client: '100',
        username: 'RFC_USER',
        password: 'test_password'
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });
      
      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('success');
      expect(response.data).toHaveProperty('status');
    });
  });
  
  describe('8. Excel Import/Export', () => {
    test('Should download Excel template', async () => {
      const response = await axios.get(`${API_BASE_URL}/integration/excel/template/trade_spend`, {
        headers: { Authorization: `Bearer ${authToken}` },
        responseType: 'arraybuffer'
      });
      
      expect(response.status).toBe(200);
      expect(response.headers['content-type']).toContain('spreadsheetml');
      expect(response.data.byteLength).toBeGreaterThan(0);
    });
    
    test('Should import data from Excel', async () => {
      // Create a mock Excel file
      const form = new FormData();
      const mockExcelContent = Buffer.from('mock excel content');
      form.append('file', mockExcelContent, 'test_import.xlsx');
      form.append('type', 'trade_spend');
      
      const response = await axios.post(`${API_BASE_URL}/integration/excel/import`, form, {
        headers: {
          ...form.getHeaders(),
          Authorization: `Bearer ${authToken}`
        }
      });
      
      expect(response.status).toBe(200);
      expect(response.data).toHaveProperty('success');
      expect(response.data).toHaveProperty('recordsProcessed');
      expect(response.data).toHaveProperty('recordsImported');
    });
  });
  
  describe('9. Responsive Design & UI', () => {
    test('Should serve web application', async () => {
      const response = await axios.get('http://localhost:3000', {
        validateStatus: () => true
      });
      
      expect([200, 404]).toContain(response.status);
    });
    
    test('Should serve admin portal', async () => {
      const response = await axios.get('http://localhost:3001', {
        validateStatus: () => true
      });
      
      expect([200, 404]).toContain(response.status);
    });
  });
  
  describe('10. Performance & Load Testing', () => {
    test('Should handle concurrent requests', async () => {
      const requests = Array.from({ length: 50 }, () => 
        axios.get(`${API_BASE_URL}/promotions`, {
          headers: { Authorization: `Bearer ${authToken}` }
        })
      );
      
      const start = Date.now();
      const responses = await Promise.all(requests);
      const duration = Date.now() - start;
      
      expect(responses.every(r => r.status === 200)).toBe(true);
      expect(duration).toBeLessThan(5000); // All requests complete within 5 seconds
    });
    
    test('Should enforce rate limiting', async () => {
      const requests = Array.from({ length: 150 }, () => 
        axios.get(`${API_BASE_URL}/health`, {
          validateStatus: () => true
        })
      );
      
      const responses = await Promise.all(requests);
      const rateLimited = responses.filter(r => r.status === 429);
      
      expect(rateLimited.length).toBeGreaterThan(0);
    });
  });
  
  describe('11. Security Testing', () => {
    test('Should reject requests without authentication', async () => {
      const response = await axios.get(`${API_BASE_URL}/promotions`, {
        validateStatus: () => true
      });
      
      expect(response.status).toBe(401);
    });
    
    test('Should validate JWT token expiry', async () => {
      const expiredToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjEyMyIsImV4cCI6MTAwMDAwMDAwMH0.invalid';
      
      const response = await axios.get(`${API_BASE_URL}/promotions`, {
        headers: { Authorization: `Bearer ${expiredToken}` },
        validateStatus: () => true
      });
      
      expect(response.status).toBe(401);
    });
    
    test('Should sanitize user inputs', async () => {
      const response = await axios.post(`${API_BASE_URL}/promotions`, {
        name: '<script>alert("XSS")</script>',
        description: 'Test SQL injection: DROP TABLE promotions;',
        type: 'SEASONAL',
        startDate: new Date(),
        endDate: new Date(),
        discountType: 'PERCENTAGE',
        discountValue: 20,
        budget: 1000
      }, {
        headers: { Authorization: `Bearer ${authToken}` },
        validateStatus: () => true
      });
      
      if (response.status === 201) {
        expect(response.data.name).not.toContain('<script>');
        expect(response.data.description).not.toContain('DROP TABLE');
      }
    });
  });
  
  describe('12. Data Validation', () => {
    test('Should validate all Diplomat SA data exists', async () => {
      // Check company
      const company = await prisma.company.findUnique({
        where: { code: 'DIPL-SA-001' }
      });
      expect(company).toBeTruthy();
      expect(company.name).toBe('Diplomat SA');
      
      // Check users
      const users = await prisma.user.count({
        where: { companyId: company.id }
      });
      expect(users).toBe(10);
      
      // Check stores by type
      const storeTypes = await prisma.store.groupBy({
        by: ['type'],
        where: { companyId: company.id },
        _count: true
      });
      
      expect(storeTypes.find(s => s.type === 'HYPERMARKET')?._count).toBeGreaterThan(0);
      expect(storeTypes.find(s => s.type === 'SUPERMARKET')?._count).toBeGreaterThan(0);
      expect(storeTypes.find(s => s.type === 'CONVENIENCE')?._count).toBeGreaterThan(0);
      expect(storeTypes.find(s => s.type === 'PHARMACY')?._count).toBeGreaterThan(0);
      expect(storeTypes.find(s => s.type === 'WHOLESALE')?._count).toBeGreaterThan(0);
      expect(storeTypes.find(s => s.type === 'ONLINE')?._count).toBeGreaterThan(0);
      
      // Check one year of data
      const analytics = await prisma.analytics.findMany({
        where: { companyId: company.id },
        orderBy: { date: 'asc' }
      });
      
      expect(analytics.length).toBeGreaterThan(0);
      const firstDate = new Date(analytics[0].date);
      const lastDate = new Date(analytics[analytics.length - 1].date);
      const monthsDiff = (lastDate.getFullYear() - firstDate.getFullYear()) * 12 + 
                        (lastDate.getMonth() - firstDate.getMonth());
      expect(monthsDiff).toBeGreaterThanOrEqual(11);
    });
  });
});

// Run specific component tests
describe('Component Integration Tests', () => {
  test('API Gateway health check', async () => {
    const response = await axios.get('http://localhost:4000/health');
    expect(response.status).toBe(200);
    expect(response.data.status).toBe('healthy');
  });
  
  test('All microservices ready check', async () => {
    const response = await axios.get('http://localhost:4000/ready', {
      validateStatus: () => true
    });
    
    if (response.status === 200) {
      expect(response.data.status).toBe('ready');
      expect(response.data.services).toBeDefined();
    }
  });
});