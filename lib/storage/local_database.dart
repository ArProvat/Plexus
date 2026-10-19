import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import '../models/chunk_draft.dart';
import '../models/document_chunk.dart';
import '../models/source_file.dart';

class LocalDatabase {
  LocalDatabase._();
  static final instance = LocalDatabase._();
  Future<Database>? _opening;

  Future<Database> get db => _opening ??= _open();

  Future<Database> _open() async =>
      openDatabase('${await getDatabasesPath()}/pocketsearch.db',
          version: 1,
          onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
          onCreate: (db, _) async {
            await db.execute(
                'CREATE TABLE files (id INTEGER PRIMARY KEY, uri TEXT NOT NULL UNIQUE, '
                'folder_uri TEXT, name TEXT NOT NULL, mime TEXT NOT NULL, size INTEGER, '
                'status TEXT NOT NULL, error TEXT, active_revision INTEGER NOT NULL DEFAULT 0)');
            await db.execute(
                'CREATE TABLE chunks (id INTEGER PRIMARY KEY, file_id INTEGER NOT NULL '
                'REFERENCES files(id) ON DELETE CASCADE, revision INTEGER NOT NULL, sequence INTEGER NOT NULL, '
                'text TEXT NOT NULL, page INTEGER, slide INTEGER, char_start INTEGER, char_end INTEGER, '
                'section TEXT, vector BLOB, embedding_spec TEXT, UNIQUE(file_id, revision, sequence))');
            await db.execute(
                'CREATE TABLE index_jobs (file_id INTEGER PRIMARY KEY REFERENCES files(id) '
                'ON DELETE CASCADE, stage TEXT NOT NULL, progress INTEGER NOT NULL DEFAULT 0, '
                'retries INTEGER NOT NULL DEFAULT 0, error TEXT)');
            await db.execute(
                'CREATE VIRTUAL TABLE chunk_fts USING fts4(text, tokenize=unicode61)');
          });

