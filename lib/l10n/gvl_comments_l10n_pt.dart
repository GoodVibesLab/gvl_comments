// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'gvl_comments_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class GvlCommentsL10nPt extends GvlCommentsL10n {
  GvlCommentsL10nPt([String locale = 'pt']) : super(locale);

  @override
  String get retryTooltip => 'Tentar novamente';

  @override
  String get sendTooltip => 'Enviar';

  @override
  String get addCommentHint => 'Adicionar um comentário…';

  @override
  String get signInToCommentHint => 'Entre para comentar';

  @override
  String get reportSentLabel => 'Denúncia enviada';

  @override
  String get reportErrorLabel => 'Erro ao enviar denúncia';

  @override
  String get reportLabel => 'Denunciar';

  @override
  String get alreadyReportedLabel => 'Você já denunciou este comentário';

  @override
  String get reportedPlaceholderLabel => '⚠ Este comentário foi denunciado';

  @override
  String get moderatedPlaceholderLabel => '⚠ Este comentário foi moderado';

  @override
  String get loadPreviousCommentsLabel => 'Carregar comentários anteriores';

  @override
  String get timeJustNow => 'Agora mesmo';

  @override
  String get timeOneMinute => 'Há 1 min';

  @override
  String timeXMinutes(Object m) {
    return 'Há $m min';
  }

  @override
  String get timeOneHour => 'Há 1h';

  @override
  String timeXHours(Object h) {
    return 'Há ${h}h';
  }

  @override
  String get timeYesterday => 'Ontem';

  @override
  String timeXDays(Object d) {
    return 'Há $d dias';
  }

  @override
  String timeFallbackDate(Object d, Object m, Object y) {
    return '$d/$m/$y';
  }

  @override
  String get errorTitle => 'Erro';

  @override
  String get retryLabel => 'Tentar novamente';

  @override
  String get genericErrorLabel => 'Algo deu errado.';

  @override
  String get networkErrorLabel =>
      'Erro de rede. Verifique sua conexão e tente novamente.';

  @override
  String get unauthorizedErrorLabel =>
      'Erro de autenticação. Faça login novamente.';

  @override
  String get timeoutErrorLabel => 'A solicitação expirou. Tente novamente.';

  @override
  String get detailsLabel => 'Detalhes';

  @override
  String get copyLabel => 'Copiar';

  @override
  String get copiedLabel => 'Copiado';

  @override
  String get replyLabel => 'Responder';

  @override
  String replyingToLabel(String name) {
    return 'Respondendo a $name';
  }

  @override
  String replyHint(String name) {
    return 'Responder a $name…';
  }

  @override
  String get cancelReplyTooltip => 'Cancelar resposta';

  @override
  String seeMoreReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'respostas',
      one: 'resposta',
    );
    return 'Ver mais $count $_temp0';
  }

  @override
  String get reactionLike => 'Curtir';

  @override
  String get reactionLove => 'Amei';

  @override
  String get reactionLaugh => 'Haha';

  @override
  String get reactionWow => 'Uau';

  @override
  String get reactionSad => 'Triste';

  @override
  String get reactionAngry => 'Grr';
}
