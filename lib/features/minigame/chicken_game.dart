import 'dart:math' as math;

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// «Atrapá las gallinas»: black-cat Sebastián on a Barcelona rooftop.
///
/// Chickens run across the terrace (sometimes they hop, they panic when the cat
/// comes close, a rare golden one is worth 5). Tap a chicken and the cat leaps
/// there — they keep running, so aim ahead. Tap the floor and he runs there.
/// A round lasts [roundSeconds].
class ChickenGame extends FlameGame with TapCallbacks {
  ChickenGame({this.roundSeconds = 30});

  final int roundSeconds;

  final ValueNotifier<int> score = ValueNotifier(0);
  final ValueNotifier<double> timeLeft = ValueNotifier(0);
  final ValueNotifier<bool> running = ValueNotifier(false);

  /// Called when a round ends (with the score).
  void Function(int score)? onRoundOver;

  final _rnd = math.Random();
  final Images _img = Images(prefix: 'assets/minigame/');
  late final Map<String, Sprite> _s;
  late final SpriteComponent _bg;
  late final _Cat _cat;
  final List<_Chicken> _chickens = [];
  double _spawnIn = 0.6;
  double _elapsed = 0;

  /// Feet line of everyone on the terrace.
  double floorY = 0;

  Sprite sprite(String name) => _s[name]!;

  @override
  Color backgroundColor() => const Color(0xFF1C2260);

  @override
  Future<void> onLoad() async {
    const names = [
      'bg_roof', 'cat_run1', 'cat_run2', 'cat_jump', 'cat_pounce', 'cat_win',
      'chicken_run1', 'chicken_run2', 'chicken_hop', 'chicken_scared', 'chicken_golden', 'chicken_dizzy',
    ];
    _s = {for (final n in names) n: Sprite(await _img.load('$n.webp'))};
    _bg = SpriteComponent(sprite: _s['bg_roof'], priority: -10);
    _cat = _Cat();
    await addAll([_bg, _cat]);
    _layout(size);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) _layout(size);
  }

  void _layout(Vector2 view) {
    // cover the screen with the rooftop, keep the terrace (bottom of the picture) in view
    final src = _bg.sprite!.srcSize;
    final k = math.max(view.x / src.x, view.y / src.y);
    _bg.size = src * k;
    _bg.position = Vector2((view.x - _bg.size.x) / 2, view.y - _bg.size.y);
    floorY = _bg.position.y + _bg.size.y * 0.885;
    _cat.fit(view);
    for (final c in _chickens) {
      c.fit(view);
    }
  }

  /// A new round.
  void startRound() {
    for (final c in _chickens) {
      c.removeFromParent();
    }
    _chickens.clear();
    score.value = 0;
    timeLeft.value = roundSeconds.toDouble();
    _elapsed = 0;
    _spawnIn = 0.4;
    _cat.reset();
    running.value = true;
  }

  @override
  void update(double dt) {
    dt = math.min(dt, 0.1);
    super.update(dt);
    if (!running.value) return;
    _elapsed += dt;
    timeLeft.value = math.max(0, roundSeconds - _elapsed);
    if (timeLeft.value <= 0) {
      running.value = false;
      _cat.win();
      onRoundOver?.call(score.value);
      return;
    }
    _spawnIn -= dt;
    if (_spawnIn <= 0) {
      _spawn();
      // faster and faster: from ~1.4 s to ~0.6 s between chickens
      final pace = 1 - (_elapsed / roundSeconds);
      _spawnIn = 0.55 + 0.9 * pace * (0.6 + _rnd.nextDouble() * 0.6);
    }
    _chickens.removeWhere((c) => c.isRemoving || c.parent == null);
  }

  void _spawn() {
    final fromLeft = _rnd.nextBool();
    final golden = _rnd.nextDouble() < 0.1;
    final speed = size.x * (0.22 + 0.2 * _rnd.nextDouble() + 0.18 * (_elapsed / roundSeconds)) * (golden ? 1.35 : 1);
    final c = _Chicken(dir: fromLeft ? 1 : -1, speed: speed, golden: golden);
    _chickens.add(c);
    add(c);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!running.value) return;
    final p = event.canvasPosition;
    // the chicken the player meant: nearest to the tap, generous radius
    _Chicken? target;
    var best = double.infinity;
    for (final c in _chickens.where((c) => !c.caught)) {
      final d = c.centre.distanceTo(p);
      if (d < c.size.y * 1.1 && d < best) {
        best = d;
        target = c;
      }
    }
    if (target != null) {
      _cat.leapTo(target.position.x);
    } else {
      _cat.runTo(p.x);
    }
  }

  /// The cat landed at [x]: every chicken under his paws is caught.
  void landedAt(double x, double reach) {
    var caughtNow = 0;
    for (final c in _chickens.where((c) => !c.caught)) {
      if ((c.position.x - x).abs() < reach + c.size.x * 0.3 && !c.inAir) {
        c.catchIt();
        score.value += c.golden ? 5 : 1;
        caughtNow++;
      }
    }
    if (caughtNow > 1) score.value += caughtNow; // two at once: a bonus
  }

  /// Chickens panic when the cat is close.
  double get catX => _cat.position.x;

  @override
  void onRemove() {
    _img.clearCache();
    super.onRemove();
  }
}

enum _CatState { idle, run, jump, pounce, win }

class _Cat extends SpriteComponent with HasGameReference<ChickenGame> {
  _Cat() : super(anchor: const Anchor(0.5, 0.94), priority: 5);

