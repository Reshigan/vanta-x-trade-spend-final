export const API_BASE_URL = process.env.EXPO_PUBLIC_API_URL || 'https://api.vantax.com';

export const COLORS = {
  primary: '#1976d2',
  secondary: '#dc004e',
  success: '#4caf50',
  warning: '#ff9800',
  error: '#f44336',
  info: '#2196f3',
  background: '#f5f5f5',
  surface: '#ffffff',
  text: '#212121',
  textSecondary: '#757575'
};

export const STORAGE_KEYS = {
  AUTH_TOKEN: 'authToken',
  USER: 'user',
  WALLET: 'wallet',
  OFFLINE_MODE: 'offlineMode',
  LAST_SYNC: 'lastSync'
};

export const TRANSACTION_TYPES = {
  CREDIT: 'CREDIT',
  DEBIT: 'DEBIT',
  REFUND: 'REFUND',
  ADJUSTMENT: 'ADJUSTMENT'
};

export const WALLET_STATUS = {
  ACTIVE: 'ACTIVE',
  SUSPENDED: 'SUSPENDED',
  EXPIRED: 'EXPIRED',
  LOCKED: 'LOCKED'
};

export const GEOFENCE_RADIUS = 500; // meters

export const SYNC_INTERVAL = 5 * 60 * 1000; // 5 minutes

export const CACHE_DURATION = {
  WALLET: 5 * 60 * 1000, // 5 minutes
  TRANSACTIONS: 2 * 60 * 1000, // 2 minutes
  STORES: 30 * 60 * 1000 // 30 minutes
};