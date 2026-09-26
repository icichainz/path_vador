import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/path_engine.dart';
import '../settings/app_settings.dart';
import '../theme/tokens.dart';
import 'env_tab.dart';
import 'inspector_controller.dart';
import 'join_tab.dart';
import 'path_tab.dart';
import 'widgets.dart';

/// The main window after onboarding: Path · Join · Env tabs, a CLI echo
/// footer, and a window-wide drop target.
///
/// Needs an [EngineScope] and a [SettingsScope] above it.
class InspectorScreen extends StatefulWidget {
  /// Creates the screen. [onOpenSettings] runs on ⌘, (Ctrl+, elsewhere);
  /// when null the shortcut does nothing.
  const InspectorScreen({super.key, this.onOpenSettings});

  final VoidCallback? onOpenSettings;

  @override
  State<InspectorScreen> createState() => _InspectorScreenState();
}

class _InspectorScreenState extends State<InspectorScreen> {
  InspectorController? _controller;
  PathEngine? _engine;
  bool _dragging = false;
  String? _dragName;

  InspectorController get controller => _controller!;

  bool get _isMac => defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final engine = EngineScope.of(context);
    final settings = SettingsScope.of(context).value;
    if (_controller == null || engine != _engine) {
      _controller?.dispose();
      _engine = engine;
      _controller = InspectorController(
        engine,
        shell: settings.shell,
        base: settings.baseFolder,
      )..start();
    } else {
      controller.syncSettings(base: settings.baseFolder, shell: settings.shell);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onDrop(DropDoneDetails details) async {
    final asFragment = HardwareKeyboard.instance.isAltPressed;
    setState(() {
      _dragging = false;
      _dragName = null;
    });
    final paths = details.files.map((f) => f.path).where((p) => p.isNotEmpty);
    if (paths.isEmpty) return;
    await handleDrop(paths.first, asFragment: asFragment);
  }

  /// Applies a dropped [path]: a Join fragment when [asFragment], else the
  /// Path tab (plus recents and, with followDrops, the base folder).
  Future<void> handleDrop(String path, {required bool asFragment}) async {
    final settings = SettingsScope.of(context);
    if (asFragment) {
      controller.addFragments(path, split: false);
      controller.tab = InspectorTab.join;
      return;
    }
    controller.loadPath(path);
    rememberPath(settings, path);
    if (settings.value.followDrops) {
      try {
        // The engine decides what the parent folder is.
        final parent = (await controller.engine.inspect(path)).dir;
        if (parent.isNotEmpty && parent != '.') {
          await settings.update((s) => s.copyWith(baseFolder: parent));
        }
      } on EngineException {
        // The Path tab already shows the error.
      }
    }
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts() {
    SingleActivator key(LogicalKeyboardKey k) =>
        SingleActivator(k, meta: _isMac, control: !_isMac);
    return {
      key(LogicalKeyboardKey.digit1): () => controller.tab = InspectorTab.path,
      key(LogicalKeyboardKey.digit2): () => controller.tab = InspectorTab.join,
      key(LogicalKeyboardKey.digit3): () => controller.tab = InspectorTab.env,
      key(LogicalKeyboardKey.keyE): controller.sendFocusedToEnv,
      key(LogicalKeyboardKey.comma): () => widget.onOpenSettings?.call(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = ipColors(context);
    return CallbackShortcuts(
      bindings: _shortcuts(),
      // Each tab autofocuses its first field; the shortcuts above still
      // see every key event that bubbles up from it.
      child: Focus(
        child: Scaffold(
          backgroundColor: c.surface,
          body: DropTarget(
            onDragEntered: (_) => setState(() => _dragging = true),
            onDragExited: (_) => setState(() {
              _dragging = false;
              _dragName = null;
            }),
            onDragDone: _onDrop,
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => Stack(
                children: [
                  Column(
                    children: [
                      _Header(controller: controller),
                      Divider(height: 1, thickness: 1, color: c.outlineSubtle),
                      Expanded(child: _body()),
                      _CliEcho(line: controller.cliEcho),
                    ],
                  ),
                  if (_dragging)
                    Positioned.fill(
                      child: _DropOverlay(
                        fileName: _dragName,
                        modifier: _isMac ? '⌥' : 'Alt',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() => switch (controller.tab) {
    InspectorTab.path => PathTab(controller: controller),
    InspectorTab.join => JoinTab(controller: controller),
    InspectorTab.env => EnvTab(controller: controller),
  };
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final InspectorController controller;

  @override
  Widget build(BuildContext context) {
    final c = ipColors(context);
    final info = controller.info;
    final status = info != null
        ? '${info.shell} · ${info.goos}'
        : (controller.detectError ?? '…');
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PvSpace.xxl,
        vertical: PvSpace.md,
      ),
      child: Row(
        children: [
          Text(
            'path_vador',
            style: ipMono(
              context,
              size: 15,
              color: c.primary,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: PvSpace.lg),
          SegmentedPills<InspectorTab>(
            selected: controller.tab,
            onChanged: (t) => controller.tab = t,
            segments: const [
              PillSegment(InspectorTab.path, 'Path'),
              PillSegment(InspectorTab.join, 'Join'),
              PillSegment(InspectorTab.env, 'Env'),
            ],
          ),
          const SizedBox(width: PvSpace.md),
          const Spacer(),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: info != null ? c.tertiary : c.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: PvSpace.sm),
          Flexible(
            flex: 0,
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ipMono(context, size: 12, color: c.onSurfaceMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _CliEcho extends StatelessWidget {
  const _CliEcho({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final c = ipColors(context);
    return Container(
      height: pvTouchTarget + 4,
      padding: const EdgeInsets.only(left: PvSpace.xxl, right: PvSpace.md),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        border: Border(top: BorderSide(color: c.outlineSubtle)),
      ),
      child: Row(
        children: [
          Icon(Icons.terminal, size: 14, color: c.onSurfaceSubtle),
          const SizedBox(width: PvSpace.sm),
          Expanded(
            child: Text(
              line,
              key: const Key('cli-echo'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ipMono(context, size: 12, color: c.onSurfaceMuted),
            ),
          ),
          TextButton(
            onPressed: () => copyToClipboard(
              context,
              line.startsWith(r'$ ') ? line.substring(2) : line,
            ),
            style: TextButton.styleFrom(
              foregroundColor: c.onSurfaceMuted,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('copy'),
          ),
        ],
      ),
    );
  }
}

class _DropOverlay extends StatelessWidget {
  const _DropOverlay({required this.fileName, required this.modifier});

  final String? fileName;
  final String modifier;

  @override
  Widget build(BuildContext context) {
    final c = ipColors(context);
    return IgnorePointer(
      child: ColoredBox(
        color: c.surface.withValues(alpha: 0.72),
        child: Padding(
          padding: const EdgeInsets.all(PvSpace.md),
          child: DashedBox(
            color: c.tertiary,
            strokeWidth: 2,
            radius: 18,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.upload_rounded, size: 40, color: c.tertiary),
                  const SizedBox(height: PvSpace.md),
                  Text(
                    'Drop to inspect',
                    style: TextStyle(
                      color: c.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: PvSpace.md),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 360),
                    padding: const EdgeInsets.symmetric(
                      horizontal: PvSpace.md,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: c.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(PvRadius.control),
                    ),
                    child: Text(
                      // The drag events carry no file names before the drop.
                      fileName ?? 'file or folder',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ipMono(context, size: 13),
                    ),
                  ),
                  const SizedBox(height: PvSpace.md),
                  Text(
                    'Hold $modifier to add it as a Join fragment instead',
                    style: TextStyle(color: c.onSurfaceSubtle, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
