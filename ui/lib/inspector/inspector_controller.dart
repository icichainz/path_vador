import 'dart:async';

import 'package:flutter/widgets.dart';

import '../engine/path_engine.dart';
import '../settings/app_settings.dart';

/// The three inspector tabs, in header order.
enum InspectorTab { path, join, env }

/// Shared state of the inspector window, so the tabs, drops and keyboard
/// shortcuts can move values between tabs.
///
/// Owns the text controllers of the fields other tabs write into (the path,
/// the env name and value). Engine calls are cancellable: each kind of call
/// carries a sequence number and a result is dropped if a newer request was
/// made meanwhile.
class InspectorController extends ChangeNotifier {
  /// Creates the controller; call [start] once to run `detect`.
  InspectorController(
    this.engine, {
    ShellChoice shell = ShellChoice.auto,
    String base = '',
    this.debounce = const Duration(milliseconds: 60),
  }) : _shell = shell,
       _base = base {
    pathField.addListener(_onPathText);
    envNameField.addListener(_onEnvText);
    envValueField.addListener(_onEnvText);
  }

  /// The engine every derived value comes from.
  final PathEngine engine;

  /// Delay between the last keystroke in the path field and `inspect`.
  final Duration debounce;

  /// The path field of the Path tab.
  final pathField = TextEditingController();

  /// The "next fragment" field of the Join tab.
  final fragmentField = TextEditingController();

  /// The variable name field of the Env tab.
  final envNameField = TextEditingController();

  /// The value field of the Env tab.
  final envValueField = TextEditingController();

  /// Result of `detect`, null until it arrives or if it failed.
  EngineInfo? info;

  /// Error from `detect`, if any.
  String? detectError;

  InspectorTab _tab = InspectorTab.path;
  String _base;
  String _lastPath = '';

  /// Latest inspection of [path]; null when the path is empty or failed.
  PathInspection? inspection;

  /// Engine error for the current [path], shown instead of the rows.
  String? pathError;

  final List<String> _fragments = [];

  /// Result of joining [fragments]; null when there are none.
  String? joined;

  /// Engine error from `join`.
  String? joinError;

  ShellChoice _shell;
  String _lastEnvName = '';
  String _lastEnvValue = '';

  /// Latest env command; null when the name is empty or failed.
  EnvCommand? envCommand;

  /// Engine error from `env`, shown verbatim.
  String? envError;

  /// The result value that last had focus; what ⌘E sends to Env.
  String? focusedValue;

  int _pathSeq = 0;
  int _joinSeq = 0;
  int _envSeq = 0;
  Timer? _timer;
  bool _disposed = false;

  /// The selected tab.
  InspectorTab get tab => _tab;
  set tab(InspectorTab value) {
    if (value == _tab) return;
    _tab = value;
    focusedValue = null;
    _notify();
  }

  /// The path currently in the Path tab.
  String get path => pathField.text;

  /// Path separator reported by the engine (`/` until `detect` answers).
  String get separator => info?.separator ?? '/';

  /// Folder relative paths resolve against, as stored in settings; empty
  /// means the user's home.
  String get base => _base;

  /// [base] with the "empty means home" rule applied.
  String get effectiveBase => _base.isNotEmpty ? _base : (info?.home ?? '');

  /// Fragments of the Join tab, in order.
  List<String> get fragments => List.unmodifiable(_fragments);

  /// The shell choice of the Env tab.
  ShellChoice get shell => _shell;
  set shell(ShellChoice value) {
    if (value == _shell) return;
    _shell = value;
    _notify();
    _runEnv();
  }

  /// Runs `detect`, then refreshes every derived value.
  Future<void> start() async {
    try {
      info = await engine.detect();
      detectError = null;
    } on EngineException catch (e) {
      detectError = e.message;
    }
    if (_disposed) return;
    _notify();
    _schedulePath(immediate: true);
    _runJoin();
    _runEnv();
  }

  /// Brings the controller in line with settings changed elsewhere. Safe to
  /// call during build: it never notifies synchronously.
  void syncSettings({required String base, required ShellChoice shell}) {
    if (base != _base) {
      _base = base;
      scheduleMicrotask(() => _schedulePath());
    }
    if (shell != _shell) {
      _shell = shell;
      scheduleMicrotask(_runEnv);
    }
  }

  /// Puts [value] in the path field, inspects it without debounce and shows
  /// the Path tab.
  void loadPath(String value) {
    pathField.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _schedulePath(immediate: true);
    tab = InspectorTab.path;
  }

  /// Adds [raw] to the fragments. With [split], a value containing path
  /// separators becomes several fragments (a leading separator is kept as a
  /// root fragment).
  void addFragments(String raw, {bool split = true}) {
    final parts = split ? splitFragments(raw) : [if (raw.isNotEmpty) raw];
    if (parts.isEmpty) return;
    _fragments.addAll(parts);
    _notify();
    _runJoin();
  }

