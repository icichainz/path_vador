import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Outcome of [CliInstaller.install]. [message] is shown to the user as is.
class CliInstallResult {
  const CliInstallResult({
    required this.ok,
    required this.message,
    this.installedPath,
  });

  final bool ok;
  final String message;

  /// Where the command now lives: the symlink on macOS/Linux, the folder
  /// added to PATH on Windows.
  final String? installedPath;
}

/// Runs a process; injectable for tests.
typedef ProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

const _moduleLine = 'module github.com/icichainz/path_vador';
const _systemBinDir = '/usr/local/bin';

/// Puts the Go `path_vador` CLI on the user's PATH.
///
/// macOS/Linux: a symlink in `/usr/local/bin` (macOS asks for an admin
/// password via `osascript` when needed; Linux falls back to
/// `~/.local/bin`). Windows: the binary's folder is appended to the user
/// PATH in `HKCU\Environment`. No method throws.
class CliInstaller {
  CliInstaller({
    String? executable,
    String? workingDirectory,
    String? operatingSystem,
    Map<String, String>? environment,
    ProcessRunner? run,
  }) : _executable = executable ?? Platform.resolvedExecutable,
       _cwd = workingDirectory ?? Directory.current.path,
       _os = operatingSystem ?? Platform.operatingSystem,
       _env = environment ?? Platform.environment,
       _run = run ?? ((exe, args) => Process.run(exe, args));

  final String _executable;
  final String _cwd;
  final String _os;
  final Map<String, String> _env;
  final ProcessRunner _run;

  bool get _windows => _os == 'windows';
  String get _home => _env['HOME'] ?? _env['USERPROFILE'] ?? '';
  String get _userBinDir => '$_home/.local/bin';

  /// The CLI binary this app would install, or null if none was found.
  String? binary() => resolveCliBinary(
    executable: _executable,
    workingDirectory: _cwd,
    operatingSystem: _os,
  );

