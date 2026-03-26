import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/gvl_comments_l10n.dart';
import '../gvl_comments.dart';
import '../models.dart';
import '../utils/time_utils.dart';
import 'comment_reactions_bar.dart';
import 'comments_error_view.dart';
import 'linked_text.dart';

/// Ready-to-use comment thread widget with pagination and a composer.
///
/// The widget renders a vertically scrolling list of comments for [threadKey]
/// and exposes builder hooks to customize avatars, bubbles, and the composer.
/// It fetches data through [CommentsKit] and keeps pagination state internally.
/// Preferred API name (no `Gvl` prefix).
class CommentsList extends StatefulWidget {
  /// Default number of comments fetched per page.
  ///
  /// Kept intentionally conservative for performance on mobile networks.
  static const int defaultPageSize = 30;

  /// Hard upper bound for the `limit` parameter.
  ///
  /// This protects both the host app and the backend from accidental large
  /// requests (e.g. `limit: 100000`).
  static const int maxPageSize = 100;

  /// Unique identifier for the thread to display.
  ///
  /// ## Important (security)
  /// This value must be **stable** (same post -> same key) and **high-entropy**
  /// (hard to guess) to reduce enumeration/spam risk.
  ///
  /// Recommended:
  /// - UUID (v4), ULID
  /// - Firestore / database document IDs
  /// - Any opaque random identifier you already have for the content
  ///
  /// Avoid guessable keys such as:
  /// - `post-123`, `article-42`, `news:2026-01-02`
  ///
  /// ### Format rules (strict mode)
  /// Allowed characters: `a-zA-Z0-9:_-.`
  /// - Minimum length: 20
  ///
  /// See: https://www.goodvibeslab.cloud/docs
  final String threadKey;

  /// Profile of the active user used for authentication and author metadata.
  ///
  /// When `null`, the widget operates in **read-only mode**: comments are
  /// visible but the composer is hidden and interactions (reply, react) are
  /// disabled.
  ///
  /// To allow anonymous posting, pass a guest profile instead of `null`:
  /// ```dart
  /// UserProfile(id: 'guest-$deviceId', name: 'Anonymous')
  /// ```
  final UserProfile? user;

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

  /// Builder for the "load more" button shown when pagination is available.
  ///
  /// When `null`, a default [TextButton] is used.
  final LoadMoreButtonBuilder? loadMoreButtonBuilder;

  /// Maximum number of comments fetched per page.
  final int limit;

  /// Padding applied around the scrollable list.
  final EdgeInsetsGeometry? padding;

  /// Optional scroll controller that allows programmatic scrolling.
  final ScrollController? scrollController;

  /// Optional local theme override for this widget.
  final GvlCommentsThemeData? theme;

  /// Display order of comments.
  /// - false = feed-like (default)
  /// - true = chat-like
  final bool newestAtBottom;

  /// Whether end-users can react to comments (emoji/like bar).
  ///
  /// This is a front-end only switch: it hides reaction UI and disables
  /// reaction interactions without changing backend behavior.
  final bool reactionsEnabled;

  /// Forces the "Powered by GVL Cloud" branding to be visible.
  ///
  /// By default, the branding footer is only shown for free-tier projects.
  /// Set this to `true` to display it regardless of the current plan
  /// (e.g. in a demo or showcase app).
  final bool showBranding;

  /// When `true`, the comment list does not scroll internally.
  ///
  /// Use this to embed comments inside a parent scrollable (e.g.
  /// `SingleChildScrollView` or `CustomScrollView`). The host is
  /// responsible for providing scroll and the composer should be placed
  /// outside (e.g. in a `Scaffold.bottomSheet`).
  ///
  /// When combined with [header], the widget handles everything: the
  /// header and comments scroll together inside a `SingleChildScrollView`
  /// while the composer stays sticky at the bottom.
  ///
  /// Defaults to `false` (the widget manages its own scroll).
  final bool shrinkWrap;

  /// Called when the user taps the composer while not signed in ([user] is
  /// `null`). Use this to trigger your sign-in flow.
  final VoidCallback? onSignInTap;

  /// Optional widget displayed above the comment list.
  ///
  /// Typically a post card, article preview, or any content that should
  /// scroll together with the comments. Best used with [shrinkWrap] set
  /// to `true` — the header scrolls away while the composer stays sticky
  /// at the bottom.
  final Widget? header;

  /// Creates a comments list bound to a thread and user profile.
  ///
  /// Provide builder callbacks to customize rendering; otherwise sensible
  /// defaults are used.
  const CommentsList({
    super.key,
    required this.threadKey,
    this.user,
    this.onSignInTap,
    this.commentItemBuilder,
    this.avatarBuilder,
    this.sendButtonBuilder,
    this.composerBuilder,
    this.separatorBuilder,
    this.loadMoreButtonBuilder,
    this.limit = defaultPageSize,
    this.padding,
    this.scrollController,
    this.theme,
    // Feed-like by default (newest comments first).
    this.newestAtBottom = false,
    this.reactionsEnabled = true,
    this.showBranding = false,
    this.shrinkWrap = false,
    this.header,
  });

  @override
  State<CommentsList> createState() => _CommentsListState();
}

/// Metadata passed to builders to customize rendering.
///
/// Indicates whether the comment belongs to the current user and exposes basic
/// interaction callbacks that can be forwarded to custom widgets.
@immutable
class CommentMeta {
  /// Whether the comment was authored by the active user.
  final bool isMine;

  /// Whether the comment is currently being sent and not yet confirmed.
  final bool isSending;

  /// Whether this comment is a reply (depth > 0).
  final bool isReply;

  /// Callback to initiate a reply to this comment.
  final VoidCallback? onReply;

  /// Optional handler for long-press interactions (for example opening a menu).
  final VoidCallback? onLongPress;

  /// Optional handler for tap interactions.
  final VoidCallback? onTap;

  /// Creates metadata for a comment item.
  const CommentMeta({
    required this.isMine,
    this.isSending = false,
    this.isReply = false,
    this.onReply,
    this.onLongPress,
    this.onTap,
  });
}

