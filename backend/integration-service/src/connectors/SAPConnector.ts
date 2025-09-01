import axios, { AxiosInstance } from 'axios';
import { Logger } from 'winston';
import { createLogger } from '../utils/logger';

export interface SAPConfig {
  baseUrl: string;
  client: string;
  username: string;
  password: string;
  language?: string;
  systemType: 'ECC' | 'S4HANA';
}

export interface SAPTradeSpendData {
  documentNumber: string;
  companyCode: string;
  customerNumber: string;
  customerName: string;
  promotionId: string;
  promotionDescription: string;
  startDate: Date;
  endDate: Date;
  plannedAmount: number;
  actualAmount: number;
  currency: string;
  status: string;
  productGroups: Array<{
    materialNumber: string;
    materialDescription: string;
    plannedQuantity: number;
    actualQuantity: number;
    unitOfMeasure: string;
    discountPercentage: number;
  }>;
  stores: Array<{
    storeId: string;
    storeName: string;
    region: string;
    channel: string;
  }>;
}

export class SAPConnector {
  private client: AxiosInstance;
  private logger: Logger;
  private config: SAPConfig;
  private sessionToken?: string;

  constructor(config: SAPConfig) {
    this.config = config;
    this.logger = createLogger('SAPConnector');
    
    this.client = axios.create({
      baseURL: config.baseUrl,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'sap-client': config.client,
        'sap-language': config.language || 'EN',
      },
      auth: {
        username: config.username,
        password: config.password,
      },
    });

