import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

// Local persistence for API configuration (baseUrl + token).
// Uses shared_preferences so the token/baseUrl survive restarts.
class Config {
  static const _kBaseUrl = 'api_base_url';
  static const _kToken = 'api_token';

  // Load persisted settings into Api static vars (call once at startup).
  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final b = p.getString(_kBaseUrl);
      final t = p.getString(_kToken);
      if (b != null && b.isNotEmpty) Api.baseUrl = b;
      Api.token = t ?? '';
    } catch (_) {
      // Storage unavailable (e.g. tests) — fall back to no-op.
    }
  }

  static Future<void> save({String? baseUrl, String? token}) async {
    if (baseUrl != null) Api.baseUrl = baseUrl.trim();
    if (token != null) Api.token = token.trim();
    try {
      final p = await SharedPreferences.getInstance();
      if (baseUrl != null) await p.setString(_kBaseUrl, Api.baseUrl);
      if (token != null) await p.setString(_kToken, Api.token);
    } catch (_) {
      // Storage unavailable — Api statics still updated for this session.
    }
  }

  static Future<void> clearToken() async {
    Api.token = '';
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_kToken);
    } catch (_) {}
  }
}