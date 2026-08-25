import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/config.dart';
import 'pod_terminal_screen.dart';

// ── Sci-fi HUD 配色（暗黑 + 霓虹青 / 霓虹紫 accent）──────────────────
const Color _kNeonBg = Color(0xFF05070D); // 深空底
const Color _kNeonCyan = Color(0xFF00E5FF); // 主要 accent 霓虹青
const Color _kNeonPurple = Color(0xFFB85CFF); // 次要 accent 霓虹紫
const Color _kNeonPurple2 = Color(0xFF7C6CF0); // 輔助紫
const Color _kGlass = Color(0xFF0D1520); // 玻璃半透明卡底
const Color _kTerminalBg = Color(0xFF04060C); // 終端黑底
const Color _kGreenTerm = Color(0xFF9BE29B); // k9s 式綠色 terminal 字
const Color _kCyanTerm = Color(0xFF7DE8FF); // 科幻青色 terminal 字
const Color _kNeonRed = Color(0xFFFF4D6D); // 失敗
const Color _kNeonYellow = Color(0xFFFFC44D); // 待定

// kubenav 式 Kubernetes cluster 管理（Sci-fi HUD 風格）。
// 目前未有真 cluster：UI 已準備好資源清單 / 詳情 / logs 概念，資料源透過
// /api/k8s/resources?type=... 讀取；未能抓到就顯示「未連接 cluster」友善空狀態，
// 並可前往「連接 Cluster」設定位 或「載入示範資料」預覽 UI。
class K8sScreen extends StatefulWidget {
  const K8sScreen({super.key});
  @override
  State<K8sScreen> createState() => _K8sScreenState();
}

class _K8sScreenState extends State<K8sScreen> {
  static const _types = <_ResourceType>[
    _ResourceType('Deployments', 'deployments', Icons.dehaze),
    _ResourceType('Pods', 'pods', Icons.crop_square),
    _ResourceType('Services', 'services', Icons.hub_outlined),
    _ResourceType('StatefulSets', 'statefulsets', Icons.view_agenda_outlined),
    _ResourceType('ConfigMaps', 'configmaps', Icons.tune),
    _ResourceType('Secrets', 'secrets', Icons.lock_outline),
  ];

  late _ResourceType _type = _types.first;
  List<K8sResource> _resources = [];
  bool _loading = false;
  bool _disconnected = false;
  String? _error;

  // G-Brain 式資源節點網絡圖摺疊狀態。
  bool _networkCollapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  // true = 有 cluster 連線設定；false = 從未連接（直接顯示空狀態，唔打 API）。
  bool get _hasConnection =>
      Config.kubeconfig.isNotEmpty || Config.k8sServer.isNotEmpty;

