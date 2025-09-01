import { chromium, Browser, Page } from 'playwright';

describe('Trade Spend Management E2E Workflow', () => {
  let browser: Browser;
  let page: Page;
  const baseURL = process.env.BASE_URL || 'http://localhost:3000';

  beforeAll(async () => {
    browser = await chromium.launch({
      headless: process.env.HEADLESS !== 'false',
    });
  });

  afterAll(async () => {
    await browser.close();
  });

  beforeEach(async () => {
    page = await browser.newPage();
  });

  afterEach(async () => {
    await page.close();
  });

  describe('Complete Trade Spend Workflow', () => {
    it('should complete full trade spend optimization workflow', async () => {
      // 1. Login with Microsoft 365 SSO
      await page.goto(`${baseURL}/login`);
      await page.click('[data-testid="sso-microsoft-button"]');
      
      // Handle Microsoft login (in test environment, this would be mocked)
      await page.fill('[data-testid="email-input"]', 'sarah.johnson@diplomatsa.com');
      await page.fill('[data-testid="password-input"]', 'DiplomatSA2025!');
      await page.click('[data-testid="login-submit"]');
      
      // Wait for dashboard
      await page.waitForSelector('[data-testid="dashboard"]', { timeout: 10000 });
      
      // 2. Navigate to Trade Spend Management
      await page.click('[data-testid="nav-trade-spend"]');
      await page.waitForSelector('[data-testid="trade-spend-dashboard"]');
      
      // 3. Create new promotion
      await page.click('[data-testid="create-promotion-button"]');
      await page.waitForSelector('[data-testid="promotion-form"]');
      
      // Fill promotion details
      await page.fill('[data-testid="promotion-name"]', 'Summer Beverages Campaign 2025');
      await page.selectOption('[data-testid="category-select"]', 'Beverages');
      await page.selectOption('[data-testid="store-type-select"]', 'Supermarket');
      await page.selectOption('[data-testid="discount-type-select"]', 'PERCENTAGE');
      await page.fill('[data-testid="discount-value"]', '15');
      await page.fill('[data-testid="duration"]', '14');
      
      // 4. Get AI optimization
      await page.click('[data-testid="optimize-button"]');
      await page.waitForSelector('[data-testid="optimization-results"]');
      
      // Verify optimization results
      const recommendedSpend = await page.textContent('[data-testid="recommended-spend"]');
      expect(recommendedSpend).toBeTruthy();
      expect(parseFloat(recommendedSpend!.replace(/[^0-9.-]+/g, ''))).toBeGreaterThan(0);
      
      const expectedROI = await page.textContent('[data-testid="expected-roi"]');
      expect(expectedROI).toBeTruthy();
      expect(parseFloat(expectedROI!.replace(/[^0-9.-]+/g, ''))).toBeGreaterThan(0);
      
      // 5. Accept optimization and save
      await page.click('[data-testid="accept-optimization"]');
      await page.click('[data-testid="save-promotion"]');
      
      // Wait for success message
      await page.waitForSelector('[data-testid="success-message"]');
      const successMessage = await page.textContent('[data-testid="success-message"]');
      expect(successMessage).toContain('Promotion created successfully');
      
      // 6. View in promotions list
      await page.click('[data-testid="view-promotions"]');
      await page.waitForSelector('[data-testid="promotions-list"]');
      
      // Verify promotion appears in list
      const promotionRow = await page.locator('[data-testid="promotion-row"]', {
        hasText: 'Summer Beverages Campaign 2025',
      });
      expect(await promotionRow.count()).toBe(1);
    });

    it('should handle anomaly detection workflow', async () => {
      // Assume already logged in
      await page.goto(`${baseURL}/dashboard`);
      
      // Navigate to Analytics
      await page.click('[data-testid="nav-analytics"]');
      await page.waitForSelector('[data-testid="analytics-dashboard"]');
      
      // Check anomaly alerts
      await page.click('[data-testid="anomaly-alerts"]');
      await page.waitForSelector('[data-testid="anomaly-list"]');
      
      // Click on critical anomaly
      const criticalAnomaly = await page.locator('[data-testid="anomaly-item"][data-severity="critical"]').first();
      if (await criticalAnomaly.count() > 0) {
        await criticalAnomaly.click();
        
        // View anomaly details
        await page.waitForSelector('[data-testid="anomaly-details"]');
        
        // Take action
        await page.click('[data-testid="investigate-anomaly"]');
        await page.waitForSelector('[data-testid="investigation-panel"]');
        
        // Add note
        await page.fill('[data-testid="investigation-note"]', 'Investigating negative revenue anomaly');
        await page.click('[data-testid="save-investigation"]');
        
        // Verify investigation saved
        await page.waitForSelector('[data-testid="investigation-saved"]');
      }
    });

    it('should use AI chatbot for assistance', async () => {
      // Assume already logged in
      await page.goto(`${baseURL}/dashboard`);
      
      // Open chatbot
      await page.click('[data-testid="chatbot-button"]');
      await page.waitForSelector('[data-testid="chatbot-window"]');
      
      // Send message
      await page.fill('[data-testid="chatbot-input"]', 'What are the top performing categories this month?');
      await page.click('[data-testid="chatbot-send"]');
      
      // Wait for response
      await page.waitForSelector('[data-testid="chatbot-response"]');
      const response = await page.textContent('[data-testid="chatbot-response"]');
      expect(response).toBeTruthy();
      expect(response!.length).toBeGreaterThan(0);
      
      // Click on suggested action
      const suggestedAction = await page.locator('[data-testid="chatbot-suggestion"]').first();
      if (await suggestedAction.count() > 0) {
        await suggestedAction.click();
        // Verify action executed
        await page.waitForSelector('[data-testid="action-result"]');
      }
    });
  });

  describe('Data Import Workflow', () => {
    it('should import data from Excel template', async () => {
      // Navigate to import section
      await page.goto(`${baseURL}/import`);
      
      // Download template
      await page.click('[data-testid="download-template-excel"]');
      
      // Upload filled template (in real test, would use actual file)
      const fileInput = await page.locator('[data-testid="file-upload-excel"]');
      await fileInput.setInputFiles('./test-data/trade-spend-template.xlsx');
      
      // Preview data
      await page.click('[data-testid="preview-import"]');
      await page.waitForSelector('[data-testid="import-preview-table"]');
      
      // Verify preview
      const previewRows = await page.locator('[data-testid="preview-row"]').count();
      expect(previewRows).toBeGreaterThan(0);
      
      // Confirm import
      await page.click('[data-testid="confirm-import"]');
      await page.waitForSelector('[data-testid="import-success"]');
      
      const importMessage = await page.textContent('[data-testid="import-success"]');
      expect(importMessage).toContain('successfully imported');
    });

    it('should connect to SAP system', async () => {
      // Navigate to integrations
      await page.goto(`${baseURL}/settings/integrations`);
      
      // Click SAP integration
      await page.click('[data-testid="sap-integration"]');
      await page.waitForSelector('[data-testid="sap-config-form"]');
      
      // Fill SAP connection details
      await page.fill('[data-testid="sap-host"]', 'sap.diplomatsa.com');
      await page.fill('[data-testid="sap-client"]', '100');
      await page.fill('[data-testid="sap-username"]', 'TRADE_USER');
      await page.fill('[data-testid="sap-password"]', 'SecurePass123!');
      await page.selectOption('[data-testid="sap-type"]', 'S4HANA');
      
      // Test connection
      await page.click('[data-testid="test-connection"]');
      await page.waitForSelector('[data-testid="connection-status"]');
      
      const connectionStatus = await page.textContent('[data-testid="connection-status"]');
      expect(connectionStatus).toContain('Connection successful');
      
      // Save configuration
      await page.click('[data-testid="save-sap-config"]');
      await page.waitForSelector('[data-testid="config-saved"]');
    });
  });

  describe('Responsive Design Tests', () => {
    const devices = [
      { name: 'Mobile', width: 375, height: 667 },
      { name: 'Tablet', width: 768, height: 1024 },
      { name: 'Desktop', width: 1920, height: 1080 },
    ];

    devices.forEach(device => {
      it(`should display correctly on ${device.name}`, async () => {
        await page.setViewportSize({ width: device.width, height: device.height });
        await page.goto(`${baseURL}/dashboard`);
        
        // Check navigation
        if (device.name === 'Mobile') {
          // Mobile should have hamburger menu
          await page.waitForSelector('[data-testid="mobile-menu-button"]');
          await page.click('[data-testid="mobile-menu-button"]');
          await page.waitForSelector('[data-testid="mobile-menu"]');
        } else {
          // Desktop and tablet should have regular nav
          await page.waitForSelector('[data-testid="desktop-nav"]');
        }
        
        // Check layout
        const mainContent = await page.locator('[data-testid="main-content"]');
        const contentBox = await mainContent.boundingBox();
        expect(contentBox).toBeTruthy();
        expect(contentBox!.width).toBeLessThanOrEqual(device.width);
        
        // Check responsive grid
        const gridItems = await page.locator('[data-testid="dashboard-grid-item"]').count();
        if (gridItems > 0) {
          const firstItem = await page.locator('[data-testid="dashboard-grid-item"]').first();
          const itemBox = await firstItem.boundingBox();
          expect(itemBox).toBeTruthy();
          
          if (device.name === 'Mobile') {
            // Items should stack on mobile
            expect(itemBox!.width).toBeGreaterThan(device.width * 0.8);
          }
        }
      });
    });
  });
});