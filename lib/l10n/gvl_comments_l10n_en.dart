// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'gvl_comments_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class GvlCommentsL10nEn extends GvlCommentsL10n {
  GvlCommentsL10nEn([String locale = 'en']) : super(locale);

  @override
  String get retryTooltip => 'Retry';

  @override
  String get sendTooltip => 'Send';

  @override
  String get addCommentHint => 'Add a comment…';

  @override
  String get reportSentLabel => 'Report sent';

  @override
  String get reportErrorLabel => 'Error sending report';

  @override
  String get reportLabel => 'Report';

  @override
  String get alreadyReportedLabel => 'You already reported this comment';

  @override
  String get reportedPlaceholderLabel => '⚠ This comment has been reported';

  @override
  String get moderatedPlaceholderLabel => '⚠ This comment has been moderated';

  @override
  String get loadPreviousCommentsLabel => 'Load previous comments';

  @override
  String get timeJustNow => 'Just now';

  @override
  String get timeOneMinute => '1 min ago';

  @override
  String timeXMinutes(Object m) {
    return '$m min ago';
  }

  @override
  String get timeOneHour => '1h ago';

  @override
  String timeXHours(Object h) {
    return '${h}h ago';
  }

  @override
  String get timeYesterday => 'Yesterday';

  @override
  String timeXDays(Object d) {
    return '$d days ago';
  }

  @override
  String timeFallbackDate(Object d, Object m, Object y) {
    return 'On $y-$m-$d';
  }
}
