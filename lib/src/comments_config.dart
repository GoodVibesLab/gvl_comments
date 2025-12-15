import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:package_info_plus/package_info_plus.dart';

/// Runtime configuration detected from the host platform and app metadata.
class CommentsConfig {
  /// Your GoodVibesLab install key (for example `cmt_live_xxx`).
  final String installKey;

  /// Base API endpoint used by the SDK.
  final Uri apiBase;

  /// Platform identifier (`android`, `ios`, `web`, or `unknown`).
  final String platform;

  /// Host app package/bundle identifier if available.
  final String packageName;

  /// Host app version string if available.
  final String appVersion;

  CommentsConfig._({
    required this.installKey,
    required this.apiBase,
    required this.platform,
    required this.packageName,
    required this.appVersion,
  });

  /// Detects platform, package, and version metadata.
  static Future<CommentsConfig> detect({required String installKey}) async {
    // Base API can be overridden via --dart-define, but remains opaque to apps.
    final apiBase = Uri.parse(
      const String.fromEnvironment(
        'GVL_API_BASE',
        defaultValue: 'https://api.goodvibeslab.cloud/comments/v1/',
      ),
    );

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