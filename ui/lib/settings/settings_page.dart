import 'package:flutter/material.dart';

import '../engine/path_engine.dart';
import '../onboarding/onboarding_steps.dart';
import '../theme/pv_widgets.dart';
import '../theme/theme.dart';
import 'app_settings.dart';
import 'cli_install.dart';
import 'shell_options.dart';

/// Pushes the [SettingsPage] (bound to ⌘, / Ctrl+, by the inspector).
Future<void> showSettings(BuildContext context) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
}

/// Change the onboarding answers later: shell, base folder, drops, theme,
/// and the CLI link.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.installer, this.environment});

  /// Defaults to a real [CliInstaller].
  final CliInstaller? installer;

  /// Overrides the process environment (for `$SHELL`); for tests.
  final Map<String, String>? environment;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final CliInstaller _installer = widget.installer ?? CliInstaller();
  final _base = TextEditingController();
  PathEngine? _engine;
  ShellDetection? _detection;
  Map<ShellChoice, String> _examples = const {};
  bool? _installed;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _checkInstalled();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final engine = EngineScope.of(context);
    if (!identical(engine, _engine)) {
      _engine = engine;
      _detect(engine);
    }
  }

  @override
  void dispose() {
    _base.dispose();
    super.dispose();
  }

  Future<void> _detect(PathEngine engine) async {
    try {
      final d = ShellDetection.from(
        await engine.detect(),
        environment: widget.environment,
      );
      if (!mounted) return;
      final saved = SettingsScope.of(context).value.baseFolder;
      setState(() {
        _detection = d;
        if (_base.text.isEmpty) {
          _base.text = saved.isEmpty ? d.info.home : saved;
        }
      });
      final examples = await loadShellExamples(engine, d);
      if (mounted) setState(() => _examples = examples);
    } catch (_) {
      // Keep placeholders.
    }
  }

  Future<void> _checkInstalled() async {
    final v = await _installer.isInstalled();
    if (mounted) setState(() => _installed = v);
  }

  Future<void> _toggleCli() async {
    final settings = SettingsScope.of(context);
    setState(() => _busy = true);
    if (_installed ?? false) {
      await _installer.uninstall();
      final still = await _installer.isInstalled();
      await settings.update((s) => s.copyWith(cliInstalled: still));
      if (mounted) {
        showPvSnackBar(
          context,
          still ? 'Could not remove the command.' : 'Command removed.',
        );
      }
    } else {
      final r = await _installer.install();
      await settings.update((s) => s.copyWith(cliInstalled: r.ok));
      if (mounted) {
        showPvSnackBar(
          context,
          r.message,
          duration: const Duration(seconds: 4),
        );
      }
    }
    await _checkInstalled();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = SettingsScope.of(context);
    final s = controller.value;
    final pv = context.pv;
    final windows = _detection?.isWindows ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(40, 8, 40, 40),
        children: [
          const SectionLabel('Appearance'),
          const SizedBox(height: 10),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) =>
                controller.update((c) => c.copyWith(themeMode: v.first)),
          ),
          const SizedBox(height: 28),
          const SectionLabel('Shell'),
          const SizedBox(height: 10),
          ShellChoiceList(
            detection: _detection,
            examples: _examples,
            selected: s.shell,
            onSelect: (v) => controller.update((c) => c.copyWith(shell: v)),
          ),
          const SizedBox(height: 28),
          const SectionLabel('Base folder'),
          const SizedBox(height: 10),
          BaseFolderField(
            controller: _base,
            onChanged: (v) =>
                controller.update((c) => c.copyWith(baseFolder: v.trim())),
            onPicked: (v) {
              _base.text = v;
              controller.update((c) => c.copyWith(baseFolder: v));
            },
          ),
          const SizedBox(height: 12),
          FollowDropsRow(
            value: s.followDrops,
            onChanged: (v) =>
                controller.update((c) => c.copyWith(followDrops: v)),
          ),
          const SizedBox(height: 28),
          const SectionLabel('Command line'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _installed == null
                      ? 'Checking…'
                      : _installed!
                      ? 'path_vador is on your PATH.'
                      : windows
                      ? 'path_vador is not on your user PATH.'
                      : 'The path_vador command is not installed.',
                  style: TextStyle(color: pv.onSurfaceMuted),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _busy || _installed == null ? null : _toggleCli,
                child: Text(
                  (_installed ?? false) ? 'Uninstall' : 'Install command',
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const SectionLabel('Setup'),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                controller.update((c) => c.copyWith(onboarded: false));
                Navigator.of(context).maybePop();
              },
              child: const Text('Run the setup again'),
            ),
          ),
        ],
      ),
    );
  }
}
