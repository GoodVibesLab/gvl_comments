import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'models.dart';
import 'token_store.dart';
import 'comments_config.dart';
import 'utils/comments_logger.dart';

/// Typed auth error thrown by the SDK when authentication cannot proceed.
///
/// This is intentionally lightweight and stable so client apps can branch on
/// [code] (e.g. show a dedicated install-key / binding screen).
class CommentsAuthException implements Exception {
  CommentsAuthException(this.code, {this.requestId, this.message});

  /// Stable machine-readable error code (e.g. `invalid_binding`).
  final String code;

  /// Optional correlation id returned by the API.
  final String? requestId;

  /// Optional human-readable message (safe to display).
  final String? message;

  @override
  String toString() {
    final rid = requestId != null ? ', request_id=$requestId' : '';
    final msg = message != null ? ', message=$message' : '';
    return 'CommentsAuthException(code=$code$rid$msg)';
  }
}

/// High-level entry point for interacting with GoodVibesLab comments.
///
/// Use [initialize] once during app startup, then access the singleton via
/// [CommentsKit.I]. All network operations are routed through this instance.
class CommentsKit {
  static const String _threadKeyDocsUrl = 'https://www.goodvibeslab.cloud/docs';

  /// Default number of comments fetched per page when no limit is specified.
  ///
  /// Tuned for mobile-first UX and fast first paint.
  static const int defaultPageSize = 30;

  /// Hard upper bound for comments pagination.
  ///
  /// This protects client apps from accidental over-fetching that could lead
  /// to performance issues or excessive memory usage.
  static const int maxPageSize = 100;
  static CommentsKit? _instance;

  /// Returns the previously initialized singleton instance.
  ///
  /// Call [initialize] before invoking this method. Accessing [I] without prior
  /// initialization will throw a runtime error.
  static CommentsKit I() {
    final i = _instance;
    if (i == null) {
      throw StateError(
          'CommentsKit not initialized. Call CommentsKit.initialize() first.');
    }
    return i;
  }

  static CommentsKit get instance => I();

  final CommentsConfig _config;
  final ApiClient _http;

  late final String _installKeyHash12 =
      sha256.convert(utf8.encode(_config.installKey)).toString().substring(0, 12);

  /// Thread-scoped bearer token (used for list/post on a real thread).
  final TokenStore _threadTokens = TokenStore();

  /// Meta-scoped bearer token (used for identify/settings/report/react).
  ///
  /// Keeping this separate prevents "token scoped to different thread" churn
  /// when meta calls happen before/after opening a real thread.
  final TokenStore _metaTokens = TokenStore();

  Future<String>? _authInFlight;
  Future<String>? _metaAuthInFlight;
  DateTime? _invalidBindingUntil;

  /// The threadKey the current cached *thread* token is scoped to (server-enforced in prod).
  String? _tokenThreadKey;

  /// Latest user passed to identify() when no token was available yet.
  /// Will be replayed automatically after a successful token acquisition.
  UserProfile? _pendingIdentifyUser;

  /// Prevent concurrent identify flushes.
  Future<void>? _identifyInFlight;

  CommentsKit._(this._config, this._http);

  // ===== Logging helpers =====

  static String _safeKeyPrefix(String key) {
    final k = key.trim();
    if (k.isEmpty) return '(empty)';
    if (k.length <= 10) return '$k…';
    return '${k.substring(0, 10)}…';
  }

  static String _safeUserId(String id) {
    final u = id.trim();
    if (u.isEmpty) return '(empty)';
    if (u.length <= 6) return u;
    return '${u.substring(0, 3)}…${u.substring(u.length - 2)}';
  }

  static String _redactedTokenHeadersForLogs(Map<String, String> headers) {
    // Avoid printing full device/app binding proofs unless explicitly in TRACE.
    if (CommentsLogger.level.index >= CommentsLogLevel.trace.index) {
      return headers.toString();
    }

    final redacted = Map<String, String>.from(headers);
    if (redacted.containsKey('x-android-sha256')) {
      redacted['x-android-sha256'] = '***';
    }
    if (redacted.containsKey('x-ios-team-id')) {
      redacted['x-ios-team-id'] = '***';
    }
    return redacted.toString();
  }

