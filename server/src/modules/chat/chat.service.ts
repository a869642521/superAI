import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { MessageRole } from '@prisma/client';

@Injectable()
export class ChatService {
  constructor(private readonly prisma: PrismaService) {}

  async createConversation(userId: string, agentId: string) {
    const agent = await this.prisma.agent.findUnique({ where: { id: agentId } });
    if (!agent) throw new NotFoundException('Agent not found');

    return this.prisma.conversation.create({
      data: {
        userId,
        agentId,
        title: `与 ${agent.name} 的对话`,
      },
      include: { agent: true },
    });
  }

  async getConversations(userId: string) {
    return this.prisma.conversation.findMany({
      where: { userId },
      include: {
        agent: { select: { id: true, name: true, emoji: true, gradientStart: true, gradientEnd: true } },
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1,
          select: { content: true, createdAt: true, role: true },
        },
      },
      orderBy: { lastMessageAt: 'desc' },
    });
  }

  async getMessages(conversationId: string, cursor?: string, limit = 30) {
    const where: any = { conversationId };
    if (cursor) {
      where.createdAt = { lt: new Date(cursor) };
    }

    return this.prisma.message.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }

  async saveMessage(conversationId: string, role: MessageRole, content: string) {
    const message = await this.prisma.message.create({
      data: { conversationId, role, content },
    });

    await this.prisma.conversation.update({
      where: { id: conversationId },
      data: { lastMessageAt: new Date() },
    });

    return message;
  }

  async getConversationWithAgent(conversationId: string) {
    const conversation = await this.prisma.conversation.findUnique({
      where: { id: conversationId },
      include: { agent: true },
    });
    if (!conversation) throw new NotFoundException('Conversation not found');
    return conversation;
  }

  async getRecentMessagesForContext(conversationId: string, limit = 20) {
    const messages = await this.prisma.message.findMany({
      where: { conversationId },
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: { role: true, content: true },
    });
    return messages.reverse();
  }
}
