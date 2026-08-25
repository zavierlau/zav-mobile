import 'package:flutter/material.dart';
import '../services/api.dart';
import '../widgets/no_token_view.dart';

// Jobs screen: mirrors the dashboard "Jobs" tab.
//   GET /api/calendar  -> { jobs:[{id,name,schedule,enabled,last_status,...}] }
//   POST /api/cron     -> { job_id, action:'pause'|'resume' } to toggle enabled.
class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});
  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  List<CronJob> _jobs = [];
  bool _loading = true;
  String? _error;
  late bool _hadToken;
  // Track which job is busy toggling so the switch gives immediate feedback.
  final Set<String> _busy = {};

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
      final dynamic raw = await Api.get('/api/calendar');
      final list = _extractList(raw);
      final jobs = list.map(CronJob.fromJson).where((j) => j.name.isNotEmpty).toList();
      if (mounted) setState(() => _jobs = jobs);
    } catch (e) {
      if (mounted) setState(() => _error = '載入失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(CronJob job, bool enable) async {
    final action = enable ? 'resume' : 'pause';
    setState(() => _busy.add(job.id));
    try {
      await Api.post('/api/cron', {
        'job_id': job.id.isEmpty ? job.name : job.id,
        'action': action,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${job.name}：${enable ? '已啟用' : '已停用'}'),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('切換失敗，已還原：$e'),
          duration: const Duration(seconds: 3),
        ));
      }
    } finally {
      // Always reload to reflect server truth (reverts optimistic switch on failure).
      await _load();
      if (mounted) setState(() => _busy.remove(job.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Api.token.isNotEmpty) _reloadIfTokenJustSet();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('定時任務')),
      body: Api.token.isEmpty
          ? const NoTokenView(title: '需要 Token 先可載入 Cron 任務')
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _jobs.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null && _jobs.isEmpty) {
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
    if (_jobs.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
          SizedBox(height: 200),
          Center(child: Text('暫無定時任務', style: TextStyle(color: Colors.white54))),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: _jobs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _JobCard(
          job: _jobs[i],
          busy: _busy.contains(_jobs[i].id),
          onToggle: (enable) => _toggle(_jobs[i], enable),
          onTap: () => _showDetail(context, _jobs[i]),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, CronJob job) {
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
            Text(job.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _DetailRow(label: 'ID', value: job.id),
            _DetailRow(label: '排程', value: job.schedule),
            _DetailRow(label: '下次執行', value: job.nextRunAt),
            _DetailRow(label: '上次執行', value: job.lastRunAt),
            _DetailRow(label: '上次狀態', value: job.lastStatus),
            _DetailRow(label: '狀態', value: job.enabled ? '已啟用' : '已停用'),
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

class _JobCard extends StatelessWidget {
  final CronJob job;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;
  const _JobCard({
    required this.job,
    required this.busy,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(job.lastStatus);
    return Card(
      color: const Color(0xFF151820),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(job.schedule,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white60,
                            fontFamily: 'monospace')),
                    const SizedBox(height: 6),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _Badge(
                          text: job.enabled ? '已啟用' : '已停用',
                          color: job.enabled ? const Color(0xFF80CBC4) : Colors.white38,
                        ),
                        _Badge(
                          text: job.lastStatus.isEmpty ? '無記錄' : job.lastStatus,
                          color: statusColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              busy
                  ? const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Switch(
                      value: job.enabled,
                      onChanged: (v) => onToggle(v),
                      activeColor: const Color(0xFF7C6CF0),
                      activeTrackColor: const Color(0xFF7C6CF0).withOpacity(0.4),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    final t = s.toLowerCase();
    if (t.contains('success') || t.contains('ok') || t.contains('done')) {
      return const Color(0xFF80CBC4);
    }
    if (t.contains('fail') || t.contains('error') || t.contains('skipped')) {
      return const Color(0xFFEF9A9A);
    }
    return Colors.white54;
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600)),
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

List<dynamic> _extractList(dynamic raw) {
  if (raw is List) return raw.cast<dynamic>();
  if (raw is Map) {
    for (final k in ['jobs', 'data', 'cron']) {
      if (raw.containsKey(k) && raw[k] is List) return (raw[k] as List).cast<dynamic>();
    }
  }
  return <dynamic>[];
}