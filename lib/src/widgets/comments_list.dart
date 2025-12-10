import 'package:flutter/material.dart';
import '../../l10n/gvl_comments_l10n.dart';
import '../gvl_comments.dart';
import '../models.dart';

/// Ready-to-use comment thread widget with pagination and a composer.
///
/// The widget renders a vertically scrolling list of comments for [threadKey]
/// and exposes builder hooks to customize avatars, bubbles, and the composer.
/// It fetches data through [CommentsKit] and keeps pagination state internally.
class GvlCommentsList extends StatefulWidget {
  /// Unique identifier for the thread to display.
  final String threadKey;

  /// Profile of the active user used for authentication and author metadata.
  final UserProfile user;

  /// Optional builder to fully override how each comment is rendered.
  final CommentItemBuilder? commentItemBuilder;

  /// Builder for the avatar widget displayed next to a comment.
  final AvatarBuilder? avatarBuilder;

  /// Builder for the send button inside the composer.
  final SendButtonBuilder? sendButtonBuilder;

  /// Builder to replace the default composer entirely.
  final ComposerBuilder? composerBuilder;

  /// Builder for separators between list items.
  final SeparatorBuilder? separatorBuilder;

  /// Controls bubble alignment in the list.
  final GvlCommentAlignment alignment;

  /// Maximum number of comments fetched per page.
  final int limit;

  /// Padding applied around the scrollable list.
  final EdgeInsetsGeometry? padding;

  /// Optional scroll controller that allows programmatic scrolling.
  final ScrollController? scrollController;

  /// Optional local theme override for this widget.
  final GvlCommentsThemeData? theme;

  /// Creates a comments list bound to a thread and user profile.
  ///
  /// Provide builder callbacks to customize rendering; otherwise sensible
  /// defaults are used. Set [alignment] to [GvlCommentAlignment.autoByUser] to
  /// mirror chat-like alignment.
  const GvlCommentsList({
    super.key,
    required this.threadKey,
    required this.user,
    this.commentItemBuilder,
    this.avatarBuilder,
    this.sendButtonBuilder,
    this.composerBuilder,
    this.separatorBuilder,
    this.limit = 50,
    this.padding,
    this.scrollController,
    this.alignment = GvlCommentAlignment.left,
    this.theme,
  });

  @override
  State<GvlCommentsList> createState() => _GvlCommentsListState();
}

