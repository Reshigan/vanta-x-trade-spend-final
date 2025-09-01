import axios from 'axios';
import { v4 as uuidv4 } from 'uuid';
import { addDays, subDays, startOfYear, endOfYear, format } from 'date-fns';

// Configuration
const API_BASE_URL = process.env.API_BASE_URL || 'http://localhost:3000/api/v1';
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || 'your-admin-token';

// Test data configuration
const COMPANY_DATA = {
  name: 'Diplomat SA',
  code: 'DIPSA',
  registrationNumber: '2010/123456/07',
  taxNumber: 'ZA1234567890',
  type: 'ENTERPRISE',
  industry: 'Retail & Distribution',
  website: 'https://www.diplomatsa.com',
  email: 'info@diplomatsa.com',
  phone: '+27 11 123 4567',
  address: {
    street: '123 Main Road',
    city: 'Johannesburg',
    state: 'Gauteng',
    postalCode: '2001',
    country: 'South Africa',
  },
  settings: {
    currency: 'ZAR',
    timezone: 'Africa/Johannesburg',
    fiscalYearStart: 'March',
    dateFormat: 'DD/MM/YYYY',
  },
};

const USERS = [
  { name: 'John Smith', email: 'john.smith@diplomatsa.com', role: 'CEO', department: 'Executive' },
  { name: 'Sarah Johnson', email: 'sarah.johnson@diplomatsa.com', role: 'Trade Marketing Director', department: 'Trade Marketing' },
  { name: 'Michael Chen', email: 'michael.chen@diplomatsa.com', role: 'Trade Marketing Manager', department: 'Trade Marketing' },
  { name: 'Emily Davis', email: 'emily.davis@diplomatsa.com', role: 'Category Manager', department: 'Category Management' },
  { name: 'Robert Wilson', email: 'robert.wilson@diplomatsa.com', role: 'Sales Director', department: 'Sales' },
  { name: 'Lisa Anderson', email: 'lisa.anderson@diplomatsa.com', role: 'Finance Manager', department: 'Finance' },
  { name: 'David Martinez', email: 'david.martinez@diplomatsa.com', role: 'Data Analyst', department: 'Analytics' },
  { name: 'Jennifer Taylor', email: 'jennifer.taylor@diplomatsa.com', role: 'Promotion Coordinator', department: 'Trade Marketing' },
  { name: 'William Brown', email: 'william.brown@diplomatsa.com', role: 'Store Operations Manager', department: 'Operations' },
  { name: 'Maria Garcia', email: 'maria.garcia@diplomatsa.com', role: 'Business Intelligence Analyst', department: 'Analytics' },
];

const STORE_TYPES = ['Hypermarket', 'Supermarket', 'Convenience', 'Wholesale'];
const REGIONS = ['Gauteng', 'Western Cape', 'KwaZulu-Natal', 'Eastern Cape', 'Mpumalanga', 'Limpopo', 'Free State', 'North West', 'Northern Cape'];
const PRODUCT_CATEGORIES = ['Beverages', 'Snacks', 'Dairy', 'Bakery', 'Frozen Foods', 'Personal Care', 'Household', 'Health & Beauty'];
const BRANDS = ['CocaCola', 'Pepsi', 'Nestle', 'Unilever', 'P&G', 'Kelloggs', 'Cadbury', 'Lays'];

// API client with authentication
const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Authorization': `Bearer ${ADMIN_TOKEN}`,
    'Content-Type': 'application/json',
  },
});

// Helper functions
function getRandomElement<T>(array: T[]): T {
  return array[Math.floor(Math.random() * array.length)];
}

function getRandomElements<T>(array: T[], count: number): T[] {
  const shuffled = [...array].sort(() => 0.5 - Math.random());
  return shuffled.slice(0, count);
}

