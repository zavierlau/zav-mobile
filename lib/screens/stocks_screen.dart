import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/config.dart';
import '../screens/settings_screen.dart';

class StocksScreen extends StatefulWidget {
  const StocksScreen({super.key});
  @override
  State<StocksScreen> createState() => _StocksScreenState();
}

class _StocksScreenState extends State<StocksScreen> {
  List<Stock> _stocks = [];
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
  bool _reloadIfTokenJustSet() {
    if (!_hadToken && Api.token.isNotEmpty) {
      _hadToken = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
      return true;
    }
    return false;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dynamic raw = await Api.get('/api/stocks');
      final List<Stock> stocks = _parseStocks(raw);
      if (mounted) setState(() => _stocks = stocks);
    } catch (e) {
      if (mounted) setState(() => _error = '載入失敗：$e\n\n請檢查 Base URL 同 Token 是否正確。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Tolerate: [{...}] or {"stocks":[{...}]} or {"data":[{...}]}.
  List<Stock> _parseStocks(dynamic raw) {
    final List<dynamic> list = _extractList(raw, 'stocks');
    return list.map(Stock.fromJson).where((s) => s.symbol.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (Api.token.isNotEmpty) _reloadIfTokenJustSet();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('股票行情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '設定',
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Api.token.isEmpty ? const _LoginGate() : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _stocks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _stocks.isEmpty) {
      return _ErrorView(error: _error!, retry: _load);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: _stocks.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 300,
                  child: _error != null
                      ? _ErrorView(error: _error!, retry: _load)
                      : const Center(child: Text('暫無股票數據', style: TextStyle(color: Colors.white54))),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _stocks.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF1C1F27)),
              itemBuilder: (context, i) => _StockRow(stock: _stocks[i]),
            ),
    );
  }
}

class _LoginGate extends StatefulWidget {
  const _LoginGate();
  @override
  State<_LoginGate> createState() => _LoginGateState();
}

class _LoginGateState extends State<_LoginGate> {
  final _baseCtrl = TextEditingController(text: Api.baseUrl);
  final _tokenCtrl = TextEditingController();
  bool _saving = false;
  String? _err;

  @override
  void dispose() {
    _baseCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _err = null;
    });
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      setState(() {
        _err = '請輸入 Token';
        _saving = false;
      });
      return;
    }
    await Config.save(baseUrl: _baseCtrl.text, token: token);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_open, size: 52, color: Color(0xFF7C6CF0)),
            const SizedBox(height: 12),
            const Text('連接 Dashboard',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('輸入 Base URL 同 Token 以載入股票數據。',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            TextField(
              controller: _baseCtrl,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                hintText: 'http://100.126.80.55:3000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _tokenCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Token',
                border: OutlineInputBorder(),
              ),
            ),
            if (_err != null) ...[
              const SizedBox(height: 10),
              Text(_err!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('儲存並載入'),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              child: const Text('進階設定'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  final Stock stock;
  const _StockRow({required this.stock});

  @override
  Widget build(BuildContext context) {
    final up = stock.chg >= 0;
    final color = up ? const Color(0xFF26A69A) : const Color(0xFFEF5350);
    final label = stock.name.isNotEmpty ? stock.name : stock.symbol;
    return ListTile(
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      subtitle: Text('${stock.symbol}  \$${_fmt(stock.price)}',
          style: const TextStyle(color: Colors.white54)),
      trailing: Text(
        '${up ? '+' : ''}${_fmt(stock.chg)}%',
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  String _fmt(num v) {
    if (v == v.roundToDouble() && v.abs() < 1e9) return v.toStringAsFixed(v is double ? 2 : 0);
    return v.toStringAsFixed(2);
  }
}

List<dynamic> _extractList(dynamic raw, String key) {
  if (raw is List) return raw.cast<dynamic>();
  if (raw is Map) {
    final k = raw.containsKey(key)
        ? key
        : (raw.containsKey('data') ? 'data' : null);
    if (k != null) {
      final v = raw[k];
      if (v is List) return v.cast<dynamic>();
    }
  }
  return <dynamic>[];
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback retry;
  const _ErrorView({required this.error, required this.retry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.orangeAccent, size: 40),
            const SizedBox(height: 12),
            // Show only first ~600 chars of any raw payload so nothing crashes UI.
            Text(error.length > 600 ? '${error.substring(0, 600)}…' : error,
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: retry, icon: const Icon(Icons.refresh), label: const Text('重試')),
          ],
        ),
      ),
    );
  }
}