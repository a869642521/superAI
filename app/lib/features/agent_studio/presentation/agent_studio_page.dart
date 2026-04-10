import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/agent_studio/data/agent_providers.dart';
import 'package:starpath/features/agent_studio/data/agent_template_categories.dart';
import 'package:starpath/features/agent_studio/domain/agent_model.dart';
import 'package:starpath/features/chat/data/chat_providers.dart';
import 'package:starpath/shared/widgets/aura_avatar.dart';

Color _hexColor(String hex) {
  hex = hex.replaceFirst('#', '');
  return Color(int.parse('FF$hex', radix: 16));
}

/// Preview agents shown when the backend returns no data or an error.
final List<AgentModel> _previewAgents = [
  AgentModel(
    id: 'preview-1', userId: 'preview', name: '旅行达人 Luna', emoji: '🌍',
    personality: const ['热情', '博学', '幽默'], bio: '环游世界的旅行顾问',
    templateId: 'travel-buddy',
    gradientStart: '#00B4D8', gradientEnd: '#0077B6',
    isPublic: true, createdAt: DateTime(2025),
  ),
  AgentModel(
    id: 'preview-2', userId: 'preview', name: '代码伙伴 阿码', emoji: '💻',
    personality: const ['理性', '耐心', '严谨'], bio: '全栈编程助手',
    templateId: 'code-assistant',
    gradientStart: '#6C63FF', gradientEnd: '#00D2FF',
    isPublic: true, createdAt: DateTime(2025),
  ),
  AgentModel(
    id: 'preview-3', userId: 'preview', name: '文字精灵 墨染', emoji: '✨',
    personality: const ['感性', '浪漫', '细腻'], bio: '创意写作伙伴',
    templateId: 'creative-writer',
    gradientStart: '#9B59B6', gradientEnd: '#E74C8F',
    isPublic: true, createdAt: DateTime(2025),
  ),
  AgentModel(
    id: 'preview-4', userId: 'preview', name: '心灵导师 暖阳', emoji: '☀️',
    personality: const ['温柔', '善解人意', '正能量'], bio: '温暖的倾听者',
    templateId: 'life-coach',
    gradientStart: '#FFD93D', gradientEnd: '#FF6B6B',
    isPublic: true, createdAt: DateTime(2025),
  ),
  AgentModel(
    id: 'preview-5', userId: 'preview', name: '运动教练 活力', emoji: '💪',
    personality: const ['活力', '鼓励', '专业'], bio: '私人健身教练',
    templateId: 'fitness-coach',
    gradientStart: '#6BCB77', gradientEnd: '#4D96FF',
    isPublic: true, createdAt: DateTime(2025),
  ),
  AgentModel(
    id: 'preview-6', userId: 'preview', name: '学习搭子 知识', emoji: '📚',
    personality: const ['博学', '耐心', '幽默'], bio: '学习路上的好伙伴',
    templateId: 'study-partner',
    gradientStart: '#48C9B0', gradientEnd: '#1ABC9C',
    isPublic: true, createdAt: DateTime(2025),
  ),
  AgentModel(
    id: 'preview-7', userId: 'preview', name: '萌宠 团子', emoji: '🐱',
    personality: const ['可爱', '调皮', '粘人'], bio: '爱撒娇的虚拟宠物',
    templateId: 'pet-companion',
    gradientStart: '#FF85A2', gradientEnd: '#FFAA85',
    isPublic: true, createdAt: DateTime(2025),
  ),
  AgentModel(
    id: 'preview-8', userId: 'preview', name: '智者 深思', emoji: '🦉',
    personality: const ['深邃', '睿智', '冷静'], bio: '陪你思考人生',
    templateId: 'philosopher',
    gradientStart: '#8E44AD', gradientEnd: '#3498DB',
    isPublic: true, createdAt: DateTime(2025),
  ),
];

