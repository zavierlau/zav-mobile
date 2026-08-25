import 'package:flutter/material.dart';
import '../services/api.dart';
import '../widgets/no_token_view.dart';

// Alerts screen: mirrors the dashboard "Alerts" tab.
// No dedicated alerts API exists, so we snapshot GET /api/logs — log files whose
// size exceeds a threshold (or that look like error logs) are flagged as alerts.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  static const double _alertKb = 50.0; // files larger than 50 KB are "big"
  List<LogFile> _files = [];
  bool _loading = true;
  String? _error;
  late bool _hadToken;

  @override
  void initState() {
    super.initState();
    _hadToken = Api.token.isNotEmpty;
    if (_hadToken) _load();
  }

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
      final list = _extractList(raw);
      final files = list.map(LogFile.fromJson).where((f) => f.name.isNotEmpty).toList();
      if (mounted) setState(() => _files = files);
    } catch (e) {
      if (mounted) setState(() => _error = '載入失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<LogFile> get _alerts =>
      _files.where((f) => f.sizeKb >= _alertKb || _looksErrorLog(f)).toList();

  bool _looksErrorLog(LogFile f) {
    final n = f.name.toLowerCase();
    return n.contains('error') || n.contains('fail') || n.contains('critical');
  }

  @override
  Widget build(BuildContext context) {
    if (Api.token.isNotEmpty) _reloadIfTokenJustSet();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('警示')),
      body: Api.token.isEmpty
          ? const NoTokenView(title: '需要 Token 先可載入警示')
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
    final alerts = _alerts;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF151820),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(alerts.isEmpty
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
                    color: alerts.isEmpty ? const Color(0xFF26A69A) : const Color(0xFFFFB74D)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    alerts.isEmpty
                        ? '未偵測到警示。\n日誌檔案皆低於警報門檻。'
                        : '偵測到 ${alerts.length} 個需注意的日誌檔案。',
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('日誌快照',
              style: TextStyle(
                  fontSize: 13, color: Colors.white38, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_files.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('暫無日誌檔案', style: TextStyle(color: Colors.white38)),
            )
          else
            ..._files.map((f) {
              final isAlert = f.sizeKb >= _alertKb || _looksErrorLog(f);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _AlertTile(file: f, alert: isAlert),
              );
            }),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final LogFile file;
  final bool alert;
  const _AlertTile({required this.file, required this.alert});

  @override
  Widget build(BuildContext context) {
    final accent = alert ? const Color(0xFFFFB74D) : const Color(0xFF26A69A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151820),
        borderRadius: BorderRadius.circular(10),
        border: alert ? Border.all(color: accent.withOpacity(0.4), width: 1) : null,
      ),
      child: Row(
        children: [
          Icon(_icon(alert), size: 18, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(file.name,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 13, color: Colors.white)),
                    ),
                    if (alert) ...[
                      const SizedBox(width: 8),
                      Text('警戒',
                          style: TextStyle(
                              fontSize: 11, color: accent, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text('${file.sizeKb.toStringAsFixed(0)} KB · ${file.mtime.isEmpty ? '—' : file.mtime}',
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 11, color: Colors.white54)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _icon(bool alert) => alert ? Icons.warning_amber_rounded : Icons.article_outlined;
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