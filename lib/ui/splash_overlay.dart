import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Native-app splash: the key art with a slow zoom until [ready] completes
/// (never shorter than [minShow]), then a soft fade. On the web the HTML video
/// splash plays this role, so this widget is not used there.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({super.key, required this.ready, this.minShow = const Duration(seconds: 4)});

  final Future<void> ready;
  final Duration minShow;

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _zoom =
      AnimationController(vsync: this, duration: const Duration(seconds: 8))..forward();
  bool _fading = false;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    Future.wait<void>([widget.ready, Future<void>.delayed(widget.minShow)]).whenComplete(() {
      if (!mounted) return;
      setState(() => _fading = true);
      Timer(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _gone = true);
      });
    });
  }

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: _fading,
      child: AnimatedOpacity(
        opacity: _fading ? 0 : 1,
        duration: const Duration(milliseconds: 450),
        child: ColoredBox(
          color: const Color(0xFF1D1B2E),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedBuilder(
                animation: _zoom,
                builder: (context, child) => Transform.scale(
                  scale: 1 + 0.08 * Curves.easeOut.transform(_zoom.value),
                  child: child,
                ),
                child: Image.asset('assets/splash/splash.jpg', fit: BoxFit.cover),
              ),
              Align(
                alignment: const Alignment(0, 0.93),
                child: Text(
                  'Cargando…',
                  style: GoogleFonts.pixelifySans(
                    fontSize: 16,
                    color: const Color(0xFFFFF4DE),
                    shadows: const [Shadow(color: Color(0xFF2B1830), blurRadius: 0, offset: Offset(2, 2))],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
