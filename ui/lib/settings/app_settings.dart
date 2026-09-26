import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';

/// The shell a generated env command targets. `auto` defers to the Go
/// library's detection.
enum ShellChoice { auto, sh, powershell, cmd }

/// Everything the first-run flow asks, plus what the inspector remembers.
/// Persisted as JSON by [SettingsStore]; changed through [SettingsScope].
@immutable
class AppSettings {
  const AppSettings({
    this.onboarded = false,
    this.shell = ShellChoice.auto,
    this.baseFolder = '',
    this.followDrops = true,
    this.cliInstalled = false,
    this.recents = const [],
    this.themeMode = ThemeMode.system,
  });

  final bool onboarded;
  final ShellChoice shell;

  /// Folder relative paths resolve against. Empty means the user's home.
  final String baseFolder;

  /// When a file is dropped, its folder becomes [baseFolder].
  final bool followDrops;
  final bool cliInstalled;

  /// Most recent first, at most [maxRecents].
  final List<String> recents;
  final ThemeMode themeMode;

  static const maxRecents = 8;

  AppSettings copyWith({
    bool? onboarded,
    ShellChoice? shell,
    String? baseFolder,
    bool? followDrops,
    bool? cliInstalled,
    List<String>? recents,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      onboarded: onboarded ?? this.onboarded,
      shell: shell ?? this.shell,
      baseFolder: baseFolder ?? this.baseFolder,
      followDrops: followDrops ?? this.followDrops,
      cliInstalled: cliInstalled ?? this.cliInstalled,
      recents: recents ?? this.recents,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  /// Returns a copy with [path] moved to the front of [recents].
  AppSettings withRecent(String path) {
    final next = [path, ...recents.where((r) => r != path)];
    return copyWith(recents: next.take(maxRecents).toList());
  }

  Map<String, Object?> toJson() => {
        'onboarded': onboarded,
        'shell': shell.name,
        'baseFolder': baseFolder,
        'followDrops': followDrops,
        'cliInstalled': cliInstalled,
        'recents': recents,
        'themeMode': themeMode.name,
      };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      onboarded: json['onboarded'] as bool? ?? false,
      shell: ShellChoice.values.asNameMap()[json['shell']] ?? ShellChoice.auto,
      baseFolder: json['baseFolder'] as String? ?? '',
      followDrops: json['followDrops'] as bool? ?? true,
      cliInstalled: json['cliInstalled'] as bool? ?? false,
      recents: (json['recents'] as List?)?.cast<String>() ?? const [],
      themeMode:
          ThemeMode.values.asNameMap()[json['themeMode']] ?? ThemeMode.system,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.onboarded == onboarded &&
      other.shell == shell &&
      other.baseFolder == baseFolder &&
      other.followDrops == followDrops &&
      other.cliInstalled == cliInstalled &&
      listEquals(other.recents, recents) &&
      other.themeMode == themeMode;

  @override
  int get hashCode => Object.hash(onboarded, shell, baseFolder, followDrops,
      cliInstalled, Object.hashAll(recents), themeMode);
}

/// Loads and saves [AppSettings]. The production implementation writes a
/// JSON file under the platform config directory; tests use an in-memory one.
abstract class SettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

/// Holds the live settings and persists every change.
class SettingsController extends ValueNotifier<AppSettings> {
  SettingsController(this._store, AppSettings initial) : super(initial);

  final SettingsStore _store;

  Future<void> update(AppSettings Function(AppSettings current) change) async {
    value = change(value);
    await _store.save(value);
  }
}

/// Makes the [SettingsController] available to the widget tree:
/// `SettingsScope.of(context)` rebuilds on every change.
class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({
    super.key,
    required SettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static SettingsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'No SettingsScope above this widget');
    return scope!.notifier!;
  }
}
