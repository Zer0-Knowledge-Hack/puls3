/// The Freighter bridge for this platform: JS interop on the web, a
/// "not installed" stub elsewhere (VM tests, desktop).
library;

export 'freighter_bridge_stub.dart'
    if (dart.library.js_interop) 'freighter_bridge_web.dart';
