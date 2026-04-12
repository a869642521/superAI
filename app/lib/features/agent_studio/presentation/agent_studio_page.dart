import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/agent_studio/data/agent_providers.dart';
import 'package:starpath/features/agent_studio/data/agent_template_categories.dart';
import 'package:starpath/features/agent_studio/domain/agent_model.dart';

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
  'images/ip0.png',
  'images/ip1.png',
  'images/ip2.png',
];

/// 按顺序循环分配 AI 伙伴封面。
String agentCoverImageByIndex(int index) =>
    kAgentCoverImages[index % kAgentCoverImages.length];

/// Spotlight 角色破框上移量；页眉副标题间距与之对齐以便与兔耳同高。
const double _kSpotlightTopBleed = 42.0;
/// 立绘相对卡片竖直偏移（破框上移）；副标题用 Stack 叠在上层，可与视频同值。
const double _kSpotlightMediaNudgeY = -100.0;
/// 在比例算出高度基础上额外加高（主 Spotlight 卡片可视区）
const double _kSpotlightCardHeightExtra = 100.0;
/// Spotlight 横滑整块相对布局竖直偏移（负上移、正下移）
const double _kSpotlightSectionOffsetY = 20.0;
/// Spotlight 左右切换按钮距屏幕边缘
const double _kSpotlightNavEdgeInset = 10.0;
/// Spotlight 切换按钮尺寸
const double _kSpotlightNavButtonSize = 44.0;
/// 主卡底部（含 CHAT）到「更多 ai 伙伴」分割线的垂直间距
const double _kSpotlightChatToDividerGap = 60.0;
/// Spotlight 大卡底部「Chat」按钮：左蓝右紫，与顶部创建按钮区分层次
const LinearGradient _kSpotlightChatButtonGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [
    Color(0xFF2B8CFF),
    Color(0xFF5B5CFF),
    Color(0xFF9B5CFF),
  ],
);

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
  /// 进入/切换卡片时首次播放一次的招呼动画。
  final String? helloVideo;
  /// hello 播完后播放一次的过渡动画。
  final String? haitVideo;
  /// hait 播完后循环的呼吸待机动画。
  final String? breatheVideo;
  /// 用户点击角色时播放一次的互动动画，播完走 hait→breathe。
  final String? downVideo;

  const _SpotlightCommunity({
    required this.ipName,
    required this.personality,
    required this.tag,
    required this.agentId,
    this.helloVideo,
    this.haitVideo,
    this.breatheVideo,
    this.downVideo,
  });
}

