import 'dart:math';

double cosineSimilarity(List<double> a, List<double> b) {
  if (a.isEmpty || a.length != b.length) {
    throw ArgumentError('Vectors must be nonempty and have equal dimensions.');
  }
  var dot = 0.0, aa = 0.0, bb = 0.0;
  for (var i = 0; i < a.length; i++) {
    if (!a[i].isFinite || !b[i].isFinite) {
      throw ArgumentError('Vectors must contain finite numbers.');
    }
    dot += a[i] * b[i];
    aa += a[i] * a[i];
    bb += b[i] * b[i];
  }
  if (aa == 0 || bb == 0) throw ArgumentError('Zero vectors are invalid.');
  return (dot / sqrt(aa * bb)).clamp(-1.0, 1.0).toDouble();
}
