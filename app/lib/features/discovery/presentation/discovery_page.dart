import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/discovery/data/content_providers.dart';
import 'package:starpath/features/discovery/domain/card_model.dart';
import 'package:starpath/features/discovery/widgets/user_avatar.dart';

// ── Entry Point ───────────────────────────────────────────────────────────────

class DiscoveryPage extends ConsumerStatefulWidget {
  const DiscoveryPage({super.key});

  @override
  ConsumerState<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends ConsumerState<DiscoveryPage>
    with SingleTickerProviderStateMixin {
  // Top nav tabs
  final _navTabs = const ['关注', '发现', '附近'];
  int _navIndex = 1; // "发现" selected by default

  // Category filter chips
  final _categories = const ['推荐', 'AI创作', '热门', '摄影', '生活'];
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
    return Scaffold(
      backgroundColor: StarpathColors.surface,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildAppBar(),
          _buildCategoryBar(),
          _buildMasonryFeed(),
          _buildLoadMoreIndicator(),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
                return GestureDetector(
                  onTap: () => setState(() => _navIndex = i),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
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
                          child: Text(_navTabs[i]),
                        ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 2,
                          width: selected ? 20 : 0,
                          decoration: BoxDecoration(
                            gradient: selected
                                ? StarpathColors.primaryGradient
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
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _categoryIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 5),
                  decoration: BoxDecoration(
                    gradient:
                        selected ? StarpathColors.primaryGradient : null,
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
                  child: Text(
                    _categories[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? StarpathColors.onPrimary
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
          onTap: () => context.push('/cards/${state.items[index].id}'),
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

class _FeedCard extends StatelessWidget {
  final ContentCardModel card;
  final VoidCallback onTap;

  const _FeedCard({required this.card, required this.onTap});

  Color _hexColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = card.imageUrls.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cover with title overlay ─────────────────────────────────
            _buildCoverWithTitle(hasImage),

            // ── Footer: avatar + name + likes ───────────────────────────
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverWithTitle(bool hasImage) {
    return Stack(
      children: [
        // Image / gradient placeholder — fixed 4:3 ratio
        AspectRatio(
          aspectRatio: 4 / 3,
          child: hasImage
              ? CachedNetworkImage(
                  imageUrl: card.imageUrls.first,
                  imageBuilder: (ctx, img) => Image(
                    image: img,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                  placeholder: (ctx, url) => _gradientPlaceholder(),
                  errorWidget: (ctx, url, err) => _gradientPlaceholder(),
                )
              : _gradientPlaceholder(),
        ),

        // Dark gradient overlay at bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 32, 10, 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0xCC000000), // black ~80%
                ],
              ),
            ),
            child: Text(
              card.title.isNotEmpty ? card.title : card.content,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.4,
                shadows: [
                  Shadow(
                    color: Color(0x66000000),
                    blurRadius: 4,
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _gradientPlaceholder() {
    final gradStart = card.agent != null
        ? _hexColor(card.agent!.gradientStart)
        : StarpathColors.primary;
    final gradEnd = card.agent != null
        ? _hexColor(card.agent!.gradientEnd)
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
          card.agent?.emoji ?? '✨',
          style: const TextStyle(fontSize: 44),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      color: StarpathColors.surfaceContainer.withValues(alpha: 0.55),
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 9),
      child: Row(
        children: [
          UserAvatar(user: card.user, size: 20),
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
          Icon(
            Icons.favorite_rounded,
            size: 12,
            color: card.isLiked
                ? const Color(0xFFFF4D6D)
                : StarpathColors.onSurfaceVariant,
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
