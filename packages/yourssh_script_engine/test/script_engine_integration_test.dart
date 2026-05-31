import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:yourssh_script_engine/src/script_engine_service.dart';
import 'package:yourssh_script_engine/src/hook_bus.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('plugin_engine_test_');
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  test('plugin transforms terminal.output via JS hook', () async {
    final pluginDir = Directory('${tmpDir.path}/test-plugin')..createSync();
    File('${pluginDir.path}/plugin.json').writeAsStringSync('''
{
  "id": "test.plugin",
  "name": "Test",
  "version": "1.0.0",
  "entry": "index.js",
  "minAppVersion": "1.0.0",
  "permissions": ["terminal.transform"]
}
''');
    File('${pluginDir.path}/index.js').writeAsStringSync('''
plugin.on("terminal.output", function(ctx) {
  return ctx.data.replace("hello", "HELLO");
});
''');

    final bus = HookBus();
    final svc = ScriptEngineService(
      hookBus: bus,
      uiRegistry: null,
      sshDelegate: null,
      sftpDelegate: null,
    );

    await svc.loadPlugin(pluginDir.path,
        grantedPermissions: {'terminal.transform'});

    final result = bus.fireTransform(
        'terminal.output', TransformEvent(sessionId: 's1', data: 'say hello world'));

    expect(result, 'say HELLO world');
    svc.dispose();
  });

  test('plugin can cancel terminal.input via return false', () async {
    final pluginDir = Directory('${tmpDir.path}/cancel-plugin')..createSync();
    File('${pluginDir.path}/plugin.json').writeAsStringSync('''
{
  "id": "cancel.plugin",
  "name": "Cancel",
  "version": "1.0.0",
  "entry": "index.js",
  "minAppVersion": "1.0.0",
  "permissions": ["terminal.intercept"]
}
''');
    File('${pluginDir.path}/index.js').writeAsStringSync('''
plugin.on("terminal.input", function(ctx) {
  if (ctx.data.indexOf("danger") !== -1) return false;
  return ctx.data;
});
''');

    final bus = HookBus();
    final svc = ScriptEngineService(
      hookBus: bus,
      uiRegistry: null,
      sshDelegate: null,
      sftpDelegate: null,
    );

    await svc.loadPlugin(pluginDir.path,
        grantedPermissions: {'terminal.intercept'});

    final blocked = bus.fireInterceptable(
        'terminal.input', TransformEvent(sessionId: 's1', data: 'danger command'));
    expect(blocked, isNull); // cancelled

    final allowed = bus.fireInterceptable(
        'terminal.input', TransformEvent(sessionId: 's1', data: 'safe command'));
    expect(allowed, 'safe command');
    svc.dispose();
  });

  test('unloadPlugin removes hooks', () async {
    final pluginDir = Directory('${tmpDir.path}/unload-plugin')..createSync();
    File('${pluginDir.path}/plugin.json').writeAsStringSync('''
{
  "id": "unload.plugin",
  "name": "Unload",
  "version": "1.0.0",
  "entry": "index.js",
  "minAppVersion": "1.0.0",
  "permissions": ["terminal.transform"]
}
''');
    File('${pluginDir.path}/index.js').writeAsStringSync('''
plugin.on("terminal.output", function(ctx) { return "INTERCEPTED"; });
''');

    final bus = HookBus();
    final svc = ScriptEngineService(
      hookBus: bus,
      uiRegistry: null,
      sshDelegate: null,
      sftpDelegate: null,
    );

    await svc.loadPlugin(pluginDir.path,
        grantedPermissions: {'terminal.transform'});
    svc.unloadPlugin('unload.plugin');

    final result = bus.fireTransform(
        'terminal.output', TransformEvent(sessionId: 's1', data: 'original'));
    expect(result, 'original'); // hook removed
    svc.dispose();
  });
}