function generateRandomNumber(min: number, max: number): number {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

// Data generation functions
async function createCompany() {
  try {
    console.log('Creating company: Diplomat SA...');
    const response = await apiClient.post('/companies', COMPANY_DATA);
    console.log('✅ Company created:', response.data.name);
    return response.data;
  } catch (error: any) {
    console.error('❌ Failed to create company:', error.response?.data || error.message);
    throw error;
  }
}

async function createUsers(companyId: string) {
  console.log('Creating users...');
  const createdUsers = [];
  
  for (const userData of USERS) {
    try {
      const [firstName, lastName] = userData.name.split(' ');
      const response = await apiClient.post('/users', {
        email: userData.email,
        firstName,
        lastName,
        password: 'DiplomatSA2025!',
        companyId,
        role: userData.role,
        department: userData.department,
      });
      createdUsers.push(response.data);
      console.log(`✅ User created: ${userData.name}`);
    } catch (error: any) {
      console.error(`❌ Failed to create user ${userData.name}:`, error.response?.data || error.message);
    }
  }
  
  return createdUsers;
}

async function createStores(companyId: string) {
  console.log('Creating stores...');
  const stores = [];
  let storeIndex = 1;
  
  for (const region of REGIONS) {
    for (const storeType of STORE_TYPES) {
      try {
        const response = await apiClient.post('/stores', {
          code: `ST${String(storeIndex).padStart(4, '0')}`,
          name: `${region} ${storeType} ${storeIndex}`,
          type: storeType,
          companyId,
          region,
          address: {
            street: `${storeIndex} Retail Avenue`,
            city: `${region} City`,
            province: region,
            postalCode: String(1000 + storeIndex),
            country: 'South Africa',
          },
          size: storeType === 'Hypermarket' ? 5000 : storeType === 'Supermarket' ? 2000 : 500,
        });
        stores.push(response.data);
        storeIndex++;
      } catch (error: any) {
        console.error(`❌ Failed to create store:`, error.response?.data || error.message);
      }
    }
  }
  
  console.log(`✅ Created ${stores.length} stores`);
  return stores;
}

async function createProducts(companyId: string) {
  console.log('Creating products...');
  const products = [];
  
  for (const category of PRODUCT_CATEGORIES) {
    for (let i = 0; i < 10; i++) {
      const brand = getRandomElement(BRANDS);
      try {
        const response = await apiClient.post('/products', {
          code: `PRD${category.substring(0, 3).toUpperCase()}${String(i + 1).padStart(3, '0')}`,
          barcode: `600${String(Math.floor(Math.random() * 1000000000)).padStart(9, '0')}`,
          name: `${brand} ${category} Product ${i + 1}`,
          brand,
          category,
          subCategory: `${category} Sub ${i % 3 + 1}`,
          unitSize: getRandomElement(['250ml', '500ml', '1L', '100g', '250g', '500g', '1kg']),
          costPrice: generateRandomNumber(10, 100),
          sellingPrice: generateRandomNumber(15, 150),
          companyId,
        });
        products.push(response.data);
      } catch (error: any) {
        console.error(`❌ Failed to create product:`, error.response?.data || error.message);
      }
    }
  }
  
  console.log(`✅ Created ${products.length} products`);
  return products;
}

async function createPromotionsAndTradeSpend(companyId: string, stores: any[], products: any[]) {
  console.log('Creating promotions and trade spend data...');
  const promotions = [];
  const startDate = startOfYear(new Date());
  
  for (let month = 0; month < 12; month++) {
    for (let i = 0; i < 5; i++) {
      const promotionStartDate = new Date(startDate);
      promotionStartDate.setMonth(month);
      promotionStartDate.setDate(generateRandomNumber(1, 15));
      
      const promotionEndDate = new Date(promotionStartDate);
      promotionEndDate.setDate(promotionStartDate.getDate() + generateRandomNumber(7, 21));
      
      const selectedProducts = getRandomElements(products, generateRandomNumber(5, 15));
      const selectedStores = getRandomElements(stores, generateRandomNumber(10, 30));
      
      try {
        const promotionData = {
          code: `PROMO-2025-${String(month + 1).padStart(2, '0')}${String(i + 1).padStart(2, '0')}`,
          name: `${getRandomElement(['Summer', 'Winter', 'Spring', 'Autumn'])} ${getRandomElement(['Sale', 'Special', 'Promotion', 'Deal'])} ${month + 1}/${i + 1}`,
          type: getRandomElement(['PRICE_REDUCTION', 'BOGO', 'VOLUME_DISCOUNT', 'BUNDLE']),
          startDate: promotionStartDate.toISOString(),
          endDate: promotionEndDate.toISOString(),
          companyId,
          discountType: getRandomElement(['PERCENTAGE', 'FIXED_AMOUNT']),
          discountValue: generateRandomNumber(10, 30),
          budget: generateRandomNumber(50000, 200000),
          productIds: selectedProducts.map(p => p.id),
          storeIds: selectedStores.map(s => s.id),
        };
        
        const response = await apiClient.post('/promotions', promotionData);
        promotions.push(response.data);
        
        // Create associated trade spend
        const tradeSpendData = {
          promotionId: response.data.id,
          companyId,
          period: {
            year: 2025,
            month: month + 1,
            quarter: Math.floor(month / 3) + 1,
          },
          plannedAmount: promotionData.budget,
          actualAmount: promotionEndDate < new Date() ? generateRandomNumber(40000, 180000) : 0,
          currency: 'ZAR',
        };
        
        await apiClient.post('/trade-spend', tradeSpendData);
        
      } catch (error: any) {
        console.error(`❌ Failed to create promotion:`, error.response?.data || error.message);
      }
    }
  }
  
  console.log(`✅ Created ${promotions.length} promotions with trade spend data`);
  return promotions;
}

async function generateAnalyticsData(companyId: string, stores: any[], products: any[], promotions: any[]) {
  console.log('Generating analytics data for the past year...');
  const startDate = startOfYear(new Date());
  const endDate = new Date();
  let recordCount = 0;
  
  // Sample subset for performance
  const sampleStores = stores.slice(0, 20);
  const sampleProducts = products.slice(0, 30);
  
  for (const store of sampleStores) {
    for (const product of sampleProducts) {
      const analyticsData = [];
      
      for (let date = new Date(startDate); date <= endDate; date.setDate(date.getDate() + 1)) {
        const isPromotionDay = promotions.some((p: any) => 
          new Date(p.startDate) <= date && 
          new Date(p.endDate) >= date &&
          p.productIds?.includes(product.id) &&
          p.storeIds?.includes(store.id)
        );
        
        const baselineUnits = generateRandomNumber(10, 100);
        const upliftMultiplier = isPromotionDay ? 1.2 + Math.random() * 0.8 : 1;
        
        analyticsData.push({
          date: format(date, 'yyyy-MM-dd'),
          storeId: store.id,
          productId: product.id,
          companyId,
          units: Math.round(baselineUnits * upliftMultiplier),
          revenue: Math.round(baselineUnits * upliftMultiplier * product.sellingPrice),
          transactions: generateRandomNumber(5, 25),
          isPromotion: isPromotionDay,
        });
      }
      
      // Batch insert analytics data
      try {
        await apiClient.post('/analytics/batch', { data: analyticsData });
        recordCount += analyticsData.length;
      } catch (error: any) {
        console.error(`❌ Failed to create analytics data:`, error.response?.data || error.message);
      }
    }
  }
  
  console.log(`✅ Generated ${recordCount} analytics records`);
}

// Main execution function
async function generateTestData() {
  try {
    console.log('🚀 Starting test data generation for Diplomat SA...\n');
    
    // Create company
    const company = await createCompany();
    
    // Create users
    const users = await createUsers(company.id);
    
    // Create stores
    const stores = await createStores(company.id);
    
    // Create products
    const products = await createProducts(company.id);
    
    // Create promotions and trade spend
    const promotions = await createPromotionsAndTradeSpend(company.id, stores, products);
    
    // Generate analytics data
    await generateAnalyticsData(company.id, stores, products, promotions);
    
    console.log('\n🎉 Test data generation completed successfully!');
    console.log('\n📊 Summary:');
    console.log(`- Company: ${company.name}`);
    console.log(`- Users: ${users.length}`);
    console.log(`- Stores: ${stores.length}`);
    console.log(`- Products: ${products.length}`);
    console.log(`- Promotions: ${promotions.length}`);
    console.log('\n🔐 Default password for all users: DiplomatSA2025!');
    console.log('\n✨ The system is ready for testing!');
    
  } catch (error) {
    console.error('\n❌ Test data generation failed:', error);
    process.exit(1);
  }
}

// Run the data generation
if (require.main === module) {
  generateTestData()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

export { generateTestData };