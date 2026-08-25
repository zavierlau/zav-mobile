// Web-only: register the 3D command-center <iframe> as a Flutter platform view.
// Selected by `if (dart.library.html)` in main.dart, so it only compiles for web.
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;
import 'command_center_screen.dart' show commandCenterUrl;

void registerEmbed() {
  try {
    ui_web.platformViewRegistry.registerViewFactory('command-center-iframe', (int id) {
      final iframe = html.IFrameElement()
        ..id = 'cc-$id'
        ..src = commandCenterUrl
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = '0'
        ..style.background = '#0a0b10';
      return iframe;
    });
  } catch (_) {
    // registration failure — CommandCenterScreen will just show empty on web
  }
}