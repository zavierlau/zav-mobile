import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api.dart';
import '../widgets/no_token_view.dart';

// Crypto screen: BTC / ETH cards from GET /api/crypto.
// Expected shape: {btc:{usd,chg24h}, eth:{usd,chg24h}}.
class CryptoScreen extends StatefulWidget {
  const CryptoScreen({super.key});
  @override
  State<CryptoScreen> createState() => _CryptoScreenState();
}

class _CryptoScreenState extends State<CryptoScreen> {
  List<CryptoCoin> _coins = [];
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
      final dynamic raw = await Api.get('/api/crypto');
      final List<CryptoCoin> coins = _parseCrypto(raw);
      if (mounted) {
        setState(() {
          _coins = coins;
          // Whole object not shaped as expected -> keep raw preview instead of crashing.
          if (coins.isEmpty && raw != null) _rawPreview = _truncate(raw);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '載入失敗：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Tolerate: {btc:{...},eth:{...}} or {data:{btc:{...},eth:{...}}} or [...] of entries.
  List<CryptoCoin> _parseCrypto(dynamic raw) {
    Map<String, dynamic>? map;
    if (raw is Map) {
      map = raw.cast<String, dynamic>();
      // unwrap {data:{...}}
      if (map.containsKey('data') && map['data'] is Map) {
        map = (map['data'] as Map).cast<String, dynamic>();
      }
    } else if (raw is List) {
      // [{symbol,usd,chg24h}, ...]
      final out = <CryptoCoin>[];
      for (final e in raw) {
        if (e is Map) {
          final m = e.cast<String, dynamic>();
          final sym = '${m['symbol'] ?? m['coin'] ?? ''}'.toUpperCase();
          if (sym.isNotEmpty) {
            out.add(CryptoCoin(
              sym,
              (m['usd'] ?? m['price'] ?? 0) as num,
              (m['chg24h'] ?? 0) as num,
            ));
          }
        }
      }
      return out;
    } else {
      return const [];
    }
    const order = ['btc', 'eth', 'bitcoin', 'ethereum'];
    final out = <CryptoCoin>[];
    final keys = <String>[
      ...order,
      ...map.keys.where((k) => !order.contains(k)),
    ];
    outer:
    for (final key in keys) {
      final v = map[key];
      if (v is! Map) continue;
      final m = v.cast<String, dynamic>();
      final usd = m['usd'] ?? m['price'];
      if (usd == null && m['chg24h'] == null) continue;
      final sym = key.toUpperCase();
      out.add(CryptoCoin(
        sym,
        (usd ?? 0) as num,
        (m['chg24h'] ?? m['change'] ?? 0) as num,
      ));
      if (out.length >= 2) break outer;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (Api.token.isNotEmpty) _reloadIfTokenJustSet();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('加密貨幣')),
      body: Api.token.isEmpty
          ? const NoTokenView(title: '需要 Token 先可載入加密數據')
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _coins.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _coins.isEmpty) {
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
    if (_coins.isEmpty && _rawPreview == null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
          SizedBox(height: 200),
          Center(child: Text('暫無加密貨幣數據', style: TextStyle(color: Colors.white54))),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          ..._coins.map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _CoinCard(coin: c),
              )),
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

class CryptoCoin {
  final String symbol;
  final num usd;
  final num chg24h;
  const CryptoCoin(this.symbol, this.usd, this.chg24h);
}

class _CoinCard extends StatelessWidget {
  final CryptoCoin coin;
  const _CoinCard({required this.coin});

  @override
  Widget build(BuildContext context) {
    final up = coin.chg24h >= 0;
    final color = up ? const Color(0xFF26A69A) : const Color(0xFFEF5350);
    return Card(
      color: const Color(0xFF151820),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF7C6CF0).withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Text(
                coin.symbol.length >= 4 ? coin.symbol.substring(0, 3) : coin.symbol,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFB3A8FF)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(coin.symbol.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('\$${_fmt(coin.usd)}',
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('24h',
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
                const SizedBox(height: 4),
                Text(
                  '${up ? '+' : ''}${coin.chg24h.toStringAsFixed(2)}%',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(num v) {
    if (v > 100) {
      return v.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    }
    return v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);
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