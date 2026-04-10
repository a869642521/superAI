import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/chat/data/chat_providers.dart';
import 'package:starpath/features/chat/domain/chat_model.dart';
import 'package:starpath/shared/widgets/aura_avatar.dart';

Color _hexColor(String hex) {
  hex = hex.replaceFirst('#', '');
  return Color(int.parse('FF$hex', radix: 16));
}

String _formatTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
  if (diff.inDays < 1) return '${diff.inHours}小时前';
  return DateFormat('MM/dd').format(dt);
}

class ChatListPage extends ConsumerWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: StarpathColors.surface,
      appBar: AppBar(title: const Text('对话')),
      body: conversationsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: StarpathColors.primary),
        ),
        error: (_, __) => _buildEmptyState(context),
        data: (conversations) => conversations.isEmpty
            ? _buildEmptyState(context)
            : _buildList(context, conversations),
      ),
    );
  }

  Widget _buildList(
      BuildContext context, List<ConversationModel> conversations) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: conversations.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _ConversationTile(conversation: conversations[i]),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: StarpathColors.surfaceContainerHigh,
              shape: BoxShape.circle,
              border: Border.all(
                  color: StarpathColors.outlineVariant, width: 1),
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                size: 36, color: StarpathColors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Text('还没有对话',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            '先去创建一个AI伙伴再开始聊天',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: () => context.go('/agents'),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(
                    color: StarpathColors.primary.withValues(alpha: 0.5),
                    width: 1.5),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '去创建伙伴 →',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: StarpathColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  final ConversationModel conversation;
  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agent = conversation.agent;
    final gradStart = _hexColor(agent.gradientStart);
    final gradEnd = _hexColor(agent.gradientEnd);
    final lastMsg = conversation.lastMessage;

    return GestureDetector(
      onTap: () => context.push('/chat/${conversation.id}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: StarpathColors.surfaceContainer.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: StarpathColors.outlineVariant,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                AuraAvatar(
                  fallbackEmoji: agent.emoji,
                  size: 48,
                  gradientColors: [gradStart, gradEnd],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            agent.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: StarpathColors.onSurface,
                            ),
                          ),
                          Text(
                            _formatTime(conversation.lastMessageAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: StarpathColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lastMsg?.content ?? '开始聊天吧 ✨',
                        style: const TextStyle(
                          fontSize: 13,
                          color: StarpathColors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget to start a new conversation with an agent and navigate to it
class StartChatButton extends ConsumerWidget {
  final String agentId;
  final String label;

  const StartChatButton(
      {super.key, required this.agentId, required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        final repo = ref.read(chatRepositoryProvider);
        final conv = await repo.createConversation(agentId);
        if (context.mounted) {
          ref.invalidate(conversationsProvider);
          context.push('/chat/${conv.id}');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          gradient: StarpathColors.primaryGradient,
          borderRadius: BorderRadius.circular(100),
          boxShadow: [
            BoxShadow(
              color: StarpathColors.primary.withValues(alpha: 0.30),
              blurRadius: 16,
              spreadRadius: -3,
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: StarpathColors.onPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
