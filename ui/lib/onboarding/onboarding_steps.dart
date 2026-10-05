import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../settings/app_settings.dart';
import '../settings/shell_options.dart';
import '../theme/helm_icon.dart';
import '../theme/pv_widgets.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';

/// Title + body shared by steps 2–5.
class _StepIntro extends StatelessWidget {
  const _StepIntro({required this.title, this.body});

  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.headlineSmall),
        if (body != null) ...[
          const SizedBox(height: 10),
          Text(
            body!,
            style: text.bodyLarge?.copyWith(color: context.pv.onSurfaceMuted),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

// --- 1. Welcome --------------------------------------------------------

/// Step 1: the icon, the pitch and the three ways in.
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pv = context.pv;
    return Column(
      children: [
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: const HelmIcon(size: 128),
        ),
        const SizedBox(height: 28),
        Text(
          'Welcome to PathVador',
          style: text.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(
            'Drop a path, get every form of it. Turn any value into a shell '
            'command. One tool, three ways in.',
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(color: pv.onSurfaceMuted),
          ),
        ),
        const SizedBox(height: 32),
        const IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _WayCard(
                  label: 'Window',
                  text: 'This app. Drag, drop, click to copy.',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _WayCard(
                  label: 'Terminal',
                  code: 'path_vador',
                  text: 'opens the TUI',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _WayCard(
                  label: 'Scripts',
                  code: 'path_vador abs …',
                  text: 'prints one line',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WayCard extends StatelessWidget {
  const _WayCard({required this.label, required this.text, this.code});

  final String label;
  final String? code;
  final String text;

  @override
  Widget build(BuildContext context) {
    final pv = context.pv;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pv.surfaceContainer,
        borderRadius: BorderRadius.circular(PvRadius.card),
        border: Border.all(color: pv.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label),
          const SizedBox(height: 10),
          if (code != null) ...[
            Text(code!, style: pvMono(context, size: 13)),
            const SizedBox(height: 4),
          ],
          Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: pv.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}

// --- 2. Shell ----------------------------------------------------------

/// Step 2: which shell the env commands target.
class ShellStep extends StatelessWidget {
  const ShellStep({
    super.key,
    required this.detection,
    required this.examples,
    required this.selected,
    required this.onSelect,
  });

  final ShellDetection? detection;
  final Map<ShellChoice, String> examples;
  final ShellChoice selected;
  final ValueChanged<ShellChoice> onSelect;

  @override
  Widget build(BuildContext context) {
    final d = detection;
    final found = d == null ? r'We read $SHELL and found …' : d.foundSentence;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepIntro(
          title: 'Which shell do you use?',
          body:
              'This only shapes the env commands PathVador writes for you. '
              '$found',
        ),
        ShellChoiceList(
          detection: d,
          examples: examples,
          selected: selected,
          onSelect: onSelect,
        ),
      ],
    );
  }
}

/// The four shell rows; shared with the Settings page.
class ShellChoiceList extends StatelessWidget {
  const ShellChoiceList({
    super.key,
    required this.detection,
    required this.examples,
    required this.selected,
    required this.onSelect,
  });

  final ShellDetection? detection;
  final Map<ShellChoice, String> examples;
  final ShellChoice selected;
  final ValueChanged<ShellChoice> onSelect;

  @override
  Widget build(BuildContext context) {
    final d = detection;
    final value = d?.exampleValue ?? '/home/you/dev';
    return Column(
      children: [
        for (final c in ShellChoice.values) ...[
          ChoiceRow(
            title: shellTitle(c, d),
            example: examples[c] ?? fallbackExample(c, value),
            selected: c == selected,
            onTap: () => onSelect(c),
            trailing: c == ShellChoice.auto && d != null
                ? PvBadge(d.assumed ? 'Assumed' : 'Detected')
                : null,
          ),
          if (c != ShellChoice.values.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

// --- 3. Base folder ----------------------------------------------------

/// Step 3: the folder relative paths resolve against.
class BaseFolderStep extends StatelessWidget {
  const BaseFolderStep({
    super.key,
    required this.controller,
    required this.preview,
    required this.followDrops,
    required this.onChanged,
    required this.onPicked,
    required this.onFollowDrops,
  });

  final TextEditingController controller;
  final String preview;
  final bool followDrops;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onPicked;
  final ValueChanged<bool> onFollowDrops;

  @override
  Widget build(BuildContext context) {
    final pv = context.pv;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepIntro(
          title: 'Where do relative paths start?',
          body:
              "A terminal has a working directory; a window doesn't. Pick the "
              'folder README.MD should resolve against.',
        ),
        BaseFolderField(
          controller: controller,
          onChanged: onChanged,
          onPicked: onPicked,
        ),
        const SizedBox(height: 16),
        FollowDropsRow(value: followDrops, onChanged: onFollowDrops),
        const SizedBox(height: 16),
        DashedBorder(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Preview'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'README.MD',
                      style: pvMono(context, color: pv.onSurfaceMuted),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '→',
                        style: TextStyle(color: pv.onSurfaceSubtle),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        preview,
                        key: const ValueKey('base-preview'),
                        overflow: TextOverflow.ellipsis,
                        style: pvMono(context, weight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Mono text field + "Choose…" folder picker; shared with Settings.
class BaseFolderField extends StatelessWidget {
  const BaseFolderField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onPicked,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onPicked;

  Future<void> _choose() async {
    try {
      final picked = await FilePicker.getDirectoryPath(
        dialogTitle: 'Base folder',
        initialDirectory: controller.text.isEmpty ? null : controller.text,
      );
      if (picked != null) onPicked(picked);
    } catch (_) {
      // Picker unavailable (e.g. sandbox); the field still works.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: pvMono(context, size: 14),
            decoration: const InputDecoration(hintText: 'Base folder'),
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton(onPressed: _choose, child: const Text('Choose…')),
      ],
    );
  }
}

/// "Follow dropped files" switch row; shared with Settings.
class FollowDropsRow extends StatelessWidget {
  const FollowDropsRow({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final pv = context.pv;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: pv.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pv.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Follow dropped files',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'When you drop a file, its folder becomes the base until '
                  'you change it.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: pv.onSurfaceMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// --- 4. Command line ---------------------------------------------------

/// Step 4: offer to put the CLI on PATH.
class CliStep extends StatelessWidget {
  const CliStep({
    super.key,
    required this.detection,
    required this.install,
    required this.onInstall,
    required this.preview,
  });

  final ShellDetection? detection;
  final bool install;
  final ValueChanged<bool> onInstall;

  /// `README.MD` resolved against the base folder.
  final String preview;

  @override
  Widget build(BuildContext context) {
    final pv = context.pv;
    final windows = detection?.isWindows ?? false;
    final linux = detection?.info.goos == 'linux';
    final title = windows
        ? 'Add path_vador to your user PATH'
        : 'Install the path_vador command';
    final sub = windows
        ? r'Writes one entry to HKCU\Environment\Path. No admin prompt. New '
              'terminals pick it up; open ones need a restart.'
        : linux
        ? 'Adds a link in /usr/local/bin, or ~/.local/bin if that is not '
              'writable. Remove it any time from Settings.'
        : 'Adds a link in /usr/local/bin. macOS will ask for your password '
              'once. Remove it any time from Settings.';

    final lines = windows
        ? [
            const TerminalLine.comment('# then, in any terminal'),
            const TerminalLine.command(
              'path_vador abs README.MD',
              prompt: 'PS>',
            ),
            TerminalLine.output(preview),
            const TerminalLine.command(
              r'Invoke-Expression (path_vador env export PROJECT_ROOT $PWD)',
              prompt: 'PS>',
            ),
            const TerminalLine.command(
              'path_vador   # no arguments opens the TUI',
              prompt: 'PS>',
            ),
          ]
        : [
            const TerminalLine.comment('# then, in any terminal'),
            const TerminalLine.command('path_vador abs README.MD'),
            TerminalLine.output(preview),
            const TerminalLine.command(
              r'eval "$(path_vador env export PROJECT_ROOT "$PWD")"',
            ),
            const TerminalLine.command(
              'path_vador   # no arguments opens the TUI',
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepIntro(
          title: 'Use it from the terminal too?',
          body:
              'The same binary runs the window, the TUI and the CLI. Putting '
              'it on your PATH makes all three one command away.',
        ),
        Material(
          color: install ? pv.surfaceContainerHigh : pv.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: install ? pv.primary : pv.outline,
              width: install ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onInstall(!install),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: install,
                    onChanged: (v) => onInstall(v ?? false),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sub,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: pv.onSurfaceMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TerminalBlock(lines: lines),
      ],
    );
  }
}

// --- 5. Ready ----------------------------------------------------------

/// Step 5: summary, a (visual) drop zone and the shortcuts.
class ReadyStep extends StatelessWidget {
  const ReadyStep({
    super.key,
    required this.detection,
    required this.settings,
    required this.base,
  });

  final ShellDetection? detection;
  final AppSettings settings;
  final String base;

  @override
  Widget build(BuildContext context) {
    final pv = context.pv;
    final text = Theme.of(context).textTheme;
    final mod = detection?.mod ?? '⌘';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepIntro(title: 'Ready.'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Chip(
              child: Text(
                'Shell · ${shellSummary(settings.shell, detection)}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            _Chip(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: base, style: pvMono(context, size: 12.5)),
                    if (settings.followDrops)
                      TextSpan(
                        text: ' · follows drops',
                        style: TextStyle(
                          fontSize: 13,
                          color: pv.onSurfaceMuted,
                        ),
                      ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _Chip(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: settings.cliInstalled
                          ? pv.tertiary
                          : pv.onSurfaceSubtle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    settings.cliInstalled
                        ? 'CLI installed'
                        : 'CLI not installed',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        DashedBorder(
          color: pv.outline,
          radius: PvRadius.panel,
          dash: 8,
          gap: 5,
          strokeWidth: 1.5,
          child: SizedBox(
            width: double.infinity,
            height: 150,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.file_download_outlined,
                  size: 28,
                  color: pv.onSurfaceSubtle,
                ),
                const SizedBox(height: 10),
                Text('Drop a file here to inspect it', style: text.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'or paste a path with ${mod}V',
                  style: text.bodySmall?.copyWith(color: pv.onSurfaceMuted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _Shortcut(label: 'Copy a value', keys: 'click · ${mod}C'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Shortcut(
                label: 'Path · Join · Env',
                keys: '${mod}1 ${mod}2 ${mod}3',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _Shortcut(label: 'Send value to Env', keys: '${mod}E'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Shortcut(label: 'Change these answers', keys: '$mod,'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pv = context.pv;
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: pv.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: pv.outline),
      ),
      child: child,
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.label, required this.keys});

  final String label;
  final String keys;

  @override
  Widget build(BuildContext context) {
    final pv = context.pv;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: pv.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pv.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(keys, style: pvMono(context, size: 12.5, color: pv.primary)),
        ],
      ),
    );
  }
}