/// NFT-style reference: purple → pink for selected filter chips.
const LinearGradient _chipSelectedGradient = LinearGradient(
  colors: [Color(0xFF8E2DE2), Color(0xFFFF0080)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class AgentStudioPage extends ConsumerStatefulWidget {
  const AgentStudioPage({super.key});

  @override
  ConsumerState<AgentStudioPage> createState() => _AgentStudioPageState();
}

class _AgentStudioPageState extends ConsumerState<AgentStudioPage> {
  late final List<String> _chipLabels;
  int _chipIndex = 0;

  @override
  void initState() {
    super.initState();
    _chipLabels = ['全部', ...kAgentStyleCategories];
  }

  List<AgentModel> _filtered(List<AgentModel> agents) {
    if (_chipIndex == 0) return agents;
    final cat = _chipLabels[_chipIndex];
    return agents
        .where((a) => categoryForTemplateId(a.templateId) == cat)
        .toList();
  }

  Future<void> _openCreate() async {
    await context.push('/agents/create');
    if (mounted) ref.invalidate(myAgentsProvider);
  }

  Widget _buildScrollView(List<AgentModel> agents) {
    final filtered = _filtered(agents);
    return CustomScrollView(
      slivers: [
        _headerSliver(),
        _chipsSliver(),
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildFilteredEmptyBody(context),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.68,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _AgentCard(agent: filtered[i]),
                childCount: filtered.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final agentsAsync = ref.watch(myAgentsProvider);

    return Scaffold(
      backgroundColor: StarpathColors.surface,
      body: agentsAsync.when(
        loading: () => CustomScrollView(
          slivers: [
            _headerSliver(),
            _chipsSliver(),
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: StarpathColors.primary),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
        error: (_, __) => _buildScrollView(_previewAgents),
        data: (agents) =>
            _buildScrollView(agents.isEmpty ? _previewAgents : agents),
      ),
    );
  }

  Widget _headerSliver() {
    final top = MediaQuery.paddingOf(context).top;
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, top + 16, 20, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ── 标题与副标题 ──────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '我的 AI 伙伴',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: StarpathColors.onSurface,
                          height: 1.1,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '发现并创建属于你的智能伙伴',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: StarpathColors.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // ── 创建按钮 ─────────────────────────────────────────────
            GestureDetector(
              onTap: _openCreate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: StarpathColors.primaryGradient,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: StarpathColors.primary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      spreadRadius: -2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: StarpathColors.onPrimary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '创建伙伴',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: StarpathColors.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipsSliver() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 44,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
          itemCount: _chipLabels.length,
          itemBuilder: (context, i) {
            final selected = i == _chipIndex;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _chipIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: selected ? _chipSelectedGradient : null,
                    color: selected
                        ? null
                        : StarpathColors.surfaceContainerHigh
                            .withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(100),
                    border: selected
                        ? null
                        : Border.all(
                            color: StarpathColors.outlineVariant,
                            width: 0.8,
                          ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF8E2DE2)
                                  .withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    _chipLabels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? Colors.white
                          : StarpathColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilteredEmptyBody(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 48,
              color: StarpathColors.onSurfaceVariant.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 16),
            Text(
              '该风格下暂无伙伴',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: StarpathColors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '试试「全部」筛选，或创建一个新伙伴',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
    final topLabel = categoryForTemplateId(agent.templateId) ??
        (agent.personality.isNotEmpty ? agent.personality.first : '自定义');
    final subtitle = agent.bio.isNotEmpty
        ? agent.bio
        : agent.personality.join(' · ');

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
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: StarpathColors.surfaceContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: StarpathColors.outlineVariant,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        topLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: StarpathColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: StarpathColors.surfaceContainerHigh
                            .withValues(alpha: 0.55),
                        border: Border.all(
                          color: StarpathColors.outlineVariant,
                          width: 0.8,
                        ),
                      ),
                      child: const Icon(
                        Icons.north_east_rounded,
                        size: 16,
                        color: StarpathColors.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [gradStart, gradEnd],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: AuraAvatar(
                        fallbackEmoji: agent.emoji,
                        size: 76,
                        gradientColors: [gradStart, gradEnd],
                        state: CompanionState.active,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  agent.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: StarpathColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle.isNotEmpty ? subtitle : ' ',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.25,
                    color: StarpathColors.onSurfaceVariant,
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
