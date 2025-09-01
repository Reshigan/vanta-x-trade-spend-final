import { PrismaClient } from '@prisma/client';
import { faker } from '@faker-js/faker';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

// Store types for Diplomat SA
const STORE_TYPES = [
  'HYPERMARKET',
  'SUPERMARKET', 
  'CONVENIENCE',
  'PHARMACY',
  'WHOLESALE',
  'ONLINE'
];

// Product categories
const CATEGORIES = [
  'Beverages',
  'Dairy Products',
  'Snacks & Confectionery',
  'Personal Care',
  'Home Care',
  'Health & Wellness',
  'Baby Care',
  'Pet Care'
];

// Promotion types
const PROMOTION_TYPES = [
  'PRICE_REDUCTION',
  'BOGO',
  'BUNDLE',
  'LOYALTY',
  'SEASONAL',
  'CLEARANCE',
  'NEW_PRODUCT',
  'CROSS_SELL'
];

async function seedDiplomatData() {
  console.log('🌱 Starting Diplomat SA data seeding...');
  
  try {
    // 1. Create Diplomat SA company
    const diplomatSA = await prisma.company.create({
      data: {
        name: 'Diplomat SA',
        code: 'DIPL-SA-001',
        domain: 'diplomat.sa',
        email: 'admin@diplomat.sa',
        phone: '+966 11 123 4567',
        address: 'King Fahd Road, Riyadh 11564, Saudi Arabia',
        licenseType: 'ENTERPRISE',
        licenseCount: 10,
        licenseExpiresAt: new Date('2025-12-31'),
        settings: {
          currency: 'SAR',
          timezone: 'Asia/Riyadh',
          fiscalYearStart: 1,
          language: 'en'
        }
      }
    });
    
    console.log('✅ Created Diplomat SA company');
    
    // 2. Create user roles and licenses
    const roles = [
      { email: 'admin@diplomat.sa', role: 'ADMIN', firstName: 'System', lastName: 'Administrator' },
      { email: 'trade.manager@diplomat.sa', role: 'MANAGER', firstName: 'Ahmed', lastName: 'Al-Rashid' },
      { email: 'category.manager1@diplomat.sa', role: 'MANAGER', firstName: 'Fatima', lastName: 'Al-Zahrani' },
      { email: 'category.manager2@diplomat.sa', role: 'MANAGER', firstName: 'Mohammed', lastName: 'Al-Qahtani' },
      { email: 'analyst1@diplomat.sa', role: 'ANALYST', firstName: 'Sara', lastName: 'Al-Mutairi' },
      { email: 'analyst2@diplomat.sa', role: 'ANALYST', firstName: 'Omar', lastName: 'Al-Harbi' },
      { email: 'finance.manager@diplomat.sa', role: 'MANAGER', firstName: 'Khalid', lastName: 'Al-Dosari' },
      { email: 'sales.rep1@diplomat.sa', role: 'USER', firstName: 'Nora', lastName: 'Al-Otaibi' },
      { email: 'sales.rep2@diplomat.sa', role: 'USER', firstName: 'Abdullah', lastName: 'Al-Shehri' },
      { email: 'viewer@diplomat.sa', role: 'VIEWER', firstName: 'Layla', lastName: 'Al-Ghamdi' }
    ];
    
    const hashedPassword = await bcrypt.hash('DiplomatSA2024!', 10);
    
    for (const userData of roles) {
      await prisma.user.create({
        data: {
          ...userData,
          password: hashedPassword,
          companyId: diplomatSA.id,
          isActive: true,
          lastLoginAt: faker.date.recent({ days: 7 })
        }
      });
    }
    
    console.log('✅ Created 10 user licenses');
    
    // 3. Create product categories
    const categories = [];
    for (const categoryName of CATEGORIES) {
      const category = await prisma.category.create({
        data: {
          name: categoryName,
          code: categoryName.toUpperCase().replace(/\s+/g, '_'),
          description: `${categoryName} product category`,
          companyId: diplomatSA.id
        }
      });
      categories.push(category);
    }
    
    console.log('✅ Created product categories');
    
    // 4. Create products (20 per category)
    const products = [];
    for (const category of categories) {
      for (let i = 0; i < 20; i++) {
        const product = await prisma.product.create({
          data: {
            sku: `${category.code}-${faker.string.alphanumeric(6).toUpperCase()}`,
            name: faker.commerce.productName(),
            description: faker.commerce.productDescription(),
            barcode: faker.string.numeric(13),
            unitPrice: parseFloat(faker.commerce.price({ min: 5, max: 500 })),
            categoryId: category.id,
            companyId: diplomatSA.id,
            isActive: true
          }
        });
        products.push(product);
      }
    }
    
    console.log(`✅ Created ${products.length} products`);
    
    // 5. Create stores across different types
    const stores = [];
    let storeCount = 0;
    
    for (const storeType of STORE_TYPES) {
      const numStores = storeType === 'HYPERMARKET' ? 5 : 
                       storeType === 'SUPERMARKET' ? 15 :
                       storeType === 'CONVENIENCE' ? 30 :
                       storeType === 'PHARMACY' ? 20 :
                       storeType === 'WHOLESALE' ? 8 : 10;
      
      for (let i = 0; i < numStores; i++) {
        const store = await prisma.store.create({
          data: {
            code: `${storeType.substring(0, 3)}-${String(++storeCount).padStart(3, '0')}`,
            name: `${faker.company.name()} ${storeType}`,
            type: storeType,
            address: faker.location.streetAddress(),
            city: faker.helpers.arrayElement(['Riyadh', 'Jeddah', 'Dammam', 'Mecca', 'Medina']),
            region: faker.helpers.arrayElement(['Central', 'Western', 'Eastern', 'Northern', 'Southern']),
            contactPerson: faker.person.fullName(),
            contactEmail: faker.internet.email(),
            contactPhone: faker.phone.number('+966 5# ### ####'),
            companyId: diplomatSA.id,
            isActive: true
          }
        });
        stores.push(store);
      }
    }
    
    console.log(`✅ Created ${stores.length} stores across all types`);
    
    // 6. Generate one year of historical data
    const startDate = new Date();
    startDate.setFullYear(startDate.getFullYear() - 1);
    
    // Create promotions
    const promotions = [];
    for (let month = 0; month < 12; month++) {
      for (let i = 0; i < 10; i++) {
        const promotionStart = new Date(startDate);
        promotionStart.setMonth(startDate.getMonth() + month);
        promotionStart.setDate(faker.number.int({ min: 1, max: 25 }));
        
        const promotionEnd = new Date(promotionStart);
        promotionEnd.setDate(promotionStart.getDate() + faker.number.int({ min: 7, max: 30 }));
        
        const budget = faker.number.int({ min: 50000, max: 500000 });
        const actualSpend = budget * faker.number.float({ min: 0.7, max: 1.1 });
        const targetRevenue = budget * faker.number.float({ min: 3, max: 5 });
        const actualRevenue = targetRevenue * faker.number.float({ min: 0.8, max: 1.2 });
        
        const promotion = await prisma.promotion.create({
          data: {
            code: `PROMO-${new Date().getFullYear()}-${String(promotions.length + 1).padStart(4, '0')}`,
            name: faker.commerce.productAdjective() + ' ' + faker.helpers.arrayElement(['Sale', 'Offer', 'Deal', 'Discount']),
            description: faker.lorem.paragraph(),
            type: faker.helpers.arrayElement(PROMOTION_TYPES),
            status: promotionEnd < new Date() ? 'COMPLETED' : 
                   promotionStart < new Date() ? 'ACTIVE' : 'APPROVED',
            startDate: promotionStart,
            endDate: promotionEnd,
            discountType: faker.helpers.arrayElement(['PERCENTAGE', 'FIXED_AMOUNT']),
            discountValue: faker.number.int({ min: 5, max: 50 }),
            budget,
            actualSpend,
            targetRevenue,
            actualRevenue,
            categoryId: faker.helpers.arrayElement(categories).id,
            companyId: diplomatSA.id,
            createdBy: faker.helpers.arrayElement(roles.filter(r => r.role !== 'VIEWER')).email
          }
        });
        
        // Link promotion to stores
        const selectedStores = faker.helpers.arrayElements(stores, { min: 5, max: 20 });
        for (const store of selectedStores) {
          await prisma.promotionStore.create({
            data: {
              promotionId: promotion.id,
              storeId: store.id
            }
          });
        }
        
        // Link promotion to products
        const categoryProducts = products.filter(p => p.categoryId === promotion.categoryId);
        const selectedProducts = faker.helpers.arrayElements(categoryProducts, { min: 3, max: 10 });
        for (const product of selectedProducts) {
          await prisma.promotionProduct.create({
            data: {
              promotionId: promotion.id,
              productId: product.id
            }
          });
        }
        
        promotions.push(promotion);
      }
    }
    
    console.log(`✅ Created ${promotions.length} promotions with store and product associations`);
    
    // 7. Generate trade spend records
    const tradeSpends = [];
    for (const promotion of promotions) {
      if (promotion.status === 'COMPLETED' || promotion.status === 'ACTIVE') {
        const linkedStores = await prisma.promotionStore.findMany({
          where: { promotionId: promotion.id },
          include: { store: true }
        });
        
        for (const { store } of linkedStores) {
          const amount = promotion.actualSpend / linkedStores.length;
          const tradeSpend = await prisma.tradeSpend.create({
            data: {
              promotionId: promotion.id,
              storeId: store.id,
              amount: amount * faker.number.float({ min: 0.8, max: 1.2 }),
              type: faker.helpers.arrayElement(['REBATE', 'DISCOUNT', 'LISTING_FEE', 'DISPLAY_FEE']),
              status: promotion.status === 'COMPLETED' ? 'PAID' : 'APPROVED',
              date: faker.date.between({ from: promotion.startDate, to: promotion.endDate }),
              companyId: diplomatSA.id
            }
          });
          tradeSpends.push(tradeSpend);
        }
      }
    }
    
    console.log(`✅ Created ${tradeSpends.length} trade spend records`);
    
    // 8. Generate analytics data
    for (const store of stores) {
      for (let month = 0; month < 12; month++) {
        const date = new Date(startDate);
        date.setMonth(startDate.getMonth() + month);
        
        await prisma.analytics.create({
          data: {
            date,
            storeId: store.id,
            revenue: faker.number.float({ min: 100000, max: 1000000 }),
            tradeSpend: faker.number.float({ min: 10000, max: 100000 }),
            volume: faker.number.int({ min: 1000, max: 10000 }),
            roi: faker.number.float({ min: 2, max: 5 }),
            incrementalRevenue: faker.number.float({ min: 50000, max: 200000 }),
            companyId: diplomatSA.id
          }
        });
      }
    }
    
    console.log('✅ Created analytics data for all stores');
    
    // 9. Generate AI insights
    const insights = [
      {
        type: 'OPTIMIZATION',
        title: 'Optimize Beverage Promotions in Hypermarkets',
        description: 'AI analysis suggests reducing discount depth from 25% to 20% in hypermarkets can improve ROI by 15% without significant volume impact.',
        impact: 'HIGH',
        confidence: 0.89,
        recommendations: ['Adjust discount levels', 'Focus on bundle offers', 'Increase promotion frequency']
      },
      {
        type: 'ANOMALY',
        title: 'Unusual Spending Pattern Detected in Eastern Region',
        description: 'Trade spend in Eastern region pharmacies is 35% higher than historical average with no corresponding revenue increase.',
        impact: 'MEDIUM',
        confidence: 0.92,
        recommendations: ['Review pharmacy contracts', 'Audit recent promotions', 'Investigate competitor activity']
      },
      {
        type: 'PREDICTION',
        title: 'Q4 Revenue Forecast Shows Strong Growth',
        description: 'Machine learning models predict 18% revenue growth in Q4 based on current promotion calendar and historical patterns.',
        impact: 'HIGH',
        confidence: 0.85,
        recommendations: ['Maintain current strategy', 'Ensure inventory availability', 'Prepare for increased demand']
      }
    ];
    
    for (const insight of insights) {
      await prisma.aIInsight.create({
        data: {
          ...insight,
          metadata: {
            model: 'ensemble_v2.1',
            features: ['historical_data', 'seasonality', 'competitor_analysis'],
            generatedAt: new Date()
          },
          companyId: diplomatSA.id
        }
      });
    }
    
    console.log('✅ Created AI insights');
    
    // 10. Create notification preferences
    const users = await prisma.user.findMany({
      where: { companyId: diplomatSA.id }
    });
    
    for (const user of users) {
      await prisma.notificationPreference.create({
        data: {
          userId: user.id,
          email: true,
          push: true,
          promotionAlerts: user.role !== 'VIEWER',
          spendAlerts: ['ADMIN', 'MANAGER'].includes(user.role),
          performanceReports: ['ADMIN', 'MANAGER', 'ANALYST'].includes(user.role),
          systemAlerts: user.role === 'ADMIN'
        }
      });
    }
    
    console.log('✅ Created notification preferences');
    
    console.log('\n🎉 Diplomat SA data seeding completed successfully!');
    console.log(`
    Summary:
    - Company: Diplomat SA
    - Users: 10 (with different roles)
    - Categories: ${categories.length}
    - Products: ${products.length}
    - Stores: ${stores.length} (across all types)
    - Promotions: ${promotions.length}
    - Trade Spends: ${tradeSpends.length}
    - 12 months of historical data
    - AI insights and predictions
    `);
    
  } catch (error) {
    console.error('❌ Error seeding data:', error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

// Run the seed function
seedDiplomatData()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });