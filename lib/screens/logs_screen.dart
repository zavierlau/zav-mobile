import 'package:flutter/material.dart';
import '../services/api.dart';
import '../widgets/no_token_view.dart';

// Logs screen: lists log FILES (GET /api/logs -> {files:[{name,size_kb,mtime}]}).
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});
  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<LogFile> _files = [];
  bool _loading = false;
  String? _error;
  late bool _hadToken;

  @override
  void initState() {
    super.initState();
    _hadToken = Api.token.isNotEmpty;
    if (_hadToken) _load();
  }

  // Reload when the user returns from Settings having just set a token.
  void _reloadIfTokenJustSet() {
    if (!_hadToken && Api.token.isNotEmpty) {
      _hadToken = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dynamic raw = await Api.get('/api/logs');
      final List<dynamic> list = _extractList(raw);
      final files =
          list.map(LogFile.fromJson).where((f) => f.name.isNotEmpty).toList();
      if (mounted) setState(() => _files = files);
    } catch (e) {
      if (mounted) setState(() => _error = '載入失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Api.token.isNotEmpty) _reloadIfTokenJustSet();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Api.token.isEmpty
          ? const NoTokenView(title: '需要 Token 先可載入日誌')
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
          const SizedBox(height: 120),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.orangeAccent)),
          ),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton.icon(
                onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('重試')),
          ),
        ]),
      );
    }
    if (_files.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
          SizedBox(height: 200),
          Center(child: Text('暫無日誌檔案', style: TextStyle(color: Colors.white54))),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: _files.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final f = _files[i];
          return Card(
            color: const Color(0xFF151820),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: const Icon(Icons.description_outlined, color: Colors.white38),
              title: Text(f.name,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 14, color: Colors.white)),
              subtitle: Text(
                '${_size(f.sizeKb)} KB  ·  ${f.mtime.isEmpty ? '—' : f.mtime}',
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 12, color: Colors.white54),
              ),
              onTap: () => _showDetail(context, f),
            ),
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext context, LogFile f) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF151820),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.name,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _Row(label: '大小', value: '${_size(f.sizeKb)} KB'),
            _Row(label: '修改時間', value: f.mtime.isEmpty ? '—' : f.mtime),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('關閉'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _size(num kb) {
    if (kb >= 1024) return (kb / 1024).toStringAsFixed(1);
    return kb.toStringAsFixed(kb == kb.roundToDouble() ? 0 : 1);
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Colors.white38))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white70, fontFamily: 'monospace'))),
        ],
      ),
    );
  }
}

List<dynamic> _extractList(dynamic raw) {
  if (raw is List) return raw.cast<dynamic>();
  if (raw is Map) {
    for (final k in ['files', 'data', 'entries']) {
      if (raw.containsKey(k) && raw[k] is List) return (raw[k] as List).cast<dynamic>();
    }
  }
  return <dynamic>[];
}