  // 依任務要求嘗試 Api.get('/api/k8s/resources?type=<type>')。
  // 從未連接 → 唔打 API，直接顯示「未連接」友善空狀態。
  // 已設定但 API fail / 唔通 → 顯示「未連接 cluster 或 API 未準備」。
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _disconnected = false;
      _error = null;
    });
    if (!_hasConnection) {
      // No cluster config yet — auto-load demo data so the UI is immediately
      // visible (no manual "load demo" tap needed). Shows label "示範".
      _loadDemo();
      return;
    }
    try {
      final raw = await Api.get(
          '/api/k8s/resources?type=${_type.apiName}');
      final items = _extractResources(raw);
      if (!mounted) return;
      setState(() {
        _resources = items;
        _disconnected = items.isEmpty;
      });
    } catch (e) {
      // 未有真 cluster 或 API 未準備 → 唔 crash，顯示友善空狀態。
      if (!mounted) return;
      setState(() {
        _resources = [];
        _disconnected = true;
        _error = '未連接 cluster 或 API 未準備：$e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 載入示範資料，令 UI 喺未有真 cluster 時都可見。
  void _loadDemo() {
    setState(() {
      _resources = _demoResources(_type);
      _disconnected = false;
      _error = null;
      _loading = false;
    });
  }

  Future<void> _reloadAfterConnect() async {
    await Config.loadK8s();
    if (mounted) await _load();
  }

  Future<void> _openConnectSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kNeonBg,
      barrierColor: Colors.black.withOpacity(0.7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _K8sConnectSheet(),
    );
    await _reloadAfterConnect();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kNeonBg,
      appBar: AppBar(
        backgroundColor: _kNeonBg,
        elevation: 0,
        foregroundColor: Colors.white,
        flexibleSpace: _bottomGlowLine(),
        title: Row(
          children: [
            const Icon(Icons.dns, size: 22, color: _kNeonCyan),
            const SizedBox(width: 10),
            const Text(
              'KUBERNETES',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
            if (!_hasConnection) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kNeonCyan, _kNeonPurple],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: _kNeonCyan.withOpacity(0.4), blurRadius: 8),
                  ],
                ),
                child: const Text('示範',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.black)),
              ),
            ],
            if (_resources.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _kGlass,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kNeonCyan.withOpacity(0.4)),
                ),
                child: Text(
                  '${_resources.length}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    letterSpacing: 1,
                    color: _kNeonCyan,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: '連接 Cluster',
            icon: const Icon(Icons.cloud_outlined, color: _kNeonCyan),
            onPressed: _openConnectSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeaderBar(),
          _buildTypeChips(),
          const SizedBox(height: 4),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // 底部一道霓虹漸層微光（AppBar 底部亮線）。
  Widget _bottomGlowLine() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 1.5,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_kNeonCyan, Colors.transparent, _kNeonPurple],
          ),
          boxShadow: [BoxShadow(color: _kNeonCyan.withOpacity(0.5), blurRadius: 8)],
        ),
      ),
    );
  }

  // Header：cyan 微字型 + mono 資源計數，營造 HUD 感。
  Widget _buildHeaderBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Text(
            '// ${_type.label.toUpperCase()}',
            style: TextStyle(
              color: _kNeonCyan.withOpacity(0.7),
              fontSize: 11,
              fontFamily: 'monospace',
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          if (_loading)
            const Text(
              '▚ SYNCING',
              style: TextStyle(
                  color: _kNeonPurple, fontSize: 10, fontFamily: 'monospace',
                  letterSpacing: 1.5),
            )
          else
            Text(
              '${_resources.length.toString().padLeft(2, '0')} RESOURCES',
              style: TextStyle(
                color: _kNeonPurple.withOpacity(0.8),
                fontSize: 10,
                fontFamily: 'monospace',
                letterSpacing: 1.5,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeChips() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _types.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final t = _types[i];
          final selected = t == _type;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: _kNeonCyan.withOpacity(0.45),
                          blurRadius: 10,
                          spreadRadius: 0.5),
                    ]
                  : const [],
            ),
            child: ChoiceChip(
              label: Text(
                t.label,
                style: TextStyle(
                  color: selected ? _kNeonCyan : Colors.white60,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  letterSpacing: 0.5,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              avatar: Icon(t.icon,
                  size: 15, color: selected ? _kNeonCyan : Colors.white38),
              selected: selected,
              selectedColor: _kGlass,
              backgroundColor: _kGlass,
              checkmarkColor: _kNeonCyan,
              showCheckmark: false,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              side: BorderSide(
                color: selected ? _kNeonCyan : Colors.white12,
                width: selected ? 1.4 : 1,
              ),
              onSelected: (_) {
                setState(() => _type = t);
                _load();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    final Widget content;
    if (_loading) {
      content = const Center(
        child: CircularProgressIndicator(
            color: _kNeonCyan, strokeWidth: 2.5),
      );
    } else if (_disconnected) {
      content = RefreshIndicator(
        color: _kNeonCyan,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 48),
            const Icon(Icons.cloud_off,
                size: 72, color: _kNeonCyan),
            const SizedBox(height: 16),
            Text(
              _hasConnection ? '未連接 Cluster 或 API 未準備' : '尚未連接 Cluster',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold,
                  letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            Text(
              _hasConnection
                  ? '未能從 dashboard 讀取 ${_type.label}。請確認 /api/k8s/resources 已準備好。'
                  : '定義一個 cluster（匯入 kubeconfig 或輸入 server + token），就可開始管理 Kubernetes 資源。',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, height: 1.5),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _kNeonRed, fontSize: 12, fontFamily: 'monospace'),
              ),
            ],
            const SizedBox(height: 28),
            Center(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: _kNeonCyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: _openConnectSheet,
                icon: const Icon(Icons.add_link),
                label: const Text('新增 / 連接 Cluster',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: _loadDemo,
                icon: const Icon(Icons.preview, color: _kNeonPurple),
                label: const Text('載入示範資料預覽',
                    style: TextStyle(color: _kNeonPurple)),
              ),
            ),
          ],
        ),
      );
    } else if (_resources.isEmpty) {
      content = RefreshIndicator(
        color: _kNeonCyan,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(child: Text('暫無資源', style: TextStyle(color: Colors.white54))),
          ],
        ),
      );
    } else {
      // ══════ G-Brain 資源節點網絡圖 + 下面保留實用資源 list ══════
      content = RefreshIndicator(
        color: _kNeonCyan,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          children: [
            _NetworkHeader(
              count: _resources.length,
              collapsed: _networkCollapsed,
              onToggle: () =>
                  setState(() => _networkCollapsed = !_networkCollapsed),
            ),
            if (!_networkCollapsed) ...[
              const SizedBox(height: 10),
              _ResourceNetworkCanvas(
                resources: _resources,
                type: _type,
                demo: !_hasConnection,
                onRefresh: _load,
              ),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 4),
            ..._resources.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ResourceCard(
                  resource: r,
                  type: _type,
                  demo: !_hasConnection,
                  onRefresh: _load,
                ),
              ),
            ),
          ],
        ),
      );
    }
    // G-Brain 動態背景光環 + 浮動粒子。放 content 上面做半透明浮層，
    // 確保粒子/光環一定可見（唔會被不透明卡片遮住）。
    return Stack(
      children: [
        content,
        Positioned.fill(
          child: IgnorePointer(
            child: _HUDOrbBackground(kind: _type.apiName),
          ),
        ),
      ],
    );
  }
}

class _ResourceType {
  final String label;
  final String apiName;
  final IconData icon;
  const _ResourceType(this.label, this.apiName, this.icon);
}

