import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/document_chunk.dart';
import '../platform/native_bridge.dart';
import '../storage/local_database.dart';
import 'vector_search.dart';

class FileMatch {
  FileMatch(this.chunk, this.name, this.uri, this.score);
  final DocumentChunk chunk;
  final String name, uri;
  final double score;
}

class SearchEngine {
  SearchEngine(this.database);
  final LocalDatabase database;

  Future<List<FileMatch>> search(String query, String spec) async {
    final vector = await NativeBridge.embedQuery(query);
    final rows = await database.searchableChunks(spec);
    final scores = await compute(_scoreRows, (rows: rows, query: vector));
    final dense = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final lexical = await database.keywordMatches(query);
    final fused = <int, double>{};
    for (var i = 0; i < dense.length && i < 50; i++) {
      fused.update(dense[i].key, (v) => v + 1 / (60 + i),
          ifAbsent: () => 1 / (60 + i));
    }
    for (var i = 0; i < lexical.length; i++) {
      fused.update(lexical[i], (v) => v + 1 / (60 + i),
          ifAbsent: () => 1 / (60 + i));
    }
    final ranked = rows.where((r) => fused.containsKey(r['id'])).toList()
      ..sort((a, b) => fused[b['id']]!.compareTo(fused[a['id']]!));
    final seen = <int>{};
    return ranked.where((r) => seen.add(r['file_id'] as int)).take(10).map((r) =>
      FileMatch(DocumentChunk.fromRow(r), r['name'] as String,
          r['uri'] as String, fused[r['id']]!)).toList();
  }
}

Map<int, double> _scoreRows(({List<Map<String, Object?>> rows,
    List<double> query}) input) {
  final scores = <int, double>{};
  for (final row in input.rows) {
    final bytes = row['vector'] as Uint8List;
    final vector = LocalDatabase.unpack(bytes);
    if (vector.length == input.query.length) {
      scores[row['id'] as int] = cosineSimilarity(input.query, vector);
    }
  }
  return scores;
}
