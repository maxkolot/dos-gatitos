import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../audio/sfx.dart';

/// A frame animation prepared by `tool/prep_anim.py`: the frames plus where the
/// character stands in them, so a frame can replace the idle sprite exactly.
class FrameAnimData {
  FrameAnimData({
    required this.frames,
    required this.fps,
    required this.loop,
    required this.hold,
    required this.refHeight,
    required this.feetY,
    required this.centerX,
    this.heads = const [],
    this.duoHeads = const [],
    this.sequence,
    this.finale,
    this.finaleHold = 3,
    this.cues = const {},
    this.name = '',
    this.startCues = const [],
  });

  final List<ui.Image> frames;
  final double fps;
  final bool loop;

  /// Seconds the last frame stays on screen (one-shot animations).
  final double hold;

  /// Character height, feet line and body centre in frame pixels.
  final double refHeight;
  final double feetY;
  final double centerX;

  /// Top of the head per frame (frame pixels) — the name tag rides on it.
  final List<ui.Offset> heads;

  /// Duo scenes: [Sebastián's head, Maxito's head] per frame (frame pixels).
  final List<List<ui.Offset>> duoHeads;

  /// Optional order of the frames (e.g. there and back again for slow talk scenes).
  final List<int>? sequence;

  /// A frame shown once at the very end (e.g. leaning back full after the loop of eating).
  final int? finale;
  final double finaleHold;

  /// Sounds that go with a frame (`"sfx": {"2": ["sizzle_in", "loop:sizzle"]}` in
  /// the meta, see [Sfx.cue]); `"start"` plays when the animation starts.
  final Map<int, List<String>> cues;

  /// `dance`, `hug`, `dinner`… (the file name).
  final String name;
  final List<String> startCues;

  /// Head top of frame [i] inside the idle sprite box (see [paintAnimFrame]).
  ui.Offset? headInBox(int i, double boxWidth, double boxHeight) {
    if (heads.isEmpty) return null;
    final h = heads[i.clamp(0, heads.length - 1)];
    final k = boxHeight / refHeight;
    return ui.Offset(boxWidth / 2 + (h.dx - centerX) * k, boxHeight - (feetY - h.dy) * k);
  }

  double get oneShotSeconds => (sequence?.length ?? frames.length) / fps + hold;

