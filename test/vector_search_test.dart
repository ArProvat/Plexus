import 'package:flutter_test/flutter_test.dart';
import 'package:pocketsearch/search/vector_search.dart';

void main() {
  test('cosine is invariant to magnitude and rejects incompatible vectors', () {
    expect(cosineSimilarity([2, 0], [5, 0]), closeTo(1, 1e-9));
    expect(cosineSimilarity([1, 0], [0, 1]), 0);
    expect(cosineSimilarity([1, 0], [-1, 0]), -1);
    expect(() => cosineSimilarity([1], [1, 2]), throwsArgumentError);
    expect(() => cosineSimilarity([0], [1]), throwsArgumentError);
    expect(() => cosineSimilarity([double.nan], [1]), throwsArgumentError);
  });
}
