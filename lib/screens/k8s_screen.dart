import 'package:flutter/material.dart';

// Kubernetes（kubenav）留位屏幕。
// 顯示 placeholder + 架構說明；之後會加入真實 cluster 管理 / API wiring。
class K8sScreen extends StatelessWidget {
  const K8sScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Kubernetes（kubenav）')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Icon(Icons.dns, size: 72, color: Color(0xFF326CE5)),
          SizedBox(height: 16),
          Text(
            'Kubenav 功能 —— 即將推出',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            '此頁面目前為留位（placeholder）。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60),
          ),
          SizedBox(height: 24),
          _ArchitectureCard(
            title: '架構',
            points: [
              '將加入 kubeconfig 匯入，支援多 cluster 切換',
              'CRUD 檢視 / 管理：Deployments、Pods、Services、ConfigMaps、Secrets 等',
              '瀏覽 event / logs、原地執行 kubectl 常用指令',
              '透過 Hermes dashboard API 接駁 Kubernetes 控制平面',
            ],
          ),
        ],
      ),
    );
  }
}

class _ArchitectureCard extends StatelessWidget {
  final String title;
  final List<String> points;
  const _ArchitectureCard({required this.title, required this.points});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151820),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ...points.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.circle, size: 8, color: Color(0xFF7C6CF0)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(p,
                        style: const TextStyle(color: Colors.white70, height: 1.5)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}