const List<_SpotlightCommunity> _kSpotlightCommunities = [
  _SpotlightCommunity(
    ipName: '云朵骑兔 啵比',
    personality: '外向 · 爱冒险，周末最爱拉你刷一条新路线，聊装备也不腻。',
    tag: '旅行',
    agentId: 'preview-1',
    helloVideo:   'video/ip0/ip0_hello.mp4',
    haitVideo:    'video/ip0/ip0_hait.mp4',
    breatheVideo: 'video/ip0/ip0_breathe.mp4',
    downVideo:    'video/ip0/ip0_down.mp4',
  ),
  _SpotlightCommunity(
    ipName: 'Lo-Fi 小音',
    personality: '细腻 · 慢性子，陪你从和弦到编曲，把灵感落成完整 Demo。',
    tag: '创作',
    agentId: 'preview-3',
    helloVideo:   'video/ip1/ip1_hello.mp4',
    haitVideo:    'video/ip1/ip1_hait.mp4',
    breatheVideo: 'video/ip1/ip1_breathe.mp4',
    downVideo:    'video/ip1/ip1_down.mp4',
  ),
  _SpotlightCommunity(
    ipName: '代码伙伴 阿码',
    personality: '理性 · 写代码像搭积木，debug 也陪你一步步拆到根因。',
    tag: '编程',
    agentId: 'preview-2',
    helloVideo:   'video/ip2/ip2_hello.mp4',
    haitVideo:    'video/ip2/ip2_hait.mp4',
    breatheVideo: 'video/ip2/ip2_breathe.mp4',
    downVideo:    'video/ip2/ip2_down.mp4',
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
  final GlobalKey _moreAgentsGridKey = GlobalKey();
  late final PageController _spotlightPageController;
  int _spotlightPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _chipLabels = ['全部', ...kAgentStyleCategories];
    _spotlightPageController = PageController();
  }

  @override
  void dispose() {
    _spotlightPageController.dispose();
    super.dispose();
  }

  void _spotlightGoToPage(int page) {
    if (!mounted) return;
    _spotlightPageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _spotlightSideNavButton({
    required bool isPrev,
    required bool enabled,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                final i = _spotlightPageIndex;
                if (isPrev) {
                  if (i > 0) _spotlightGoToPage(i - 1);
                } else {
                  if (i < _kSpotlightCommunities.length - 1) {
                    _spotlightGoToPage(i + 1);
                  }
                }
              }
            : null,
        customBorder: const CircleBorder(),
        child: Opacity(
          opacity: enabled ? 1 : 0.35,
          child: Container(
            width: _kSpotlightNavButtonSize,
            height: _kSpotlightNavButtonSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              isPrev ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              size: 28,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
        ),
      ),
    );
  }

  void _scrollToMoreAgents() {
    HapticFeedback.selectionClick();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _moreAgentsGridKey.currentContext;
      if (!mounted || ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
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
      clipBehavior: Clip.none,
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
            key: _moreAgentsGridKey,
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
      child: Scaffold(
        backgroundColor: StarpathColors.surface,
        body: agentsAsync.when(
          loading: () => CustomScrollView(
            clipBehavior: Clip.none,
            slivers: [
              _headerSliver(),
              _spotlightCardsSliver(),
              _chipsSliver(),
              const SliverFillRemaining(
                child: Center(
                  child:
                      CircularProgressIndicator(color: StarpathColors.primary),
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
                      color: Colors.white,
                      height: 1.1,
                    ) ??
                    TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
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
                  color: StarpathColors.primaryContainer,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: StarpathColors.primary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      spreadRadius: -2,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
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
      child: Builder(
        builder: (context) {
          // 用逻辑屏宽，保证卡片铺满左右
          final cardWidth = MediaQuery.sizeOf(context).width;
          final media = MediaQuery.of(context);
          final safeH = media.size.height - media.padding.top;
          final cardHeight = (safeH * 0.58 - 72.0).clamp(320.0, 480.0) +
              _kSpotlightCardHeightExtra;
          return Transform.translate(
            offset: const Offset(0, _kSpotlightSectionOffsetY),
            child: SizedBox(
              height: cardHeight +
                  _kSpotlightTopBleed +
                  _kSpotlightChatToDividerGap,
              child: Padding(
                // 留出底部 chat-to-divider 间距，内容区与分割线保持一致
                padding:
                    const EdgeInsets.only(bottom: _kSpotlightChatToDividerGap),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    PageView.builder(
                      controller: _spotlightPageController,
                      clipBehavior: Clip.none,
                      physics: const PageScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      itemCount: _kSpotlightCommunities.length,
                      onPageChanged: (i) {
                        setState(() => _spotlightPageIndex = i);
                      },
                      itemBuilder: (context, i) {
                        return _SpotlightCommunityCard(
                          data: _kSpotlightCommunities[i],
                          imageAsset: agentCoverImageByIndex(i),
                          width: cardWidth,
                          height: cardHeight,
                          topBleed: _kSpotlightTopBleed,
                        );
                      },
                    ),
                    // 两侧切换（位于立绘区域垂直居中，不挡底部文案与 CHAT）
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          _kSpotlightNavEdgeInset,
                          8,
                          _kSpotlightNavEdgeInset,
                          cardHeight * 0.38 + 8,
                        ),
                        child: Transform.translate(
                          offset: const Offset(0, 40),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _spotlightSideNavButton(
                                isPrev: true,
                                enabled: _spotlightPageIndex > 0,
                              ),
                              _spotlightSideNavButton(
                                isPrev: false,
                                enabled: _spotlightPageIndex <
                                    _kSpotlightCommunities.length - 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
            child: SizedBox(
              height: 1,
              width: double.infinity,
              child: ColoredBox(
                color: StarpathColors.primary.withValues(alpha: 0.38),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    '更多ai伙伴',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                  ),
                ),
                GestureDetector(
                  onTap: _scrollToMoreAgents,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '查看更多',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: StarpathColors.primary,
                                    height: 1,
                                  ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: StarpathColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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

/// 将子树以 [BlendMode.screen] 与下层已绘制内容做滤色合成，不叠加任何额外颜色层。
class _SpotlightScreenBlend extends SingleChildRenderObjectWidget {
  const _SpotlightScreenBlend({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSpotlightScreenBlend();
}

class _RenderSpotlightScreenBlend extends RenderProxyBox {
  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.saveLayer(
      offset & size,
      Paint()..blendMode = BlendMode.screen,
    );
    super.paint(context, offset);
    context.canvas.restore();
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
    this.topBleed = _kSpotlightTopBleed,
  });

  @override
  State<_SpotlightCommunityCard> createState() =>
      _SpotlightCommunityCardState();
}

/// 四段视频的播放阶段
/// hello(×1) → hait(×1) → breathe(∞) ；点击 → down(×1) → hait(×1) → breathe(∞)
enum _VideoPhase { hello, hait, breathe, down }

class _SpotlightCommunityCardState extends State<_SpotlightCommunityCard> {
  VideoPlayerController? _helloCtrl;
  VideoPlayerController? _haitCtrl;
  VideoPlayerController? _breatheCtrl;
  VideoPlayerController? _downCtrl;

  _VideoPhase _phase = _VideoPhase.hello;

  VideoPlayerController _makeCtrl(String asset) => kIsWeb
      ? VideoPlayerController.networkUrl(Uri.parse('assets/$asset'))
      : VideoPlayerController.asset(asset);

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    final d = widget.data;
    await Future.wait([
      if (d.helloVideo   != null) _initCtrl(d.helloVideo!,   loop: false).then((c) { _helloCtrl   = c; }),
      if (d.haitVideo    != null) _initCtrl(d.haitVideo!,    loop: false, autoPlay: false).then((c) { _haitCtrl    = c; }),
      if (d.breatheVideo != null) _initCtrl(d.breatheVideo!, loop: true,  autoPlay: false).then((c) { _breatheCtrl = c; }),
      if (d.downVideo    != null) _initCtrl(d.downVideo!,    loop: false, autoPlay: false).then((c) { _downCtrl    = c; }),
    ]);
    if (!mounted) return;
    _beginHello();
  }

  Future<VideoPlayerController?> _initCtrl(
    String asset, {
    required bool loop,
    bool autoPlay = false,
  }) async {
    final c = _makeCtrl(asset);
    try {
      await c.initialize();
      if (!mounted) { await c.dispose(); return null; }
      await c.setLooping(loop);
      await c.setVolume(0);
      if (autoPlay) await c.play();
      return c;
    } catch (e) {
      debugPrint('[SpotlightVideo] $asset: $e');
      await c.dispose();
      return null;
    }
  }

  // ── 启动 hello（或跳过直接 hait） ────────────────────────────
  Future<void> _beginHello() async {
    if (!mounted) return;
    final hello = _helloCtrl;
    if (hello != null) {
      await hello.seekTo(Duration.zero);
      hello.addListener(_onHelloTick);
      await hello.play();
      if (mounted) setState(() => _phase = _VideoPhase.hello);
    } else {
      _beginHait();
    }
  }

  void _onHelloTick() {
    final c = _helloCtrl;
    if (c == null || !c.value.isInitialized) return;
    final dur = c.value.duration;
    if (dur == Duration.zero) return;
    if (c.value.position + const Duration(milliseconds: 80) >= dur) {
      c.removeListener(_onHelloTick);
      c.pause();
      _beginHait();
    }
  }

  // ── hait（单次）→ breathe（循环） ─────────────────────────────
  Future<void> _beginHait() async {
    if (!mounted) return;
    final hait = _haitCtrl;
    if (hait != null) {
      await hait.seekTo(Duration.zero);
      hait.addListener(_onHaitTick);
      await hait.play();
      if (mounted) setState(() => _phase = _VideoPhase.hait);
    } else {
      _beginBreathe();
    }
  }

  void _onHaitTick() {
    final c = _haitCtrl;
    if (c == null || !c.value.isInitialized) return;
    final dur = c.value.duration;
    if (dur == Duration.zero) return;
    if (c.value.position + const Duration(milliseconds: 80) >= dur) {
      c.removeListener(_onHaitTick);
      c.pause();
      _beginBreathe();
    }
  }

  Future<void> _beginBreathe() async {
    if (!mounted) return;
    final breathe = _breatheCtrl;
    if (breathe != null) {
      await breathe.seekTo(Duration.zero);
      await breathe.play();
      if (mounted) setState(() => _phase = _VideoPhase.breathe);
    }
  }

  // ── down（单次）→ hait → breathe ─────────────────────────────
  void _onDownTick() {
    final c = _downCtrl;
    if (c == null || !c.value.isInitialized) return;
    final dur = c.value.duration;
    if (dur == Duration.zero) return;
    if (c.value.position + const Duration(milliseconds: 80) >= dur) {
      c.removeListener(_onDownTick);
      c.pause();
      c.seekTo(Duration.zero);
      _beginHait();
    }
  }

  // ── 用户点击角色 ─────────────────────────────────────────────
  void _handleVideoTap() {
    if (_phase == _VideoPhase.down) return;
    if (widget.data.downVideo == null) return;
    final down = _downCtrl;
    if (down == null || !down.value.isInitialized) return;
    HapticFeedback.lightImpact();
    // 暂停当前正在播放的阶段
    switch (_phase) {
      case _VideoPhase.hello:   _helloCtrl?.removeListener(_onHelloTick);   _helloCtrl?.pause();
      case _VideoPhase.hait:    _haitCtrl?.removeListener(_onHaitTick);     _haitCtrl?.pause();
      case _VideoPhase.breathe: _breatheCtrl?.pause();
      case _VideoPhase.down:    break;
    }
    down.seekTo(Duration.zero).then((_) {
      if (!mounted) return;
      down.addListener(_onDownTick);
      down.play();
      setState(() => _phase = _VideoPhase.down);
    });
  }

  @override
  void dispose() {
    _helloCtrl?.removeListener(_onHelloTick);
    _helloCtrl?.dispose();
    _haitCtrl?.removeListener(_onHaitTick);
    _haitCtrl?.dispose();
    _breatheCtrl?.dispose();
    _downCtrl?.removeListener(_onDownTick);
    _downCtrl?.dispose();
    super.dispose();
  }


  /// 构建视频层：铺满父级约束宽度，高度由 Positioned 决定，消除 Center 引起的横向偏移。
  Widget _buildVideoDisplay() {
    final d = widget.data;
    final bool hasVideo =
        d.helloVideo != null || d.haitVideo != null || d.downVideo != null;
    if (!hasVideo) {
      return IgnorePointer(
        child: Image.asset(
          widget.imageAsset,
          fit: BoxFit.cover,
          alignment: Alignment.bottomCenter,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    }

    final VideoPlayerController? activeCtrl = switch (_phase) {
      _VideoPhase.hello   => _helloCtrl,
      _VideoPhase.hait    => _haitCtrl,
      _VideoPhase.breathe => _breatheCtrl,
      _VideoPhase.down    => _downCtrl,
    };

    // 视频未就绪时显示透明空白（与卡片底色融合），避免闪出 PNG 封面图
    if (activeCtrl == null || !activeCtrl.value.isInitialized) {
      return const IgnorePointer(child: SizedBox.expand());
    }

    final sz = activeCtrl.value.size;
    if (sz.width == 0 || sz.height == 0) {
      return const IgnorePointer(child: SizedBox.expand());
    }

    final videoWidget = ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: sz.width,
          height: sz.height,
          child: VideoPlayer(activeCtrl),
        ),
      ),
    );
    return IgnorePointer(child: _SpotlightScreenBlend(child: videoWidget));
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final w = widget.width;
    final h = widget.height;
    final bleed = widget.topBleed;

    return SizedBox(
      width: w,
      height: h + bleed,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Spotlight 主区域：圆角纯色卡片底（与页面 surface 一致）
            Positioned(
              left: 0,
              right: 0,
              top: bleed,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: StarpathColors.surface,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: bleed,
              bottom: 0,
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  // 视频：用 Positioned 钉满左右，消除 Center 引起的横向留白
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _kSpotlightMediaNudgeY,
                    bottom: -_kSpotlightMediaNudgeY,
                    child: _buildVideoDisplay(),
                  ),
                  // 角色热区：透明覆盖上半区域，专门拦截角色点击
                  if (d.downVideo != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      bottom: h * 0.42,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _handleVideoTap,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  // 底部标题区
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        final uri = Uri(
                          path: '/chat/agent/${d.agentId}',
                          queryParameters: {
                            'agentName': d.ipName,
                            if (d.helloVideo   != null) 'helloVideo':   d.helloVideo!,
                            if (d.haitVideo    != null) 'haitVideo':    d.haitVideo!,
                            if (d.breatheVideo != null) 'breatheVideo': d.breatheVideo!,
                            if (d.downVideo    != null) 'downVideo':    d.downVideo!,
                          },
                        );
                        context.push(uri.toString());
                      },
                      child: Align(
                      alignment: Alignment.bottomCenter,
                      widthFactor: 1,
                      heightFactor: 1,
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(18, 8, 18, 10),
                        child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  d.ipName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.2,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  d.personality,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    height: 1.4,
                                    color: Colors.white
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 26),
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    final uri = Uri(
                                      path: '/chat/agent/${d.agentId}',
                                      queryParameters: {
                                        'agentName': d.ipName,
                                        if (d.helloVideo   != null) 'helloVideo':   d.helloVideo!,
                                        if (d.haitVideo    != null) 'haitVideo':    d.haitVideo!,
                                        if (d.breatheVideo != null) 'breatheVideo': d.breatheVideo!,
                                        if (d.downVideo    != null) 'downVideo':    d.downVideo!,
                                      },
                                    );
                                    context.push(uri.toString());
                                  },
                                  child: Container(
                                    width: 180,
                                    height: 46,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      gradient: _kSpotlightChatButtonGradient,
                                      borderRadius:
                                          BorderRadius.circular(100),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF5B6CFF)
                                              .withValues(alpha: 0.55),
                                          blurRadius: 20,
                                          spreadRadius: -1,
                                          offset: const Offset(0, 9),
                                        ),
                                        BoxShadow(
                                          color: const Color(0xFF8B4DFF)
                                              .withValues(alpha: 0.38),
                                          blurRadius: 28,
                                          spreadRadius: -4,
                                          offset: const Offset(0, 13),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: Center(
                                            child: Icon(
                                              Icons.mic_rounded,
                                              size: 20,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'CHAT',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            height: 1,
                                            letterSpacing: 0.85,
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
                ],
              ),
            ),
          ],
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
                              gradient: StarpathColors.blueVioletCtaGradient,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1)
                                      .withValues(alpha: 0.38),
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
