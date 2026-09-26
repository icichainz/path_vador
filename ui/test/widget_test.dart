import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_vador_ui/app.dart';
import 'package:path_vador_ui/engine/path_engine.dart';
import 'package:path_vador_ui/settings/app_settings.dart';
import 'package:path_vador_ui/settings/settings_store.dart';

class _Engine implements PathEngine {
  @override
  Future<EngineInfo> detect() async => const EngineInfo(
    shell: 'sh',
    goos: 'darwin',
    separator: '/',
    home: '/Users/you',
  );

  @override
  Future<PathInspection> inspect(String path, {String base = ''}) async =>
      PathInspection(
        clean: path,
        abs: '$base/$path',
        dir: '.',
        base: path,
        ext: '',
        stem: path,
      );

  @override
  Future<String> join(List<String> parts) async => parts.join('/');

  @override
  Future<EnvCommand> env({
    required String shell,
    required String name,
    required String value,
  }) async =>
      EnvCommand(command: "export $name='$value'", shell: 'sh', kind: 'export');
}

void main() {
  testWidgets('first run shows onboarding', (tester) async {
    final store = MemorySettingsStore();
    await tester.pumpWidget(
      PathVadorApp(
        settings: SettingsController(store, const AppSettings()),
        engine: _Engine(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome to path_vador'), findsOneWidget);
  });

  testWidgets('engine error screen explains where the library is', (
    tester,
  ) async {
    await tester.pumpWidget(const EngineErrorApp(error: 'dlopen failed'));
    expect(find.text('dlopen failed'), findsOneWidget);
    expect(find.text('Where is libpathvador?'), findsOneWidget);
    expect(find.textContaining('ENGINE.md'), findsOneWidget);
  });

  testWidgets('theme mode follows settings', (tester) async {
    final controller = SettingsController(
      MemorySettingsStore(),
      const AppSettings(themeMode: ThemeMode.dark),
    );
    await tester.pumpWidget(
      PathVadorApp(settings: controller, engine: _Engine()),
    );
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });
}