/// A root comment grouped with its replies for threaded display.
class _CommentThread {
  final CommentModel root;
  final List<CommentModel> replies;

  const _CommentThread({required this.root, this.replies = const []});
}

/// Builds a list of [_CommentThread] from a flat list of comments.
///
/// Roots are comments with depth == 0. Replies are grouped under their
/// root ancestor. The order of roots is preserved; replies within each
/// thread are sorted by [createdAt] ascending.
List<_CommentThread> _buildThreads(List<CommentModel> flat) {
  final roots = <CommentModel>[];
  final depth1ById = <String, CommentModel>{};
  final repliesByRoot = <String, List<CommentModel>>{};

  // First pass: separate roots and index depth-1 comments.
  for (final c in flat) {
    if (c.depth == 0) {
      roots.add(c);
    } else if (c.depth == 1) {
      depth1ById[c.id] = c;
      repliesByRoot.putIfAbsent(c.parentId!, () => []).add(c);
    }
  }

  // Second pass: attach depth-2 to their root via their depth-1 parent.
  for (final c in flat) {
    if (c.depth == 2 && c.parentId != null) {
      final d1Parent = depth1ById[c.parentId!];
      final rootId = d1Parent?.parentId ?? c.parentId!;
      repliesByRoot.putIfAbsent(rootId, () => []).add(c);
    }
  }

  return roots.map((r) {
    final replies = repliesByRoot[r.id] ?? [];
    replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return _CommentThread(root: r, replies: replies);
  }).toList();
}

/// Preferred API name (no `Gvl` prefix).
typedef CommentsThemeData = GvlCommentsThemeData;

/// Preferred API name (no `Gvl` prefix).
typedef CommentsTheme = GvlCommentsTheme;

/// Preferred API name (no `Gvl` prefix).
typedef CommentsStrings = GvlCommentsStrings;

/// Backward-compatible name.
@Deprecated('Use CommentsList.')
class GvlCommentsList extends CommentsList {
  const GvlCommentsList({
    super.key,
    required super.threadKey,
    required super.user,
    super.commentItemBuilder,
    super.avatarBuilder,
    super.sendButtonBuilder,
    super.composerBuilder,
    super.separatorBuilder,
    super.loadMoreButtonBuilder,
    super.limit,
    super.padding,
    super.scrollController,
    super.theme,
    // Inherits default: feed-like ordering (newestAtBottom = false)
    super.newestAtBottom,
    super.reactionsEnabled,
    super.shrinkWrap,
    super.header,
  });
}

