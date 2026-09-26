import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Native-app splash: the intro video plays once, then its back-and-forth tail
/// (from [loopFrom]) loops until [ready] completes — never shorter than
/// [minShow] — then it fades out. The sharp first frame shows until the video
/// starts. On the web the HTML video splash in web/index.html plays this role.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({
    super.key,
    required this.ready,
    this.minShow = const Duration(seconds: 4),
    this.loopFrom = const Duration(seconds: 5),
  });

  final Future<void> ready;
  final Duration minShow;
  final Duration loopFrom;

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay> {
  final VideoPlayerController _video = VideoPlayerController.asset(
    'assets/splash/splash.mp4',
    videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
  );
  bool _playing = false;
  bool _fading = false;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _start();
    Future.wait<void>([widget.ready, Future<void>.delayed(widget.minShow)]).whenComplete(() {
      if (!mounted) return;
      setState(() => _fading = true);
      Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _video.pause();
        setState(() => _gone = true);
      });
    });
  }

  Future<void> _start() async {
    try {
      await _video.initialize();
      await _video.setVolume(0);
      _video.addListener(_loopTail);
      await _video.play();
      if (mounted) setState(() => _playing = true);
    } catch (e) {
      debugPrint('Splash video: $e'); // the still frame stays, the game still loads
    }
  }

  /// At the end, jump back to the start of the tail: the tail is recorded
  /// backwards-then-forwards, so the jump is invisible.
  void _loopTail() {
    final v = _video.value;
    if (!v.isInitialized || v.duration == Duration.zero) return;
    if (v.position >= v.duration - const Duration(milliseconds: 80) || v.isCompleted) {
      _video.seekTo(widget.loopFrom);
      if (!v.isPlaying) _video.play();
    }
  }

  @override
  void dispose() {
    _video.removeListener(_loopTail);
    _video.dispose();
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
              Image.asset('assets/splash/splash.jpg', fit: BoxFit.cover),
              if (_playing)
                FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _video.value.size.width,
                    height: _video.value.size.height,
                    child: VideoPlayer(_video),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