class K8sResource {
  final String name;
  final String namespace;
  final String status;
  final Map<String, String> labels;
  final bool healthy; // Running / Ready → 綠；否則灰。
  const K8sResource({
    required this.name,
    required this.namespace,
    required this.status,
    required this.labels,
    required this.healthy,
  });

  factory K8sResource.fromJson(dynamic j) {
    final m = j is Map ? j : {};
    final status = '${m['status'] ?? m['phase'] ?? ''}';
    final labels = <String, String>{};
    final rawLabels = m['labels'];
    if (rawLabels is Map) {
      rawLabels.forEach((k, v) => labels['$k'] = '$v');
    }
    final healthy = _isHealthy(status);
    return K8sResource(
      name: '${m['name'] ?? ''}',
      namespace: '${m['namespace'] ?? 'default'}',
      status: status,
      labels: labels,
      healthy: healthy,
    );
  }

  static bool _isHealthy(String status) {
    final s = status.toLowerCase();
    if (s.contains('running')) return true;
    if (s.contains('ready')) return true;
    if (s.contains('available')) return true;
    if (s.contains('complete')) return true;
    return false;
  }
}

// 由 status string 決定霓虹狀態色 + tooltip（Running 青 / 待定黃 / 失敗紅）。
(Color, String) _statusHue(String status, bool healthy) {
  final s = status.toLowerCase();
  if (s.contains('fail') ||
      s.contains('error') ||
      s.contains('crash') ||
      s.contains('backoff') ||
      s.contains('terminated') ||
      s.contains('unschedulable')) {
    return (_kNeonRed, '失敗');
  }
  if (s.contains('pending') ||
      s.contains('creating') ||
      s.contains('initializing') ||
      s.contains('containercreating') ||
      s.contains('terminating')) {
    return (_kNeonYellow, '待定');
  }
  if (s.contains('running') ||
      s.contains('ready') ||
      s.contains('available') ||
      s.contains('complete') ||
      s.contains('succeeded')) {
    return (_kNeonCyan, 'Running / Ready');
  }
  return (healthy ? _kNeonCyan : _kNeonYellow, healthy ? 'Running / Ready' : '未知');
}

class _ResourceCard extends StatelessWidget {
  final K8sResource resource;
  final _ResourceType type;
  final bool demo;
  final VoidCallback? onRefresh;
  const _ResourceCard({
    required this.resource,
    required this.type,
    this.demo = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // 外層：1px 霓虹漸層描邊 + depth glow shadow
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [_kNeonCyan, _kNeonPurple2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _kNeonCyan.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: _kNeonPurple.withOpacity(0.10),
            blurRadius: 22,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Material(
            color: _kGlass,
            child: InkWell(
              onTap: () => _showDetail(context),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _StatusDot(healthy: resource.healthy, status: resource.status),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resource.name.isEmpty ? '（未命名）' : resource.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.folder_outlined,
                                  size: 13, color: Colors.white38),
                              const SizedBox(width: 4),
                              Text(resource.namespace,
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.white60)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            resource.status.isEmpty ? type.label : resource.status,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              letterSpacing: 0.3,
                              color: resource.healthy
                                  ? _kNeonCyan.withOpacity(0.9)
                                  : Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white38),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    _showResourceDetailSheet(context, resource, type,
        demo: demo, onRefresh: onRefresh);
  }
}

class _StatusDot extends StatelessWidget {
  final bool healthy;
  final String status;
  const _StatusDot({required this.healthy, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = _statusHue(status, healthy);
    return Tooltip(
      message: label,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.7), blurRadius: 8, spreadRadius: 1),
          ],
        ),
      ),
    );
  }
}

class _ResourceDetailSheet extends StatefulWidget {
  final K8sResource resource;
  final _ResourceType type;
  final bool demo;
  final VoidCallback? onRefresh;
  const _ResourceDetailSheet({
    required this.resource,
    required this.type,
    this.demo = false,
    this.onRefresh,
  });
  @override
  State<_ResourceDetailSheet> createState() => _ResourceDetailSheetState();
}

class _ResourceDetailSheetState extends State<_ResourceDetailSheet> {
  final TextEditingController _yamlCtrl = TextEditingController();

  bool _busy = false;
  bool _activeYaml = false; // which result panel is being shown
  bool _demoResult = false;
  String? _message; // info / error / 未連接 cluster
  String? _yaml;
  String? _logs;

  _ResourceType get type => widget.type;
  K8sResource get resource => widget.resource;
  bool get _isPod => type.apiName == 'pods'; // logs / exec 僅限 Pod

  @override
  void dispose() {
    _yamlCtrl.dispose();
    super.dispose();
  }

  // 構造含 query 嘅 action path（用 Api.get 帶 query 讀取）。
  String _actionPath(String op) {
    final q = <String, String>{
      'op': op,
      'kind': type.label,
      if (resource.name.isNotEmpty) 'name': resource.name,
      if (resource.namespace.isNotEmpty) 'namespace': resource.namespace,
    };
    return '/api/k8s/action?${Uri(queryParameters: q).query}';
  }

