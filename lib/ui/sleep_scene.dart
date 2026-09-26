import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../features/sleep/sleep.dart';

/// The bedtime cinematic and the night countdown, over the whole game.
///
/// Letterboxed (the pictures are wide): six story pictures, 3 s each with soft
/// crossfades and a slow zoom — they move the table, unfold the sofa bed, jump in,
/// tuck in, lights off — then the dark room: the two night pictures (clouds and
/// the lights of the houses change) crossfade in a loop while the camera drifts to
/// the window, then black and «Los gatitos duermen · Nos vemos en 07:59:59».
class SleepScene extends StatelessWidget {
  const SleepScene({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Sleep.instance,
      builder: (context, _) => switch (Sleep.instance.phase) {
        SleepPhase.awake => const SizedBox.shrink(),
        // the flat fades into the night instead of cutting to black
        SleepPhase.cinematic => TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            builder: (context, v, child) => Opacity(opacity: v, child: child),
            child: const _Cinematic(),
          ),
        SleepPhase.sleeping => const _Countdown(),
      },
    );
  }
}

const _dir = 'assets/sleep';
const _story = ['sleep_1', 'sleep_2', 'sleep_3', 'sleep_4', 'sleep_5', 'sleep_6'];
const _night = ['night_1', 'night_2'];

const double _perStory = 3.0; // seconds per story picture
const double _fade = 0.8; // crossfade between pictures
const double _darkSeconds = 16; // the dark room and the drift to the window
const double _nightPer = 3.2; // one night picture to the other
const double _toBlack = 2.5;
final double _total = _story.length * _perStory + _darkSeconds + _toBlack;

class _Cinematic extends StatefulWidget {
  const _Cinematic();

  @override
  State<_Cinematic> createState() => _CinematicState();
}

class _CinematicState extends State<_Cinematic> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_total * 1000).round()),
  )
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) Sleep.instance.cinematicDone();
    })
    ..forward();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final name in [..._story, ..._night]) {
      precacheImage(AssetImage('$_dir/$name.webp'), context);
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  /// Which picture(s) are on screen at [s] seconds: (current, next, how far into the fade).
  (String, String?, double) _frameAt(double s) {
    final storyEnd = _story.length * _perStory;
    if (s < storyEnd) {
      final i = (s / _perStory).floor().clamp(0, _story.length - 1);
      final into = s - i * _perStory;
      final fadeStart = _perStory - _fade;
      if (into > fadeStart && i + 1 < _story.length) {
        return (_story[i], _story[i + 1], (into - fadeStart) / _fade);
      }
      return (_story[i], null, 0);
    }
    // dark room: the two night pictures crossfade slowly back and forth
    final d = s - storyEnd;
    final i = (d / _nightPer).floor();
    final into = d - i * _nightPer;
    final a = _night[i % _night.length];
    final b = _night[(i + 1) % _night.length];
    const fade = 1.6;
    return into > _nightPer - fade ? (a, b, (into - (_nightPer - fade)) / fade) : (a, null, 0);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, _) {
          final s = _t.value * _total;
          final storyEnd = _story.length * _perStory;
          // camera: a slow zoom through the story, then a drift towards the window
          final double zoom;
          final Alignment focus;
          if (s < storyEnd) {
            zoom = 1.0 + 0.14 * (s / storyEnd);
            focus = const Alignment(0, 0.1);
          } else {
            final k = Curves.easeInOut.transform(((s - storyEnd) / _darkSeconds).clamp(0.0, 1.0));
            zoom = 1.14 + 0.9 * k;
            focus = Alignment.lerp(const Alignment(0, 0.1), const Alignment(0.06, -0.62), k)!;
          }
          final black = ((s - storyEnd - _darkSeconds) / _toBlack).clamp(0.0, 1.0);
          final (cur, next, f) = _frameAt(s);
          Widget pic(String name) => Image.asset('$_dir/$name.webp', fit: BoxFit.cover, gaplessPlayback: true);
          return Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: 1280 / 853, // letterbox: the whole picture across the screen
                  child: ClipRect(
                    child: Transform.scale(
                      scale: zoom,
                      alignment: focus,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          pic(cur),
                          if (next != null) Opacity(opacity: Curves.easeInOut.transform(f.clamp(0.0, 1.0)), child: pic(next)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IgnorePointer(child: ColoredBox(color: Colors.black.withValues(alpha: black))),
            ],
          );
        },
      ),
    );
  }
}

class _Countdown extends StatefulWidget {
  const _Countdown();

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  bool _showSkip = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showSkip = true);
    });
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    TextStyle px(double size, Color color) => GoogleFonts.pixelifySans(fontSize: size, color: color, height: 1.2);
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.rotate(
                    angle: -math.pi / 10,
                    child: const Icon(Icons.nightlight_round, color: Color(0xFFFFD08A), size: 40),
                  ),
                  const SizedBox(height: 18),
                  Text('Los gatitos duermen', style: px(24, const Color(0xFFFFF4DE))),
                  const SizedBox(height: 10),
                  Text('Nos vemos en', style: px(15, const Color(0x99FFF4DE))),
                  const SizedBox(height: 4),
                  Text(_fmt(Sleep.instance.remaining), style: px(38, const Color(0xFFFFD08A))),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedOpacity(
                opacity: _showSkip ? 0.55 : 0,
                duration: const Duration(milliseconds: 900),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: TextButton(
                    onPressed: _showSkip ? Sleep.instance.wake : null,
                    child: Text('Saltar', style: px(16, const Color(0xFFFFF4DE))),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
