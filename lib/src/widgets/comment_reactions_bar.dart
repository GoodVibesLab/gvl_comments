import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';

/// Small, Messenger-like reactions bar displayed under a comment bubble.
///
/// The bar supports:
/// - Tap to toggle a reaction (defaults to "like" when no reaction exists).
/// - Long-press to open a floating overlay reaction picker.
/// - Showing aggregated counts (from the backend) and the viewer reaction.
///
/// The widget is dependency-free and designed to be embedded inside the
/// default comment item, or in custom builders.
class CommentReactionsBar extends StatelessWidget {
  /// Comment holding the current reaction state.
  ///
  /// The backend populates:
  /// - [CommentModel.viewerReaction]
  /// - [CommentModel.reactionCounts]
  /// - [CommentModel.reactionTotal]
  final CommentModel comment;

  /// Called when the user selects a reaction.
  ///
  /// Pass `null` to remove the current reaction.
  final ValueChanged<String?> onReact;

  /// Whether interactions are enabled.
  ///
  /// Disable while a comment is being sent or when the host UI wants to
  /// prevent changes.
  final bool enabled;

  /// Visual density tweak.
  final double spacing;

  /// Creates a reactions bar for a comment.
  const CommentReactionsBar({
    super.key,
    required this.comment,
    required this.onReact,
    this.enabled = true,
    this.spacing = 6,
  });

