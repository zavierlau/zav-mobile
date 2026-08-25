import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api.dart';
import '../widgets/no_token_view.dart';

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});
  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  List<CronJob> _jobs = [];
  bool _loading = false;
  String? _error;
  String? _rawPreview;
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
      _rawPreview = null;
    });
    try {
      final dynamic raw = await Api.get('/api/calendar');
      final List<dynamic> list = _extractList(raw);
      final jobs = list.map(CronJob.fromJson).where((j) => j.name.isNotEmpty).toList();
      if (mounted) {
        setState(() {
          _jobs = jobs;
          // If the payload wasn't a clean list of jobs, keep a raw preview.
          if (list.isEmpty && raw != null) _rawPreview = _truncate(raw);
        });
      }
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
      appBar: AppBar(title: const Text('定時任務')),
      body: Api.token.isEmpty
          ? const NoTokenView(title: '需要 Token 先可載入 Cron') 
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
    if (_jobs.isEmpty && _rawPreview == null) {
      return const Center(child: Text('暫無定時任務', style: TextStyle(color: Colors.white54)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          if (_jobs.isNotEmpty) ..._jobs.map((j) => _JobCard(job: j)),
          if (_rawPreview != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _RawPreviewBlock(preview: _rawPreview!),
            ),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final CronJob job;
  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF151820),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // kubenav-style status dot
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: job.enabled ? const Color(0xFF26A69A) : Colors.white24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(job.schedule,
                        style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white60,
                            fontFamily: 'monospace')),
                    const SizedBox(height: 4),
                    Text(
                      job.enabled ? '已啟用' : '已停用',
                      style: TextStyle(
                          fontSize: 12,
                          color: job.enabled ? const Color(0xFF80CBC4) : Colors.white38),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
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
            Row(
              children: [
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: job.enabled ? const Color(0xFF26A69A) : Colors.white24,
                  ),
                ),
                const SizedBox(width: 10),
                Text(job.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            _DetailRow(label: 'ID', value: job.id),
            _DetailRow(label: '排程', value: job.schedule),
            _DetailRow(label: '下次執行', value: job.nextRunAt),
            _DetailRow(label: '上次執行', value: job.lastRunAt),
            _DetailRow(label: '上次狀態', value: job.lastStatus),
            _DetailRow(label: '已啟用', value: job.enabled ? '是' : '否'),
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
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text(label, style: const TextStyle(color: Colors.white38))),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }
}

class _RawPreviewBlock extends StatelessWidget {
  final String preview;
  const _RawPreviewBlock({required this.preview});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('API 回傳格式未符合預期，原始資料：',
            style: TextStyle(color: Colors.orangeAccent, fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0E13),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(preview,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white54)),
        ),
      ],
    );
  }
}

List<dynamic> _extractList(dynamic raw) {
  if (raw is List) return raw.cast<dynamic>();
  if (raw is Map) {
    for (final k in ['jobs', 'data', 'cron']) {
      if (raw.containsKey(k) && raw[k] is List) return (raw[k] as List).cast<dynamic>();
    }
  }
  return <dynamic>[];
}

String _truncate(dynamic raw, [int max = 400]) {
  final s = raw is String ? raw : jsonEncode(raw);
  return s.length > max ? '${s.substring(0, max)}…' : s;
}