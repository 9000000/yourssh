import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yourssh/models/app_release.dart';
import 'package:yourssh/providers/update_provider.dart';
import 'package:yourssh/services/update_service.dart';
import 'package:yourssh/widgets/update_banner.dart';

class _StubService extends UpdateService {
  _StubService(this._release);
  final AppRelease _release;
  @override
  Future<AppRelease> fetchLatestRelease() async => _release;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, UpdateProvider p) {
    return tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: p,
        child: MaterialApp(
          home: Scaffold(body: UpdateBanner(onShowDetails: () {})),
        ),
      ),
    );
  }

  testWidgets('hidden when up to date', (tester) async {
    final p = UpdateProvider(
      _StubService(AppRelease.fromJson({'tag_name': 'v0.1.18', 'assets': []})),
      currentVersion: '0.1.18',
    );
    await p.checkForUpdates(manual: true);
    await pump(tester, p);
    expect(find.byType(UpdateBanner), findsOneWidget);
    expect(find.textContaining('available'), findsNothing);
  });

  testWidgets('shows version when an update is available', (tester) async {
    final p = UpdateProvider(
      _StubService(AppRelease.fromJson({'tag_name': 'v0.2.0', 'assets': []})),
      currentVersion: '0.1.18',
    );
    await p.checkForUpdates(manual: true);
    await pump(tester, p);
    expect(find.textContaining('0.2.0'), findsOneWidget);
  });
}
