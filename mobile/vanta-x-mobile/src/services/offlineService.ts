import * as SQLite from 'expo-sqlite';
import * as Network from 'expo-network';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { walletService } from './walletService';

const db = SQLite.openDatabase('vantax.db');

interface OfflineTransaction {
  id: string;
  walletId: string;
  amount: number;
  type: string;
  description: string;
  location?: {
    latitude: number;
    longitude: number;
  };
  createdAt: string;
  synced: boolean;
}

class OfflineService {
  constructor() {
    this.initDatabase();
  }

  private initDatabase() {
    db.transaction(tx => {
      tx.executeSql(
        `CREATE TABLE IF NOT EXISTS offline_transactions (
          id TEXT PRIMARY KEY,
          walletId TEXT NOT NULL,
          amount REAL NOT NULL,
          type TEXT NOT NULL,
          description TEXT,
          latitude REAL,
          longitude REAL,
          createdAt TEXT NOT NULL,
          synced INTEGER DEFAULT 0
        )`
      );

      tx.executeSql(
        `CREATE TABLE IF NOT EXISTS offline_data (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updatedAt TEXT NOT NULL
        )`
      );
    });
  }

  async isConnected(): Promise<boolean> {
    const networkState = await Network.getNetworkStateAsync();
    return networkState.isConnected && networkState.isInternetReachable;
  }

  async saveTransaction(transaction: any): Promise<any> {
    return new Promise((resolve, reject) => {
      const id = `offline-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
      const createdAt = new Date().toISOString();

      db.transaction(
        tx => {
          tx.executeSql(
            `INSERT INTO offline_transactions 
            (id, walletId, amount, type, description, latitude, longitude, createdAt, synced) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)`,
            [
              id,
              transaction.walletId,
              transaction.amount,
              transaction.type,
              transaction.description,
              transaction.location?.latitude || null,
              transaction.location?.longitude || null,
              createdAt
            ],
            (_, result) => {
              resolve({
                id,
                ...transaction,
                createdAt,
                offline: true
              });
            },
            (_, error) => {
              reject(error);
              return false;
            }
          );
        }
      );
    });
  }

  async getOfflineTransactions(): Promise<OfflineTransaction[]> {
    return new Promise((resolve, reject) => {
      db.transaction(tx => {
        tx.executeSql(
          'SELECT * FROM offline_transactions WHERE synced = 0 ORDER BY createdAt ASC',
          [],
          (_, { rows }) => {
            const transactions = [];
            for (let i = 0; i < rows.length; i++) {
              const row = rows.item(i);
              transactions.push({
                ...row,
                location: row.latitude && row.longitude ? {
                  latitude: row.latitude,
                  longitude: row.longitude
                } : undefined,
                synced: row.synced === 1
              });
            }
            resolve(transactions);
          },
          (_, error) => {
            reject(error);
            return false;
          }
        );
      });
    });
  }

  async syncTransactions(walletId: string): Promise<void> {
    const isConnected = await this.isConnected();
    if (!isConnected) return;

    const offlineTransactions = await this.getOfflineTransactions();
    const walletTransactions = offlineTransactions.filter(t => t.walletId === walletId);

    for (const transaction of walletTransactions) {
      try {
        // Send to server
        await walletService.createTransaction({
          walletId: transaction.walletId,
          amount: transaction.amount,
          type: transaction.type,
          description: transaction.description,
          location: transaction.location,
          offlineId: transaction.id
        });

        // Mark as synced
        await this.markTransactionSynced(transaction.id);
      } catch (error) {
        console.error('Failed to sync transaction:', transaction.id, error);
        // Continue with next transaction
      }
    }
  }

  private async markTransactionSynced(id: string): Promise<void> {
    return new Promise((resolve, reject) => {
      db.transaction(tx => {
        tx.executeSql(
          'UPDATE offline_transactions SET synced = 1 WHERE id = ?',
          [id],
          (_, result) => resolve(),
          (_, error) => {
            reject(error);
            return false;
          }
        );
      });
    });
  }

  async cacheData(key: string, value: any): Promise<void> {
    const valueStr = JSON.stringify(value);
    const updatedAt = new Date().toISOString();

    return new Promise((resolve, reject) => {
      db.transaction(tx => {
        tx.executeSql(
          'INSERT OR REPLACE INTO offline_data (key, value, updatedAt) VALUES (?, ?, ?)',
          [key, valueStr, updatedAt],
          (_, result) => resolve(),
          (_, error) => {
            reject(error);
            return false;
          }
        );
      });
    });
  }

  async getCachedData(key: string): Promise<any> {
    return new Promise((resolve, reject) => {
      db.transaction(tx => {
        tx.executeSql(
          'SELECT value FROM offline_data WHERE key = ?',
          [key],
          (_, { rows }) => {
            if (rows.length > 0) {
              try {
                const value = JSON.parse(rows.item(0).value);
                resolve(value);
              } catch (error) {
                resolve(null);
              }
            } else {
              resolve(null);
            }
          },
          (_, error) => {
            reject(error);
            return false;
          }
        );
      });
    });
  }

  async clearOldData(daysToKeep: number = 7): Promise<void> {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - daysToKeep);
    const cutoffDateStr = cutoffDate.toISOString();

    return new Promise((resolve, reject) => {
      db.transaction(tx => {
        // Clear synced transactions older than cutoff
        tx.executeSql(
          'DELETE FROM offline_transactions WHERE synced = 1 AND createdAt < ?',
          [cutoffDateStr]
        );

        // Clear old cached data
        tx.executeSql(
          'DELETE FROM offline_data WHERE updatedAt < ?',
          [cutoffDateStr],
          (_, result) => resolve(),
          (_, error) => {
            reject(error);
            return false;
          }
        );
      });
    });
  }

  async exportOfflineData(): Promise<string> {
    const transactions = await this.getOfflineTransactions();
    const cachedData = await this.getAllCachedData();

    const exportData = {
      exportDate: new Date().toISOString(),
      transactions,
      cachedData,
      deviceInfo: {
        platform: 'mobile',
        version: '1.0.0'
      }
    };

    return JSON.stringify(exportData, null, 2);
  }

  private async getAllCachedData(): Promise<any> {
    return new Promise((resolve, reject) => {
      db.transaction(tx => {
        tx.executeSql(
          'SELECT * FROM offline_data',
          [],
          (_, { rows }) => {
            const data: any = {};
            for (let i = 0; i < rows.length; i++) {
              const row = rows.item(i);
              try {
                data[row.key] = JSON.parse(row.value);
              } catch (error) {
                data[row.key] = row.value;
              }
            }
            resolve(data);
          },
          (_, error) => {
            reject(error);
            return false;
          }
        );
      });
    });
  }
}

export const offlineService = new OfflineService();