import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'engine/engine_loader.dart';
import 'engine/path_engine.dart';
import 'settings/app_settings.dart';
import 'settings/settings_store.dart';
import 'theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: pvDefaultWindowSize,
    minimumSize: pvMinWindowSize,
    title: 'path_vador',
    center: true,
    titleBarStyle: TitleBarStyle.normal,
  );
  windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  final store = FileSettingsStore();
  final settings = SettingsController(store, await store.load());

  final PathEngine engine;
  try {
    engine = await loadPathEngine();
  } catch (e) {
    runApp(EngineErrorApp(error: '$e', themeMode: settings.value.themeMode));
    return;
  }
  runApp(PathVadorApp(settings: settings, engine: engine));
}
