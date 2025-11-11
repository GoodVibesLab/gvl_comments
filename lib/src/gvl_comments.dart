import 'dart:async';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'models.dart' hide CommentsConfig;
import 'token_store.dart';
import 'comments_config.dart';

class CommentsKit {
  static CommentsKit? _instance;
  static CommentsKit I() => _instance!;

  final CommentsConfig _config;
  final ApiClient _http;
  final TokenStore _tokens = TokenStore();
  UserProfile? _user;

  CommentsKit._(this._config, this._http);

  /// Init MINIMALISTE : uniquement l’installKey.
  static Future<void> initialize({
    required String installKey,
    http.Client? httpClient,
  }) async {
    final cfg = await CommentsConfig.detect(installKey: installKey);
    _instance = CommentsKit._(cfg, ApiClient(httpClient: httpClient));
  }

  /// Binder l’utilisateur plus tard (ex: à l’ouverture de l’écran Comments).
  Future<void> setUser(UserProfile? user) async {
    _user = user;
    await _tokens.clear(); // force un nouveau JWT (claims user)
  }

  bool get hasUser => _user != null;

  // === Private ===

  Future<String> _getBearer() async {
    final cached = _tokens.validBearer();
    if (cached != null) return cached;

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-platform': _config.platform,
      'x-package-name': _config.packageName,
      'x-app-version': _config.appVersion,
    };

    final body = {
      'apiKey': _config.installKey,
      if (_user != null)
        'externalUser': {
          'id': _user!.id,
          if (_user!.name != null) 'name': _user!.name,
          if (_user!.avatarUrl != null) 'avatarUrl': _user!.avatarUrl,
        },
    };

    final json = await _http.postJson(_config.apiBase.resolve('/api/token'), body, headers: headers);
    final token = json['access_token'] as String;
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
    _tokens.save(token, expiresIn);
    return token;
  }

  // === Public SDK ===

  Future<List<CommentModel>> listByThreadKey(String threadKey, {int limit = 50}) async {
    final bearer = await _getBearer();
    final url = _config.apiBase
        .resolve('/api/comments?thread=${Uri.encodeComponent(threadKey)}&limit=$limit');
    final list = await _http.getList(url, headers: {'Authorization': 'Bearer $bearer'});
    return list.map((e) => CommentModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CommentModel> post({required String threadKey, required String body}) async {
    if (_user == null) {
      throw StateError('No user bound. Call setUser(UserProfile(...)) before posting.');
    }
    final bearer = await _getBearer();
    final json = await _http.postJson(
      _config.apiBase.resolve('/api/comments'),
      {'threadKey': threadKey, 'body': body},
      headers: {'Authorization': 'Bearer $bearer'},
    );
    return CommentModel.fromJson(json as Map<String, dynamic>);
  }
}