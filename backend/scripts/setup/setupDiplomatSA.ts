import { PrismaClient } from '@prisma/client';
import { v4 as uuidv4 } from 'uuid';
import bcrypt from 'bcrypt';
import { addDays, subDays, startOfYear, endOfYear } from 'date-fns';

const prisma = new PrismaClient();

interface UserRole {
  name: string;
  email: string;
  role: string;
  department: string;
}

const DIPLOMAT_SA_USERS: UserRole[] = [
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

async function setupDiplomatSA() {
  try {
    console.log('🚀 Setting up Diplomat SA company and data...');

    // 1. Create Diplomat SA Company
    const company = await prisma.company.create({
      data: {
        id: uuidv4(),
        name: 'Diplomat SA',
        code: 'DIPSA',
        registrationNumber: '2010/123456/07',
        taxNumber: 'ZA1234567890',
        type: 'ENTERPRISE',
        status: 'ACTIVE',
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
          features: {
            tradeSpend: true,
            promotions: true,
            analytics: true,
            aiInsights: true,
            multiStore: true,
            sapIntegration: true,
            excelImport: true,
          },
        },
        metadata: {
          employeeCount: 5000,
          annualRevenue: 2500000000, // 2.5 billion ZAR
          foundedYear: 2010,
          description: 'Leading retail and distribution company in South Africa',
        },
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    });

    console.log('✅ Company created:', company.name);

    // 2. Create License for Diplomat SA
    const license = await prisma.license.create({
      data: {
        id: uuidv4(),
        companyId: company.id,
        type: 'ENTERPRISE',
        status: 'ACTIVE',
        userLimit: 10,
        startDate: new Date(),
        endDate: addDays(new Date(), 365), // 1 year license
        features: {
          modules: ['trade-spend', 'promotions', 'analytics', 'ai-insights', 'import-export'],
          storage: '1TB',
          apiCalls: 'unlimited',
          customReports: true,
          advancedAnalytics: true,
          aiChatbot: true,
          multiCompany: true,
        },
        billing: {
          plan: 'ENTERPRISE',
          amount: 50000, // Monthly
          currency: 'ZAR',
          billingCycle: 'MONTHLY',
        },
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    });

    console.log('✅ License created: Enterprise license for 10 users');

    // 3. Create Roles
    const roles = await Promise.all([
      prisma.role.create({
        data: {
          id: uuidv4(),
          name: 'CEO',
          description: 'Chief Executive Officer - Full system access',
          permissions: ['*'], // All permissions
          companyId: company.id,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      }),
      prisma.role.create({
        data: {
          id: uuidv4(),
          name: 'Trade Marketing Director',
          description: 'Director of Trade Marketing - Full trade marketing access',
          permissions: [
            'trade-spend:*',
            'promotions:*',
            'analytics:*',
            'reports:*',
            'users:read',
            'stores:*',
            'products:*',
          ],
          companyId: company.id,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      }),
      prisma.role.create({
        data: {
          id: uuidv4(),
          name: 'Trade Marketing Manager',
          description: 'Trade Marketing Manager - Manage promotions and spend',
          permissions: [
            'trade-spend:create',
            'trade-spend:read',
            'trade-spend:update',
            'promotions:*',
            'analytics:read',
            'reports:read',
            'stores:read',
            'products:read',
          ],
          companyId: company.id,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      }),
      prisma.role.create({
        data: {
          id: uuidv4(),
          name: 'Category Manager',
          description: 'Category Manager - Manage product categories',
          permissions: [
            'products:*',
            'categories:*',
            'promotions:read',
            'analytics:read',
            'reports:read',
          ],
          companyId: company.id,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      }),
      prisma.role.create({
        data: {
          id: uuidv4(),
          name: 'Sales Director',
          description: 'Sales Director - View sales and performance data',
          permissions: [
            'sales:*',
            'stores:*',
            'analytics:read',
            'reports:*',
            'promotions:read',
            'trade-spend:read',
          ],
          companyId: company.id,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      }),
      prisma.role.create({
        data: {
          id: uuidv4(),
          name: 'Finance Manager',
          description: 'Finance Manager - Financial oversight',
          permissions: [
            'finance:*',
            'trade-spend:read',
            'trade-spend:approve',
            'reports:*',
            'analytics:read',
          ],
          companyId: company.id,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      }),
      prisma.role.create({
        data: {
          id: uuidv4(),
          name: 'Data Analyst',
          description: 'Data Analyst - Analytics and reporting',
          permissions: [
            'analytics:*',
            'reports:*',
            'trade-spend:read',
            'promotions:read',
            'stores:read',
            'products:read',
          ],
          companyId: company.id,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      }),
      prisma.role.create({
        data: {
          id: uuidv4(),
          name: 'Promotion Coordinator',
          description: 'Promotion Coordinator - Coordinate promotional activities',
          permissions: [
            'promotions:create',
            'promotions:read',
            'promotions:update',
            'stores:read',
            'products:read',
            'reports:read',
          ],
          companyId: company.id,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      }),
      prisma.role.create({
        data: {
          id: uuidv4(),
          name: 'Store Operations Manager',
          description: 'Store Operations Manager - Manage store operations',
          permissions: [
            'stores:*',
            'promotions:read',
            'products:read',
            'analytics:read',
            'reports:read',
          ],
          companyId: company.id,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      }),
      prisma.role.create({
        data: {
          id: uuidv4(),
          name: 'Business Intelligence Analyst',
          description: 'BI Analyst - Advanced analytics and AI insights',
          permissions: [
            'analytics:*',
            'ai-insights:*',
            'reports:*',
            'trade-spend:read',
            'promotions:read',
            'stores:read',
            'products:read',
          ],
          companyId: company.id,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      }),
    ]);

    console.log('✅ Roles created:', roles.length);

    // 4. Create Users
    const hashedPassword = await bcrypt.hash('DiplomatSA2025!', 10);
    const users = await Promise.all(
      DIPLOMAT_SA_USERS.map(async (userData, index) => {
        const role = roles.find(r => r.name === userData.role);
        const [firstName, lastName] = userData.name.split(' ');
        
        return prisma.user.create({
          data: {
            id: uuidv4(),
            email: userData.email,
            firstName,
            lastName,
            displayName: userData.name,
            password: hashedPassword,
            status: 'ACTIVE',
            emailVerified: true,
            companyId: company.id,
            roleId: role?.id,
            department: userData.department,
            jobTitle: userData.role,
            phone: `+27 11 123 456${index}`,
            avatar: `https://ui-avatars.com/api/?name=${encodeURIComponent(userData.name)}&background=3B82F6&color=fff`,
            preferences: {
              theme: 'light',
              language: 'en',
              notifications: {
                email: true,
                push: true,
                sms: false,
              },
            },
            metadata: {
              employeeId: `EMP${String(index + 1).padStart(4, '0')}`,
              officeLocation: 'Johannesburg HQ',
              manager: index === 0 ? null : DIPLOMAT_SA_USERS[0].name,
            },
            createdAt: new Date(),
            updatedAt: new Date(),
          },
        });
      })
    );

    console.log('✅ Users created:', users.length);

    // 5. Create Stores
    const stores = [];
    let storeIndex = 1;
    
    for (const region of REGIONS) {
      for (const storeType of STORE_TYPES) {
        const store = await prisma.store.create({
          data: {
            id: uuidv4(),
            code: `ST${String(storeIndex).padStart(4, '0')}`,
            name: `${region} ${storeType} ${storeIndex}`,
            type: storeType,
            companyId: company.id,
            region,
            province: region,
            city: `${region} City`,
            address: {
              street: `${storeIndex} Retail Avenue`,
              city: `${region} City`,
              province: region,
              postalCode: String(1000 + storeIndex),
              country: 'South Africa',
            },
            contact: {
              manager: `Manager ${storeIndex}`,
              phone: `+27 11 ${String(100 + storeIndex).padStart(3, '0')} ${String(1000 + storeIndex).padStart(4, '0')}`,
              email: `store${storeIndex}@diplomatsa.com`,
            },
            operatingHours: {
              monday: { open: '08:00', close: '20:00' },
              tuesday: { open: '08:00', close: '20:00' },
              wednesday: { open: '08:00', close: '20:00' },
              thursday: { open: '08:00', close: '20:00' },
              friday: { open: '08:00', close: '21:00' },
              saturday: { open: '08:00', close: '18:00' },
              sunday: { open: '09:00', close: '17:00' },
            },
            size: storeType === 'Hypermarket' ? 5000 : storeType === 'Supermarket' ? 2000 : storeType === 'Convenience' ? 500 : 3000,
            status: 'ACTIVE',
            metadata: {
              parkingSpaces: storeType === 'Hypermarket' ? 500 : 200,
              departments: PRODUCT_CATEGORIES,
              yearOpened: 2010 + Math.floor(Math.random() * 15),
            },
            createdAt: new Date(),
            updatedAt: new Date(),
          },
        });
        stores.push(store);
        storeIndex++;
      }
    }

    console.log('✅ Stores created:', stores.length);

    // 6. Create Products
    const products = [];
    const brands = ['CocaCola', 'Pepsi', 'Nestle', 'Unilever', 'P&G', 'Kelloggs', 'Cadbury', 'Lays'];
    
    for (const category of PRODUCT_CATEGORIES) {
      for (let i = 0; i < 10; i++) {
        const brand = brands[Math.floor(Math.random() * brands.length)];
        const product = await prisma.product.create({
          data: {
            id: uuidv4(),
            code: `PRD${category.substring(0, 3).toUpperCase()}${String(i + 1).padStart(3, '0')}`,
            barcode: `600${String(Math.floor(Math.random() * 1000000000)).padStart(9, '0')}`,
            name: `${brand} ${category} Product ${i + 1}`,
            brand,
            category,
            subCategory: `${category} Sub ${i % 3 + 1}`,
            description: `Premium ${category.toLowerCase()} product from ${brand}`,
            unitSize: ['250ml', '500ml', '1L', '100g', '250g', '500g', '1kg'][Math.floor(Math.random() * 7)],
            unitOfMeasure: category === 'Beverages' ? 'ml' : 'g',
            packSize: [6, 12, 24][Math.floor(Math.random() * 3)],
            costPrice: Math.round(10 + Math.random() * 90),
            sellingPrice: Math.round(15 + Math.random() * 135),
            vatRate: 15,
            supplier: brand,
            status: 'ACTIVE',
            companyId: company.id,
            metadata: {
              shelfLife: `${Math.floor(Math.random() * 12 + 3)} months`,
              storageTemp: category === 'Frozen Foods' ? '-18°C' : 'Room temperature',
            },
            createdAt: new Date(),
            updatedAt: new Date(),
          },
        });
        products.push(product);
      }
    }

    console.log('✅ Products created:', products.length);

    // 7. Create Promotions and Trade Spend Data for the past year
    const promotions = [];
    const tradeSpends = [];
    const startDate = startOfYear(new Date());
    const endDate = endOfYear(new Date());
    
    for (let month = 0; month < 12; month++) {
      for (let i = 0; i < 5; i++) {
        const promotionStartDate = new Date(startDate);
        promotionStartDate.setMonth(month);
        promotionStartDate.setDate(Math.floor(Math.random() * 15) + 1);
        
        const promotionEndDate = new Date(promotionStartDate);
        promotionEndDate.setDate(promotionStartDate.getDate() + Math.floor(Math.random() * 14) + 7);
        
        const selectedProducts = products
          .sort(() => 0.5 - Math.random())
          .slice(0, Math.floor(Math.random() * 10) + 5);
        
        const selectedStores = stores
          .sort(() => 0.5 - Math.random())
          .slice(0, Math.floor(Math.random() * 20) + 10);
        
        const promotion = await prisma.promotion.create({
          data: {
            id: uuidv4(),
            code: `PROMO-${new Date().getFullYear()}-${String(month + 1).padStart(2, '0')}${String(i + 1).padStart(2, '0')}`,
            name: `${['Summer', 'Winter', 'Spring', 'Autumn'][Math.floor(month / 3)]} ${['Sale', 'Special', 'Promotion', 'Deal'][i % 4]} ${month + 1}/${i + 1}`,
            type: ['PRICE_REDUCTION', 'BOGO', 'VOLUME_DISCOUNT', 'BUNDLE'][i % 4],
            status: promotionEndDate < new Date() ? 'COMPLETED' : promotionStartDate > new Date() ? 'PLANNED' : 'ACTIVE',
            startDate: promotionStartDate,
            endDate: promotionEndDate,
            companyId: company.id,
            mechanics: {
              discountType: ['PERCENTAGE', 'FIXED_AMOUNT'][i % 2],
              discountValue: i % 2 === 0 ? [10, 15, 20, 25][i % 4] : [5, 10, 15, 20][i % 4],
              minPurchaseQty: [1, 2, 3][i % 3],
              maxDiscountQty: [10, 20, 50][i % 3],
            },
            budget: {
              planned: Math.round(50000 + Math.random() * 150000),
              actual: promotionEndDate < new Date() ? Math.round(40000 + Math.random() * 140000) : 0,
              currency: 'ZAR',
            },
            products: {
              connect: selectedProducts.map(p => ({ id: p.id })),
            },
            stores: {
              connect: selectedStores.map(s => ({ id: s.id })),
            },
            createdBy: users[Math.floor(Math.random() * users.length)].id,
            metadata: {
              targetAudience: ['All Customers', 'Loyalty Members', 'New Customers'][i % 3],
              channel: ['In-Store', 'Online', 'Both'][i % 3],
            },
            createdAt: new Date(),
            updatedAt: new Date(),
          },
        });
        promotions.push(promotion);
        
        // Create associated trade spend
        const tradeSpend = await prisma.tradeSpend.create({
          data: {
            id: uuidv4(),
            promotionId: promotion.id,
            companyId: company.id,
            period: {
              year: new Date().getFullYear(),
              month: month + 1,
              quarter: Math.floor(month / 3) + 1,
            },
            plannedAmount: promotion.budget.planned,
            actualAmount: promotion.budget.actual,
            variance: promotion.budget.actual > 0 ? promotion.budget.actual - promotion.budget.planned : 0,
            currency: 'ZAR',
            status: promotion.status === 'COMPLETED' ? 'CLOSED' : promotion.status === 'ACTIVE' ? 'IN_PROGRESS' : 'PLANNED',
            approvedBy: users.find(u => u.jobTitle === 'Finance Manager')?.id,
            approvedAt: promotion.status !== 'PLANNED' ? subDays(promotionStartDate, 7) : null,
            performance: promotion.status === 'COMPLETED' ? {
              roi: 1.2 + Math.random() * 0.8,
              incrementalRevenue: Math.round(promotion.budget.actual * (2 + Math.random() * 3)),
              incrementalUnits: Math.round(1000 + Math.random() * 9000),
              uplift: Math.round(10 + Math.random() * 40),
            } : null,
            createdAt: new Date(),
            updatedAt: new Date(),
          },
        });
        tradeSpends.push(tradeSpend);
      }
    }

    console.log('✅ Promotions created:', promotions.length);
    console.log('✅ Trade Spends created:', tradeSpends.length);

    // 8. Create sample analytics data
    const analyticsData = [];
    
    for (const store of stores.slice(0, 20)) {
      for (const product of products.slice(0, 30)) {
        for (let day = 0; day < 365; day++) {
          const date = new Date(startDate);
          date.setDate(date.getDate() + day);
          
          const isPromotionDay = promotions.some(p => 
            date >= p.startDate && 
            date <= p.endDate && 
            p.products.some((pp: any) => pp.id === product.id) &&
            p.stores.some((ps: any) => ps.id === store.id)
          );
          
          const baselineUnits = Math.round(10 + Math.random() * 90);
          const upliftMultiplier = isPromotionDay ? 1.2 + Math.random() * 0.8 : 1;
          
          const analytics = await prisma.analytics.create({
            data: {
              id: uuidv4(),
              date,
              storeId: store.id,
              productId: product.id,
              companyId: company.id,
              metrics: {
                units: Math.round(baselineUnits * upliftMultiplier),
                revenue: Math.round(baselineUnits * upliftMultiplier * product.sellingPrice),
                cost: Math.round(baselineUnits * upliftMultiplier * product.costPrice),
                margin: Math.round((product.sellingPrice - product.costPrice) * baselineUnits * upliftMultiplier),
                transactions: Math.round(5 + Math.random() * 20),
              },
              isPromotion: isPromotionDay,
              createdAt: new Date(),
              updatedAt: new Date(),
            },
          });
          analyticsData.push(analytics);
        }
      }
    }

    console.log('✅ Analytics data created:', analyticsData.length);

    console.log('\n🎉 Diplomat SA setup completed successfully!');
    console.log('\n📊 Summary:');
    console.log(`- Company: ${company.name}`);
    console.log(`- License: Enterprise (10 users)`);
    console.log(`- Users: ${users.length}`);
    console.log(`- Stores: ${stores.length}`);
    console.log(`- Products: ${products.length}`);
    console.log(`- Promotions: ${promotions.length}`);
    console.log(`- Trade Spends: ${tradeSpends.length}`);
    console.log(`- Analytics Records: ${analyticsData.length}`);
    console.log('\n🔐 Default password for all users: DiplomatSA2025!');
    console.log('\n✨ The system is ready for testing and deployment!');

  } catch (error) {
    console.error('❌ Error setting up Diplomat SA:', error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

// Run the setup
setupDiplomatSA()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });