import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'path_engine.dart';

typedef _EvalNative = Pointer<Utf8> Function(Pointer<Utf8> request);
typedef _FreeNative = Void Function(Pointer<Utf8> p);
typedef _FreeDart = void Function(Pointer<Utf8> p);

/// [PathEngine] backed by the Go `c-shared` library described in ENGINE.md.
///
/// Every operation is one synchronous `pv_eval` call that exchanges JSON.
/// The calls are pure string manipulation inside Go (no I/O besides reading
/// the environment in `detect`) and return in microseconds, so they run on
/// the calling isolate: moving them to a background isolate would cost more
/// (reopening the library, copying messages) than the call itself. The
/// methods stay `async` so the interface can move off-thread later without
/// touching callers.
class FfiPathEngine implements PathEngine {
  /// Binds `pv_eval` and `pv_free` from [library]. Throws an
  /// [ArgumentError] if either symbol is missing.
  FfiPathEngine(DynamicLibrary library)
    : _eval = library.lookupFunction<_EvalNative, _EvalNative>('pv_eval'),
      _free = library.lookupFunction<_FreeNative, _FreeDart>('pv_free');

  final _EvalNative _eval;
  final _FreeDart _free;

  /// Sends one request and returns its `result` object, or throws
  /// [EngineException] with the library's own message when `ok` is false.
  Map<String, Object?> _call(Map<String, Object?> request) {
    final requestPtr = jsonEncode(request).toNativeUtf8(allocator: malloc);
    final String raw;
    try {
      final responsePtr = _eval(requestPtr);
      if (responsePtr == nullptr) {
        throw const EngineException('engine returned no response');
      }
      try {
        raw = responsePtr.toDartString();
      } finally {
        _free(responsePtr);
      }
    } finally {
      malloc.free(requestPtr);
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw EngineException('engine returned invalid JSON: ${e.message}');
    }
    if (decoded is! Map<String, Object?>) {
      throw const EngineException('engine returned a non-object response');
    }
    if (decoded['ok'] != true) {
      throw EngineException(
        decoded['error'] as String? ?? 'engine reported an unknown error',
      );
    }
    final result = decoded['result'];
    if (result is! Map<String, Object?>) {
      throw const EngineException('engine response has no result');
    }
    return result;
  }

  static String _str(Map<String, Object?> m, String key) =>
      m[key] as String? ?? '';

  @override
  Future<EngineInfo> detect() async {
    final r = _call({'op': 'detect'});
    return EngineInfo(
      shell: _str(r, 'shell'),
      goos: _str(r, 'goos'),
      separator: _str(r, 'separator'),
      home: _str(r, 'home'),
    );
  }

  @override
  Future<PathInspection> inspect(String path, {String base = ''}) async {
    final r = _call({'op': 'inspect', 'path': path, 'base': base});
    return PathInspection(
      clean: _str(r, 'clean'),
      abs: _str(r, 'abs'),
      dir: _str(r, 'dir'),
      base: _str(r, 'base'),
      ext: _str(r, 'ext'),
      stem: _str(r, 'stem'),
    );
  }

  @override
  Future<String> join(List<String> parts) async {
    final r = _call({'op': 'join', 'parts': parts});
    return _str(r, 'joined');
  }

  @override
  Future<EnvCommand> env({
    required String shell,
    required String name,
    required String value,
  }) async {
    final r = _call({
      'op': 'env',
      'shell': shell,
      'name': name,
      'value': value,
    });
    return EnvCommand(
      command: _str(r, 'command'),
      shell: _str(r, 'shell'),
      kind: _str(r, 'kind'),
    );
  }
}
