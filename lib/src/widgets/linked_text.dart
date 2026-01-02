// lib/widgets/linked_text.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Regex used to detect urls + emails.
  final RegExp? pattern;

  const LinkedText(
    this.text, {
    super.key,
    this.style,
    this.linkStyle,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.pattern,
  });

  @override
  State<LinkedText> createState() => _LinkedTextState();
}

class _LinkedTextState extends State<LinkedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Important: rebuild clears old recognizers to avoid leaks.
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final regex = widget.pattern ??
        RegExp(
          r'((https?:\/\/)?(www\.)?([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}([\/\w\-.?%&=+#]*)?|[\w.\-]+@[\w.\-]+\.\w+)',
          caseSensitive: false,
        );

    final spans = <InlineSpan>[];
    final text = widget.text;

    if (text.isNotEmpty) {
      int start = 0;
      for (final match in regex.allMatches(text)) {
        if (match.start > start) {
          spans.add(TextSpan(text: text.substring(start, match.start)));
        }

        final raw = match.group(0) ?? '';
        final recognizer = TapGestureRecognizer()..onTap = () => _open(raw);
        _recognizers.add(recognizer);

        spans.add(
          TextSpan(
            text: raw,
            style: (widget.linkStyle ??
                (widget.style ?? const TextStyle()).copyWith(
                  decoration: TextDecoration.underline,
                )),
            recognizer: recognizer,
          ),
        );

        start = match.end;
      }

      if (start < text.length) {
        spans.add(TextSpan(text: text.substring(start)));
      }
    }

    return RichText(
      textAlign: widget.textAlign ?? TextAlign.start,
      maxLines: widget.maxLines,
      overflow: widget.overflow ?? TextOverflow.clip,
      text: TextSpan(
        style: widget.style ?? DefaultTextStyle.of(context).style,
        children: spans,
      ),
    );
  }

  Future<void> _open(String raw) async {
    var link = raw.trim();
    if (link.isEmpty) return;

    final lower = link.toLowerCase();
    if (!lower.startsWith('http')) {
      if (link.contains('@')) {
        link = 'mailto:$link';
      } else {
        link = 'https://$link';
      }
    }

    final uri = Uri.tryParse(link);
    if (uri == null) return;

    // Best-effort, no throw.
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