  // 統一檢查：connected:false → 「未連接 cluster」；ok:false → 錯誤訊息。
  // 有訊息就 setState 並回傳 true（表示要停手）。
  bool _guardFailure(dynamic raw, String actionName) {
    String? msg;
    final m = raw is Map ? raw : const <String, dynamic>{};
    if (m['connected'] == false) {
      msg = '未連接 cluster';
    } else if (m['ok'] == false) {
      final err = m['error'] ?? m['message'];
      msg = err is String && err.isNotEmpty ? '$actionName失敗：$err' : '$actionName失敗';
    }
    if (msg != null) {
      setState(() {
        _message = msg;
        _activeYaml = false;
        _yaml = null;
        _logs = null;
        _demoResult = false;
        _busy = false;
      });
      return true;
    }
    return false;
  }

  Future<void> _fetchYaml() async {
    setState(() => _busy = true);
    try {
      if (widget.demo) {
        setState(() {
          _yaml = _demoYaml();
          _logs = null;
          _message = null;
          _activeYaml = true;
          _demoResult = true;
          _busy = false;
        });
        return;
      }
      final raw = await Api.get(_actionPath('get'));
      if (!mounted) return;
      if (_guardFailure(raw, '讀取 YAML')) return;
      final y = raw is Map ? raw['yaml'] : null;
      setState(() {
        _yaml = y is String ? y : '（無 YAML）';
        _logs = null;
        _message = null;
        _activeYaml = true;
        _demoResult = false;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = '讀取 YAML 失敗：$e';
        _activeYaml = false;
        _busy = false;
      });
    }
  }

  Future<void> _applyYaml() async {
    setState(() => _busy = true);
    try {
      final raw = await Api.post('/api/k8s/action', {
        'op': 'apply',
        'yaml': _yamlCtrl.text,
      });
      if (!mounted) return;
      if (_guardFailure(raw, '套用')) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('YAML 已套用，已刷新')),
      );
      widget.onRefresh?.call();
      setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('套用失敗：$e')),
      );
    }
  }

  Future<void> _fetchLogs() async {
    if (!_isPod) {
      setState(() {
        _message = '只有 Pod 有 logs';
        _activeYaml = false;
        _yaml = null;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      if (widget.demo) {
        setState(() {
          _logs = _demoLogs();
          _yaml = null;
          _message = null;
          _activeYaml = false;
          _demoResult = true;
          _busy = false;
        });
        return;
      }
      final raw = await Api.get(_actionPath('logs'));
      if (!mounted) return;
      if (_guardFailure(raw, '讀取 Logs')) return;
      final l = raw is Map ? raw['logs'] : null;
      setState(() {
        _logs = l is String ? l : '（無日誌）';
        _yaml = null;
        _message = null;
        _activeYaml = false;
        _demoResult = false;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = '讀取 Logs 失敗：$e';
        _activeYaml = false;
        _busy = false;
      });
    }
  }

  Future<void> _runExec() async {
    if (!_isPod) return; // 按鈕已禁用；雙重保險
    if (widget.demo) return; // 示範模式無 terminal-server，唔開 terminal
    // 全屏互動 Terminal（WS → kubectl exec）
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PodTerminalScreen(
        podName: resource.name,
        namespace: resource.namespace,
      ),
    ));
  }

  // ── 示範（demo）假資料 —────────────────────────────────────────
  String _demoYaml() {
    return 'apiVersion: apps/v1\n'
        'kind: ${type.label}\n'
        'metadata:\n'
        '  name: ${resource.name}\n'
        '  namespace: ${resource.namespace}\n'
        '  labels:\n'
        '    app: demo\n'
        'spec:\n'
        '  replicas: 2\n'
        '  selector:\n'
        '    matchLabels:\n'
        '      app: demo\n'
        '  template:\n'
        '    metadata:\n'
        '      labels:\n'
        '        app: demo\n'
        '    spec:\n'
        '      containers:\n'
        '      - name: main\n'
        '        image: nginx:1.25\n'
        '        ports:\n'
        '        - containerPort: 8080\n';
  }

  String _demoLogs() {
    return '2026-08-25 10:00:01 INFO  container ready\n'
        '2026-08-25 10:00:02 INFO  Started HTTP server on 0.0.0.0:8080\n'
        '2026-08-25 10:00:05 DEBUG healthz ok\n'
        '2026-08-25 10:00:11 INFO  GET /stats 200 4ms\n'
        '2026-08-25 10:00:12 INFO  worker tick processed 42\n'
        '2026-08-25 10:00:14 DEBUG connection pool size=4\n';
  }

  @override
  Widget build(BuildContext context) {
    final demo = widget.demo || _demoResult;
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(type.icon, color: _kNeonCyan),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      resource.name.isEmpty ? '（未命名）' : resource.name,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5),
                    ),
                  ),
                  _StatusDot(healthy: resource.healthy, status: resource.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(type.label,
                  style: const TextStyle(
                      color: _kNeonPurple,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      letterSpacing: 1.5)),
              const SizedBox(height: 12),
              // 動作按鈕列：YAML / Logs / Exec
              Row(
                children: [
                  _actionButton('📝', 'YAML', _fetchYaml),
                  _actionButton('🖥', 'LOGS', _isPod ? _fetchLogs : null),
                  _actionButton('▶', 'EXEC', _isPod ? _runExec : null),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _DetailRow(label: 'TYPE', value: type.label),
                    _DetailRow(label: 'NAME', value: resource.name),
                    _DetailRow(label: 'NAMESPACE', value: resource.namespace),
                    _DetailRow(label: 'STATUS', value: resource.status),
                    if (resource.labels.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('// LABELS',
                          style: TextStyle(
                              color: _kNeonCyan,
                              fontSize: 11,
                              fontFamily: 'monospace',
                              letterSpacing: 1.5)),
                      const SizedBox(height: 6),
                      ...resource.labels.entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _kGlass,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: _kNeonPurple.withOpacity(0.35)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.label_outline,
                                    size: 14, color: _kNeonCyan),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${e.key}=${e.value}',
                                    style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildActionPanel(demo),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kNeonCyan,
                    side: BorderSide(color: _kNeonCyan.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('關閉'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String emoji, String label, VoidCallback? onTap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: onTap == null ? Colors.white24 : _kNeonCyan,
            side: BorderSide(
                color: onTap == null
                    ? Colors.white12
                    : _kNeonCyan.withOpacity(0.6)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text('$emoji $label',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  letterSpacing: 0.5)),
        ),
      ),
    );
  }

  // 結果區：錯誤 / 未連接 / YAML 編輯器 / Logs / Exec 輸出。
  Widget _buildActionPanel(bool demo) {
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
            child:
                CircularProgressIndicator(color: _kNeonCyan, strokeWidth: 2.5)),
      );
    }
    if (_message != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kGlass,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orangeAccent.withOpacity(0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline,
                size: 18, color: Colors.orangeAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _message!,
                style: const TextStyle(
                    color: Colors.orangeAccent, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }
    if (_activeYaml && _yaml != null) {
      // 可編輯 YAML editor（monospace）
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_yamlCtrl.text != _yaml) _yamlCtrl.text = _yaml!;
      });
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelHeader('YAML', demo),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: _kTerminalBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kNeonCyan.withOpacity(0.4)),
            ),
            child: TextField(
              controller: _yamlCtrl,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: _kCyanTerm),
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                isCollapsed: true,
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: _kNeonCyan, foregroundColor: Colors.black),
              onPressed: _busy ? null : _applyYaml,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('💾 套用',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      );
    }
    if (_logs != null) {
      return _terminalPanel('LOGS', _logs!, demo, textColor: _kGreenTerm);
    }
    // 預設提示
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text('⏵ 撳上方按鈕查看 YAML / Logs / 執行命令',
            style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontFamily: 'monospace')),
      ),
    );
  }

  // Panel 標題列：cyan mono 微字 + 「示範」徽章。
  Widget _panelHeader(String title, bool demo) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                color: _kNeonCyan,
                fontSize: 12,
                fontFamily: 'monospace',
                letterSpacing: 1.5)),
        if (demo) ...[
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_kNeonCyan, _kNeonPurple]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('示範',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.black)),
          ),
        ],
      ],
    );
  }

  // Monospace 暗黑終端顯示（logs / exec 輸出共用），藍/綠霓虹描邊。
  Widget _terminalPanel(String title, String text, bool demo,
      {Color textColor = _kCyanTerm}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panelHeader(title, demo),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 240),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kTerminalBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kNeonCyan.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(color: _kNeonCyan.withOpacity(0.08), blurRadius: 8),
            ],
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: textColor,
                  height: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
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
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    color: _kNeonPurple2,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    letterSpacing: 1)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                  color: Colors.white70, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 連接 Cluster 設定位 ──────────────────────────────────────────────
class _K8sConnectSheet extends StatefulWidget {
  const _K8sConnectSheet();
  @override
  State<_K8sConnectSheet> createState() => _K8sConnectSheetState();
}

