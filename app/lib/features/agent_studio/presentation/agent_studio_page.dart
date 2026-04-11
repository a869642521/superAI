import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/agent_studio/data/agent_providers.dart';
import 'package:starpath/features/agent_studio/data/agent_template_categories.dart';
import 'package:starpath/features/agent_studio/domain/agent_model.dart';
import 'package:starpath/features/agent_studio/presentation/partner_page_background.dart';
Color _hexColor(String hex) {
  hex = hex.replaceFirst('#', '');
  return Color(int.parse('FF$hex', radix: 16));
}

/// Preview agents shown when the backend returns no data or an error.
final List<AgentModel> _previewAgents = [
  AgentModel(
    id: 'preview-1', userId: 'preview', name: '旅行达人 Luna', emoji: '🌍',
    personality: const ['热情', '博学', '幽默'], bio: '环游世界的旅行顾问，带你发现世界之美',
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
    personality: const ['可爱', '调皮', '粘人'], bio: '爱撒娇的虚拟宠物伴侣',
    templateId: 'pet-companion',
    gradientStart: '#FF85A2', gradientEnd: '#FFAA85',
    isPublic: true, createdAt: DateTime(2025),
  ),
  AgentModel(
    id: 'preview-8', userId: 'preview', name: '智者 深思', emoji: '🦉',
    personality: const ['深邃', '睿智', '冷静'], bio: '陪你思考人生的哲学智者',
    templateId: 'philosopher',
    gradientStart: '#8E44AD', gradientEnd: '#3498DB',
    isPublic: true, createdAt: DateTime(2025),
  ),
  AgentModel(
    id: 'preview-9', userId: 'preview', name: '美食家 香满', emoji: '🍜',
    personality: const ['热爱美食', '分享', '讲究'], bio: '发现城市里的每一口好滋味',
    templateId: 'foodie',
    gradientStart: '#FF6B35', gradientEnd: '#F7931E',
    isPublic: true, createdAt: DateTime(2025),
  ),
  AgentModel(
    id: 'preview-10', userId: 'preview', name: '音乐人 弦歌', emoji: '🎵',
    personality: const ['感性', '创意', '随性'], bio: '用音乐记录每一刻心情',
    templateId: 'musician',
    gradientStart: '#C471ED', gradientEnd: '#12C2E9',
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

/// 按顺序循环分配社区封面，避免同屏出现重复图片。
String partnerCoverImageByIndex(int index) =>
    kPartnerCoverImages[index % kPartnerCoverImages.length];

/// AI 伙伴卡片专用透明 PNG，循环分配。
const List<String> kAgentCoverImages = [
  'images/png/ai1.png',
  'images/png/ai2.png',
  'images/png/ai3.png',
];

/// 按顺序循环分配 AI 伙伴封面。
String agentCoverImageByIndex(int index) =>
    kAgentCoverImages[index % kAgentCoverImages.length];

/// Spotlight 角色破框上移量；页眉副标题间距与之对齐以便与兔耳同高。
const double _kSpotlightTopBleed = 42.0;

/// AI 伙伴网格卡片封面（ip*.png，加载失败回退首张）。
class _AgentCoverImage extends StatelessWidget {
  final int index;
  const _AgentCoverImage({required this.index});

  @override
  Widget build(BuildContext context) {
    final path = partnerCoverImageByIndex(index);
    return Image.asset(
      path,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Image.asset(
        kPartnerCoverImages[0],
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}

class _SpotlightCommunity {
  final String ipName;
  final String personality;
  final String tag;
  /// 对应 preview agent id，点击进入 AI 聊天页 `/chat/agent/:agentId`。
  final String agentId;

  const _SpotlightCommunity({
    required this.ipName,
    required this.personality,
    required this.tag,
    required this.agentId,
  });
}

const List<_SpotlightCommunity> _kSpotlightCommunities = [
  _SpotlightCommunity(
    ipName: '云朵骑兔 啵比',
    personality: '外向 · 爱冒险，周末最爱拉你刷一条新路线，聊装备也不腻。',
    tag: '旅行',
    agentId: 'preview-1',
  ),
  _SpotlightCommunity(
    ipName: 'Lo-Fi 小音',
    personality: '细腻 · 慢性子，陪你从和弦到编曲，把灵感落成完整 Demo。',
    tag: '创作',
    agentId: 'preview-3',
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
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                mainAxisExtent: 280,
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

    // 透明状态栏 + 浅色图标
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemStatusBarContrastEnforced: false,
      ),
      // ── 将渐变置于 Scaffold 外层，从屏幕最顶端（含状态栏）开始，彻底消除断层 ──
      child: Builder(
        builder: (context) {
          const gradientH = 200.0;
          return Stack(
            children: [
              // 全屏底色
              const Positioned.fill(
                child: ColoredBox(color: StarpathColors.surface),
              ),
              // 顶部固定渐变带（不随滚动变化的装饰色）
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: gradientH,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0x334D2E8B),
                          Color(0x227C3AED),
                          Color(0x009B72FF),
                        ],
                        stops: [0.0, 0.55, 1.0],
                      ),
                    ),
                    child: SizedBox.expand(),
                  ),
                ),
              ),
              // Scaffold 透明，内容正常显示在渐变上
              Scaffold(
                backgroundColor: Colors.transparent,
                body: agentsAsync.when(
                  loading: () => CustomScrollView(
                    slivers: [
                      _headerSliver(),
                      _spotlightCardsSliver(),
                      _chipsSliver(),
                      const SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(
                              color: StarpathColors.primary),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  ),
                  error: (_, __) => _buildScrollView(_previewAgents),
                  data: (agents) {
                    // 真实 agent 优先；不足 10 个时用预览卡片补全到 10 个
                    if (agents.length >= 10) return _buildScrollView(agents);
                    final realIds = agents.map((a) => a.id).toSet();
                    final fills = _previewAgents
                        .where((p) => !realIds.contains(p.id))
                        .take(10 - agents.length)
                        .toList();
                    return _buildScrollView([...agents, ...fills]);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _headerSliver() {
    final top = MediaQuery.paddingOf(context).top;
    final titleStyle = Theme.of(context).textTheme.headlineMedium;
    final titleSize = (titleStyle?.fontSize ?? 28) + 8;
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, top + 16, 20, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                '我的 AI 伙伴',
                style: titleStyle?.copyWith(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                      color: StarpathColors.onSurface,
                      height: 1.1,
                    ) ??
                    TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                      color: StarpathColors.onSurface,
                      height: 1.1,
                    ),
              ),
            ),
            const SizedBox(width: 4),
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
          const cardHeight = 150.0; // 原 210，减少 60px
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 与首张卡片左缘对齐，处于破框兔耳一带（红框示意区）
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: Text(
                  '发现并创建属于你的智能伙伴',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: StarpathColors.onSurfaceVariant,
                      ),
                ),
              ),
              SizedBox(
                height: cardHeight + 20 + _kSpotlightTopBleed,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  itemCount: _kSpotlightCommunities.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, i) {
                    return _SpotlightCommunityCard(
                      data: _kSpotlightCommunities[i],
                      imageAsset: agentCoverImageByIndex(i),
                      width: cardWidth,
                      height: cardHeight,
                      topBleed: _kSpotlightTopBleed,
                      isFirstCard: i == 0,
                      isSecondCard: i == 1,
                    );
                  },
                ),
              ),
            ],
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
  /// 首张：与页顶同色紫渐变；第二张：橙→紫粉；其余暖色底
  final bool isFirstCard;
  final bool isSecondCard;

  const _SpotlightCommunityCard({
    required this.data,
    required this.imageAsset,
    required this.width,
    required this.height,
    this.topBleed = _kSpotlightTopBleed,
    this.isFirstCard = false,
    this.isSecondCard = false,
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

  /// 第二张长卡：左橙 → 右紫粉（与首张同向：左→右）
  static const List<Color> _secondCardOrangePinkGradient = [
    Color(0xFFFF7A3D),
    Color(0xFFFF9F66),
    Color(0xFFFF6B9D),
    Color(0xFFE879F9),
    Color(0xFFC084FC),
    Color(0xFFB565F0),
  ];

  static const List<double> _secondCardOrangePinkStops = [
    0.0,
    0.22,
    0.45,
    0.62,
    0.82,
    1.0,
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
        kAgentCoverImages[0],
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
          context.push('/chat/agent/${d.agentId}');
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
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: widget.isFirstCard
                            ? PartnerPageBackgroundConfig.gradientColors
                            : widget.isSecondCard
                                ? _secondCardOrangePinkGradient
                                : _warmCardGradient,
                        stops: widget.isFirstCard
                            ? PartnerPageBackgroundConfig.gradientStops
                            : widget.isSecondCard
                                ? _secondCardOrangePinkStops
                                : null,
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
                                  // 左上：标签（渐变描边 + 微光）
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white
                                              .withValues(alpha: 0.22),
                                          Colors.white
                                              .withValues(alpha: 0.08),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.55),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.white
                                              .withValues(alpha: 0.12),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.sell_rounded,
                                          size: 13,
                                          color: Colors.white
                                              .withValues(alpha: 0.95),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          d.tag,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            height: 1,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  // 左下：IP 名称 + 性格介绍（无磨砂底，靠阴影保证可读）
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        d.ipName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          height: 1.2,
                                          letterSpacing: -0.3,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.35),
                                              blurRadius: 12,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        d.personality,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          height: 1.4,
                                          color: Colors.white
                                              .withValues(alpha: 0.6),
                                          shadows: [
                                            Shadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.28),
                                              blurRadius: 8,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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

  void _startChat() {
    HapticFeedback.lightImpact();
    context.push('/chat/agent/${widget.agent.id}');
  }

  @override
  Widget build(BuildContext context) {
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
          decoration: BoxDecoration(
            color: StarpathColors.surfaceContainer.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: StarpathColors.outlineVariant, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 正方形封面图区（带左上角胶囊 + 右上角聊天按钮）──
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _AgentCoverImage(index: widget.imageIndex),
                      // 左上角分类胶囊
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            topLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      // 右上角前往聊天按钮
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: _startChat,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: StarpathColors.selectedGradient,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: StarpathColors.accentViolet
                                      .withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              '前往',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ── 图片下方文字区 ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.agent.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: StarpathColors.onSurface,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: StarpathColors.onSurfaceVariant
                            .withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 作者头像 + 名字 + 点赞数
                    Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                gradEnd.withValues(alpha: 0.8),
                                gradEnd,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              widget.agent.emoji,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            widget.agent.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: StarpathColors.onSurfaceVariant
                                  .withValues(alpha: 0.65),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.favorite_border_rounded,
                          size: 12,
                          color: StarpathColors.onSurfaceVariant
                              .withValues(alpha: 0.55),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${(widget.imageIndex + 1) * 38}',
                          style: TextStyle(
                            fontSize: 10,
                            color: StarpathColors.onSurfaceVariant
                                .withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