  /// Current billing plan for this install (e.g. "free", "starter", "pro").
  ///
  /// Prefer the thread-scoped plan when available, otherwise fall back to the
  /// meta-scoped plan.
  String? get currentPlan => _threadTokens.plan ?? _metaTokens.plan;

  /// Last pagination cursor returned by the API (opaque).
  ///
  /// When present, pass it back via `cursor:` to fetch the next page.
  String? lastNextCursor;

  /// Whether the API indicates more pages are available.
  bool lastHasMore = false;

  /// Minimal initialization with install key only.
  ///
  /// Provide your GoodVibesLab [installKey] and an optional custom [httpClient]
  /// if you need advanced networking controls (for example interceptors or
  /// caching). Must be awaited before using [CommentsKit.I].
  static Future<void> initialize({
    required String installKey,
    http.Client? httpClient,
    CommentsLogLevel? logLevel,
  }) async {
    final trimmedKey = installKey.trim();
    CommentsLogger.level = logLevel ??
        (kReleaseMode ? CommentsLogLevel.error : CommentsLogLevel.debug);
    if (trimmedKey.isEmpty) {
      CommentsLogger.error(
        'install key missing. Create one at https://goodvibeslab.cloud and pass it via --dart-define=GVL_INSTALL_KEY="cmt_live_xxx"',
      );
      throw StateError('GVL install key missing');
    }
    final cfg = await CommentsConfig.detect(installKey: trimmedKey);
    _instance = CommentsKit._(cfg, ApiClient(httpClient: httpClient));
    CommentsLogger.info(
      'initialized (platform=${cfg.platform}, package=${cfg.packageName}, key=${_safeKeyPrefix(cfg.installKey)})',
    );
  }

  /// Disposes the SDK instance and clears cached tokens.
  void dispose() {
    invalidateToken();
    _http.close();
  }

  /// Clears the cached JWT (for example when the user changes).
  void invalidateToken() {
    CommentsLogger.info('token cache cleared');
    lastNextCursor = null;
    lastHasMore = false;

    // Clear both caches: thread + meta.
    _threadTokens.clear();
    _metaTokens.clear();

    _tokenThreadKey = null;

    // Intentionally keep _pendingIdentifyUser so a profile update can be
    // replayed once a token is obtained again.
  }

  String _metaThreadKey(String purpose, {String? a, String? b}) {
    String clean(String s) => s.replaceAll(RegExp(r'[^a-zA-Z0-9:_\-\.]'), '');

    final p = clean(purpose);
    final aa = clean(a ?? '');
    final bb = clean(b ?? '');

    final base = 'meta:$p:$_installKeyHash12';
    if (aa.isEmpty && bb.isEmpty) return base;
    if (bb.isEmpty) return '$base:$aa';
    return '$base:$aa:$bb';
  }

  // ===== threadKey validation (strict) =====

  /// Strict production rule: threadKey must be high-entropy (UUID/ULID/Firestore docId).
  ///
  /// Rationale: prevents guessable thread ids like `post-123` which make scraping/spam cheap.
  ///
  /// Format constraints:
  /// - Allowed chars: [a-zA-Z0-9:_-.]
  /// - Minimum length: 20
  ///
  /// See docs: https://www.goodvibeslab.cloud/docs
  static bool _isValidThreadKeyFormat(String v) {
    final s = v.trim();
    if (s.length < 20) return false;
    return RegExp(r'^[a-zA-Z0-9:_\-\.]+$').hasMatch(s);
  }