  _CatState _state = _CatState.idle;
  double _t = 0;
  double _targetX = 0;
  double _fromX = 0;
  double _dir = 1;
  static const _jumpTime = 0.5;

  @override
  Future<void> onLoad() async {
    sprite = game.sprite('cat_run1'); // sitting still until the first tap
  }

  void fit(Vector2 view) {
    final h = (view.y * 0.14).clamp(80.0, 190.0);
    size = Vector2(h * 437 / 420, h);
    if (position.x == 0) position = Vector2(view.x * 0.5, game.floorY);
    position.y = game.floorY;
  }

  void reset() {
    _state = _CatState.idle;
    position = Vector2(game.size.x * 0.5, game.floorY);
    sprite = game.sprite('cat_run1');
    _face(1);
  }

  void _face(double dir) {
    if (dir == 0 || dir == _dir) return;
    _dir = dir;
    flipHorizontallyAroundCenter();
  }

  void runTo(double x) {
    if (_state == _CatState.jump || _state == _CatState.pounce) return;
    _targetX = x.clamp(size.x / 2, game.size.x - size.x / 2);
    _face((_targetX - position.x).sign);
    _state = _CatState.run;
  }

  void leapTo(double x) {
    if (_state == _CatState.jump || _state == _CatState.pounce) return;
    _fromX = position.x;
    _targetX = x.clamp(size.x / 2, game.size.x - size.x / 2);
    _face((_targetX - _fromX).sign);
    _state = _CatState.jump;
    _t = 0;
    sprite = game.sprite('cat_jump');
  }

  void win() {
    _state = _CatState.win;
    position.y = game.floorY;
    sprite = game.sprite('cat_win');
    _face(1);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    switch (_state) {
      case _CatState.run:
        final step = game.size.x * 1.1 * dt;
        final d = _targetX - position.x;
        if (d.abs() <= step) {
          position.x = _targetX;
          _state = _CatState.idle;
          sprite = game.sprite('cat_run1');
        } else {
          position.x += step * d.sign;
          sprite = game.sprite((_t * 10).floor().isEven ? 'cat_run1' : 'cat_run2');
        }
      case _CatState.jump:
        final k = (_t / _jumpTime).clamp(0.0, 1.0);
        position.x = _fromX + (_targetX - _fromX) * k;
        position.y = game.floorY - math.sin(k * math.pi) * size.y * 1.1;
        if (k >= 1) {
          position.y = game.floorY;
          _state = _CatState.pounce;
          _t = 0;
          sprite = game.sprite('cat_pounce');
          game.landedAt(position.x + _dir * size.x * 0.25, size.x * 0.45);
        }
      case _CatState.pounce:
        if (_t > 0.28) {
          _state = _CatState.idle;
          sprite = game.sprite('cat_run1');
        }
      case _CatState.idle:
      case _CatState.win:
        break;
    }
  }
}

class _Chicken extends SpriteComponent with HasGameReference<ChickenGame> {
  _Chicken({required this.dir, required this.speed, required this.golden})
      : super(anchor: const Anchor(0.5, 0.99), priority: 4);

  final double dir;
  double speed;
  final bool golden;
  bool caught = false;
  double _t = 0;
  double _hop = 0; // >0 while in the air
  double _scared = 0;
  double _caughtFor = 0;
  final _rnd = math.Random();

  bool get inAir => _hop > 0.05;
  Vector2 get centre => position - Vector2(0, size.y * 0.5);

  void fit(Vector2 view) {
    final h = (view.y * 0.085).clamp(50.0, 120.0);
    size = Vector2(h * 417 / 420, h);
  }

  @override
  Future<void> onLoad() async {
    fit(game.size);
    position = Vector2(dir > 0 ? -size.x : game.size.x + size.x, game.floorY);
    sprite = game.sprite(golden ? 'chicken_golden' : 'chicken_run1');
    if (dir < 0) flipHorizontallyAroundCenter(); // the art runs to the right
  }

  void catchIt() {
    caught = true;
    _caughtFor = 0;
    sprite = game.sprite('chicken_dizzy');
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (caught) {
      _caughtFor += dt;
      position.y = game.floorY;
      opacity = (1 - (_caughtFor - 0.6) / 0.4).clamp(0.0, 1.0);
      if (_caughtFor > 1.0) removeFromParent();
      return;
    }
    // panic when the cat is close: faster for a moment
    if ((game.catX - position.x).abs() < game.size.x * 0.22 && _scared <= 0) _scared = 0.5;
    _scared -= dt;
    final boost = _scared > 0 ? 1.7 : 1.0;
    position.x += dir * speed * boost * dt;
    // now and then a flapping hop
    if (_hop <= 0 && _rnd.nextDouble() < dt * 0.5) _hop = 0.001;
    if (_hop > 0) {
      _hop += dt;
      final k = _hop / 0.45;
      position.y = game.floorY - math.sin(k.clamp(0.0, 1.0) * math.pi) * size.y * 0.8;
      if (k >= 1) {
        _hop = 0;
        position.y = game.floorY;
      }
    }
    if (!golden) {
      sprite = game.sprite(_scared > 0
          ? 'chicken_scared'
          : _hop > 0
              ? 'chicken_hop'
              : ((_t * 8).floor().isEven ? 'chicken_run1' : 'chicken_run2'));
    }
    if (position.x < -size.x * 1.5 || position.x > game.size.x + size.x * 1.5) removeFromParent();
  }
}
