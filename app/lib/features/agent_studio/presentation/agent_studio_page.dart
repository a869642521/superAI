import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/agent_studio/data/agent_providers.dart';
import 'package:starpath/features/agent_studio/domain/agent_model.dart';
import 'package:starpath/features/chat/data/chat_providers.dart';
import 'package:starpath/shared/widgets/aura_avatar.dart';

Color _hexColor(String hex) {
  hex = hex.replaceFirst('#', '');
  return Color(int.parse('FF$hex', radix: 16));
}

class AgentStudioPage extends ConsumerWidget {
  const AgentStudioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(myAgentsProvider);

    return Scaffold(
      backgroundColor: StarpathColors.surface,
      appBar: AppBar(
        title: const Text('我的伙伴'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () async {
                await context.push('/agents/create');
                ref.invalidate(myAgentsProvider);
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  gradient: StarpathColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33CC97FF),
                      blurRadius: 16,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded,
                    color: StarpathColors.onPrimary, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: agentsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: StarpathColors.primary),
        ),
        error: (_, __) => _buildEmptyState(context),
        data: (agents) => agents.isEmpty
            ? _buildEmptyState(context)
            : _buildList(context, ref, agents),
      ),
    );
  }

  Widget _buildList(
      BuildContext context, WidgetRef ref, List<AgentModel> agents) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: agents.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _AgentCard(agent: agents[i]),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AuraAvatar(
            fallbackEmoji: '✨',
            size: 88,
            gradientColors: const [
              StarpathColors.primary,
              StarpathColors.secondary,
            ],
            state: CompanionState.sleeping,
          ),
          const SizedBox(height: 24),
          Text('还没有AI伙伴',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            '创建你的第一个AI伙伴，开启奇妙旅程',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 36),
          GestureDetector(
            onTap: () => context.push('/agents/create'),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                gradient: StarpathColors.primaryGradient,
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: StarpathColors.primary.withValues(alpha: 0.30),
                    blurRadius: 24,
                    spreadRadius: -4,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Text(
                '创建AI伙伴',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: StarpathColors.onPrimary,
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
    final gradStart = _hexColor(agent.gradientStart);
    final gradEnd = _hexColor(agent.gradientEnd);

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
              const SnackBar(
                content: Text('启动对话失败，请确认后端服务正在运行'),
                backgroundColor: StarpathColors.surfaceContainerHigh,
              ),
            );
          }
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: StarpathColors.surfaceContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: StarpathColors.outlineVariant,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Avatar
                AuraAvatar(
                  fallbackEmoji: agent.emoji,
                  size: 56,
                  gradientColors: [gradStart, gradEnd],
                  state: CompanionState.active,
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agent.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: StarpathColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        agent.bio.isNotEmpty
                            ? agent.bio
                            : agent.personality.join(' · '),
                        style: const TextStyle(
                          fontSize: 13,
                          color: StarpathColors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: agent.personality.take(3).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: gradStart.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 11,
                                color: gradStart.withValues(alpha: 0.9) ,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Chat button
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [gradStart, gradEnd]),
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(
                        color: gradStart.withValues(alpha: 0.35),
                        blurRadius: 12,
                        spreadRadius: -2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    '聊天',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
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
