import 'package:boso/zone.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _element({
  required int id,
  required String name,
  int? currentTemperature,
  int setTemperature = 210,
  String relayState = 'off',
  bool visibility = true,
}) => {
  'zone': {
    'id': id,
    'currentTemperature': currentTemperature,
    'setTemperature': setTemperature,
    'flags': {'relayState': relayState},
    'visibility': visibility,
  },
  'description': {'name': name},
  'mode': {'id': id + 100, 'parentId': id, 'mode': 'constantTemp'},
};

void main() {
  group('Zone.listFromModuleData', () {
    test('converts tenths of a degree and reads heating state', () {
      final zones = Zone.listFromModuleData({
        'zones': {
          'elements': [
            _element(
              id: 1,
              name: 'Salon',
              currentTemperature: 223,
              setTemperature: 215,
              relayState: 'on',
            ),
          ],
        },
      });

      final salon = zones.single;
      expect(salon.id, 1);
      expect(salon.modeId, 101);
      expect(salon.name, 'Salon');
      expect(salon.currentTemperature, 22.3);
      expect(salon.setTemperature, 21.5);
      expect(salon.isHeating, isTrue);
    });

    test('keeps zones without a sensor reading and skips hidden ones', () {
      final zones = Zone.listFromModuleData({
        'zones': {
          'elements': [
            _element(id: 1, name: 'Bathroom'),
            _element(id: 2, name: 'Hidden', visibility: false),
          ],
        },
      });

      expect(zones.map((z) => z.name), ['Bathroom']);
      expect(zones.single.currentTemperature, isNull);
      expect(zones.single.isHeating, isFalse);
    });

    test('returns no zones for a controller without a zones section', () {
      expect(Zone.listFromModuleData({'tiles': <dynamic>[]}), isEmpty);
    });
  });

  test('toTenths rounds instead of truncating float error', () {
    // 21.7 * 10 == 216.99999999999997 in floating point.
    expect(toTenths(21.7), 217);
  });

  group('stepTemperature', () {
    test('snaps an off-grid value to the nearest half degree first', () {
      expect(stepTemperature(21.9, up: true), 22.0);
      expect(stepTemperature(21.9, up: false), 21.5);
      expect(stepTemperature(21.1, up: true), 21.5);
      expect(stepTemperature(21.1, up: false), 21.0);
    });

    test('moves a whole half degree from an on-grid value', () {
      expect(stepTemperature(22.0, up: true), 22.5);
      expect(stepTemperature(22.0, up: false), 21.5);
      expect(stepTemperature(21.5, up: false), 21.0);
    });
  });
}
