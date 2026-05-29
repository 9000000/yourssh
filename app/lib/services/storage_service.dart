import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/host.dart';
import '../models/known_host.dart';

class StorageService {
  static const _hostsKey = 'yourssh.hosts';
  static const _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(accountName: 'yourssh'),
    wOptions: WindowsOptions(),
  );

  // ── Hosts ──────────────────────────────────────────────

  Future<List<Host>> loadHosts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_hostsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => Host.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveHosts(List<Host> hosts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostsKey, jsonEncode(hosts.map((h) => h.toJson()).toList()));
  }

  // ── Credentials (Keychain / Credential Manager) ────────

  Future<void> savePassword(String hostId, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pw_$hostId', password);
    try {
      await _storage.write(key: 'pw_$hostId', value: password);
    } catch (_) {}
  }

  Future<String?> loadPassword(String hostId) async {
    try {
      final val = await _storage.read(key: 'pw_$hostId');
      if (val != null) return val;
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('pw_$hostId');
  }

  Future<void> deletePassword(String hostId) async {
    try {
      await _storage.delete(key: 'pw_$hostId');
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pw_$hostId');
  }

  Future<void> savePassphrase(String keyId, String passphrase) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pp_$keyId', passphrase);
    try {
      await _storage.write(key: 'pp_$keyId', value: passphrase);
    } catch (_) {}
  }

  Future<String?> loadPassphrase(String keyId) async {
    try {
      final val = await _storage.read(key: 'pp_$keyId');
      if (val != null) return val;
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('pp_$keyId');
  }

  // ── Known Hosts ────────────────────────────────────────────

  static const _knownHostsKey = 'yourssh.known_hosts';

  Future<List<KnownHost>> loadKnownHosts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_knownHostsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => KnownHost.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveKnownHosts(List<KnownHost> hosts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _knownHostsKey, jsonEncode(hosts.map((h) => h.toJson()).toList()));
  }
}
