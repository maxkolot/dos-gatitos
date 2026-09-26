import 'package:dos_gatitos/features/room/room_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two acceptance screens.
const _screens = <Size>[Size(390, 844), Size(430, 932)];

void main() {
  group('RoomLayout cover maths', () {
    for (final size in _screens) {
      test('$size: art covers the canvas without stretching', () {
        final layout = RoomLayout(canvas: size);
        final rect = layout.roomRect;
        expect(rect.width / RoomLayout.artSize.width, closeTo(rect.height / RoomLayout.artSize.height, 1e-9));
        expect(rect.width, greaterThanOrEqualTo(size.width - 0.01));
        expect(rect.height, greaterThanOrEqualTo(size.height - 0.01));
        // art ratio matches the screens, so barely any crop
        expect(rect.height - size.height, lessThan(size.height * 0.01));
        expect(rect.width - size.width, lessThan(size.width * 0.01));
      });

      test('$size: zones and floor line are on screen', () {
        final layout = RoomLayout(canvas: size);
        for (final zone in RoomZones.all) {
          final rect = layout.zoneRect(zone);
          expect(rect.left, greaterThanOrEqualTo(0), reason: zone.id);
          expect(rect.right, lessThanOrEqualTo(size.width + 0.01), reason: zone.id);
          expect(rect.top, greaterThan(layout.hudSafeArea.bottom), reason: zone.id);
          expect(rect.bottom, lessThanOrEqualTo(size.height + 0.01), reason: zone.id);
        }
        expect(layout.floorLineY, inInclusiveRange(layout.hudSafeArea.bottom, size.height));
        expect(layout.zoneRectById('sofa').center.dy, lessThan(layout.floorLineY));
      });

      test('$size: characters stand on the floor line inside their zone', () {
        final layout = RoomLayout(canvas: size);
        for (final id in ['sofa', 'table', 'window', 'music']) {
          final feet = layout.standPoint(id, height: 96);
          expect(feet.dx, inInclusiveRange(0, size.width), reason: id);
          expect(feet.dy + 48, closeTo(layout.floorLineY, 0.01), reason: id);
        }
      });
    }

    test('zoneAt finds the hotspot under a point', () {
      final layout = RoomLayout(canvas: _screens.last);
      expect(layout.zoneAt(layout.zoneRectById('music').center)?.id, 'music');
      expect(layout.zoneAt(const Offset(0, 0)), isNull);
    });
  });
}
