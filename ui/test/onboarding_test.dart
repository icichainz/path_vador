import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_vador_ui/engine/path_engine.dart';
import 'package:path_vador_ui/onboarding/onboarding_flow.dart';
import 'package:path_vador_ui/settings/app_settings.dart';
import 'package:path_vador_ui/settings/cli_install.dart';
import 'package:path_vador_ui/settings/settings_page.dart';
import 'package:path_vador_ui/settings/settings_store.dart';
import 'package:path_vador_ui/theme/theme.dart';

/// Canned engine answers for a macOS machine.
class FakePathEngine implements PathEngine {
  FakePathEngine({this.goos = 'darwin', this.shell = 'sh'});

  final String goos;
  final String shell;

  @override
  Future<EngineInfo> detect() async =>
      EngineInfo(shell: shell, goos: goos, separator: '/', home: '/Users/you');

  @override
  Future<PathInspection> inspect(String path, {String base = ''}) async {
    final abs = '${base.isEmpty ? '/Users/you' : base}/$path';
    return PathInspection(
      clean: path,
      abs: abs,
      dir: '.',
      base: path,
      ext: '.MD',
      stem: 'README',
    );
  }

  @override
  Future<String> join(List<String> parts) async => parts.join('/');

  @override
  Future<EnvCommand> env({
    required String shell,
    required String name,
    required String value,
  }) async {
    final resolved = shell == 'auto' ? this.shell : shell;
    final command = switch (resolved) {
      'powershell' => "\$Env:$name = '$value'",
      'cmd' => 'set "$name=$value"',
      _ => "export $name='$value'",
    };
    return EnvCommand(command: command, shell: resolved, kind: 'export');
  }
}

/// Records installs instead of touching the machine.
class FakeInstaller extends CliInstaller {
  FakeInstaller({this.ok = true});

  final bool ok;
  int installs = 0;

  @override
  Future<CliInstallResult> install() async {
    installs++;
    return CliInstallResult(
      ok: ok,
      message: ok ? 'Installed.' : 'Nope.',
      installedPath: ok ? '/usr/local/bin/path_vador' : null,
    );
  }

  @override
  Future<bool> isInstalled() async => false;
}

