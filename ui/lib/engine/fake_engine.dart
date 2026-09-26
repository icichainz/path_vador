import 'path_engine.dart';

/// Deterministic, POSIX-only [PathEngine] for widget tests. NEVER used by
/// the app.
///
/// As a test double it deliberately reimplements a small subset of the Go
/// rules (lexical `path.Clean`, `filepath.Join`, sh/PowerShell/cmd command
/// formatting) so tests can assert realistic values without the native
/// library. The Go library stays the single source of truth for production.
///
/// `detect` reports `sh` on `darwin` with separator `/` and home
/// [home]; an empty `base` in [inspect] resolves against [home].
class FakePathEngine implements PathEngine {
  /// Creates the fake; [shell] is what `auto` resolves to.
  const FakePathEngine({this.home = '/home/you', this.shell = 'sh'});

  final String home;
  final String shell;

  @override
  Future<EngineInfo> detect() async =>
      EngineInfo(shell: shell, goos: 'darwin', separator: '/', home: home);

  @override
  Future<PathInspection> inspect(String path, {String base = ''}) async {
    if (path.isEmpty) throw const EngineException('path is empty');
    final root = base.isEmpty ? home : base;
    final clean = _clean(path);
    final abs = path.startsWith('/') ? clean : _clean('$root/$path');
    final b = _base(path);
    final ext = _ext(path);
    return PathInspection(
      clean: clean,
      abs: abs,
      dir: _dir(path),
      base: b,
      ext: ext,
      stem: b.substring(0, b.length - ext.length),
    );
  }

  @override
  Future<String> join(List<String> parts) async {
    final nonEmpty = parts.where((p) => p.isNotEmpty).toList();
    return nonEmpty.isEmpty ? '' : _clean(nonEmpty.join('/'));
  }

  @override
  Future<EnvCommand> env({
    required String shell,
    required String name,
    required String value,
  }) async {
    final resolved = switch (shell.trim().toLowerCase()) {
      '' || 'auto' => this.shell,
      'sh' || 'bash' || 'zsh' => 'sh',
      'powershell' || 'pwsh' => 'powershell',
      'cmd' => 'cmd',
      _ => throw EngineException('unsupported shell "$shell"'),
    };
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name)) {
      throw EngineException('invalid variable name "$name"');
    }
    if (value.isEmpty) {
      final command = switch (resolved) {
        'sh' => 'unset $name',
        'powershell' => 'Remove-Item Env:$name',
        _ => 'set "$name="',
      };
      return EnvCommand(command: command, shell: resolved, kind: 'unset');
    }
    final String command;
    switch (resolved) {
      case 'sh':
        command = "export $name='${value.replaceAll("'", "'\"'\"'")}'";
      case 'powershell':
        command = "\$Env:$name = '${value.replaceAll("'", "''")}'";
      default:
        final bad = RegExp('["%!\r\n]').firstMatch(value);
        if (bad != null) {
          throw EngineException(
            "cmd cannot safely set a value containing '${bad[0]}'; "
            'use --shell powershell',
          );
        }
        command = 'set "$name=$value"';
    }
    return EnvCommand(command: command, shell: resolved, kind: 'export');
  }

  /// Lexical clean, as Go's `path.Clean`.
  static String _clean(String p) {
    if (p.isEmpty) return '.';
    final rooted = p.startsWith('/');
    final out = <String>[];
    for (final seg in p.split('/')) {
      if (seg.isEmpty || seg == '.') continue;
      if (seg == '..') {
        if (out.isNotEmpty && out.last != '..') {
          out.removeLast();
        } else if (!rooted) {
          out.add('..');
        }
        continue;
      }
      out.add(seg);
    }
    final joined = out.join('/');
    if (rooted) return '/$joined';
    return joined.isEmpty ? '.' : joined;
  }

  static String _base(String p) {
    if (p.isEmpty) return '.';
    var s = p;
    while (s.length > 1 && s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (s == '/') return '/';
    return s.substring(s.lastIndexOf('/') + 1);
  }

  static String _dir(String p) =>
      _clean(p.substring(0, p.lastIndexOf('/') + 1));

  static String _ext(String p) {
    for (var i = p.length - 1; i >= 0 && p[i] != '/'; i--) {
      if (p[i] == '.') return p.substring(i);
    }
    return '';
  }
}
