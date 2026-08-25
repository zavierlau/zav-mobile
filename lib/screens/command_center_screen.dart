import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

// 3D 指揮中心 — embed the Three.js dashboard web page.
// Uses flutter_inappwebview's InAppWebView which renders as an <iframe> on
// web (Flutter Web) and a real WebView on Android/iOS. Cross-platform.
const String commandCenterUrl = 'http://100.126.80.55:3000/command-center';

class CommandCenterScreen extends StatelessWidget {
  const CommandCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0B10),
      appBar: AppBar(title: const Text('3D 指揮中心')),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(commandCenterUrl)),
        initialSettings: InAppWebViewSettings(
          transparentBackground: true,
          supportZoom: true,
        ),
      ),
    );
  }
}