import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pixel-font name above a character: cream letters with a dark plum outline,
/// drawn by the character itself so it follows every step and sway.
class NameTag {
  NameTag(this.name, {this.accent = const Color(0xFFFFD08A)}) {
    // the pixel font is fetched at runtime; until it arrives the fallback font is laid out,
    // so lay the text out again once it is there
    _fontReady.then((_) => refresh(), onError: (_) {});
  }

  /// true once the pixel font is there (others relayout their text then too).
  static bool fontReady = false;

  static void _markReady() => fontReady = true;

  static final Future<void> _fontReady =
      GoogleFonts.pendingFonts([GoogleFonts.pixelifySans(fontWeight: FontWeight.w600)])..then((_) => _markReady(), onError: (_) {});

  final String name;

  /// Small underline in the character's colour.
  final Color accent;

  TextPainter? _fill;
  TextPainter? _stroke;
  final ui.Paint _accentPaint = ui.Paint();

  void _layout() {
    TextStyle style(Paint? foreground, Color? color) => GoogleFonts.pixelifySans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          foreground: foreground,
          color: color,
        );
    _stroke = TextPainter(
      text: TextSpan(
        text: name,
        style: style(
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeJoin = StrokeJoin.miter
            ..color = const Color(0xFF2B1830),
          null,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _fill = TextPainter(
      text: TextSpan(text: name, style: style(null, const Color(0xFFFFF4DE))),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  /// Paints the tag with its bottom centre at [bottomCenter].
  void paint(ui.Canvas canvas, ui.Offset bottomCenter, {double opacity = 1}) {
    if (opacity <= 0.01) return;
    if (_fill == null) _layout();
    final fill = _fill!;
    final stroke = _stroke!;
    final topLeft = bottomCenter - ui.Offset(fill.width / 2, fill.height + 6);
    if (opacity < 0.99) {
      canvas.saveLayer(null, ui.Paint()..color = ui.Color.fromRGBO(255, 255, 255, opacity));
    }
    stroke.paint(canvas, topLeft);
    fill.paint(canvas, topLeft);
    _accentPaint.color = accent;
    canvas.drawRect(
      ui.Rect.fromCenter(center: bottomCenter + const ui.Offset(0, -2), width: fill.width * 0.55, height: 3),
      _accentPaint,
    );
    if (opacity < 0.99) canvas.restore();
  }

  /// Google Fonts arrive asynchronously: relayout once they are there.
  void refresh() {
    _fill = null;
    _stroke = null;
  }
}