  /// Tokenises a pasted path for the Join tab. UI-only: it decides where
  /// chips break, the engine still does the joining.
  List<String> splitFragments(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return const [];
    final seps = {separator, if (separator == r'\') '/'};
    final pattern = RegExp(seps.map(RegExp.escape).join('|'));
    final pieces = value.split(pattern);
    final out = <String>[];
    for (var i = 0; i < pieces.length; i++) {
      final piece = pieces[i];
      if (i == 0 && piece.isEmpty && pieces.length > 1) {
        out.add(separator); // rooted path
      } else if (i == 0 && piece.length == 2 && piece.endsWith(':')) {
        out.add('$piece$separator'); // drive root
      } else if (piece.isNotEmpty) {
        out.add(piece);
      }
    }
    return out;
  }

  /// Removes the fragment at [index].
  void removeFragment(int index) {
    if (index < 0 || index >= _fragments.length) return;
    _fragments.removeAt(index);
    _notify();
    _runJoin();
  }

  /// Puts [value] in the Env value field and shows the Env tab.
  void sendToEnv(String value) {
    envValueField.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    tab = InspectorTab.env;
  }

  /// ⌘E: sends the focused result, or the first one of the current tab.
  void sendFocusedToEnv() {
    final value =
        focusedValue ??
        switch (_tab) {
          InspectorTab.path => inspection?.clean,
          InspectorTab.join => joined,
          InspectorTab.env => null,
        };
    if (value == null || value.isEmpty) return;
    sendToEnv(value);
  }

  /// The value a result row reports when it gains focus.
  void focusValue(String? value) => focusedValue = value;

  /// What the current tab would be as a `path_vador` command line.
  String get cliEcho {
    final args = <String>[];
    switch (_tab) {
      case InspectorTab.path:
        if (path.isNotEmpty) args.addAll(['abs', path]);
      case InspectorTab.join:
        if (_fragments.isNotEmpty) args.addAll(['join', ..._fragments]);
      case InspectorTab.env:
        final name = envNameField.text;
        if (name.isNotEmpty) {
          final value = envValueField.text;
          args.addAll(['env', value.isEmpty ? 'unset' : 'export']);
          if (_shell != ShellChoice.auto) args.addAll(['--shell', _shell.name]);
          args.add(name);
          if (value.isNotEmpty) args.add(value);
        }
    }
    return ['\$ path_vador', ...args.map(shellQuoteArg)].join(' ');
  }

  void _onPathText() {
    if (pathField.text == _lastPath) return;
    _lastPath = pathField.text;
    _schedulePath();
    _notify();
  }

  void _onEnvText() {
    final name = envNameField.text;
    final value = envValueField.text;
    if (name == _lastEnvName && value == _lastEnvValue) return;
    _lastEnvName = name;
    _lastEnvValue = value;
    _runEnv();
  }

  void _schedulePath({bool immediate = false}) {
    if (_disposed) return;
    _timer?.cancel();
    final seq = ++_pathSeq;
    if (path.isEmpty) {
      inspection = null;
      pathError = null;
      _notify();
      return;
    }
    if (immediate) {
      _runInspect(seq);
    } else {
      _timer = Timer(debounce, () => _runInspect(seq));
    }
  }

  Future<void> _runInspect(int seq) async {
    final requested = path;
    try {
      final r = await engine.inspect(requested, base: effectiveBase);
      if (seq != _pathSeq || _disposed) return;
      inspection = r;
      pathError = null;
    } on EngineException catch (e) {
      if (seq != _pathSeq || _disposed) return;
      inspection = null;
      pathError = e.message;
    }
    _notify();
  }

  Future<void> _runJoin() async {
    final seq = ++_joinSeq;
    if (_fragments.isEmpty) {
      joined = null;
      joinError = null;
      _notify();
      return;
    }
    try {
      final r = await engine.join(List.of(_fragments));
      if (seq != _joinSeq || _disposed) return;
      joined = r;
      joinError = null;
    } on EngineException catch (e) {
      if (seq != _joinSeq || _disposed) return;
      joined = null;
      joinError = e.message;
    }
    _notify();
  }

  Future<void> _runEnv() async {
    final seq = ++_envSeq;
    final name = envNameField.text;
    if (name.isEmpty) {
      envCommand = null;
      envError = null;
      _notify();
      return;
    }
    try {
      final r = await engine.env(
        shell: _shell.name,
        name: name,
        value: envValueField.text,
      );
      if (seq != _envSeq || _disposed) return;
      envCommand = r;
      envError = null;
    } on EngineException catch (e) {
      if (seq != _envSeq || _disposed) return;
      envCommand = null;
      envError = e.message;
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    pathField.dispose();
    fragmentField.dispose();
    envNameField.dispose();
    envValueField.dispose();
    super.dispose();
  }
}

final _safeArg = RegExp(r'^[A-Za-z0-9_/.\-:=~]+$');

/// Quotes [arg] for the CLI echo line: single quotes when it contains
/// anything outside `[A-Za-z0-9_/.\-:=~]`.
String shellQuoteArg(String arg) {
  if (_safeArg.hasMatch(arg)) return arg;
  return "'${arg.replaceAll("'", "'\"'\"'")}'";
}
