class DocumentChunk {
  const DocumentChunk({required this.id, required this.fileId,
    required this.sequence, required this.text, required this.revision,
    this.page, this.slide, this.charStart, this.charEnd, this.section});

  final int id, fileId, sequence, revision;
  final String text;
  final int? page, slide, charStart, charEnd;
  final String? section;

  String get location => page != null ? 'Page $page' : slide != null
      ? 'Slide $slide' : charStart != null
      ? 'Characters $charStart–$charEnd' : section ?? 'Passage ${sequence + 1}';

  factory DocumentChunk.fromRow(Map<String, Object?> row) => DocumentChunk(
    id: row['id'] as int, fileId: row['file_id'] as int,
    revision: row['revision'] as int, sequence: row['sequence'] as int,
    text: row['text'] as String, page: row['page'] as int?,
    slide: row['slide'] as int?, charStart: row['char_start'] as int?,
    charEnd: row['char_end'] as int?, section: row['section'] as String?,
  );
}
