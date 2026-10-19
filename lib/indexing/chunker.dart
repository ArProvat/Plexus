import '../storage/local_database.dart';

class ExtractedSegment {
  const ExtractedSegment(this.text, {this.page, this.slide, this.section});
  final String text;
  final int? page, slide;
  final String? section;
}

/// Keeps offsets in Dart UTF-16 code units, matching String.substring.
List<ChunkDraft> chunkSegments(List<ExtractedSegment> segments) {
  final chunks = <ChunkDraft>[];
  for (final segment in segments) {
    final text = segment.text;
    var start = 0;
    while (start < text.length) {
      while (start < text.length && text[start].trim().isEmpty) { start++; }
      if (start >= text.length) break;
      var end = (start + 900).clamp(0, text.length);
      if (end < text.length) {
        final candidate = text.lastIndexOf(RegExp(r'[.!?।\n]'), end);
        if (candidate > start + 450) end = candidate + 1;
        else {
          final space = text.lastIndexOf(RegExp(r'\s'), end);
          if (space > start + 450) end = space;
        }
      }
      final piece = text.substring(start, end);
      if (piece.trim().isNotEmpty) {
        chunks.add(ChunkDraft(piece, page: segment.page, slide: segment.slide,
          charStart: segment.page == null && segment.slide == null ? start : null,
          charEnd: segment.page == null && segment.slide == null ? end : null,
          section: segment.section));
      }
      if (end == text.length) break;
      start = (end - 100).clamp(start + 1, end);
    }
  }
  return chunks;
}
