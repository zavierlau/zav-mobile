import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _baseCtrl;
  late final TextEditingController _tokenCtrl;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _baseCtrl = TextEditingController(text: Api.baseUrl);
    _tokenCtrl = TextEditingController(text: Api.token);
  }

  @override
  void dispose() {
    _baseCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await Config.save(baseUrl: _baseCtrl.text, token: _tokenCtrl.text);
    if (!mounted) return;
    setState(() => _saved = true);
    // Live preview so users can validate the new config without leaving.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('設定已儲存'), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _clearToken() async {
    await Config.clearToken();
    if (!mounted) return;
    setState(() {
      _tokenCtrl.clear();
      _saved = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Token 已清除'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('設定')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('API 設定', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('連接到 ZAV/Hermes dashboard server。Token 會以 x-control-token header 傳送。',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 20),
            TextField(
              controller: _baseCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'http://100.126.80.55:3000',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tokenCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Token',
                helperText: '由本機儲存 (shared_preferences)，非加密存儲，請酌量使用。',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key_outlined),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('儲存設定'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _clearToken,
              icon: const Icon(Icons.logout),
              label: const Text('清除 Token'),
            ),
            const SizedBox(height: 20),
            if (_saved) ...[
              const Divider(color: Color(0xFF1C1F27)),
              const SizedBox(height: 12),
              const Text('目前值：', style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 6),
              Text('Base URL: ${Api.baseUrl}', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 4),
              Text('Token: ${Api.token.isEmpty ? '(空)' : '••••${Api.token.substring(min(Api.token.length, 6))}'}',
                  style: const TextStyle(color: Colors.white70, fontFamily: 'monospace')),
            ],
          ],
        ),
      ),
    );
  }
}

int min(int a, int b) => a < b ? a : b;