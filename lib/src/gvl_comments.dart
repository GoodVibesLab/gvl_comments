import 'dart:async';
import 'package:flutter/cupertino.dart';
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

  CommentsKit._(this._config, this._http);

  /// Initialisation minimale : clé d’installation uniquement
  static Future<void> initialize({
    required String installKey,
    http.Client? httpClient,
  }) async {
    final cfg = await CommentsConfig.detect(installKey: installKey);
    _instance = CommentsKit._(cfg, ApiClient(httpClient: httpClient));
  }

  /// Permet d’invalider le JWT stocké (par ex. quand l’utilisateur change)
  void invalidateToken() => _tokens.clear();

  // === Private ===

  Future<String> _getBearer({UserProfile? user}) async {
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
      if (user != null)
        'externalUser': {
          'id': user.id,
          if (user.name != null) 'name': user.name,
          if (user.avatarUrl != null) 'avatarUrl': user.avatarUrl,
        },
    };

    final json = await _http.postJson(
      _config.apiBase.resolve('token'),
      body,
      headers: headers,
    );

    final token = json['access_token'] as String;
    final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
    _tokens.save(token, expiresIn);
    return token;
  }

  // === Public SDK ===

  /// Récupère la liste des commentaires d’un thread
  Future<List<CommentModel>> listByThreadKey(
      String threadKey, {
        int limit = 50,
        UserProfile? user, // <-- ajouté
      }) async {
    final bearer = await _getBearer(user: user);
    debugPrint('apiBase=${_config.apiBase}');
    final url = _config.apiBase.resolve(
      'comments?thread=${Uri.encodeComponent(threadKey)}&limit=$limit',
    );

    debugPrint('CommentsKit.listByThreadKey: url=$url');
    final list = await _http.getList(url, headers: {'Authorization': 'Bearer $bearer'});
    return list.map((e) => CommentModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Poste un nouveau commentaire
  Future<CommentModel> post({
    required String threadKey,
    required String body,
    required UserProfile user, // <-- obligatoire ici
  }) async {
    final bearer = await _getBearer(user: user);
    final json = await _http.postJson(
      _config.apiBase.resolve('comments'),
      {'threadKey': threadKey, 'body': body},
      headers: {'Authorization': 'Bearer $bearer'},
    );
    return CommentModel.fromJson(json as Map<String, dynamic>);
  }

  Future<void> identify(UserProfile user) async {
    // Option “soft”: si tu veux que ça ne casse pas en cas d’erreur, tu catch ici.
    await _http.postJson(
      _config.apiBase.resolve('profile/upsert'),
      {
        'external_user_id': user.id,
        if (user.name != null) 'display_name': user.name,
        if (user.avatarUrl != null) 'avatar_url': user.avatarUrl,
      },
      headers: {
        'Authorization': 'Bearer ${_config.installKey}', // si endpoint protégé par clé d'install
      },
    );
  }
}