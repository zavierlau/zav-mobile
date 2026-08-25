import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// 3D 指揮中心 — Three.js dashboard web page.
// Native build (Android/iOS): 用 url_launcher 開瀏覽器。
// Web build: 彈出提示話喺 native build 先用 WebView 嵌入。
const String commandCenterUrl = 'http://100.126.80.55:3000/command-center';

class CommandCenterScreen extends StatelessWidget {
  const CommandCenterScreen({super.key});

  Future<void> _open() async {
    final uri = Uri.parse(commandCenterUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      // fall back to in-place external kind if externalApplication not supported
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('3D 指揮中心')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.view_in_ar, size: 72, color: Color(0xFF7C6CF0)),
          const SizedBox(height: 16),
          const Text(
            '3D 指揮中心',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '以 Three.js 實作嘅即時 3D 儀表板。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _open,
            icon: const Icon(Icons.open_in_new),
            label: const Text('打開 3D 指揮中心'),
          ),
          const SizedBox(height: 16),
          if (kIsWeb)
            const _InfoCard(
              message:
                  'Web build 唔支援 Embedded WebView，請改用下方按鈕喺新分頁開啟。'
                      '喺 native build（Android/iOS）會用 WebView 內嵌顯示。',
            )
          else
            const _InfoCard(
              message:
                  '請使用 external browser 開啟。之後 native build 可改用 '
                      'webview_flutter 直接內嵌「3D 指揮中心」。',
            ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String message;
  const _InfoCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151820),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.amberAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: Colors.white70, height: 1.5)),
          ),
        ],
      ),
    );
  }
}