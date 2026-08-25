import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../services/api.dart';

// ── Sci-fi HUD 配色（與 K8s screen 一致）──────────────────────────────
const Color _kNeonBg = Color(0xFF05070D); // 深空底
const Color _kNeonCyan = Color(0xFF00E5FF); // 主要 accent 霓虹青
const Color _kTerminalBg = Color(0xFF04060C); // 終端黑底
const Color _kGreenTerm = Color(0xFF9BE29B); // k9s 式綠色 terminal 字
const Color _kCyanTerm = Color(0xFF7DE8FF); // 科幻青色 terminal 字
const Color _kNeonRed = Color(0xFFFF4D6D); // 失敗
const Color _kNeonYellow = Color(0xFFFFC44D); // 待定

enum _ConnState { connecting, connected, disconnected }

/// Pod 全屏互動 Terminal。
///
/// 協議（terminal-server）：
///   1. connect ws://<Api.baseUrl host>:4300
///   2. send {token: Api.token} 認證
///   3. send {type:'k8s', kind:'Pods', name, namespace, container?} 開 kubectl exec
///   4. input: send {type:'input', data}
///   收 {type:'out', data}
class PodTerminalScreen extends StatefulWidget {
  final String podName;
  final String namespace;
  final String? container;
  const PodTerminalScreen({
    super.key,
    required this.podName,
    required this.namespace,
    this.container,
  });

  @override
  State<PodTerminalScreen> createState() => _PodTerminalScreenState();
}

