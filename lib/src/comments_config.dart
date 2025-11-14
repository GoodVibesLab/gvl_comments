import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:io' show Platform;
import 'package:package_info_plus/package_info_plus.dart';

class CommentsConfig {
  final String installKey;   // cmt_live_xxx
  final Uri apiBase;         // auto: https://api.goodvibeslab.cloud
  final String platform;     // android | ios | web (auto)
  final String packageName;  // auto
  final String appVersion;   // auto

  CommentsConfig._({
    required this.installKey,
    required this.apiBase,
    required this.platform,
    required this.packageName,
    required this.appVersion,
  });

  /// Détection auto (plateforme, bundle/basename et version).
  static Future<CommentsConfig> detect({required String installKey}) async {
    // Base API: overridable via --dart-define mais invisible côté app
    final apiBase = Uri.parse(
      const String.fromEnvironment(
        'GVL_API_BASE',
        defaultValue: 'https://api.goodvibeslab.cloud/comments/v1/',
      ),
    );

    debugPrint('CommentsConfig.detect: apiBase=$apiBase');

    String platform;
    if (kIsWeb) {
      platform = 'web';
    } else if (Platform.isAndroid) {
      platform = 'android';
    } else if (Platform.isIOS) {
      platform = 'ios';
    } else {
      platform = 'unknown';
    }

    String pkg = 'unknown';
    String ver = '0.0.0';
    try {
      final info = await PackageInfo.fromPlatform();
      pkg = info.packageName;
      ver = info.version;
    } catch (_) {}

    return CommentsConfig._(
      installKey: installKey,
      apiBase: apiBase,
      platform: platform,
      packageName: pkg,
      appVersion: ver,
    );
  }
}