  static bool _looksHighEntropy(String v) {
    final s = v.trim();

    // UUID (accept any UUID shape, not only v4)
    if (RegExp(
            r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$')
        .hasMatch(s)) {
      return true;
    }

    // ULID (26 Crockford base32)
    if (RegExp(r'^[0-9A-HJKMNP-TV-Z]{26}$').hasMatch(s)) {
      return true;
    }

    // Generic heuristic: require at least 2 character classes among lower/upper/digit.
    // This rejects simple slugs like `post-123` even if long.
    final hasLower = RegExp(r'[a-z]').hasMatch(s);
    final hasUpper = RegExp(r'[A-Z]').hasMatch(s);
    final hasDigit = RegExp(r'[0-9]').hasMatch(s);
    final categories = [hasLower, hasUpper, hasDigit].where((x) => x).length;

    // Reject obvious guessable patterns.
    final looksTooSimple = RegExp(
      r'^(post|article|thread|item|page|news|blog|product|video)[:_\-]?\d+$',
      caseSensitive: false,
    ).hasMatch(s);

    return !looksTooSimple && categories >= 2 && s.length >= 20;
  }

  static void _assertStrictThreadKey(String threadKey) {
    final tk = threadKey.trim();
    if (tk.isEmpty) {
      CommentsLogger.error('invalid threadKey: empty (see $_threadKeyDocsUrl)');
      throw ArgumentError('threadKey is required. See $_threadKeyDocsUrl');
    }
    if (!_isValidThreadKeyFormat(tk)) {
      CommentsLogger.error(
          'invalid threadKey format: "$tk" (see $_threadKeyDocsUrl)');
      throw ArgumentError(
        'Invalid threadKey format. Allowed: [a-zA-Z0-9:_-.], min length 20. See $_threadKeyDocsUrl',
      );
    }
    if (!_looksHighEntropy(tk)) {
      CommentsLogger.error(
          'threadKey too guessable: "$tk" (see $_threadKeyDocsUrl)');
      throw ArgumentError(
        'threadKey is too guessable. Use a UUID/ULID/Firestore docId (>=20 chars). See $_threadKeyDocsUrl',
      );
    }
  }
  // ===== Internal =====

  Future<String> _getBearer(
      {required String threadKey, UserProfile? user}) async {
    final tk = threadKey.trim();
    if (tk.isEmpty) {
      throw StateError('threadKey is required to obtain an auth token');
    }

    final cached = _threadTokens.validBearer();
    if (cached != null && _tokenThreadKey == tk) {
      CommentsLogger.info('auth token cache hit');
      return cached;
    }

    if (cached != null && _tokenThreadKey != tk) {
      // The token is scoped to a different thread. Clear it and fetch a new one.
      CommentsLogger.info('auth token scoped to different thread, refreshing');
      _threadTokens.clear();
    }

    final now = DateTime.now();
    if (_invalidBindingUntil != null && now.isBefore(_invalidBindingUntil!)) {
      CommentsLogger.info('auth blocked (invalid_binding cooldown active)');
      throw CommentsAuthException(
        'invalid_binding',
        message:
            'This API key requires a valid app binding (signature/origin).',
      );
    }

    if (_authInFlight != null) {
      return _authInFlight!;
    }

    CommentsLogger.debug(
        'Preparing headers for token request: ${_redactedTokenHeadersForLogs(_config.tokenHeaders())}');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      ..._config.tokenHeaders(),
    };

    final body = <String, dynamic>{
      'apiKey': _config.installKey,
      'threadKey': tk,
      if (user != null)
        'externalUser': {
          'id': user.id,
          if (user.name != null) 'name': user.name,
          if (user.avatarUrl != null) 'avatarUrl': user.avatarUrl,
        },
    };

    CommentsLogger.info('requesting auth token');

    _authInFlight = () async {
      try {
        final json = await _http.postJson(
          _config.apiBase.resolve('token'),
          body,
          headers: headers,
        );

        final token = json['access_token'] as String;
        final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
        final plan = json['plan'] as String?;
        _threadTokens.save(token, expiresIn, plan: plan);
        _tokenThreadKey = tk;
        CommentsLogger.info(
            'auth token received (expiresIn=${expiresIn}s, plan=${plan ?? "unknown"})');

        // Replay pending identify in the background (best-effort).
        _flushPendingIdentifyIfAny().ignore();

        return token;
      } catch (e) {
        CommentsLogger.error(
          'failed to obtain auth token. Check your install key at https://goodvibeslab.cloud '
          '(key=${_safeKeyPrefix(_config.installKey)}): $e',
        );

        final msg = e.toString();
        if (msg.contains('"error":"invalid_binding"') ||
            msg.contains('invalid_binding')) {
          _invalidBindingUntil =
              DateTime.now().add(const Duration(seconds: 60));
          CommentsLogger.info('invalid_binding detected, cooling down for 60s');

          // Throw a stable typed exception so callers can branch without
          // relying on string parsing.
          throw CommentsAuthException(
            'invalid_binding',
            message:
                'This API key requires a valid app binding (signature/origin).',
          );
        }
        rethrow;
      } finally {
        _authInFlight = null;
      }
    }();

    return _authInFlight!;
  }

