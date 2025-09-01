import { PrismaClient } from '@prisma/client';
import QRCode from 'qrcode';
import bcrypt from 'bcryptjs';
import { v4 as uuidv4 } from 'uuid';
import { isPointWithinRadius } from 'geolib';
import { logger } from '../utils/logger';
import { Redis } from 'ioredis';

const prisma = new PrismaClient();
const redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379');

interface CreateWalletInput {
  userId: string;
  storeId?: string;
  coopBudgetId: string;
  creditLimit: number;
  pin?: string;
}

interface TransactionInput {
  walletId: string;
  amount: number;
  type: 'CREDIT' | 'DEBIT' | 'REFUND' | 'ADJUSTMENT';
  storeId?: string;
  description?: string;
  reasonCode?: string;
  receipt?: string;
  location?: {
    latitude: number;
    longitude: number;
  };
}

interface WalletValidation {
  isValid: boolean;
  errors: string[];
  warnings: string[];
}

export class DigitalWalletService {
  async createWallet(input: CreateWalletInput) {
    try {
      const { userId, storeId, coopBudgetId, creditLimit, pin } = input;

      // Validate co-op budget
      const coopBudget = await prisma.coopBudget.findUnique({
        where: { id: coopBudgetId },
        include: { budget: true }
      });

      if (!coopBudget || coopBudget.status !== 'ACTIVE') {
        throw new Error('Invalid or inactive co-op budget');
      }

      // Check available budget
      if (coopBudget.allocatedAmount + creditLimit > coopBudget.totalAmount) {
        throw new Error('Insufficient co-op budget available');
      }

      // Generate wallet number and QR code
      const walletNumber = this.generateWalletNumber();
      const qrData = {
        walletNumber,
        userId,
        coopBudgetId,
        timestamp: new Date().toISOString()
      };
      const qrCode = await QRCode.toDataURL(JSON.stringify(qrData));

      // Hash PIN if provided
      const hashedPin = pin ? await bcrypt.hash(pin, 10) : null;

      // Create wallet
      const wallet = await prisma.digitalWallet.create({
        data: {
          walletNumber,
          userId,
          storeId,
          coopBudgetId,
          balance: creditLimit,
          creditLimit,
          spentAmount: 0,
          status: 'ACTIVE',
          pin: hashedPin,
          qrCode,
          companyId: coopBudget.companyId,
          expiresAt: coopBudget.endDate
        }
      });

      // Update co-op budget allocation
      await prisma.coopBudget.update({
        where: { id: coopBudgetId },
        data: {
          allocatedAmount: {
            increment: creditLimit
          }
        }
      });

      // Cache wallet data for quick access
      await this.cacheWalletData(wallet);

      logger.info('Digital wallet created', { walletId: wallet.id, userId });

      return wallet;
    } catch (error) {
      logger.error('Error creating digital wallet:', error);
      throw error;
    }
  }

  async processTransaction(input: TransactionInput): Promise<any> {
    try {
      const { walletId, amount, type, storeId, description, reasonCode, receipt, location } = input;

      // Get wallet with lock to prevent concurrent transactions
      const wallet = await prisma.digitalWallet.findUnique({
        where: { id: walletId },
        include: {
          store: true,
          coopBudget: true
        }
      });

      if (!wallet) {
        throw new Error('Wallet not found');
      }

      // Validate wallet status
      const validation = await this.validateWallet(wallet);
      if (!validation.isValid) {
        throw new Error(`Wallet validation failed: ${validation.errors.join(', ')}`);
      }

      // Validate location if provided
      if (location && wallet.store) {
        const isWithinGeofence = await this.validateLocation(
          location,
          wallet.store
        );
        if (!isWithinGeofence) {
          throw new Error('Transaction location outside store geofence');
        }
      }

      // Calculate new balance
      let newBalance = wallet.balance;
      switch (type) {
        case 'DEBIT':
          if (wallet.balance < amount) {
            throw new Error('Insufficient balance');
          }
          newBalance = wallet.balance - amount;
          break;
        case 'CREDIT':
        case 'REFUND':
          newBalance = wallet.balance + amount;
          if (newBalance > wallet.creditLimit) {
            throw new Error('Credit limit exceeded');
          }
          break;
        case 'ADJUSTMENT':
          newBalance = wallet.balance + amount;
          break;
      }

      // Create transaction
      const transaction = await prisma.walletTransaction.create({
        data: {
          transactionId: `TXN-${uuidv4()}`,
          walletId,
          type,
          amount,
          balance: newBalance,
          storeId: storeId || wallet.storeId,
          description,
          reasonCode,
          receipt,
          latitude: location?.latitude,
          longitude: location?.longitude,
          metadata: {
            processedAt: new Date().toISOString(),
            walletStatus: wallet.status
          }
        }
      });

      // Update wallet balance and spent amount
      const updateData: any = { balance: newBalance };
      if (type === 'DEBIT') {
        updateData.spentAmount = { increment: amount };
      }

      await prisma.digitalWallet.update({
        where: { id: walletId },
        data: updateData
      });

      // Update co-op budget spent amount
      if (type === 'DEBIT') {
        await prisma.coopBudget.update({
          where: { id: wallet.coopBudgetId },
          data: {
            spentAmount: { increment: amount }
          }
        });
      }

      // Update cache
      await this.updateCachedBalance(walletId, newBalance);

      // Send notification
      await this.sendTransactionNotification(wallet.userId, transaction);

      logger.info('Transaction processed', {
        transactionId: transaction.transactionId,
        walletId,
        type,
        amount
      });

      return transaction;
    } catch (error) {
      logger.error('Error processing transaction:', error);
      throw error;
    }
  }

