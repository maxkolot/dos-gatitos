import 'package:dos_gatitos/features/room/room_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two acceptance phones + a desktop browser window.
const _phones = <Size>[Size(390, 844), Size(430, 932)];
const _desktop = Size(1280, 720);

void main() {
  group('RoomLayout on phones (cover)', () {
    for (final size in _phones) {
      test('$size: art covers the canvas without stretching, sides cropped at most ~17%', () {
        final layout = RoomLayout(canvas: size);
        final rect = layout.roomRect;
        expect(rect.width / RoomLayout.artSize.width, closeTo(rect.height / RoomLayout.artSize.height, 1e-9));
        expect(rect.width, greaterThanOrEqualTo(size.width - 0.01));
        expect(rect.height, greaterThanOrEqualTo(size.height - 0.01));
        expect(rect.height - size.height, lessThan(size.height * 0.01), reason: 'no vertical crop');
        expect(-rect.left / rect.width, lessThan(0.17), reason: 'left crop');
      });

      test('$size: the furniture zones are on screen (the record player may be clipped)', () {
        final layout = RoomLayout(canvas: size);
        final screen = Offset.zero & size;
        for (final zone in RoomZones.all.where((z) => z.id != 'music')) {
          final rect = layout.zoneRect(zone);
          final visible = rect.intersect(screen);
          expect(visible.width / rect.width, greaterThan(0.6), reason: zone.id);
          expect(rect.top, greaterThan(layout.hudSafeArea.bottom), reason: zone.id);
          expect(rect.bottom, lessThanOrEqualTo(size.height + 0.01), reason: zone.id);
        }
        expect(layout.floorLineY, inInclusiveRange(layout.hudSafeArea.bottom, size.height));
        expect(layout.zoneRectById('sofa').center.dy, lessThan(layout.floorLineY));
      });

      test('$size: characters stand on the floor line, always on screen', () {
        final layout = RoomLayout(canvas: size);
        for (final id in ['sofa', 'table', 'window', 'music', 'plants']) {
          final feet = layout.standPoint(id, height: 96);
          expect(feet.dx, inInclusiveRange(size.width * 0.1, size.width * 0.9), reason: id);
          expect(feet.dy + 48, closeTo(layout.floorLineY, 0.01), reason: id);
        }
      });
    }
  });

  test('desktop: the height fits, so the floor stays on screen', () {
    final layout = RoomLayout(canvas: _desktop);
    expect(layout.roomRect.height, closeTo(_desktop.height, 0.01));
    expect(layout.roomRect.width, lessThan(_desktop.width));
    expect(layout.floorLineY, inInclusiveRange(0, _desktop.height));
  });

  test('zoneAt finds the hotspot under a point', () {
    final layout = RoomLayout(canvas: const Size(390, 844));
    final table = layout.zoneRectById('table');
    expect(layout.zoneAt(table.center)?.id, 'table');
    expect(layout.zoneAt(const Offset(5, 20)), isNull);
  });
}
