// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'gvl_comments_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class GvlCommentsL10nEs extends GvlCommentsL10n {
  GvlCommentsL10nEs([String locale = 'es']) : super(locale);

  @override
  String get retryTooltip => 'Reintentar';

  @override
  String get sendTooltip => 'Enviar';

  @override
  String get addCommentHint => 'Añadir un comentario…';

  @override
  String get signInToCommentHint => 'Inicia sesión para comentar';

  @override
  String get reportSentLabel => 'Reporte enviado';

  @override
  String get reportErrorLabel => 'Error al enviar el reporte';

  @override
  String get reportLabel => 'Reportar';

  @override
  String get alreadyReportedLabel => 'Ya reportaste este comentario';

  @override
  String get reportedPlaceholderLabel => '⚠ Este comentario ha sido reportado';

  @override
  String get moderatedPlaceholderLabel => '⚠ Este comentario ha sido moderado';

  @override
  String get loadPreviousCommentsLabel => 'Cargar comentarios anteriores';

  @override
  String get timeJustNow => 'Ahora mismo';

  @override
  String get timeOneMinute => 'Hace 1 min';

  @override
  String timeXMinutes(Object m) {
    return 'Hace $m min';
  }

  @override
  String get timeOneHour => 'Hace 1h';

  @override
  String timeXHours(Object h) {
    return 'Hace ${h}h';
  }

  @override
  String get timeYesterday => 'Ayer';

  @override
  String timeXDays(Object d) {
    return 'Hace $d días';
  }

  @override
  String timeFallbackDate(Object d, Object m, Object y) {
    return '$d/$m/$y';
  }

  @override
  String get errorTitle => 'Error';

  @override
  String get retryLabel => 'Reintentar';

  @override
  String get genericErrorLabel => 'Algo salió mal.';

  @override
  String get networkErrorLabel =>
      'Error de red. Verifica tu conexión e inténtalo de nuevo.';

  @override
  String get unauthorizedErrorLabel =>
      'Error de autenticación. Inicia sesión de nuevo.';

  @override
  String get timeoutErrorLabel => 'La solicitud expiró. Inténtalo de nuevo.';

  @override
  String get detailsLabel => 'Detalles';

  @override
  String get copyLabel => 'Copiar';

  @override
  String get copiedLabel => 'Copiado';

  @override
  String get replyLabel => 'Responder';

  @override
  String replyingToLabel(String name) {
    return 'Respondiendo a $name';
  }

  @override
  String replyHint(String name) {
    return 'Responder a $name…';
  }

  @override
  String get cancelReplyTooltip => 'Cancelar respuesta';

  @override
  String seeMoreReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'respuestas',
      one: 'respuesta',
    );
    return 'Ver $count $_temp0 más';
  }

  @override
  String get reactionLike => 'Me gusta';

  @override
  String get reactionLove => 'Me encanta';

  @override
  String get reactionLaugh => 'Jaja';

  @override
  String get reactionWow => 'Guau';

  @override
  String get reactionSad => 'Triste';

  @override
  String get reactionAngry => 'Grr';
}