  /// `dir/name.json` + its frames. `null` (and a log line) when missing.
  static Future<FrameAnimData?> load(String dir, String name) async {
    try {
      final meta = jsonDecode(await rootBundle.loadString('$dir/$name.json')) as Map<String, dynamic>;
      final cues = <int, List<String>>{};
      var startCues = const <String>[];
      for (final e in ((meta['sfx'] as Map?) ?? const {}).entries) {
        final list = e.value is List ? (e.value as List).cast<String>() : [e.value as String];
        if (e.key == 'start') {
          startCues = list;
        } else {
          cues[int.parse(e.key as String)] = list;
        }
      }
      final frames = <ui.Image>[];
      for (final file in (meta['frames'] as List).cast<String>()) {
        final data = await rootBundle.load('$dir/$file');
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        frames.add((await codec.getNextFrame()).image);
      }
      return FrameAnimData(
        frames: frames,
        fps: (meta['fps'] as num).toDouble(),
        loop: meta['loop'] == true,
        hold: (meta['hold'] as num? ?? 1.5).toDouble(),
        refHeight: (meta['refHeight'] as num).toDouble(),
        feetY: (meta['feetY'] as num).toDouble(),
        centerX: (meta['centerX'] as num).toDouble(),
        heads: [
          for (final p in (meta['heads'] as List? ?? const []))
            ui.Offset(((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()),
        ],
        sequence: (meta['sequence'] as List?)?.map((e) => (e as num).toInt()).toList(),
        finale: (meta['finale'] as num?)?.toInt(),
        finaleHold: (meta['finaleHold'] as num? ?? 3).toDouble(),
        cues: cues,
        name: name,
        startCues: startCues,
        duoHeads: [
          for (final pair in (meta['duoHeads'] as List? ?? const []))
            [
              for (final p in pair as List)
                ui.Offset(((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()),
            ],
        ],
      );
    } catch (e) {
      debugPrint('FrameAnimData: cannot load $dir/$name ($e)');
      return null;
    }
  }
}

/// Plays one [FrameAnimData] at a time for a character.
class FramePlayer {
  FrameAnimData? _data;
  double _t = 0;
  double _limit = 0;
  VoidCallback? _onDone;
  bool _inFinale = false;
  int _lastFrame = -1;
  final Set<String> _loopsOn = {}; // ambience this animation started (sizzle, crackle)

  void _fire(List<String>? cues) {
    for (final c in cues ?? const <String>[]) {
      if (c.startsWith('loop:')) _loopsOn.add(Sfx.parse(c.substring(5)).$1);
      if (c.startsWith('stop:')) _loopsOn.remove(Sfx.parse(c.substring(5)).$1);
      Sfx.instance.cue(c);
    }
  }

  void _endLoops() {
    for (final name in _loopsOn) {
      Sfx.instance.stopLoop(name);
    }
    _loopsOn.clear();
  }

  void _checkCues() {
    final d = _data;
    if (d == null) return;
    final i = frameIndex;
    if (i == _lastFrame) return;
    _lastFrame = i;
    _fire(d.cues[i]);
  }

  bool get playing => _data != null;
  FrameAnimData? get data => _data;

  /// One-shot animations run once and hold the last frame; looping ones run
  /// for [seconds] (or until [stop]). [onDone] runs when it ends either way.
  void play(FrameAnimData? data, {double? seconds, VoidCallback? onDone}) {
    if (data == null) {
      onDone?.call();
      return;
    }
    _endLoops();
    _data = data;
    _t = 0;
    _inFinale = false;
    _lastFrame = -1;
    _fire(data.startCues);
    _checkCues();
    _limit = seconds ?? (data.loop ? double.infinity : data.oneShotSeconds);
    _onDone = onDone;
  }

  /// Stops without running the follow-up (another action took over the stage).
  void cancel() {
    _endLoops();
    _data = null;
    _onDone = null;
  }

  void stop() {
    _endLoops();
    final done = _onDone;
    _data = null;
    _onDone = null;
    done?.call();
  }

  void update(double dt) {
    if (_data == null) return;
    // after the app was in the background the first frame brings a huge dt:
    // continue where it was instead of skipping the whole animation
    _t += math.min(dt, 0.1);
    _checkCues();
    if (_t < _limit) return;
    final finale = _data?.finale;
    if (finale != null && !_inFinale) {
      _inFinale = true; // the closing frame, once
      _t = 0;
      _limit = _data!.finaleHold;
      _checkCues();
      return;
    }
    stop();
  }

  int get frameIndex {
    final d = _data;
    if (d == null || d.frames.isEmpty) return 0;
    if (_inFinale && d.finale != null) return d.finale!.clamp(0, d.frames.length - 1);
    final seq = d.sequence;
    final n = seq?.length ?? d.frames.length;
    var i = (_t * d.fps).floor();
    i = d.loop ? i % n : math.min(i, n - 1);
    return (seq != null ? seq[i] : i).clamp(0, d.frames.length - 1);
  }

  ui.Image? get frame {
    final d = _data;
    if (d == null || d.frames.isEmpty) return null;
    return d.frames[frameIndex];
  }
}

/// Draws [image] so the character in it stands exactly in a box of
/// [boxWidth] x [boxHeight] (feet on the bottom edge, body centred) — the box
/// of the idle sprite. Props in the frame (a cabinet, a table) stick out of it.
void paintAnimFrame(
  ui.Canvas canvas,
  ui.Image image,
  FrameAnimData data,
  double boxWidth,
  double boxHeight,
  ui.Paint paint,
) {
  final k = boxHeight / data.refHeight;
  canvas.drawImageRect(
    image,
    ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    ui.Rect.fromLTWH(
      boxWidth / 2 - data.centerX * k,
      boxHeight - data.feetY * k,
      image.width * k,
      image.height * k,
    ),
    paint,
  );
}
