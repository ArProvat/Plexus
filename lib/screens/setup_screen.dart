import 'package:flutter/material.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('PocketSearch setup')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          const Icon(Icons.manage_search, size: 64),
          const SizedBox(height: 24),
          Text('Your knowledge, within reach',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          const Text('Search privately on your phone. Today you can try three '
              'sample passages using a local embedding model.'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/search'),
            icon: const Icon(Icons.search), label: const Text('Quick Search'),
          ),
          const SizedBox(height: 16),
          const OutlinedButton(onPressed: null, child: Text('Import files - Day 2')),
          const Text('File import is not available yet. Samples are not your documents.'),
          const SizedBox(height: 24),
          const Text('Home-screen shortcut', style: TextStyle(fontWeight: FontWeight.bold)),
          const Text('Add the PocketSearch widget from your Android launcher to open search directly.'),
        ]),
      );
}
