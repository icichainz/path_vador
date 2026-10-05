import 'package:flutter/material.dart';

import '../engine/path_engine.dart';
import '../settings/app_settings.dart';
import '../settings/cli_install.dart';
import '../settings/shell_options.dart';
import '../theme/helm_icon.dart';
import '../theme/theme.dart';
import 'onboarding_steps.dart';

/// First-run flow: Welcome, Shell, Base folder, Command line, Ready.
///
/// Every answer is written straight to [SettingsScope]; the last step sets
/// `onboarded`, which swaps the app's home to the inspector.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, this.installer, this.environment});

  /// Installs the CLI on Finish; defaults to a real [CliInstaller].
  final CliInstaller? installer;

  /// Overrides the process environment (for `$SHELL`); for tests.
  final Map<String, String>? environment;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

const _stepLabels = [
  'Welcome',
  'Shell',
  'Base folder',
  'Command line',
  'Ready',
];
const _primaryLabels = [
  'Set up in a minute',
  'Continue',
  'Continue',
  'Finish',
  'Open inspector',
];

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _step = 0;
  bool _installCli = true;
  bool _busy = false;

  PathEngine? _engine;
  ShellDetection? _detection;
  Map<ShellChoice, String> _examples = const {};
  final _baseController = TextEditingController();
  bool _baseSeeded = false;

  /// `README.MD` resolved against the base folder, by the engine.
  String? _preview;
  int _previewSeq = 0;

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
    _baseController.dispose();
    super.dispose();
  }

  Future<void> _detect(PathEngine engine) async {
    try {
      final info = await engine.detect();
      final d = ShellDetection.from(info, environment: widget.environment);
      if (!mounted) return;
      setState(() => _detection = d);
      _seedBase();
      final examples = await loadShellExamples(engine, d);
      if (mounted) setState(() => _examples = examples);
    } catch (_) {
      // Leave the placeholders; the inspector reports engine errors.
    }
  }

  void _seedBase() {
    if (_baseSeeded) return;
    _baseSeeded = true;
    final saved = SettingsScope.of(context).value.baseFolder;
    _baseController.text = saved.isEmpty
        ? (_detection?.info.home ?? '')
        : saved;
    _refreshPreview();
  }

  String get _base {
    final typed = _baseController.text.trim();
    return typed.isEmpty ? (_detection?.info.home ?? '') : typed;
  }

  Future<void> _refreshPreview() async {
    final engine = _engine;
    if (engine == null) return;
    final seq = ++_previewSeq;
    String? abs;
    try {
      abs = (await engine.inspect('README.MD', base: _base)).abs;
    } catch (_) {
      abs = null;
    }
    if (mounted && seq == _previewSeq) setState(() => _preview = abs);
  }

  String get _previewText {
    if (_preview != null) return _preview!;
    final sep = _detection?.info.separator ?? '/';
    final base = _base;
    return base.endsWith(sep) ? '${base}README.MD' : '$base${sep}README.MD';
  }

  SettingsController get _settings => SettingsScope.of(context);

  void _onBaseChanged(String value) {
    _settings.update((s) => s.copyWith(baseFolder: value.trim()));
    _refreshPreview();
  }

  void _onBasePicked(String path) {
    _baseController.text = path;
    _onBaseChanged(path);
  }

  Future<void> _skip() async {
    await _settings.update(
      (s) => const AppSettings().copyWith(
        onboarded: true,
        cliInstalled: s.cliInstalled,
        recents: s.recents,
        themeMode: s.themeMode,
      ),
    );
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _next() async {
    switch (_step) {
      case 3:
        if (_installCli) await _runInstall();
        if (mounted) setState(() => _step = 4);
      case 4:
        await _settings.update((s) => s.copyWith(onboarded: true));
      default:
        setState(() => _step++);
    }
  }

  Future<void> _runInstall() async {
    setState(() => _busy = true);
    final installer = widget.installer ?? CliInstaller();
    final result = await installer.install();
    if (!mounted) return;
    await _settings.update((s) => s.copyWith(cliInstalled: result.ok));
    if (!mounted) return;
    setState(() => _busy = false);
    showPvSnackBar(
      context,
      result.message,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context).value;
    final d = _detection;
    final Widget body = switch (_step) {
      0 => const WelcomeStep(),
      1 => ShellStep(
        detection: d,
        examples: _examples,
        selected: settings.shell,
        onSelect: (c) => _settings.update((s) => s.copyWith(shell: c)),
      ),
      2 => BaseFolderStep(
        controller: _baseController,
        preview: _previewText,
        followDrops: settings.followDrops,
        onChanged: _onBaseChanged,
        onPicked: _onBasePicked,
        onFollowDrops: (v) =>
            _settings.update((s) => s.copyWith(followDrops: v)),
      ),
      3 => CliStep(
        detection: d,
        install: _installCli,
        onInstall: (v) => setState(() => _installCli = v),
        preview: _previewText,
      ),
      _ => ReadyStep(detection: d, settings: settings, base: _base),
    };

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              label: _stepLabels[_step],
              onSkip: _step >= 1 && _step <= 3 ? _skip : null,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(40, 20, 40, 24),
                child: KeyedSubtree(key: ValueKey(_step), child: body),
              ),
            ),
          ],
        ),
      ),
      // As bottomNavigationBar, floating SnackBars stay above the buttons.
      bottomNavigationBar: SafeArea(
        top: false,
        child: _Footer(
          step: _step,
          busy: _busy,
          primaryLabel: _primaryLabels[_step],
          onBack: _step >= 1 && _step <= 3 ? _back : null,
          onNext: _busy ? null : _next,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.label, this.onSkip});

  final String label;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final pv = context.pv;
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: pv.outlineSubtle)),
      ),
      child: Row(
        children: [
          const HelmIcon(size: 24),
          const SizedBox(width: 10),
          Text(
            'PathVador',
            style: pvMono(
              context,
              size: 14,
              weight: FontWeight.w600,
              color: pv.primary,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '· $label',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: pv.onSurfaceSubtle),
            ),
          ),
          const Spacer(),
          if (onSkip != null)
            TextButton(onPressed: onSkip, child: const Text('Skip setup')),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.step,
    required this.busy,
    required this.primaryLabel,
    required this.onNext,
    this.onBack,
  });

  final int step;
  final bool busy;
  final String primaryLabel;
  final VoidCallback? onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final pv = context.pv;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: pv.outlineSubtle)),
      ),
      child: Row(
        children: [
          ProgressDots(count: _stepLabels.length, current: step),
          const Spacer(),
          if (onBack != null) ...[
            OutlinedButton(onPressed: onBack, child: const Text('Back')),
            const SizedBox(width: 12),
          ],
          FilledButton(
            onPressed: onNext,
            child: busy
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: pv.onPrimary,
                    ),
                  )
                : Text(primaryLabel),
          ),
        ],
      ),
    );
  }
}

/// Step indicator: the current step is a 22px pill in primary, finished
/// steps are tertiary dots, upcoming ones outline-coloured dots.
class ProgressDots extends StatelessWidget {
  const ProgressDots({super.key, required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final pv = context.pv;
    return Semantics(
      label: 'Step ${current + 1} of $count',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 6),
              width: i == current ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: i == current
                    ? pv.primary
                    : i < current
                    ? pv.tertiary
                    : pv.outline,
              ),
            ),
        ],
      ),
    );
  }
}