  // ===== Public SDK =====

  /// Fetches moderation settings for the current tenant.
  ///
  /// The result is cached in memory for the lifetime of the process. It is
  /// cleared when [invalidateToken] is called (for example when the user
  /// changes or you want to force a refresh).
  Future<ModerationSettings> getModerationSettings({
    UserProfile? user,
  }) async {
    late final String bearer;
    try {
      bearer = await _getMetaBearer(purpose: 'settings', user: user);
    } catch (_) {
      CommentsLogger.info(
          'skipping moderation settings load due to auth failure');
      rethrow;
    }

    final json = await _http.getJson(
      _config.apiBase.resolve('comments/settings'),
      headers: {'Authorization': 'Bearer $bearer'},
    );

    final settings = ModerationSettings.fromJson(json);
    return settings;
  }

  /// Lists comments for a thread key.
  ///
  /// Pagination:
  /// - Prefer [cursor] (opaque) which comes from the `x-next-cursor` response header.
  /// - [before] is legacy (ISO-8601 created_at) and may skip items when multiple
  ///   comments share the same timestamp.
  ///
  /// [limit] controls the maximum number of comments to retrieve per call. Throws when network calls fail.
  Future<List<CommentModel>> listByThreadKey(
    String threadKey, {
    required UserProfile user,
    int limit = defaultPageSize,
    String? before,
    String? cursor,
  }) async {
    try {
      _assertStrictThreadKey(threadKey);
      final bearer = await _getBearer(threadKey: threadKey, user: user);
      CommentsLogger.info(
        'loading comments (limit=${limit.clamp(1, maxPageSize)}${(cursor != null || before != null) ? ", paginated" : ""})',
      );

      // Clamp limit to a safe range to avoid accidental over-fetching.
      final effectiveLimit = limit.clamp(1, maxPageSize);

      // Build a safe URL using queryParameters (no manual encoding, avoids double-encoding bugs).
      final params = <String, String>{
        'thread': threadKey,
        'limit': '$effectiveLimit',
        if (cursor != null) 'cursor': cursor,
        if (cursor == null && before != null) 'before': before,
      };

      final url =
          _config.apiBase.resolve('comments').replace(queryParameters: params);

      final res = await _http.getRaw(
        url,
        headers: {'Authorization': 'Bearer $bearer'},
      );

      // Capture pagination headers (best-effort).
      lastNextCursor = res.headers['x-next-cursor'];
      final hm = res.headers['x-has-more']?.toLowerCase();
      lastHasMore = hm == 'true' || hm == '1';

      final list = await _http.decodeListResponse(res);
      return list.map((e) => CommentModel.fromJson(e)).toList();
    } catch (e, stack) {
      // Keep auth failures stable and non-noisy.
      if (e is CommentsAuthException) {
        CommentsLogger.error('failed to load comments: $e');
        rethrow;
      }

      if (!kReleaseMode) {
        debugPrintStack(stackTrace: stack);
      }
      CommentsLogger.error('failed to load comments: $e');
      throw StateError('Failed to load comments: $e');
    }
  }

