import 'package:flutter/material.dart';
import '../platform/native_bridge.dart';
import '../search/search_engine.dart';
import '../storage/local_database.dart';

class QuickSearchScreen extends StatefulWidget {
  const QuickSearchScreen({super.key});
  @override
  State<QuickSearchScreen> createState() => _QuickSearchScreenState();
}

class _QuickSearchScreenState extends State<QuickSearchScreen> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  String? _error;
  List<FileMatch> _results = [];
  String? _notice;

  Future<void> _search() async {
    if (_busy) return;
    final query = _query.text.trim();
    if (query.isEmpty) return;
    setState(() { _busy = true; _error = null; _results = []; _notice = null; });
    try {
      final files = await LocalDatabase.instance.files();
      if (!files.any((f) => f.status == 'searchable')) {
        if (mounted) setState(() => _notice = 'No indexed files yet. Choose files or a folder in Setup.');
        return;
      }
      await NativeBridge.initializeEmbedding();
      final results = await SearchEngine(LocalDatabase.instance).search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        if (results.isEmpty) _notice = 'No relevant content found in your indexed files.';
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Local search could not run: $e';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() { _query.dispose(); _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Quick Search')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          TextField(
            controller: _query, focusNode: _focus, autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: 'Search your files',
              suffixIcon: IconButton(onPressed: _busy ? null : _search,
                  tooltip: 'Search', icon: const Icon(Icons.search)),
            ),
          ),
          const SizedBox(height: 16),
          if (_busy) ...[
            const LinearProgressIndicator(),
            const Text('Searching indexed files…'),
          ],
          if (_error != null) Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (_notice != null) Text(_notice!),
          if (!_busy && _error == null && _notice == null && _results.isEmpty)
            const Text('Enter a question to search your indexed files.'),
          for (final result in _results)
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${result.name} · ${result.chunk.location}',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8), Text(result.chunk.text),
                TextButton(onPressed: () async {
                  try { await NativeBridge.openSource(result.uri); }
                  catch (e) { if (mounted) setState(() => _error = '$e'); }
                }, child: const Text('Open original')),
              ],
            ))),
        ]),
      );
}
