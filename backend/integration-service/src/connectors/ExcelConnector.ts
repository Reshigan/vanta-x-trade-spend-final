import * as XLSX from 'xlsx';
import { Readable } from 'stream';
import { Logger } from 'winston';
import { createLogger } from '../utils/logger';
import * as fs from 'fs/promises';
import * as path from 'path';

export interface ExcelImportResult {
  success: boolean;
  totalRows: number;
  processedRows: number;
  errors: Array<{
    row: number;
    field: string;
    message: string;
  }>;
  data: any[];
}

export interface ExcelTemplate {
  name: string;
  sheets: Array<{
    name: string;
    columns: Array<{
      field: string;
      header: string;
      type: 'string' | 'number' | 'date' | 'boolean';
      required: boolean;
      format?: string;
      validation?: {
        min?: number;
        max?: number;
        pattern?: string;
        values?: string[];
      };
    }>;
    sampleData?: any[];
  }>;
}

export class ExcelConnector {
  private logger: Logger;
  private templates: Map<string, ExcelTemplate>;

  constructor() {
    this.logger = createLogger('ExcelConnector');
    this.templates = new Map();
    this.initializeTemplates();
  }

  private initializeTemplates(): void {
    // Trade Spend Import Template
    this.templates.set('trade-spend', {
      name: 'Trade Spend Import Template',
      sheets: [{
        name: 'Trade Spend Data',
        columns: [
          { field: 'promotionId', header: 'Promotion ID', type: 'string', required: true },
          { field: 'promotionName', header: 'Promotion Name', type: 'string', required: true },
          { field: 'customerCode', header: 'Customer Code', type: 'string', required: true },
          { field: 'customerName', header: 'Customer Name', type: 'string', required: true },
          { field: 'startDate', header: 'Start Date', type: 'date', required: true, format: 'DD/MM/YYYY' },
          { field: 'endDate', header: 'End Date', type: 'date', required: true, format: 'DD/MM/YYYY' },
          { field: 'plannedSpend', header: 'Planned Spend', type: 'number', required: true },
          { field: 'actualSpend', header: 'Actual Spend', type: 'number', required: false },
          { field: 'currency', header: 'Currency', type: 'string', required: true, validation: { values: ['USD', 'EUR', 'GBP', 'ZAR'] } },
          { field: 'status', header: 'Status', type: 'string', required: true, validation: { values: ['Planned', 'Active', 'Completed', 'Cancelled'] } },
          { field: 'productCategory', header: 'Product Category', type: 'string', required: true },
          { field: 'storeType', header: 'Store Type', type: 'string', required: true },
          { field: 'region', header: 'Region', type: 'string', required: true },
          { field: 'discountType', header: 'Discount Type', type: 'string', required: true },
          { field: 'discountValue', header: 'Discount Value', type: 'number', required: true },
        ],
        sampleData: [
          {
            promotionId: 'PROMO-2025-001',
            promotionName: 'Summer Sale 2025',
            customerCode: 'CUST001',
            customerName: 'Diplomat SA',
            startDate: '01/06/2025',
            endDate: '30/06/2025',
            plannedSpend: 50000,
            actualSpend: 0,
            currency: 'ZAR',
            status: 'Planned',
            productCategory: 'Beverages',
            storeType: 'Hypermarket',
            region: 'Gauteng',
            discountType: 'Percentage',
            discountValue: 15,
          },
        ],
      }],
    });

    // Store Master Data Template
    this.templates.set('stores', {
      name: 'Store Master Data Template',
      sheets: [{
        name: 'Stores',
        columns: [
          { field: 'storeCode', header: 'Store Code', type: 'string', required: true },
          { field: 'storeName', header: 'Store Name', type: 'string', required: true },
          { field: 'storeType', header: 'Store Type', type: 'string', required: true, validation: { values: ['Hypermarket', 'Supermarket', 'Convenience', 'Wholesale'] } },
          { field: 'region', header: 'Region', type: 'string', required: true },
          { field: 'province', header: 'Province', type: 'string', required: true },
          { field: 'city', header: 'City', type: 'string', required: true },
          { field: 'address', header: 'Address', type: 'string', required: true },
          { field: 'postalCode', header: 'Postal Code', type: 'string', required: true },
          { field: 'latitude', header: 'Latitude', type: 'number', required: false },
          { field: 'longitude', header: 'Longitude', type: 'number', required: false },
          { field: 'managerName', header: 'Store Manager', type: 'string', required: false },
          { field: 'contactNumber', header: 'Contact Number', type: 'string', required: true },
          { field: 'email', header: 'Email', type: 'string', required: false },
          { field: 'openingDate', header: 'Opening Date', type: 'date', required: false, format: 'DD/MM/YYYY' },
          { field: 'status', header: 'Status', type: 'string', required: true, validation: { values: ['Active', 'Inactive', 'Closed'] } },
        ],
      }],
    });

    // Product Master Data Template
    this.templates.set('products', {
      name: 'Product Master Data Template',
      sheets: [{
        name: 'Products',
        columns: [
          { field: 'productCode', header: 'Product Code', type: 'string', required: true },
          { field: 'barcode', header: 'Barcode', type: 'string', required: true },
          { field: 'productName', header: 'Product Name', type: 'string', required: true },
          { field: 'brand', header: 'Brand', type: 'string', required: true },
          { field: 'category', header: 'Category', type: 'string', required: true },
          { field: 'subCategory', header: 'Sub-Category', type: 'string', required: true },
          { field: 'unitSize', header: 'Unit Size', type: 'string', required: true },
          { field: 'unitOfMeasure', header: 'Unit of Measure', type: 'string', required: true },
          { field: 'packSize', header: 'Pack Size', type: 'number', required: true },
          { field: 'costPrice', header: 'Cost Price', type: 'number', required: true },
          { field: 'sellingPrice', header: 'Selling Price', type: 'number', required: true },
          { field: 'vatRate', header: 'VAT Rate %', type: 'number', required: true },
          { field: 'supplier', header: 'Supplier', type: 'string', required: true },
          { field: 'status', header: 'Status', type: 'string', required: true, validation: { values: ['Active', 'Discontinued', 'Seasonal'] } },
        ],
      }],
    });

    // Promotion Performance Template
    this.templates.set('promotion-performance', {
      name: 'Promotion Performance Template',
      sheets: [{
        name: 'Performance Data',
        columns: [
          { field: 'promotionId', header: 'Promotion ID', type: 'string', required: true },
          { field: 'storeCode', header: 'Store Code', type: 'string', required: true },
          { field: 'productCode', header: 'Product Code', type: 'string', required: true },
          { field: 'date', header: 'Date', type: 'date', required: true, format: 'DD/MM/YYYY' },
          { field: 'baselineUnits', header: 'Baseline Units', type: 'number', required: true },
          { field: 'promotedUnits', header: 'Promoted Units', type: 'number', required: true },
          { field: 'incrementalUnits', header: 'Incremental Units', type: 'number', required: true },
          { field: 'baselineRevenue', header: 'Baseline Revenue', type: 'number', required: true },
          { field: 'promotedRevenue', header: 'Promoted Revenue', type: 'number', required: true },
          { field: 'incrementalRevenue', header: 'Incremental Revenue', type: 'number', required: true },
          { field: 'tradeSpend', header: 'Trade Spend', type: 'number', required: true },
          { field: 'roi', header: 'ROI %', type: 'number', required: true },
          { field: 'uplift', header: 'Uplift %', type: 'number', required: true },
        ],
      }],
    });
  }

