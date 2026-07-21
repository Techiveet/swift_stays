import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores credentials in encrypted platform storage and non-sensitive cached
/// app data in SharedPreferences.
class AppStorage {
  AppStorage._(this._prefs, this._secureStorage, this._token, this._tokenType);

  @visibleForTesting
  AppStorage.forTesting(SharedPreferences prefs)
    : this._(prefs, const FlutterSecureStorage(), null, 'Bearer');

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;
  String? _token;
  String _tokenType;

  static const _kToken = 'access_token';
  static const _kTokenType = 'token_type';
  static const _kRestaurant = 'restaurant';
  static const _kPushConfig = 'push_config';
  static const _kCurrency = 'currency';

  static Future<AppStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage(aOptions: AndroidOptions());

    var token = await secureStorage.read(key: _kToken);
    var tokenType = await secureStorage.read(key: _kTokenType);

    // One-time migration keeps existing signed-in restaurant users working.
    token ??= prefs.getString(_kToken);
    tokenType ??= prefs.getString(_kTokenType);
    if (token != null && token.isNotEmpty) {
      await secureStorage.write(key: _kToken, value: token);
      await secureStorage.write(key: _kTokenType, value: tokenType ?? 'Bearer');
    }
    await prefs.remove(_kToken);
    await prefs.remove(_kTokenType);

    return AppStorage._(prefs, secureStorage, token, tokenType ?? 'Bearer');
  }

  String? get token => _token;
  String get tokenType => _tokenType;
  bool get isLoggedIn => (token ?? '').isNotEmpty;

  Future<void> saveToken(String token, String tokenType) async {
    _token = token;
    _tokenType = tokenType;
    await _secureStorage.write(key: _kToken, value: token);
    await _secureStorage.write(key: _kTokenType, value: tokenType);
  }

  Map<String, dynamic>? get restaurant {
    final raw = _prefs.getString(_kRestaurant);
    if (raw == null || raw.isEmpty) return null;
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveRestaurant(Map<String, dynamic> data) =>
      _prefs.setString(_kRestaurant, json.encode(data));

  Map<String, dynamic>? get pushConfig {
    final raw = _prefs.getString(_kPushConfig);
    if (raw == null || raw.isEmpty) return null;
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> savePushConfig(Map<String, dynamic>? data) async {
    if (data == null) return;
    await _prefs.setString(_kPushConfig, json.encode(data));
  }

  String get currency => _prefs.getString(_kCurrency) ?? '';
  Future<void> saveCurrency(String? symbol) async {
    if (symbol == null) return;
    await _prefs.setString(_kCurrency, symbol);
  }

  String? announcementSeen(String key) => _prefs.getString(key);
  Future<void> markAnnouncementSeen(String key, String value) =>
      _prefs.setString(key, value);

  Future<void> clear() async {
    _token = null;
    _tokenType = 'Bearer';
    await _secureStorage.delete(key: _kToken);
    await _secureStorage.delete(key: _kTokenType);
    await _prefs.remove(_kRestaurant);
    // Keep push_config/currency — harmless and avoids a re-fetch on next login.
  }
}
