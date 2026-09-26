import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'app_settings.dart';

/// Persists [AppSettings] as `settings.json` in the platform's application
/// support directory (or [directory], for tests).
///
/// Writes are atomic (temp file + rename) and serialised; loading never
/// throws: a missing or unreadable file yields the defaults.
class FileSettingsStore implements SettingsStore {
  FileSettingsStore({Directory? directory}) : _directory = directory;

  static const fileName = 'settings.json';

  Directory? _directory;
  Future<void> _pending = Future.value();

  Future<Directory> _dir() async =>
      _directory ??= await getApplicationSupportDirectory();

  /// The settings file this store reads and writes.
  Future<File> file() async => File('${(await _dir()).path}/$fileName');

  @override
  Future<AppSettings> load() async {
    try {
      final f = await file();
      if (!await f.exists()) return const AppSettings();
      final decoded = jsonDecode(await f.readAsString());
      if (decoded is! Map) return const AppSettings();
      return AppSettings.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) {
    final next = _pending.then((_) => _write(settings));
    // Keep the chain alive even if one write fails.
    _pending = next.catchError((_) {});
    return next;
  }

  Future<void> _write(AppSettings settings) async {
    final dir = await _dir();
    await dir.create(recursive: true);
    final target = File('${dir.path}/$fileName');
    final temp = File('${target.path}.tmp');
    const encoder = JsonEncoder.withIndent('  ');
    await temp.writeAsString(encoder.convert(settings.toJson()), flush: true);
    await temp.rename(target.path);
  }
}

/// Keeps settings in memory. For tests and previews.
class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([this.value = const AppSettings()]);

  /// The last saved settings.
  AppSettings value;

  /// How many times [save] was called.
  int saves = 0;

  @override
  Future<AppSettings> load() async => value;

  @override
  Future<void> save(AppSettings settings) async {
    value = settings;
    saves++;
  }
}
