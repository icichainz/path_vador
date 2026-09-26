import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_vador_ui/engine/fake_engine.dart';
import 'package:path_vador_ui/engine/path_engine.dart';
import 'package:path_vador_ui/inspector/inspector_controller.dart';
import 'package:path_vador_ui/inspector/inspector_screen.dart';
import 'package:path_vador_ui/settings/app_settings.dart';
import 'package:path_vador_ui/settings/settings_store.dart';

class _Harness {
  _Harness([AppSettings initial = const AppSettings(onboarded: true)])
    : settings = SettingsController(MemorySettingsStore(initial), initial);

  final SettingsController settings;
  String? clipboard;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(640, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      EngineScope(
        engine: const FakePathEngine(),
        child: SettingsScope(
          controller: settings,
          child: const MaterialApp(home: InspectorScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

/// Lets the 60 ms debounce and the async engine call complete.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

/// Drains the "Copied" timers and snack bar.
Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  await tester.pumpAndSettle();
}

Future<void> _shortcut(WidgetTester tester, LogicalKeyboardKey key) async {
  final modifier = defaultTargetPlatform == TargetPlatform.macOS
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('header shows the detected shell and OS', (tester) async {
    await _Harness().pump(tester);
    expect(find.text('path_vador'), findsOneWidget);
    expect(find.text('sh · darwin'), findsOneWidget);
    expect(
      find.text('Drop a file or folder, or type a path above.'),
      findsOneWidget,
    );
  });

  testWidgets('typing a path shows six derived rows', (tester) async {
    final h = _Harness(
      const AppSettings(onboarded: true, baseFolder: '/home/you/dev'),
    );
    await h.pump(tester);
    await tester.enterText(
      find.byKey(const Key('path-field')),
      './internal/../pkg/env.go',
    );
    await _settle(tester);

    for (final label in [
      'Cleaned',
      'Absolute',
      'Directory',
      'Base name',
      'Extension',
      'Stem',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('pkg/env.go'), findsOneWidget);
    expect(find.text('/home/you/dev/pkg/env.go'), findsOneWidget);
    expect(find.text('pkg'), findsOneWidget);
    expect(find.text('env.go'), findsOneWidget);
    expect(find.text('.go'), findsOneWidget);
    expect(find.text('env'), findsOneWidget);
    expect(find.text('~/dev'), findsOneWidget); // base caption
    expect(
      find.text(r"$ path_vador abs ./internal/../pkg/env.go"),
      findsOneWidget,
    );
    // Typing alone does not add to recents.
    expect(h.settings.value.recents, isEmpty);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(h.settings.value.recents, ['./internal/../pkg/env.go']);
  });

  testWidgets('a file without extension shows (none)', (tester) async {
    await _Harness().pump(tester);
    await tester.enterText(find.byKey(const Key('path-field')), 'Makefile');
    await _settle(tester);
    expect(find.text('(none)'), findsNWidgets(1));
    expect(find.text('/home/you/Makefile'), findsOneWidget);
  });

  testWidgets('Copy puts the value on the clipboard', (tester) async {
    final h = _Harness();
    await h.pump(tester);
    await tester.enterText(find.byKey(const Key('path-field')), '/a/b.txt');
    await _settle(tester);

    await tester.tap(find.text('Copy').first);
    await tester.pump();
    expect(h.clipboard, '/a/b.txt');
    expect(find.text('Copied'), findsWidgets); // button + snack bar
    await _drain(tester);
    expect(find.text('Copied'), findsNothing);
  });

  testWidgets('Join splits a pasted path into fragments', (tester) async {
    await _Harness().pump(tester);
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('fragment-field')),
      'src/assets/logo.svg',
    );
    await tester.pumpAndSettle();

    const expected = ['src', 'assets', 'logo.svg'];
    for (var i = 0; i < expected.length; i++) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('fragment-$i')),
          matching: find.text(expected[i]),
        ),
        findsOneWidget,
      );
    }
    expect(find.text('src/assets/logo.svg'), findsOneWidget); // joined
    expect(find.text(r'$ path_vador join src assets logo.svg'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove assets'));
    await tester.pumpAndSettle();
    expect(find.text('src/logo.svg'), findsOneWidget);

    await tester.tap(find.byTooltip('Inspect joined path'));
    await _settle(tester);
    expect(find.text('Cleaned'), findsOneWidget);
  });

  testWidgets('Env with an empty value shows the unset command', (
    tester,
  ) async {
    await _Harness().pump(tester);
    await tester.tap(find.text('Env'));
    await tester.pumpAndSettle();
    expect(find.text('Name a variable to see the command.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('env-name-field')),
      'PROJECT_ROOT',
    );
    await tester.pumpAndSettle();
    expect(find.text('UNSET COMMAND'), findsOneWidget);
    expect(find.text('unset PROJECT_ROOT'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('env-value-field')), '/x y');
    await tester.pumpAndSettle();
    expect(find.text('EXPORT COMMAND'), findsOneWidget);
    expect(find.text("export PROJECT_ROOT='/x y'"), findsOneWidget);
    expect(
      find.text(r"$ path_vador env export PROJECT_ROOT '/x y'"),
      findsOneWidget,
    );
  });

  testWidgets('cmd errors offer Use PowerShell and persist the shell', (
    tester,
  ) async {
    final h = _Harness();
    await h.pump(tester);
    await tester.tap(find.text('Env'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('env-name-field')), 'X');
    await tester.enterText(find.byKey(const Key('env-value-field')), '%X%');
    await tester.tap(find.text('cmd'));
    await tester.pumpAndSettle();
    expect(h.settings.value.shell, ShellChoice.cmd);
    expect(find.textContaining('cmd cannot safely set'), findsOneWidget);

    await tester.tap(find.text('Use PowerShell'));
    await tester.pumpAndSettle();
    expect(h.settings.value.shell, ShellChoice.powershell);
    expect(find.text(r"$Env:X = '%X%'"), findsOneWidget);
  });

  testWidgets(
    'shortcuts switch tabs and ⌘E sends a value to Env',
    (tester) async {
      await _Harness().pump(tester);
      await tester.enterText(find.byKey(const Key('path-field')), 'a/../b.txt');
      await _settle(tester);

      await _shortcut(tester, LogicalKeyboardKey.keyE);
      expect(find.byKey(const Key('env-value-field')), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const Key('env-value-field')),
      );
      expect(field.controller!.text, 'b.txt');

      await _shortcut(tester, LogicalKeyboardKey.digit2);
      expect(find.text('Fragments, in order'), findsOneWidget);
      await _shortcut(tester, LogicalKeyboardKey.digit1);
      expect(find.text('Cleaned'), findsOneWidget);
    },
    variant: TargetPlatformVariant.desktop(),
  );

  testWidgets('→ env on a row sends that row', (tester) async {
    await _Harness().pump(tester);
    await tester.enterText(find.byKey(const Key('path-field')), 'a/b.txt');
    await _settle(tester);
    await tester.tap(find.byTooltip('Send to Env').at(1)); // Absolute
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.byKey(const Key('env-value-field')),
    );
    expect(field.controller!.text, '/home/you/a/b.txt');
  });

  test('controller drops stale inspect results', () async {
    final c = InspectorController(
      const FakePathEngine(),
      debounce: Duration.zero,
    );
    await c.start();
    c.pathField.text = 'one.txt';
    c.pathField.text = 'two.txt';
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.inspection?.base, 'two.txt');
    c.dispose();
  });

  test('splitFragments keeps a root and drops empty pieces', () {
    final c = InspectorController(const FakePathEngine());
    expect(c.splitFragments('/usr//local/'), ['/', 'usr', 'local']);
    expect(c.splitFragments('src'), ['src']);
    expect(c.splitFragments('  '), isEmpty);
    c.dispose();
  });

  test('shellQuoteArg', () {
    expect(shellQuoteArg('/a/b-c_d.e:f=g~'), '/a/b-c_d.e:f=g~');
    expect(shellQuoteArg('a b'), "'a b'");
    expect(shellQuoteArg("it's"), "'it'\"'\"'s'");
    expect(shellQuoteArg(''), "''");
  });
}
