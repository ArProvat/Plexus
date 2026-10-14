import 'package:flutter/material.dart';
import '../platform/native_bridge.dart';
import '../search/vector_search.dart';

const samplePassages = [
  'AI agents remember previous conversations by storing messages and summaries '
      'in memory and retrieving relevant context for the next interaction.',
  'Neural networks learn during training by adjusting weights using gradients '
      'to reduce a loss function over batches of examples.',
  'To cook a vegetable soup, chop carrots and onions, simmer them in stock, '
      'and season with herbs before serving.',
];

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
  String? _measurement;
  List<List<double>>? _vectors;
  List<({int index, double score})> _results = [];

  Future<void> _search() async {
    if (_busy) return;
    final query = _query.text.trim();
    if (query.isEmpty) {
      setState(() { _results = []; _error = null; _measurement = null; });
      return;
    }
    setState(() { _busy = true; _error = null; _results = []; _measurement = null; });
    try {
      final spec = await NativeBridge.initializeEmbedding();
      _vectors ??= await NativeBridge.embedDocuments(samplePassages);
      if (_vectors!.length != samplePassages.length) {
        throw StateError('The model returned an unexpected number of vectors.');
      }
      final timer = Stopwatch()..start();
      final vector = await NativeBridge.embedQuery(query);
      timer.stop();
      final results = List.generate(samplePassages.length, (i) =>
          (index: i, score: cosineSimilarity(vector, _vectors![i])))
        ..sort((a, b) => b.score.compareTo(a.score));
      if (!mounted) return;
      setState(() {
        _results = results;
        _measurement = 'Model load: ${spec['loadMs']} ms. '
            'Warm query including bridge: ${timer.elapsedMilliseconds} ms. '
            '${vector.length} dimensions.';
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Local search could not run. Check the native runtime and '
            'bundled model configuration.\n$e';
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
          const Text('Sample content only - no documents imported.'),
          TextButton(onPressed: _busy ? null : () {
            _query.text = 'How do agents remember previous conversations?';
            _search();
          }, child: const Text('Try the agent memory question')),
          if (_busy) ...[
            const LinearProgressIndicator(),
            const Text('Running the local embedding model...'),
          ],
          if (_error != null) Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (!_busy && _error == null && _results.isEmpty)
            const Text('Enter a question to search the three sample passages.'),
          for (final result in _results)
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sample ${result.index + 1} | cosine ${result.score.toStringAsFixed(3)}'),
                const SizedBox(height: 8), Text(samplePassages[result.index]),
              ],
            ))),
          if (_measurement != null) Text(_measurement!),
        ]),
      );
}
