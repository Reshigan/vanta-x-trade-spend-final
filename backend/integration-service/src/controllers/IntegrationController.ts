import { Request, Response } from 'express';
import { SAPConnector, SAPConfig } from '../connectors/SAPConnector';
import { ExcelConnector } from '../connectors/ExcelConnector';
import { createLogger } from '../utils/logger';
import multer from 'multer';
import { Readable } from 'stream';

const logger = createLogger('IntegrationController');
const upload = multer({ 
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 50 * 1024 * 1024, // 50MB limit
  },
});

export class IntegrationController {
  private sapConnectors: Map<string, SAPConnector> = new Map();
  private excelConnector: ExcelConnector;

  constructor() {
    this.excelConnector = new ExcelConnector();
  }

  // SAP Integration Methods
  async testSAPConnection(req: Request, res: Response): Promise<void> {
    try {
      const config: SAPConfig = req.body;
      const connector = new SAPConnector(config);
      
      const isConnected = await connector.testConnection();
      
      if (isConnected) {
        // Store connector for reuse
        const connectionId = `${config.baseUrl}_${config.client}`;
        this.sapConnectors.set(connectionId, connector);
        
        res.json({
          success: true,
          message: 'SAP connection successful',
          connectionId,
        });
      } else {
        res.status(400).json({
          success: false,
          message: 'SAP connection failed',
        });
      }
    } catch (error) {
      logger.error('SAP connection test failed:', error);
      res.status(500).json({
        success: false,
        message: 'SAP connection test failed',
        error: error.message,
      });
    }
  }

  async importFromSAP(req: Request, res: Response): Promise<void> {
    try {
      const { connectionId, importType, params } = req.body;
      
      const connector = this.sapConnectors.get(connectionId);
      if (!connector) {
        res.status(400).json({
          success: false,
          message: 'SAP connection not found. Please test connection first.',
        });
        return;
      }

      let data: any[];
      
      switch (importType) {
        case 'tradeSpend':
          data = await connector.fetchTradeSpendData(params);
          break;
        case 'promotions':
          data = await connector.fetchPromotions(params);
          break;
        case 'customers':
        case 'products':
        case 'stores':
          data = await connector.fetchMasterData(importType);
          break;
        default:
          res.status(400).json({
            success: false,
            message: `Invalid import type: ${importType}`,
          });
          return;
      }

      res.json({
        success: true,
        message: `Successfully imported ${data.length} records from SAP`,
        data,
        count: data.length,
      });
    } catch (error) {
      logger.error('SAP import failed:', error);
      res.status(500).json({
        success: false,
        message: 'SAP import failed',
        error: error.message,
      });
    }
  }

  // Excel Import/Export Methods
  async downloadTemplate(req: Request, res: Response): Promise<void> {
    try {
      const { templateType } = req.params;
      
      const buffer = await this.excelConnector.generateTemplate(templateType);
      
      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      res.setHeader('Content-Disposition', `attachment; filename="vanta-x-${templateType}-template.xlsx"`);
      res.send(buffer);
    } catch (error) {
      logger.error('Template generation failed:', error);
      res.status(500).json({
        success: false,
        message: 'Template generation failed',
        error: error.message,
      });
    }
  }

  async importExcel(req: Request, res: Response): Promise<void> {
    try {
      if (!req.file) {
        res.status(400).json({
          success: false,
          message: 'No file uploaded',
        });
        return;
      }

      const { templateType } = req.body;
      const result = await this.excelConnector.importFile(req.file.buffer, templateType);
      
      if (result.success) {
        // Here you would typically save the data to your database
        // For now, we'll just return the parsed data
        res.json({
          success: true,
          message: `Successfully imported ${result.processedRows} of ${result.totalRows} rows`,
          data: result.data,
          processedRows: result.processedRows,
          totalRows: result.totalRows,
        });
      } else {
        res.status(400).json({
          success: false,
          message: 'Import completed with errors',
          errors: result.errors,
          processedRows: result.processedRows,
          totalRows: result.totalRows,
          data: result.data,
        });
      }
    } catch (error) {
      logger.error('Excel import failed:', error);
      res.status(500).json({
        success: false,
        message: 'Excel import failed',
        error: error.message,
      });
    }
  }

  async exportToExcel(req: Request, res: Response): Promise<void> {
    try {
      const { templateType, data, options } = req.body;
      
      const buffer = await this.excelConnector.exportData(data, templateType, options);
      
      res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      res.setHeader('Content-Disposition', `attachment; filename="vanta-x-${templateType}-export-${Date.now()}.xlsx"`);
      res.send(buffer);
    } catch (error) {
      logger.error('Excel export failed:', error);
      res.status(500).json({
        success: false,
        message: 'Excel export failed',
        error: error.message,
      });
    }
  }

  // Batch Import Methods
  async batchImport(req: Request, res: Response): Promise<void> {
    try {
      const { source, config, importTypes } = req.body;
      const results = [];

      if (source === 'sap') {
        const connector = new SAPConnector(config);
        const isConnected = await connector.testConnection();
        
        if (!isConnected) {
          res.status(400).json({
            success: false,
            message: 'Failed to connect to SAP',
          });
          return;
        }

        for (const importType of importTypes) {
          try {
            let data: any[];
            
            switch (importType.type) {
              case 'tradeSpend':
                data = await connector.fetchTradeSpendData(importType.params || {});
                break;
              case 'promotions':
                data = await connector.fetchPromotions(importType.params || {});
                break;
              case 'customers':
              case 'products':
              case 'stores':
                data = await connector.fetchMasterData(importType.type);
                break;
              default:
                data = [];
            }

            results.push({
              type: importType.type,
              success: true,
              count: data.length,
              data,
            });
          } catch (error) {
            results.push({
              type: importType.type,
              success: false,
              error: error.message,
            });
          }
        }
      }

      res.json({
        success: true,
        message: 'Batch import completed',
        results,
      });
    } catch (error) {
      logger.error('Batch import failed:', error);
      res.status(500).json({
        success: false,
        message: 'Batch import failed',
        error: error.message,
      });
    }
  }

  // Integration Status
  async getIntegrationStatus(req: Request, res: Response): Promise<void> {
    try {
      const status = {
        sap: {
          connected: this.sapConnectors.size > 0,
          connections: Array.from(this.sapConnectors.keys()),
        },
        excel: {
          available: true,
          templates: ['trade-spend', 'stores', 'products', 'promotion-performance'],
        },
        lastSync: {
          sap: null, // Would be fetched from database
          excel: null, // Would be fetched from database
        },
      };

      res.json({
        success: true,
        status,
      });
    } catch (error) {
      logger.error('Failed to get integration status:', error);
      res.status(500).json({
        success: false,
        message: 'Failed to get integration status',
        error: error.message,
      });
    }
  }

  // Middleware for file upload
  get uploadMiddleware() {
    return upload.single('file');
  }
}