    this.setupInterceptors();
  }

  private setupInterceptors(): void {
    // Request interceptor
    this.client.interceptors.request.use(
      (config) => {
        if (this.sessionToken) {
          config.headers['x-csrf-token'] = this.sessionToken;
        }
        this.logger.info(`SAP Request: ${config.method?.toUpperCase()} ${config.url}`);
        return config;
      },
      (error) => {
        this.logger.error('SAP Request Error:', error);
        return Promise.reject(error);
      }
    );

    // Response interceptor
    this.client.interceptors.response.use(
      (response) => {
        // Extract CSRF token if present
        const csrfToken = response.headers['x-csrf-token'];
        if (csrfToken) {
          this.sessionToken = csrfToken;
        }
        return response;
      },
      async (error) => {
        if (error.response?.status === 403 && !error.config._retry) {
          // CSRF token might be invalid, try to fetch a new one
          error.config._retry = true;
          await this.fetchCSRFToken();
          return this.client(error.config);
        }
        this.logger.error('SAP Response Error:', error.response?.data || error.message);
        return Promise.reject(error);
      }
    );
  }

  private async fetchCSRFToken(): Promise<void> {
    try {
      const response = await this.client.get('/sap/opu/odata/sap/', {
        headers: {
          'x-csrf-token': 'Fetch',
        },
      });
      this.sessionToken = response.headers['x-csrf-token'];
      this.logger.info('CSRF token fetched successfully');
    } catch (error) {
      this.logger.error('Failed to fetch CSRF token:', error);
    }
  }

  async testConnection(): Promise<boolean> {
    try {
      await this.fetchCSRFToken();
      const endpoint = this.config.systemType === 'S4HANA' 
        ? '/sap/opu/odata/sap/API_BUSINESS_PARTNER/A_BusinessPartner?$top=1'
        : '/sap/opu/odata/sap/ZGW_TRADE_SPEND_SRV/TradeSpendSet?$top=1';
      
      const response = await this.client.get(endpoint);
      return response.status === 200;
    } catch (error) {
      this.logger.error('Connection test failed:', error);
      return false;
    }
  }

  async fetchTradeSpendData(params: {
    companyCode?: string;
    dateFrom?: Date;
    dateTo?: Date;
    customerNumber?: string;
    limit?: number;
    offset?: number;
  }): Promise<SAPTradeSpendData[]> {
    try {
      let filters: string[] = [];
      
      if (params.companyCode) {
        filters.push(`CompanyCode eq '${params.companyCode}'`);
      }
      if (params.dateFrom) {
        filters.push(`StartDate ge datetime'${params.dateFrom.toISOString()}'`);
      }
      if (params.dateTo) {
        filters.push(`EndDate le datetime'${params.dateTo.toISOString()}'`);
      }
      if (params.customerNumber) {
        filters.push(`CustomerNumber eq '${params.customerNumber}'`);
      }

      const filterString = filters.length > 0 ? `$filter=${filters.join(' and ')}` : '';
      const pagination = `$top=${params.limit || 100}&$skip=${params.offset || 0}`;
      
      const endpoint = this.config.systemType === 'S4HANA'
        ? `/sap/opu/odata/sap/API_TRADE_SPEND_MGMT/TradeSpendSet?${filterString}&${pagination}&$expand=ProductGroups,Stores`
        : `/sap/opu/odata/sap/ZGW_TRADE_SPEND_SRV/TradeSpendSet?${filterString}&${pagination}&$expand=ProductGroups,Stores`;

      const response = await this.client.get(endpoint);
      
      return this.mapSAPResponse(response.data.d.results);
    } catch (error) {
      this.logger.error('Failed to fetch trade spend data:', error);
      throw new Error(`SAP data fetch failed: ${error}`);
    }
  }

  async fetchPromotions(params: {
    status?: string;
    dateFrom?: Date;
    dateTo?: Date;
  }): Promise<any[]> {
    try {
      let filters: string[] = [];
      
      if (params.status) {
        filters.push(`Status eq '${params.status}'`);
      }
      if (params.dateFrom) {
        filters.push(`ValidFrom ge datetime'${params.dateFrom.toISOString()}'`);
      }
      if (params.dateTo) {
        filters.push(`ValidTo le datetime'${params.dateTo.toISOString()}'`);
      }

      const filterString = filters.length > 0 ? `$filter=${filters.join(' and ')}` : '';
      
      const endpoint = this.config.systemType === 'S4HANA'
        ? `/sap/opu/odata/sap/API_PROMOTION_MGMT/PromotionSet?${filterString}`
        : `/sap/opu/odata/sap/ZGW_PROMOTION_SRV/PromotionSet?${filterString}`;

      const response = await this.client.get(endpoint);
      return response.data.d.results;
    } catch (error) {
      this.logger.error('Failed to fetch promotions:', error);
      throw error;
    }
  }

  async fetchMasterData(entityType: 'customers' | 'products' | 'stores'): Promise<any[]> {
    try {
      let endpoint: string;
      
      switch (entityType) {
        case 'customers':
          endpoint = this.config.systemType === 'S4HANA'
            ? '/sap/opu/odata/sap/API_BUSINESS_PARTNER/A_Customer'
            : '/sap/opu/odata/sap/ZGW_CUSTOMER_SRV/CustomerSet';
          break;
        case 'products':
          endpoint = this.config.systemType === 'S4HANA'
            ? '/sap/opu/odata/sap/API_PRODUCT_SRV/A_Product'
            : '/sap/opu/odata/sap/ZGW_MATERIAL_SRV/MaterialSet';
          break;
        case 'stores':
          endpoint = this.config.systemType === 'S4HANA'
            ? '/sap/opu/odata/sap/API_STORE_MGMT/StoreSet'
            : '/sap/opu/odata/sap/ZGW_STORE_SRV/StoreSet';
          break;
      }

      const response = await this.client.get(endpoint);
      return response.data.d.results;
    } catch (error) {
      this.logger.error(`Failed to fetch ${entityType}:`, error);
      throw error;
    }
  }

  private mapSAPResponse(sapData: any[]): SAPTradeSpendData[] {
    return sapData.map(item => ({
      documentNumber: item.DocumentNumber || item.TradeSpendID,
      companyCode: item.CompanyCode,
      customerNumber: item.CustomerNumber || item.Customer,
      customerName: item.CustomerName,
      promotionId: item.PromotionID || item.PromotionNumber,
      promotionDescription: item.PromotionDescription || item.PromotionText,
      startDate: new Date(parseInt(item.StartDate.match(/\d+/)[0])),
      endDate: new Date(parseInt(item.EndDate.match(/\d+/)[0])),
      plannedAmount: parseFloat(item.PlannedAmount),
      actualAmount: parseFloat(item.ActualAmount || '0'),
      currency: item.Currency,
      status: item.Status,
      productGroups: this.mapProductGroups(item.ProductGroups?.results || []),
      stores: this.mapStores(item.Stores?.results || []),
    }));
  }

  private mapProductGroups(products: any[]): any[] {
    return products.map(product => ({
      materialNumber: product.MaterialNumber || product.Product,
      materialDescription: product.MaterialDescription || product.ProductDescription,
      plannedQuantity: parseFloat(product.PlannedQuantity || '0'),
      actualQuantity: parseFloat(product.ActualQuantity || '0'),
      unitOfMeasure: product.UnitOfMeasure || product.UoM,
      discountPercentage: parseFloat(product.DiscountPercentage || '0'),
    }));
  }

  private mapStores(stores: any[]): any[] {
    return stores.map(store => ({
      storeId: store.StoreID || store.Store,
      storeName: store.StoreName || store.StoreDescription,
      region: store.Region,
      channel: store.Channel || store.DistributionChannel,
    }));
  }

  async createPromotion(promotionData: any): Promise<any> {
    try {
      const endpoint = this.config.systemType === 'S4HANA'
        ? '/sap/opu/odata/sap/API_PROMOTION_MGMT/PromotionSet'
        : '/sap/opu/odata/sap/ZGW_PROMOTION_SRV/PromotionSet';

      const response = await this.client.post(endpoint, promotionData);
      return response.data.d;
    } catch (error) {
      this.logger.error('Failed to create promotion:', error);
      throw error;
    }
  }

  async updateTradeSpend(documentNumber: string, updateData: any): Promise<any> {
    try {
      const endpoint = this.config.systemType === 'S4HANA'
        ? `/sap/opu/odata/sap/API_TRADE_SPEND_MGMT/TradeSpendSet('${documentNumber}')`
        : `/sap/opu/odata/sap/ZGW_TRADE_SPEND_SRV/TradeSpendSet('${documentNumber}')`;

      const response = await this.client.patch(endpoint, updateData);
      return response.data.d;
    } catch (error) {
      this.logger.error('Failed to update trade spend:', error);
      throw error;
    }
  }
}