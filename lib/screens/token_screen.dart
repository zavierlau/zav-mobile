import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api.dart';
import '../widgets/no_token_view.dart';

// Token screen: daily usage trend (GET /api/usage_trend -> {daily:[{day,tokens}]})
// + quota cards (GET /api/quota -> {rolling,weekly,monthly} each with percent).
class TokenScreen extends StatefulWidget {
  const TokenScreen({super.key});
  @override
  State<TokenScreen> createState() => _TokenScreenState();
}

class _TokenScreenState extends State<TokenScreen> {
  List<TrendPoint> _trend = [];
  List<Quota> _quotas = [];
  bool _loading = true;
  String? _error;
  String? _rawPreview;
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
      _rawPreview = null;
    });
    try {
      final rawTrend = await Api.get('/api/usage_trend');
      final trend = _parseTrend(rawTrend);

      List<Quota> quotas = const [];
      String? quotaRaw;
      try {
        final rawQuota = await Api.get('/api/quota');
        quotas = _parseQuota(rawQuota);
        quotaRaw = _quotaRaw(rawQuota);
      } catch (_) {
        // quota failure shouldn't fail the whole screen; trend still shown.
      }

      if (mounted) {
        setState(() {
          _trend = trend;
          _quotas = quotas;
          if (trend.isEmpty && quotas.isEmpty && quotaRaw != null) {
            _rawPreview = _truncate(rawTrend is Map && rawTrend.containsKey('quota')
                ? rawTrend
                : rawTrend);
          } else if (quotas.isEmpty && quotaRaw != null) {
            _rawPreview = _truncate(quotaRaw);
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '載入失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<TrendPoint> _parseTrend(dynamic raw) {
    List<dynamic> list;
    if (raw is List) {
      list = raw;
    } else if (raw is Map) {
      dynamic d = raw['daily'] ?? raw['data'] ?? raw['trend'];
      if (d is List) {
        list = d;
      } else {
        return const [];
      }
    } else {
      return const [];
    }
    final out = <TrendPoint>[];
    for (final e in list) {
      if (e is! Map) continue;
      final m = e.cast<String, dynamic>();
      final tokens = m['tokens'] ?? m['count'] ?? 0;
      out.add(TrendPoint(
        '${m['day'] ?? m['date'] ?? ''}',
        (tokens ?? 0) as num,
      ));
    }
    // newest first
    out.sort((a, b) => b.day.compareTo(a.day));
    return out;
  }

  List<Quota> _parseQuota(dynamic raw) {
    if (raw is! Map) return const [];
    final m = raw.cast<String, dynamic>();
    // unwrap {data:{...}}
    if (m.containsKey('data') && m['data'] is Map) {
      final d = (m['data'] as Map).cast<String, dynamic>();
      for (final key in ['rolling', 'weekly', 'monthly']) {
        if (d.containsKey(key)) return _buildQuotas(m, d);
      }
      // data itself might BE a quota object
      if (d.containsKey('percent')) {
        final q = _mapQuota(d, 'rolling');
        final qw = _mapQuota(d, 'weekly');
        final qm = _mapQuota(d, 'monthly');
        if (q != null || qw != null || qm != null) {
          return [if (q != null) q, if (qw != null) qw, if (qm != null) qm];
        }
      }
    }
    return _buildQuotas(m, m);
  }

  List<Quota> _buildQuotas(Map<String, dynamic> root, Map<String, dynamic> m) {
    final out = <Quota>[];
    for (final key in ['rolling', 'weekly', 'monthly']) {
      final q = _mapQuota(m, key);
      if (q != null) out.add(q);
    }
    // If the object itself is a single quota, fall back to it.
    if (out.isEmpty && m.containsKey('percent')) {
      final q = _mapQuota(m, 'rolling');
      if (q != null) out.add(q);
    }
    return out;
  }

  Quota? _mapQuota(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is! Map) return null;
    final sub = v.cast<String, dynamic>();
    final percent = sub['percent'];
    if (percent == null && sub['used_usd'] == null) return null;
    final labels = {
      'rolling': 'Rolling',
      'weekly': 'Weekly',
      'monthly': 'Monthly',
    };
    return Quota(
      labels[key] ?? key,
      key,
      (percent ?? 0) as num,
      (sub['used_usd'] ?? 0) as num,
      (sub['total_usd'] ?? 0) as num,
      (sub['remaining_usd'] ?? 0) as num,
    );
  }

  String? _quotaRaw(dynamic raw) {
    if (raw is! Map) return null;
    final m = raw.cast<String, dynamic>();
    final hasQuota =
        m.containsKey('rolling') || m.containsKey('weekly') || m.containsKey('monthly');
    return hasQuota ? null : jsonEncode(raw);
  }

  @override
  Widget build(BuildContext context) {
    if (Api.token.isNotEmpty) _reloadIfTokenJustSet();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Api.token.isEmpty
          ? const NoTokenView(title: '需要 Token 先可載入 Token 用量')
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _trend.isEmpty && _quotas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _trend.isEmpty && _quotas.isEmpty) {
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
    if (_trend.isEmpty && _quotas.isEmpty && _rawPreview == null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
          SizedBox(height: 200),
          Center(child: Text('暫無 Token 數據', style: TextStyle(color: Colors.white54))),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          if (_quotas.isNotEmpty) ...[
            const Text('Quota',
                style: TextStyle(
                    fontSize: 13, color: Colors.white38, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._quotas.map((q) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: _QuotaCard(quota: q),
                )),
            const SizedBox(height: 16),
          ],
          if (_trend.isNotEmpty) ...[
            const Text('每日用量',
                style: TextStyle(
                    fontSize: 13, color: Colors.white38, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF151820),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: _trend
                    .map((t) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(t.day,
                                    style: const TextStyle(
                                        fontFamily: 'monospace', fontSize: 13)),
                              ),
                              Text(_num(t.tokens),
                                  style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
          if (_rawPreview != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _RawPreviewBlock(preview: _rawPreview!),
            ),
        ],
      ),
    );
  }

  String _num(num v) {
    if (v == v.roundToDouble() && v < 1e15) return v.toStringAsFixed(v is double ? 0 : 0);
    return v.toStringAsFixed(0);
  }
}

class TrendPoint {
  final String day;
  final num tokens;
  const TrendPoint(this.day, this.tokens);
}

class Quota {
  final String label;
  final String key;
  final num percent;
  final num usedUsd;
  final num totalUsd;
  final num remainingUsd;
  const Quota(this.label, this.key, this.percent, this.usedUsd, this.totalUsd,
      this.remainingUsd);
}

class _QuotaCard extends StatelessWidget {
  final Quota quota;
  const _QuotaCard({required this.quota});

  @override
  Widget build(BuildContext context) {
    final pct = quota.percent.clamp(0, 100);
    final color = _barColor(quota.percent);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151820),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(quota.label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              Text('${quota.percent.toStringAsFixed(1)}%',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct.toDouble() / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFF0D0E13),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('已用 \$${_usd(quota.usedUsd)}',
                  style: const TextStyle(fontSize: 12, color: Colors.white54)),
              Text('總額 \$${_usd(quota.totalUsd)}',
                  style: const TextStyle(fontSize: 12, color: Colors.white54)),
              Text('剩餘 \$${_usd(quota.remainingUsd)}',
                  style: const TextStyle(fontSize: 12, color: Colors.white38)),
            ],
          ),
        ],
      ),
    );
  }

  Color _barColor(num percent) {
    if (percent >= 85) return const Color(0xFFEF5350);
    if (percent >= 60) return const Color(0xFFFFB74D);
    return const Color(0xFF26A69A);
  }

  String _usd(num v) {
    if (v >= 100) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2);
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

String _truncate(dynamic raw, [int max = 400]) {
  final s = raw is String ? raw : jsonEncode(raw);
  return s.length > max ? '${s.substring(0, max)}…' : s;
}