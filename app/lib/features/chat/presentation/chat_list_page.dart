import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/chat/data/chat_providers.dart';
import 'package:starpath/features/chat/domain/chat_model.dart';
import 'package:starpath/shared/widgets/aura_avatar.dart';

Color _hexToColor(String hex) {
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
      backgroundColor: StarpathColors.background,
      appBar: AppBar(title: const Text('对话')),
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _buildEmptyState(context),
        data: (conversations) => conversations.isEmpty
            ? _buildEmptyState(context)
            : _buildList(context, ref, conversations),
      ),
    );
  }

  Widget _buildList(
      BuildContext context, WidgetRef ref, List<ConversationModel> conversations) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: conversations.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 80,
        color: StarpathColors.divider,
      ),
      itemBuilder: (context, index) {
        final conv = conversations[index];
        return _ConversationTile(conversation: conv);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 64,
              color: StarpathColors.textTertiary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('还没有对话',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('先去创建一个AI伙伴再开始聊天',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => context.go('/agents'),
            child: ShaderMask(
              shaderCallback: (bounds) =>
                  StarpathColors.brandGradient.createShader(bounds),
              child: const Text(
                '去创建伙伴 →',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
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
    final gradStart = _hexToColor(agent.gradientStart);
    final gradEnd = _hexToColor(agent.gradientEnd);
    final lastMsg = conversation.lastMessage;

    return InkWell(
      onTap: () =>
          context.push('/chat/${conversation.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            AuraAvatar(
              fallbackEmoji: agent.emoji,
              size: 48,
              gradientColors: [gradStart, gradEnd],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(agent.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(
                        _formatTime(conversation.lastMessageAt),
                        style: TextStyle(
                            fontSize: 12,
                            color: StarpathColors.textTertiary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMsg?.content ?? '开始聊天吧',
                    style: TextStyle(
                        fontSize: 14,
                        color: StarpathColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
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
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: StarpathColors.brandGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}
