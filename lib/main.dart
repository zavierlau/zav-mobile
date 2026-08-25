import 'package:flutter/material.dart';
import 'screens/resources_screen.dart';
import 'screens/stocks_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/crypto_screen.dart';
import 'screens/token_screen.dart';
import 'screens/system_screen.dart';
import 'screens/jobs_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/command_center_screen.dart';
import 'screens/k8s_screen.dart';
import 'services/config.dart';
import 'screens/native_web_embed.dart' if (dart.library.html) 'screens/web_web_embed.dart' as web_embed;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Config.load();
  await Config.loadK8s();
  web_embed.registerEmbed();
  runApp(const ZavApp());
}

// ZAV Mobile — kubenav-style mobile app for the ZAV/Hermes dashboard.
// Bottom navigation across 行情 / 加密 / 資源 / Token / 日誌, plus a 更多 hub
// that hosts the dashboard System / Jobs / Alerts tabs. Connects to the Hermes
// dashboard API (host + token configurable in settings).
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
    CryptoScreen(),
    ResourcesScreen(),
    TokenScreen(),
    LogsScreen(),
    MoreScreen(),
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
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.show_chart), label: '行情'),
          NavigationDestination(icon: Icon(Icons.currency_bitcoin), label: '加密'),
          NavigationDestination(icon: Icon(Icons.dashboard), label: '資源'),
          NavigationDestination(icon: Icon(Icons.token), label: 'Token'),
          NavigationDestination(icon: Icon(Icons.terminal), label: '日誌'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: '更多'),
        ],
      ),
    );
  }
}

// "更多" hub: hosts the dashboard System / Jobs / Alerts tabs that don't fit
// the 5-slot Material 3 NavigationBar. Each tile pushes its own screen.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('更多')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _HubTile(
            icon: Icons.memory,
            title: '系統',
            subtitle: '磁碟用量 · Gateway · 日誌檔案',
            color: const Color(0xFF7C6CF0),
            onTap: () => _push(context, const SystemScreen()),
          ),
          _HubTile(
            icon: Icons.event_repeat,
            title: 'Jobs',
            subtitle: '定時任務及啟用狀態',
            color: const Color(0xFF26A69A),
            onTap: () => _push(context, const JobsScreen()),
          ),
          _HubTile(
            icon: Icons.notifications_active,
            title: '警示',
            subtitle: '日誌快照與警報',
            color: const Color(0xFFFFB74D),
            onTap: () => _push(context, const AlertsScreen()),
          ),
          _HubTile(
            icon: Icons.view_in_ar,
            title: '3D 指揮中心',
            subtitle: '粒子頭像光球指揮中心',
            color: const Color(0xFF7C6CF0),
            onTap: () => _push(context, const CommandCenterScreen()),
          ),
          _HubTile(
            icon: Icons.circle,
            title: 'Kubernetes',
            subtitle: 'kubenav 式管理 · 連接 cluster 閱覽資源',
            color: const Color(0xFF326CE5),
            onTap: () => _push(context, const K8sScreen()),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF151820),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: color.withOpacity(0.18), shape: BoxShape.circle),
          child: Icon(icon, color: color),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 13, color: Colors.white54)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: onTap,
      ),
    );
  }
}