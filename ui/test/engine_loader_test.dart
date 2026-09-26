import 'package:flutter_test/flutter_test.dart';
import 'package:path_vador_ui/engine/engine_loader.dart';

void main() {
  group('libraryCandidates', () {
    test('macOS: env, Frameworks, exe dir, then ui/native walking up', () {
      final c = libraryCandidates(
        os: 'macos',
        environment: const {'PATHVADOR_LIB': '/opt/lib/libpathvador.dylib'},
        resolvedExecutable: '/Apps/pv.app/Contents/MacOS/pv',
        currentDirectory: '/Users/me/path_vador/ui',
      );
      expect(c, [
        '/opt/lib/libpathvador.dylib',
        '/Apps/pv.app/Contents/MacOS/../Frameworks/libpathvador.dylib',
        '/Apps/pv.app/Contents/MacOS/libpathvador.dylib',
        '/Users/me/path_vador/ui/ui/native/macos/libpathvador.dylib',
        '/Users/me/path_vador/ui/native/macos/libpathvador.dylib',
        '/Users/me/ui/native/macos/libpathvador.dylib',
        '/Users/ui/native/macos/libpathvador.dylib',
        '/ui/native/macos/libpathvador.dylib',
      ]);
    });

    test('Linux: no PATHVADOR_LIB, .so next to the executable', () {
      final c = libraryCandidates(
        os: 'linux',
        environment: const {},
        resolvedExecutable: '/usr/lib/pv/pv',
        currentDirectory: '/',
      );
      expect(c, [
        '/usr/lib/pv/libpathvador.so',
        '/ui/native/linux/libpathvador.so',
      ]);
    });

    test('Windows: backslashes and drive roots', () {
      final c = libraryCandidates(
        os: 'windows',
        environment: const {'PATHVADOR_LIB': '  '},
        resolvedExecutable: r'C:\Program Files\pv\pv.exe',
        currentDirectory: r'C:\src\path_vador',
      );
      expect(c, [
        r'C:\Program Files\pv\pathvador.dll',
        r'C:\src\path_vador\ui\native\windows\pathvador.dll',
        r'C:\src\ui\native\windows\pathvador.dll',
        r'C:\ui\native\windows\pathvador.dll',
      ]);
    });

    test('duplicates are removed and empty inputs skipped', () {
      final c = libraryCandidates(
        os: 'linux',
        environment: const {'PATHVADOR_LIB': '/a/libpathvador.so'},
        resolvedExecutable: '/a/pv',
        currentDirectory: '',
      );
      expect(c, ['/a/libpathvador.so']);
    });
  });

  test('libraryFileName', () {
    expect(libraryFileName('macos'), 'libpathvador.dylib');
    expect(libraryFileName('linux'), 'libpathvador.so');
    expect(libraryFileName('windows'), 'pathvador.dll');
  });

  test('candidateLibraryPaths uses the running process', () {
    expect(candidateLibraryPaths(), isNotEmpty);
  });
}
