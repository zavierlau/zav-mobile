import 'package:flutter/material.dart';
import '../services/api.dart';
import '../widgets/no_token_view.dart';

// System screen: mirrors the dashboard "System" tab.
//   GET /api/system   -> { disk:{used_gb,total_gb,pct}, critical }
//   GET /api/gateway  -> gateway health
//   GET /api/logs     -> { files:[{name,size_kb,mtime}] }
class SystemScreen extends StatefulWidget {
  const SystemScreen({super.key});
  @override
  State<SystemScreen> createState() => _SystemScreenState();
}

class _SystemScreenState extends State<SystemScreen> {
  DiskInfo? _disk;
  bool _critical = false;
  String _gateway = '';
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
      // System is required; gateway & logs failures are non-fatal (kept partial).
      final sys = await Api.get('/api/system');
      if (mounted) {
        setState(() {
          _disk = DiskInfo.fromJson(sys is Map ? sys['disk'] : null);
          _critical = _asBool(sys is Map ? sys['critical'] : false);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '載入失敗：$e');
    }

    try {
      final g = await Api.get('/api/gateway');
      final m = g is Map ? g : {};
      final s = m['status'] ?? m['state'] ?? m['healthy'] ?? '';
      if (mounted) setState(() => _gateway = s.toString());
    } catch (e) {
      if (mounted && _error == null) setState(() => _gateway = '無法取得');
    }

    try {
      final raw = await Api.get('/api/logs');
      final list = _extractList(raw);
      final files = list.map(LogFile.fromJson).where((f) => f.name.isNotEmpty).toList();
      if (mounted) setState(() => _files = files);
    } catch (e) {
      if (mounted && _error == null) _files = [];
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (Api.token.isNotEmpty) _reloadIfTokenJustSet();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('系統')),
      body: Api.token.isEmpty
          ? const NoTokenView(title: '需要 Token 先可載入系統狀態')
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _disk == null) {
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
    final disk = _disk;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          const _SectionLabel('磁碟用量'),
          const SizedBox(height: 8),
          if (disk != null)
            _DiskCard(disk: disk, critical: _critical)
          else
            const _EmptyHint('暫無磁碟資料'),
          const SizedBox(height: 16),
          const _SectionLabel('Gateway 狀態'),
          const SizedBox(height: 8),
          _GatewayCard(status: _gateway),
          const SizedBox(height: 16),
          const _SectionLabel('日誌檔案'),
          const SizedBox(height: 8),
          if (_files.isEmpty)
            const _EmptyHint('暫無日誌檔案')
          else
            ..._files.map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _LogTile(file: f),
                )),
        ],
      ),
    );
  }

  static bool _asBool(dynamic v) => v == true || v == 1 || '$v'.toLowerCase() == 'true';
}

class DiskInfo {
  final num usedGb;
  final num totalGb;
  final num pct;
  const DiskInfo(this.usedGb, this.totalGb, this.pct);
  factory DiskInfo.fromJson(dynamic j) {
    final m = j is Map ? j : {};
    return DiskInfo(
      (m['used_gb'] ?? 0) as num,
      (m['total_gb'] ?? 0) as num,
      (m['pct'] ?? 0) as num,
    );
  }
}

class _DiskCard extends StatelessWidget {
  final DiskInfo disk;
  final bool critical;
  const _DiskCard({required this.disk, required this.critical});

  @override
  Widget build(BuildContext context) {
    final pct = disk.pct.clamp(0, 100);
    final def = pct < 0.0001 && disk.totalGb > 0 ? (disk.usedGb / disk.totalGb * 100) : pct;
    final shown = def.clamp(0, 100).toDouble();
    final color = _barColor(shown, critical);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151820),
        borderRadius: BorderRadius.circular(12),
        border: critical
            ? Border.all(color: const Color(0xFFEF5350), width: 1.2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('已用 ${_gb(disk.usedGb)} / ${_gb(disk.totalGb)} GB',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              if (critical)
                const Text('⚠ 嚴重',
                    style: TextStyle(color: Color(0xFFEF5350), fontWeight: FontWeight.bold))
              else
                Text('${shown.toStringAsFixed(1)}%',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          if (critical) const SizedBox(height: 4),
          if (critical)
            const Text('磁碟用量達到警戒等級', style: TextStyle(color: Color(0xFFEF5350), fontSize: 12)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: shown / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFF0D0E13),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Color _barColor(double pct, bool critical) {
    if (critical || pct >= 85) return const Color(0xFFEF5350);
    if (pct >= 60) return const Color(0xFFFFB74D);
    return const Color(0xFF26A69A);
  }

  String _gb(num gb) {
    if (gb >= 1024) return (gb / 1024).toStringAsFixed(1);
    return gb.toStringAsFixed(gb == gb.roundToDouble() ? 0 : 1);
  }
}

class _GatewayCard extends StatelessWidget {
  final String status;
  const _GatewayCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final ok = status.isNotEmpty &&
        !status.toLowerCase().contains('fail') &&
        !status.contains('否') &&
        status != '無法取得';
    final color = ok ? const Color(0xFF26A69A) : const Color(0xFFFFB74D);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151820),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(status.isEmpty ? '—' : status,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final LogFile file;
  const _LogTile({required this.file});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151820),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, size: 18, color: Colors.white38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 13, color: Colors.white)),
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
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 13, color: Colors.white38, fontWeight: FontWeight.w600));
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(text, style: const TextStyle(color: Colors.white38)),
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