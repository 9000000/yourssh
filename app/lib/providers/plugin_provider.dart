import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yourssh_plugin_api/yourssh_plugin_api.dart';

class PluginProvider extends ChangeNotifier {
  final List<YourSSHPlugin> plugins;
  Set<String> _enabledIds = {};

  PluginProvider({required this.plugins});

  List<YourSSHPlugin> get enabledPlugins =>
      plugins.where((p) => _enabledIds.contains(p.id)).toList();

  bool isEnabled(String pluginId) => _enabledIds.contains(pluginId);

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('enabled_plugins') ?? [];
    _enabledIds = saved.toSet();
    notifyListeners();
  }

  Future<void> toggle(String pluginId) async {
    _enabledIds.contains(pluginId)
        ? _enabledIds.remove(pluginId)
        : _enabledIds.add(pluginId);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('enabled_plugins', _enabledIds.toList());
  }
}