  async generateTemplate(templateType: string): Promise<Buffer> {
    const template = this.templates.get(templateType);
    if (!template) {
      throw new Error(`Template type '${templateType}' not found`);
    }

    const workbook = XLSX.utils.book_new();

    for (const sheet of template.sheets) {
      // Create headers
      const headers = sheet.columns.map(col => col.header);
      const worksheetData = [headers];

      // Add sample data if provided
      if (sheet.sampleData) {
        for (const sample of sheet.sampleData) {
          const row = sheet.columns.map(col => sample[col.field] || '');
          worksheetData.push(row);
        }
      }

      // Create worksheet
      const worksheet = XLSX.utils.aoa_to_sheet(worksheetData);

      // Apply column widths
      const colWidths = sheet.columns.map(col => ({ wch: Math.max(col.header.length, 15) }));
      worksheet['!cols'] = colWidths;

      // Add data validation comments
      sheet.columns.forEach((col, index) => {
        const cellAddress = XLSX.utils.encode_cell({ r: 0, c: index });
        if (!worksheet[cellAddress].c) worksheet[cellAddress].c = [];
        
        let comment = `Type: ${col.type}\nRequired: ${col.required ? 'Yes' : 'No'}`;
        if (col.format) comment += `\nFormat: ${col.format}`;
        if (col.validation?.values) comment += `\nAllowed values: ${col.validation.values.join(', ')}`;
        
        worksheet[cellAddress].c.push({
          a: 'Vanta X System',
          t: comment,
        });
      });

      XLSX.utils.book_append_sheet(workbook, worksheet, sheet.name);
    }

    // Add instructions sheet
    const instructionsData = [
      ['Vanta X - Trade Spend Import Instructions'],
      [''],
      ['Template: ' + template.name],
      ['Generated: ' + new Date().toISOString()],
      [''],
      ['Instructions:'],
      ['1. Fill in the data in the respective sheets'],
      ['2. Ensure all required fields are populated'],
      ['3. Follow the format specified in column headers'],
      ['4. Save the file and upload through the import interface'],
      [''],
      ['Field Descriptions:'],
    ];

    for (const sheet of template.sheets) {
      instructionsData.push(['']);
      instructionsData.push([`Sheet: ${sheet.name}`]);
      for (const col of sheet.columns) {
        let description = `${col.header}: ${col.type} field`;
        if (col.required) description += ' (Required)';
        if (col.format) description += ` - Format: ${col.format}`;
        if (col.validation?.values) description += ` - Values: ${col.validation.values.join(', ')}`;
        instructionsData.push([description]);
      }
    }

    const instructionsSheet = XLSX.utils.aoa_to_sheet(instructionsData);
    instructionsSheet['!cols'] = [{ wch: 100 }];
    XLSX.utils.book_append_sheet(workbook, instructionsSheet, 'Instructions');

    return XLSX.write(workbook, { type: 'buffer', bookType: 'xlsx' });
  }

