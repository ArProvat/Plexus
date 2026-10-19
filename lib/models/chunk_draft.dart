class ChunkDraft {
  ChunkDraft(this.text,
      {this.page,
      this.slide,
      this.charStart,
      this.charEnd,
      this.section,
      this.vector});
  final String text;
  final int? page, slide, charStart, charEnd;
  final String? section;
  List<double>? vector;
}
