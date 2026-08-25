import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

// 3D 指揮中心 — embed the Three.js dashboard web page.
// Web build: embed a real <iframe> via HtmlElementView (the ONLY reliable
// cross-origin embed on Flutter Web). Android/iOS: open externally (native
// WebView embedding would need platform pointer-inject which is fragile).
const String commandCenterUrl = 'http://100.126.80.55:3000/command-center';

class CommandCenterScreen extends StatelessWidget {
  const CommandCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0B10),
      appBar: AppBar(title: const Text('3D 指揮中心')),
      body: kIsWeb
          ? const _WebIframe()
          : const _NativeNote(),
    );
  }
}

// Web: inline iframe. The view type is registered in main() for web only.
class _WebIframe extends StatelessWidget {
  const _WebIframe();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0B10),
      child: HtmlElementView(
        viewType: 'command-center-iframe',
      ),
    );
  }
}

// Native: informational note + open-in-browser button.
class _NativeNote extends StatelessWidget {
  const _NativeNote();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.view_in_ar, size: 72, color: Color(0xFF7C6CF0)),
        const SizedBox(height: 16),
        const Center(child: Text('3D 指揮中心', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        const SizedBox(height: 8),
        const Center(child: Text('3D 儀表板（Three.js）', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60))),
      ],
    );
  }
}