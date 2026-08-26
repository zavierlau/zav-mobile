import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api.dart';

// Stock detail screen: live quote + price history chart + technical indicators.
//
// Data (all cycber / neon themed):
//   - /api/stocks/hist?symbol=X  -> {timestamps, closes, opens, highs, lows, volumes}
//   - /api/tech?symbol=X         -> {rsi, sma20, sma50, macd, macd_signal, signals[]}
//   - /api/stocks                -> live quotes, pick current symbol for 52w range + volume
//
// Parsing tolerates wrapper shapes ({data:{...}}, [..]) and missing fields so the
// screen never crashes on unexpected payloads.
class StockDetailScreen extends StatefulWidget {
  final String symbol;
  final String name;
  const StockDetailScreen({super.key, required this.symbol, required this.name});

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  bool _loading = true;
  String? _error;

  // History (index-aligned).
  List<num> _closes = [];
  List<String> _timestamps = [];
  List<num> _volumes = [];

  // Quote.
  num? _price;
  num? _chg;
  num? _wkHigh;
  num? _wkLow;
  num? _volume;

  // Technical indicators.
  num? _rsi;
  num? _sma20;
  num? _sma50;
  num? _macd;
  num? _macdSignal;
  List<dynamic> _signals = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        Api.get('/api/stocks/hist?symbol=${widget.symbol}'),
        Api.get('/api/tech?symbol=${widget.symbol}'),
        Api.get('/api/stocks'),
      ]);
      if (!mounted) return;
      setState(() {
        _parseHist(results[0]);
        _parseTech(results[1]);
        _parseQuote(results[2]);
      });
    } catch (e) {
      if (mounted) setState(() => _error = '載入失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- parsing ----------

  dynamic _unwrap(dynamic raw) {
    // If payload wraps everything under {data:{...}} use that map directly.
    if (raw is Map && raw.containsKey('data') && raw['data'] is Map) {
      final d = raw['data'] as Map;
      // only unwrap when top-level doesn't already carry the fields
      if (!raw.containsKey('closes') && !raw.containsKey('rsi')) return d;
    }
    return raw;
  }

  List<num> _numList(dynamic v) {
    if (v is List) {
      return v.whereType<num>().toList();
    }
    return const [];
  }

  List<String> _stringList(dynamic v) {
    if (v is List) {
      return v.where((e) => e != null).map((e) => '$e').toList();
    }
    return const [];
  }

  num _num(Object? v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v) ?? 0;
    return 0;
  }

  void _parseHist(dynamic raw) {
    final src = _unwrap(raw);
    final m = src is Map ? src.cast<String, dynamic>() : const <String, dynamic>{};
    final closes = _numList(m['closes']);
    _closes = closes.isEmpty ? _numList(m['close']) : closes;
    _timestamps = _stringList(m['timestamps']).isNotEmpty
        ? _stringList(m['timestamps'])
        : _stringList(m['dates']);
    final vol = _numList(m['volumes']);
    _volumes = vol.isEmpty ? _numList(m['volume']) : vol;
  }

  void _parseTech(dynamic raw) {
    final src = _unwrap(raw);
    // /api/tech returns {symbols:[{symbol,rsi14,sma20,sma50,macd_hist,signals}]} —
    // it runs the WHOLE watchlist, so pick our own symbol out of the array.
    dynamic mine;
    final target = widget.symbol.toUpperCase();
    if (src is Map) {
      final arr = src['symbols'];
      if (arr is List) {
        for (final e in arr) {
          if (e is! Map) continue;
          if ('${e['symbol'] ?? ''}'.toUpperCase() == target) { mine = e.cast<String, dynamic>(); break; }
        }
      }
    }
    final Map<String, dynamic> m = (mine is Map) ? Map<String, dynamic>.from(mine) : <String, dynamic>{};
    _rsi = m['rsi14'] != null ? _num(m['rsi14']) : (m['rsi'] != null ? _num(m['rsi']) : null);
    _sma20 = m['sma20'] != null ? _num(m['sma20'])
        : (m['sma_20'] != null ? _num(m['sma_20']) : null);
    _sma50 = m['sma50'] != null ? _num(m['sma50'])
        : (m['sma_50'] != null ? _num(m['sma_50']) : null);
    _macd = m['macd_hist'] != null ? _num(m['macd_hist']) : (m['macd'] != null ? _num(m['macd']) : null);
    _macdSignal = m['macd_signal'] != null ? _num(m['macd_signal'])
        : (m['signal'] != null ? _num(m['signal']) : null);
    final sig = m['signals'];
    if (sig is List) {
      _signals = sig;
    } else if (sig is Map) {
      _signals = <dynamic>[sig];
    } else {
      _signals = const [];
    }
  }

  void _parseQuote(dynamic raw) {
    final list = raw is List
        ? raw
        : (raw is Map
            ? (raw['stocks'] ?? raw['data'] ?? const []) as dynamic
            : const []);
    if (list is! List) return;
    final target = widget.symbol.toUpperCase();
    for (final e in list) {
      if (e is! Map) continue;
      final m = e.cast<String, dynamic>();
      final sym = '${m['symbol'] ?? ''}'.toUpperCase();
      if (sym != target && sym != widget.symbol.toUpperCase()) continue;
      _price = m['price'] != null ? _num(m['price']) : _price;
      _chg = (m['change_pct'] ?? m['chg']) != null
          ? _num(m['change_pct'] ?? m['chg'])
          : _chg;
      _wkHigh = _numOrNull(m, ['fifty_two_week_high', 'fiftyTwoWeekHigh', 'week52_high', '52w_high', 'week_high']);
      _wkLow = _numOrNull(m, ['fifty_two_week_low', 'fiftyTwoWeekLow', 'week52_low', '52w_low', 'week_low']);
      _volume = _numOrNull(m, ['regular_market_volume', 'regularMarketVolume', 'volume', 'vol']);
      break;
    }
  }

  num? _numOrNull(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      if (m[k] != null) {
        final v = _num(m[k]);
        return v == 0 ? null : v;
      }
    }
    return null;
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0B10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0B10),
        title: Text(widget.symbol, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.orangeAccent)),
            ),
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh), label: const Text('重試')),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          _HeaderCard(
            symbol: widget.symbol,
            name: widget.name,
            price: _price,
            chg: _chg,
            wkHigh: _wkHigh,
            wkLow: _wkLow,
            volume: _volume ?? (_volumes.isNotEmpty ? _volumes.last : null),
          ),
          const SizedBox(height: 12),
          _ChartCard(closes: _closes, timestamps: _timestamps, volumes: _volumes),
          const SizedBox(height: 12),
          _TechCard(
            rsi: _rsi,
            sma20: _sma20,
            sma50: _sma50,
            macd: _macd,
            macdSignal: _macdSignal,
            signals: _signals,
            lastClose: _closes.isNotEmpty ? _closes.last : null,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header: name / price / change (red-green) / 52w high-low / volume
// ---------------------------------------------------------------------------
class _HeaderCard extends StatelessWidget {
  final String symbol;
  final String name;
  final num? price;
  final num? chg;
  final num? wkHigh;
  final num? wkLow;
  final num? volume;
  const _HeaderCard({
    required this.symbol, required this.name, required this.price,
    required this.chg, required this.wkHigh, required this.wkLow, required this.volume,
  });

  @override
  Widget build(BuildContext context) {
    final up = (chg ?? 0) >= 0;
    final chgColor = up ? const Color(0xFF26A69A) : const Color(0xFFEF5350);
    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(fontSize: 15, color: Colors.white70)),
                      const SizedBox(height: 2),
                      Text(symbol.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB3A8FF))),
                      const SizedBox(height: 6),
                      Text('\$${_fmt(price)}',
                          style: const TextStyle(
                              fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ],
                  ),
                ),
                if (chg != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('今日', style: TextStyle(fontSize: 11, color: Colors.white38)),
                      const SizedBox(height: 4),
                      Text('${up ? '+' : ''}${chg!.toStringAsFixed(2)}%',
                          style: TextStyle(
                              color: chgColor, fontWeight: FontWeight.bold, fontSize: 22)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Stat(label: '52週高', value: _fmt(wkHigh), color: const Color(0xFF26A69A)),
                const SizedBox(width: 12),
                _Stat(label: '52週低', value: _fmt(wkLow), color: const Color(0xFFEF5350)),
                const SizedBox(width: 12),
                _Stat(label: '成交量', value: _fmtVol(volume), color: Colors.white70),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0E13),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.white38)),
            const SizedBox(height: 4),
            Text(value,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chart: neon line chart of closes + volume bars underneath
// ---------------------------------------------------------------------------
class _ChartCard extends StatelessWidget {
  final List<num> closes;
  final List<String> timestamps;
  final List<num> volumes;
  const _ChartCard({required this.closes, required this.timestamps, required this.volumes});

  @override
  Widget build(BuildContext context) {
    if (closes.isEmpty) {
      return const _Card(child: Padding(
        padding: EdgeInsets.all(20),
        child: Text('無歷史數據', textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54)),
      ));
    }
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 6, 4, 6),
            child: Text('價格走勢', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70)),
          ),
          SizedBox(
            height: 220,
            child: _LineChart(closes: closes, timestamps: timestamps, volumes: volumes),
          ),
        ],
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  final List<num> closes;
  final List<String> timestamps;
  final List<num> volumes;
  const _LineChart({required this.closes, required this.timestamps, required this.volumes});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (int i = 0; i < closes.length; i++)
        FlSpot(i.toDouble(), closes[i].toDouble()),
    ];
    final minY = closes.map((c) => c.toDouble()).reduce((a, b) => a < b ? a : b);
    final maxY = closes.map((c) => c.toDouble()).reduce((a, b) => a > b ? a : b);
    final pad = (maxY - minY) == 0 ? 1.0 : (maxY - minY) * 0.1;
    final n = closes.length;
    final step = (n / 5).ceil().clamp(1, n);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (n - 1).toDouble(),
        minY: minY - pad,
        maxY: maxY + pad,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: const Color(0xFF252A38),
            getTooltipItems: (touched) => [
              for (final t in touched)
                LineTooltipItem('\$${t.y.toStringAsFixed(2)}',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Color(0xFF1C1F27), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, meta) => Text(_fmt(v),
                  style: const TextStyle(color: Colors.white38, fontSize: 9)),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: step.toDouble(),
              getTitlesWidget: (v, meta) {
                final idx = v.round();
                if (idx < 0 || idx >= timestamps.length) {
                  return const SizedBox.shrink();
                }
                final t = timestamps[idx];
                final label = t.length >= 10 ? t.substring(0, 10) : t;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(label,
                      style: const TextStyle(color: Colors.white38, fontSize: 9)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: const Color(0xFF00E5FF),
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF00E5FF).withOpacity(0.06),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Technical indicators: RSI / SMA20 / SMA50 / MACD + signals
// ---------------------------------------------------------------------------
class _TechCard extends StatelessWidget {
  final num? rsi;
  final num? sma20;
  final num? sma50;
  final num? macd;
  final num? macdSignal;
  final List<dynamic> signals;
  final num? lastClose;
  const _TechCard({
    required this.rsi, required this.sma20, required this.sma50,
    required this.macd, required this.macdSignal,
    required this.signals, required this.lastClose,
  });

  String _fmtNum(num? v) => v == null ? '—' : v.toStringAsFixed(2);
  String _fmtPrice(num? v) => (v == null || v == 0) ? '—' : '\$${_fmtNum(v)}';

  Color _rsiColor(num? v) {
    if (v == null) return Colors.white70;
    if (v >= 70) return const Color(0xFFEF5350); // overbought
    if (v <= 30) return const Color(0xFF26A69A);  // oversold
    return const Color(0xFFFFD54F);
  }

  Color _smaColor(num? v) {
    if (v == null || lastClose == null) return Colors.white70;
    return v >= lastClose! ? const Color(0xFF26A69A) : const Color(0xFFEF5350);
  }

  Color _macdColor(num? v) {
    if (v == null) return Colors.white70;
    return v >= 0 ? const Color(0xFF26A69A) : const Color(0xFFEF5350);
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 6, 4, 10),
            child: Text('技術指標', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70)),
          ),
          Row(
            children: [
              _Metric(label: 'RSI', value: _fmtNum(rsi), color: _rsiColor(rsi)),
              _Metric(label: 'SMA 20', value: _fmtPrice(sma20), color: _smaColor(sma20)),
              _Metric(label: 'SMA 50', value: _fmtPrice(sma50), color: _smaColor(sma50)),
              _Metric(label: 'MACD', value: macdSignal != null
                      ? '${_fmtNum(macd)} / ${_fmtNum(macdSignal)}'
                      : _fmtNum(macd),
                  color: _macdColor(macd)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFF1C1F27)),
          const SizedBox(height: 8),
          const Text('訊號', style: TextStyle(fontSize: 12, color: Colors.white54)),
          const SizedBox(height: 6),
          ..._renderSignals(),
        ],
      ),
    );
  }

  List<Widget> _renderSignals() {
    if (signals.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('暫無技術訊號', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ),
      ];
    }
    return [
      for (final s in signals)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _signalDot(s),
              const SizedBox(width: 8),
              Expanded(child: Text(_signalText(s),
                  style: const TextStyle(fontSize: 12, color: Colors.white70))),
            ],
          ),
        ),
    ];
  }

  String _signalText(dynamic s) {
    if (s is Map) {
      final m = s.cast<String, dynamic>();
      final t = m['signal'] ?? m['label'] ?? m['type']
          ?? m['text'] ?? m['message'];
      if (t != null) {
        final lvl = m['level'] ?? m['strength'];
        return lvl != null ? '$t ($lvl)' : '$t';
      }
      return m.values.join(' · ');
    }
    return '$s';
  }

  Widget _signalDot(dynamic s) {
    var up = false;
    var down = false;
    if (s is Map) {
      final m = s.cast<String, dynamic>();
      final val = '${m['signal'] ?? m['type'] ?? m['action'] ?? ''}'.toLowerCase();
      up = val.contains('buy') || val.contains('bull') || val.contains('over') == false && val.contains('long');
      down = val.contains('sell') || val.contains('bear') || val.contains('short');
      // neutral if neither
    } else {
      final val = '$s'.toLowerCase();
      up = val.contains('buy') || val.contains('bull');
      down = val.contains('sell') || val.contains('bear');
    }
    final color = up ? const Color(0xFF26A69A)
        : down ? const Color(0xFFEF5350)
        : const Color(0xFFFFD54F);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      width: 8, height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Metric({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0E13),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
            const SizedBox(height: 4),
            Text(value,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// shared bits
// ---------------------------------------------------------------------------
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFF151820),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: child,
    );
  }
}

String _fmt(num? v) {
  if (v == null) return '—';
  final d = v.toDouble().abs();
  if (d >= 1000) {
    return v.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
  return v.toStringAsFixed(v == v.roundToDouble() ? 2 : 2);
}

String _fmtVol(num? v) {
  if (v == null) return '—';
  final d = v.toDouble();
  if (d >= 1e9) return '${(d / 1e9).toStringAsFixed(2)}B';
  if (d >= 1e6) return '${(d / 1e6).toStringAsFixed(2)}M';
  if (d >= 1e3) return '${(d / 1e3).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}