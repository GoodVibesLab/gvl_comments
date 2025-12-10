import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'models.dart' hide CommentsConfig;
import 'token_store.dart';
import 'comments_config.dart';

/// High-level entry point for interacting with GoodVibesLab comments.
class CommentsKit {
  static CommentsKit? _instance;
  static CommentsKit I() => _instance!;

  final CommentsConfig _config;
  final ApiClient _http;
  final TokenStore _tokens = TokenStore();

  CommentsKit._(this._config, this._http);

  /// Minimal initialization with install key only.
  static Future<void> initialize({
    required String installKey,
    http.Client? httpClient,
  }) async {
    final cfg = await CommentsConfig.detect(installKey: installKey);
    _instance = CommentsKit._(cfg, ApiClient(httpClient: httpClient));
  }

  /// Clears the cached JWT (for example when the user changes).
  void invalidateToken() => _tokens.clear();

  // ===== Internal =====

  Future<String> _getBearer({UserProfile? user}) async {
    final cached = _tokens.validBearer();
    if (cached != null) return cached;

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-platform': _config.platform,
      'x-package-name': _config.packageName,
      'x-app-version': _config.appVersion,
    };

    final body = <String, dynamic>{
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

  // ===== Public SDK =====

  /// List comments for a thread key.
  ///
  /// [before] is an optional ISO-8601 cursor (created_at). If provided,
  /// only comments with created_at < before are returned.
  Future<List<CommentModel>> listByThreadKey(
      String threadKey, {
        required UserProfile user,
        int limit = 50,
        String? before,
      }) async {
    final bearer = await _getBearer(user: user);
    debugPrint('gvl_comments: apiBase=${_config.apiBase}');

    final params = <String, String>{
      'thread': threadKey,
      'limit': '$limit',
      if (before != null) 'before': before,
    };
    final query = Uri(queryParameters: params).query;

    final url = _config.apiBase.resolve('comments?$query');
    debugPrint('gvl_comments: listByThreadKey → $url');

    final list = await _http.getList(
      url,
      headers: {'Authorization': 'Bearer $bearer'},
    );
    return list
        .map((e) => CommentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CommentModel> post({
    required String threadKey,
    required String body,
    required UserProfile user,
  }) async {
    final bearer = await _getBearer(user: user);
    final json = await _http.postJson(
      _config.apiBase.resolve('comments'),
      {
        'threadKey': threadKey,
        'body': body,
      },
      headers: {'Authorization': 'Bearer $bearer'},
    );
    return CommentModel.fromJson(json as Map<String, dynamic>);
  }

  /// Reports a comment.
  /// Returns true if this comment was already reported by this user (duplicate),
  /// false if this is a fresh report.
  Future<bool> report({
    required String commentId,
    required UserProfile user,
    String? reason,
  }) async {
    final bearer = await _getBearer(user: user);
    final json = await _http.postJson(
      _config.apiBase.resolve('comments/report'),
      {
        'commentId': commentId,
        if (reason != null) 'reason': reason,
      },
      headers: {'Authorization': 'Bearer $bearer'},
    );

    // Two possible shapes:
    // - duplicate: { "status": "ok", "duplicate": true }
    // - fresh: [ { ... row from comment_reports ... } ]
    return json['duplicate'] == true;
  }

  /// Best-effort profile sync (name / avatar) based on the JWT.
  Future<void> identify(UserProfile user) async {
    try {
      final bearer = await _getBearer(user: user);

      await _http.postJson(
        _config.apiBase.resolve('profile/upsert'),
        {
          if (user.name != null) 'displayName': user.name,
          if (user.avatarUrl != null) 'avatarUrl': user.avatarUrl,
        },
        headers: {
          'Authorization': 'Bearer $bearer',
        },
      );
    } catch (e) {
      debugPrint('gvl_comments: error during identify(): $e');
    }
  }
}