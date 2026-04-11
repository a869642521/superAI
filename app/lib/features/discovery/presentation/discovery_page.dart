import 'dart:math';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/discovery/data/content_providers.dart';
import 'package:starpath/features/discovery/data/discovery_demo_content.dart';
import 'package:starpath/features/discovery/domain/card_model.dart';
import 'package:starpath/features/discovery/widgets/user_avatar.dart';
import 'package:starpath/features/discovery/presentation/nearby_globe_page.dart';

// ── Entry Point ───────────────────────────────────────────────────────────────

class DiscoveryPage extends ConsumerStatefulWidget {
  const DiscoveryPage({super.key});

  @override
  ConsumerState<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends ConsumerState<DiscoveryPage>
    with SingleTickerProviderStateMixin {
  // Top nav tabs: (emoji, label)
  final _navTabs = const [
    ('👥', '关注'),
    ('✨', '发现'),
    ('📍', '附近'),
  ];
  int _navIndex = 1; // "发现" selected by default

  // Category filter chips: (emoji, label)
  final _categories = const [
    ('✨', '推荐'),
    ('🤖', 'AI创作'),
    ('🔥', '热门'),
    ('📷', '摄影'),
    ('☕', '生活'),
  ];
  int _categoryIndex = 0;

  late final AnimationController _underlineAnim;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _underlineAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..forward();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _underlineAnim.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: StarpathColors.surface,
      body: Stack(
        children: [
          // ── 右上角深紫同心圆雷达背景（仅发现/关注 Tab 显示）──────────────
          if (_navIndex != 2)
            Positioned(
              right: -size.width * 0.35,
              top: -size.width * 0.25,
              child: IgnorePointer(
                child: CustomPaint(
                  size: Size(size.width * 1.1, size.width * 1.1),
                  painter: const _RadarBgPainter(),
                ),
              ),
            ),

          // ── 附近 Tab：3D 地球 ─────────────────────────────────────────────
          if (_navIndex == 2)
            const Positioned.fill(child: NearbyGlobePage()),

          // ── 关注 / 发现 Tab：瀑布流 ──────────────────────────────────────
          if (_navIndex != 2)
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                _buildAppBar(),
                _buildCategoryBar(),
                _buildMasonryFeed(),
                _buildLoadMoreIndicator(),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),

          // 附近 Tab：无 Scrollable 的独立顶栏，避免抢占地球手势
          if (_navIndex == 2)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: _buildGlobeTopBar(),
              ),
            ),
        ],
      ),
    );
  }

  // ── AppBar: 三Tab居中导航 ────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      snap: true,
      pinned: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: StarpathColors.surface.withValues(alpha: 0.88),
          ),
        ),
      ),
      title: Row(
        children: [
          // Left: search
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 24),
            color: StarpathColors.onSurfaceVariant,
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),

          // Center: 3 nav tabs
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_navTabs.length, (i) {
                final selected = i == _navIndex;
                final (emoji, label) = _navTabs[i];
                return GestureDetector(
                  onTap: () => setState(() => _navIndex = i),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: selected ? 16 : 15,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: selected
                                ? StarpathColors.onSurface
                                : StarpathColors.onSurfaceVariant,
                            letterSpacing: selected ? -0.3 : 0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                emoji,
                                style: TextStyle(
                                  fontSize: selected ? 15 : 14,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(label),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 2,
                          width: selected ? 20 : 0,
                          decoration: BoxDecoration(
                            gradient: selected
                                ? StarpathColors.selectedGradient
                                : null,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),

          // Right: notification bell
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 24),
            color: StarpathColors.onSurfaceVariant,
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  // ── 附近 Tab 顶栏（无 Scrollable，不抢手势） ────────────────────────────────

  Widget _buildGlobeTopBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: kToolbarHeight,
          color: StarpathColors.surface.withValues(alpha: 0.88),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.search_rounded, size: 24),
                color: StarpathColors.onSurfaceVariant,
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_navTabs.length, (i) {
                    final selected = i == _navIndex;
                    final (emoji, label) = _navTabs[i];
                    return GestureDetector(
                      onTap: () => setState(() => _navIndex = i),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: selected ? 16 : 15,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: selected
                                    ? StarpathColors.onSurface
                                    : StarpathColors.onSurfaceVariant,
                                letterSpacing: selected ? -0.3 : 0,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    emoji,
                                    style: TextStyle(
                                      fontSize: selected ? 15 : 14,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(label),
                                ],
                              ),
                            ),
                            const SizedBox(height: 3),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 2,
                              width: selected ? 20 : 0,
                              decoration: BoxDecoration(
                                gradient: selected
                                    ? StarpathColors.selectedGradient
                                    : null,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.notifications_outlined, size: 24),
                color: StarpathColors.onSurfaceVariant,
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Category chips: 横向滚动筛选条 ──────────────────────────────────────────

  Widget _buildCategoryBar() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 44,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
          itemCount: _categories.length,
          itemBuilder: (context, i) {
            final selected = i == _categoryIndex;
            final (emoji, label) = _categories[i];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _categoryIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    gradient:
                        selected ? StarpathColors.selectedGradient : null,
                    color: selected
                        ? null
                        : StarpathColors.surfaceContainerHigh,
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
                              color:
                                  StarpathColors.primary.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        emoji,
                        style: const TextStyle(fontSize: 14, height: 1.1),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : StarpathColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Masonry Feed ────────────────────────────────────────────────────────────

  Widget _buildMasonryFeed() {
    final state = ref.watch(feedProvider);

    if (state.isLoading) {
      return const SliverFillRemaining(
        child: Center(child: _LoadingIndicator()),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return SliverFillRemaining(
        child: _ErrorView(
          message: state.error!,
          onRetry: () => ref.read(feedProvider.notifier).refresh(),
        ),
      );
    }

    if (state.items.isEmpty) {
      return const SliverFillRemaining(child: _EmptyView());
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        itemBuilder: (context, index) => _FeedCard(
          card: state.items[index],
          index: index,
          onTap: () => context.push(
            '/cards/${state.items[index].id}',
            extra: state.items[index],
          ),
        ),
        childCount: state.items.length,
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    final state = ref.watch(feedProvider);
    if (!state.isLoadingMore) {
      return const SliverToBoxAdapter(child: SizedBox());
    }
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: _LoadingIndicator()),
      ),
    );
  }
}

