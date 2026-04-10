import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:starpath/features/discovery/data/content_repository.dart';
import 'package:starpath/features/discovery/domain/card_model.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  return ContentRepository();
});

// ── Feed State ────────────────────────────────────────────────────────────────

class FeedState {
  final List<ContentCardModel> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? nextCursor;
  final String? error;

  const FeedState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.nextCursor,
    this.error,
  });

  FeedState copyWith({
    List<ContentCardModel>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? nextCursor,
    String? error,
    bool clearError = false,
  }) {
    return FeedState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class FeedNotifier extends StateNotifier<FeedState> {
  final ContentRepository _repo;

  FeedNotifier(this._repo) : super(const FeedState()) {
    refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true, hasMore: true);
    try {
      final result = await _repo.getFeed(limit: 20);
      final items = result.items.isEmpty ? _buildMockFeed() : result.items;
      state = FeedState(
        items: items,
        isLoading: false,
        hasMore: result.nextCursor != null,
        nextCursor: result.nextCursor,
      );
    } catch (e) {
      state = FeedState(
        items: _buildMockFeed(),
        isLoading: false,
        hasMore: false,
      );
    }
  }

  static List<ContentCardModel> _buildMockFeed() {
    final rng = Random(42);

    const titles = [
      'AI 绘制的星空旅行日记',
      '用 GPT 写了一首诗，它哭了',
      '深夜咖啡馆的赛博朋克氛围',
      '我让 AI 设计了我的房间',
      '数字艺术：光与影的碰撞',
      '用 AI 还原古代壁画的色彩',
      '城市霓虹 · 未来感街拍',
      '一个人的极简生活美学',
      '海边黄昏，治愈系风景',
      '星际旅人的最后一封信',
      'AI 助手帮我规划了环球旅行',
      '赛博朋克风格的城市夜景',
      '春日樱花·慢生活记录',
      '我用 AI 创作了一首 Lo-Fi 曲',
      '未来实验室的一天',
      '极光下的孤独与宁静',
      '量子纠缠：视觉艺术新探索',
      '山间云海·治愈心灵之旅',
      '用 AI 复刻莫奈的睡莲',
      '霓虹城市 · 像素艺术集',
    ];

    const users = [
      ('u001', '星际旅人', null),
      ('u002', '代码诗人', null),
      ('u003', '夜猫设计师', null),
      ('u004', '像素画家', null),
      ('u005', '晨光摄影师', null),
      ('u006', 'AI 探索者', null),
      ('u007', '极光追逐者', null),
      ('u008', '数字游民', null),
    ];

    const gradients = [
      ('#6C63FF', '#00D2FF'),
      ('#FF6B6B', '#FFE66D'),
      ('#A18CD1', '#FBC2EB'),
      ('#43E97B', '#38F9D7'),
      ('#FA709A', '#FEE140'),
      ('#30CFD0', '#330867'),
      ('#667EEA', '#764BA2'),
      ('#F093FB', '#F5576C'),
    ];

    const emojis = ['✨', '🎨', '🌌', '🤖', '🎵', '🌸', '🔮', '💫'];

    return List.generate(20, (i) {
      final u = users[i % users.length];
      final g = gradients[i % gradients.length];
      final seed = 100 + i * 7 + rng.nextInt(5);

      return ContentCardModel(
        id: 'mock_$i',
        userId: u.$1,
        agentId: 'agent_${i % 5}',
        type: CardType.textImage,
        title: titles[i],
        content: titles[i],
        imageUrls: ['https://picsum.photos/seed/$seed/400/300'],
        likeCount: 100 + rng.nextInt(9900),
        commentCount: 5 + rng.nextInt(200),
        createdAt: DateTime.now().subtract(Duration(hours: i * 3)),
        user: UserBrief(id: u.$1, nickname: u.$2, avatarUrl: u.$3),
        agent: AgentCardBrief(
          id: 'agent_${i % 5}',
          name: 'AI 助手 ${i % 5 + 1}',
          emoji: emojis[i % emojis.length],
          gradientStart: g.$1,
          gradientEnd: g.$2,
        ),
        isLiked: i % 4 == 0,
      );
    });
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result =
          await _repo.getFeed(cursor: state.nextCursor, limit: 20);
      state = state.copyWith(
        items: [...state.items, ...result.items],
        isLoadingMore: false,
        hasMore: result.nextCursor != null,
        nextCursor: result.nextCursor,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// Optimistically update like count in the list
  void updateLike(String cardId, {required bool liked}) {
    state = state.copyWith(
      items: state.items.map((card) {
        if (card.id != cardId) return card;
        return ContentCardModel(
          id: card.id,
          userId: card.userId,
          agentId: card.agentId,
          type: card.type,
          title: card.title,
          content: card.content,
          imageUrls: card.imageUrls,
          likeCount: liked ? card.likeCount + 1 : card.likeCount - 1,
          commentCount: card.commentCount,
          createdAt: card.createdAt,
          user: card.user,
          agent: card.agent,
          isLiked: liked,
        );
      }).toList(),
    );
  }

  /// Increment comment count after adding a comment
  void incrementCommentCount(String cardId) {
    state = state.copyWith(
      items: state.items.map((card) {
        if (card.id != cardId) return card;
        return ContentCardModel(
          id: card.id,
          userId: card.userId,
          agentId: card.agentId,
          type: card.type,
          title: card.title,
          content: card.content,
          imageUrls: card.imageUrls,
          likeCount: card.likeCount,
          commentCount: card.commentCount + 1,
          createdAt: card.createdAt,
          user: card.user,
          agent: card.agent,
          isLiked: card.isLiked,
        );
      }).toList(),
    );
  }

  /// Prepend a newly created card to the top of the feed
  void prependCard(ContentCardModel card) {
    state = state.copyWith(items: [card, ...state.items]);
  }
}

final feedProvider =
    StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  final repo = ref.watch(contentRepositoryProvider);
  return FeedNotifier(repo);
});
