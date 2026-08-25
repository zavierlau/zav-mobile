import 'package:flutter/material.dart';
import 'screens/resources_screen.dart';
import 'screens/stocks_screen.dart';
import 'screens/logs_screen.dart';
import 'services/config.dart';

// ZAV Mobile — kubenav-style mobile app for the ZAV/Hermes dashboard.
// Bottom navigation across Dashboard / Resources / Logs. Connects to the
// Hermes dashboard API (host + token configurable in settings).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Config.load(); // restore persisted baseUrl + token into Api statics
  runApp(const ZavApp());
}

class ZavApp extends StatelessWidget {
  const ZavApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZAV Mobile',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C6CF0),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0B10),
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [
    StocksScreen(),
    ResourcesScreen(),
    LogsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: const Color(0xFF0F1117),
        indicatorColor: const Color(0xFF7C6CF0),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.show_chart), label: '行情'),
          NavigationDestination(icon: Icon(Icons.dashboard), label: '資源'),
          NavigationDestination(icon: Icon(Icons.terminal), label: '日誌'),
        ],
      ),
    );
  }
}