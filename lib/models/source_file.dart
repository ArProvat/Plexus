class SourceFile {
  const SourceFile(
      {required this.id,
      required this.uri,
      required this.name,
      required this.mime,
      required this.status,
      this.error,
      this.activeRevision = 0,
      this.folderUri,
      this.jobStage,
      this.progress = 0});

  final int id;
  final String uri, name, mime, status;
  final String? error, folderUri;
  final String? jobStage;
  final int progress;
  final int activeRevision;

  factory SourceFile.fromRow(Map<String, Object?> row) => SourceFile(
        id: row['id'] as int,
        uri: row['uri'] as String,
        name: row['name'] as String,
        mime: row['mime'] as String,
        status: row['status'] as String,
        error: row['error'] as String?,
        activeRevision: row['active_revision'] as int,
        folderUri: row['folder_uri'] as String?,
        jobStage: row['job_stage'] as String?,
        progress: row['job_progress'] as int? ?? 0,
      );
}
