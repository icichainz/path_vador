import 'package:flutter/widgets.dart';

/// Result of `detect`: what the Go library knows about this machine.
class EngineInfo {
  const EngineInfo({
    required this.shell,
    required this.goos,
    required this.separator,
    required this.home,
  });

  /// `sh` | `powershell` | `cmd`, as auto-detection resolved it.
  final String shell;
  final String goos;
  final String separator;
  final String home;
}

/// Result of `inspect`: every derived form of one path.
class PathInspection {
  const PathInspection({
    required this.clean,
    required this.abs,
    required this.dir,
    required this.base,
    required this.ext,
    required this.stem,
  });

  final String clean;
  final String abs;
  final String dir;
  final String base;
  final String ext;
  final String stem;
}

/// Result of `env`.
class EnvCommand {
  const EnvCommand({
    required this.command,
    required this.shell,
    required this.kind,
  });

  final String command;

  /// The shell the command was written for after auto-detection.
  final String shell;

  /// `export` | `unset`.
  final String kind;
}

/// Raised when the engine answers `ok: false`. [message] is the Go
/// library's own wording and is shown to the user verbatim.
class EngineException implements Exception {
  const EngineException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// The one door to `pkg/pathvador`. See ENGINE.md for the wire format.
/// Implementations: the FFI binding (production) and a fake (tests).
abstract class PathEngine {
  Future<EngineInfo> detect();

  /// [base] is the folder relative paths resolve against; empty means the
  /// process working directory.
  Future<PathInspection> inspect(String path, {String base = ''});

  Future<String> join(List<String> parts);

  /// An empty [value] asks for an unset command.
  Future<EnvCommand> env({
    required String shell,
    required String name,
    required String value,
  });
}

/// Provides the [PathEngine] to the widget tree: `EngineScope.of(context)`.
class EngineScope extends InheritedWidget {
  const EngineScope({super.key, required this.engine, required super.child});

  final PathEngine engine;

  static PathEngine of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<EngineScope>();
    assert(scope != null, 'No EngineScope above this widget');
    return scope!.engine;
  }

  @override
  bool updateShouldNotify(EngineScope oldWidget) => engine != oldWidget.engine;
}