  async importFile(buffer: Buffer, templateType: string): Promise<ExcelImportResult> {
    const template = this.templates.get(templateType);
    if (!template) {
      throw new Error(`Template type '${templateType}' not found`);
    }

    const result: ExcelImportResult = {
      success: false,
      totalRows: 0,
      processedRows: 0,
      errors: [],
      data: [],
    };

    try {
      const workbook = XLSX.read(buffer, { type: 'buffer', cellDates: true });
      
      for (const sheetTemplate of template.sheets) {
        const worksheet = workbook.Sheets[sheetTemplate.name];
        if (!worksheet) {
          result.errors.push({
            row: 0,
            field: 'sheet',
            message: `Sheet '${sheetTemplate.name}' not found`,
          });
          continue;
        }

        const jsonData = XLSX.utils.sheet_to_json(worksheet, { 
          header: sheetTemplate.columns.map(col => col.field),
          range: 1, // Skip header row
          dateNF: 'dd/mm/yyyy',
        });

        result.totalRows += jsonData.length;

        for (let rowIndex = 0; rowIndex < jsonData.length; rowIndex++) {
          const row = jsonData[rowIndex] as any;
          const validatedRow: any = {};
          let hasError = false;

          for (const column of sheetTemplate.columns) {
            const value = row[column.field];
            const validation = this.validateField(value, column, rowIndex + 2); // +2 for 1-based index and header

            if (validation.error) {
              result.errors.push(validation.error);
              hasError = true;
            } else {
              validatedRow[column.field] = validation.value;
            }
          }

          if (!hasError) {
            result.data.push({
              ...validatedRow,
              _sheet: sheetTemplate.name,
              _row: rowIndex + 2,
            });
            result.processedRows++;
          }
        }
      }

      result.success = result.errors.length === 0;
      return result;
    } catch (error) {
      this.logger.error('Excel import failed:', error);
      result.errors.push({
        row: 0,
        field: 'file',
        message: `Import failed: ${error}`,
      });
      return result;
    }
  }