  /// Posts a new comment in the specified thread.
  ///
  /// The comment body is sent as-is; perform validation in your UI before
  /// calling this method. Returns the created [CommentModel] populated with
  /// server timestamps and moderation status. Requires the calling [user] to be
  /// authenticated via [initialize].
  Future<CommentModel> post({
    required String threadKey,
    required String body,
    required UserProfile user,
  }) async {
    _assertStrictThreadKey(threadKey);
    CommentsLogger.info('posting comment');
    final bearer = await _getBearer(threadKey: threadKey, user: user);
    try {
      final json = await _http.postJson(
        _config.apiBase.resolve('comments'),
        {
          'threadKey': threadKey,
          'body': body,
        },
        headers: {'Authorization': 'Bearer $bearer'},
      );
      CommentsLogger.info('comment posted');
      return CommentModel.fromJson(json);
    } catch (e) {
      CommentsLogger.error('failed to post comment: $e');
      rethrow;
    }
  }

  /// Reports a comment.
  ///
  /// Returns `true` if this comment was already reported by the same user
  /// (duplicate), `false` if the report was freshly recorded by the backend.
  Future<bool> report({
    required String commentId,
    required UserProfile user,
    String? reason,
  }) async {
    final bearer = await _getMetaBearer(purpose: 'report', user: user);
    CommentsLogger.info('reporting comment');
    Map<String, dynamic> json;
    try {
      json = await _http.postJson(
        _config.apiBase.resolve('comments/report'),
        {
          'commentId': commentId,
          if (reason != null) 'reason': reason,
        },
        headers: {'Authorization': 'Bearer $bearer'},
      );
      CommentsLogger.info('report sent');
    } catch (e) {
      CommentsLogger.error('failed to report comment: $e');
      rethrow;
    }

    // Two possible shapes:
    // - duplicate: { "status": "ok", "duplicate": true }
    // - fresh: [ { ... row from comment_reports ... } ]
    return json['duplicate'] == true;
  }

  /// Sets (or clears) the current user's reaction on a comment.
  ///
  /// Passing a non-null [reaction] records the reaction for the current user.
  /// Passing `null` clears the existing reaction (if any).
  ///
  /// This call requires a valid user token and will throw if the network call
  /// fails.
  Future<void> setCommentReaction({
    required String commentId,
    required UserProfile user,
    required String? reaction,
  }) async {
    final bearer = await _getMetaBearer(purpose: 'react', user: user);
    CommentsLogger.info(
        'setting reaction comment=$commentId reaction=${reaction ?? "(clear)"}');

    try {
      await _http.postJson(
        _config.apiBase.resolve('comments/react'),
        {
          'commentId': commentId,
          // When null, the API treats it as a "remove".
          'reaction': reaction,
        },
        headers: {'Authorization': 'Bearer $bearer'},
      );
    } catch (e) {
      CommentsLogger.error('failed to set comment reaction: $e');
      rethrow;
    }
  }

  /// Best-effort profile sync (name / avatar).
  ///
  /// This is designed to be safe to call at any time:
  /// - If no token exists yet, we queue the latest user and replay once a token
  ///   is obtained (meta or thread).
  /// - If a token exists, we upsert immediately.
  ///
  /// Errors are logged but never thrown (non-fatal).
  Future<void> identify(UserProfile user) async {
    final now = DateTime.now();
    if (_invalidBindingUntil != null && now.isBefore(_invalidBindingUntil!)) {
      return;
    }

    _pendingIdentifyUser = user;

    // dedup
    if (_identifyInFlight != null) return _identifyInFlight!;

    _identifyInFlight = () async {
      try {
        final token = _threadTokens.validBearer() ?? _metaTokens.validBearer();
        if (token == null) return;
        CommentsLogger.info('identify user=${_safeUserId(user.id)}');
        await _identifyWithToken(token, user);
        if (_pendingIdentifyUser?.id == user.id) _pendingIdentifyUser = null;

        // If another update arrived while we were in-flight, flush again.
        if (_pendingIdentifyUser != null) {
          _flushPendingIdentifyIfAny().ignore();
        }
      } catch (e) {
        CommentsLogger.error('failed to identify user (non-fatal): $e');
      } finally {
        _identifyInFlight = null;
      }
    }();

    return _identifyInFlight!;
  }

