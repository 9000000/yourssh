import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yourssh/models/host.dart';
import 'package:yourssh/services/bulk_action_service.dart';
import 'package:yourssh/widgets/bulk/bulk_run_dialog.dart';
import 'package:yourssh_snippets/yourssh_snippets.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget wrap(Widget child) => ChangeNotifierProvider(
        create: (_) => SnippetProvider(),
        child: MaterialApp(home: Scaffold(body: child)),
      );

  testWidgets('runs a command and shows per-host results', (tester) async {
    final hosts = [
      Host(label: 'a', host: 'a.x', username: 'u'),
      Host(label: 'b', host: 'b.x', username: 'u'),
    ];
    final service = BulkActionService(
        exec: (h, c) async => (stdout: 'up 1 day', stderr: '', exitCode: 0));

    await tester.pumpWidget(
        wrap(BulkRunDialog(hosts: hosts, serviceOverride: service)));
    expect(find.text('Run command on 2 hosts'), findsOneWidget);

    await tester.enterText(
        find.byKey(const Key('bulk-command-field')), 'uptime');
    await tester.tap(find.text('RUN'));
    await tester.pumpAndSettle();

    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
    expect(find.textContaining('2 ok'), findsOneWidget);
  });

  testWidgets('RUN does nothing with an empty command', (tester) async {
    var execCount = 0;
    final service = BulkActionService(exec: (h, c) async {
      execCount++;
      return (stdout: '', stderr: '', exitCode: 0);
    });
    await tester.pumpWidget(wrap(BulkRunDialog(
        hosts: [Host(label: 'a', host: 'a.x', username: 'u')],
        serviceOverride: service)));
    await tester.tap(find.text('RUN'));
    await tester.pumpAndSettle();
    expect(execCount, 0);
  });
}