  @override
  Widget build(BuildContext context) {
    final counts = comment.reactionCounts;
    final total = comment.reactionTotal;
    final viewer = comment.viewerReaction;

    // Hide entirely when there is nothing to show.
    if (total <= 0 && (viewer == null || viewer.isEmpty)) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final bg = cs.surfaceContainerHigh;
    final border = cs.outlineVariant.withAlpha(120);

    // Display up to 3 top reactions (by count).
    final top = _topReactions(counts, max: 3);

    final labelStyle = (textTheme.labelSmall ?? const TextStyle(fontSize: 11))
        .copyWith(color: cs.onSurfaceVariant.withAlpha(220));

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: bg,
        shape: StadiumBorder(side: BorderSide(color: border)),
        child: _ReactionBarGesture(
          enabled: enabled,
          currentReaction: viewer,
          onTapToggle: () {
            // Messenger-like behavior:
            // - if already reacted -> remove
            // - else -> like
            if (viewer != null && viewer.isNotEmpty) {
              onReact(null);
            } else {
              onReact(_ReactionCatalog.like.id);
            }
          },
          onPick: (picked) {
            if (picked == null) return;
            // If the user picked the same reaction again, treat as toggle off.
            if (picked == viewer) {
              onReact(null);
            } else {
              onReact(picked);
            }
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing + 2, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Emoji cluster
                if (top.isNotEmpty) ...[
                  for (final r in top) ...[
                    Text(
                      _ReactionCatalog.emojiFor(r.id),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 2),
                  ],
                ],

                // Total count
                if (total > 0) ...[
                  if (top.isNotEmpty) const SizedBox(width: 2),
                  Text('$total', style: labelStyle),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Internal representation of a reaction with stable identifier and emoji.
class _ReactionOption {
  final String id;
  final String emoji;
  final String label;

  const _ReactionOption({
    required this.id,
    required this.emoji,
    required this.label,
  });
}

/// Fixed reaction catalog (v1).
///
/// The identifiers are stable and are also stored in the database.
class _ReactionCatalog {
  static const _ReactionOption like =
      _ReactionOption(id: 'like', emoji: '👍', label: 'Like');
  static const _ReactionOption love =
      _ReactionOption(id: 'love', emoji: '❤️', label: 'Love');
  static const _ReactionOption laugh =
      _ReactionOption(id: 'laugh', emoji: '😂', label: 'Haha');
  static const _ReactionOption wow =
      _ReactionOption(id: 'wow', emoji: '😮', label: 'Wow');
  static const _ReactionOption sad =
      _ReactionOption(id: 'sad', emoji: '😢', label: 'Sad');
  static const _ReactionOption angry =
      _ReactionOption(id: 'angry', emoji: '😡', label: 'Angry');

  static const List<_ReactionOption> all = <_ReactionOption>[
    like,
    love,
    laugh,
    wow,
    sad,
    angry,
  ];

  static String emojiFor(String id) {
    for (final r in all) {
      if (r.id == id) return r.emoji;
    }
    return '👍';
  }
}

class _ReactionCount {
  final String id;
  final int count;

  const _ReactionCount(this.id, this.count);
}

List<_ReactionCount> _topReactions(Map<String, int> counts, {int max = 3}) {
  final items = <_ReactionCount>[];
  counts.forEach((key, value) {
    final v = value;
    if (v > 0) items.add(_ReactionCount(key, v));
  });

  items.sort((a, b) {
    final c = b.count.compareTo(a.count);
    if (c != 0) return c;
    return a.id.compareTo(b.id);
  });

  if (items.length <= max) return items;
  return items.sublist(0, max);
}

/// Opens the reaction picker as a floating overlay (Messenger-like).
///
/// Returns the selected reaction id (e.g. "like") or `null` if dismissed.
///
/// Provide [anchor] in global coordinates (e.g. from `TapDownDetails` or
/// `LongPressStartDetails`). The overlay will appear slightly above it.
Future<String?> showCommentReactionPicker(
  BuildContext context, {
  required Offset anchor,
  String? currentReaction,
}) {
  return _showOverlayPicker(context,
      anchor: anchor, currentReaction: currentReaction);
}

Future<String?> _showOverlayPicker(
  BuildContext context, {
  required Offset anchor,
  String? currentReaction,
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);

  final cs = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;

  final completer = Completer<String?>();
  late OverlayEntry entry;

  void close([String? value]) {
    if (!completer.isCompleted) completer.complete(value);
    entry.remove();
  }

  // Layout constants
  const double barHeight = 44;
  const double horizontalPadding = 10;
  const double emojiSize = 26;
  const double gap = 10;

  // Compute position (clamped inside the screen)
  final media = MediaQuery.of(context);
  final size = media.size;
  final safeTop = media.padding.top;
  final safeBottom = media.padding.bottom;

  final int n = _ReactionCatalog.all.length;
  final double barWidth =
      horizontalPadding * 2 + (emojiSize * n) + (gap * (n - 1));

  // Try to center the bar around the anchor.x
  double left = anchor.dx - barWidth / 2;
  left = left.clamp(12.0, size.width - barWidth - 12.0);

  // Show above the anchor by default
  double top = anchor.dy - barHeight - 14;

  // If too high, show below
  if (top < safeTop + 12) {
    top = anchor.dy + 14;
  }

  // If still overflows bottom, clamp
  top = top.clamp(safeTop + 12.0, size.height - safeBottom - barHeight - 12.0);

  entry = OverlayEntry(
    builder: (ctx) {
      return _ReactionOverlay(
        left: left,
        top: top,
        width: barWidth,
        height: barHeight,
        colorScheme: cs,
        textTheme: textTheme,
        currentReaction: currentReaction,
        onDismiss: () => close(null),
        onPick: (id) => close(id),
      );
    },
  );

  overlay.insert(entry);
  return completer.future;
}

class _ReactionBarGesture extends StatefulWidget {
  final bool enabled;
  final String? currentReaction;
  final VoidCallback onTapToggle;
  final ValueChanged<String?> onPick;
  final Widget child;

  const _ReactionBarGesture({
    required this.enabled,
    required this.currentReaction,
    required this.onTapToggle,
    required this.onPick,
    required this.child,
  });

  @override
  State<_ReactionBarGesture> createState() => _ReactionBarGestureState();
}

class _ReactionBarGestureState extends State<_ReactionBarGesture> {
  Offset? _lastGlobal;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => _lastGlobal = d.globalPosition,
      onLongPressStart: (d) => _lastGlobal = d.globalPosition,
      child: InkResponse(
        radius: 999,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        onTap: widget.enabled ? widget.onTapToggle : null,
        onLongPress: !widget.enabled
            ? null
            : () async {
                HapticFeedback.mediumImpact();

                final anchor = _lastGlobal ??
                    Offset(MediaQuery.of(context).size.width / 2,
                        MediaQuery.of(context).size.height / 2);
                final picked = await showCommentReactionPicker(
                  context,
                  anchor: anchor,
                  currentReaction: widget.currentReaction,
                );
                widget.onPick(picked);
              },
        child: widget.child,
      ),
    );
  }
}

class _ReactionOverlay extends StatefulWidget {
  final double left;
  final double top;
  final double width;
  final double height;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final String? currentReaction;
  final VoidCallback onDismiss;
  final ValueChanged<String> onPick;

  const _ReactionOverlay({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.colorScheme,
    required this.textTheme,
    required this.currentReaction,
    required this.onDismiss,
    required this.onPick,
  });

  @override
  State<_ReactionOverlay> createState() => _ReactionOverlayState();
}

class _ReactionOverlayState extends State<_ReactionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      reverseDuration: const Duration(milliseconds: 120),
    );

    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutBack),
    );
    _slide =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOut),
    );

    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (!_c.isAnimating) {
      await _c.reverse();
    }
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;

    final bg = cs.surface;
    final border = cs.outlineVariant.withAlpha(130);
    final shadow = cs.shadow.withAlpha(40);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Tap outside to dismiss
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: const SizedBox.expand(),
            ),
          ),

          Positioned(
            left: widget.left,
            top: widget.top,
            width: widget.width,
            height: widget.height,
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: ScaleTransition(
                  scale: _scale,
                  alignment: Alignment.center,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: border),
                      boxShadow: [
                        BoxShadow(
                          color: shadow,
                          blurRadius: 16,
                          spreadRadius: 2,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final r in _ReactionCatalog.all)
                            _EmojiButton(
                              emoji: r.emoji,
                              isSelected: widget.currentReaction == r.id,
                              onTap: () => widget.onPick(r.id),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiButton extends StatefulWidget {
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _EmojiButton({
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_EmojiButton> createState() => _EmojiButtonState();
}

class _EmojiButtonState extends State<_EmojiButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _c.forward(),
      onTapCancel: () => _c.reverse(),
      onTapUp: (_) {
        _c.reverse();
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: widget.isSelected
              ? BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withAlpha(220),
                  borderRadius: BorderRadius.circular(6),
                )
              : null,
          child: Text(
            widget.emoji,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }
}
