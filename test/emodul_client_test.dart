import 'dart:convert';

import 'package:boso/emodul_client.dart';
import 'package:boso/strings.dart';
import 'package:boso/zone.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes.dart';

const _zone = Zone(
  id: 101,
  modeId: 210,
  name: 'Salon',
  currentTemperature: 22.3,
  setTemperature: 21,
  isHeating: false,
);

void main() {
  test(
    'requests go to the user from the token, with the token as Bearer',
    () async {
      final client = EmodulClient(
        MockClient((request) async {
          expect(request.url.path, '/api/v1/users/42/modules');
          expect(request.headers['Authorization'], 'Bearer $validToken');
          return jsonResponse([
            {'udid': 'abc', 'name': 'L-4X WiFi', 'type': 'zones_controller'},
          ]);
        }),
        validToken,
      );

      final modules = await client.fetchModules();

      expect(modules.single.udid, 'abc');
      expect(modules.single.name, 'L-4X WiFi');
    },
  );

  test('rejects tokens that are missing, not a JWT, or lack user_id', () {
    final httpClient = MockClient((_) async => jsonResponse({}));
    for (final token in [
      '',
      'not-a-jwt',
      fakeToken({'username': 'jan'}),
    ]) {
      expect(
        () => EmodulClient(httpClient, token),
        throwsFormatException,
        reason: token,
      );
    }
  });

  test('setZoneTemperature posts a constant temperature in tenths', () async {
    late http.Request sent;
    final client = EmodulClient(
      MockClient((request) async {
        sent = request;
        return jsonResponse({'id': 210});
      }),
      validToken,
    );

    await client.setZoneTemperature('abc', _zone, 21.5);

    expect(sent.method, 'POST');
    expect(sent.url.path, '/api/v1/users/42/modules/abc/zones');
    expect(jsonDecode(sent.body), {
      'mode': {
        'id': 210,
        'parentId': 101,
        'mode': 'constantTemp',
        'constTempTime': 0,
        'setTemperature': 215,
        'scheduleIndex': 0,
      },
    });
  });

  test(
    'setZoneTemperature with a duration posts timeLimit in minutes',
    () async {
      late http.Request sent;
      final client = EmodulClient(
        MockClient((request) async {
          sent = request;
          return jsonResponse({'id': 210});
        }),
        validToken,
      );

      await client.setZoneTemperature(
        'abc',
        _zone,
        25,
        duration: const Duration(hours: 4),
      );

      final mode = (jsonDecode(sent.body) as Map<String, dynamic>)['mode'];
      expect(mode['mode'], 'timeLimit');
      expect(mode['constTempTime'], 240);
      expect(mode['setTemperature'], 250);
    },
  );

  test(
    'zone data that does not match the spec becomes EmodulException',
    () async {
      final client = EmodulClient(
        MockClient(
          (_) async => jsonResponse({
            'zones': {
              'elements': [
                {'zone': null},
              ],
            },
          }),
        ),
        validToken,
      );

      await expectLater(
        client.fetchZones('abc'),
        throwsA(isA<EmodulException>()),
      );
    },
  );

  test(
    'revoked token surfaces as an EmodulException about the token',
    () async {
      final client = EmodulClient(
        MockClient((_) async => jsonResponse({'authenticated': false}, 401)),
        validToken,
      );

      await expectLater(
        client.fetchZones('abc'),
        throwsA(
          isA<EmodulException>().having(
            (e) => e.message,
            'message',
            Strings.tokenRevoked,
          ),
        ),
      );
    },
  );

  test(
    'server errors surface as EmodulException with the status code',
    () async {
      final client = EmodulClient(
        MockClient((_) async => http.Response('oops', 500)),
        validToken,
      );

      await expectLater(
        client.fetchModules(),
        throwsA(
          isA<EmodulException>().having(
            (e) => e.message,
            'message',
            contains('500'),
          ),
        ),
      );
    },
  );
}
