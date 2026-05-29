import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yourssh/providers/settings_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('terminalFont defaults to monospace', () async {
    final provider = SettingsProvider();
    await Future<void>.delayed(Duration.zero);
    expect(provider.terminalFont, 'monospace');
  });

  test('save persists terminalFont', () async {
    final provider = SettingsProvider();
    await Future<void>.delayed(Duration.zero);
    await provider.save(terminalFont: 'DejaVu Sans Mono for Powerline');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('terminalFont'), 'DejaVu Sans Mono for Powerline');
    expect(provider.terminalFont, 'DejaVu Sans Mono for Powerline');
  });

  test('loads persisted terminalFont on init', () async {
    SharedPreferences.setMockInitialValues({
      'terminalFont': 'Inconsolata for Powerline',
    });
    final provider = SettingsProvider();
    await Future<void>.delayed(Duration.zero);
    expect(provider.terminalFont, 'Inconsolata for Powerline');
  });
}
