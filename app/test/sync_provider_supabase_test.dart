import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yourssh/providers/sync_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('isSupabaseConfigured is false on fresh provider', () {
    final p = SyncProvider();
    expect(p.isSupabaseConfigured, isFalse);
    expect(p.supabaseUrl, '');
    expect(p.supabaseAnonKey, '');
  });

  test('setSupabaseConfig updates getters and persists', () async {
    final p = SyncProvider();
    await p.setSupabaseConfig('https://x.supabase.co', 'anon-key-abc');
    expect(p.supabaseUrl, 'https://x.supabase.co');
    expect(p.supabaseAnonKey, 'anon-key-abc');
    expect(p.isSupabaseConfigured, isTrue);

    // Verify persisted to prefs
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('supabase_url'), 'https://x.supabase.co');
    expect(prefs.getString('supabase_anon_key'), 'anon-key-abc');
  });

  test('setSupabaseConfig trims whitespace', () async {
    final p = SyncProvider();
    await p.setSupabaseConfig('  https://x.supabase.co  ', '  key  ');
    expect(p.supabaseUrl, 'https://x.supabase.co');
    expect(p.supabaseAnonKey, 'key');
  });

  test('isSupabaseConfigured false when only URL is set', () async {
    final p = SyncProvider();
    await p.setSupabaseConfig('https://x.supabase.co', '');
    expect(p.isSupabaseConfigured, isFalse);
  });
}
