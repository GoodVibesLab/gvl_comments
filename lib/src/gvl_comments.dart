import 'dart:convert';
import 'api_client.dart';
import 'token_store.dart';
import 'models.dart';

/// Main entry point for the GVL Comments SDK.
class GvlComments {
  static final GvlComments _i = GvlComments._();
  GvlComments._();
  factory GvlComments() => _i;

  static const _apiBase = 'https://api.goodvibeslab.cloud';

  final _api = ApiClient();
  final _tokens = TokenStore();
  CommentsConfig? _config;

  bool get isInitialized => _config != null;

  Future<void> initialize(CommentsConfig config) async {
    _config = config;
  }

  Future<String> _ensureToken() async {
    if (_tokens.isValid && _tokens.token != null) return _tokens.token!;

    final res = await _api.postJson(
      Uri.parse('$_apiBase/api/token'),
      {
        'apiKey': _config!.installKey,
        'externalUser': {
          'id': _config!.externalUserId,
          'name': _config!.externalUserName,
        },
      },
    );

    final token = res['access_token'] as String;
    final exp = (res['expires_in'] ?? 3600) as int;
    _tokens.setToken(token, Duration(seconds: exp));
    return token;
  }

  /// Fetch comments for a given thread.
  Future<List<CommentModel>> fetchComments(String threadKey) async {
    final token = await _ensureToken();
    final uri = Uri.parse('$_apiBase/api/comments?thread=$threadKey');
    final list =
    await _api.getList(uri, headers: {'Authorization': 'Bearer $token'});
    return list.map((e) => CommentModel.fromJson(e)).toList();
  }

  /// Post a comment to a thread.
  Future<CommentModel> post(String threadKey, String text) async {
    final token = await _ensureToken();
    final uri = Uri.parse('$_apiBase/api/comments');
    final res = await _api.postJson(
      uri,
      {'threadKey': threadKey, 'body': text},
      headers: {'Authorization': 'Bearer $token'},
    );
    return CommentModel.fromJson(res);
  }
}