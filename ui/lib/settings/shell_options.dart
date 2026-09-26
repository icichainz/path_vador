import 'dart:io' show Platform;

import '../engine/path_engine.dart';
import 'app_settings.dart';

/// What the app knows about the user's shell, for the shell pickers.
class ShellDetection {
  const ShellDetection({
    required this.info,
    required this.name,
    required this.assumed,
  });

  /// Combines the engine's `detect` with `$SHELL` from [environment]
  /// (defaults to the process environment).
  factory ShellDetection.from(
    EngineInfo info, {
    Map<String, String>? environment,
  }) {
    final shellVar = (environment ?? Platform.environment)['SHELL'] ?? '';
    final base = shellVar.split(RegExp(r'[\\/]')).last.trim();
    final assumed = info.goos == 'windows' && shellVar.isEmpty;
    return ShellDetection(
      info: info,
      name: base.isEmpty ? shellLabel(info.shell) : base,
      assumed: assumed,
    );
  }

  final EngineInfo info;

  /// Human name of the detected shell: `$SHELL`'s basename (`zsh`) or the
  /// engine's resolved family (`PowerShell`).
  final String name;

  /// True on Windows when `$SHELL` was empty and PowerShell is a guess.
  final bool assumed;

  bool get isWindows => info.goos == 'windows';
  bool get isMac => info.goos == 'darwin';

  /// `⌘` on macOS, `Ctrl+` elsewhere.
  String get mod => isMac ? '⌘' : 'Ctrl+';

  /// The sentence after "We read $SHELL".
  String get foundSentence => assumed
      ? r'We read $SHELL: it was empty, so on Windows we assume PowerShell.'
      : 'We read \$SHELL and found $name.';

  /// `<home><sep>dev`, the value used in example commands.
  String get exampleValue {
    final home = info.home.endsWith(info.separator)
        ? info.home.substring(0, info.home.length - 1)
        : info.home;
    return '$home${info.separator}dev';
  }
}

/// Display name of an engine shell family.
String shellLabel(String engineShell) => switch (engineShell) {
  'powershell' => 'PowerShell',
  'cmd' => 'cmd',
  _ => 'sh',
};

/// The `shell` value the engine expects for [choice].
String shellWire(ShellChoice choice) => switch (choice) {
  ShellChoice.auto => 'auto',
  ShellChoice.sh => 'sh',
  ShellChoice.powershell => 'powershell',
  ShellChoice.cmd => 'cmd',
};

/// Row title for [choice] in the shell pickers.
String shellTitle(ShellChoice choice, ShellDetection? d) => switch (choice) {
  ShellChoice.auto => 'Auto — ${d?.name ?? '…'} right now',
  ShellChoice.sh =>
    'sh · bash · zsh${d?.isWindows ?? false ? ' (Git Bash, WSL)' : ''}',
  ShellChoice.powershell => 'PowerShell',
  ShellChoice.cmd => 'cmd',
};

/// Short label for summaries ("Auto (zsh)", "PowerShell").
String shellSummary(ShellChoice choice, ShellDetection? d) => switch (choice) {
  ShellChoice.auto => 'Auto (${d?.name ?? '…'})',
  ShellChoice.sh => 'sh · bash · zsh',
  ShellChoice.powershell => 'PowerShell',
  ShellChoice.cmd => 'cmd',
};

/// Placeholder examples until the engine answers.
String fallbackExample(ShellChoice choice, String value) => switch (choice) {
  ShellChoice.auto || ShellChoice.sh => "export PROJECT_ROOT='$value'",
  ShellChoice.powershell => "\$Env:PROJECT_ROOT = '$value'",
  ShellChoice.cmd => 'set "PROJECT_ROOT=$value"',
};

/// Asks the engine for a real `PROJECT_ROOT` export command per choice.
Future<Map<ShellChoice, String>> loadShellExamples(
  PathEngine engine,
  ShellDetection d,
) async {
  final value = d.exampleValue;
  final out = <ShellChoice, String>{};
  for (final choice in ShellChoice.values) {
    try {
      final cmd = await engine.env(
        shell: shellWire(choice),
        name: 'PROJECT_ROOT',
        value: value,
      );
      out[choice] = cmd.command;
    } catch (_) {
      out[choice] = fallbackExample(choice, value);
    }
  }
  return out;
}
