import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { ChatService } from './chat.service';
import { CurrencyService } from '../currency/currency.service';
import { MessageRole } from '@prisma/client';

@WebSocketGateway({
  cors: { origin: '*' },
  namespace: '/chat',
})
export class ChatGateway {
  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly chatService: ChatService,
    private readonly currencyService: CurrencyService,
  ) {}

  @SubscribeMessage('sendMessage')
  async handleMessage(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    data: { conversationId: string; content: string; userId: string },
  ) {
    const { conversationId, content, userId } = data;

    await this.chatService.saveMessage(
      conversationId,
      MessageRole.user,
      content,
    );

    // Check and deduct currency for messages beyond free tier
    try {
      await this.currencyService.handleMessageCost(userId);
    } catch {
      client.emit('error', { message: '灵感币不足，请先发布内容赚取灵感币' });
      return;
    }

    const conversation =
      await this.chatService.getConversationWithAgent(conversationId);
    const recentMessages =
      await this.chatService.getRecentMessagesForContext(conversationId);

    // Call AI service via HTTP
    try {
      const aiServiceUrl = process.env.AI_SERVICE_URL || 'http://localhost:8000';
      const response = await fetch(`${aiServiceUrl}/chat/completions`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          agent_id: conversation.agentId,
          system_prompt: conversation.agent.systemPrompt,
          messages: recentMessages.map((m) => ({
            role: m.role,
            content: m.content,
          })),
          stream: true,
        }),
      });

      if (!response.ok || !response.body) {
        throw new Error('AI service error');
      }

      let fullContent = '';
      const reader = response.body.getReader();
      const decoder = new TextDecoder();

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        const chunk = decoder.decode(value, { stream: true });
        const lines = chunk.split('\n').filter((l) => l.startsWith('data: '));

        for (const line of lines) {
          const jsonStr = line.slice(6);
          if (jsonStr === '[DONE]') continue;

          try {
            const parsed = JSON.parse(jsonStr);
            if (parsed.error) {
              client.emit('error', { message: parsed.error });
              return;
            }
            const delta = parsed.choices?.[0]?.delta ?? {};
            // Thinking phase
            if (delta.thinking) {
              client.emit('thinkingChunk', { conversationId, token: delta.thinking });
            }
            // Actual response
            if (delta.content) {
              fullContent += delta.content;
              client.emit('messageChunk', { conversationId, token: delta.content });
            }
          } catch {
            // skip malformed chunks
          }
        }
      }

      if (fullContent) {
        await this.chatService.saveMessage(
          conversationId,
          MessageRole.assistant,
          fullContent,
        );
      }

      client.emit('messageComplete', { conversationId });
    } catch (error) {
      client.emit('error', {
        message: 'AI 服务暂时不可用，请稍后再试',
      });
    }
  }
}