  async validatePin(walletId: string, pin: string): Promise<boolean> {
    const wallet = await prisma.digitalWallet.findUnique({
      where: { id: walletId },
      select: { pin: true }
    });

    if (!wallet || !wallet.pin) {
      return false;
    }

    return bcrypt.compare(pin, wallet.pin);
  }

  async getWalletBalance(walletId: string): Promise<number> {
    // Try cache first
    const cached = await redis.get(`wallet:${walletId}:balance`);
    if (cached) {
      return parseFloat(cached);
    }

    // Fallback to database
    const wallet = await prisma.digitalWallet.findUnique({
      where: { id: walletId },
      select: { balance: true }
    });

    if (!wallet) {
      throw new Error('Wallet not found');
    }

    // Cache the balance
    await redis.setex(`wallet:${walletId}:balance`, 300, wallet.balance);

    return wallet.balance;
  }

  async getTransactionHistory(walletId: string, options?: {
    startDate?: Date;
    endDate?: Date;
    limit?: number;
    offset?: number;
  }) {
    const where: any = { walletId };

    if (options?.startDate || options?.endDate) {
      where.createdAt = {};
      if (options.startDate) {
        where.createdAt.gte = options.startDate;
      }
      if (options.endDate) {
        where.createdAt.lte = options.endDate;
      }
    }

    return prisma.walletTransaction.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: options?.limit || 50,
      skip: options?.offset || 0,
      include: {
        store: {
          select: {
            name: true,
            code: true
          }
        }
      }
    });
  }

  async suspendWallet(walletId: string, reason: string) {
    const wallet = await prisma.digitalWallet.update({
      where: { id: walletId },
      data: {
        status: 'SUSPENDED',
        metadata: {
          suspendedAt: new Date().toISOString(),
          suspendReason: reason
        }
      }
    });

    // Clear cache
    await redis.del(`wallet:${walletId}:balance`);

    logger.info('Wallet suspended', { walletId, reason });

    return wallet;
  }

  async reactivateWallet(walletId: string) {
    const wallet = await prisma.digitalWallet.findUnique({
      where: { id: walletId },
      include: { coopBudget: true }
    });

    if (!wallet) {
      throw new Error('Wallet not found');
    }

    // Check if co-op budget is still active
    if (wallet.coopBudget.status !== 'ACTIVE') {
      throw new Error('Associated co-op budget is not active');
    }

    const updated = await prisma.digitalWallet.update({
      where: { id: walletId },
      data: {
        status: 'ACTIVE',
        metadata: {
          ...wallet.metadata as any,
          reactivatedAt: new Date().toISOString()
        }
      }
    });

    logger.info('Wallet reactivated', { walletId });

    return updated;
  }

  private generateWalletNumber(): string {
    const prefix = 'VXW';
    const timestamp = Date.now().toString(36).toUpperCase();
    const random = Math.random().toString(36).substring(2, 6).toUpperCase();
    return `${prefix}-${timestamp}-${random}`;
  }

  private async validateWallet(wallet: any): Promise<WalletValidation> {
    const errors: string[] = [];
    const warnings: string[] = [];

    // Check wallet status
    if (wallet.status !== 'ACTIVE') {
      errors.push(`Wallet is ${wallet.status}`);
    }

    // Check expiration
    if (wallet.expiresAt && new Date(wallet.expiresAt) < new Date()) {
      errors.push('Wallet has expired');
    }

    // Check co-op budget status
    if (wallet.coopBudget.status !== 'ACTIVE') {
      errors.push('Associated co-op budget is not active');
    }

    // Check balance warnings
    const balancePercentage = (wallet.balance / wallet.creditLimit) * 100;
    if (balancePercentage < 20) {
      warnings.push('Low balance warning');
    }

    return {
      isValid: errors.length === 0,
      errors,
      warnings
    };
  }

  private async validateLocation(
    location: { latitude: number; longitude: number },
    store: any
  ): Promise<boolean> {
    if (!store.latitude || !store.longitude) {
      // No geofence configured
      return true;
    }

    // Default radius of 500 meters if not specified
    const radius = store.geoFence?.radius || 500;

    return isPointWithinRadius(
      location,
      { latitude: store.latitude, longitude: store.longitude },
      radius
    );
  }

  private async cacheWalletData(wallet: any) {
    const key = `wallet:${wallet.id}`;
    const data = {
      balance: wallet.balance,
      creditLimit: wallet.creditLimit,
      status: wallet.status,
      userId: wallet.userId
    };

    await redis.setex(key, 3600, JSON.stringify(data));
    await redis.setex(`${key}:balance`, 300, wallet.balance);
  }

  private async updateCachedBalance(walletId: string, newBalance: number) {
    await redis.setex(`wallet:${walletId}:balance`, 300, newBalance);
  }

  private async sendTransactionNotification(userId: string, transaction: any) {
    // In production, integrate with notification service
    logger.info('Transaction notification queued', {
      userId,
      transactionId: transaction.transactionId
    });
  }
}