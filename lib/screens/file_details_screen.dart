import 'package:flutter/material.dart';
import '../indexing/indexer.dart';
import '../models/document_chunk.dart';
import '../models/source_file.dart';
import '../platform/native_bridge.dart';
import '../storage/local_database.dart';

class FileDetailsScreen extends StatefulWidget {
  const FileDetailsScreen({super.key, required this.fileId});
  final int fileId;
  @override
  State<FileDetailsScreen> createState() => _FileDetailsScreenState();
}

class _FileDetailsScreenState extends State<FileDetailsScreen> {
  SourceFile? _file;
  List<DocumentChunk> _chunks = [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final file = await LocalDatabase.instance.file(widget.fileId);
    final chunks = await LocalDatabase.instance.chunks(widget.fileId);
    if (mounted)
      setState(() {
        _file = file;
        _chunks = chunks;
      });
  }

  Future<void> _retry() async {
    if (_file == null) return;
    setState(() => _busy = true);
    final indexer = Indexer(LocalDatabase.instance);
    if (_file!.status == 'text_ready' &&
        (await NativeBridge.modelStatus())['ready'] == true) {
      await indexer.embedPrepared(_file!, _refresh);
    } else {
      await indexer.process(_file!, _refresh);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _open() async {
    try {
      await NativeBridge.openSource(_file!.uri);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_file?.name ?? 'Document')),
        body: _file == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                Text(
                    'Status: ${(_file!.jobStage ?? _file!.status).replaceAll('_', ' ')}'),
                if (_file!.error != null)
                  Text(_file!.error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                if (_error != null) Text(_error!),
                Text('${_chunks.length} passages'),
                Wrap(spacing: 8, children: [
                  TextButton(
                      onPressed: _open, child: const Text('Open original')),
                  TextButton(
                      onPressed: _busy ? null : _retry,
                      child: const Text('Retry')),
                  TextButton(
                      onPressed: () async {
                        await LocalDatabase.instance.remove(widget.fileId);
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text('Remove')),
                ]),
                if (_busy) const LinearProgressIndicator(),
                for (final chunk in _chunks)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(chunk.location,
                                    style:
                                        Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 6),
                                Text(chunk.text),
                              ]))),
              ]),
      );
}
