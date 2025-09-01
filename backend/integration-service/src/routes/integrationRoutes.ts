import { Router } from 'express';
import { IntegrationController } from '../controllers/IntegrationController';

const router = Router();
const controller = new IntegrationController();

// SAP Integration Routes
router.post('/sap/test-connection', controller.testSAPConnection.bind(controller));
router.post('/sap/import', controller.importFromSAP.bind(controller));

// Excel Import/Export Routes
router.get('/excel/template/:templateType', controller.downloadTemplate.bind(controller));
router.post('/excel/import', controller.uploadMiddleware, controller.importExcel.bind(controller));
router.post('/excel/export', controller.exportToExcel.bind(controller));

// Batch Operations
router.post('/batch/import', controller.batchImport.bind(controller));

// Status
router.get('/status', controller.getIntegrationStatus.bind(controller));

export default router;