import 'package:flutter/material.dart';
import '../services/api.dart';
import '../services/config.dart';

// K8s brand blue (kubenav-style accent).
const Color _kK8sBlue = Color(0xFF326CE5);
const Color _kCardBg = Color(0xFF151820);
const Color _kGreen = Color(0xFF26A69A);

// kubenav 式 Kubernetes cluster 管理。
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
      backgroundColor: _kCardBg,
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: _kK8sBlue,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.dns, size: 22),
            const SizedBox(width: 10),
            const Text('Kubernetes', style: TextStyle(fontWeight: FontWeight.bold)),
            if (!_hasConnection) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                child: const Text('示範', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: '連接 Cluster',
            icon: const Icon(Icons.cloud_outlined),
            onPressed: _openConnectSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTypeChips(),
          const SizedBox(height: 4),
          Expanded(child: _buildBody()),
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
          return ChoiceChip(
            label: Text(t.label),
            selected: selected,
            avatar: Icon(t.icon, size: 16),
            selectedColor: _kK8sBlue,
            backgroundColor: _kCardBg,
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
            side: BorderSide(
              color: selected ? _kK8sBlue : Colors.white12,
            ),
            onSelected: (_) {
              setState(() => _type = t);
              _load();
            },
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _kK8sBlue),
      );
    }
    if (_disconnected) {
      return RefreshIndicator(
        color: _kK8sBlue,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 48),
            const Icon(Icons.cloud_off, size: 72, color: _kK8sBlue),
            const SizedBox(height: 16),
            Text(
              _hasConnection ? '未連接 Cluster 或 API 未準備' : '尚未連接 Cluster',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                    color: Colors.orangeAccent, fontSize: 12, fontFamily: 'monospace'),
              ),
            ],
            const SizedBox(height: 28),
            Center(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _kK8sBlue),
                onPressed: _openConnectSheet,
                icon: const Icon(Icons.add_link),
                label: const Text('新增 / 連接 Cluster'),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: _loadDemo,
                icon: const Icon(Icons.preview, color: Colors.white54),
                label: const Text('載入示範資料預覽', style: TextStyle(color: Colors.white54)),
              ),
            ),
          ],
        ),
      );
    }
    if (_resources.isEmpty) {
      return RefreshIndicator(
        color: _kK8sBlue,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(child: Text('暫無資源', style: TextStyle(color: Colors.white54))),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: _kK8sBlue,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: _resources.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) => _ResourceCard(
          resource: _resources[i],
          type: _type,
          demo: !_hasConnection,
          onRefresh: _load,
        ),
      ),
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
    return Card(
      color: _kCardBg,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
                    Text(resource.status.isEmpty ? type.label : resource.status,
                        style: TextStyle(
                          fontSize: 12,
                          color: resource.healthy
                              ? const Color(0xFF80CBC4)
                              : Colors.white38,
                        )),
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
      isScrollControlled: true,
      backgroundColor: _kCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ResourceDetailSheet(
          resource: resource, type: type, demo: demo, onRefresh: onRefresh),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool healthy;
  final String status;
  const _StatusDot({required this.healthy, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = healthy ? _kGreen : Colors.white24;
    return Tooltip(
      message: healthy ? 'Running / Ready' : '未知',
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
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
  String? _exec;

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
        _exec = null;
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
          _exec = null;
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
        _exec = null;
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
        _exec = null;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      if (widget.demo) {
        setState(() {
          _logs = _demoLogs();
          _yaml = null;
          _exec = null;
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
        _exec = null;
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
    final cmdCtrl = TextEditingController(text: 'ls -la');
    final cmd = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCardBg,
        title: const Text('▶ Exec 命令'),
        content: TextField(
          controller: cmdCtrl,
          autofocus: true,
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: const InputDecoration(
            labelText: '命令',
            hintText: 'ls -la',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kK8sBlue),
            onPressed: () {
              final t = cmdCtrl.text.trim();
              Navigator.pop(ctx, t.isEmpty ? 'ls -la' : t);
            },
            child: const Text('執行'),
          ),
        ],
      ),
    );
    cmdCtrl.dispose();
    if (cmd == null) return;
    setState(() => _busy = true);
    try {
      if (widget.demo) {
        setState(() {
          _exec = _demoExec(cmd);
          _yaml = null;
          _logs = null;
          _message = null;
          _activeYaml = false;
          _demoResult = true;
          _busy = false;
        });
        return;
      }
      final raw = await Api.post('/api/k8s/action', {
        'op': 'exec',
        'kind': type.label,
        'name': resource.name,
        'namespace': resource.namespace,
        'cmd': cmd,
      });
      if (!mounted) return;
      if (_guardFailure(raw, '執行')) return;
      final out = raw is Map ? raw['output'] ?? raw['result'] ?? raw['stdout'] : null;
      setState(() {
        _exec = out is String ? out : '（無輸出）';
        _yaml = null;
        _logs = null;
        _message = null;
        _activeYaml = false;
        _demoResult = false;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = '執行失敗：$e';
        _activeYaml = false;
        _busy = false;
      });
    }
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

  String _demoExec(String cmd) {
    return '\$ $cmd\n'
        'total 52\n'
        'drwxr-xr-x 1 root root  4096 Aug 25 09:58 .\n'
        'drwxr-xr-x 1 root root  4096 Aug 25 09:58 ..\n'
        '-rw-r--r-- 1 root root    14 Aug 25 09:58 .env\n'
        'drwxr-xr-x 2 root root  4096 Aug 25 09:58 config\n'
        '-rwxr-xr-x 1 root root 28912 Aug 25 09:58 app\n'
        'exit 0\n';
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
                  Icon(type.icon, color: _kK8sBlue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      resource.name.isEmpty ? '（未命名）' : resource.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  _StatusDot(healthy: resource.healthy, status: resource.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(type.label,
                  style: const TextStyle(color: _kK8sBlue, fontSize: 13)),
              const SizedBox(height: 12),
              // 動作按鈕列：YAML / Logs / Exec
              Row(
                children: [
                  _actionButton('📝', 'YAML', _fetchYaml),
                  _actionButton('🖥', 'Logs', _isPod ? _fetchLogs : null),
                  _actionButton('▶', 'Exec', _isPod ? _runExec : null),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _DetailRow(label: '類型', value: type.label),
                    _DetailRow(label: 'Name', value: resource.name),
                    _DetailRow(label: 'Namespace', value: resource.namespace),
                    _DetailRow(label: 'Status', value: resource.status),
                    if (resource.labels.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Labels',
                          style: TextStyle(color: Colors.white38, fontSize: 13)),
                      const SizedBox(height: 6),
                      ...resource.labels.entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D0E13),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.label_outline,
                                    size: 14, color: _kK8sBlue),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${e.key}=${e.value}',
                                    style: const TextStyle(
                                        fontFamily: 'monospace', fontSize: 12),
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
            foregroundColor: onTap == null ? Colors.white24 : _kK8sBlue,
            side: BorderSide(
                color: onTap == null
                    ? Colors.white12
                    : _kK8sBlue.withOpacity(0.55)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: Text('$emoji $label',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
            child: CircularProgressIndicator(color: _kK8sBlue, strokeWidth: 2.5)),
      );
    }
    if (_message != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF20160A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orangeAccent.withOpacity(0.4)),
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
          Row(
            children: [
              const Text('YAML',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
              if (demo) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('示範',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0E13),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: TextField(
              controller: _yamlCtrl,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 12, color: Colors.white70),
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
              style: FilledButton.styleFrom(backgroundColor: _kK8sBlue),
              onPressed: _busy ? null : _applyYaml,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('💾 套用'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      );
    }
    if (_logs != null) {
      return _terminalPanel('Logs', _logs!, demo);
    }
    if (_exec != null) {
      return _terminalPanel('Exec 輸出', _exec!, demo);
    }
    // 預設提示
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text('撳上方按鈕查看 YAML / Logs / 執行命令',
            style: TextStyle(color: Colors.white38, fontSize: 12)),
      ),
    );
  }

  // Monospace 黑底終端顯示（logs / exec 輸出共用）。
  Widget _terminalPanel(String title, String text, bool demo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title,
                style: const TextStyle(color: Colors.white38, fontSize: 13)),
            if (demo) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('示範',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 240),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Color(0xFFA5D6A7), // 綠色 terminal 字
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
          SizedBox(width: 90, child: Text(label,
              style: const TextStyle(color: Colors.white38))),
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
                Icon(Icons.cloud_done, color: _kK8sBlue),
                SizedBox(width: 10),
                Text('連接 Cluster',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '用其中一種方式接入：匯入 kubeconfig，或輸入 cluster server + token。'
              '設定會存去裝置（shared_preferences），之後用作連接 dashboard /api/k8s。',
              style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            const Text('方式一：kubeconfig',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _kubeconfigCtrl,
              maxLines: 6,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(
                hintText: '貼上 kubeconfig YAML…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text('方式二：Server + Token',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _serverCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Cluster Server IP / URL',
                hintText: 'https://192.168.1.10:6443',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns_outlined, color: _kK8sBlue),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Token',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key_outlined, color: _kK8sBlue),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _kK8sBlue),
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('儲存連線設定'),
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