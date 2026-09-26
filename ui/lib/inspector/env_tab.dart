import 'package:flutter/material.dart';

import '../settings/app_settings.dart';
import '../theme/tokens.dart';
import 'inspector_controller.dart';
import 'widgets.dart';

/// Human name of an engine shell id (`sh` | `powershell` | `cmd`).
String shellDisplayName(String shell) => switch (shell) {
  'powershell' => 'PowerShell',
  'cmd' => 'cmd',
  _ => 'sh',
};

/// Env tab: variable name and value in, a paste-ready shell command out.
class EnvTab extends StatelessWidget {
  /// Creates the tab.
  const EnvTab({super.key, required this.controller});

  final InspectorController controller;

  void _setShell(SettingsController settings, ShellChoice shell) {
    controller.shell = shell;
    settings.update((s) => s.copyWith(shell: shell));
  }

  @override
  Widget build(BuildContext context) {
    final c = ipColors(context);
    final settings = SettingsScope.of(context);
    final detected = controller.info?.shell;
    TextStyle label() => TextStyle(
      color: c.onSurfaceMuted,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(PvSpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Variable', style: label()),
          const SizedBox(height: PvSpace.sm),
          TextField(
            key: const Key('env-name-field'),
            controller: controller.envNameField,
            style: ipMono(context),
            decoration: ipFieldDecoration(context, hint: 'PROJECT_ROOT'),
          ),
          const SizedBox(height: PvSpace.lg),
          Text('Value · leave empty to unset', style: label()),
          const SizedBox(height: PvSpace.sm),
          TextField(
            key: const Key('env-value-field'),
            controller: controller.envValueField,
            style: ipMono(context),
            decoration: ipFieldDecoration(context, hint: ''),
          ),
          const SizedBox(height: PvSpace.lg),
          Text('Shell', style: label()),
          const SizedBox(height: PvSpace.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedPills<ShellChoice>(
                selected: controller.shell,
                onChanged: (s) => _setShell(settings, s),
                segments: [
                  PillSegment(
                    ShellChoice.auto,
                    detected == null
                        ? 'Auto'
                        : 'Auto · ${shellDisplayName(detected)}',
                  ),
                  const PillSegment(ShellChoice.sh, 'sh'),
                  const PillSegment(ShellChoice.powershell, 'PowerShell'),
                  const PillSegment(ShellChoice.cmd, 'cmd'),
                ],
              ),
            ),
          ),
          const SizedBox(height: PvSpace.xxl),
          _result(context, settings),
        ],
      ),
    );
  }

  Widget _result(BuildContext context, SettingsController settings) {
    final c = ipColors(context);
    final error = controller.envError;
    if (error != null) {
      return ErrorBox(
        message: error,
        action: error.contains('cmd')
            ? Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.error,
                    foregroundColor: c.errorContainer,
                    minimumSize: const Size(0, pvTouchTarget),
                  ),
                  onPressed: () => _setShell(settings, ShellChoice.powershell),
                  child: const Text('Use PowerShell'),
                ),
              )
            : null,
      );
    }
    final cmd = controller.envCommand;
    if (controller.envNameField.text.isEmpty || cmd == null) {
      return const EmptyHint(
        title: 'Name a variable to see the command.',
        subtitle:
            'Any value in the Path tab can be sent here '
            'with its → button.',
      );
    }
    return OutlinedCard(
      padding: const EdgeInsets.all(PvSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionLabel(
                  cmd.kind == 'unset' ? 'UNSET COMMAND' : 'EXPORT COMMAND',
                  color: c.tertiary,
                ),
              ),
              CopyButton(value: cmd.command, filled: true),
            ],
          ),
          const SizedBox(height: PvSpace.md),
          TerminalBlock(text: cmd.command),
          const SizedBox(height: PvSpace.md),
          Text(
            'Paste into ${shellDisplayName(cmd.shell)}. A window can\'t reach '
            'into your terminal\'s environment, so you get the command '
            'instead.',
            style: TextStyle(color: c.onSurfaceSubtle, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
