import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_vador_ui/engine/engine_loader.dart';
import 'package:path_vador_ui/engine/ffi_engine.dart';
import 'package:path_vador_ui/engine/path_engine.dart';

/// First existing library among the loader's candidates (PATHVADOR_LIB, then
/// `ui/native/<os>/` found by walking up from the test's working directory).
String? _findLibrary() {
  for (final p in candidateLibraryPaths()) {
    if (File(p).existsSync()) return p;
  }
  return null;
}

void main() {
  final lib = _findLibrary();
  final skip = lib == null
      ? 'Go library not built (run `make ui-native` or set PATHVADOR_LIB); '
            'tried ${candidateLibraryPaths().length} paths'
      : false;

  group('FfiPathEngine against the real library', () {
    late PathEngine engine;
    setUpAll(() => engine = FfiPathEngine(DynamicLibrary.open(lib!)));

    test('detect', () async {
      final info = await engine.detect();
      expect(['sh', 'powershell', 'cmd'], contains(info.shell));
      final goos = Platform.isMacOS ? 'darwin' : Platform.operatingSystem;
      expect(info.goos, goos);
      expect(info.separator, Platform.pathSeparator);
      expect(info.home, isNotEmpty);
    });

    test('inspect', () async {
      if (Platform.isWindows) return; // POSIX expectations below.
      final r = await engine.inspect(
        './internal/../pkg/env.go',
        base: '/Users/you/dev',
      );
      expect(r.clean, 'pkg/env.go');
      expect(r.abs, '/Users/you/dev/pkg/env.go');
      expect(r.dir, 'pkg');
      expect(r.base, 'env.go');
      expect(r.ext, '.go');
      expect(r.stem, 'env');
    });

    test('inspect of an empty path is an error', () async {
      await expectLater(engine.inspect(''), throwsA(isA<EngineException>()));
    });

    test('join', () async {
      final sep = Platform.pathSeparator;
      expect(
        await engine.join(['src', 'assets', 'logo.svg']),
        'src${sep}assets${sep}logo.svg',
      );
    });

    test('env export and unset', () async {
      final export = await engine.env(
        shell: 'sh',
        name: 'PROJECT_ROOT',
        value: '/Users/you/dev',
      );
      expect(export.command, "export PROJECT_ROOT='/Users/you/dev'");
      expect(export.shell, 'sh');
      expect(export.kind, 'export');

      final unset = await engine.env(shell: 'powershell', name: 'X', value: '');
      expect(unset.command, 'Remove-Item Env:X');
      expect(unset.kind, 'unset');
    });

    test('env errors come back as EngineException', () async {
      await expectLater(
        engine.env(shell: 'sh', name: '1BAD', value: 'x'),
        throwsA(
          isA<EngineException>().having(
            (e) => e.message,
            'message',
            contains('1BAD'),
          ),
        ),
      );
      await expectLater(
        engine.env(shell: 'cmd', name: 'X', value: '%X%'),
        throwsA(
          isA<EngineException>().having(
            (e) => e.message,
            'message',
            contains('cmd'),
          ),
        ),
      );
    });
  }, skip: skip);
}
