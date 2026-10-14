import 'package:flutter/material.dart';
import 'platform/native_bridge.dart';
import 'screens/setup_screen.dart';
import 'screens/quick_search_screen.dart';

class PocketSearchApp extends StatefulWidget {
  const PocketSearchApp({super.key});

  @override
  State<PocketSearchApp> createState() => _PocketSearchAppState();
}

class _PocketSearchAppState extends State<PocketSearchApp> {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    NativeBridge.onSearch = _openSearch;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await NativeBridge.consumeSearchLaunch() && mounted) _openSearch();
    });
  }

  void _openSearch() {
    _navigator.currentState?.pushNamedAndRemoveUntil('/search', (r) => r.isFirst);
  }

  @override
  void dispose() {
    NativeBridge.onSearch = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorKey: _navigator,
        title: 'PocketSearch',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF356859)),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        routes: {
          '/': (_) => const SetupScreen(),
          '/search': (_) => const QuickSearchScreen(),
        },
      );
}
