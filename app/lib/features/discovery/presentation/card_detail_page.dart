import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/features/discovery/data/content_providers.dart';
import 'package:starpath/features/discovery/data/discovery_demo_content.dart';
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
    with TickerProviderStateMixin {
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  final _scrollController = ScrollController();
  late final PageController _galleryPageController;
  bool _isSendingComment = false;
  int _galleryPageIndex = 0;
  bool _showBurstHeart = false;
  late final AnimationController _heartAnim;

  @override
  void initState() {
    super.initState();
    _galleryPageController = PageController();
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
    _commentFocusNode.dispose();
    _scrollController.dispose();
    _galleryPageController.dispose();
    _heartAnim.dispose();
    super.dispose();
  }

  void _onGalleryDoubleTap(ContentCardModel card) {
    _toggleLike(card);
    setState(() => _showBurstHeart = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showBurstHeart = false);
    });
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

  void _prepareReply(CommentModel comment) {
    _commentController.text = '回复 @${comment.user.nickname} ';
    _commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _commentController.text.length),
    );
    _commentFocusNode.requestFocus();
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
    final commentsAsync = ref.watch(_commentsProvider(widget.cardId));
    final isLiked = localLike ?? card.isLiked;
    final displayTitle = displayTitleForCard(card);
    final publishMeta = publishMetaForCard(card);
    final tags = tagsForCard(card);
    final commentCount = commentsAsync.valueOrNull?.length ?? card.commentCount;

    var displayLike = card.likeCount;
    if (localLike != null) {
      if (localLike == true && !card.isLiked) displayLike += 1;
      if (localLike == false && card.isLiked) displayLike -= 1;
    }

    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.of(context).padding.top + 12,
                  16,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMediaCard(card),
                    const SizedBox(height: 18),
                    Text(
                      displayTitle,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: StarpathColors.onSurface,
                        letterSpacing: -0.44,
                        height: 1.3,
                      ),
                    ),
                    if (card.title.isNotEmpty && card.title != displayTitle) ...[
                      const SizedBox(height: 6),
                      Text(
                        card.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: StarpathColors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    // Author row
                    _AuthorRow(user: card.user, publishMeta: publishMeta),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tags
                          .map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: StarpathColors.surfaceContainerHigh
                                    .withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: StarpathColors.outlineVariant,
                                ),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: StarpathColors.primary,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
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

                    const SizedBox(height: 20),
                    _SocialStatsRow(
                      likeCount: displayLike,
                      commentCount: commentCount,
                      favoriteCount: favoriteCountForCard(card),
                      shareCount: shareCountForCard(card),
                    ),

                    // Divider
                    const SizedBox(height: 24),
                    Divider(
                      color: StarpathColors.outlineVariant,
                      thickness: 0.8,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            _buildComments(card, commentsAsync),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),

        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          child: _buildBackButton(),
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
            commentFocusNode: _commentFocusNode,
            isSendingComment: _isSendingComment,
            onLike: () => _toggleLike(card),
            onSend: () => _sendComment(card),
          ),
        ),
      ],
    );
  }

  Widget _buildBackButton() {
    return ClipOval(
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
    );
  }

  Widget _buildMediaCard(ContentCardModel card) {
    final urls = galleryUrlsForCard(card);
    final ratio = coverAspectRatioForCard(card);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 12),
            spreadRadius: -8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: GestureDetector(
          onDoubleTap: () => _onGalleryDoubleTap(card),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AspectRatio(
                aspectRatio: ratio,
                child: PageView.builder(
                  controller: _galleryPageController,
                  onPageChanged: (i) => setState(() => _galleryPageIndex = i),
                  itemCount: urls.length,
                  itemBuilder: (context, i) {
                    Widget img = CachedNetworkImage(
                      imageUrl: urls[i],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorWidget: (_, __, ___) => _GradientCover(card: card),
                    );
                    if (i == 0) {
                      img = Hero(
                        tag: 'card-cover-${card.id}',
                        child: img,
                      );
                    }
                    return img;
                  },
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.34),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_galleryPageIndex + 1}/${urls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (urls.length > 1)
                Positioned(
                  bottom: 14,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(urls.length, (i) {
                      final active = i == _galleryPageIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),
                ),
              if (_showBurstHeart)
                Center(
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 100,
                    color: const Color(0xFFFF4D6D).withValues(alpha: 0.92),
                  )
                      .animate()
                      .scale(
                        duration: 220.ms,
                        begin: const Offset(0.35, 0.35),
                        curve: Curves.easeOutBack,
                      )
                      .fadeOut(
                        delay: 350.ms,
                        duration: 280.ms,
                      ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComments(
    ContentCardModel card,
    AsyncValue<List<CommentModel>> commentsAsync,
  ) {

    Widget headerRow(int count, {bool loading = false}) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Row(
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
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 13,
                  color: StarpathColors.onSurfaceVariant,
                ),
              ),
          ],
        ),
      );
    }

    return commentsAsync.when(
      loading: () => SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            headerRow(0, loading: true),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ],
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            headerRow(fakeCommentsFor(widget.cardId).length),
            ...fakeCommentsFor(widget.cardId).map(
              (c) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _CommentTile(
                  comment: c,
                  onReplyTap: _prepareReply,
                ),
              ),
            ),
          ],
        ),
      ),
      data: (comments) {
        if (comments.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  '还没有评论，来抢沙发吧',
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
            (context, i) {
              if (i == 0) {
                return headerRow(comments.length);
              }
              final comment = comments[i - 1];
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _CommentTile(
                  comment: comment,
                  onReplyTap: _prepareReply,
                ),
              );
            },
            childCount: comments.length + 1,
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
  final FocusNode commentFocusNode;
  final bool isSendingComment;
  final VoidCallback onLike;
  final VoidCallback onSend;

  const _BottomBar({
    required this.card,
    required this.isLiked,
    required this.displayLikeCount,
    required this.heartAnim,
    required this.commentController,
    required this.commentFocusNode,
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
                      focusNode: commentFocusNode,
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
  final String publishMeta;

  const _AuthorRow({
    required this.user,
    required this.publishMeta,
  });

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
              const SizedBox(height: 4),
              Text(
                publishMeta,
                style: const TextStyle(
                  fontSize: 12,
                  color: StarpathColors.textTertiary,
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

class _SocialStatsRow extends StatelessWidget {
  final int likeCount;
  final int commentCount;
  final int favoriteCount;
  final int shareCount;

  const _SocialStatsRow({
    required this.likeCount,
    required this.commentCount,
    required this.favoriteCount,
    required this.shareCount,
  });

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: StarpathColors.textTertiary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: StarpathColors.textTertiary,
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 16,
      runSpacing: 10,
      children: [
        item(Icons.favorite_rounded, _fmt(likeCount)),
        item(Icons.chat_bubble_rounded, _fmt(commentCount)),
        item(Icons.bookmark_rounded, _fmt(favoriteCount)),
        item(Icons.reply_rounded, _fmt(shareCount)),
      ],
    );
  }

  String _fmt(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}w';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
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

class _CommentTile extends StatefulWidget {
  final CommentModel comment;
  final ValueChanged<CommentModel> onReplyTap;

  const _CommentTile({
    required this.comment,
    required this.onReplyTap,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  late bool _liked = widget.comment.isLiked;
  late int _likeCount = widget.comment.likeCount;
  bool _expandedReplies = false;

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;

    Widget actionsRow({bool nested = false}) {
      return Row(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _liked = !_liked;
                _likeCount += _liked ? 1 : -1;
              });
            },
            child: Row(
              children: [
                Icon(
                  _liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 15,
                  color: _liked
                      ? const Color(0xFFFF4D6D)
                      : StarpathColors.textTertiary,
                ),
                if (_likeCount > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$_likeCount',
                    style: const TextStyle(
                      fontSize: 11,
                      color: StarpathColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          GestureDetector(
            onTap: () => widget.onReplyTap(comment),
            child: const Text(
              '回复',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: StarpathColors.textTertiary,
              ),
            ),
          ),
          if (!nested && comment.replies.isNotEmpty) ...[
            const SizedBox(width: 14),
            GestureDetector(
              onTap: () => setState(() => _expandedReplies = !_expandedReplies),
              child: Text(
                _expandedReplies
                    ? '收起回复'
                    : '展开${comment.replies.length}条回复',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: StarpathColors.primary,
                ),
              ),
            ),
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(user: comment.user, size: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            comment.user.nickname,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: StarpathColors.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (comment.isAuthorReply) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: StarpathColors.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '作者',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: StarpathColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    relativeCommentTime(comment.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: StarpathColors.textTertiary,
                    ),
                  ),
                ],
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
              const SizedBox(height: 8),
              actionsRow(),
              if (_expandedReplies && comment.replies.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  decoration: BoxDecoration(
                    color:
                        StarpathColors.surfaceContainerHigh.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: comment.replies
                        .map(
                          (reply) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _NestedReplyTile(
                              comment: reply,
                              onReplyTap: widget.onReplyTap,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NestedReplyTile extends StatefulWidget {
  final CommentModel comment;
  final ValueChanged<CommentModel> onReplyTap;

  const _NestedReplyTile({
    required this.comment,
    required this.onReplyTap,
  });

  @override
  State<_NestedReplyTile> createState() => _NestedReplyTileState();
}

class _NestedReplyTileState extends State<_NestedReplyTile> {
  late bool _liked = widget.comment.isLiked;
  late int _likeCount = widget.comment.likeCount;

  @override
  Widget build(BuildContext context) {
    final comment = widget.comment;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(user: comment.user, size: 26),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      comment.user.nickname,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: StarpathColors.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    relativeCommentTime(comment.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: StarpathColors.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                comment.content,
                style: const TextStyle(
                  fontSize: 13,
                  color: StarpathColors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _liked = !_liked;
                        _likeCount += _liked ? 1 : -1;
                      });
                    },
                    child: Row(
                      children: [
                        Icon(
                          _liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 14,
                          color: _liked
                              ? const Color(0xFFFF4D6D)
                              : StarpathColors.textTertiary,
                        ),
                        if (_likeCount > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '$_likeCount',
                            style: const TextStyle(
                              fontSize: 11,
                              color: StarpathColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: () => widget.onReplyTap(comment),
                    child: const Text(
                      '回复',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: StarpathColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