class _GvlCommentsListState extends State<GvlCommentsList>
    with AutomaticKeepAliveClientMixin {
  List<CommentModel>? _comments;
  String? _error;
  final _ctrl = TextEditingController();
  bool _loading = true;
  bool _sending = false;

  // Pagination state
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _beforeCursor;

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
      _resetPagination();
      _primeAndLoad();
    } else if (oldWidget.threadKey != widget.threadKey) {
      _resetPagination();
      _load();
    }
  }

  void _resetPagination() {
    _comments = null;
    _hasMore = true;
    _beforeCursor = null;
  }

  Future<void> _primeAndLoad() async {
    final kit = CommentsKit.I();

    // Synchronize the profile based on the current JWT.
    try {
      await kit.identify(widget.user);
    } catch (e) {
      debugPrint('gvl_comments: error during identify(): $e');
    }

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
        user: widget.user,
        limit: widget.limit,
        before: null,
      );

      debugPrint(
          'gvl_comments: loaded ${list.length} comments for thread ${widget.threadKey}');
      for (final c in list) {
        debugPrint(
            ' - [${c.id}] ${c.authorName ?? c.externalUserId}: ${c.body}, avatar=${c.avatarUrl}');
      }

      setState(() {
        _comments = list;
        _hasMore = list.length >= widget.limit;
        if (_comments != null && _comments!.isNotEmpty) {
          _beforeCursor = _comments!.last.createdAt.toIso8601String();
        } else {
          _beforeCursor = null;
        }
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _beforeCursor == null) return;

    setState(() {
      _loadingMore = true;
      _error = null;
    });

    try {
      final kit = CommentsKit.I();
      final list = await kit.listByThreadKey(
        widget.threadKey,
        user: widget.user,
        limit: widget.limit,
        before: _beforeCursor,
      );

      debugPrint(
          'gvl_comments: loaded MORE ${list.length} comments for thread ${widget.threadKey}');

      setState(() {
        final current = _comments ?? <CommentModel>[];
        _comments = [...current, ...list];

        _hasMore = list.length >= widget.limit;
        if (_comments != null && _comments!.isNotEmpty) {
          _beforeCursor = _comments!.last.createdAt.toIso8601String();
        } else {
          _beforeCursor = null;
        }
        _loadingMore = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingMore = false;
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

  Future<void> _onReportComment(CommentModel comment) async {
    try {
      final kit = CommentsKit.I();
      final isDuplicate = await kit.report(
        commentId: comment.id,
        user: widget.user,
      );

      if (mounted) {
        final l10n = GvlCommentsL10n.of(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isDuplicate
                  ? (l10n?.alreadyReportedLabel ?? 'You already reported this comment')
                  : (l10n?.reportSentLabel ?? 'Comment reported'),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('gvl_comments: error while reporting comment ${comment.id}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              GvlCommentsL10n.of(context)?.reportErrorLabel ??
                  'Unable to report comment',
            ),
          ),
        );
      }
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

    final child = _buildContent(context);

    if (widget.theme != null) {
      return GvlCommentsTheme(
        data: widget.theme!,
        child: child,
      );
    }

    return child;
  }

  Widget _buildContent(BuildContext context) {

    final l10n = GvlCommentsL10n.of(context);
    final t = GvlCommentsTheme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && (_comments == null || _comments!.isEmpty)) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _error!,
              style: t.errorStyle ??
                  TextStyle(
                    color: t.errorColor ?? Theme.of(context).colorScheme.error,
                  ),
            ),
            const SizedBox(height: 12),
            IconButton.outlined(
              tooltip: l10n?.retryTooltip,
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      );
    }

    // All comments returned by the API are safe to render.
    // Server-side RLS / views already hide hard-deleted comments.
    final comments = _comments ?? [];

    final padding = widget.padding ??
        EdgeInsets.symmetric(vertical: (t.spacing ?? 8));

    final hasMoreRow = _hasMore && comments.isNotEmpty;
    final itemCount = comments.length + (hasMoreRow ? 1 : 0);

    return Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: t.gutterColor ?? Colors.transparent,
            child: ListView.separated(
              controller: widget.scrollController,
              reverse: true,
              padding: padding,
              itemCount: itemCount,
              separatorBuilder: (ctx, index) {
                // Do not put separator between last comment and "load more" row.
                if (hasMoreRow && index == comments.length - 1) {
                  return const SizedBox.shrink();
                }
                return _buildSeparator(ctx);
              },
              itemBuilder: (ctx, i) {
                if (hasMoreRow && i == comments.length) {
                  return _buildLoadMoreRow(ctx);
                }

                final c = comments[i];
                final isMine = c.externalUserId == widget.user.id;

                Widget item;
                if (widget.commentItemBuilder != null) {
                  item = widget.commentItemBuilder!(
                    ctx,
                    c,
                    GvlCommentMeta(isMine: isMine),
                  );
                } else {
                  item = _DefaultCommentItem(
                    comment: c,
                    isMine: isMine,
                    alignment: widget.alignment,
                    avatarBuilder: widget.avatarBuilder,
                  );
                }

                return Stack(
                  children: [
                    item,
                    Positioned(
                      top: 0,
                      right: 0,
                      child: PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          size: 18,
                        ),
                        onSelected: (value) {
                          if (value == 'report') {
                            _onReportComment(c);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem<String>(
                            value: 'report',
                            child: Text(
                              GvlCommentsL10n.of(context)?.reportLabel ??
                                  'Report',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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

  Widget _buildComposer(
      BuildContext context,
      GvlCommentsThemeData t,
      GvlCommentsL10n? l10n,
      ) {
    final maxLines = t.composerMaxLines ?? 6;
    final hint = l10n?.addCommentHint;

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
                hintText: hint,
                isDense: dense.vertical < 0,
                border: t.composerShape == null
                    ? const OutlineInputBorder()
                    : InputBorder.none,
              ),
            ),
          ),
          SizedBox(width: t.spacing ?? 8),
          widget.sendButtonBuilder != null
              ? widget.sendButtonBuilder!(
            context,
            _sending ? () {} : _send,
            _sending,
          )
              : IconButton.filled(
            onPressed: _sending ? null : _send,
            tooltip: l10n?.sendTooltip,
            icon: _sending
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  Widget _buildSeparator(BuildContext context) {
    if (widget.separatorBuilder == null) {
      return SizedBox(
        height: (GvlCommentsTheme.of(context).spacing ?? 8) / 2,
      );
    }
    return widget.separatorBuilder!(context);
  }

  Widget _buildLoadMoreRow(BuildContext context) {
    final t = GvlCommentsTheme.of(context);
    final l10n = GvlCommentsL10n.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: t.spacing ?? 8),
      child: Center(
        child: _loadingMore
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : TextButton(
          onPressed: _loadMore,
          child: Text(
            l10n?.loadPreviousCommentsLabel ??
                'Load previous comments',
          ),
        ),
      ),
    );
  }
}

String _commentDisplayText(CommentModel comment, GvlCommentsL10n? l10n) {
  // Moderated comments: content should be replaced by a generic message.
  if (comment.isModerated) {
    return l10n?.moderatedPlaceholderLabel ??
        'This comment has been moderated.';
  }

  // Reported-but-pending comments: show a "reported" placeholder.
  if (comment.isReported) {
    return l10n?.reportedPlaceholderLabel ??
        'This comment has been reported.';
  }

  // Normal case: show the raw body.
  return comment.body;
}

/// Default comment item (bubble + optional avatar).
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

    final bg = isMine
        ? (t.bubbleColor ?? cs.surfaceContainerHighest)
        : (t.bubbleAltColor ?? cs.surfaceContainer);
    final text = Theme.of(context).textTheme;
    final l10n = GvlCommentsL10n.of(context);

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
        borderRadius:
            t.bubbleRadius ?? const BorderRadius.all(Radius.circular(12)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: EdgeInsets.all((t.spacing ?? 8) + 4),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                comment.authorName ?? comment.externalUserId,
                style: t.authorStyle ??
                    text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                _commentDisplayText(comment, l10n),
                style: (t.bodyStyle ?? text.bodyMedium)?.copyWith(
                  fontStyle: comment.isVisibleNormally
                      ? FontStyle.normal
                      : FontStyle.italic,
                ),
              ),
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
        alignment:
        alignRight ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!alignRight && avatar != null) ...[
              SizedBox(
                width: avatarSize,
                height: avatarSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(avatarSize / 2),
                  child: avatar,
                ),
              ),
              SizedBox(width: t.spacing ?? 8),
            ],
            bubble,
            if (alignRight && avatar != null) ...[
              SizedBox(width: t.spacing ?? 8),
              SizedBox(
                width: avatarSize,
                height: avatarSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(avatarSize / 2),
                  child: avatar,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Metadata passed to builders to customize rendering.
///
/// Indicates whether the comment belongs to the current user and exposes basic
/// interaction callbacks that can be forwarded to custom widgets.
class GvlCommentMeta {
  /// Whether the comment was authored by the active user.
  final bool isMine;

  /// Whether the comment is currently being sent and not yet confirmed.
  final bool isSending;

  /// Optional handler for long-press interactions (for example opening a menu).
  final VoidCallback? onLongPress;

  /// Optional handler for tap interactions.
  final VoidCallback? onTap;

  /// Creates metadata for a comment item.
  const GvlCommentMeta({
    required this.isMine,
    this.isSending = false,
    this.onLongPress,
    this.onTap,
  });
}

/// Signature for building a single comment widget.
typedef CommentItemBuilder = Widget Function(
    BuildContext context,
    CommentModel comment,
    GvlCommentMeta meta,
    );

/// Signature for building separators between list items.
typedef SeparatorBuilder = Widget Function(
    BuildContext context,
    );

/// Signature for building avatar widgets.
typedef AvatarBuilder = Widget Function(
    BuildContext context,
    CommentModel comment,
    double size,
    );

/// Signature for building a custom send button.
typedef SendButtonBuilder = Widget Function(
    BuildContext context,
    VoidCallback onPressed,
    bool isSending,
    );

/// Allows replacing the whole composer (input + send button).
///
/// The builder receives the current [TextEditingController], callbacks for
/// submit actions, and the computed maximum line count for the text field.
typedef ComposerBuilder = Widget Function(
    BuildContext context, {
    required TextEditingController controller,
    required VoidCallback onSubmit,
    required bool isSending,
    required int maxLines,
    required String hintText,
    });

/// Theme extension used to style the comments list and composer.
@immutable
class GvlCommentsThemeData extends ThemeExtension<GvlCommentsThemeData> {
  /// Background color for comments authored by the current user.
  final Color? bubbleColor;

  /// Background color for comments authored by other users.
  final Color? bubbleAltColor;

  /// Color applied behind the list (gutter/background).
  final Color? gutterColor;

  /// Color used for badges such as moderation markers.
  final Color? badgeColor;

  /// Color used for error text and indicators.
  final Color? errorColor;

  /// Text style for author names.
  final TextStyle? authorStyle;

  /// Text style for comment bodies.
  final TextStyle? bodyStyle;

  /// Text style for timestamps.
  final TextStyle? timestampStyle;

  /// Text style used to display errors.
  final TextStyle? errorStyle;

  /// Text style for placeholder or hint text.
  final TextStyle? hintStyle;

  /// Text style for action buttons such as “Send”.
  final TextStyle? buttonStyle;

  /// Base spacing unit used for paddings and gaps.
  final double? spacing;

  /// Avatar size in logical pixels.
  final double? avatarSize;

  /// Corner radii applied to comment bubbles.
  final BorderRadius? bubbleRadius;

  /// Shape used for the composer input.
  final OutlinedBorder? composerShape;

  /// Elevation applied to bubbles.
  final double? elevation;

  /// Maximum number of visible lines in the composer before scrolling.
  final int? composerMaxLines;

  /// Creates theme data for the comments experience.
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

  /// Baseline theme tuned for comment threads.
  ///
  /// Uses the ambient [ThemeData] to derive colors and typography, providing a
  /// sensible starting point for most apps.
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
      timestampStyle:
      tt.bodySmall?.copyWith(color: cs.onSurface.withAlpha(0x99)),
      errorStyle: tt.bodyMedium?.copyWith(color: cs.error),
      hintStyle: theme.inputDecorationTheme.hintStyle ??
          tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
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

  /// Neutral preset with minimal decoration suitable for dense layouts.
  factory GvlCommentsThemeData.neutral(BuildContext context) {
    final base = GvlCommentsThemeData.defaults(context);
    return base.copyWith(
      spacing: (base.spacing ?? 8),
      avatarSize: base.avatarSize ?? 32,
      elevation: 0,
    );
  }

  /// Compact preset that reduces spacing and typography sizes.
  factory GvlCommentsThemeData.compact(BuildContext context) {
    final base = GvlCommentsThemeData.defaults(context);
    return base.copyWith(
      spacing: (base.spacing ?? 8) * 0.6,
      avatarSize: (base.avatarSize ?? 32) * 0.8,
      bodyStyle: base.bodyStyle?.copyWith(
        fontSize: (base.bodyStyle?.fontSize ?? 14) - 1,
      ),
      authorStyle: base.authorStyle?.copyWith(
        fontSize: (base.authorStyle?.fontSize ?? 13) - 1,
      ),
      bubbleRadius: const BorderRadius.all(Radius.circular(10)),
      elevation: 0,
    );
  }

  /// Card-like preset with subtle elevation and equal bubble colors.
  factory GvlCommentsThemeData.card(BuildContext context) {
    final base = GvlCommentsThemeData.defaults(context);
    final cs = Theme.of(context).colorScheme;
    return base.copyWith(
      bubbleColor: cs.surface,
      bubbleAltColor: cs.surface,
      gutterColor: cs.surface,
      elevation: 1.5,
      spacing: (base.spacing ?? 8) + 2,
      bubbleRadius: const BorderRadius.all(Radius.circular(14)),
    );
  }

  /// Playful preset with rounded “bubble” styling.
  factory GvlCommentsThemeData.bubble(BuildContext context) {
    final base = GvlCommentsThemeData.defaults(context);
    final cs = Theme.of(context).colorScheme;
    return base.copyWith(
      bubbleColor: cs.primaryContainer.withAlpha(220),
      bubbleAltColor: cs.surfaceContainer,
      authorStyle: base.authorStyle?.copyWith(
        color: cs.onPrimaryContainer,
        fontWeight: FontWeight.w700,
      ),
      bodyStyle: base.bodyStyle?.copyWith(color: cs.onPrimaryContainer),
      bubbleRadius: const BorderRadius.all(Radius.circular(18)),
      spacing: (base.spacing ?? 8) + 2,
    );
  }

  /// Combines two theme definitions, preferring non-null values from [other].
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

  @override
  /// Returns a copy with selectively overridden properties.
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
  /// Linearly interpolates between two themes.
  ThemeExtension<GvlCommentsThemeData> lerp(
      ThemeExtension<GvlCommentsThemeData>? other,
      double t,
      ) {
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
      composerMaxLines:
      t < 0.5 ? composerMaxLines : other.composerMaxLines,
    );
  }

  /// Helper to interpolate nullable doubles while preserving `null` when both
  /// inputs are `null`.
  static double? lerpDoubleNullable(double? a, double? b, double t) {
    if (a == null && b == null) return null;
    return Tween<double>(begin: a ?? b ?? 0, end: b ?? a ?? 0)
        .transform(t);
  }
}

/// Wrapper for local theme overrides.
class GvlCommentsTheme extends InheritedWidget {
  /// Theme data applied to descendant comments widgets.
  final GvlCommentsThemeData data;

  const GvlCommentsTheme({
    Key? key,
    required this.data,
    required Widget child,
  }) : super(key: key, child: child);

  /// Resolves the effective theme by merging defaults, global extensions, and
  /// the nearest [GvlCommentsTheme] ancestor.
  static GvlCommentsThemeData of(BuildContext context) {
    final local =
    context.dependOnInheritedWidgetOfExactType<GvlCommentsTheme>();
    final ext = Theme.of(context).extension<GvlCommentsThemeData>();
    final base = GvlCommentsThemeData.defaults(context);
    return base.merge(ext).merge(local?.data);
  }

  @override
  bool updateShouldNotify(GvlCommentsTheme oldWidget) =>
      data != oldWidget.data;
}

/// Immutable bundle of localized strings used by the comments UI.
@immutable
class GvlCommentsStrings {
  /// Title used for error banners.
  final String errorTitle;

  /// Label for retry actions.
  final String retry;

  /// Label for the send button.
  final String send;

  /// Placeholder displayed in the composer input.
  final String hintAddComment;

  /// Creates a localized string bundle.
  const GvlCommentsStrings({
    required this.errorTitle,
    required this.retry,
    required this.send,
    required this.hintAddComment,
  });

  /// French localization for the built-in strings.
  factory GvlCommentsStrings.fr() => const GvlCommentsStrings(
    errorTitle: 'Erreur',
    retry: 'Réessayer',
    send: 'Envoyer',
    hintAddComment: 'Ajouter un commentaire…',
  );

  /// English localization for the built-in strings.
  factory GvlCommentsStrings.en() => const GvlCommentsStrings(
    errorTitle: 'Error',
    retry: 'Retry',
    send: 'Send',
    hintAddComment: 'Add a comment…',
  );

  /// Returns a copy with selectively overridden labels.
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

/// Bubble alignment.
///
/// * [left] renders every comment starting from the left edge.
/// * [right] aligns all comments to the right edge.
/// * [autoByUser] aligns comments by author: current user on the right,
///   others on the left.
enum GvlCommentAlignment { left, right, autoByUser }