  /// Returns a bearer suitable for meta operations (identify/settings/report/react).
  ///
  /// This does NOT affect the thread-scoped token cache.
  Future<String> _getMetaBearer({required String purpose, UserProfile? user}) async {
    final cached = _metaTokens.validBearer();
    if (cached != null) {
      CommentsLogger.info('meta auth token cache hit');
      return cached;
    }

    final now = DateTime.now();
    if (_invalidBindingUntil != null && now.isBefore(_invalidBindingUntil!)) {
      CommentsLogger.info('auth blocked (invalid_binding cooldown active)');
      throw CommentsAuthException(
        'invalid_binding',
        message: 'This API key requires a valid app binding (signature/origin).',
      );
    }

    if (_metaAuthInFlight != null) {
      return _metaAuthInFlight!;
    }

    // Use a deterministic high-entropy meta thread key so the backend can scope
    // JWT claims / RLS consistently without requiring a real content thread.
    final metaThreadKey = _metaThreadKey(purpose, a: user?.id);

    CommentsLogger.debug(
      'Preparing headers for meta token request: ${_redactedTokenHeadersForLogs(_config.tokenHeaders())}',
    );

    final headers = <String, String>{
      'Content-Type': 'application/json',
      ..._config.tokenHeaders(),
    };

    final body = <String, dynamic>{
      'apiKey': _config.installKey,
      'threadKey': metaThreadKey,
      if (user != null)
        'externalUser': {
          'id': user.id,
          if (user.name != null) 'name': user.name,
          if (user.avatarUrl != null) 'avatarUrl': user.avatarUrl,
        },
    };

    CommentsLogger.info('requesting meta auth token (purpose=$purpose)');

    _metaAuthInFlight = () async {
      try {
        final json = await _http.postJson(
          _config.apiBase.resolve('token'),
          body,
          headers: headers,
        );

        final token = json['access_token'] as String;
        final expiresIn = (json['expires_in'] as num?)?.toInt() ?? 3600;
        final plan = json['plan'] as String?;

        _metaTokens.save(token, expiresIn, plan: plan);

        CommentsLogger.info(
          'meta auth token received (purpose=$purpose, expiresIn=${expiresIn}s, plan=${plan ?? "unknown"})',
        );

        // If we had a pending identify, replay now in the background.
        // Do not await: keep callers fast.
        _flushPendingIdentifyIfAny().ignore();

        return token;
      } catch (e) {
        CommentsLogger.error(
          'failed to obtain meta auth token. Check your install key at https://goodvibeslab.cloud '
          '(key=${_safeKeyPrefix(_config.installKey)}): $e',
        );

        final msg = e.toString();
        if (msg.contains('"error":"invalid_binding"') || msg.contains('invalid_binding')) {
          _invalidBindingUntil = DateTime.now().add(const Duration(seconds: 60));
          CommentsLogger.info('invalid_binding detected, cooling down for 60s');
          throw CommentsAuthException(
            'invalid_binding',
            message: 'This API key requires a valid app binding (signature/origin).',
          );
        }
        rethrow;
      } finally {
        _metaAuthInFlight = null;
      }
    }();

    return _metaAuthInFlight!;
  }

  Future<void> _flushPendingIdentifyIfAny() {
    final now = DateTime.now();
    if (_invalidBindingUntil != null && now.isBefore(_invalidBindingUntil!)) {
      return Future.value();
    }

    final u = _pendingIdentifyUser;
    if (u == null) return Future.value();

    final token = _threadTokens.validBearer() ?? _metaTokens.validBearer();
    if (token == null) return Future.value();

    if (_identifyInFlight != null) return _identifyInFlight!;

    _identifyInFlight = () async {
      try {
        await _identifyWithToken(token, u);
        if (_pendingIdentifyUser?.id == u.id) _pendingIdentifyUser = null;
      } finally {
        _identifyInFlight = null;
      }
    }();

    return _identifyInFlight!;
  }

  Future<void> _identifyWithToken(String token, UserProfile user) async {
    await _http.postJson(
      _config.apiBase.resolve('profile/upsert'),
      {
        if (user.name != null) 'displayName': user.name,
        if (user.avatarUrl != null) 'avatarUrl': user.avatarUrl,
      },
      headers: {'Authorization': 'Bearer $token'},
    );
  }
}
