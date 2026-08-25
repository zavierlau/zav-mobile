import 'package:flutter/material.dart';
import '../screens/settings_screen.dart';

// Shown by screens that need an authenticated API call but no token is set.
class NoTokenView extends StatelessWidget {
  final String title;
  const NoTokenView({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 56, color: Colors.white38),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              '尚未設定 Token。請前往「設定」輸入 Base URL 同 Token 之後再試。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen())),
              icon: const Icon(Icons.settings),
              label: const Text('前往設定'),
            ),
          ],
        ),
      ),
    );
  }
}