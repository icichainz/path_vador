import 'path_engine.dart';

/// Loads the production engine. STUB: replaced by the FFI implementation;
/// until then it throws so nobody ships the app without the Go library.
Future<PathEngine> loadPathEngine() async {
  throw UnimplementedError('FFI engine not wired yet; see ENGINE.md');
}
