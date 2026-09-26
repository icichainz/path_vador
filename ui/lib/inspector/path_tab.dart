import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../settings/app_settings.dart';
import '../theme/tokens.dart';
import 'inspector_controller.dart';
import 'widgets.dart';

/// Adds [path] to the recents in settings (drops, picker choices, Enter).
void rememberPath(SettingsController settings, String path) {
  if (path.trim().isEmpty) return;
  settings.update((s) => s.withRecent(path));
}

/// Shows [path] with the home prefix as `~`, for captions only.
String tildePath(String path, String home) {
  if (home.isEmpty || path.isEmpty) return path;
  if (path == home) return '~';
  for (final sep in const ['/', r'\']) {
    if (path.startsWith('$home$sep')) return '~${path.substring(home.length)}';
  }
  return path;
}

/// Path tab: one input, every derived form of it, and the recents.
class PathTab extends StatelessWidget {
  /// Creates the tab.
  const PathTab({super.key, required this.controller});

  final InspectorController controller;

  Future<void> _pickFile(SettingsController settings) async {
    final files = await FilePicker.pickFiles(dialogTitle: 'Inspect a file');
    final path = files.isEmpty ? null : files.first.path;
    if (path == null) return;
    controller.loadPath(path);
    rememberPath(settings, path);
  }

  Future<void> _pickFolder(SettingsController settings) async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Inspect a folder',
    );
    if (path == null) return;
    controller.loadPath(path);
    rememberPath(settings, path);
  }

  Future<void> _changeBase(SettingsController settings) async {
    final path = await FilePicker.getDirectoryPath(
      dialogTitle: 'Resolve relative paths against',
      initialDirectory: controller.effectiveBase.isEmpty
          ? null
          : controller.effectiveBase,
    );
    if (path == null) return;
    await settings.update((s) => s.copyWith(baseFolder: path));
  }

  @override
  Widget build(BuildContext context) {
    final c = ipColors(context);
    final settings = SettingsScope.of(context);
    final home = controller.info?.home ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(PvSpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 52,
            child: TextField(
              key: const Key('path-field'),
              controller: controller.pathField,
              style: ipMono(context, size: 15),
              textAlignVertical: TextAlignVertical.center,
              onSubmitted: (v) => rememberPath(settings, v),
              decoration: ipFieldDecoration(
                context,
                hint: 'Type or drop a path',
                height: 52,
                suffix: PopupMenuButton<bool>(
                  tooltip: 'Choose a file or folder',
                  icon: Icon(
                    Icons.folder_open_outlined,
                    color: c.onSurfaceMuted,
                  ),
                  onSelected: (folder) =>
                      folder ? _pickFolder(settings) : _pickFile(settings),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: false, child: Text('Choose file…')),
                    PopupMenuItem(value: true, child: Text('Choose folder…')),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: PvSpace.sm),
          Row(
            children: [
              Flexible(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Relative paths resolve against ',
                      style: TextStyle(color: c.onSurfaceSubtle, fontSize: 12),
                    ),
                    Text(
                      tildePath(controller.effectiveBase, home),
                      style: ipMono(context, size: 12, color: c.onSurfaceMuted),
                    ),
                    Text(
                      ' · ',
                      style: TextStyle(color: c.onSurfaceSubtle, fontSize: 12),
                    ),
                    InkWell(
                      onTap: () => _changeBase(settings),
                      child: Text(
                        'change',
                        style: TextStyle(
                          color: c.tertiary,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                          decorationColor: c.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: PvSpace.md),
              Text(
                'or drop a file anywhere here',
                style: TextStyle(color: c.onSurfaceSubtle, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: PvSpace.xl),
          _results(context),
          if (settings.value.recents.isNotEmpty) ...[
            const SizedBox(height: PvSpace.xxl),
            const SectionLabel('RECENT'),
            const SizedBox(height: PvSpace.sm),
            Wrap(
              spacing: PvSpace.sm,
              runSpacing: PvSpace.sm,
              children: [
                for (final r in settings.value.recents)
                  _RecentChip(path: r, onTap: () => controller.loadPath(r)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _results(BuildContext context) {
    if (controller.path.isEmpty) {
      return const EmptyHint(
        title: 'Drop a file or folder, or type a path above.',
        subtitle:
            'Every derived value appears at once, '
            'each one a click from the clipboard.',
      );
    }
    final error = controller.pathError;
    if (error != null) return ErrorBox(message: error);
    final i = controller.inspection;
    if (i == null) return const SizedBox(height: 52);
    final rows = [
      ('Cleaned', i.clean),
      ('Absolute', i.abs),
      ('Directory', i.dir),
      ('Base name', i.base),
      ('Extension', i.ext),
      ('Stem', i.stem),
    ];
    final c = ipColors(context);
    return OutlinedCard(
      child: Column(
        children: [
          for (var n = 0; n < rows.length; n++) ...[
            if (n > 0) Divider(height: 1, thickness: 1, color: c.outlineSubtle),
            ResultRow(
              label: rows[n].$1,
              value: rows[n].$2,
              onFocused: () => controller.focusValue(rows[n].$2),
              onSendToEnv: () => controller.sendToEnv(rows[n].$2),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({required this.path, required this.onTap});

  final String path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = ipColors(context);
    return Tooltip(
      message: path,
      waitDuration: const Duration(milliseconds: 600),
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: c.outline),
          borderRadius: BorderRadius.circular(PvRadius.control),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280, minHeight: 32),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PvSpace.md,
                vertical: 7,
              ),
              child: Text(
                path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ipMono(context, size: 12, color: c.onSurfaceMuted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