class _K8sConnectSheetState extends State<_K8sConnectSheet> {
  late final TextEditingController _kubeconfigCtrl;
  late final TextEditingController _serverCtrl;
  late final TextEditingController _tokenCtrl;

  @override
  void initState() {
    super.initState();
    _kubeconfigCtrl = TextEditingController(text: Config.kubeconfig);
    _serverCtrl = TextEditingController(text: Config.k8sServer);
    _tokenCtrl = TextEditingController(text: Config.k8sToken);
  }

  @override
  void dispose() {
    _kubeconfigCtrl.dispose();
    _serverCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await Config.saveK8s(
      kubeconfig: _kubeconfigCtrl.text,
      server: _serverCtrl.text,
      token: _tokenCtrl.text,
    );
    await Config.loadK8s();
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cluster 連線設定已儲存')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cloud_done, color: _kNeonCyan),
                SizedBox(width: 10),
                Text('連接 CLUSTER',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '用其中一種方式接入：匯入 kubeconfig，或輸入 cluster server + token。'
              '設定會存去裝置（shared_preferences），之後用作連接 dashboard /api/k8s。',
              style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            const Text('— 01 — KUBECONFIG',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _kNeonCyan,
                    fontFamily: 'monospace',
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            TextField(
              controller: _kubeconfigCtrl,
              maxLines: 6,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: InputDecoration(
                hintText: '貼上 kubeconfig YAML…',
                filled: true,
                fillColor: _kGlass,
                enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: _kNeonCyan.withOpacity(0.4))),
                border: const OutlineInputBorder(
                    borderSide: BorderSide(color: _kNeonCyan)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('— 02 — SERVER + TOKEN',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _kNeonCyan,
                    fontFamily: 'monospace',
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            TextField(
              controller: _serverCtrl,
              keyboardType: TextInputType.url,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Cluster Server IP / URL',
                labelStyle: const TextStyle(color: _kNeonCyan),
                hintText: 'https://192.168.1.10:6443',
                filled: true,
                fillColor: _kGlass,
                enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: _kNeonCyan.withOpacity(0.4))),
                border: const OutlineInputBorder(
                    borderSide: BorderSide(color: _kNeonCyan)),
                prefixIcon: const Icon(Icons.dns_outlined, color: _kNeonCyan),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenCtrl,
              obscureText: true,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Token',
                labelStyle: const TextStyle(color: _kNeonCyan),
                filled: true,
                fillColor: _kGlass,
                enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: _kNeonCyan.withOpacity(0.4))),
                border: const OutlineInputBorder(
                    borderSide: BorderSide(color: _kNeonCyan)),
                prefixIcon: const Icon(Icons.key_outlined, color: _kNeonCyan),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: _kNeonCyan, foregroundColor: Colors.black),
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('儲存連線設定',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── helper ───────────────────────────────────────────────────────────
List<K8sResource> _extractResources(dynamic raw) {
  List<dynamic> list;
  if (raw is List) {
    list = raw;
  } else if (raw is Map) {
    final items = raw['resources'] ?? raw['items'] ?? raw['data'];
    list = items is List ? items : <dynamic>[];
  } else {
    list = <dynamic>[];
  }
  return list
      .map(K8sResource.fromJson)
      .where((r) => r.name.isNotEmpty)
      .toList();
}

List<K8sResource> _demoResources(_ResourceType type) {
  const ns = 'default';
  switch (type.apiName) {
    case 'deployments':
      return const [
        K8sResource(
            name: 'web-frontend', namespace: ns, status: '2/2 Ready',
            labels: {'app': 'web', 'tier': 'frontend'}, healthy: true),
        K8sResource(
            name: 'api-gateway', namespace: ns, status: '1/2 Ready',
            labels: {'app': 'api'}, healthy: false),
        K8sResource(
            name: 'worker', namespace: 'batch', status: '3/3 Ready',
            labels: {'app': 'worker'}, healthy: true),
      ];
    case 'pods':
      return const [
        K8sResource(
            name: 'web-frontend-7b6f9c-4x2kq', namespace: ns,
            status: 'Running', labels: {'app': 'web', 'pod-template-hash': '7b6f9c'},
            healthy: true),
        K8sResource(
            name: 'api-gateway-55dfc-r8xm1', namespace: ns,
            status: 'CrashLoopBackOff', labels: {'app': 'api'},
            healthy: false),
        K8sResource(
            name: 'redis-0', namespace: 'cache', status: 'Running',
            labels: {'app': 'redis'}, healthy: true),
      ];
    case 'services':
      return const [
        K8sResource(
            name: 'web-frontend', namespace: ns, status: 'ClusterIP 10.96.0.10',
            labels: {'app': 'web'}, healthy: true),
        K8sResource(
            name: 'db', namespace: 'data', status: 'ExternalName',
            labels: {}, healthy: true),
      ];
    case 'statefulsets':
      return const [
        K8sResource(
            name: 'redis', namespace: 'cache', status: '2/2 Ready',
            labels: {'app': 'redis'}, healthy: true),
      ];
    case 'configmaps':
      return const [
        K8sResource(
            name: 'app-config', namespace: ns, status: '1 map',
            labels: {'app': 'config'}, healthy: true),
      ];
    case 'secrets':
      return const [
        K8sResource(
            name: 'db-credentials', namespace: ns, status: 'Opaque',
            labels: {}, healthy: true),
      ];
    default:
      return const [];
  }
}

// ═══════════════════════════════════════════════════════════════════════
// G-Brain 式動態視覺（FounderOS G-Brain：旋轉光環 + 外圍浮動粒子 + 節點網絡圖）
// ═══════════════════════════════════════════════════════════════════════

// 依資源 kind 決定節點色：Deployment=cyan Pod=purple Service=green
// ConfigMap=yellow Secret=red；其餘（StatefulSets 等）用紫灰。
Color _kindColor(String apiName) {
  switch (apiName) {
    case 'deployments':
      return _kNeonCyan;
    case 'pods':
      return _kNeonPurple;
    case 'services':
      return _kGreenTerm;
    case 'configmaps':
      return _kNeonYellow;
    case 'secrets':
      return _kNeonRed;
    default:
      return _kNeonPurple2;
  }
}

// 共用詳情 sheet（_ResourceCard 與網絡圖節點共用同一套詳情邏輯）。
void _showResourceDetailSheet(BuildContext context, K8sResource resource,
    _ResourceType type,
    {bool demo = false, VoidCallback? onRefresh}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: _kNeonBg,
    barrierColor: Colors.black.withOpacity(0.7),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _ResourceDetailSheet(
        resource: resource, type: type, demo: demo, onRefresh: onRefresh),
  );
}

String _shortLabel(String s, [int max = 13]) {
  final v = s.isEmpty ? '（未命名）' : s;
  return v.length <= max ? v : '${v.substring(0, max)}…';
}

// ── 1) 資源節點網絡圖（可摺疊標題列）──────────────────────────────────
class _NetworkHeader extends StatelessWidget {
  final int count;
  final bool collapsed;
  final VoidCallback onToggle;
  const _NetworkHeader({
    required this.count,
    required this.collapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _kGlass,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kNeonCyan.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(color: _kNeonCyan.withOpacity(0.06), blurRadius: 12),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.hub_outlined, color: _kNeonCyan, size: 20),
              const SizedBox(width: 10),
              const Text(
                'NETWORK · 資源節點網絡圖',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count',
                style: const TextStyle(
                  color: _kNeonCyan,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              Icon(
                collapsed
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_up,
                color: _kNeonCyan.withOpacity(0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 網絡節點（資源 + 畫布座標）。
class _NetNode {
  final K8sResource resource;
  final Offset center;
  final double radius;
  const _NetNode(this.resource, this.center, this.radius);
}

// 固定高度網絡圖畫布：CustomPaint 畫節點 + GestureDetector 撳節點睇詳情。
class _ResourceNetworkCanvas extends StatelessWidget {
  final List<K8sResource> resources;
  final _ResourceType type;
  final bool demo;
  final VoidCallback? onRefresh;
  const _ResourceNetworkCanvas({
    required this.resources,
    required this.type,
    this.demo = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final kindColor = _kindColor(type.apiName);
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF0C111C), Color(0xFF070A12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: _kNeonCyan.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(color: _kNeonCyan.withOpacity(0.08), blurRadius: 18),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final nodes = _computeNetworkNodes(size, resources);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) =>
                _onNodeTap(context, d.localPosition, nodes),
            child: CustomPaint(
              size: size,
              painter: _NetworkPainter(nodes: nodes, kindColor: kindColor),
            ),
          );
        },
      ),
    );
  }

  // 撳節點 → 重用詳情 sheet。搵最近（且於 hit-radius 內）節點。
  void _onNodeTap(
      BuildContext context, Offset local, List<_NetNode> nodes) {
    _NetNode? best;
    var bestHit = 40.0;
    for (final n in nodes) {
      final d = (n.center - local).distance;
      final threshold = n.radius + 12;
      if (d < threshold && d < bestHit) {
        bestHit = d;
        best = n;
      }
    }
    if (best != null) {
      _showResourceDetailSheet(context, best.resource, type,
          demo: demo, onRefresh: onRefresh);
    }
  }
}

// 放射狀佈局：節點圍繞中心分佈。為主圖美貌，最多顯示前 12 個節點。
List<_NetNode> _computeNetworkNodes(Size size, List<K8sResource> resources) {
  final shown = resources.length <= 12 ? resources : resources.take(12).toList();
  final n = shown.length;
  if (n == 0) return const [];
  final center = Offset(size.width / 2, size.height / 2 + 4);
  final radius = math.min(size.width, size.height) * 0.30;
  final nodeRadius = n <= 8 ? 21.0 : 16.0;
  final nodes = <_NetNode>[];
  for (var i = 0; i < n; i++) {
    final angle = -math.pi / 2 + (i * 2 * math.pi) / n;
    final pos = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    nodes.add(_NetNode(shown[i], pos, nodeRadius));
  }
  return nodes;
}

class _NetworkPainter extends CustomPainter {
  final List<_NetNode> nodes;
  final Color kindColor;
  _NetworkPainter({required this.nodes, required this.kindColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 4);
    // 背景參考數據環（G-Brain 感）
    final faintCircle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final r in [38.0, 64.0, math.min(size.width, size.height) * 0.42]) {
      faintCircle.color = _kNeonCyan.withOpacity(0.06);
      canvas.drawCircle(center, r, faintCircle);
    }
    if (nodes.isEmpty) {
      final tp = TextPainter(
        text: const TextSpan(
          text: '無資源節點',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
      return;
    }
    // 放射狀連線：中心 ↔ 每個節點
    for (final n in nodes) {
      canvas.drawLine(
        center,
        n.center,
        Paint()
          ..strokeWidth = 1
          ..color = kindColor.withOpacity(0.28),
      );
    }
    // 環狀連線：節點 ↔ 下一個節點（織網感）
    final ringPaint = Paint()
      ..strokeWidth = 1
      ..color = kindColor.withOpacity(0.14);
    for (var i = 0; i < nodes.length; i++) {
      final a = nodes[i];
      final b = nodes[(i + 1) % nodes.length];
      canvas.drawLine(a.center, b.center, ringPaint);
    }
    // 中心 hub 亮點
    canvas.drawCircle(
      center,
      3.4,
      Paint()
        ..color = kindColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(center, 1.4, Paint()..color = Colors.white);
    // 節點
    for (final n in nodes) {
      _drawNode(canvas, n);
    }
  }

  void _drawNode(Canvas canvas, _NetNode n) {
    final c = n.center;
    final r = n.radius;
    final healthy = n.resource.healthy;
    // glow
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = kindColor.withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // fill
    canvas.drawCircle(
      c,
      r,
      Paint()..color = kindColor.withOpacity(healthy ? 0.26 : 0.12),
    );
    // border
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = kindColor.withOpacity(healthy ? 0.9 : 0.45),
    );
    if (!healthy) {
      canvas.drawCircle(
        c,
        r + 3,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = _kNeonRed.withOpacity(0.85),
      );
    }
    // label（小字）
    final tp = TextPainter(
      text: TextSpan(
        text: _shortLabel(n.resource.name),
        style: TextStyle(
          color: healthy ? Colors.white70 : Colors.white38,
          fontSize: 9,
          fontFamily: 'monospace',
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c + Offset(-tp.width / 2, r + 6));
  }

  @override
  bool shouldRepaint(_NetworkPainter old) =>
      old.nodes != nodes || old.kindColor != kindColor;
}

// ── 2) 動態背景：旋轉光環 + 浮動粒子（G-Brain 科幻感）──────────────────
class _HUDOrbBackground extends StatefulWidget {
  final String kind;
  const _HUDOrbBackground({required this.kind});
  @override
  State<_HUDOrbBackground> createState() => _HUDOrbBackgroundState();
}

// 背景粒子（位置/大小/漂移/相位均隨機，緩慢漂移 + 微閃）。
class _OrbParticle {
  final double x, y, size, speed, phase, opacity;
  final Offset drift;
  final bool purple;
  const _OrbParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.phase,
    required this.opacity,
    required this.drift,
    required this.purple,
  });
}

class _HUDOrbBackgroundState extends State<_HUDOrbBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_OrbParticle> _particles;
  late final Color _accent;

  @override
  void initState() {
    super.initState();
    _accent = _kindColor(widget.kind);
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    final rnd = math.Random(20260825);
    _particles = List.generate(48, (_) => _OrbParticle(
          x: rnd.nextDouble(),
          y: rnd.nextDouble(),
          size: 1.6 + rnd.nextDouble() * 3.4,
          speed: 0.35 + rnd.nextDouble() * 1.4,
          phase: rnd.nextDouble() * 2 * math.pi,
          opacity: 0.45 + rnd.nextDouble() * 0.5,
          drift: Offset((rnd.nextDouble() - 0.5) * 28,
              (rnd.nextDouble() - 0.5) * 22),
          purple: rnd.nextBool(),
        ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _HUDOrbPainter(
          t: _controller.value,
          particles: _particles,
          accent: _accent,
        ),
      ),
    );
  }
}

class _HUDOrbPainter extends CustomPainter {
  final double t;
  final List<_OrbParticle> particles;
  final Color accent;
  _HUDOrbPainter({
    required this.t,
    required this.particles,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;
    // 光環集中在資源列表上方區域（背景）。
    final center = Offset(w * 0.5, h * 0.28);
    // 中心柔光
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [accent.withOpacity(0.12), Colors.transparent],
      ).createShader(
        Rect.fromCircle(center: center, radius: math.min(w, h) * 0.45),
      );
    canvas.drawRect(Offset.zero & size, glow);

    // 3 條旋轉光環（輪流 cyan / purple / kind accent）
    const colors = [_kNeonCyan, _kNeonPurple, _kNeonCyan];
    const radii = [46.0, 74.0, 106.0];
    for (var i = 0; i < 3; i++) {
      final sweep = (1.0 - 0.10 * i) * 2 * math.pi; // 留缺口見旋轉
      final rot = t * 2 * math.pi * (i.isEven ? 1 : -1) * (1.0 + 0.15 * i) +
          i * 0.7;
      _drawRing(
        canvas,
        center,
        radii[i],
        i == 2 ? accent.withOpacity(0.9) : colors[i],
        sweep,
        rot,
      );
    }
    // 中心核心亮點
    canvas.drawCircle(
      center,
      3.4,
      Paint()
        ..color = accent
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // 浮動粒子：緩慢漂移 + 微閃
    for (final p in particles) {
      final px = (p.x * w + math.sin(t * 2 * math.pi * p.speed + p.phase) *
              p.drift.dx +
          t * 40 * p.speed) %
          (w + 6);
      final py = (p.y * h + math.cos(t * 2 * math.pi * p.speed + p.phase) *
              p.drift.dy) %
          (h + 6);
      final flick = 0.5 + 0.5 * math.sin(t * 2 * math.pi * 2.5 + p.phase);
      final op = p.opacity * (0.35 + 0.65 * flick);
      final paint = Paint()
        ..color = (p.purple ? _kNeonPurple : _kNeonCyan).withOpacity(op);
      canvas.drawCircle(Offset(px, py), p.size, paint);
    }
  }

  void _drawRing(
      Canvas c, Offset center, double radius, Color color, double sweep,
      double rot) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    // 淡底整圈
    c.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withOpacity(0.14),
    );
    // glow arc（較粗 + blur）
    c.drawArc(
      rect,
      rot,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..color = color.withOpacity(0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // 亮弧
    c.drawArc(
      rect,
      rot,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color,
    );
    // 弧上軌道亮點（令旋轉更明顯）
    final mid = rot + sweep * 0.5;
    final pos = center + Offset(math.cos(mid), math.sin(mid)) * radius;
    c.drawCircle(
      pos,
      2.2,
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    c.drawCircle(pos, 1.1, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_HUDOrbPainter old) => old.t != t;
}