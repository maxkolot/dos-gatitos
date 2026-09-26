import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import 'room_layout.dart';

/// The cozy Barcelona flat: background art + interactive zone geometry.
///
/// Add it *before* the characters (or keep [roomPriority]) so it is drawn
/// behind them:
/// ```dart
/// await add(RoomScene());            // background + zones
/// await add(Cats(...));              // characters on top
/// final sofa = room.standPoint('sofa', height: 96);
/// ```
class RoomScene extends Component with HasGameReference<FlameGame> {
  RoomScene({this.showZoneDebug = false, super.priority = roomPriority});

  /// Anything with a smaller priority is rendered earlier (further back).
  static const int roomPriority = -100;

  /// The only background asset of the room. Path is stable — the integrator may
  /// reuse it for a widget based HUD (`RoomBackdrop`).
  static const String backgroundAsset = 'assets/room/bg_room.png';

  /// Draws the zone rectangles + ids on top of the room (debug only).
  final bool showZoneDebug;

  /// Current mapping art -> canvas. Valid from the first frame on.
  RoomLayout layout = RoomLayout(canvas: Size.zero);

  /// Called once per size change (rotation, browser resize, folding phone).
  void Function(RoomLayout layout)? onLayoutChanged;

  Sprite? _background;
  final Paint _paint = Paint()..filterQuality = FilterQuality.none; // crisp pixels, no blur
  final Paint _zoneFill = Paint()..color = const Color(0x33FF8A3D);
  final Paint _zoneStroke = Paint()
    ..color = const Color(0xCCFFD08A)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  Future<void> onLoad() async {
    final image = await game.images.load(backgroundAsset);
    _background = Sprite(
      image,
      srcSize: Vector2(image.width.toDouble(), image.height.toDouble()),
    );
    _syncLayout();
  }

  /// Recomputes the layout if the canvas size changed. Called every frame —
  /// cheap, and it survives any resize without extra bookkeeping.
  @override
  void update(double dt) {
    _syncLayout();
    super.update(dt);
  }

  void _syncLayout() {
    final size = Size(game.size.x, game.size.y);
    if (size.isEmpty || layout.canvas == size) return;
    layout = RoomLayout(canvas: size);
    onLayoutChanged?.call(layout);
  }

  /// Feet line of the characters (use it to place every actor).
  double get floorLineY => layout.floorLineY;

  Rect zoneRect(String id) => layout.zoneRectById(id);

  /// Where a character of [height] stands when it is "at" that zone.
  Offset standPoint(String id, {double height = 96}) => layout.standPoint(id, height: height);

  /// Zone under a canvas point — for tap/drag handling.
  RoomZone? zoneAt(Offset point) => layout.zoneAt(point);

  @override
  void render(Canvas canvas) {
    final background = _background;
    if (background == null) return;
    // BoxFit.cover: scale up until the art fills the canvas, centre it. The art
    // ratio matches both target screens, so nothing gets stretched.
    canvas.drawImageRect(
      background.image,
      Offset.zero & RoomLayout.artSize,
      layout.roomRect,
      _paint,
    );
    if (showZoneDebug) _renderZoneDebug(canvas);
  }

  void _renderZoneDebug(Canvas canvas) {
    for (final zone in RoomZones.all) {
      final rect = layout.zoneRect(zone);
      canvas.drawRect(rect, _zoneFill);
      canvas.drawRect(rect, _zoneStroke);
      final painter = TextPainter(
        text: TextSpan(
          text: '${zone.id}  (${rect.left.round()},${rect.top.round()}) ${rect.width.round()}x${rect.height.round()}',
          style: const TextStyle(color: Color(0xFFFFE7C4), fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, Offset(rect.left + 4, rect.top + 4));
    }
    final hud = layout.hudSafeArea;
    canvas.drawRect(
      hud,
      Paint()
        ..color = const Color(0x22FFFFFF)
        ..style = PaintingStyle.fill,
    );
    canvas.drawLine(
      Offset(0, floorLineY),
      Offset(layout.canvas.width, floorLineY),
      Paint()
        ..color = const Color(0x88FF8A3D)
        ..strokeWidth = 2,
    );
  }
}

/// Widget flavour of the same room for integrators that stack Flutter widgets
/// instead of Flame components. Uses identical cover maths
/// ([RoomLayout]), so characters placed with [RoomLayout.standPoint] land
/// exactly on the sofa/table/window/music hotspots.
class RoomBackdrop extends StatelessWidget {
  const RoomBackdrop({super.key, this.child, this.builder, this.showZoneDebug = false});

  /// Drawn on top of the room (e.g. characters, HUD).
  final Widget? child;

  /// Same as [child], but gets the current [RoomLayout].
  final Widget Function(RoomLayout layout)? builder;

  final bool showZoneDebug;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          RoomScene.backgroundAsset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.none,
          isAntiAlias: false,
        ),
        if (showZoneDebug) Positioned.fill(child: CustomPaint(painter: _ZoneDebugPainter())),
        if (builder case final build?) Positioned.fill(child: _LayoutBuilderBox(builder: build)),
        ?child,
      ],
    );
  }
}

class _LayoutBuilderBox extends StatelessWidget {
  const _LayoutBuilderBox({required this.builder});

  final Widget Function(RoomLayout layout) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => builder(RoomLayout(canvas: constraints.biggest)),
    );
  }
}

class _ZoneDebugPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final layout = RoomLayout(canvas: size);
    final fill = Paint()..color = const Color(0x33FF8A3D);
    final stroke = Paint()
      ..color = const Color(0xCCFFD08A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final zone in RoomZones.all) {
      canvas.drawRect(layout.zoneRect(zone), fill);
      canvas.drawRect(layout.zoneRect(zone), stroke);
    }
    canvas.drawLine(
      Offset(0, layout.floorLineY),
      Offset(size.width, layout.floorLineY),
      Paint()
        ..color = const Color(0x88FF8A3D)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

