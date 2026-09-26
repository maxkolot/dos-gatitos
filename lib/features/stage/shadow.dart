import 'dart:ui' as ui;

final ui.Paint _shadow = ui.Paint()
  ..color = const ui.Color(0x80000000)
  ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5);

/// A soft contact shadow on the floor under someone's feet, so nobody seems to float.
/// [lift] (0..1) shrinks and fades it while they are in the air.
void paintShadow(ui.Canvas canvas, ui.Offset feet, double width, {double lift = 0}) {
  final k = (1 - lift * 0.5).clamp(0.3, 1.0);
  final paint = lift <= 0 ? _shadow : (ui.Paint()
    ..color = ui.Color.fromRGBO(0, 0, 0, 0.5 * k)
    ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5));
  canvas.drawOval(ui.Rect.fromCenter(center: feet, width: width * k, height: width * 0.2 * k), paint);
}