  private validateField(value: any, column: any, row: number): { value?: any; error?: any } {
    // Check required fields
    if (column.required && (value === undefined || value === null || value === '')) {
      return {
        error: {
          row,
          field: column.field,
          message: `${column.header} is required`,
        },
      };
    }

    // Skip validation for empty optional fields
    if (!column.required && (value === undefined || value === null || value === '')) {
      return { value: null };
    }

    // Type validation
    switch (column.type) {
      case 'number':
        const numValue = Number(value);
        if (isNaN(numValue)) {
          return {
            error: {
              row,
              field: column.field,
              message: `${column.header} must be a number`,
            },
          };
        }
        if (column.validation?.min !== undefined && numValue < column.validation.min) {
          return {
            error: {
              row,
              field: column.field,
              message: `${column.header} must be at least ${column.validation.min}`,
            },
          };
        }
        if (column.validation?.max !== undefined && numValue > column.validation.max) {
          return {
            error: {
              row,
              field: column.field,
              message: `${column.header} must be at most ${column.validation.max}`,
            },
          };
        }
        return { value: numValue };

      case 'date':
        const dateValue = this.parseDate(value);
        if (!dateValue) {
          return {
            error: {
              row,
              field: column.field,
              message: `${column.header} must be a valid date (${column.format || 'DD/MM/YYYY'})`,
            },
          };
        }
        return { value: dateValue };

      case 'boolean':
        const boolValue = String(value).toLowerCase();
        if (!['true', 'false', '1', '0', 'yes', 'no'].includes(boolValue)) {
          return {
            error: {
              row,
              field: column.field,
              message: `${column.header} must be true/false, yes/no, or 1/0`,
            },
          };
        }
        return { value: ['true', '1', 'yes'].includes(boolValue) };

      case 'string':
      default:
        const strValue = String(value).trim();
        if (column.validation?.values && !column.validation.values.includes(strValue)) {
          return {
            error: {
              row,
              field: column.field,
              message: `${column.header} must be one of: ${column.validation.values.join(', ')}`,
            },
          };
        }
        if (column.validation?.pattern) {
          const regex = new RegExp(column.validation.pattern);
          if (!regex.test(strValue)) {
            return {
              error: {
                row,
                field: column.field,
                message: `${column.header} format is invalid`,
              },
            };
          }
        }
        return { value: strValue };
    }
  }

  private parseDate(value: any): Date | null {
    if (value instanceof Date) {
      return value;
    }
    
    if (typeof value === 'number') {
      // Excel serial date
      return new Date((value - 25569) * 86400 * 1000);
    }
    
    if (typeof value === 'string') {
      // Try parsing DD/MM/YYYY format
      const parts = value.split('/');
      if (parts.length === 3) {
        const date = new Date(parseInt(parts[2]), parseInt(parts[1]) - 1, parseInt(parts[0]));
        if (!isNaN(date.getTime())) {
          return date;
        }
      }
      
      // Try standard date parsing
      const date = new Date(value);
      if (!isNaN(date.getTime())) {
        return date;
      }
    }
    
    return null;
  }

  async exportData(data: any[], templateType: string, options?: {
    includeHeaders?: boolean;
    dateFormat?: string;
  }): Promise<Buffer> {
    const template = this.templates.get(templateType);
    if (!template) {
      throw new Error(`Template type '${templateType}' not found`);
    }

    const workbook = XLSX.utils.book_new();
    
    for (const sheet of template.sheets) {
      const sheetData = data.filter(item => !item._sheet || item._sheet === sheet.name);
      
      const worksheetData = [];
      
      // Add headers if requested
      if (options?.includeHeaders !== false) {
        worksheetData.push(sheet.columns.map(col => col.header));
      }
      
      // Add data rows
      for (const item of sheetData) {
        const row = sheet.columns.map(col => {
          const value = item[col.field];
          if (col.type === 'date' && value) {
            return this.formatDate(value, options?.dateFormat || col.format || 'DD/MM/YYYY');
          }
          return value ?? '';
        });
        worksheetData.push(row);
      }
      
      const worksheet = XLSX.utils.aoa_to_sheet(worksheetData);
      
      // Apply column widths
      const colWidths = sheet.columns.map(col => ({ wch: Math.max(col.header.length, 15) }));
      worksheet['!cols'] = colWidths;
      
      XLSX.utils.book_append_sheet(workbook, worksheet, sheet.name);
    }
    
    return XLSX.write(workbook, { type: 'buffer', bookType: 'xlsx' });
  }

  private formatDate(date: Date | string, format: string): string {
    const d = typeof date === 'string' ? new Date(date) : date;
    
    const day = String(d.getDate()).padStart(2, '0');
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const year = d.getFullYear();
    
    return format
      .replace('DD', day)
      .replace('MM', month)
      .replace('YYYY', String(year))
      .replace('YY', String(year).slice(-2));
  }
}