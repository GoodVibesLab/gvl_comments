import 'package:flutter/material.dart';

import '../gvl_comments.dart';
import '../models.dart';
import '../utils/time_utils.dart' show formatRelativeTime;
import 'comment_reactions_bar.dart';
import 'comments_list.dart';
import 'linked_text.dart';

/// Signature for a builder that renders a fully custom top comment widget.
///
/// Receives the loaded [comment] (never null when called) and a [refresh]
/// callback that the host can call to re-fetch the top comment from the API.
typedef TopCommentBuilder = Widget Function(
  BuildContext context,
  CommentModel comment,
  VoidCallback refresh,
);

/// Signature for a builder that renders a custom loading state.
typedef TopCommentLoadingBuilder = Widget Function(BuildContext context);

/// Signature for a builder that renders a custom empty state.
typedef TopCommentEmptyBuilder = Widget Function(BuildContext context);

/// Signature for a builder that renders a custom error state.
typedef TopCommentErrorBuilder = Widget Function(
  BuildContext context,
  String error,
  VoidCallback retry,
);

/// Widget that displays the single most-engaged comment for a thread.
///
/// Ideal for "highlight" UIs — for example showing a standout comment
/// below a post or article in a feed.
///
/// ## Usage
///
/// ### Default UI
/// ```dart
/// TopComment(
///   threadKey: 'post:abc-123-uuid-xxx',
///   user: UserProfile(id: 'user1', name: 'Alice'),
/// )
/// ```
///
/// ### Fully custom rendering
/// ```dart
/// TopComment(
///   threadKey: 'post:abc-123-uuid-xxx',
///   user: UserProfile(id: 'user1', name: 'Alice'),
///   builder: (context, comment, refresh) {
///     return ListTile(
///       title: Text(comment.authorName ?? 'Anonymous'),
///       subtitle: Text(comment.body),
///       trailing: Text('${comment.reactionTotal} reactions'),
///       onTap: refresh,
///     );
///   },
/// )
/// ```
class TopComment extends StatefulWidget {
  /// Thread to fetch the top comment from.
  final String threadKey;

  /// Current user (required for authentication).
  final UserProfile user;

  /// Fully custom builder. When provided, [avatarBuilder], [theme],
  /// [reactionsEnabled], and [padding] are ignored.
  final TopCommentBuilder? builder;

  /// Custom loading state builder.
  final TopCommentLoadingBuilder? loadingBuilder;

  /// Custom empty state builder (no comments in the thread).
  final TopCommentEmptyBuilder? emptyBuilder;

  /// Custom error state builder.
  final TopCommentErrorBuilder? errorBuilder;

  /// Builder for the avatar widget (default UI only).
  final AvatarBuilder? avatarBuilder;

  /// Theme override (default UI only).
  final GvlCommentsThemeData? theme;

  /// Whether to show reactions (default UI only).
  final bool reactionsEnabled;

  /// Padding around the widget (default UI only).
  final EdgeInsetsGeometry? padding;

  /// Whether to show the timestamp (default UI only).
  final bool showTimestamp;

  /// Called when the comment is tapped.
  final VoidCallback? onTap;

  const TopComment({
    super.key,
    required this.threadKey,
    required this.user,
    this.builder,
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.avatarBuilder,
    this.theme,
    this.reactionsEnabled = true,
    this.padding,
    this.showTimestamp = true,
    this.onTap,
  });

  @override
  State<TopComment> createState() => _TopCommentState();
}

