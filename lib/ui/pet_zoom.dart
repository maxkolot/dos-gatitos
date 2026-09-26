import 'package:flutter/material.dart';

import '../app_state.dart';

/// The camera coming close to Sr. Fer while he sleeps ([petZoom] 0..1 around
/// [petFocus]): the whole room zooms in, he slides to the middle, the edges get
/// a soft dark vignette. The tree never changes shape, so the game underneath is
/// never re-mounted.
class PetZoom extends StatelessWidget {
  const PetZoom({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => ValueListenableBuilder<double>(
        valueListenable: petZoom,
        child: child,
        builder: (context, k, child) {
          final p = petFocus;
          final to = Offset(box.maxWidth / 2, box.maxHeight * 0.56);
          final s = 1 + 1.1 * k;
          final m = Matrix4.identity()
            ..translateByDouble(p.dx + (to.dx - p.dx) * k, p.dy + (to.dy - p.dy) * k, 0, 1)
            ..scaleByDouble(s, s, 1, 1)
            ..translateByDouble(-p.dx, -p.dy, 0, 1);
          return Stack(
            fit: StackFit.expand,
            children: [
              Transform(transform: k > 0 ? m : Matrix4.identity(), child: child),
              IgnorePointer(
                child: Opacity(
                  opacity: (k * 0.75).clamp(0.0, 1.0),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, 0.12),
                        radius: 0.95,
                        colors: [Color(0x00000000), Color(0x22100A28), Color(0xCC0A0618)],
                        stops: [0.35, 0.65, 1],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
