import { Router } from 'express';
import { ChatbotController } from '../controllers/ChatbotController';

const router = Router();
const chatbotController = new ChatbotController();

// Session management
router.post('/sessions/start', chatbotController.startSession.bind(chatbotController));
router.delete('/sessions/:sessionId/end', chatbotController.endSession.bind(chatbotController));
router.get('/sessions/:sessionId/history', chatbotController.getSessionHistory.bind(chatbotController));
router.get('/sessions/:sessionId/export', chatbotController.exportConversation.bind(chatbotController));

// Messaging
router.post('/message', chatbotController.sendMessage.bind(chatbotController));
router.post('/message/stream', chatbotController.streamMessage.bind(chatbotController));

// Admin
router.get('/sessions', chatbotController.getActiveSessions.bind(chatbotController));
router.post('/sessions/cleanup', chatbotController.cleanupSessions.bind(chatbotController));

export default router;