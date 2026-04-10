import 'package:starpath/core/api_client.dart';
import 'package:starpath/features/discovery/domain/card_model.dart';

class ContentRepository {
  final _api = ApiClient();

  Future<FeedResult> getFeed({String? cursor, int limit = 20}) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null) params['cursor'] = cursor;

    final response = await _api.dio.get('/cards/feed', queryParameters: params);

    // Backend wraps response as { code, message, data: { items, nextCursor } }
    final raw = response.data;
    final body = (raw is Map && raw['data'] != null) ? raw['data'] : raw;

    if (body is Map && body['items'] != null) {
      final items = (body['items'] as List)
          .map((e) => ContentCardModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return FeedResult(
        items: items,
        nextCursor: body['nextCursor'] as String?,
      );
    } else if (body is List) {
      final items = body
          .map((e) => ContentCardModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return FeedResult(items: items, nextCursor: null);
    } else {
      return const FeedResult(items: [], nextCursor: null);
    }
  }

  Future<ContentCardModel> getCard(String id) async {
    final response = await _api.dio.get('/cards/$id');
    return ContentCardModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  Future<List<CommentModel>> getComments(String cardId) async {
    final response = await _api.dio.get('/cards/$cardId/comments');
    final data = response.data['data'] as List? ??
        response.data as List? ??
        <dynamic>[];
    return data
        .map((e) => CommentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<bool> likeCard(String id) async {
    try {
      await _api.dio.post('/cards/$id/like');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unlikeCard(String id) async {
    try {
      await _api.dio.delete('/cards/$id/like');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<CommentModel> addComment(String cardId, String content) async {
    final response = await _api.dio
        .post('/cards/$cardId/comments', data: {'content': content});
    final data = response.data['data'] ?? response.data;
    return CommentModel.fromJson(data as Map<String, dynamic>);
  }

  Future<ContentCardModel> createCard({
    required String type,
    required String title,
    required String content,
    List<String>? imageUrls,
    String? agentId,
  }) async {
    final response = await _api.dio.post('/cards', data: {
      'type': type,
      'title': title,
      'content': content,
      'imageUrls': imageUrls ?? [],
      if (agentId != null) 'agentId': agentId,
    });
    final data = response.data['data'] ?? response.data;
    return ContentCardModel.fromJson(data as Map<String, dynamic>);
  }
}