class _PodTerminalScreenState extends State<PodTerminalScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final List<String> _lines = [];
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  _ConnState _state = _ConnState.disconnected;
  String? _error;
  bool _connecting = false;
  bool _k8sReady = false; // k8s exec 已開啟

  String get _podName => widget.podName;
  String get _namespace => widget.namespace;
  String? get _container => widget.container;

  // 由 http://100.126.80.55:3000 → ws://100.126.80.55:4300
  String get _wsUrl {
    final uri = Uri.tryParse(Api.baseUrl);
    final host = uri?.host.isNotEmpty == true ? uri!.host : 'localhost';
    final scheme = (uri?.scheme == 'https') ? 'wss' : 'ws';
    return '$scheme://$host:4300';
  }

  @override
  void dispose() {
    _teardown();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _teardown() {
    _sub?.cancel();
    _sub = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
  }

  void _append(String text) {
    if (!mounted) return;
    setState(() {
      for (final line in text.split('\n')) {
        // 保留空行數組，但 trim 尾隨空行避免無限增長。
        _lines.add(line);
      }
      while (_lines.length > 2000) {
        _lines.removeAt(0);
      }
    });
    // 自動滾到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> _connect() async {
    if (_connecting) return;
    _teardown();
    setState(() {
      _state = _ConnState.connecting;
      _error = null;
      _connecting = true;
      _k8sReady = false;
    });
    try {
      final channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _channel = channel;
      _sub = channel.stream.listen(
        (raw) => _onData(raw),
        onError: (e) => _onError('WS error: $e'),
        onDone: _onDone,
        cancelOnError: true,
      );
      // 認證
      channel.sink.add(jsonEncode({'token': Api.token}));
      // 開 kubectl exec
      channel.sink.add(jsonEncode({
        'type': 'k8s',
        'kind': 'Pods',
        'name': _podName,
        'namespace': _namespace,
        if (_container != null && _container!.isNotEmpty)
          'container': _container,
      }));
      _append('┌─ ${_podName.isEmpty ? '(pod)' : _podName} @ $_namespace '
          '($_wsUrl)');
      _append('└ connecting...');
      if (mounted) {
        setState(() {
          _state = _ConnState.connected;
          _k8sReady = true;
          _connecting = false;
        });
      }
    } catch (e) {
      _onError('connect 失敗：$e');
    }
  }

  void _retry() {
    setState(() => _lines.clear());
    _connect();
  }

  void _onData(dynamic raw) {
    if (raw is! String && raw is! List<int>) return;
    String text;
    try {
      text = raw is List<int> ? utf8.decode(raw) : raw;
    } catch (_) {
      return;
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      // 唔係 JSON → 當原始輸出 append
      _append(text);
      return;
    }
    if (decoded is Map) {
      final type = decoded['type'];
      final data = decoded['data'];
      if (type == 'out' && data is String) {
        _append(data);
      } else if (type == 'error' || type == 'err') {
        _onError(data is String ? data : jsonEncode(decoded));
      } else if (type == 'status' || type == 'system') {
        _append('[$type] ${data is String ? data : jsonEncode(decoded)}');
      } else if (decoded.containsKey('error') || decoded.containsKey('message')) {
        // 認證 / 開啟失敗等通用錯誤
        final m = decoded['error'] ?? decoded['message'];
        _onError(m is String ? m : jsonEncode(decoded));
      } else {
        _append(text);
      }
    } else {
      // 非物件 JSON（如狀態碼）→ 原樣輸出
      _append(text);
    }
  }

  void _onError(String msg) {
    if (!mounted) return;
    setState(() {
      _state = _ConnState.disconnected;
      _connecting = false;
      _error = msg;
    });
    _append('[!] $msg');
  }

  void _onDone() {
    if (!mounted) return;
    setState(() {
      _state = _ConnState.disconnected;
      _connecting = false;
    });
    _append('└─ 連線已關閉');
  }

  void _send() {
    final text = _inputCtrl.text;
    if (text.isEmpty) return;
    if (_channel == null || _state != _ConnState.connected) {
      _append('[!] 未連線，無法送出命令');
      return;
    }
    _append('\$ $text');
    try {
      _channel!.sink.add(jsonEncode({'type': 'input', 'data': text}));
    } catch (e) {
      _onError('送出失敗：$e');
    }
    _inputCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kNeonBg,
      appBar: AppBar(
        backgroundColor: _kNeonBg,
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: _kNeonCyan),
        title: Row(
          children: [
            const Icon(Icons.terminal, size: 20, color: _kNeonCyan),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _podName.isEmpty ? 'POD TERMINAL' : _podName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontFamily: 'monospace',
                  fontSize: 15,
                ),
              ),
            ),
            _statusBadge(),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '重新連線',
            icon: const Icon(Icons.refresh, color: _kNeonCyan),
            onPressed: _state == _ConnState.disconnected ? _retry : null,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null) _errorBanner(),
          _buildTerminal(),
          _statusBar(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _statusBadge() {
    final (label, color) = switch (_state) {
      _ConnState.connecting =>
        ('CONNECTING', _kNeonYellow),
      _ConnState.connected => ('CONNECTED', _kGreenTerm),
      _ConnState.disconnected => ('DISCONNECTED', _kNeonRed),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _state == _ConnState.connected
            ? _kGreenTerm.withOpacity(0.12)
            : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontFamily: 'monospace',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _errorBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kNeonRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kNeonRed.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, size: 16, color: _kNeonRed),
              SizedBox(width: 6),
              Text('連線錯誤',
                  style: TextStyle(
                      color: _kNeonRed,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _error!,
            style: const TextStyle(
                color: _kNeonRed, fontSize: 12, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  // 黑底 monospace 滾動輸出區（綠/青字，k9s 風）
  Widget _buildTerminal() {
    return Expanded(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kTerminalBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kNeonCyan.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(color: _kNeonCyan.withOpacity(0.08), blurRadius: 10),
          ],
        ),
        child: _lines.isEmpty
            ? const Align(
                alignment: Alignment.topLeft,
                child: Text(
                  '// 等待輸出...',
                  style: TextStyle(
                      color: Colors.white38,
                      fontFamily: 'monospace',
                      fontSize: 12),
                ),
              )
            : Scrollbar(
                controller: _scrollCtrl,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollCtrl,
                  reverse: false,
                  child: SelectableText.rich(
                    TextSpan(
                      children: [
                        for (var i = 0; i < _lines.length; i++) ...[
                          _lineSpan(_lines[i]),
                          if (i != _lines.length - 1 ||
                              _lines.last.isNotEmpty)
                            const TextSpan(text: '\n'),
                        ],
                      ],
                    ),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // k9s 風配色：command 行（$ ...）青色，其餘輸出綠色。
  TextSpan _lineSpan(String line) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('\$ ') || trimmed.startsWith('┌─') ||
        trimmed.startsWith('└')) {
      return TextSpan(text: line, style: const TextStyle(color: _kCyanTerm));
    }
    if (trimmed.startsWith('[!]') || trimmed.startsWith('*')) {
      return TextSpan(text: line, style: const TextStyle(color: _kNeonRed));
    }
    return TextSpan(text: line, style: const TextStyle(color: _kGreenTerm));
  }

  Widget _statusBar() {
    final s = switch (_state) {
      _ConnState.connecting => 'connecting...',
      _ConnState.connected => _k8sReady
          ? 'connected · kubectl exec $podLabel'
          : 'connected',
      _ConnState.disconnected => 'disconnected',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '// $_namespace/$_podName · $s',
          style: TextStyle(
            color: _state == _ConnState.connected
                ? _kGreenTerm.withOpacity(0.8)
                : _kNeonYellow.withOpacity(0.8),
            fontFamily: 'monospace',
            fontSize: 11,
            letterSpacing: 0.5,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  String get podLabel => _podName.isEmpty ? '?' : _podName;

  // 底部輸入行：TextField（monospace）+ 送出
  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: _kTerminalBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kNeonCyan.withOpacity(0.5)),
              ),
              child: const Text('❯',
                  style: TextStyle(
                      color: _kNeonCyan,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: _kCyanTerm),
                cursorColor: _kNeonCyan,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  hintText: '輸入 command，例如 ls -la',
                  hintStyle:
                      const TextStyle(color: Colors.white24, fontSize: 12),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  filled: true,
                  fillColor: _kTerminalBg,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _kNeonCyan.withOpacity(0.4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: _kNeonCyan, width: 1.3),
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: '送出',
              style: IconButton.styleFrom(
                backgroundColor: _kNeonCyan,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white12,
                disabledForegroundColor: Colors.white24,
              ),
              onPressed:
                  _state == _ConnState.connected ? _send : null,
              icon: const Icon(Icons.send, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
