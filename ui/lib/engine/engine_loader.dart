import 'dart:ffi';
import 'dart:io';

import 'ffi_engine.dart';
import 'path_engine.dart';

/// File name of the Go library on [os] (a `Platform.operatingSystem` value).
String libraryFileName(String os) => switch (os) {
  'macos' => 'libpathvador.dylib',
  'windows' => 'pathvador.dll',
  _ => 'libpathvador.so',
};

/// Every path [loadPathEngine] tries, in ENGINE.md order:
///
/// 1. `PATHVADOR_LIB` from [environment] (a full path);
/// 2. next to [resolvedExecutable] (`../Frameworks/` then `.` on macOS,
///    `.` elsewhere);
/// 3. `ui/native/<os>/<lib>` in [currentDirectory] and each of its parents
///    (development runs from anywhere inside the repo).
///
/// Pure: all inputs are injected so it can be tested for any platform.
List<String> libraryCandidates({
  required String os,
  required Map<String, String> environment,
  required String resolvedExecutable,
  required String currentDirectory,
}) {
  final sep = os == 'windows' ? r'\' : '/';
  final lib = libraryFileName(os);
  final out = <String>[];
  void add(String p) {
    if (p.isNotEmpty && !out.contains(p)) out.add(p);
  }

  final fromEnv = environment['PATHVADOR_LIB'];
  if (fromEnv != null && fromEnv.trim().isNotEmpty) add(fromEnv.trim());

  if (resolvedExecutable.isNotEmpty) {
    final exeDir = _parent(resolvedExecutable, sep, os);
    if (os == 'macos') {
      add(_join(exeDir, ['..', 'Frameworks', lib], sep));
    }
    add(_join(exeDir, [lib], sep));
  }

  if (currentDirectory.isNotEmpty) {
    var dir = currentDirectory;
    while (true) {
      add(_join(dir, ['ui', 'native', os, lib], sep));
      final parent = _parent(dir, sep, os);
      if (parent == dir) break;
      dir = parent;
    }
  }
  return out;
}

/// [libraryCandidates] for the running process; shown on the error screen
/// when no library opens.
List<String> candidateLibraryPaths() => libraryCandidates(
  os: Platform.operatingSystem,
  environment: Platform.environment,
  resolvedExecutable: Platform.resolvedExecutable,
  currentDirectory: Directory.current.path,
);

/// Opens the Go library from the first candidate that loads and wraps it in
/// an [FfiPathEngine]. Throws a [StateError] listing every path tried (and
/// why each failed) when none opens.
Future<PathEngine> loadPathEngine() async {
  final tried = <String>[];
  for (final path in candidateLibraryPaths()) {
    if (!File(path).existsSync()) {
      tried.add('$path (not found)');
      continue;
    }
    try {
      return FfiPathEngine(DynamicLibrary.open(path));
    } on Object catch (e) {
      tried.add('$path ($e)');
    }
  }
  throw StateError(
    'Could not load the path_vador engine library. Tried:\n'
    '${tried.map((t) => '  - $t').join('\n')}\n'
    'Build it with `make ui-native` or set PATHVADOR_LIB.',
  );
}

String _join(String dir, List<String> parts, String sep) {
  final head = dir.endsWith(sep) ? dir : '$dir$sep';
  return '$head${parts.join(sep)}';
}

/// Lexical parent of [p]; returns [p] itself at the root.
String _parent(String p, String sep, String os) {
  var trimmed = p;
  while (trimmed.length > 1 && trimmed.endsWith(sep)) {
    if (os == 'windows' && trimmed.length == 3 && trimmed[1] == ':') break;
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  final i = trimmed.lastIndexOf(sep);
  if (i < 0) return trimmed;
  if (i == 0) return sep;
  if (i == trimmed.length - 1) return trimmed; // Windows drive root "C:\"
  final parent = trimmed.substring(0, i);
  if (os == 'windows' && parent.length == 2 && parent[1] == ':') {
    return '$parent$sep';
  }
  return parent;
}
