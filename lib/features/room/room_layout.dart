import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

/// Design size of `assets/room/bg_room.png` (portrait 430x932 scaled by ~1.65).
///
/// Both target screens, 390x844 (0.4621) and 430x932 (0.4613), are within 0.2%
/// of this ratio, so the background is drawn with [BoxFit.cover]: it is only
/// cropped by a pixel or two, never stretched.
const double roomArtWidth = 708;
const double roomArtHeight = 1536;

/// Normalized (0..1, top-left origin) horizontal line where the floor meets the
/// wall furniture — the line characters stand on.
const double roomFloorLine = 0.795;

/// Height of the top strip that stays free for the HUD (title + score).
/// Nothing interactive and no character may be placed above this line.
const double roomHudSafeHeight = 108;

/// One interactive hotspot of the room, in normalized room coordinates.
///
/// Coordinates are relative to the *art*, not to the screen, so the same zone
/// works on every phone size once [RoomLayout] has mapped the art onto the
/// canvas (see `assets/room/README.md` for a picture with all rectangles).
class RoomZone {
  const RoomZone({
    required this.id,
    required this.label,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  /// Stable id used by the gameplay code: `sofa`, `table`, `window`, `music`.
  final String id;

  /// Spanish label, for tooltips/debug — never drawn onto the background art.
  final String label;

  final double left;
  final double top;
  final double width;
  final double height;

  Rect get normalizedRect => Rect.fromLTWH(left, top, width, height);

  /// The zone in room-art pixel space (0..[roomArtWidth] x 0..[roomArtHeight]).
  Rect get artRect =>
      Rect.fromLTWH(left * roomArtWidth, top * roomArtHeight, width * roomArtWidth, height * roomArtHeight);

  Vector2 get center2 => Vector2(left + width / 2, top + height / 2);
}

/// The four interactive zones of the flat + the plants (decor, optional).
abstract final class RoomZones {
  static const sofa = RoomZone(id: 'sofa', label: 'Sofá', left: 0.300, top: 0.530, width: 0.440, height: 0.270);
  static const table = RoomZone(id: 'table', label: 'Mesa', left: 0.360, top: 0.720, width: 0.290, height: 0.150);
  static const window = RoomZone(id: 'window', label: 'Ventana / balcón', left: 0.055, top: 0.140, width: 0.305, height: 0.380);
  static const music = RoomZone(id: 'music', label: 'Música', left: 0.655, top: 0.470, width: 0.290, height: 0.300);
  static const plants = RoomZone(id: 'plants', label: 'Plantas', left: 0.020, top: 0.550, width: 0.170, height: 0.330);

  /// Zones the gameplay may interact with, in a stable order.
  static const List<RoomZone> all = [sofa, table, window, music, plants];

  static RoomZone? byId(String id) {
    for (final zone in all) {
      if (zone.id == id) return zone;
    }
    return null;
  }
}

/// Maps the room art onto the current canvas and answers every geometry
/// question the rest of the game asks: where is the wall, the floor line, a
/// zone rectangle, where does a character of height `h` stand when it is "at"
/// the sofa, and is a tap inside the room.
class RoomLayout {
  RoomLayout({required this.canvas});

  static const Size artSize = Size(roomArtWidth, roomArtHeight);

  /// Logical canvas (game) size.
  final Size canvas;

  /// Cover scale: art is scaled up until it fills the whole canvas.
  double get scale => math.max(canvas.width / artSize.width, canvas.height / artSize.height);

  /// Where the art lands on the canvas (may stick out on the sides).
  Rect get roomRect {
    final w = artSize.width * scale;
    final h = artSize.height * scale;
    // Centred: the composition keeps its furniture in the central 70% of the
    // art, so a small horizontal crop is harmless on both target screens.
    return Rect.fromLTWH((canvas.width - w) / 2, (canvas.height - h) / 2, w, h);
  }

  /// Top strip reserved for the HUD.
  Rect get hudSafeArea => Rect.fromLTWH(0, 0, canvas.width, math.min(roomHudSafeHeight, canvas.height * 0.2));

  /// Everything below the HUD — where characters and hotspots live.
  Rect get playArea => Rect.fromLTRB(0, hudSafeArea.bottom, canvas.width, canvas.height);

  /// Canvas y of the floor line: feet of the characters stand here.
  double get floorLineY => roomRect.top + roomRect.height * roomFloorLine;

  /// A normalized room point in canvas coordinates.
  Offset toCanvas(Offset normalized) =>
      Offset(roomRect.left + normalized.dx * roomRect.width, roomRect.top + normalized.dy * roomRect.height);

  /// The canvas rectangle of a zone.
  Rect zoneRect(RoomZone zone) {
    final a = roomRect;
    return Rect.fromLTWH(
      a.left + zone.left * a.width,
      a.top + zone.top * a.height,
      zone.width * a.width,
      zone.height * a.height,
    );
  }

  Rect zoneRectById(String id) {
    final zone = RoomZones.byId(id);
    return zone == null ? Rect.zero : zoneRect(zone);
  }

  /// Where a character of the given [height] stands while it is "at" that zone:
  /// horizontally centred on the zone, feet on the floor line — the room is a
  /// flat stage, every actor stands on the same line.
  Offset standPoint(String id, {double height = 96}) {
    final rect = zoneRectById(id);
    final x = rect.isEmpty ? canvas.width / 2 : rect.center.dx;
    return Offset(x, floorLineY - height / 2);
  }

  /// Which zone is under a canvas point (top-most first), or null.
  RoomZone? zoneAt(Offset point) {
    for (final zone in RoomZones.all.reversed) {
      if (zoneRect(zone).contains(point)) return zone;
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is RoomLayout && other.canvas == canvas;

  @override
  int get hashCode => canvas.hashCode;
}
