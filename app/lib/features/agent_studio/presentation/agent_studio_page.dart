import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/agent_studio/data/agent_providers.dart';
import 'package:starpath/features/agent_studio/domain/agent_model.dart';
import 'package:starpath/features/chat/data/chat_providers.dart';
import 'package:starpath/shared/widgets/aura_avatar.dart';
import 'package:starpath/shared/widgets/frosted_card.dart';

Color _hexToColor(String hex) {
  hex = hex.replaceFirst('#', '');
  return Color(int.parse('FF$hex', radix: 16));
}

class AgentStudioPage extends ConsumerWidget {
  const AgentStudioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(myAgentsProvider);

    return Scaffold(
      backgroundColor: StarpathColors.background,
      appBar: AppBar(
        title: const Text('我的伙伴'),
        actions: [
          IconButton(
            icon: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                gradient: StarpathColors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 18),
            ),
            onPressed: () async {
              await context.push('/agents/create');
              // Refresh list after returning from create page
              ref.invalidate(myAgentsProvider);
            },
          ),
        ],
      ),
      body: agentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildEmptyState(context),
        data: (agents) => agents.isEmpty
            ? _buildEmptyState(context)
            : _buildAgentList(context, ref, agents),
      ),
    );
  }

  Widget _buildAgentList(
      BuildContext context, WidgetRef ref, List<AgentModel> agents) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: agents.length,
      itemBuilder: (context, index) {
        final agent = agents[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _AgentCard(agent: agent),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AuraAvatar(
            fallbackEmoji: '✨',
            size: 80,
            gradientColors: const [
              StarpathColors.brandPurple,
              StarpathColors.brandBlue,
            ],
            state: CompanionState.sleeping,
          ),
          const SizedBox(height: 24),
          Text('还没有AI伙伴',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('创建你的第一个AI伙伴，开启奇妙旅程',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () => context.push('/agents/create'),
            child: FrostedCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              child: ShaderMask(
                shaderCallback: (bounds) =>
                    StarpathColors.brandGradient.createShader(bounds),
                child: const Text(
                  '创建AI伙伴',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentCard extends ConsumerWidget {
  final AgentModel agent;

  const _AgentCard({required this.agent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradStart = _hexToColor(agent.gradientStart);
    final gradEnd = _hexToColor(agent.gradientEnd);

    return GestureDetector(
      onTap: () async {
        try {
          final repo = ref.read(chatRepositoryProvider);
          final conv = await repo.createConversation(agent.id);
          if (context.mounted) {
            ref.invalidate(conversationsProvider);
            context.push('/chat/${conv.id}');
          }
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('启动对话失败，请确认后端服务正在运行')),
            );
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradStart.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Gradient left accent bar
            Container(
              width: 6,
              height: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [gradStart, gradEnd],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
            ),
            const SizedBox(width: 14),
            AuraAvatar(
              fallbackEmoji: agent.emoji,
              size: 52,
              gradientColors: [gradStart, gradEnd],
              state: CompanionState.active,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    agent.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    agent.bio.isNotEmpty ? agent.bio : agent.personality.join(' · '),
                    style: TextStyle(
                      fontSize: 13,
                      color: StarpathColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: agent.personality.take(3).map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: gradStart.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 11,
                            color: gradStart,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [gradStart, gradEnd]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                '聊天',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
