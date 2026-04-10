import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/discovery/data/content_providers.dart';
import 'package:starpath/features/discovery/data/content_repository.dart';
import 'package:starpath/features/discovery/domain/card_model.dart';
import 'package:starpath/features/discovery/widgets/user_avatar.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _cardDetailProvider =
    FutureProvider.family<ContentCardModel, String>((ref, id) async {
  final repo = ref.watch(contentRepositoryProvider);
  return repo.getCard(id);
});

final _commentsProvider =
    FutureProvider.family<List<CommentModel>, String>((ref, cardId) async {
  final repo = ref.watch(contentRepositoryProvider);
  return repo.getComments(cardId);
});

// Local like state for the detail page (optimistic)
final _localLikeProvider =
    StateProvider.family<bool?, String>((ref, cardId) => null);

// ── Page ──────────────────────────────────────────────────────────────────────

class CardDetailPage extends ConsumerStatefulWidget {
  final String cardId;
  const CardDetailPage({super.key, required this.cardId});

  @override
  ConsumerState<CardDetailPage> createState() => _CardDetailPageState();
}

class _CardDetailPageState extends ConsumerState<CardDetailPage>
    with SingleTickerProviderStateMixin {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSendingComment = false;
  late final AnimationController _heartAnim;

  @override
  void initState() {
    super.initState();
    _heartAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 0.75,
      upperBound: 1.25,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _heartAnim.dispose();
    super.dispose();
  }

  Future<void> _toggleLike(ContentCardModel card) async {
    final localLike = ref.read(_localLikeProvider(widget.cardId));
    final isCurrentlyLiked = localLike ?? card.isLiked;

    // Optimistic update
    ref.read(_localLikeProvider(widget.cardId).notifier).state =
        !isCurrentlyLiked;
    ref.read(feedProvider.notifier).updateLike(
          widget.cardId,
          liked: !isCurrentlyLiked,
        );

    // Animate heart
    HapticFeedback.lightImpact();
    _heartAnim.forward().then((_) => _heartAnim.reverse());

    // API call
    final repo = ref.read(contentRepositoryProvider);
    final success = isCurrentlyLiked
        ? await repo.unlikeCard(widget.cardId)
        : await repo.likeCard(widget.cardId);

    if (!success && mounted) {
      // Revert on failure
      ref.read(_localLikeProvider(widget.cardId).notifier).state =
          isCurrentlyLiked;
      ref.read(feedProvider.notifier).updateLike(
            widget.cardId,
            liked: isCurrentlyLiked,
          );
    }
  }

  Future<void> _sendComment(ContentCardModel card) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSendingComment = true);
    _commentController.clear();

    try {
      final repo = ref.read(contentRepositoryProvider);
      await repo.addComment(widget.cardId, text);
      ref.read(feedProvider.notifier).incrementCommentCount(widget.cardId);
      // Invalidate comments so they reload
      ref.invalidate(_commentsProvider(widget.cardId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardAsync = ref.watch(_cardDetailProvider(widget.cardId));

    return Scaffold(
      backgroundColor: StarpathColors.surface,
      body: cardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('加载失败：$e',
              style: const TextStyle(color: StarpathColors.onSurfaceVariant)),
        ),
        data: (card) => _buildContent(card),
      ),
    );
  }

  Widget _buildContent(ContentCardModel card) {
    final localLike = ref.watch(_localLikeProvider(widget.cardId));
    final isLiked = localLike ?? card.isLiked;

    // Compute displayed like count adjusted for local state
    int displayLike = card.likeCount;
    if (localLike != null) {
      final diff = localLike ? 1 : -1;
      final baseDiff = card.isLiked ? 1 : 0;
      displayLike = card.likeCount - baseDiff + (localLike ? 1 : 0);
      displayLike = card.likeCount + diff - (card.isLiked ? 1 : 0);
    }

    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildSliverAppBar(card),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    if (card.title.isNotEmpty) ...[
                      Text(
                        card.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: StarpathColors.onSurface,
                          letterSpacing: -0.44,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Author row
                    _AuthorRow(user: card.user),
                    const SizedBox(height: 16),

                    // Body content
                    Text(
                      card.content,
                      style: const TextStyle(
                        fontSize: 15,
                        color: StarpathColors.onSurfaceVariant,
                        height: 1.65,
                      ),
                    ),

                    // Agent tag
                    if (card.agent != null) ...[
                      const SizedBox(height: 20),
                      _AgentTag(agent: card.agent!),
                    ],

                    // Divider
                    const SizedBox(height: 24),
                    Divider(
                      color: StarpathColors.outlineVariant,
                      thickness: 0.8,
                    ),
                    const SizedBox(height: 8),

                    // Comments header
                    Row(
                      children: [
                        Text(
                          '评论',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: StarpathColors.onSurface,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${card.commentCount}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: StarpathColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            _buildComments(card),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),

        // Bottom action bar: like + comment
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _BottomBar(
            card: card,
            isLiked: isLiked,
            displayLikeCount: displayLike,
            heartAnim: _heartAnim,
            commentController: _commentController,
            isSendingComment: _isSendingComment,
            onLike: () => _toggleLike(card),
            onSend: () => _sendComment(card),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar(ContentCardModel card) {
    final hasImage = card.imageUrls.isNotEmpty;

    return SliverAppBar(
      expandedHeight: hasImage ? 300 : 180,
      pinned: true,
      stretch: true,
      backgroundColor: StarpathColors.surface,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: StarpathColors.surfaceContainer.withValues(alpha: 0.6),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                color: StarpathColors.onSurface,
                onPressed: () => context.pop(),
              ),
            ),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: hasImage
            ? _CoverImage(url: card.imageUrls.first)
            : _GradientCover(card: card),
      ),
    );
  }

  Widget _buildComments(ContentCardModel card) {
    final commentsAsync = ref.watch(_commentsProvider(widget.cardId));

    return commentsAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (e, _) => const SliverToBoxAdapter(child: SizedBox()),
      data: (comments) {
        if (comments.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  '还没有评论，来抢沙发吧 🎉',
                  style: const TextStyle(
                    color: StarpathColors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: _CommentTile(comment: comments[i]),
            ),
            childCount: comments.length,
          ),
        );
      },
    );
  }
}