class _CommentsListState extends State<CommentsList>
    with AutomaticKeepAliveClientMixin {
  List<CommentModel>? _comments;
  String? _error;
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();

  /// The comment currently being replied to (`null` = posting a root).
  CommentModel? _replyingTo;

  /// Root IDs whose reply threads have been fully expanded by the user.
  final _expandedThreads = <String>{};

  // Scroll controller used by the ListView.
  // If the host app provides one, we use it; otherwise we create our own.
  late ScrollController _scrollController;
  late bool _ownsScrollController;
  bool _loading = true;
  bool _sending = false;

  // Pagination state
  bool _loadingMore = false;
  bool _hasMore = true;

  /// Opaque cursor returned by the API in `x-next-cursor`.
  /// When null, we are at the first page.
  String? _nextCursor;

  bool _userReportsEnabled = true;

  // Track pending (optimistic) comments.
  final Set<String> _pendingIds = <String>{};

  // Track freshly created comments for entry animation.
  final Set<String> _recentlyCreatedCommentIds = <String>{};

  /// Sanitized per-page size used for API calls.
  ///
  /// We clamp to a safe range so consumers can't accidentally request
  /// extremely large pages.
  int get _effectiveLimit {
    final raw = widget.limit;
    if (raw <= 0) return 1;
    return raw.clamp(1, CommentsList.maxPageSize);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _ownsScrollController = widget.scrollController == null;
    _scrollController = widget.scrollController ?? ScrollController();

    _primeAndLoad();
  }

  @override
  void didUpdateWidget(covariant CommentsList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Keep the scroll controller consistent with the widget.
    // If the host swaps controllers, we must stop using the old one.
    if (oldWidget.scrollController != widget.scrollController) {
      if (_ownsScrollController) {
        _scrollController.dispose();
      }
      _ownsScrollController = widget.scrollController == null;
      _scrollController = widget.scrollController ?? ScrollController();
    }

    if (oldWidget.user?.id != widget.user?.id) {
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
    _nextCursor = null;
  }

  Future<void> _primeAndLoad() async {
    final kit = CommentsKit.I();

    // Best-effort identify (fire-and-forget).
    final user = widget.user;
    if (user != null) {
      unawaited(kit.identify(user));
    }

    // Fetch moderation settings and comments in PARALLEL.
    // Settings are non-critical — comments should never wait for them.
    final settingsFuture = kit
        .getModerationSettings(user: user)
        .then((settings) {
      if (mounted) {
        setState(() {
          _userReportsEnabled = settings.userReportsEnabled;
        });
      }
    }).catchError((Object e) {
      if (e is CommentsAuthException) {
        debugPrint(
            'gvl_comments: moderation settings unavailable (${e.code}) — keeping defaults');
      } else {
        debugPrint('gvl_comments: error while loading moderation settings: $e');
      }
    });

    // Load comments without waiting for settings.
    await _load();

    // Ensure settings complete before we're fully done (best-effort).
    await settingsFuture;
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
        limit: _effectiveLimit,
        cursor: null,
      );

      if (!mounted) return;

      setState(() {
        _comments = list;
        // Prefer cursor-based pagination (stable with duplicate timestamps).
        _nextCursor = kit.lastNextCursor;
        _hasMore = kit.lastHasMore;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        if (e is CommentsAuthException) {
          _error = e.message;
        } else {
          _error = e.toString();
        }
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _nextCursor == null) return;

    setState(() {
      _loadingMore = true;
      _error = null;
    });

    try {
      final kit = CommentsKit.I();
      final list = await kit.listByThreadKey(
        widget.threadKey,
        user: widget.user,
        limit: _effectiveLimit,
        cursor: _nextCursor,
      );

      if (!mounted) return;

      setState(() {
        final current = _comments ?? <CommentModel>[];
        _comments = [...current, ...list];

        _nextCursor = kit.lastNextCursor;
        _hasMore = kit.lastHasMore;
        _loadingMore = false;
      });
    } catch (e) {
      setState(() {
        if (e is CommentsAuthException) {
          _error = e.message;
        } else {
          _error = e.toString();
        }
        _loadingMore = false;
      });
    }
  }

  /// Scrolls to the most relevant edge after the user posts a comment.
  ///
  /// - When `newestAtBottom=true`, new comments are displayed at the bottom
  ///   (oldest -> newest), so we scroll to the bottom.
  /// - When `newestAtBottom=false`, new comments are displayed at the top
  ///   (newest -> oldest), so we scroll to the top.
  ///
  /// This is best-effort: if the list is not attached yet, we simply skip.
  void _scrollToPostedComment() {
    // Run after the current frame so that the new item has a layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;

      final position = _scrollController.position;
      final targetOffset =
          widget.newestAtBottom ? position.maxScrollExtent : 0.0;

      // If the scroll extent is not ready (rare on some platforms), fall back to jump.
      try {
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      } catch (_) {
        // Animation can throw if called during certain transient layout states.
        // Jumping is safe and keeps the UX predictable.
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(targetOffset);
        }
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    // Create a local temporary ID for optimistic UI.
    final tempId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().toUtc();

    // Capture reply target before clearing state.
    final replyTarget = _replyingTo;
    final int pendingDepth;
    final String? pendingParentId;

    if (replyTarget != null) {
      if (replyTarget.depth < 2) {
        pendingDepth = replyTarget.depth + 1;
        pendingParentId = replyTarget.id;
      } else {
        // Flattened: depth stays 2, parent becomes the depth-1 ancestor.
        pendingDepth = 2;
        pendingParentId = replyTarget.parentId;
      }
    } else {
      pendingDepth = 0;
      pendingParentId = null;
    }

    final user = widget.user;
    final pending = CommentModel(
      id: tempId,
      externalUserId: user?.id ?? '',
      authorName: user?.name,
      body: text,
      createdAt: now,
      avatarUrl: user?.avatarUrl,
      isFlagged: false,
      commentStatus: CommentStatus.pending,
      parentId: pendingParentId,
      depth: pendingDepth,
    );

    // Add optimistic comment.
    setState(() {
      _pendingIds.add(tempId);
      _recentlyCreatedCommentIds.add(tempId);
      // Keep internal order newest-first so pagination (older pages appended)
      // stays consistent, regardless of UI ordering.
      _comments = [pending, ...(_comments ?? [])];
      _ctrl.clear();
      _replyingTo = null;
      _focusNode.unfocus();
    });

    // Keep the freshly posted comment in view.
    _scrollToPostedComment();

    try {
      final kit = CommentsKit.I();
      final created = await kit.post(
        threadKey: widget.threadKey,
        body: text,
        user: widget.user,
        parentId: replyTarget?.id,
      );

      if (!mounted) return;

      // Replace pending with actual.
      setState(() {
        final list = _comments ?? <CommentModel>[];
        final idx = list.indexWhere((c) => c.id == tempId);
        if (idx != -1) {
          list[idx] = created;
        }
        _comments = List<CommentModel>.from(list);
        _pendingIds.remove(tempId);
        _recentlyCreatedCommentIds
          ..remove(tempId)
          ..add(created.id);
      });
    } catch (e) {
      // Remove optimistic bubble on failure.
      setState(() {
        _comments = (_comments ?? <CommentModel>[])
            .where((c) => c.id != tempId)
            .toList();
        _pendingIds.remove(tempId);
        _recentlyCreatedCommentIds.remove(tempId);
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
                  ? (l10n?.alreadyReportedLabel ??
                      'You already reported this comment')
                  : (l10n?.reportSentLabel ?? 'Comment reported'),
            ),
          ),
        );
      }
    } catch (e) {
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

  /// Applies a reaction to a comment and updates the UI optimistically.
  ///
  /// This method is intentionally best-effort: if the API call fails, we keep
  /// the optimistic state (the next refresh will reconcile with the server).
  Future<void> _onReact(CommentModel comment, String? reaction) async {
    // Update local state optimistically.
    setState(() {
      final list = _comments ?? <CommentModel>[];
      final idx = list.indexWhere((c) => c.id == comment.id);
      if (idx == -1) return;

      final current = list[idx];

      // These fields are expected to be provided by the API:
      // - viewerReaction: String?
      // - reactionCounts: Map<String, int>
      // - reactionTotal: int
      final prev = current.viewerReaction;
      final counts = Map<String, int>.from(current.reactionCounts);

      // Remove previous reaction from counts.
      if (prev != null && prev.isNotEmpty) {
        final v = (counts[prev] ?? 0) - 1;
        if (v <= 0) {
          counts.remove(prev);
        } else {
          counts[prev] = v;
        }
      }

      // Apply new reaction (or null to remove).
      if (reaction != null && reaction.isNotEmpty) {
        counts[reaction] = (counts[reaction] ?? 0) + 1;
      }

      final total = counts.values.fold<int>(0, (a, b) => a + b);

      list[idx] = current.copyWith(
        viewerReaction:
            (reaction != null && reaction.isNotEmpty) ? reaction : null,
        reactionCounts: counts,
        reactionTotal: total,
      );

      _comments = List<CommentModel>.from(list);
    });

    // Best-effort API update.
    try {
      await CommentsKit.I().setCommentReaction(
        commentId: comment.id,
        user: widget.user,
        reaction: reaction,
      );
    } catch (e) {
      debugPrint('gvl_comments: error while setting reaction: $e');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    if (_ownsScrollController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  Future<void> _openBrandingLink() async {
    const url = 'https://www.goodvibeslab.cloud';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.theme != null) {
      return GvlCommentsTheme(
        data: widget.theme!,
        child: Builder(
          builder: (ctx) => _buildContent(ctx),
        ),
      );
    }

    return _buildContent(context);
  }

  Widget _buildContent(BuildContext context) {
    final l10n = GvlCommentsL10n.of(context);
    final t = GvlCommentsTheme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && (_comments == null || _comments!.isEmpty)) {
      return CommentsErrorView(
        error: _error!, // idéalement garde _error en Object plutôt que String
        onRetry: _load,
        threadKey: widget.threadKey,
      );
    }

    // All comments returned by the API are safe to render.
    // Server-side RLS / views already hide hard-deleted comments.
    final rawComments = _comments ?? <CommentModel>[];

    // Build threaded structure from the flat list.
    var threads = _buildThreads(rawComments);
    if (widget.newestAtBottom) {
      threads = threads.reversed.toList(growable: false);
    }

    final padding =
        widget.padding ?? EdgeInsets.symmetric(vertical: (t.spacing ?? 8));

    final hasMoreRow = _hasMore && threads.isNotEmpty;
    final itemCount = threads.length + (hasMoreRow ? 1 : 0);

    final listView = ListView.separated(
      controller: widget.shrinkWrap ? null : _scrollController,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : null,
      reverse: false,
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (ctx, index) {
        // Do not put a separator adjacent to the "load more" row.
        if (hasMoreRow) {
          if (widget.newestAtBottom && index == 0) {
            return const SizedBox.shrink();
          }
          if (!widget.newestAtBottom && index == threads.length - 1) {
            return const SizedBox.shrink();
          }
        }
        return _buildSeparator(ctx);
      },
      itemBuilder: (ctx, i) {
        // Load-more row position depends on ordering.
        if (hasMoreRow) {
          if (widget.newestAtBottom && i == 0) {
            return _buildLoadMoreRow(ctx);
          }
          if (!widget.newestAtBottom && i == threads.length) {
            return _buildLoadMoreRow(ctx);
          }
        }

        final threadIndex =
            (hasMoreRow && widget.newestAtBottom) ? i - 1 : i;
        final thread = threads[threadIndex];

        return _buildThreadItem(ctx, thread, t);
      },
    );

    final branding = (widget.showBranding ||
            (CommentsKit.I().currentPlan ?? 'free') == 'free')
        ? _buildBrandingFooter(context)
        : null;

    // Show active composer or disabled sign-in prompt.
    final isReadOnly = widget.user == null;
    final composer = isReadOnly
        ? _buildDisabledComposer(context, t, l10n)
        : _buildComposer(context, t, l10n);
    final bgColor = t.backgroundColor ?? Colors.transparent;

    // --- Mode: shrinkWrap + header ---
    // Header and comments scroll together, composer stays sticky at bottom.
    if (widget.shrinkWrap && widget.header != null) {
      return ColoredBox(
        color: bgColor,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: padding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    widget.header!,
                    // Build thread items directly (no nested ListView).
                    if (hasMoreRow && widget.newestAtBottom)
                      _buildLoadMoreRow(context),
                    for (int i = 0; i < threads.length; i++) ...[
                      if (i > 0) _buildSeparator(context),
                      _buildThreadItem(context, threads[i], t),
                    ],
                    if (hasMoreRow && !widget.newestAtBottom)
                      _buildLoadMoreRow(context),
                    if (branding != null) branding,
                  ],
                ),
              ),
            ),
            composer,
          ],
        ),
      );
    }

    // --- Mode: shrinkWrap (no header) ---
    // No internal scroll, no composer. Host manages scroll and composer.
    if (widget.shrinkWrap) {
      return ColoredBox(
        color: bgColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            listView,
            if (branding != null) branding,
            composer,
          ],
        ),
      );
    }

    // --- Default mode ---
    // Self-contained scroll with sticky composer.
    return ColoredBox(
      color: bgColor,
      child: Column(
        children: [
          Expanded(child: listView),
          if (branding != null) branding,
          composer,
        ],
      ),
    );
  }

  /// Maximum number of replies shown before the "See more" button.
  static const _collapsedReplyLimit = 2;

  /// Builds a full thread: root comment + indented replies.
  Widget _buildThreadItem(
      BuildContext ctx, _CommentThread thread, GvlCommentsThemeData t) {
    final avatarSize = t.avatarSize ?? 32;
    final spacing = t.spacing ?? 8;
    final replyIndent = avatarSize + spacing;

    final isExpanded = _expandedThreads.contains(thread.root.id);
    final allReplies = thread.replies;
    final visibleReplies =
        isExpanded || allReplies.length <= _collapsedReplyLimit
            ? allReplies
            : allReplies.sublist(0, _collapsedReplyLimit);
    final hiddenCount = allReplies.length - visibleReplies.length;

    final l10n = GvlCommentsL10n.of(ctx);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSingleComment(ctx, thread.root, indentLeft: 0),
        for (final reply in visibleReplies)
          Padding(
            padding: EdgeInsets.only(
              left: reply.depth >= 2 ? replyIndent * 2 : replyIndent,
            ),
            child: _buildSingleComment(
              ctx,
              reply,
              indentLeft: reply.depth >= 2 ? replyIndent * 2 : replyIndent,
            ),
          ),
        if (hiddenCount > 0)
          Padding(
            padding: EdgeInsets.only(left: replyIndent, top: 4, bottom: 4),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _expandedThreads.add(thread.root.id);
                });
              },
              child: Text(
                l10n?.seeMoreReplies(hiddenCount) ??
                    'See $hiddenCount more ${hiddenCount == 1 ? 'reply' : 'replies'}',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Builds a single comment item with animation, report menu, and reply button.
  Widget _buildSingleComment(BuildContext ctx, CommentModel c,
      {required double indentLeft}) {
    final user = widget.user;
    final isMine = user != null && c.externalUserId == user.id;
    final isSending = _pendingIds.contains(c.id);
    final isReadOnly = user == null;

    void onReply() {
      setState(() {
        _replyingTo = c;
      });
      _focusNode.requestFocus();
    }

    final canReact = widget.reactionsEnabled && !isReadOnly;

    Widget baseItem;
    if (widget.commentItemBuilder != null) {
      baseItem = widget.commentItemBuilder!(
        ctx,
        c,
        CommentMeta(
          isMine: isMine,
          isSending: isSending,
          isReply: c.depth > 0,
          onReply: isReadOnly ? null : onReply,
        ),
      );
    } else {
      baseItem = _DefaultCommentItem(
        comment: c,
        isMine: isMine,
        avatarBuilder: widget.avatarBuilder,
        isSending: isSending,
        reactionsEnabled: canReact,
        onReact: canReact ? _onReact : null,
        onReply: isReadOnly ? null : onReply,
        allComments: _comments ?? [],
      );
    }

    // Apply a subtle entry animation for freshly created comments.
    final isJustCreated = _recentlyCreatedCommentIds.contains(c.id);

    Widget animatedItem;
    if (isJustCreated) {
      animatedItem = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        onEnd: () {
          if (!mounted) return;
          setState(() {
            _recentlyCreatedCommentIds.remove(c.id);
          });
        },
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * 6),
              child: child,
            ),
          );
        },
        child: baseItem,
      );
    } else {
      animatedItem = baseItem;
    }

    return Stack(
      children: [
        animatedItem,
        if (_userReportsEnabled)
          Positioned(
            top: 0,
            right: 0,
            child: PopupMenuButton<String>(
              icon: Icon(
                Icons.more_horiz,
                size: 16,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant.withAlpha(100),
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
                    GvlCommentsL10n.of(context)?.reportLabel ?? 'Report',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBrandingFooter(BuildContext context) {
    final t = GvlCommentsTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final baseStyle =
        (t.timestampStyle ?? textTheme.labelSmall) ?? const TextStyle();
    final color = (t.timestampStyle?.color ?? colorScheme.onSurfaceVariant)
        .withAlpha(180);

    return Padding(
      padding: EdgeInsets.only(
        left: t.spacing ?? 8,
        right: t.spacing ?? 8,
        top: (t.spacing ?? 8) / 8,
        bottom: 0,
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: InkWell(
          onTap: _openBrandingLink,
          borderRadius: BorderRadius.circular(999),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Comments powered by ',
                style: baseStyle.copyWith(color: color),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Image.asset(
                  'assets/gvl_cloud_logo.png',
                  package: 'gvl_comments',
                  height: 11,
                  color: color,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                'GVL Cloud',
                style: baseStyle.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Disabled composer shown when [CommentsList.user] is `null`.
  ///
  /// Displays a grayed-out text field with a "Sign in to comment" hint.
  /// Tapping it invokes [CommentsList.onSignInTap] when provided.
  Widget _buildDisabledComposer(
    BuildContext context,
    GvlCommentsThemeData t,
    GvlCommentsL10n? l10n,
  ) {
    final hint =
        l10n?.signInToCommentHint ?? 'Sign in to comment';

    return SafeArea(
      top: false,
      child: GestureDetector(
        onTap: widget.onSignInTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            t.spacing ?? 8,
            (t.spacing ?? 8) / 2,
            t.spacing ?? 8,
            t.spacing ?? 8,
          ),
          child: Opacity(
            opacity: 0.5,
            child: IgnorePointer(
              child: TextField(
                enabled: false,
                decoration: InputDecoration(
                  hintText: hint,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  filled: true,
                  fillColor:
                      Theme.of(context).colorScheme.surfaceContainerHigh,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComposer(
    BuildContext context,
    GvlCommentsThemeData t,
    GvlCommentsL10n? l10n,
  ) {
    final maxLines = t.composerMaxLines ?? 6;
    final replyTo = _replyingTo;
    final replyName =
        replyTo?.authorName ?? replyTo?.externalUserId ?? '';
    final hint = replyTo != null
        ? (l10n?.replyHint(replyName) ?? 'Reply to $replyName…')
        : l10n?.addCommentHint;

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

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // "Replying to @name" chip
          if (replyTo != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                t.spacing ?? 8,
                (t.spacing ?? 8) / 2,
                t.spacing ?? 8,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n?.replyingToLabel(replyName) ??
                          'Replying to $replyName',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      tooltip: l10n?.cancelReplyTooltip ?? 'Cancel reply',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _replyingTo = null;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              t.spacing ?? 8,
              (t.spacing ?? 8) / 2,
              t.spacing ?? 8,
              t.spacing ?? 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    shape: t.composerShape ??
                        const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.all(Radius.circular(999)),
                        ),
                    child: Container(
                      color: t.backgroundColor ??
                          Theme.of(context).colorScheme.surface,
                      child: TextField(
                        controller: _ctrl,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.newline,
                        maxLines: null,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: hint,
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHigh,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: (t.spacing ?? 8) / 2),
                widget.sendButtonBuilder != null
                    ? widget.sendButtonBuilder!(
                        context,
                        _sending ? () {} : _send,
                        _sending,
                      )
                    : SizedBox(
                        height: 40,
                        width: 40,
                        child: IconButton.filled(
                          onPressed: _sending ? null : _send,
                          tooltip: l10n?.sendTooltip,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeparator(BuildContext context) {
    if (widget.separatorBuilder == null) {
      final spacing = GvlCommentsTheme.of(context).spacing ?? 8;
      return SizedBox(
        height: spacing * 0.25,
      );
    }
    return widget.separatorBuilder!(context);
  }

  Widget _buildLoadMoreRow(BuildContext context) {
    if (widget.loadMoreButtonBuilder != null) {
      return widget.loadMoreButtonBuilder!(context, _loadMore, _loadingMore);
    }

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
                  l10n?.loadPreviousCommentsLabel ?? 'Load previous comments',
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
    return l10n?.reportedPlaceholderLabel ?? 'This comment has been reported.';
  }

  // Normal case: show the raw body.
  return comment.body;
}

/// Default comment item (bubble + optional avatar).
class _DefaultCommentItem extends StatelessWidget {
  final CommentModel comment;
  final bool isMine;
  final AvatarBuilder? avatarBuilder;
  final bool isSending;

  /// Whether end-users can react to comments (emoji/like bar).
  final bool reactionsEnabled;

  /// Called when the user selects or clears a reaction.
  ///
  /// If `reaction` is `null`, the current reaction should be removed.
  final Future<void> Function(CommentModel comment, String? reaction)? onReact;

  /// Called when the user taps the reply button.
  final VoidCallback? onReply;

  /// Full flat list of comments, used to resolve @mention display names.
  final List<CommentModel> allComments;

  const _DefaultCommentItem({
    required this.comment,
    required this.isMine,
    this.avatarBuilder,
    this.isSending = false,
    this.reactionsEnabled = true,
    this.onReact,
    this.onReply,
    this.allComments = const [],
  });

  /// Resolves a display name from a user ID by looking up [allComments].
  String _resolveDisplayName(String userId) {
    for (final c in allComments) {
      if (c.externalUserId == userId && c.authorName != null) {
        return c.authorName!;
      }
    }
    return userId;
  }

  @override
  Widget build(BuildContext context) {
    final t = GvlCommentsTheme.of(context);
    final cs = Theme.of(context).colorScheme;

    final baseMine = t.bubbleColor ?? cs.surface;
    final baseOther = t.bubbleAltColor ?? cs.surface;

    final bg = isMine
        ? baseMine
        : Color.alphaBlend(
            cs.onSurface.withAlpha(10),
            baseOther,
          );

    final text = Theme.of(context).textTheme;
    final l10n = GvlCommentsL10n.of(context);

    final createdAt = comment.createdAt;
    final relativeTime = formatRelativeTime(createdAt, context);

    final avatarSize = t.avatarSize ?? 32;
    final showAvatars = t.showAvatars ?? true;

    final tsBase =
        t.timestampStyle ?? text.bodySmall ?? const TextStyle(fontSize: 11);
    final tsColor =
        (t.timestampStyle?.color ?? cs.onSurfaceVariant).withAlpha(180);
    final metaStyle = tsBase.copyWith(
      fontSize: (tsBase.fontSize ?? 11) - 1,
      color: tsColor,
      letterSpacing: (tsBase.letterSpacing ?? 0) + 0.1,
    );

    Widget? avatar;
    if (showAvatars) {
      if (avatarBuilder != null) {
        avatar = avatarBuilder!(context, comment, avatarSize);
      } else {
        final name = comment.authorName ?? comment.externalUserId;
        final initial =
            name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
        final avatarUrl = comment.avatarUrl?.trim();

        avatar = (avatarUrl != null && avatarUrl.isNotEmpty)
            ? ColoredBox(
                color: cs.secondaryContainer,
                child: Image.network(
                  avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _InitialsAvatar(
                      initial: initial,
                      textStyle: text.bodyMedium,
                    );
                  },
                ),
              )
            : _InitialsAvatar(
                initial: initial,
                textStyle: text.bodyMedium,
              );
      }
    }

    // --- Compact bubble (Facebook-style) ---
    final bubbleContent = Material(
      color: bg,
      elevation: t.elevation ?? 0,
      shape: RoundedRectangleBorder(
        borderRadius:
            t.bubbleRadius ?? const BorderRadius.all(Radius.circular(12)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                comment.authorName ?? comment.externalUserId,
                style: t.authorStyle ??
                    text.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
              const SizedBox(height: 2),
              // @mention for flattened depth-2 replies
              if (comment.replyToUserId != null &&
                  comment.isVisibleNormally) ...[
                Text(
                  '@${_resolveDisplayName(comment.replyToUserId!)}',
                  style: (t.bodyStyle ?? text.bodyMedium)?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
              ],
              LinkedText(
                _commentDisplayText(comment, l10n),
                style: (t.bodyStyle ?? text.bodyMedium)?.copyWith(
                  fontStyle: comment.isVisibleNormally
                      ? FontStyle.normal
                      : FontStyle.italic,
                ),
                linkStyle: (t.bodyStyle ?? text.bodyMedium)?.copyWith(
                  decoration: TextDecoration.underline,
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

    final bubbleWidget = Opacity(
      opacity: isSending ? 0.55 : 1.0,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: (!isSending && reactionsEnabled && onReact != null)
            ? () async {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null) return;

                final pos = box.localToGlobal(Offset.zero);
                final size = box.size;

                final anchor =
                    Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height);
                final picked = await showCommentReactionPicker(context,
                    currentReaction: comment.viewerReaction,
                    anchor: Offset(anchor.left, anchor.bottom));
                if (picked == null) return;

                final next =
                    (picked == comment.viewerReaction) ? null : picked;
                await onReact!(comment, next);
              }
            : null,
        onDoubleTap: (!isSending && reactionsEnabled && onReact != null)
            ? () async {
                final current = comment.viewerReaction;
                final next = (current == 'love') ? null : 'love';
                await onReact!(comment, next);
              }
            : null,
        child: bubbleContent,
      ),
    );

    // --- Meta row: timestamp · Reply · [reactions]    [like button] ---
    final hasReactions = comment.reactionTotal > 0;
    final counts = comment.reactionCounts;
    final viewer = comment.viewerReaction;

    // Build inline reaction summary (e.g. "❤️ 😮 3")
    Widget? reactionSummary;
    if (hasReactions) {
      final top = _topInlineReactions(counts, max: 3);
      reactionSummary = GestureDetector(
        onTap: (!isSending && reactionsEnabled && onReact != null)
            ? () async {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null) return;
                final pos = box.localToGlobal(Offset.zero);
                final size = box.size;
                final picked = await showCommentReactionPicker(context,
                    currentReaction: viewer,
                    anchor: Offset(pos.dx + size.width / 2, pos.dy));
                if (picked == null) return;
                final next = (picked == viewer) ? null : picked;
                await onReact!(comment, next);
              }
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in top)
              Padding(
                padding: const EdgeInsets.only(right: 1),
                child: Text(
                  _inlineEmojiFor(r.id),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            const SizedBox(width: 3),
            Text('${comment.reactionTotal}', style: metaStyle),
          ],
        ),
      );
    }

    // Like/react affordance: only shown when user has NOT reacted yet.
    // Once reacted, their emoji is already visible in the reaction summary.
    Widget? likeButton;
    final hasViewer = viewer != null && viewer.isNotEmpty;
    if (reactionsEnabled && onReact != null && !isSending && !hasViewer) {
      likeButton = _ReactionAffordance(
        hasReaction: false,
        viewerEmoji: null,
        onTap: () {
          onReact!(comment, 'like');
        },
        onLongPress: () async {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final pos = box.localToGlobal(Offset.zero);
          final size = box.size;
          final picked = await showCommentReactionPicker(context,
              currentReaction: viewer,
              anchor: Offset(pos.dx + size.width, pos.dy));
          if (picked == null) return;
          final next = (picked == viewer) ? null : picked;
          await onReact!(comment, next);
        },
      );
    }

    final baseSpacing = t.spacing ?? 8;
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: 4,
        horizontal: baseSpacing,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (avatar != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: SizedBox(
                width: avatarSize,
                height: avatarSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(avatarSize / 2),
                  child: avatar,
                ),
              ),
            ),
            SizedBox(width: t.spacing ?? 8),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bubbleWidget,
                const SizedBox(height: 2),
                // Meta row
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Row(
                    children: [
                      // Timestamp
                      Text(relativeTime, style: metaStyle),
                      // Reply
                      if (onReply != null && !isSending) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('·', style: metaStyle),
                        ),
                        GestureDetector(
                          onTap: onReply,
                          child: Text(
                            l10n?.replyLabel ?? 'Reply',
                            style: metaStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      // Like affordance (right after Reply)
                      if (likeButton != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('·', style: metaStyle),
                        ),
                        likeButton,
                      ],
                      // Inline reactions summary
                      if (reactionSummary != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text('·', style: metaStyle),
                        ),
                        reactionSummary,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline helper to get top reactions by count (used in meta row).
class _InlineReaction {
  final String id;
  final int count;
  const _InlineReaction(this.id, this.count);
}

List<_InlineReaction> _topInlineReactions(Map<String, int> counts,
    {int max = 3}) {
  final items = <_InlineReaction>[];
  counts.forEach((key, value) {
    if (value > 0) items.add(_InlineReaction(key, value));
  });
  items.sort((a, b) {
    final c = b.count.compareTo(a.count);
    if (c != 0) return c;
    return a.id.compareTo(b.id);
  });
  if (items.length <= max) return items;
  return items.sublist(0, max);
}

/// Maps reaction id to emoji for inline display.
String _inlineEmojiFor(String id) {
  const map = {
    'like': '👍',
    'love': '❤️',
    'laugh': '😂',
    'wow': '😮',
    'sad': '😢',
    'angry': '😡',
  };
  return map[id] ?? '👍';
}

/// Facebook-style like/react affordance button shown on the right of the
/// meta row. Tap to toggle like, long-press to open the reaction picker.
class _ReactionAffordance extends StatelessWidget {
  final bool hasReaction;
  final String? viewerEmoji;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ReactionAffordance({
    required this.hasReaction,
    this.viewerEmoji,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: hasReaction
            ? Text(
                viewerEmoji ?? '👍',
                style: const TextStyle(fontSize: 16),
              )
            : Icon(
                Icons.thumb_up_outlined,
                size: 16,
                color: cs.onSurfaceVariant.withAlpha(160),
              ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String initial;
  final TextStyle? textStyle;

  const _InitialsAvatar({
    required this.initial,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: cs.secondaryContainer,
      child: Center(
        child: Text(
          initial,
          style:
              (textStyle ?? Theme.of(context).textTheme.bodyMedium)?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

@Deprecated('Use CommentMeta.')
class GvlCommentMeta extends CommentMeta {
  const GvlCommentMeta({
    required super.isMine,
    super.isSending = false,
    super.onLongPress,
    super.onTap,
  });
}

/// Signature for building a single comment widget.
typedef CommentItemBuilder = Widget Function(
  BuildContext context,
  CommentModel comment,
  CommentMeta meta,
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

/// Signature for building the "load more" / "load previous comments" button.
///
/// The builder receives [onPressed] to trigger pagination and [isLoading]
/// to show a spinner while fetching.
typedef LoadMoreButtonBuilder = Widget Function(
  BuildContext context,
  VoidCallback onPressed,
  bool isLoading,
);

/// Theme extension used to style the comments list and composer.
@immutable
class GvlCommentsThemeData extends ThemeExtension<GvlCommentsThemeData> {
  /// Background color for comments authored by the current user.
  final Color? bubbleColor;

  /// Background color for comments authored by other users.
  final Color? bubbleAltColor;

  /// Color applied behind the list (gutter/background).
  final Color? backgroundColor;

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

  /// Whether avatar circles should be displayed next to comments.
  final bool? showAvatars;

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
    this.backgroundColor,
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
    this.showAvatars,
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
      // Keep defaults conservative, but not “invisible”.
      bubbleColor: cs.surfaceContainerHighest,
      bubbleAltColor: cs.surfaceContainer,
      // IMPORTANT: default background should be transparent so the host app can
      // control the surrounding surface without fighting the widget.
      backgroundColor: Colors.transparent,
      badgeColor: cs.secondaryContainer,
      errorColor: cs.error,
      authorStyle: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyStyle: tt.bodyMedium,
      timestampStyle: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      errorStyle: tt.bodyMedium?.copyWith(color: cs.error),
      hintStyle: theme.inputDecorationTheme.hintStyle ??
          tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
      buttonStyle: tt.labelLarge,
      // More usable baseline spacing.
      spacing: 8,
      avatarSize: 32,
      showAvatars: true,
      bubbleRadius: const BorderRadius.all(Radius.circular(12)),
      // Use the host app’s input decoration border when possible.
      composerShape: theme.inputDecorationTheme.border is OutlinedBorder
          ? theme.inputDecorationTheme.border as OutlinedBorder?
          : const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
      elevation: 0,
      composerMaxLines: 6,
    );
  }

  /// Neutral preset with minimal decoration suitable for dense layouts.
  factory GvlCommentsThemeData.neutral(BuildContext context) {
    final base = GvlCommentsThemeData.defaults(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Neutral: subtle, low contrast, clean.
    return base.copyWith(
      bubbleColor: cs.surfaceContainerHighest,
      bubbleAltColor: cs.surfaceContainer,
      elevation: 0,
      bubbleRadius: const BorderRadius.all(Radius.circular(12)),
      spacing: 8,
      avatarSize: 30,
      showAvatars: true,
    );
  }

  /// Compact preset that reduces spacing and typography sizes.
  factory GvlCommentsThemeData.compact(BuildContext context) {
    final base = GvlCommentsThemeData.defaults(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Compact: denser layout + smaller type. Designed for dashboards/admin.
    final body = base.bodyStyle ?? theme.textTheme.bodyMedium;
    final author = base.authorStyle ?? theme.textTheme.titleSmall;
    final ts = base.timestampStyle ?? theme.textTheme.bodySmall;

    return base.copyWith(
      spacing: 6,
      avatarSize: 24,
      bubbleRadius: const BorderRadius.all(Radius.circular(10)),
      elevation: 0,
      bubbleColor: cs.surfaceContainerHighest,
      bubbleAltColor: cs.surfaceContainer,
      authorStyle: author?.copyWith(
        fontSize: (author.fontSize ?? 13) - 1,
        letterSpacing: 0.2,
        fontWeight: FontWeight.w600,
      ),
      bodyStyle: body?.copyWith(
        fontSize: (body.fontSize ?? 14) - 1,
        height: 1.15,
      ),
      timestampStyle: ts?.copyWith(
        fontSize: (ts.fontSize ?? 12) - 1,
        color: cs.onSurfaceVariant.withAlpha(180),
      ),
    );
  }

  /// Card-like preset with subtle elevation and equal bubble colors.
  factory GvlCommentsThemeData.card(BuildContext context) {
    final base = GvlCommentsThemeData.defaults(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Card: clear separation from background (great on feeds).
    // Use surface for bubbles with elevation so it reads like “cards”.
    return base.copyWith(
      bubbleColor: cs.surface,
      bubbleAltColor: cs.surface,
      elevation: 2,
      bubbleRadius: const BorderRadius.all(Radius.circular(16)),
      spacing: 10,
      avatarSize: 32,
      showAvatars: true,
    );
  }

  /// Playful preset with rounded “bubble” styling.
  factory GvlCommentsThemeData.bubble(BuildContext context) {
    final base = GvlCommentsThemeData.defaults(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Bubble: playful + clearly differentiated mine vs others.
    // We keep opacity to avoid neon-looking UIs in some schemes.
    final mine = cs.primaryContainer.withAlpha(220);
    final other = cs.secondaryContainer.withAlpha(180);

    return base.copyWith(
      bubbleColor: mine,
      bubbleAltColor: other,
      elevation: 0,
      bubbleRadius: const BorderRadius.all(Radius.circular(20)),
      spacing: 10,
      avatarSize: 28,
      showAvatars: true,
      authorStyle: (base.authorStyle ?? theme.textTheme.titleSmall)?.copyWith(
        color: cs.onPrimaryContainer,
        fontWeight: FontWeight.w700,
      ),
      bodyStyle: (base.bodyStyle ?? theme.textTheme.bodyMedium)?.copyWith(
        color: cs.onPrimaryContainer,
        height: 1.25,
      ),
      timestampStyle:
          (base.timestampStyle ?? theme.textTheme.bodySmall)?.copyWith(
        color: cs.onSurfaceVariant.withAlpha(180),
      ),
    );
  }

  /// Combines two theme definitions, preferring non-null values from [other].
  GvlCommentsThemeData merge(GvlCommentsThemeData? other) {
    if (other == null) return this;
    return GvlCommentsThemeData(
      bubbleColor: other.bubbleColor ?? bubbleColor,
      bubbleAltColor: other.bubbleAltColor ?? bubbleAltColor,
      backgroundColor: other.backgroundColor ?? backgroundColor,
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
      showAvatars: other.showAvatars ?? showAvatars,
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
    Color? backgroundColor,
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
    bool? showAvatars,
    BorderRadius? bubbleRadius,
    OutlinedBorder? composerShape,
    double? elevation,
    int? composerMaxLines,
  }) {
    return GvlCommentsThemeData(
      bubbleColor: bubbleColor ?? this.bubbleColor,
      bubbleAltColor: bubbleAltColor ?? this.bubbleAltColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
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
      showAvatars: showAvatars ?? this.showAvatars,
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
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
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
      showAvatars: t < 0.5 ? showAvatars : other.showAvatars,
      bubbleRadius: BorderRadius.lerp(bubbleRadius, other.bubbleRadius, t),
      composerShape: t < 0.5 ? composerShape : other.composerShape,
      elevation: lerpDoubleNullable(elevation, other.elevation, t),
      composerMaxLines: t < 0.5 ? composerMaxLines : other.composerMaxLines,
    );
  }

  /// Helper to interpolate nullable doubles while preserving `null` when both
  /// inputs are `null`.
  static double? lerpDoubleNullable(double? a, double? b, double t) {
    if (a == null && b == null) return null;
    return Tween<double>(begin: a ?? b ?? 0, end: b ?? a ?? 0).transform(t);
  }
}

/// Wrapper for local theme overrides.
class GvlCommentsTheme extends InheritedWidget {
  /// Theme data applied to descendant comments widgets.
  final GvlCommentsThemeData data;

  const GvlCommentsTheme({
    super.key,
    required this.data,
    required super.child,
  });

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
  bool updateShouldNotify(GvlCommentsTheme oldWidget) => data != oldWidget.data;
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
