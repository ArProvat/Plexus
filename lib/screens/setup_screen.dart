import 'package:flutter/material.dart';
import '../indexing/indexer.dart';
import '../models/source_file.dart';
import '../platform/native_bridge.dart';
import '../storage/local_database.dart';
import 'file_details_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  List<SourceFile> _files = [];
  bool _busy = false, _modelReady = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _refresh();
    _resume();
  }

  Future<void> _resume() async {
    final files = await LocalDatabase.instance.files();
    final pending = files
        .where((f) => {'queued', 'extracting', 'chunking', 'embedding'}
            .contains(f.jobStage))
        .toList();
    if (pending.isEmpty) return;
    if (mounted) setState(() => _busy = true);
    for (final file in pending) {
      final indexer = Indexer(LocalDatabase.instance);
      if (file.status == 'text_ready' && file.jobStage == 'embedding') {
        await indexer.embedPrepared(file, _refresh);
      } else {
        await indexer.process(file, _refresh);
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _refresh() async {
    try {
      final files = await LocalDatabase.instance.files();
      final model = await NativeBridge.modelStatus();
      if (mounted)
        setState(() {
          _files = files;
          _modelReady = model['ready'] == true;
        });
    } catch (e) {
      if (mounted) setState(() => _message = '$e');
    }
  }

  Future<void> _download() async {
    setState(() {
      _busy = true;
      _message = 'Downloading EmbeddingGemma…';
    });
    try {
      await NativeBridge.downloadModel();
      final prepared = (await LocalDatabase.instance.files())
          .where((file) => file.status == 'text_ready')
          .toList();
      if (mounted)
        setState(() => _message =
            'Model ready. Embedding ${prepared.length} prepared files…');
      for (final file in prepared) {
        await Indexer(LocalDatabase.instance).embedPrepared(file, _refresh);
      }
      if (mounted)
        setState(() =>
            _message = 'Model ready. Prepared files have been processed.');
      await _refresh();
    } catch (e) {
      if (mounted) setState(() => _message = 'Model download failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import(bool folder) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      String? folderUri;
      List<Map<String, Object?>> items;
      if (folder) {
        final selected = await NativeBridge.pickFolder();
        if (selected == null) return;
        folderUri = selected['uri'] as String;
        items = await NativeBridge.listFolder(folderUri);
      } else {
        items = await NativeBridge.pickFiles();
      }
      const supported = {'pdf', 'txt', 'md', 'doc', 'docx', 'ppt', 'pptx'};
      final selectedCount = items.length;
      items = items
          .where((item) => supported
              .contains((item['name'] as String).toLowerCase().split('.').last))
          .toList();
      final skipped = selectedCount - items.length;
      final skippedMessage =
          skipped > 0 ? ' $skipped unsupported file(s) skipped.' : '';
      if (mounted)
        setState(() => _message = items.isEmpty && skipped > 0
            ? 'No supported files selected. Choose PDF, TXT, MD, DOC, DOCX, PPT, or PPTX.'
            : '${items.length} supported files found.$skippedMessage');
      for (final item in items) {
        final id =
            await LocalDatabase.instance.register(item, folderUri: folderUri);
        await _refresh();
        final file = await LocalDatabase.instance.file(id);
        if (file != null)
          await Indexer(LocalDatabase.instance).process(file, _refresh);
      }
    } catch (e) {
      if (mounted) setState(() => _message = 'Import failed: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('PocketSearch setup')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          const Icon(Icons.manage_search, size: 64),
          const SizedBox(height: 16),
          Text('Your knowledge, within reach',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          const Text(
              'Choose files or a folder. Your documents and search index stay on this phone.'),
          const SizedBox(height: 20),
          if (!_modelReady) ...[
            const Text(
                'Download EmbeddingGemma once to enable offline semantic search. '
                'You can inspect extracted text before downloading it.'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
                onPressed: _busy ? null : _download,
                icon: const Icon(Icons.download),
                label: const Text('Download search model')),
          ] else
            const Text('EmbeddingGemma ready for offline search.'),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: _busy ? null : () => _import(false),
              icon: const Icon(Icons.note_add),
              label: const Text('Choose files')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
              onPressed: _busy ? null : () => _import(true),
              icon: const Icon(Icons.folder_open),
              label: const Text('Choose folder')),
          const SizedBox(height: 8),
          FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/search'),
              icon: const Icon(Icons.search),
              label: const Text('Quick Search')),
          if (_busy) const LinearProgressIndicator(),
          if (_message != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_message!)),
          const SizedBox(height: 18),
          Text(
              '${_files.where((f) => f.status == 'searchable').length} of '
              '${_files.length} selected files searchable',
              style: Theme.of(context).textTheme.titleMedium),
          for (final file in _files)
            ListTile(
              title: Text(file.name),
              subtitle: Text(file.error ??
                  '${(file.jobStage ?? file.status).replaceAll('_', ' ')}'
                      '${file.jobStage == 'extracting' || file.jobStage == 'embedding' ? ' (${file.progress}%)' : ''}'),
              leading: const Icon(Icons.description_outlined),
              onTap: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => FileDetailsScreen(fileId: file.id)));
                _refresh();
              },
            ),
        ]),
      );
}
