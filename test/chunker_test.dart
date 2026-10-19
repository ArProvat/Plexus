import 'package:flutter_test/flutter_test.dart';
import 'package:pocketsearch/indexing/chunker.dart';

void main() {
  test('PDF chunks stay on their physical pages', () {
    final chunks = chunkSegments([
      const ExtractedSegment('First page text.', page: 1),
      const ExtractedSegment('Second page text.', page: 2),
    ]);
    expect(chunks.map((c) => c.page), [1, 2]);
    expect(chunks.every((c) => c.text.trim().isNotEmpty), isTrue);
  });

  test('text offsets recover original Bengali passages', () {
    final text =
        List.filled(80, 'বাংলা নথিতে গুরুত্বপূর্ণ তথ্য আছে।').join('\n');
    final chunks = chunkSegments([ExtractedSegment(text)]);
    expect(chunks.length, greaterThan(1));
    for (final chunk in chunks) {
      expect(text.substring(chunk.charStart!, chunk.charEnd!), chunk.text);
      expect(chunk.text.length, lessThanOrEqualTo(900));
    }
  });

  test('Word passages keep paragraph identity', () {
    final chunks = chunkSegments([
      const ExtractedSegment('Project planning notes', section: 'Paragraph 3'),
    ]);
    expect(chunks.single.section, 'Paragraph 3');
    expect(chunks.single.charStart, isNull);
  });
}
