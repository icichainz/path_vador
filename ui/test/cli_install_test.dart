import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_vador_ui/settings/cli_install.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('pv_cli_'));
  tearDown(() => root.deleteSync(recursive: true));

  File touch(String rel, [String content = '']) {
    final f = File('${root.path}/$rel')..createSync(recursive: true);
    f.writeAsStringSync(content);
    return f;
  }

  String real(String rel) =>
      File('${root.path}/$rel').resolveSymbolicLinksSync();

  group('resolveCliBinary', () {
    test('finds the binary next to the executable', () {
      touch('app/runner');
      touch('app/path_vador');
      expect(
        resolveCliBinary(
          executable: '${root.path}/app/runner',
          workingDirectory: root.path,
          operatingSystem: 'linux',
        ),
        real('app/path_vador'),
      );
    });

    test('uses .exe on Windows naming', () {
      touch('app/runner.exe');
      touch('app/path_vador.exe');
      expect(
        resolveCliBinary(
          executable: '${root.path}/app/runner.exe',
          workingDirectory: root.path,
          operatingSystem: 'windows',
        ),
        real('app/path_vador.exe'),
      );
    });

    test('never returns the running macOS app binary itself', () {
      touch('path_vador.app/Contents/MacOS/path_vador');
      touch('path_vador.app/Contents/Resources/path_vador');
      expect(
        resolveCliBinary(
          executable: '${root.path}/path_vador.app/Contents/MacOS/path_vador',
          workingDirectory: root.path,
          operatingSystem: 'macos',
        ),
        real('path_vador.app/Contents/Resources/path_vador'),
      );
    });

    test('falls back to <repo>/bin when running from source', () {
      touch(
        'repo/go.mod',
        'module github.com/icichainz/path_vador\n\ngo 1.22\n',
      );
      touch('repo/bin/path_vador');
      touch('repo/ui/build/app/runner');
      Directory('${root.path}/repo/ui/lib').createSync(recursive: true);
      expect(
        resolveCliBinary(
          executable: '${root.path}/repo/ui/build/app/runner',
          workingDirectory: '${root.path}/repo/ui/lib',
          operatingSystem: 'linux',
        ),
        real('repo/bin/path_vador'),
      );
    });

    test('ignores other modules and returns null when nothing is built', () {
      touch('other/go.mod', 'module example.com/other\n');
      touch('other/bin/path_vador');
      touch('app/runner');
      expect(
        resolveCliBinary(
          executable: '${root.path}/app/runner',
          workingDirectory: '${root.path}/other',
          operatingSystem: 'linux',
        ),
        isNull,
      );
    });
  });

  test('parseRegQuery reads value and type', () {
    const out =
        '\r\nHKEY_CURRENT_USER\\Environment\r\n'
        '    Path    REG_EXPAND_SZ    %USERPROFILE%\\bin;C:\\tools\r\n\r\n';
    final r = CliInstaller.parseRegQuery(out)!;
    expect(r.type, 'REG_EXPAND_SZ');
    expect(r.value, r'%USERPROFILE%\bin;C:\tools');
  });

  test('install without a binary fails gracefully', () async {
    touch('app/runner');
    final installer = CliInstaller(
      executable: '${root.path}/app/runner',
      workingDirectory: root.path,
      operatingSystem: 'linux',
      environment: {'HOME': root.path},
    );
    final r = await installer.install();
    expect(r.ok, isFalse);
    expect(r.message, contains('Could not find'));
  });
}