// ── Bottom Bar ────────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final ContentCardModel card;
  final bool isLiked;
  final int displayLikeCount;
  final AnimationController heartAnim;
  final TextEditingController commentController;
  final bool isSendingComment;
  final VoidCallback onLike;
  final VoidCallback onSend;

  const _BottomBar({
    required this.card,
    required this.isLiked,
    required this.displayLikeCount,
    required this.heartAnim,
    required this.commentController,
    required this.isSendingComment,
    required this.onLike,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: StarpathColors.surfaceContainer.withValues(alpha: 0.8),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // Comment input
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: StarpathColors.surfaceContainerHigh
                          .withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: TextField(
                      controller: commentController,
                      style: const TextStyle(
                        fontSize: 14,
                        color: StarpathColors.onSurface,
                      ),
                      decoration: const InputDecoration(
                        hintText: '说点什么...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: StarpathColors.textTertiary,
                        ),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Send button
                GestureDetector(
                  onTap: onSend,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      gradient: StarpathColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: isSendingComment
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 10),

                // Like button
                GestureDetector(
                  onTap: onLike,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: heartAnim,
                        child: Icon(
                          isLiked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 26,
                          color: isLiked
                              ? const Color(0xFFFF4D6D)
                              : StarpathColors.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _fmt(displayLikeCount),
                        style: TextStyle(
                          fontSize: 11,
                          color: isLiked
                              ? const Color(0xFFFF4D6D)
                              : StarpathColors.textTertiary,
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
    );
  }

  String _fmt(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}w';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _CoverImage extends StatelessWidget {
  final String url;
  const _CoverImage({required this.url});

  @override
  Widget build(BuildContext context) => CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorWidget: (_, __, ___) => const _GradientFallback(),
      );
}

class _GradientFallback extends StatelessWidget {
  const _GradientFallback();

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: StarpathColors.primaryGradient,
        ),
      );
}

class _GradientCover extends StatelessWidget {
  final ContentCardModel card;
  const _GradientCover({required this.card});

  Color _hexColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final gradStart = card.agent != null
        ? _hexColor(card.agent!.gradientStart)
        : StarpathColors.primary;
    final gradEnd = card.agent != null
        ? _hexColor(card.agent!.gradientEnd)
        : StarpathColors.secondary;

    return Container(
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
          style: const TextStyle(fontSize: 72),
        ),
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  final UserBrief user;
  const _AuthorRow({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        UserAvatar(user: user, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.nickname,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: StarpathColors.onSurface,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            gradient: StarpathColors.primaryGradient,
            borderRadius: BorderRadius.circular(100),
          ),
          child: const Text(
            '关注',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: StarpathColors.onPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _AgentTag extends StatelessWidget {
  final AgentCardBrief agent;
  const _AgentTag({required this.agent});

  Color _hexColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final gradStart = _hexColor(agent.gradientStart);
    final gradEnd = _hexColor(agent.gradientEnd);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradStart.withValues(alpha: 0.15),
            gradEnd.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: gradStart.withValues(alpha: 0.30),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(agent.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI 伙伴',
                style: TextStyle(
                  fontSize: 10,
                  color: StarpathColors.textTertiary,
                ),
              ),
              Text(
                agent.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: StarpathColors.onSurface,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [gradStart, gradEnd]),
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Text(
              '去聊天',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommentModel comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(user: comment.user, size: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                comment.user.nickname,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: StarpathColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                comment.content,
                style: const TextStyle(
                  fontSize: 14,
                  color: StarpathColors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