void main() {
  late MemorySettingsStore store;
  late SettingsController controller;
  late FakeInstaller installer;

  setUp(() {
    store = MemorySettingsStore();
    controller = SettingsController(store, const AppSettings());
    installer = FakeInstaller();
  });

  Future<void> pumpFlow(
    WidgetTester tester, {
    PathEngine? engine,
    Map<String, String> env = const {'SHELL': '/bin/zsh'},
    Size size = const Size(640, 760),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      SettingsScope(
        controller: controller,
        child: EngineScope(
          engine: engine ?? FakePathEngine(),
          child: MaterialApp(
            theme: pvTheme(Brightness.dark),
            home: ValueListenableBuilder<AppSettings>(
              valueListenable: controller,
              builder: (_, s, _) => s.onboarded
                  ? const Scaffold(body: Text('INSPECTOR'))
                  : OnboardingFlow(installer: installer, environment: env),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapPrimary(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(FilledButton, label));
    await tester.pumpAndSettle();
  }

  testWidgets('walking all five steps sets onboarded', (tester) async {
    await pumpFlow(tester);

    expect(find.text('Welcome to PathVador'), findsOneWidget);
    expect(find.text('Skip setup'), findsNothing);
    await tapPrimary(tester, 'Set up in a minute');

    expect(find.text('Which shell do you use?'), findsOneWidget);
    expect(find.textContaining('found zsh'), findsOneWidget);
    expect(find.text('Auto — zsh right now'), findsOneWidget);
    expect(find.text('DETECTED'), findsOneWidget);
    expect(find.text("export PROJECT_ROOT='/Users/you/dev'"), findsNWidgets(2));
    await tapPrimary(tester, 'Continue');

    expect(find.text('Where do relative paths start?'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('base-preview'))).data,
      '/Users/you/README.MD',
    );
    await tester.enterText(find.byType(TextField), '/Users/you/dev');
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('base-preview'))).data,
      '/Users/you/dev/README.MD',
    );
    expect(controller.value.baseFolder, '/Users/you/dev');
    await tapPrimary(tester, 'Continue');

    expect(find.text('Use it from the terminal too?'), findsOneWidget);
    expect(find.text('Install the path_vador command'), findsOneWidget);
    expect(find.text('/Users/you/dev/README.MD'), findsOneWidget);
    await tapPrimary(tester, 'Finish');
    expect(installer.installs, 1);
    expect(controller.value.cliInstalled, isTrue);

    expect(find.text('Ready.'), findsOneWidget);
    expect(find.text('CLI installed'), findsOneWidget);
    expect(find.text('⌘1 ⌘2 ⌘3'), findsOneWidget);
    expect(controller.value.onboarded, isFalse);
    await tapPrimary(tester, 'Open inspector');

    expect(controller.value.onboarded, isTrue);
    expect(store.value.onboarded, isTrue);
    expect(find.text('INSPECTOR'), findsOneWidget);
  });

  testWidgets('unchecking the CLI skips the install', (tester) async {
    await pumpFlow(tester);
    await tapPrimary(tester, 'Set up in a minute');
    await tapPrimary(tester, 'Continue');
    await tapPrimary(tester, 'Continue');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tapPrimary(tester, 'Finish');
    expect(installer.installs, 0);
    expect(find.text('CLI not installed'), findsOneWidget);
  });

  testWidgets('Back returns to the previous step', (tester) async {
    await pumpFlow(tester);
    await tapPrimary(tester, 'Set up in a minute');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Back'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to PathVador'), findsOneWidget);
  });

  testWidgets('Skip sets defaults and onboarded', (tester) async {
    controller.value = const AppSettings(
      shell: ShellChoice.cmd,
      followDrops: false,
    );
    await pumpFlow(tester);
    await tapPrimary(tester, 'Set up in a minute');
    await tester.tap(find.text('Skip setup'));
    await tester.pumpAndSettle();

    expect(store.value.onboarded, isTrue);
    expect(store.value.shell, ShellChoice.auto);
    expect(store.value.followDrops, isTrue);
    expect(installer.installs, 0);
    expect(find.text('INSPECTOR'), findsOneWidget);
  });

  testWidgets('choosing PowerShell persists', (tester) async {
    await pumpFlow(tester);
    await tapPrimary(tester, 'Set up in a minute');
    await tester.tap(find.text('PowerShell'));
    await tester.pumpAndSettle();

    expect(controller.value.shell, ShellChoice.powershell);
    expect(store.value.shell, ShellChoice.powershell);
    expect(find.text(r"$Env:PROJECT_ROOT = '/Users/you/dev'"), findsOneWidget);
  });

  testWidgets('Windows with empty SHELL assumes PowerShell', (tester) async {
    await pumpFlow(
      tester,
      engine: FakePathEngine(goos: 'windows', shell: 'powershell'),
      env: const {},
    );
    await tapPrimary(tester, 'Set up in a minute');
    expect(
      find.textContaining('it was empty, so on Windows we assume PowerShell'),
      findsOneWidget,
    );
    expect(find.text('ASSUMED'), findsOneWidget);
    expect(find.text('sh · bash · zsh (Git Bash, WSL)'), findsOneWidget);
    await tapPrimary(tester, 'Continue');
    await tapPrimary(tester, 'Continue');
    expect(find.text('Add path_vador to your user PATH'), findsOneWidget);
    expect(find.textContaining('Invoke-Expression'), findsOneWidget);
  });

  testWidgets('every step fits the minimum window', (tester) async {
    await pumpFlow(tester, size: const Size(520, 600));
    await tapPrimary(tester, 'Set up in a minute');
    await tapPrimary(tester, 'Continue');
    await tapPrimary(tester, 'Continue');
    await tapPrimary(tester, 'Finish');
    expect(find.text('Ready.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SettingsPage changes theme and shell', (tester) async {
    tester.view.physicalSize = const Size(640, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      SettingsScope(
        controller: controller,
        child: EngineScope(
          engine: FakePathEngine(),
          child: MaterialApp(
            theme: pvTheme(Brightness.light),
            home: SettingsPage(
              installer: installer,
              environment: const {'SHELL': '/bin/zsh'},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(store.value.themeMode, ThemeMode.dark);
    await tester.tap(find.text('cmd'));
    await tester.pumpAndSettle();
    expect(store.value.shell, ShellChoice.cmd);
    expect(find.text('Install command'), findsOneWidget);
  });
}
