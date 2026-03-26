// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'gvl_comments_l10n.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class GvlCommentsL10nFr extends GvlCommentsL10n {
  GvlCommentsL10nFr([String locale = 'fr']) : super(locale);

  @override
  String get retryTooltip => 'Réessayer';

  @override
  String get sendTooltip => 'Envoyer';

  @override
  String get addCommentHint => 'Ajouter un commentaire…';

  @override
  String get signInToCommentHint => 'Connectez-vous pour commenter';

  @override
  String get reportSentLabel => 'Signalement envoyé';

  @override
  String get reportErrorLabel => 'Erreur lors du signalement';

  @override
  String get reportLabel => 'Signaler';

  @override
  String get alreadyReportedLabel => 'Vous avez déjà signalé ce commentaire';

  @override
  String get reportedPlaceholderLabel => '⚠ Ce commentaire a été signalé';

  @override
  String get moderatedPlaceholderLabel => '⚠ Ce commentaire a été modéré';

  @override
  String get loadPreviousCommentsLabel => 'Charger les commentaires précédents';

  @override
  String get timeJustNow => 'À l\'instant';

  @override
  String get timeOneMinute => 'Il y a 1 min';

  @override
  String timeXMinutes(Object m) {
    return 'Il y a $m min';
  }

  @override
  String get timeOneHour => 'Il y a 1h';

  @override
  String timeXHours(Object h) {
    return 'Il y a ${h}h';
  }

  @override
  String get timeYesterday => 'Hier';

  @override
  String timeXDays(Object d) {
    return 'Il y a $d jours';
  }

  @override
  String timeFallbackDate(Object d, Object m, Object y) {
    return '$d/$m/$y';
  }

  @override
  String get errorTitle => 'Erreur';

  @override
  String get retryLabel => 'Réessayer';

  @override
  String get genericErrorLabel => 'Une erreur est survenue.';

  @override
  String get networkErrorLabel =>
      'Erreur réseau. Vérifiez votre connexion et réessayez.';

  @override
  String get unauthorizedErrorLabel =>
      'Erreur d\'authentification. Veuillez vous reconnecter.';

  @override
  String get timeoutErrorLabel => 'La requête a expiré. Veuillez réessayer.';

  @override
  String get detailsLabel => 'Détails';

  @override
  String get copyLabel => 'Copier';

  @override
  String get copiedLabel => 'Copié';

  @override
  String get replyLabel => 'Répondre';

  @override
  String replyingToLabel(String name) {
    return 'Réponse à $name';
  }

  @override
  String replyHint(String name) {
    return 'Répondre à $name…';
  }

  @override
  String get cancelReplyTooltip => 'Annuler la réponse';

  @override
  String seeMoreReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'réponses',
      one: 'réponse',
    );
    return 'Voir $count $_temp0 de plus';
  }

  @override
  String get reactionLike => 'J\'aime';

  @override
  String get reactionLove => 'J\'adore';

  @override
  String get reactionLaugh => 'Haha';

  @override
  String get reactionWow => 'Waouh';

  @override
  String get reactionSad => 'Triste';

  @override
  String get reactionAngry => 'Grr';
}
