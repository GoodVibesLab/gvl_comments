import 'package:flutter/material.dart';

import '../gvl_comments.dart';
import '../models.dart';

/// Signature for a builder that renders a custom comment count widget.
///
/// Receives the [count] of approved comments and a [refresh] callback.
typedef CommentCountBuilder = Widget Function(
  BuildContext context,
  int count,
  VoidCallback refresh,
);

/// Signature for a builder that renders a custom loading state.
typedef CommentCountLoadingBuilder = Widget Function(BuildContext context);

/// Signature for a builder that renders a custom error state.
typedef CommentCountErrorBuilder = Widget Function(
  BuildContext context,
  String error,
  VoidCallback retry,
);

/// Widget that displays the approved comment count for a thread.
///
/// When used after [CommentsKit.prefetchThreads], reads from cache
/// (zero latency). Otherwise, fetches the count from the API.
///
/// ## Usage
///
/// ### Default (just the number)
/// ```dart
/// CommentCount(
///   threadKey: 'post:abc-123-uuid-xxx',
///   user: UserProfile(id: 'user1', name: 'Alice'),
/// )
/// ```
///
/// ### Custom builder
/// ```dart
/// CommentCount(
///   threadKey: 'post:abc-123-uuid-xxx',
///   user: UserProfile(id: 'user1', name: 'Alice'),
///   builder: (context, count, refresh) {
///     return Row(
///       children: [
///         Icon(Icons.comment_outlined, size: 16),
///         SizedBox(width: 4),
///         Text('$count comments'),
///       ],
///     );
///   },
/// )
/// ```
class CommentCount extends StatefulWidget {
  /// Thread to fetch the comment count from.
  final String threadKey;

  /// Current user (required for authentication).
  final UserProfile user;

  /// Fully custom builder. When provided, [style] is ignored.
  final CommentCountBuilder? builder;

  /// Custom loading state builder.
  final CommentCountLoadingBuilder? loadingBuilder;

  /// Custom error state builder.
  final CommentCountErrorBuilder? errorBuilder;

  /// Text style for the default count display.
  final TextStyle? style;

  const CommentCount({
    super.key,
    required this.threadKey,
    required this.user,
    this.builder,
    this.loadingBuilder,
    this.errorBuilder,
    this.style,
  });

  @override
  State<CommentCount> createState() => _CommentCountState();
}

class _CommentCountState extends State<CommentCount> {
  int? _count;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CommentCount old) {
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
      final count = await CommentsKit.I().commentCount(
        widget.threadKey,
        user: widget.user,
      );
      if (!mounted) return;
      setState(() {
        _count = count;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return widget.loadingBuilder?.call(context) ??
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          );
    }

    if (_error != null) {
      return widget.errorBuilder?.call(context, _error!, _load) ??
          const SizedBox.shrink();
    }

    final count = _count ?? 0;

    if (widget.builder != null) {
      return widget.builder!(context, count, _load);
    }

    return Text(
      '$count',
      style: widget.style ?? Theme.of(context).textTheme.bodyMedium,
    );
  }
}
