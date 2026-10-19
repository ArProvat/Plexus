import 'package:flutter/services.dart';
import '../models/chunk_draft.dart';
import '../models/source_file.dart';
import '../platform/native_bridge.dart';
import '../storage/local_database.dart';
import 'chunker.dart';

class Indexer {
  Indexer(this.database);
  final LocalDatabase database;

  Future<void> process(SourceFile file, void Function() changed) async {
    try {
      await database.status(file.id, 'extracting');
      changed();
      final extension = file.name.toLowerCase().split('.').last;
      final segments = <ExtractedSegment>[];
      if (extension == 'pdf') {
        try {
          final pages = await NativeBridge.pdfPageCount(file.uri);
          for (var page = 1; page <= pages; page++) {
            segments.add(ExtractedSegment(
                await NativeBridge.extractPdfPage(file.uri, page),
                page: page));
            await database.status(file.id, 'extracting',
                progress: (page * 50 ~/ pages));
            changed();
          }
        } finally {
          await NativeBridge.closePdf();
        }
      } else if (extension == 'txt' || extension == 'md') {
        segments.add(ExtractedSegment(await NativeBridge.readText(file.uri)));
      } else if (['doc', 'docx', 'ppt', 'pptx'].contains(extension)) {
        for (final row
            in await NativeBridge.extractOffice(file.uri, file.name)) {
          segments.add(ExtractedSegment(row['text'] as String,
              slide: row['slide'] as int?, section: row['section'] as String?));
        }
      } else {
        throw const FormatException('Unsupported document format');
      }
      if (segments.every((s) => s.text.trim().isEmpty)) {
        throw const FormatException(
            'No selectable text found; this file may need OCR');
      }
      await database.status(file.id, 'chunking');
      changed();
      final chunks = chunkSegments(segments);
      if (chunks.isEmpty)
        throw const FormatException('No passages were extracted');
      await _embedAndPublish(file, chunks, changed, requireModel: false);
    } catch (error) {
      await _fail(file.id, error, changed);
    }
  }

  Future<void> embedPrepared(SourceFile file, void Function() changed) async {
    try {
      final saved = await database.chunks(file.id);
      if (saved.isEmpty) return;
      final chunks = saved
          .map((c) => ChunkDraft(c.text,
              page: c.page,
              slide: c.slide,
              charStart: c.charStart,
              charEnd: c.charEnd,
              section: c.section))
          .toList();
      await _embedAndPublish(file, chunks, changed, requireModel: true);
    } catch (error) {
      await _fail(file.id, error, changed);
    }
  }

  Future<void> _embedAndPublish(
      SourceFile file, List<ChunkDraft> chunks, void Function() changed,
      {required bool requireModel}) async {
    String? spec;
    try {
      final model = await NativeBridge.initializeEmbedding();
      spec = model['model'] as String;
    } on PlatformException catch (error) {
      if (requireModel || !(error.message ?? '').contains('model required'))
        rethrow;
    }
    if (spec != null) {
      await database.status(file.id, 'embedding');
      changed();
      for (var i = 0; i < chunks.length; i += 8) {
        final batch = chunks.skip(i).take(8).toList();
        final vectors = await NativeBridge.embedDocuments(
            batch.map((c) => '${file.name}\n${c.text}').toList());
        if (vectors.length != batch.length ||
            vectors.any((v) => v.length != 256)) {
          throw StateError('EmbeddingGemma returned incompatible vectors');
        }
        for (var j = 0; j < batch.length; j++) {
          batch[j].vector = vectors[j];
        }
        await database.status(file.id, 'embedding',
            progress: 50 + ((i + batch.length) * 50 ~/ chunks.length));
        changed();
      }
    }
    await database.publish(file.id, chunks, spec);
    changed();
  }

  Future<void> _fail(int fileId, Object error, void Function() changed) async {
    final message = error.toString();
    await database.status(
        fileId,
        message.contains('SecurityException') || message.contains('ACCESS')
            ? 'inaccessible'
            : 'failed',
        error: message);
    changed();
  }
}
