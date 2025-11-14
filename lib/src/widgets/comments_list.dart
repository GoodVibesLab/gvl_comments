import 'package:flutter/material.dart';
import '../../l10n/gvl_comments_l10n.dart';
import '../gvl_comments.dart'; // CommentsKit.I()
import '../models.dart';

class GvlCommentsList extends StatefulWidget {
  final String threadKey;
  final UserProfile user;

  // Slots / Builders (tous optionnels)
  final CommentItemBuilder? commentItemBuilder;
  final AvatarBuilder? avatarBuilder;
  final SendButtonBuilder? sendButtonBuilder;
  final ComposerBuilder? composerBuilder;

  final GvlCommentAlignment alignment;

  // Overrides légers
  final int limit;
  final EdgeInsetsGeometry? padding;
  final ScrollController? scrollController;

  const GvlCommentsList({
    super.key,
    required this.threadKey,
    required this.user,
    this.commentItemBuilder,
    this.avatarBuilder,
    this.sendButtonBuilder,
    this.composerBuilder,
    this.limit = 50,
    this.padding,
    this.scrollController,
    this.alignment = GvlCommentAlignment.left,
  });

  @override
  State<GvlCommentsList> createState() => _GvlCommentsListState();
}

class _GvlCommentsListState extends State<GvlCommentsList> with AutomaticKeepAliveClientMixin {
  List<CommentModel>? _comments;
  String? _error;
  final _ctrl = TextEditingController();
  bool _loading = true;
  bool _sending = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _primeAndLoad();
  }

  @override
  void didUpdateWidget(covariant GvlCommentsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      CommentsKit.I().invalidateToken();
      _primeAndLoad();
    } else if (oldWidget.threadKey != widget.threadKey) {
      _load();
    }
  }

  Future<void> _primeAndLoad() async {
    final kit = CommentsKit.I();

    // 1) on upsert le profil
    try {
      await kit.identify(widget.user);
    } catch (e) {
      debugPrint('gvl_comments: error during identify(): $e');
    }

    // 2) puis on charge les commentaires
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final kit = CommentsKit.I();
      final list = await kit.listByThreadKey(
        widget.threadKey,
        limit: widget.limit,
        user: widget.user,
      );
      setState(() {
        _comments = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final kit = CommentsKit.I();
      final created = await kit.post(
        threadKey: widget.threadKey,
        body: text,
        user: widget.user,
      );
      setState(() {
        _comments = [created, ...(_comments ?? [])];
        _ctrl.clear();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _sending = false;
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final l10n = GvlCommentsL10n.of(context);

    final t = GvlCommentsTheme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // plus de titre "Erreur" (moins de strings visibles)
            Text(_error!, style: t.errorStyle ?? TextStyle(color: t.errorColor ?? Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
            IconButton.outlined(
              tooltip: l10n?.retryTooltip,    // ex: "Réessayer"
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      );
    }

    final comments = _comments ?? [];
    final padding = widget.padding ??
        EdgeInsets.symmetric(vertical: (t.spacing ?? 8));

    return Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: t.gutterColor ?? Colors.transparent,
            child: ListView.separated(
              controller: widget.scrollController,
              reverse: true,
              padding: padding,
              itemCount: comments.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Theme.of(context).dividerColor,
              ),
              itemBuilder: (_, i) {
                final c = comments[i];
                final isMine = c.externalUserId == widget.user.id;

                if (widget.commentItemBuilder != null) {
                  return widget.commentItemBuilder!(
                    context,
                    c,
                    GvlCommentMeta(isMine: isMine),
                  );
                }
                return _DefaultCommentItem(
                  comment: c,
                  isMine: isMine,
                  alignment: widget.alignment,
                  avatarBuilder: widget.avatarBuilder,
                );
              },
            ),
          ),
        ),
        const Divider(height: 1),
        _buildComposer(context, t, l10n),
      ],
    );
  }

  Widget _buildComposer(BuildContext context, GvlCommentsThemeData t, GvlCommentsL10n? l10n) {
    final maxLines = t.composerMaxLines ?? 6;
    final hint = l10n?.addCommentHint; // null-safe: si pas de l10n, pas de hint (OK)

    if (widget.composerBuilder != null) {
      return widget.composerBuilder!(
        context,
        controller: _ctrl,
        onSubmit: _sending ? () {} : _send,
        isSending: _sending,
        maxLines: maxLines,
        hintText: hint ?? '',
      );
    }

    final dense = Theme.of(context).visualDensity;
    return Padding(
      padding: EdgeInsets.all(t.spacing ?? 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sending ? null : _send(),
              maxLines: null,
              minLines: 1,
              decoration: InputDecoration(
                hintText: hint, // <- peut être null, ça marche
                isDense: dense != null ? dense.vertical < 0 : true,
                border: t.composerShape == null ? const OutlineInputBorder() : InputBorder.none,
              ),
            ),
          ),
          SizedBox(width: t.spacing ?? 8),
          widget.sendButtonBuilder != null
              ? widget.sendButtonBuilder!(context, _sending ? () {} : _send, _sending)
              : IconButton.filled(
            onPressed: _sending ? null : _send,
            tooltip: l10n?.sendTooltip, // ex: "Envoyer"
            icon: _sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}


/// Élément par défaut (hérite totalement du thème hôte)
class _DefaultCommentItem extends StatelessWidget {
  final CommentModel comment;
  final bool isMine;
  final GvlCommentAlignment alignment;
  final AvatarBuilder? avatarBuilder;

  const _DefaultCommentItem({
    Key? key,
    required this.comment,
    required this.isMine,
    required this.alignment,
    this.avatarBuilder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = GvlCommentsTheme.of(context);
    final cs = Theme.of(context).colorScheme;

    final bg = isMine ? (t.bubbleColor ?? cs.surfaceContainerHighest)
        : (t.bubbleAltColor ?? cs.surfaceContainer);
    final text = Theme.of(context).textTheme;

    final bool alignRight = switch (alignment) {
      GvlCommentAlignment.right => true,
      GvlCommentAlignment.left => false,
      GvlCommentAlignment.autoByUser => isMine,
    };

    final avatarSize = t.avatarSize ?? 32;
    final avatar = avatarBuilder?.call(context, comment, avatarSize);

    final bubble = Material(
      color: bg,
      elevation: t.elevation ?? 0,
      shape: RoundedRectangleBorder(
        borderRadius: t.bubbleRadius ?? const BorderRadius.all(Radius.circular(12)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: EdgeInsets.all((t.spacing ?? 8) + 4),
          child: Column(
            crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                comment.authorName ?? comment.externalUserId,
                style: t.authorStyle ?? text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(comment.body, style: t.bodyStyle ?? text.bodyMedium),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: (t.spacing ?? 8),
        horizontal: (t.spacing ?? 8),
      ),
      child: Align(
        alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!alignRight && avatar != null) ...[
              SizedBox(
                width: avatarSize, height: avatarSize,
                child: ClipRRect(borderRadius: BorderRadius.circular(avatarSize/2), child: avatar),
              ),
              SizedBox(width: t.spacing ?? 8),
            ],
            bubble,
            if (alignRight && avatar != null) ...[
              SizedBox(width: (t.spacing ?? 8)),
              SizedBox(
                width: avatarSize, height: avatarSize,
                child: ClipRRect(borderRadius: BorderRadius.circular(avatarSize/2), child: avatar),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Métadonnées passées aux builders pour customiser l’affichage.
class GvlCommentMeta {
  final bool isMine;
  final bool isSending;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const GvlCommentMeta({
    required this.isMine,
    this.isSending = false,
    this.onLongPress,
    this.onTap,
  });
}

typedef CommentItemBuilder = Widget Function(
    BuildContext context,
    CommentModel comment,
    GvlCommentMeta meta,
    );

typedef AvatarBuilder = Widget Function(
    BuildContext context,
    CommentModel comment,
    double size,
    );

typedef SendButtonBuilder = Widget Function(
    BuildContext context,
    VoidCallback onPressed,
    bool isSending,
    );

/// Permet de remplacer tout le composer (input + bouton)
typedef ComposerBuilder = Widget Function(
    BuildContext context, {
    required TextEditingController controller,
    required VoidCallback onSubmit,
    required bool isSending,
    required int maxLines,
    required String hintText,
    });

/// Rôles sémantiques + tokens d’UI.
/// Ne mets pas de valeurs brutes : tout est optionnel et tombe en fallback
/// via `GvlCommentsThemeData.defaults(context)`.
@immutable
class GvlCommentsThemeData extends ThemeExtension<GvlCommentsThemeData> {
  // Couleurs
  final Color? bubbleColor;        // fond des messages
  final Color? bubbleAltColor;     // fond des messages "autres"
  final Color? gutterColor;        // fond de la zone composer / séparateurs
  final Color? badgeColor;         // ex: badge staff / auteur
  final Color? errorColor;         // erreurs

  // Typo (laisser fontFamily null => la police du host s’applique)
  final TextStyle? authorStyle;
  final TextStyle? bodyStyle;
  final TextStyle? timestampStyle;
  final TextStyle? errorStyle;
  final TextStyle? hintStyle;
  final TextStyle? buttonStyle;

  // Spacing / tailles
  final double? spacing;           // 8, 12…
  final double? avatarSize;        // 28–40
  final BorderRadius? bubbleRadius;
  final OutlinedBorder? composerShape;
  final double? elevation;

  // Comportement
  final int? composerMaxLines;

  const GvlCommentsThemeData({
    this.bubbleColor,
    this.bubbleAltColor,
    this.gutterColor,
    this.badgeColor,
    this.errorColor,
    this.authorStyle,
    this.bodyStyle,
    this.timestampStyle,
    this.errorStyle,
    this.hintStyle,
    this.buttonStyle,
    this.spacing,
    this.avatarSize,
    this.bubbleRadius,
    this.composerShape,
    this.elevation,
    this.composerMaxLines,
  });

  /// Fallbacks mappés sur le Theme hôte (Material 3 friendly)
  factory GvlCommentsThemeData.defaults(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return GvlCommentsThemeData(
      bubbleColor: cs.surfaceContainerHighest,
      bubbleAltColor: cs.surfaceContainer,
      gutterColor: cs.surface,
      badgeColor: cs.secondaryContainer,
      errorColor: cs.error,
      authorStyle: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyStyle: tt.bodyMedium,
      timestampStyle: tt.bodySmall?.copyWith(color: cs.onSurface.withOpacity(0.6)),
      errorStyle: tt.bodyMedium?.copyWith(color: cs.error),
      hintStyle: theme.inputDecorationTheme.hintStyle ?? tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      buttonStyle: tt.labelLarge,
      spacing: 8,
      avatarSize: 32,
      bubbleRadius: const BorderRadius.all(Radius.circular(12)),
      composerShape: theme.inputDecorationTheme.border is OutlinedBorder
          ? theme.inputDecorationTheme.border as OutlinedBorder?
          : const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      elevation: 0,
      composerMaxLines: 6,
    );
  }

  /// Combine deux thèmes (le `other` prime s’il définit une valeur)
  GvlCommentsThemeData merge(GvlCommentsThemeData? other) {
    if (other == null) return this;
    return GvlCommentsThemeData(
      bubbleColor: other.bubbleColor ?? bubbleColor,
      bubbleAltColor: other.bubbleAltColor ?? bubbleAltColor,
      gutterColor: other.gutterColor ?? gutterColor,
      badgeColor: other.badgeColor ?? badgeColor,
      errorColor: other.errorColor ?? errorColor,
      authorStyle: other.authorStyle ?? authorStyle,
      bodyStyle: other.bodyStyle ?? bodyStyle,
      timestampStyle: other.timestampStyle ?? timestampStyle,
      errorStyle: other.errorStyle ?? errorStyle,
      hintStyle: other.hintStyle ?? hintStyle,
      buttonStyle: other.buttonStyle ?? buttonStyle,
      spacing: other.spacing ?? spacing,
      avatarSize: other.avatarSize ?? avatarSize,
      bubbleRadius: other.bubbleRadius ?? bubbleRadius,
      composerShape: other.composerShape ?? composerShape,
      elevation: other.elevation ?? elevation,
      composerMaxLines: other.composerMaxLines ?? composerMaxLines,
    );
  }

  /// Implémentations ThemeExtension
  @override
  GvlCommentsThemeData copyWith({
    Color? bubbleColor,
    Color? bubbleAltColor,
    Color? gutterColor,
    Color? badgeColor,
    Color? errorColor,
    TextStyle? authorStyle,
    TextStyle? bodyStyle,
    TextStyle? timestampStyle,
    TextStyle? errorStyle,
    TextStyle? hintStyle,
    TextStyle? buttonStyle,
    double? spacing,
    double? avatarSize,
    BorderRadius? bubbleRadius,
    OutlinedBorder? composerShape,
    double? elevation,
    int? composerMaxLines,
  }) {
    return GvlCommentsThemeData(
      bubbleColor: bubbleColor ?? this.bubbleColor,
      bubbleAltColor: bubbleAltColor ?? this.bubbleAltColor,
      gutterColor: gutterColor ?? this.gutterColor,
      badgeColor: badgeColor ?? this.badgeColor,
      errorColor: errorColor ?? this.errorColor,
      authorStyle: authorStyle ?? this.authorStyle,
      bodyStyle: bodyStyle ?? this.bodyStyle,
      timestampStyle: timestampStyle ?? this.timestampStyle,
      errorStyle: errorStyle ?? this.errorStyle,
      hintStyle: hintStyle ?? this.hintStyle,
      buttonStyle: buttonStyle ?? this.buttonStyle,
      spacing: spacing ?? this.spacing,
      avatarSize: avatarSize ?? this.avatarSize,
      bubbleRadius: bubbleRadius ?? this.bubbleRadius,
      composerShape: composerShape ?? this.composerShape,
      elevation: elevation ?? this.elevation,
      composerMaxLines: composerMaxLines ?? this.composerMaxLines,
    );
  }

  @override
  ThemeExtension<GvlCommentsThemeData> lerp(
      ThemeExtension<GvlCommentsThemeData>? other, double t) {
    if (other is! GvlCommentsThemeData) return this;
    return GvlCommentsThemeData(
      bubbleColor: Color.lerp(bubbleColor, other.bubbleColor, t),
      bubbleAltColor: Color.lerp(bubbleAltColor, other.bubbleAltColor, t),
      gutterColor: Color.lerp(gutterColor, other.gutterColor, t),
      badgeColor: Color.lerp(badgeColor, other.badgeColor, t),
      errorColor: Color.lerp(errorColor, other.errorColor, t),
      authorStyle: TextStyle.lerp(authorStyle, other.authorStyle, t),
      bodyStyle: TextStyle.lerp(bodyStyle, other.bodyStyle, t),
      timestampStyle: TextStyle.lerp(timestampStyle, other.timestampStyle, t),
      errorStyle: TextStyle.lerp(errorStyle, other.errorStyle, t),
      hintStyle: TextStyle.lerp(hintStyle, other.hintStyle, t),
      buttonStyle: TextStyle.lerp(buttonStyle, other.buttonStyle, t),
      spacing: lerpDoubleNullable(spacing, other.spacing, t),
      avatarSize: lerpDoubleNullable(avatarSize, other.avatarSize, t),
      bubbleRadius: BorderRadius.lerp(bubbleRadius, other.bubbleRadius, t),
      composerShape: t < 0.5 ? composerShape : other.composerShape,
      elevation: lerpDoubleNullable(elevation, other.elevation, t),
      composerMaxLines: t < 0.5 ? composerMaxLines : other.composerMaxLines,
    );
  }

  static double? lerpDoubleNullable(double? a, double? b, double t) {
    if (a == null && b == null) return null;
    return Tween<double>(begin: a ?? b ?? 0, end: b ?? a ?? 0).transform(t);
  }
}

/// Wrapper pour overrides locaux.
/// Utilisation :
/// GvlCommentsTheme(
///   data: GvlCommentsThemeData(bubbleRadius: BorderRadius.circular(16)),
///   child: GvlCommentsList(...),
/// )
class GvlCommentsTheme extends InheritedWidget {
  final GvlCommentsThemeData data;

  const GvlCommentsTheme({
    Key? key,
    required this.data,
    required Widget child,
  }) : super(key: key, child: child);

  static GvlCommentsThemeData of(BuildContext context) {
    final local = context.dependOnInheritedWidgetOfExactType<GvlCommentsTheme>();
    final ext = Theme.of(context).extension<GvlCommentsThemeData>();
    final base = GvlCommentsThemeData.defaults(context);
    return base.merge(ext).merge(local?.data);
  }

  @override
  bool updateShouldNotify(GvlCommentsTheme oldWidget) => data != oldWidget.data;
}

@immutable
class GvlCommentsStrings {
  final String errorTitle;
  final String retry;
  final String send;
  final String hintAddComment;

  const GvlCommentsStrings({
    required this.errorTitle,
    required this.retry,
    required this.send,
    required this.hintAddComment,
  });

  factory GvlCommentsStrings.fr() => const GvlCommentsStrings(
    errorTitle: 'Erreur',
    retry: 'Réessayer',
    send: 'Envoyer',
    hintAddComment: 'Ajouter un commentaire…',
  );

  factory GvlCommentsStrings.en() => const GvlCommentsStrings(
    errorTitle: 'Error',
    retry: 'Retry',
    send: 'Send',
    hintAddComment: 'Add a comment…',
  );

  GvlCommentsStrings copyWith({
    String? errorTitle,
    String? retry,
    String? send,
    String? hintAddComment,
  }) {
    return GvlCommentsStrings(
      errorTitle: errorTitle ?? this.errorTitle,
      retry: retry ?? this.retry,
      send: send ?? this.send,
      hintAddComment: hintAddComment ?? this.hintAddComment,
    );
  }
}

/// Alignement des bulles de message
enum GvlCommentAlignment { left, right, autoByUser }