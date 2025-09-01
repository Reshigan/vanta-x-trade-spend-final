import { Request, Response } from 'express';
import { VantaXAssistant, ChatContext, ChatMessage } from '../ai/chatbot/VantaXAssistant';
import { createLogger } from '../utils/logger';
import { v4 as uuidv4 } from 'uuid';

const logger = createLogger('ChatbotController');

export class ChatbotController {
  private assistant: VantaXAssistant;
  private sessions: Map<string, ChatContext> = new Map();

  constructor() {
    this.assistant = new VantaXAssistant();
    this.initialize();
  }

  private async initialize(): Promise<void> {
    try {
      await this.assistant.initialize();
      logger.info('Chatbot controller initialized');
    } catch (error) {
      logger.error('Failed to initialize chatbot:', error);
    }
  }

  async startSession(req: Request, res: Response): Promise<void> {
    try {
      const { userId, companyId, userData } = req.body;
      const sessionId = uuidv4();

      const context: ChatContext = {
        userId,
        companyId,
        sessionId,
        history: [],
        userData,
      };

      this.sessions.set(sessionId, context);

      const response = await this.assistant.startConversation(context);

      // Add to history
      context.history.push({
        role: 'assistant',
        content: response.message,
        timestamp: new Date(),
      });

      res.json({
        success: true,
        sessionId,
        response,
        timestamp: new Date().toISOString(),
      });
    } catch (error: any) {
      logger.error('Failed to start chat session:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to start chat session',
        message: error.message,
      });
    }
  }

  async sendMessage(req: Request, res: Response): Promise<void> {
    try {
      const { sessionId, message } = req.body;

      const context = this.sessions.get(sessionId);
      if (!context) {
        res.status(404).json({
          success: false,
          error: 'Session not found',
          message: 'Please start a new chat session',
        });
        return;
      }

      // Add user message to history
      context.history.push({
        role: 'user',
        content: message,
        timestamp: new Date(),
      });

      // Process message
      const response = await this.assistant.processMessage(message, context);

      // Add assistant response to history
      context.history.push({
        role: 'assistant',
        content: response.message,
        timestamp: new Date(),
      });

      // Limit history size
      if (context.history.length > 50) {
        context.history = context.history.slice(-40);
      }

      res.json({
        success: true,
        response,
        timestamp: new Date().toISOString(),
      });
    } catch (error: any) {
      logger.error('Failed to process message:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to process message',
        message: error.message,
      });
    }
  }

  async endSession(req: Request, res: Response): Promise<void> {
    try {
      const { sessionId } = req.params;

      const context = this.sessions.get(sessionId);
      if (!context) {
        res.status(404).json({
          success: false,
          error: 'Session not found',
        });
        return;
      }

      const response = await this.assistant.endConversation(context);

      // Clean up session
      this.sessions.delete(sessionId);

      res.json({
        success: true,
        response,
        timestamp: new Date().toISOString(),
      });
    } catch (error: any) {
      logger.error('Failed to end session:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to end session',
        message: error.message,
      });
    }
  }

  async getSessionHistory(req: Request, res: Response): Promise<void> {
    try {
      const { sessionId } = req.params;

      const context = this.sessions.get(sessionId);
      if (!context) {
        res.status(404).json({
          success: false,
          error: 'Session not found',
        });
        return;
      }

      res.json({
        success: true,
        sessionId,
        history: context.history,
        metadata: {
          userId: context.userId,
          companyId: context.companyId,
          messageCount: context.history.length,
          startTime: context.history[0]?.timestamp,
          lastActivity: context.history[context.history.length - 1]?.timestamp,
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error: any) {
      logger.error('Failed to get session history:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to get session history',
        message: error.message,
      });
    }
  }

  async streamMessage(req: Request, res: Response): Promise<void> {
    try {
      const { sessionId, message } = req.body;

      const context = this.sessions.get(sessionId);
      if (!context) {
        res.status(404).json({
          success: false,
          error: 'Session not found',
        });
        return;
      }

      // Set up SSE
      res.setHeader('Content-Type', 'text/event-stream');
      res.setHeader('Cache-Control', 'no-cache');
      res.setHeader('Connection', 'keep-alive');

      // Add user message to history
      context.history.push({
        role: 'user',
        content: message,
        timestamp: new Date(),
      });

      // Simulate streaming response
      const response = await this.assistant.processMessage(message, context);
      const words = response.message.split(' ');
      
      for (let i = 0; i < words.length; i++) {
        const chunk = words.slice(0, i + 1).join(' ');
        res.write(`data: ${JSON.stringify({ 
          type: 'content',
          content: chunk,
          done: i === words.length - 1,
        })}\n\n`);
        
        // Simulate typing delay
        await new Promise(resolve => setTimeout(resolve, 50));
      }

      // Send final response with suggestions and actions
      res.write(`data: ${JSON.stringify({
        type: 'complete',
        response,
      })}\n\n`);

      // Add to history
      context.history.push({
        role: 'assistant',
        content: response.message,
        timestamp: new Date(),
      });

      res.end();
    } catch (error: any) {
      logger.error('Failed to stream message:', error);
      res.write(`data: ${JSON.stringify({
        type: 'error',
        error: 'Failed to process message',
        message: error.message,
      })}\n\n`);
      res.end();
    }
  }

  async exportConversation(req: Request, res: Response): Promise<void> {
    try {
      const { sessionId } = req.params;
      const { format = 'json' } = req.query;

      const context = this.sessions.get(sessionId);
      if (!context) {
        res.status(404).json({
          success: false,
          error: 'Session not found',
        });
        return;
      }

      if (format === 'text') {
        // Export as plain text
        const text = context.history
          .map(msg => `${msg.role.toUpperCase()} [${msg.timestamp?.toISOString()}]:\n${msg.content}\n`)
          .join('\n---\n\n');

        res.setHeader('Content-Type', 'text/plain');
        res.setHeader('Content-Disposition', `attachment; filename="vanta-x-chat-${sessionId}.txt"`);
        res.send(text);
      } else if (format === 'markdown') {
        // Export as markdown
        const markdown = `# Vanta X Assistant Conversation\n\n` +
          `**Session ID:** ${sessionId}\n` +
          `**User:** ${context.userData?.name || 'Unknown'}\n` +
          `**Date:** ${new Date().toLocaleDateString()}\n\n---\n\n` +
          context.history
            .map(msg => {
              const role = msg.role === 'user' ? '👤 User' : '🤖 Assistant';
              return `### ${role}\n*${msg.timestamp?.toLocaleString()}*\n\n${msg.content}\n`;
            })
            .join('\n---\n\n');

        res.setHeader('Content-Type', 'text/markdown');
        res.setHeader('Content-Disposition', `attachment; filename="vanta-x-chat-${sessionId}.md"`);
        res.send(markdown);
      } else {
        // Export as JSON (default)
        res.setHeader('Content-Type', 'application/json');
        res.setHeader('Content-Disposition', `attachment; filename="vanta-x-chat-${sessionId}.json"`);
        res.json({
          sessionId,
          userId: context.userId,
          companyId: context.companyId,
          userData: context.userData,
          history: context.history,
          exportedAt: new Date().toISOString(),
        });
      }
    } catch (error: any) {
      logger.error('Failed to export conversation:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to export conversation',
        message: error.message,
      });
    }
  }

  // Session management
  async getActiveSessions(req: Request, res: Response): Promise<void> {
    try {
      const sessions = Array.from(this.sessions.entries()).map(([sessionId, context]) => ({
        sessionId,
        userId: context.userId,
        companyId: context.companyId,
        messageCount: context.history.length,
        startTime: context.history[0]?.timestamp,
        lastActivity: context.history[context.history.length - 1]?.timestamp,
      }));

      res.json({
        success: true,
        sessions,
        totalSessions: sessions.length,
        timestamp: new Date().toISOString(),
      });
    } catch (error: any) {
      logger.error('Failed to get active sessions:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to get active sessions',
        message: error.message,
      });
    }
  }

  async cleanupSessions(req: Request, res: Response): Promise<void> {
    try {
      const { maxAge = 3600000 } = req.body; // Default 1 hour
      const now = Date.now();
      let cleaned = 0;

      for (const [sessionId, context] of this.sessions.entries()) {
        const lastActivity = context.history[context.history.length - 1]?.timestamp;
        if (lastActivity && now - lastActivity.getTime() > maxAge) {
          this.sessions.delete(sessionId);
          cleaned++;
        }
      }

      res.json({
        success: true,
        message: `Cleaned up ${cleaned} inactive sessions`,
        remainingSessions: this.sessions.size,
        timestamp: new Date().toISOString(),
      });
    } catch (error: any) {
      logger.error('Failed to cleanup sessions:', error);
      res.status(500).json({
        success: false,
        error: 'Failed to cleanup sessions',
        message: error.message,
      });
    }
  }
}