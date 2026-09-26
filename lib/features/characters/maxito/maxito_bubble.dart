import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../../game.dart';
import 'maxito_state.dart';

/// Maxito's speech bubble: hangs over his head wherever he is (also during the
/// close-up) and shows whatever the dialogue layer put into
/// [MaxitoController.say]. Screen-space on purpose, so the text never gets
/// scaled by the zoom.
class MaxitoBubble extends Component with HasGameReference<DosGatitosGame> {
  MaxitoBubble({MaxitoController? controller})
      : controller = controller ?? MaxitoController.instance;

  final MaxitoController controller;

  static const double _maxWidth = 300;
  static const double _radius = 16;
  static const Color _paper = Color(0xF7FFFBF4);
  static const Color _border = Color(0xFFE0A15C);
  static const Color _name = Color(0xFFD9762A);
  static const Color _ink = Color(0xFF2A2028);

  final _namePainter = TextPainter(
    text: const TextSpan(
      text: 'Maxito',
      style: TextStyle(color: _name, fontSize: 13, fontWeight: FontWeight.w700),
    ),
    textDirection: TextDirection.ltr,
  )..layout(); // painted every frame, so it has to be measured once

  TextPainter _body = TextPainter(textDirection: TextDirection.ltr);
  String _shown = '';
  double _fade = 0;

  final _shadow = ui.Paint()..color = const ui.Color(0x33000000);
  final _paperPaint = ui.Paint()..color = _paper;
  final _borderPaint = ui.Paint()
    ..color = _border
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void update(double dt) {
    final want = controller.hasLine ? 1.0 : 0.0;
    if (want > _fade) {
      _fade = (_fade + dt / 0.22).clamp(0.0, 1.0);
    } else {
      _fade = (_fade - dt / 0.16).clamp(0.0, 1.0);
    }
    if (controller.line != _shown) {
      _shown = controller.line;
      _body = TextPainter(
        text: TextSpan(
          text: _shown,
          style: const TextStyle(color: _ink, fontSize: 16, height: 1.25),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 5,
      )..layout(maxWidth: _maxWidth - 24);
    }
  }

  @override
  void render(ui.Canvas canvas) {
    if (_fade <= 0.01 || !controller.hasLine) return;

    final view = game.size;
    final bodyWidth = _body.width;
    final width = bodyWidth + 24;
    final height = _body.height + _namePainter.height + 24;

    // Above his head, kept on screen and away from the top edge.
    var left = controller.headX - width / 2;
    left = left.clamp(8.0, (view.x - width - 8).clamp(8.0, double.infinity));
    var top = controller.headY - height - 16;
    if (top < 64) top = controller.headY + controller.headSize * 0.55;

    final rect = ui.Rect.fromLTWH(left, top, width, height);
    final rrect = ui.RRect.fromRectAndRadius(rect, const ui.Radius.circular(_radius));

    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    final pop = 0.92 + 0.08 * _fade;
    canvas.scale(pop);
    canvas.translate(-rect.center.dx, -rect.center.dy);
    canvas.drawRRect(
      rrect.shift(const ui.Offset(0, 3)),
      _shadow,
    );
    canvas.drawRRect(rrect, _paperPaint);
    canvas.drawRRect(rrect, _borderPaint);

    // little tail towards Maxito
    final tail = ui.Path()
      ..moveTo(rect.center.dx - 10, rect.bottom - 2)
      ..lineTo(rect.center.dx + 2, rect.bottom + 12)
      ..lineTo(rect.center.dx + 12, rect.bottom - 2)
      ..close();
    canvas.drawPath(tail, _paperPaint);
    canvas.drawPath(tail, _borderPaint);

    _namePainter.paint(canvas, rect.topLeft + const ui.Offset(12, 8));
    _body.paint(canvas, rect.topLeft + ui.Offset(12, 12 + _namePainter.height));
    canvas.restore();
  }
}
