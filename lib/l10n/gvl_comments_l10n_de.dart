// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'gvl_comments_l10n.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class GvlCommentsL10nDe extends GvlCommentsL10n {
  GvlCommentsL10nDe([String locale = 'de']) : super(locale);

  @override
  String get retryTooltip => 'Erneut versuchen';

  @override
  String get sendTooltip => 'Senden';

  @override
  String get addCommentHint => 'Kommentar hinzufügen…';

  @override
  String get signInToCommentHint => 'Anmelden zum Kommentieren';

  @override
  String get reportSentLabel => 'Meldung gesendet';

  @override
  String get reportErrorLabel => 'Fehler beim Senden der Meldung';

  @override
  String get reportLabel => 'Melden';

  @override
  String get alreadyReportedLabel =>
      'Du hast diesen Kommentar bereits gemeldet';

  @override
  String get reportedPlaceholderLabel => '⚠ Dieser Kommentar wurde gemeldet';

  @override
  String get moderatedPlaceholderLabel => '⚠ Dieser Kommentar wurde moderiert';

  @override
  String get loadPreviousCommentsLabel => 'Vorherige Kommentare laden';

  @override
  String get timeJustNow => 'Gerade eben';

  @override
  String get timeOneMinute => 'Vor 1 Min.';

  @override
  String timeXMinutes(Object m) {
    return 'Vor $m Min.';
  }

  @override
  String get timeOneHour => 'Vor 1 Std.';

  @override
  String timeXHours(Object h) {
    return 'Vor $h Std.';
  }

  @override
  String get timeYesterday => 'Gestern';

  @override
  String timeXDays(Object d) {
    return 'Vor $d Tagen';
  }

  @override
  String timeFallbackDate(Object d, Object m, Object y) {
    return '$d.$m.$y';
  }

  @override
  String get errorTitle => 'Fehler';

  @override
  String get retryLabel => 'Erneut versuchen';

  @override
  String get genericErrorLabel => 'Etwas ist schiefgelaufen.';

  @override
  String get networkErrorLabel =>
      'Netzwerkfehler. Überprüfe deine Verbindung und versuche es erneut.';

  @override
  String get unauthorizedErrorLabel =>
      'Authentifizierungsfehler. Bitte erneut anmelden.';

  @override
  String get timeoutErrorLabel => 'Zeitüberschreitung. Bitte erneut versuchen.';

  @override
  String get detailsLabel => 'Details';

  @override
  String get copyLabel => 'Kopieren';

  @override
  String get copiedLabel => 'Kopiert';

  @override
  String get replyLabel => 'Antworten';

  @override
  String replyingToLabel(String name) {
    return 'Antwort an $name';
  }

  @override
  String replyHint(String name) {
    return 'Antwort an $name…';
  }

  @override
  String get cancelReplyTooltip => 'Antwort abbrechen';

  @override
  String seeMoreReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Antworten',
      one: 'Antwort',
    );
    return '$count weitere $_temp0 anzeigen';
  }

  @override
  String get reactionLike => 'Gefällt mir';

  @override
  String get reactionLove => 'Liebe';

  @override
  String get reactionLaugh => 'Haha';

  @override
  String get reactionWow => 'Wow';

  @override
  String get reactionSad => 'Traurig';

  @override
  String get reactionAngry => 'Wütend';
}
