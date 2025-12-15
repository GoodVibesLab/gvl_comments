import 'package:flutter/widgets.dart';

import '../../l10n/gvl_comments_l10n.dart';

String formatRelativeTime(DateTime createdAt, BuildContext context) {
  final now = DateTime.now().toUtc();
  final ts = createdAt.toUtc();
  final diff = now.difference(ts);

  final l10n = GvlCommentsL10n.of(context);

  if (diff.inSeconds < 45) {
    return l10n?.timeJustNow ?? 'Just now';
  }
  if (diff.inMinutes < 2) {
    return l10n?.timeOneMinute ?? '1 min ago';
  }
  if (diff.inMinutes < 60) {
    return l10n?.timeXMinutes(diff.inMinutes) ?? '${diff.inMinutes} min ago';
  }
  if (diff.inHours < 2) {
    return l10n?.timeOneHour ?? '1 h ago';
  }
  if (diff.inHours < 24) {
    return l10n?.timeXHours(diff.inHours) ?? '${diff.inHours} h ago';
  }
  if (diff.inDays < 2) {
    return l10n?.timeYesterday ?? 'Yesterday';
  }
  if (diff.inDays < 7) {
    return l10n?.timeXDays(diff.inDays) ?? '${diff.inDays} d ago';
  }

  // fallback date
  return l10n?.timeFallbackDate(
        ts.year.toString().padLeft(4, '0'),
        ts.month.toString().padLeft(2, '0'),
        ts.day.toString().padLeft(2, '0'),
      ) ??
      '${ts.year}-${ts.month}-${ts.day}';
}
