import 'package:flutter/material.dart';

import '../domain/local_search_query.dart';

class HighlightedSearchText extends StatelessWidget {
  const HighlightedSearchText(
    this.text, {
    required this.query,
    this.style,
    this.maxLines,
    this.overflow,
    super.key,
  });

  final String text;
  final String query;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final ranges = searchHighlightRanges(text, query);
    if (ranges.isEmpty) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }
    final base = style ?? DefaultTextStyle.of(context).style;
    final highlight = base.copyWith(
      color: Theme.of(context).colorScheme.onTertiaryContainer,
      backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
      fontWeight: FontWeight.w800,
    );
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final range in ranges) {
      if (range.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, range.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(range.start, range.end),
          style: highlight,
        ),
      );
      cursor = range.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
