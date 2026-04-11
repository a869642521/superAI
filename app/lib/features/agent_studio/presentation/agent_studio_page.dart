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

/// 按顺序循环分配封面，避免同屏出现重复图片。
String partnerCoverImageByIndex(int index) =>
    kPartnerCoverImages[index % kPartnerCoverImages.length];

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
                mainAxisExtent: 340,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _AgentCard(
                  agent: filtered[i],
                  imageIndex: i,
                ),
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
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
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
          // 角色图向上「破框」预留空间
          const spotlightTopBleed = 42.0;
          return SizedBox(
            height: cardHeight + 20 + spotlightTopBleed,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              itemCount: _kSpotlightCommunities.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, i) {
                return _SpotlightCommunityCard(
                  data: _kSpotlightCommunities[i],
                  imageAsset: partnerCoverImageByIndex(i),
                  width: cardWidth,
                  height: cardHeight,
                  topBleed: spotlightTopBleed,
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
  final double topBleed;

  const _SpotlightCommunityCard({
    required this.data,
    required this.imageAsset,
    required this.width,
    required this.height,
    this.topBleed = 42,
  });

  @override
  State<_SpotlightCommunityCard> createState() =>
      _SpotlightCommunityCardState();
}

class _SpotlightCommunityCardState extends State<_SpotlightCommunityCard> {
  bool _pressed = false;
  bool _hovered = false;

  static const List<Color> _warmCardGradient = [
    Color(0xFFF2E4D4),
    Color(0xFFE5D0B8),
    Color(0xFFD4BEA3),
  ];

  Widget _characterImage(double w, double h) {
    return Image.asset(
      widget.imageAsset,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      width: w,
      height: h,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Image.asset(
        kPartnerCoverImages[0],
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        width: w,
        height: h,
        gaplessPlayback: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final w = widget.width;
    final h = widget.height;
    final bleed = widget.topBleed;
    final charW = w * 0.44;
    final charH = h + bleed * 0.55;

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
          child: SizedBox(
            width: w,
            height: h + bleed,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 横版暖色主卡片（参考设计：大圆角、左侧信息区）
                Positioned(
                  left: 0,
                  right: 0,
                  top: bleed,
                  bottom: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _warmCardGradient,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                      boxShadow: _hovered
                          ? [
                              BoxShadow(
                                color: StarpathColors.accentViolet
                                    .withValues(alpha: 0.20),
                                blurRadius: 22,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.14),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 左上：人数胶囊
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 5),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.48),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.person_outline_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          '${d.memberCount}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            height: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  // 左下：深色信息块（标题 + 说明，两行）
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.black
                                          .withValues(alpha: 0.52),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          d.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            height: 1.2,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          d.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            height: 1.35,
                                            color: Colors.white
                                                .withValues(alpha: 0.88),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: w * 0.30),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // 右侧角色图：底部贴卡片，顶部超出暖色区域（破框）
                Positioned(
                  right: -4,
                  top: 0,
                  width: charW,
                  height: charH,
                  child: IgnorePointer(
                    child: _characterImage(charW, charH),
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

class _AgentCard extends ConsumerStatefulWidget {
  final AgentModel agent;
  final int imageIndex;
  const _AgentCard({required this.agent, required this.imageIndex});

  @override
  ConsumerState<_AgentCard> createState() => _AgentCardState();
}

class _AgentCardState extends ConsumerState<_AgentCard> {
  bool _pressing = false;

  Future<void> _startChat() async {
    HapticFeedback.lightImpact();
    try {
      final repo = ref.read(chatRepositoryProvider);
      final conv = await repo.createConversation(widget.agent.id);
      if (mounted) {
        ref.invalidate(conversationsProvider);
        context.push('/chat/${conv.id}');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('启动对话失败，请确认后端服务正在运行'),
            backgroundColor: StarpathColors.surfaceContainerHigh,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradStart = _hexColor(widget.agent.gradientStart);
    final gradEnd = _hexColor(widget.agent.gradientEnd);
    final topLabel = categoryForTemplateId(widget.agent.templateId) ??
        (widget.agent.personality.isNotEmpty
            ? widget.agent.personality.first
            : '自定义');
    final subtitle = widget.agent.bio.isNotEmpty
        ? widget.agent.bio
        : widget.agent.personality.join(' · ');

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressing = true),
      onTapUp: (_) {
        setState(() => _pressing = false);
        _startChat();
      },
      onTapCancel: () => setState(() => _pressing = false),
      child: AnimatedScale(
        scale: _pressing ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: StarpathColors.surfaceContainer.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: StarpathColors.outlineVariant, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 顶部：分类标签 ─────────────────────────────────────
              Text(
                topLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: StarpathColors.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 8),
              // ── 封面图（填充剩余空间）─────────────────────────────
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _PartnerCoverImage(
                        assetPath: partnerCoverImageByIndex(widget.imageIndex),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              gradStart.withValues(alpha: 0.15),
                              gradEnd.withValues(alpha: 0.35),
                            ],
                            stops: const [0.5, 0.8, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // ── 名称 ────────────────────────────────────────────────
              Text(
                widget.agent.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: StarpathColors.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle.isNotEmpty ? subtitle : ' ',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: StarpathColors.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 10),
              // ── 作者头像 + 前往聊天 ────────────────────────────────
              Row(
                children: [
                  // 作者头像（emoji 圆形）
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [gradStart, gradEnd],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        widget.agent.emoji,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.agent.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: StarpathColors.onSurfaceVariant
                            .withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  // 前往聊天按钮
                  GestureDetector(
                    onTap: _startChat,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: StarpathColors.selectedGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '聊天',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