// ── Feed Card (小红书风格) ──────────────────────────────────────────────────────

class _FeedCard extends StatefulWidget {
  final ContentCardModel card;
  final VoidCallback onTap;
  final int index;

  const _FeedCard({required this.card, required this.onTap, this.index = 0});

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> {
  bool _pressed = false;

  Color _hexColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    // Staggered entrance: cap delay so off-screen items don't wait forever
    final delay = Duration(milliseconds: (widget.index * 55).clamp(0, 500));

    return AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Material(
        color: StarpathColors.surfaceContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(12),
          splashColor: StarpathColors.primary.withValues(alpha: 0.14),
          highlightColor: StarpathColors.primary.withValues(alpha: 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCover(),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Text(
                  displayTitleForCard(card),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: StarpathColors.onSurface,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    )
        .animate(delay: delay)
        .fadeIn(duration: 380.ms, curve: Curves.easeOut)
        .slideY(begin: 0.18, duration: 380.ms, curve: Curves.easeOut);
  }

  /// 封面：3:4 或 4:3；首图与详情轮播第一张一致（便于 Hero）
  Widget _buildCover() {
    final c = widget.card;
    final urls = galleryUrlsForCard(c);
    final url = urls.first;
    final showMultiBadge = urls.length > 1;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AspectRatio(
          aspectRatio: coverAspectRatioForCard(c),
          child: Hero(
            tag: 'card-cover-${c.id}',
            child: CachedNetworkImage(
              imageUrl: url,
              imageBuilder: (ctx, img) => Image(
                image: img,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
              placeholder: (ctx, u) => _gradientPlaceholder(),
              errorWidget: (ctx, u, err) => _gradientPlaceholder(),
            ),
          ),
        ),
        if (showMultiBadge)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.48),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.layers_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
      ],
    );
  }

  Widget _gradientPlaceholder() {
    final c = widget.card;
    final gradStart = c.agent != null
        ? _hexColor(c.agent!.gradientStart)
        : StarpathColors.primary;
    final gradEnd = c.agent != null
        ? _hexColor(c.agent!.gradientEnd)
        : StarpathColors.secondary;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradStart.withValues(alpha: 0.85),
            gradEnd.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          c.agent?.emoji ?? '✨',
          style: const TextStyle(fontSize: 44),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final card = widget.card;
    return Container(
      color: StarpathColors.surfaceContainer.withValues(alpha: 0.55),
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 9),
      child: Row(
        children: [
          Hero(
            tag: 'card-author-${card.id}',
            child: UserAvatar(
              user: card.user,
              size: 20,
              useRandomAvatar: true,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              card.user.nickname,
              style: const TextStyle(
                fontSize: 11,
                color: StarpathColors.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Gradient heart when liked, plain when not
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => (card.isLiked
                    ? const LinearGradient(
                        colors: [Color(0xFFFF6B9D), Color(0xFF9B72FF)],
                      )
                    : const LinearGradient(
                        colors: [
                          StarpathColors.onSurfaceVariant,
                          StarpathColors.onSurfaceVariant
                        ],
                      ))
                .createShader(bounds),
            child: const Icon(Icons.favorite_rounded, size: 12,
                color: Colors.white),
          ),
          const SizedBox(width: 3),
          Text(
            _formatCount(card.likeCount),
            style: const TextStyle(
              fontSize: 11,
              color: StarpathColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}w';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ── Supporting Widgets ────────────────────────────────────────────────────────

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(StarpathColors.primary),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 48, color: StarpathColors.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            '加载失败',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: StarpathColors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('✨', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(
            '还没有内容\n快去创作第一篇吧！',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: StarpathColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── 右上角深紫雷达同心圆背景 ────────────────────────────────────────────────────

class _RadarBgPainter extends CustomPainter {
  const _RadarBgPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // 1. 中心径向渐变光晕
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF4A1A7A).withValues(alpha: 0.72),
          const Color(0xFF2D0E55).withValues(alpha: 0.48),
          const Color(0xFF1A0828).withValues(alpha: 0.22),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxR));
    canvas.drawCircle(center, maxR, glowPaint);

    // 2. 同心虚线圆（5 圈，从内向外渐隐）
    const ringCount = 5;
    for (int i = 1; i <= ringCount; i++) {
      final t = i / ringCount;
      final r = maxR * t;
      final alpha = (1.0 - t * 0.75).clamp(0.0, 1.0);

      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0xFFCC97FF).withValues(alpha: alpha * 0.35);

      const dashAngle = 0.045;
      const gapAngle = 0.025;
      double angle = 0;
      while (angle < 2 * pi) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          angle,
          dashAngle,
          false,
          ringPaint,
        );
        angle += dashAngle + gapAngle;
      }
    }

    // 3. 最内圈实线（更亮）
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFCC97FF).withValues(alpha: 0.45);
    canvas.drawCircle(center, maxR * 0.18, innerPaint);
  }

  @override
  bool shouldRepaint(_RadarBgPainter old) => false;
}
