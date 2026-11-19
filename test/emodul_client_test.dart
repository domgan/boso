import 'dart:convert';

import 'package:boso/emodul_client.dart';
import 'package:boso/zone.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Unsigned JWT shaped like the API tokens generated on emodul.pl.
String _token(Map<String, dynamic> payload) {
  String part(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part(payload)}.signature';
}

final _validToken = _token({'user_id': 42, 'is_generated': true, 'iat': 1});

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

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
          expect(request.headers['Authorization'], 'Bearer $_validToken');
          return _json([
            {'udid': 'abc', 'name': 'L-4X WiFi', 'type': 'zones_controller'},
          ]);
        }),
        _validToken,
      );

      final modules = await client.fetchModules();

      expect(modules.single.udid, 'abc');
      expect(modules.single.name, 'L-4X WiFi');
    },
  );

  test('rejects tokens that are missing, not a JWT, or lack user_id', () {
    final httpClient = MockClient((_) async => _json({}));
    for (final token in [
      '',
      'not-a-jwt',
      _token({'username': 'jan'}),
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
        return _json({'id': 210});
      }),
      _validToken,
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
    'revoked token surfaces as an EmodulException about the token',
    () async {
      final client = EmodulClient(
        MockClient((_) async => _json({'authenticated': false}, 401)),
        _validToken,
      );

      await expectLater(
        client.fetchZones('abc'),
        throwsA(
          isA<EmodulException>().having(
            (e) => e.message,
            'message',
            contains('Token API jest nieważny'),
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
        _validToken,
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