  Future<int> register(Map<String, Object?> item, {String? folderUri}) async {
    final database = await db;
    await database.insert(
        'files',
        {
          'uri': item['uri'],
          'folder_uri': folderUri,
          'name': item['name'],
          'mime': item['mime'] ?? 'application/octet-stream',
          'size': item['size'],
          'status': 'queued',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore);
    final rows = await database.query('files',
        columns: ['id'], where: 'uri = ?', whereArgs: [item['uri']], limit: 1);
    final id = rows.first['id'] as int;
    await database.insert('index_jobs', {'file_id': id, 'stage': 'queued'},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    return id;
  }

  Future<List<SourceFile>> files() async => (await (await db).rawQuery(
          'SELECT f.*, j.stage AS job_stage, j.progress AS job_progress FROM files f '
          'LEFT JOIN index_jobs j ON j.file_id = f.id ORDER BY f.name COLLATE NOCASE'))
      .map(SourceFile.fromRow)
      .toList();

  Future<SourceFile?> file(int id) async {
    final rows = await (await db).rawQuery(
        'SELECT f.*, j.stage AS job_stage, '
        'j.progress AS job_progress FROM files f LEFT JOIN index_jobs j ON j.file_id = f.id '
        'WHERE f.id = ?',
        [id]);
    return rows.isEmpty ? null : SourceFile.fromRow(rows.first);
  }

  Future<void> status(int id, String stage,
      {String? error, int? progress}) async {
    final database = await db;
    await database.transaction((tx) async {
      await tx.rawUpdate(
          'UPDATE files SET status = CASE WHEN active_revision = 0 '
          "OR ? = 'inaccessible' THEN ? ELSE status END, error = ? WHERE id = ?",
          [stage, stage, error, id]);
      await tx.update(
          'index_jobs',
          {
            'stage': stage,
            'error': error,
            if (progress != null) 'progress': progress
          },
          where: 'file_id = ?',
          whereArgs: [id]);
    });
  }

  Future<void> publish(
      int fileId, List<ChunkDraft> drafts, String? spec) async {
    final database = await db;
    await database.transaction((tx) async {
      final old = (await tx.query('files',
              columns: ['active_revision'],
              where: 'id = ?',
              whereArgs: [fileId]))
          .first['active_revision'] as int;
      final revision = old + 1;
      for (var i = 0; i < drafts.length; i++) {
        final chunk = drafts[i];
        final id = await tx.insert('chunks', {
          'file_id': fileId,
          'revision': revision,
          'sequence': i,
          'text': chunk.text,
          'page': chunk.page,
          'slide': chunk.slide,
          'char_start': chunk.charStart,
          'char_end': chunk.charEnd,
          'section': chunk.section,
          'vector': chunk.vector == null ? null : _pack(chunk.vector!),
          'embedding_spec': chunk.vector == null ? null : spec
        });
        await tx.insert('chunk_fts', {'rowid': id, 'text': chunk.text});
      }
      final oldIds = await tx.query('chunks',
          columns: ['id'],
          where: 'file_id = ? AND revision <> ?',
          whereArgs: [fileId, revision]);
      for (final row in oldIds) {
        await tx
            .delete('chunk_fts', where: 'rowid = ?', whereArgs: [row['id']]);
      }
      await tx.delete('chunks',
          where: 'file_id = ? AND revision <> ?',
          whereArgs: [fileId, revision]);
      await tx.update(
          'files',
          {
            'active_revision': revision,
            'status': spec == null ? 'text_ready' : 'searchable',
            'error': null
          },
          where: 'id = ?',
          whereArgs: [fileId]);
      await tx.update(
          'index_jobs',
          {
            'stage': spec == null ? 'text_ready' : 'searchable',
            'progress': 100,
            'error': null
          },
          where: 'file_id = ?',
          whereArgs: [fileId]);
    });
  }

  Future<
      List<DocumentChunk>> chunks(int fileId) async => (await (await db).rawQuery(
          'SELECT c.* FROM chunks c JOIN files f ON f.id = c.file_id '
          'WHERE c.file_id = ? AND c.revision = f.active_revision ORDER BY c.sequence',
          [fileId]))
      .map(DocumentChunk.fromRow)
      .toList();

  Future<List<Map<String, Object?>>> searchableChunks(String spec) async =>
      (await db).rawQuery(
          'SELECT c.*, f.name, f.uri FROM chunks c JOIN files f ON f.id = c.file_id '
          "WHERE f.status = 'searchable' AND c.revision = f.active_revision "
          'AND c.vector IS NOT NULL AND c.embedding_spec = ?',
          [spec]);

  Future<List<int>> keywordMatches(String query) async {
    if (query.runes.any((rune) => rune > 127)) {
      final rows = await (await db).rawQuery(
          'SELECT c.id FROM chunks c '
          'JOIN files f ON f.id = c.file_id WHERE instr(c.text, ?) > 0 '
          "AND f.status = 'searchable' AND c.revision = f.active_revision LIMIT 50",
          [query]);
      return rows.map((row) => row['id'] as int).toList();
    }
    final terms = RegExp(r'[\p{L}\p{M}\p{N}]+', unicode: true)
        .allMatches(query)
        .map((m) => '"${m.group(0)}"')
        .toList();
    if (terms.isEmpty) return [];
    final rows = await (await db).rawQuery(
        'SELECT chunk_fts.rowid FROM chunk_fts '
        'JOIN chunks c ON c.id = chunk_fts.rowid JOIN files f ON f.id = c.file_id '
        "WHERE chunk_fts MATCH ? AND f.status = 'searchable' "
        'AND c.revision = f.active_revision LIMIT 50',
        [terms.join(' OR ')]);
    return rows.map((row) => row['rowid'] as int).toList();
  }

  Future<void> remove(int fileId) async {
    final database = await db;
    await database.transaction((tx) async {
      final ids = await tx.query('chunks',
          columns: ['id'], where: 'file_id = ?', whereArgs: [fileId]);
      for (final row in ids) {
        await tx
            .delete('chunk_fts', where: 'rowid = ?', whereArgs: [row['id']]);
      }
      await tx.delete('files', where: 'id = ?', whereArgs: [fileId]);
    });
  }

  static Uint8List _pack(List<double> values) {
    final bytes = ByteData(values.length * 4);
    for (var i = 0; i < values.length; i++) {
      bytes.setFloat32(i * 4, values[i], Endian.little);
    }
    return bytes.buffer.asUint8List();
  }

  static List<double> unpack(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    return List.generate(
        bytes.length ~/ 4, (i) => data.getFloat32(i * 4, Endian.little));
  }
}
