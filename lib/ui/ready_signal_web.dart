import 'package:web/web.dart' as web;

/// Web: the HTML video splash listens for this event and fades out.
void signalReady() => web.window.dispatchEvent(web.Event('dg-ready'));

/// Web has the HTML video splash on top of the Flutter canvas.
const bool hasHtmlSplash = true;
