import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

// API service for the ZAV/Hermes dashboard.
// Base URL points at the dashboard server (override in Settings). Token is the
// dashboard x-control-token read from .env.local on the server.
class Api {
  static String baseUrl = 'http://100.126.80.55:3000'; // Tailscale IP
  static String token = '';

  static Map<String, String> get _headers => {
        'x-control-token': token,
        'Content-Type': 'application/json',
      };

  static Uri _u(String path) => Uri.parse('$baseUrl$path');

  static Future<dynamic> get(String path) async {
    final r = await http.get(_u(path), headers: _headers).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body);
  }

  static Future<dynamic> post(String path, Map body) async {
    final r = await http.post(_u(path), headers: _headers, body: jsonEncode(body)).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200 && r.statusCode != 201) throw Exception('HTTP ${r.statusCode}: ${r.body}');
    return jsonDecode(r.body);
  }
}

// ---- models (shaped to the real dashboard API) ----
@immutable
class Stock {
  final String symbol;
  final String name;
  final num price;
  final num chg; // percentage change, api key: change_pct
  const Stock(this.symbol, this.name, this.price, this.chg);
  factory Stock.fromJson(dynamic j) {
    final m = j is Map ? j : {};
    return Stock(
      '${m['symbol'] ?? ''}',
      '${m['name'] ?? ''}',
      (m['price'] ?? 0) as num,
      (m['change_pct'] ?? m['chg'] ?? 0) as num,
    );
  }
}

@immutable
class CronJob {
  final String id;
  final String name;
  final String schedule;
  final bool enabled;
  final String nextRunAt;
  final String lastStatus;
  final String lastRunAt;
  const CronJob(this.id, this.name, this.schedule, this.enabled,
      this.nextRunAt, this.lastStatus, this.lastRunAt);
  factory CronJob.fromJson(dynamic j) {
    final m = j is Map ? j : {};
    return CronJob(
      '${m['id'] ?? ''}',
      '${m['name'] ?? m['job_id'] ?? ''}',
      '${m['schedule'] ?? m['cron'] ?? ''}',
      (m['enabled'] ?? false) as bool,
      '${m['next_run_at'] ?? ''}',
      '${m['last_status'] ?? ''}',
      '${m['last_run_at'] ?? ''}',
    );
  }
}

@immutable
class LogFile {
  final String name;
  final num sizeKb;
  final String mtime;
  const LogFile(this.name, this.sizeKb, this.mtime);
  factory LogFile.fromJson(dynamic j) {
    final m = j is Map ? j : {};
    return LogFile(
      '${m['name'] ?? ''}',
      (m['size_kb'] ?? 0) as num,
      '${m['mtime'] ?? ''}',
    );
  }
}