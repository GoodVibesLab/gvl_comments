import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../comments_client.dart';
import '../../gvl_comments.dart';
import '../../l10n/gvl_comments_l10n.dart';

/// Simple, production-grade error view for the Comments UI.
///
/// - User-friendly message (l10n-first)
/// - Stable debug code (status + message when available)
/// - Retry button
/// - Optional "Details" panel (copy-friendly) to help support/debugging
class CommentsErrorView extends StatelessWidget {
  const CommentsErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    this.threadKey,
    this.compact = false,
    this.showDetails = true,
  });

  final Object error;
  final VoidCallback onRetry;

  /// Optional debug context shown in details.
  final String? threadKey;

  /// Smaller paddings/typography (for embedded layouts).
  final bool compact;

  /// Show/hide the details panel.
  final bool showDetails;

  @override
  Widget build(BuildContext context) {
    final l10n = GvlCommentsL10n.of(context);
    final t = GvlCommentsTheme.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final info = _CommentsErrorInfo.from(error);

    final spacing = (t.spacing ?? 8) * (compact ? 0.8 : 1.0);
    final titleStyle =
    (t.errorStyle ?? tt.titleMedium ?? const TextStyle()).copyWith(
      fontWeight: FontWeight.w700,
      color: t.errorColor ?? cs.error,
    );
    final bodyStyle = (tt.bodyMedium ?? const TextStyle()).copyWith(
      color: cs.onSurfaceVariant,
      height: 1.2,
    );

    final title = l10n?.errorTitle ?? 'Error';
    final retryLabel = l10n?.retryLabel ?? 'Retry';

    final userMessage = _pickUserMessage(
      l10n: l10n,
      fallback: l10n?.genericErrorLabel ?? 'Something went wrong.',
      info: info,
    );

    final codeLine = info.code; // stable “support code”
    final detailsText = _buildDetailsText(
      info: info,
      threadKey: threadKey,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: EdgeInsets.all(spacing * 2),
          child: Material(
            color: cs.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: cs.outlineVariant.withAlpha(160),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(spacing * 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: t.errorColor ?? cs.error,
                    size: compact ? 28 : 34,
                  ),
                  SizedBox(height: spacing),
                  Text(
                    title,
                    style: titleStyle,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing),
                  Text(
                    userMessage,
                    style: bodyStyle,
                    textAlign: TextAlign.center,
                  ),
                  if (codeLine != null) ...[
                    SizedBox(height: spacing),
                    _CodePill(
                      text: codeLine,
                      onCopy: () async {
                        await Clipboard.setData(ClipboardData(text: codeLine));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n?.copiedLabel ?? 'Copied',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  SizedBox(height: spacing * 1.5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: Text(retryLabel),
                      ),
                    ],
                  ),
                  if (showDetails) ...[
                    SizedBox(height: spacing),
                    _DetailsPanel(
                      title: l10n?.detailsLabel ?? 'Details',
                      details: detailsText,
                      compact: compact,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _pickUserMessage({
    required GvlCommentsL10n? l10n,
    required String fallback,
    required _CommentsErrorInfo info,
  }) {
    // If we can classify the error, provide a nicer message.
    if (info.kind == _ErrorKind.network) {
      return l10n?.networkErrorLabel ??
          'Network error. Check your connection and try again.';
    }
    if (info.kind == _ErrorKind.unauthorized) {
      return l10n?.unauthorizedErrorLabel ??
          'Authentication error. Please sign in again.';
    }
    if (info.kind == _ErrorKind.timeout) {
      return l10n?.timeoutErrorLabel ??
          'Request timed out. Please try again.';
    }
    // Fallback generic.
    return fallback;
  }

  static String _buildDetailsText({
    required _CommentsErrorInfo info,
    required String? threadKey,
  }) {
    final b = StringBuffer();
    if (info.code != null) b.writeln('code: ${info.code}');
    if (info.statusCode != null) b.writeln('status: ${info.statusCode}');
    if (threadKey != null && threadKey.trim().isNotEmpty) {
      b.writeln('threadKey: $threadKey');
    }
    if (info.message != null) b.writeln('message: ${info.message}');
    if (info.details != null) b.writeln('details: ${info.details}');
    b.writeln('error: ${info.raw}');
    return b.toString().trim();
  }
}

enum _ErrorKind { unknown, network, timeout, unauthorized }

class _CommentsErrorInfo {
  const _CommentsErrorInfo({
    required this.raw,
    this.statusCode,
    this.message,
    this.details,
    this.kind = _ErrorKind.unknown,
  });

  final Object raw;
  final int? statusCode;
  final String? message;
  final Object? details;
  final _ErrorKind kind;

  /// Stable support code (useful in customer support).
  String? get code {
    final sc = statusCode;
    final msg = message?.trim();
    if (sc == null && (msg == null || msg.isEmpty)) return null;
    if (sc != null && msg != null && msg.isNotEmpty) return '$sc:$msg';
    if (sc != null) return '$sc';
    return msg;
  }

  static _CommentsErrorInfo from(Object error) {
    // Your SDK exception type (best case).
    if (error is CommentsApiException) {
      final k = error.statusCode == 401 || error.statusCode == 403
          ? _ErrorKind.unauthorized
          : _ErrorKind.unknown;
      return _CommentsErrorInfo(
        raw: error,
        statusCode: error.statusCode,
        message: error.message,
        details: error.details,
        kind: k,
      );
    }

    final s = error.toString().toLowerCase();
    if (s.contains('timeout') || s.contains('timed out')) {
      return _CommentsErrorInfo(raw: error, kind: _ErrorKind.timeout);
    }
    if (s.contains('socket') ||
        s.contains('network') ||
        s.contains('connection') ||
        s.contains('failed host lookup')) {
      return _CommentsErrorInfo(raw: error, kind: _ErrorKind.network);
    }
    if (s.contains('401') || s.contains('403') || s.contains('unauthorized')) {
      return _CommentsErrorInfo(raw: error, kind: _ErrorKind.unauthorized);
    }

    return _CommentsErrorInfo(raw: error);
  }
}

class _CodePill extends StatelessWidget {
  const _CodePill({
    required this.text,
    required this.onCopy,
  });

  final String text;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withAlpha(160)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: onCopy,
            icon: Icon(Icons.copy, size: 16, color: cs.onSurfaceVariant),
            tooltip: GvlCommentsL10n.of(context)?.copyLabel ?? 'Copy',
          ),
        ],
      ),
    );
  }
}

class _DetailsPanel extends StatefulWidget {
  const _DetailsPanel({
    required this.title,
    required this.details,
    required this.compact,
  });

  final String title;
  final String details;
  final bool compact;

  @override
  State<_DetailsPanel> createState() => _DetailsPanelState();
}

class _DetailsPanelState extends State<_DetailsPanel> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final titleStyle = (tt.labelLarge ?? const TextStyle()).copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return Column(
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _open = !_open),
          icon: Icon(_open ? Icons.expand_less : Icons.expand_more),
          label: Text(widget.title, style: titleStyle),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState:
          _open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Container(
            width: double.infinity,
            padding: EdgeInsets.all(widget.compact ? 10 : 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant.withAlpha(160)),
            ),
            child: SelectableText(
              widget.details,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.2,
              ),
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }
}