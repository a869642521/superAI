import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/agent_studio/data/agent_providers.dart';
import 'package:starpath/features/agent_studio/data/agent_template_categories.dart';
import 'package:starpath/features/agent_studio/domain/agent_model.dart';
import 'package:starpath/features/chat/data/chat_providers.dart';

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

/// 伙伴页封面图候选（勿加 `assets/` 前缀，避免 Web 双重路径）。
/// 新增图片时放入 `app/images/` 并在此加入路径即可（`pubspec` 已声明 `images/` 目录）。
const List<String> kPartnerCoverImages = [
  'images/ip0.png',
  'images/ip1.png',
  'images/ip2.png',
  'images/ip3.png',
  'images/ip4.png',
  'images/ip5.png',
  'images/ip7.png',
];

/// 按 key 稳定分配封面（同一伙伴/社群始终同一张，看起来像「随机」混搭）。
String partnerCoverImageFor(Object key) =>
    kPartnerCoverImages[key.hashCode.abs() % kPartnerCoverImages.length];

/// 封面图：加载失败时回退到 ip1（避免新增图片后仅热重载、AssetManifest 未更新时出现红叉）。
class _PartnerCoverImage extends StatelessWidget {
  final String assetPath;

  const _PartnerCoverImage({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) {
        if (assetPath == kPartnerCoverImages[0]) {
          return const ColoredBox(
            color: StarpathColors.surfaceContainerHigh,
            child: Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                color: StarpathColors.onSurfaceVariant,
                size: 40,
              ),
            ),
          );
        }
        return _PartnerCoverImage(assetPath: kPartnerCoverImages[0]);
      },
    );
  }
}

class _SpotlightCommunity {
  final String title;
  final String description;
  final int memberCount;

  const _SpotlightCommunity({
    required this.title,
    required this.description,
    required this.memberCount,
  });
}

const List<_SpotlightCommunity> _kSpotlightCommunities = [
  _SpotlightCommunity(
    title: '骑行同好社',
    description: '和骑友分享路线、装备与周末远征计划，一起探索城市与郊外。',
    memberCount: 124,
  ),
  _SpotlightCommunity(
    title: '音乐创作圈',
    description: '从 Lo-Fi 到电子乐，交流编曲灵感与同好作品，找到你的声音。',
    memberCount: 89,
  ),
  _SpotlightCommunity(
    title: 'AI 学习营',
    description: 'Prompt、模型与工具链实战，和伙伴一起把想法做成产品。',
    memberCount: 256,
  ),
  _SpotlightCommunity(
    title: '夜跑打卡组',
    description: '每晚互相督促打卡，安全路线与配速心得，越跑越轻松。',
    memberCount: 67,
  ),
  _SpotlightCommunity(
    title: '读书与思辨',
    description: '每月共读一本书，线上圆桌讨论，把阅读变成对话。',
    memberCount: 142,
  ),
];

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
        _spotlightCardsSliver(),
        _chipsSliver(),
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildFilteredEmptyBody(context),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 14,
                childAspectRatio: 0.62,
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
            _spotlightCardsSliver(),
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
        padding: EdgeInsets.fromLTRB(20, top + 20, 20, 18),
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
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: StarpathColors.selectedGradient,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: StarpathColors.accentViolet.withValues(alpha: 0.38),
                      blurRadius: 14,
                      spreadRadius: -2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: const [
                    Icon(Icons.add_rounded, size: 18, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      '创建伙伴',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1,
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

  Widget _spotlightCardsSliver() {
    return SliverToBoxAdapter(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 卡片宽 = 可用宽 - 左侧内边距(20) - 右侧"下一张"露出量(36) - 卡片间距(12)
          final cardWidth = constraints.maxWidth - 20 - 36 - 12;
          const cardHeight = 210.0;
          return SizedBox(
            height: cardHeight + 20,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              itemCount: _kSpotlightCommunities.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                return _SpotlightCommunityCard(
                  data: _kSpotlightCommunities[i],
                  imageAsset: partnerCoverImageFor(_kSpotlightCommunities[i].title),
                  width: cardWidth,
                  height: cardHeight,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _chipsSliver() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Text(
              '超火的ai伙伴',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: StarpathColors.onSurface,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 2),
              itemCount: _chipLabels.length,
              itemBuilder: (context, i) {
                final selected = i == _chipIndex;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => _chipIndex = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        gradient:
                            selected ? StarpathColors.selectedGradient : null,
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
                                  color: StarpathColors.accentViolet
                                      .withValues(alpha: 0.38),
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
        ],
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

class _SpotlightCommunityCard extends StatefulWidget {
  final _SpotlightCommunity data;
  final String imageAsset;
  final double width;
  final double height;

  const _SpotlightCommunityCard({
    required this.data,
    required this.imageAsset,
    required this.width,
    required this.height,
  });

  @override
  State<_SpotlightCommunityCard> createState() =>
      _SpotlightCommunityCardState();
}

class _SpotlightCommunityCardState extends State<_SpotlightCommunityCard> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    // 图片高 = 卡片总高 - 底部文字区高度(56)
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          HapticFeedback.selectionClick();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('「${d.title}」即将开放'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
              backgroundColor: StarpathColors.surfaceContainerHighest,
            ),
          );
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: StarpathColors.surfaceContainer,
              borderRadius: BorderRadius.circular(20),
              boxShadow: _hovered
                  ? [
                      BoxShadow(
                        color: StarpathColors.accentViolet
                            .withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            // 整张卡片就是一张图，文字叠在底部磨砂层上
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 背景图
                  _PartnerCoverImage(assetPath: widget.imageAsset),
                  // 底部胶囊磨砂信息条
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.38),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      d.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      d.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        height: 1.3,
                                        color: Colors.white
                                            .withValues(alpha: 0.72),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 人数角标（左上）
                  Positioned(
                    top: 10,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline_rounded,
                              size: 13, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '${d.memberCount}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // 不用 BackdropFilter：Web 上模糊层与圆角裁剪易错位，底部会出现「叠色」伪影
          color: StarpathColors.surfaceContainer.withValues(alpha: 0.82),
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
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _PartnerCoverImage(
                          assetPath: partnerCoverImageFor(agent.id),
                        ),
                        // 底部轻渐变，与主题色衔接
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                gradStart.withValues(alpha: 0.18),
                                gradEnd.withValues(alpha: 0.38),
                              ],
                              stops: const [0.45, 0.78, 1.0],
                            ),
                          ),
                        ),
                      ],
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
    );
  }
}
