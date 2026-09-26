// Tells the web page (web/index.html) that the game is ready, so the HTML
// video splash can fade out. A no-op in the native apps.
export 'ready_signal_stub.dart' if (dart.library.js_interop) 'ready_signal_web.dart';