class _TopCommentState extends State<TopComment> {
  CommentModel? _comment;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TopComment old) {
    super.didUpdateWidget(old);
    if (old.threadKey != widget.threadKey || old.user.id != widget.user.id) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final comment = await CommentsKit.I().topComment(
        widget.threadKey,
        user: widget.user,
      );
      if (!mounted) return;
      setState(() {
        _comment = comment;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _onReact(String? reaction) async {
    final comment = _comment;
    if (comment == null) return;

    // Optimistic update
    final oldReaction = comment.viewerReaction;
    final newCounts = Map<String, int>.from(comment.reactionCounts);
    var newTotal = comment.reactionTotal;

    // Remove old reaction
    if (oldReaction != null && newCounts.containsKey(oldReaction)) {
      newCounts[oldReaction] = (newCounts[oldReaction]! - 1).clamp(0, 999999);
      if (newCounts[oldReaction] == 0) newCounts.remove(oldReaction);
      newTotal--;
    }

    // Add new reaction
    if (reaction != null) {
      newCounts[reaction] = (newCounts[reaction] ?? 0) + 1;
      newTotal++;
    }

    setState(() {
      _comment = comment.copyWith(
        viewerReaction: reaction,
        reactionCounts: newCounts,
        reactionTotal: newTotal,
      );
    });

    try {
      await CommentsKit.I().setCommentReaction(
        commentId: comment.id,
        user: widget.user,
        reaction: reaction,
      );
    } catch (_) {
      // Rollback on error
      if (mounted) {
        setState(() => _comment = comment);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.loadingBuilder?.call(context) ??
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
    }

    if (_error != null) {
      return widget.errorBuilder?.call(context, _error!, _load) ??
          const SizedBox.shrink();
    }

    final comment = _comment;
    if (comment == null) {
      return widget.emptyBuilder?.call(context) ?? const SizedBox.shrink();
    }

    // Fully custom builder
    if (widget.builder != null) {
      return widget.builder!(context, comment, _load);
    }

    // Default UI
    return _DefaultTopCommentView(
      comment: comment,
      theme: widget.theme,
      avatarBuilder: widget.avatarBuilder,
      reactionsEnabled: widget.reactionsEnabled,
      showTimestamp: widget.showTimestamp,
      padding: widget.padding,
      onTap: widget.onTap,
      onReact: _onReact,
    );
  }
}

class _DefaultTopCommentView extends StatelessWidget {
  final CommentModel comment;
  final GvlCommentsThemeData? theme;
  final AvatarBuilder? avatarBuilder;
  final bool reactionsEnabled;
  final bool showTimestamp;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final ValueChanged<String?> onReact;

  const _DefaultTopCommentView({
    required this.comment,
    this.theme,
    this.avatarBuilder,
    this.reactionsEnabled = true,
    this.showTimestamp = true,
    this.padding,
    this.onTap,
    required this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme ?? GvlCommentsThemeData.defaults(context);
    final spacing = t.spacing ?? 8.0;
    final avatarSize = t.avatarSize ?? 32.0;
    final showAvatars = t.showAvatars ?? true;

    final avatar = showAvatars
        ? (avatarBuilder != null
            ? avatarBuilder!(context, comment, avatarSize)
            : _buildDefaultAvatar(comment, avatarSize))
        : null;

    Widget content = InkWell(
      onTap: onTap,
      borderRadius: t.bubbleRadius ?? const BorderRadius.all(Radius.circular(12)),
      child: Padding(
        padding: padding ?? EdgeInsets.symmetric(horizontal: spacing * 2, vertical: spacing),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (avatar != null) ...[
              avatar,
              SizedBox(width: spacing),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Author + timestamp row
                  Row(
                    children: [
                      if (comment.authorName != null)
                        Flexible(
                          child: Text(
                            comment.authorName!,
                            style: t.authorStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (comment.authorName != null && showTimestamp)
                        SizedBox(width: spacing),
                      if (showTimestamp)
                        Text(
                          formatRelativeTime(comment.createdAt, context),
                          style: t.timestampStyle,
                        ),
                    ],
                  ),
                  SizedBox(height: spacing / 2),
                  // Body
                  if (comment.isVisibleNormally)
                    LinkedText(
                      comment.body,
                      style: t.bodyStyle,
                      linkStyle: t.bodyStyle?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    )
                  else
                    Text(
                      comment.isModerated
                          ? 'This comment has been moderated.'
                          : 'This comment has been reported.',
                      style: t.bodyStyle?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  // Reactions
                  if (reactionsEnabled && comment.isVisibleNormally) ...[
                    SizedBox(height: spacing / 2),
                    CommentReactionsBar(
                      comment: comment,
                      onReact: onReact,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return content;
  }

  Widget _buildDefaultAvatar(CommentModel comment, double size) {
    final url = comment.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(url),
      );
    }

    final name = comment.authorName ?? comment.externalUserId;
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';

    return CircleAvatar(
      radius: size / 2,
      child: Text(initial),
    );
  }
}
