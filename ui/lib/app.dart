import 'package:flutter/material.dart';

import 'engine/path_engine.dart';
import 'inspector/inspector_screen.dart';
import 'onboarding/onboarding_flow.dart';
import 'settings/app_settings.dart';
import 'settings/settings_page.dart';
import 'theme/helm_icon.dart';
import 'theme/theme.dart';

/// The app: themes from settings, the engine and settings in scope, and
/// the onboarding flow until it has been completed or skipped.
class PathVadorApp extends StatelessWidget {
  const PathVadorApp({super.key, required this.settings, required this.engine});

  final SettingsController settings;
  final PathEngine engine;

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      controller: settings,
      child: EngineScope(
        engine: engine,
        child: Builder(
          builder: (context) {
            final s = SettingsScope.of(context).value;
            return MaterialApp(
              title: 'PathVador',
              debugShowCheckedModeBanner: false,
              theme: pvTheme(Brightness.light),
              darkTheme: pvTheme(Brightness.dark),
              themeMode: s.themeMode,
              home: s.onboarded
                  // Builder: showSettings needs a context under the Navigator.
                  ? Builder(
                      builder: (context) => InspectorScreen(
                        onOpenSettings: () => showSettings(context),
                      ),
                    )
                  : const OnboardingFlow(),
            );
          },
        ),
      ),
    );
  }
}

/// Shown instead of [PathVadorApp] when the Go library cannot be loaded.
class EngineErrorApp extends StatelessWidget {
  const EngineErrorApp({
    super.key,
    required this.error,
    this.themeMode = ThemeMode.system,
  });

  final String error;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PathVador',
      debugShowCheckedModeBanner: false,
      theme: pvTheme(Brightness.light),
      darkTheme: pvTheme(Brightness.dark),
      themeMode: themeMode,
      home: EngineErrorScreen(error: error),
    );
  }
}

/// Full-window explanation of an engine load failure.
class EngineErrorScreen extends StatelessWidget {
  const EngineErrorScreen({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final pv = context.pv;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HelmIcon(size: 56),
              const SizedBox(height: 24),
              Text("PathVador couldn't start", style: text.headlineSmall),
              const SizedBox(height: 10),
              Text(
                'The window needs the Go library that does the real work, '
                'and it could not be loaded.',
                style: text.bodyLarge?.copyWith(color: pv.onSurfaceMuted),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: pv.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pv.error.withValues(alpha: 0.5)),
                ),
                child: SelectableText(
                  error,
                  style: pvMono(context, color: pv.onErrorContainer),
                ),
              ),
              const SizedBox(height: 24),
              Text('Where is libpathvador?', style: text.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Build it with `make ui-native` from the repo root, or set '
                'PATHVADOR_LIB to the full path of the library. The lookup '
                'order and file names are in ui/ENGINE.md.',
                style: text.bodyMedium?.copyWith(color: pv.onSurfaceMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
