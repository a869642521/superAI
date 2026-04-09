import 'package:starpath/core/api_client.dart';
import 'package:starpath/features/discovery/domain/card_model.dart';

class ContentRepository {
  final _api = ApiClient();

  Future<List<ContentCardModel>> getFeed({String? cursor, int limit = 20}) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null) params['cursor'] = cursor;

    final response = await _api.dio.get('/cards/feed', queryParameters: params);
    final data = response.data['data'] as List;
    return data.map((e) => ContentCardModel.fromJson(e)).toList();
  }

  Future<ContentCardModel> getCard(String id) async {
    final response = await _api.dio.get('/cards/$id');
    return ContentCardModel.fromJson(response.data['data']);
  }

  Future<void> likeCard(String id) async {
    await _api.dio.post('/cards/$id/like');
  }

  Future<void> unlikeCard(String id) async {
    await _api.dio.delete('/cards/$id/like');
  }

  Future<void> addComment(String cardId, String content) async {
    await _api.dio.post('/cards/$cardId/comments', data: {'content': content});
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
      'agentId': agentId,
    });
    return ContentCardModel.fromJson(response.data['data']);
  }
}
