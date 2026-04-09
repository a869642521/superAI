import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CardType } from '@prisma/client';
import { CurrencyService } from '../currency/currency.service';

@Injectable()
export class ContentService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly currencyService: CurrencyService,
  ) {}

  async createCard(
    userId: string,
    data: {
      type: CardType;
      title: string;
      content: string;
      imageUrls?: string[];
      agentId?: string;
    },
  ) {
    const card = await this.prisma.contentCard.create({
      data: {
        userId,
        agentId: data.agentId,
        type: data.type,
        title: data.title,
        content: data.content,
        imageUrls: data.imageUrls || [],
        isPublished: true,
      },
      include: {
        user: { select: { id: true, nickname: true, avatarUrl: true } },
        agent: { select: { id: true, name: true, emoji: true, gradientStart: true, gradientEnd: true } },
      },
    });

    await this.currencyService.earnFromPublish(userId);

    return card;
  }

  async getFeed(cursor?: string, limit = 20) {
    const where: any = { isPublished: true, deletedAt: null };
    if (cursor) {
      where.createdAt = { lt: new Date(cursor) };
    }

    return this.prisma.contentCard.findMany({
      where,
      include: {
        user: { select: { id: true, nickname: true, avatarUrl: true } },
        agent: { select: { id: true, name: true, emoji: true, gradientStart: true, gradientEnd: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }

  async getCardById(id: string) {
    const card = await this.prisma.contentCard.findUnique({
      where: { id, deletedAt: null },
      include: {
        user: { select: { id: true, nickname: true, avatarUrl: true } },
        agent: { select: { id: true, name: true, emoji: true, gradientStart: true, gradientEnd: true } },
        comments: {
          include: {
            user: { select: { id: true, nickname: true, avatarUrl: true } },
          },
          orderBy: { createdAt: 'desc' },
          take: 50,
        },
      },
    });
    if (!card) throw new NotFoundException('Card not found');
    return card;
  }

  async likeCard(userId: string, cardId: string) {
    const existing = await this.prisma.like.findUnique({
      where: { userId_cardId: { userId, cardId } },
    });
    if (existing) throw new ConflictException('Already liked');

    await this.prisma.$transaction([
      this.prisma.like.create({ data: { userId, cardId } }),
      this.prisma.contentCard.update({
        where: { id: cardId },
        data: { likeCount: { increment: 1 } },
      }),
    ]);

    const card = await this.prisma.contentCard.findUnique({ where: { id: cardId } });
    if (card) {
      await this.currencyService.earnFromLike(card.userId);
    }

    return { liked: true };
  }

  async unlikeCard(userId: string, cardId: string) {
    await this.prisma.$transaction([
      this.prisma.like.delete({
        where: { userId_cardId: { userId, cardId } },
      }),
      this.prisma.contentCard.update({
        where: { id: cardId },
        data: { likeCount: { decrement: 1 } },
      }),
    ]);
    return { liked: false };
  }

  async addComment(userId: string, cardId: string, content: string) {
    const comment = await this.prisma.comment.create({
      data: { userId, cardId, content },
      include: {
        user: { select: { id: true, nickname: true, avatarUrl: true } },
      },
    });

    await this.prisma.contentCard.update({
      where: { id: cardId },
      data: { commentCount: { increment: 1 } },
    });

    const card = await this.prisma.contentCard.findUnique({ where: { id: cardId } });
    if (card) {
      await this.currencyService.earnFromComment(card.userId);
    }

    return comment;
  }

  async getUserCards(userId: string) {
    return this.prisma.contentCard.findMany({
      where: { userId, deletedAt: null },
      include: {
        agent: { select: { id: true, name: true, emoji: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }
}
