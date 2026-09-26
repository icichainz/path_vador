import 'dart:io';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:path_vador_ui/settings/app_settings.dart';
import 'package:path_vador_ui/settings/settings_store.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('pv_settings_'));
  tearDown(() => dir.deleteSync(recursive: true));

  File settingsFile() => File('${dir.path}/settings.json');

  test('missing file loads defaults', () async {
    final store = FileSettingsStore(directory: dir);
    expect(await store.load(), const AppSettings());
  });

  test('corrupt file loads defaults', () async {
    settingsFile().writeAsStringSync('{not json');
    expect(await FileSettingsStore(directory: dir).load(), const AppSettings());
  });

  test('wrong JSON shape loads defaults', () async {
    settingsFile().writeAsStringSync('[1, 2, 3]');
    expect(await FileSettingsStore(directory: dir).load(), const AppSettings());
    settingsFile().writeAsStringSync('{"onboarded": "yes"}');
    expect(await FileSettingsStore(directory: dir).load(), const AppSettings());
  });

  test('round-trips every field', () async {
    const s = AppSettings(
      onboarded: true,
      shell: ShellChoice.powershell,
      baseFolder: '/Users/you/dev',
      followDrops: false,
      cliInstalled: true,
      recents: ['/a', '/b'],
      themeMode: ThemeMode.dark,
    );
    await FileSettingsStore(directory: dir).save(s);
    expect(await FileSettingsStore(directory: dir).load(), s);
  });

  test('writes atomically and leaves no temp file', () async {
    final store = FileSettingsStore(directory: dir);
    await Future.wait([
      for (var i = 0; i < 10; i++)
        store.save(AppSettings(baseFolder: '/dir$i')),
    ]);
    expect((await store.load()).baseFolder, '/dir9');
    expect(File('${settingsFile().path}.tmp').existsSync(), isFalse);
  });

  test('creates the directory if needed', () async {
    final nested = Directory('${dir.path}/a/b');
    await FileSettingsStore(
      directory: nested,
    ).save(const AppSettings(onboarded: true));
    expect((await FileSettingsStore(directory: nested).load()).onboarded, true);
  });

  test('MemorySettingsStore keeps the last save', () async {
    final store = MemorySettingsStore();
    await store.save(const AppSettings(onboarded: true));
    expect((await store.load()).onboarded, isTrue);
    expect(store.saves, 1);
  });
}
