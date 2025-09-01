import axios from 'axios';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { API_BASE_URL } from '../config/constants';

interface Wallet {
  id: string;
  walletNumber: string;
  balance: number;
  creditLimit: number;
  spentAmount: number;
  status: string;
  qrCode: string;
}

interface Transaction {
  id: string;
  transactionId: string;
  amount: number;
  type: string;
  description: string;
  createdAt: string;
  store?: {
    name: string;
    code: string;
  };
}

class WalletService {
  private apiClient = axios.create({
    baseURL: API_BASE_URL,
    timeout: 30000
  });

  constructor() {
    this.setupInterceptors();
  }

  private setupInterceptors() {
    // Request interceptor to add auth token
    this.apiClient.interceptors.request.use(
      async (config) => {
        const token = await AsyncStorage.getItem('authToken');
        if (token) {
          config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
      },
      (error) => {
        return Promise.reject(error);
      }
    );

    // Response interceptor for error handling
    this.apiClient.interceptors.response.use(
      (response) => response,
      async (error) => {
        if (error.response?.status === 401) {
          // Handle token refresh or logout
          await AsyncStorage.removeItem('authToken');
          // Navigate to login screen
        }
        return Promise.reject(error);
      }
    );
  }

  async getWallet(userId: string): Promise<Wallet> {
    const response = await this.apiClient.get(`/api/v1/wallets/user/${userId}`);
    return response.data;
  }

  async getTransactions(walletId: string, limit: number = 10): Promise<Transaction[]> {
    const response = await this.apiClient.get(`/api/v1/wallets/${walletId}/transactions`, {
      params: { limit }
    });
    return response.data;
  }

  async createTransaction(data: {
    walletId: string;
    amount: number;
    type: string;
    description: string;
    pin?: string;
    location?: {
      latitude: number;
      longitude: number;
    };
    offlineId?: string;
  }): Promise<Transaction> {
    const response = await this.apiClient.post(`/api/v1/wallets/${data.walletId}/transaction`, data);
    return response.data;
  }

  async validatePin(walletId: string, pin: string): Promise<boolean> {
    const response = await this.apiClient.post(`/api/v1/wallets/${walletId}/validate-pin`, { pin });
    return response.data.valid;
  }

  async getWalletStats(walletId: string): Promise<any> {
    const response = await this.apiClient.get(`/api/v1/wallets/${walletId}/stats`);
    return response.data;
  }

  async requestBalanceIncrease(walletId: string, amount: number, reason: string): Promise<any> {
    const response = await this.apiClient.post(`/api/v1/wallets/${walletId}/request-increase`, {
      amount,
      reason
    });
    return response.data;
  }
}

export const walletService = new WalletService();