  /// Whether `path_vador` is already on PATH through this installer.
  Future<bool> isInstalled() async {
    try {
      if (_windows) {
        final bin = binary();
        if (bin == null) return false;
        final current = await _readUserPath();
        return current != null &&
            _containsEntry(current.value, File(bin).parent.path);
      }
      for (final dir in [_systemBinDir, _userBinDir]) {
        if (await _isOurLink('$dir/path_vador')) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<CliInstallResult> install() async {
    try {
      final bin = binary();
      if (bin == null) {
        return const CliInstallResult(
          ok: false,
          message:
              'Could not find the path_vador binary next to the app. '
              'Build it with `make build` and try again from Settings.',
        );
      }
      if (_windows) return await _installWindows(bin);
      return await _installUnix(bin);
    } catch (e) {
      return CliInstallResult(ok: false, message: 'Install failed: $e');
    }
  }

  Future<void> uninstall() async {
    try {
      if (_windows) {
        final bin = binary();
        final current = await _readUserPath();
        if (bin == null || current == null) return;
        final folder = _trimSlash(File(bin).parent.path);
        final kept = _entries(
          current.value,
        ).where((e) => _trimSlash(e).toLowerCase() != folder.toLowerCase());
        await _writeUserPath(kept.join(';'), current.type);
        return;
      }
      for (final dir in [_systemBinDir, _userBinDir]) {
        final path = '$dir/path_vador';
        if (!await _isOurLink(path)) continue;
        try {
          await Link(path).delete();
        } on FileSystemException {
          if (_os == 'macos') {
            await _adminShell('rm -f ${_sq(path)}');
          }
        }
      }
    } catch (_) {
      // Never throws; the Settings page re-checks [isInstalled].
    }
  }

  // --- macOS / Linux ---------------------------------------------------

  Future<CliInstallResult> _installUnix(String bin) async {
    final target = '$_systemBinDir/path_vador';
    final clash = await _foreignFile(target);
    if (clash) {
      return CliInstallResult(
        ok: false,
        message: '$target already exists and is not a link. Remove it first.',
      );
    }
    try {
      await _link(target, bin);
      return CliInstallResult(
        ok: true,
        message: 'Installed. Try `path_vador` in a terminal.',
        installedPath: target,
      );
    } on FileSystemException {
      // Permission denied or /usr/local/bin missing.
    }

    if (_os == 'macos') {
      final cmd =
          'mkdir -p ${_sq(_systemBinDir)} && '
          'ln -sf ${_sq(bin)} ${_sq(target)}';
      final r = await _adminShell(cmd);
      if (r.exitCode == 0) {
        return CliInstallResult(
          ok: true,
          message: 'Installed. Try `path_vador` in a terminal.',
          installedPath: target,
        );
      }
      final cancelled = '${r.stderr}'.contains('-128');
      return CliInstallResult(
        ok: false,
        message: cancelled
            ? 'Cancelled. Nothing was installed.'
            : 'Could not link into $_systemBinDir: ${'${r.stderr}'.trim()}',
      );
    }

    // Linux: fall back to ~/.local/bin.
    final userTarget = '$_userBinDir/path_vador';
    if (await _foreignFile(userTarget)) {
      return CliInstallResult(
        ok: false,
        message: '$userTarget already exists and is not a link.',
      );
    }
    await Directory(_userBinDir).create(recursive: true);
    await _link(userTarget, bin);
    final onPath = (_env['PATH'] ?? '').split(':').contains(_userBinDir);
    return CliInstallResult(
      ok: true,
      message: onPath
          ? 'Installed in ~/.local/bin.'
          : 'Installed in ~/.local/bin. Add it to your PATH to use it.',
      installedPath: userTarget,
    );
  }

  Future<void> _link(String at, String to) async {
    final link = Link(at);
    if (await link.exists()) await link.delete();
    await link.create(to);
  }

  /// True when [path] exists and is not a symlink (never clobbered).
  Future<bool> _foreignFile(String path) async {
    final type = await FileSystemEntity.type(path, followLinks: false);
    return type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.link;
  }

  Future<bool> _isOurLink(String path) async {
    if (!await FileSystemEntity.isLink(path)) return false;
    final to = await Link(path).target();
    final name = to.split('/').last;
    return name == 'path_vador';
  }

  Future<ProcessResult> _adminShell(String command) {
    final escaped = command.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    return _run('osascript', [
      '-e',
      'do shell script "$escaped" with administrator privileges',
    ]);
  }

  /// Single-quotes [s] for a POSIX shell.
  static String _sq(String s) => "'${s.replaceAll("'", r"'\''")}'";

  // --- Windows ---------------------------------------------------------

  Future<CliInstallResult> _installWindows(String bin) async {
    final folder = _trimSlash(File(bin).parent.path);
    final current = await _readUserPath();
    if (current == null) {
      return const CliInstallResult(
        ok: false,
        message: r'Could not read HKCU\Environment\Path.',
      );
    }
    if (_containsEntry(current.value, folder)) {
      return CliInstallResult(
        ok: true,
        message: 'Already on your PATH.',
        installedPath: folder,
      );
    }
    final entries = [..._entries(current.value), folder];
    final r = await _writeUserPath(entries.join(';'), current.type);
    if (r.exitCode != 0) {
      return CliInstallResult(
        ok: false,
        message: 'Could not update PATH: ${'${r.stderr}'.trim()}',
      );
    }
    _broadcastEnvironmentChange();
    return CliInstallResult(
      ok: true,
      message:
          'Added to your user PATH. Open a new terminal to use path_vador.',
      installedPath: folder,
    );
  }

  /// Reads the user PATH. An absent value is an empty string; a failed
  /// `reg query` is null.
  Future<({String value, String type})?> _readUserPath() async {
    final r = await _run('reg', ['query', r'HKCU\Environment', '/v', 'Path']);
    if (r.exitCode != 0) {
      // Exit 1 with "unable to find" means the value does not exist yet.
      final out = '${r.stderr}${r.stdout}'.toLowerCase();
      return out.contains('unable to find') || out.contains('not find')
          ? (value: '', type: 'REG_EXPAND_SZ')
          : null;
    }
    return parseRegQuery('${r.stdout}');
  }

  Future<ProcessResult> _writeUserPath(String value, String type) {
    return _run('reg', [
      'add',
      r'HKCU\Environment',
      '/v',
      'Path',
      '/t',
      type,
      '/d',
      value,
      '/f',
    ]);
  }

  /// Parses `reg query ... /v Path` output into its value and type.
  static ({String value, String type})? parseRegQuery(String output) {
    final re = RegExp(r'^\s*Path\s+(REG_\w+)\s*(.*)$', caseSensitive: false);
    for (final line in output.split(RegExp(r'\r?\n'))) {
      final m = re.firstMatch(line);
      if (m != null) return (value: m.group(2)!.trim(), type: m.group(1)!);
    }
    return (value: '', type: 'REG_EXPAND_SZ');
  }

  static Iterable<String> _entries(String path) =>
      path.split(';').where((e) => e.trim().isNotEmpty);

  static bool _containsEntry(String path, String folder) {
    final want = _trimSlash(folder).toLowerCase();
    return _entries(path).any((e) => _trimSlash(e).toLowerCase() == want);
  }

  static String _trimSlash(String s) {
    var out = s.trim();
    while (out.length > 3 && (out.endsWith(r'\') || out.endsWith('/'))) {
      out = out.substring(0, out.length - 1);
    }
    return out;
  }

  /// Tells Explorer (and terminals it starts) that the environment changed.
  static void _broadcastEnvironmentChange() {
    try {
      final user32 = DynamicLibrary.open('user32.dll');
      final send = user32
          .lookupFunction<
            IntPtr Function(
              IntPtr,
              Uint32,
              IntPtr,
              Pointer<Utf16>,
              Uint32,
              Uint32,
              Pointer<IntPtr>,
            ),
            int Function(
              int,
              int,
              int,
              Pointer<Utf16>,
              int,
              int,
              Pointer<IntPtr>,
            )
          >('SendMessageTimeoutW');
      final lParam = 'Environment'.toNativeUtf16();
      try {
        const hwndBroadcast = 0xFFFF;
        const wmSettingChange = 0x001A;
        const smtoAbortIfHung = 0x0002;
        send(
          hwndBroadcast,
          wmSettingChange,
          0,
          lParam,
          smtoAbortIfHung,
          2000,
          nullptr,
        );
      } finally {
        calloc.free(lParam);
      }
    } catch (_) {
      // Best effort: new terminals still read the registry.
    }
  }
}

/// Finds the `path_vador` CLI binary.
///
/// Looks next to [executable] (and, on macOS, in the bundle's `Resources`
/// and `Helpers` folders), never returning [executable] itself: the macOS
/// app's own binary is also called `path_vador`. Then, when running from
/// source, walks up from [workingDirectory] to the repo root (the `go.mod`
/// declaring `github.com/icichainz/path_vador`) and looks in `bin/`.
String? resolveCliBinary({
  required String executable,
  required String workingDirectory,
  required String operatingSystem,
}) {
  final name = operatingSystem == 'windows' ? 'path_vador.exe' : 'path_vador';
  final sep = Platform.pathSeparator;
  final exeDir = File(executable).parent.path;

  final candidates = [
    '$exeDir$sep$name',
    if (operatingSystem == 'macos') ...[
      '$exeDir$sep..${sep}Resources$sep$name',
      '$exeDir$sep..${sep}Helpers$sep$name',
    ],
  ];

  String canonical(String p) {
    try {
      return File(p).resolveSymbolicLinksSync();
    } catch (_) {
      return p;
    }
  }

  final self = canonical(executable);
  for (final c in candidates) {
    if (File(c).existsSync() && canonical(c) != self) return canonical(c);
  }

  var dir = Directory(workingDirectory).absolute;
  while (true) {
    final goMod = File('${dir.path}${sep}go.mod');
    if (goMod.existsSync()) {
      try {
        final declares = goMod.readAsLinesSync().any(
          (l) => l.trim() == _moduleLine,
        );
        if (declares) {
          final bin = File('${dir.path}${sep}bin$sep$name');
          return bin.existsSync() ? canonical(bin.path) : null;
        }
      } catch (_) {
        // Unreadable go.mod: keep walking.
      }
    }
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
}
