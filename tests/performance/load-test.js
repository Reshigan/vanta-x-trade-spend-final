import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');

// Test configuration
export const options = {
  stages: [
    { duration: '2m', target: 50 },   // Ramp up to 50 users
    { duration: '5m', target: 50 },   // Stay at 50 users
    { duration: '2m', target: 100 },  // Ramp up to 100 users
    { duration: '5m', target: 100 },  // Stay at 100 users
    { duration: '2m', target: 200 },  // Ramp up to 200 users
    { duration: '5m', target: 200 },  // Stay at 200 users
    { duration: '5m', target: 0 },    // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests must complete below 500ms
    errors: ['rate<0.1'],             // Error rate must be below 10%
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';
const API_TOKEN = __ENV.API_TOKEN || 'test-token';

// Helper function to make authenticated requests
function makeRequest(method, endpoint, payload = null) {
  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${API_TOKEN}`,
    },
  };

  let response;
  if (method === 'GET') {
    response = http.get(`${BASE_URL}${endpoint}`, params);
  } else if (method === 'POST') {
    response = http.post(`${BASE_URL}${endpoint}`, JSON.stringify(payload), params);
  }

  // Check response
  const success = check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });

  errorRate.add(!success);
  return response;
}

// Test scenarios
export default function () {
  // Scenario 1: Dashboard Load
  makeRequest('GET', '/api/v1/dashboard/summary');
  sleep(1);

  // Scenario 2: Trade Spend Optimization
  const optimizationPayload = {
    category: 'Beverages',
    storeType: 'Supermarket',
    discountType: 'PERCENTAGE',
    discountValue: 15,
    duration: 14,
    seasonality: 0.7,
  };
  makeRequest('POST', '/api/v1/ai/optimize/trade-spend', optimizationPayload);
  sleep(2);

  // Scenario 3: Get Promotions List
  makeRequest('GET', '/api/v1/promotions?page=1&limit=20');
  sleep(1);

  // Scenario 4: Anomaly Detection
  const anomalyData = {
    data: [
      {
        timestamp: new Date().toISOString(),
        storeId: 'ST001',
        productId: 'PRD001',
        metric: 'revenue',
        value: 15000,
        expectedValue: 12000,
      },
    ],
  };
  makeRequest('POST', '/api/v1/ai/anomaly/detect', anomalyData);
  sleep(1);

  // Scenario 5: Predictive Analytics
  const historicalData = Array.from({ length: 30 }, (_, i) => ({
    timestamp: new Date(Date.now() - (30 - i) * 24 * 60 * 60 * 1000).toISOString(),
    value: 10000 + Math.random() * 5000,
  }));

  const predictionPayload = {
    historicalData,
    steps: 7,
    options: {
      includeConfidenceInterval: true,
      model: 'ensemble',
    },
  };
  makeRequest('POST', '/api/v1/ai/predict', predictionPayload);
  sleep(2);

  // Scenario 6: Chatbot Interaction
  const sessionResponse = makeRequest('POST', '/api/v1/chatbot/sessions/start', {
    userId: `user-${__VU}`,
    companyId: 'test-company',
    userData: {
      name: `Test User ${__VU}`,
      role: 'Manager',
      department: 'Trade Marketing',
    },
  });

  if (sessionResponse.status === 200) {
    const sessionId = JSON.parse(sessionResponse.body).sessionId;
    
    makeRequest('POST', '/api/v1/chatbot/message', {
      sessionId,
      message: 'What is the optimal trade spend for my next promotion?',
    });
    sleep(1);
  }

  // Scenario 7: Data Export
  makeRequest('GET', '/api/v1/export/trade-spend?format=excel&dateRange=last30days');
  sleep(2);

  // Scenario 8: Real-time Analytics
  makeRequest('GET', '/api/v1/analytics/real-time');
  sleep(1);
}

// Stress test scenario (run with: k6 run --env SCENARIO=stress load-test.js)
export function stressTest() {
  const requests = [
    () => makeRequest('GET', '/api/v1/dashboard/summary'),
    () => makeRequest('GET', '/api/v1/promotions?page=1&limit=50'),
    () => makeRequest('GET', '/api/v1/analytics/performance'),
    () => makeRequest('POST', '/api/v1/ai/insights', { companyId: 'test', timeRange: 'last7days' }),
  ];

  // Execute random request
  const randomRequest = requests[Math.floor(Math.random() * requests.length)];
  randomRequest();
  
  // Minimal sleep for stress testing
  sleep(0.1);
}

// Spike test scenario
export function spikeTest() {
  // Simulate sudden traffic spike
  for (let i = 0; i < 10; i++) {
    makeRequest('GET', '/api/v1/dashboard/summary');
  }
  sleep(5);
}

// Soak test configuration (long-running test)
export const soakTestOptions = {
  stages: [
    { duration: '5m', target: 100 },   // Ramp up
    { duration: '4h', target: 100 },   // Stay at 100 users for 4 hours
    { duration: '5m', target: 0 },     // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<1000'], // More relaxed for soak test
    errors: ['rate<0.05'],             // Stricter error rate for soak test
  },
};