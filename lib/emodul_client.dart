import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'module.dart';
import 'zone.dart';
import 'strings.dart';

class EmodulException implements Exception {
  const EmodulException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Client for the eModul cloud API (see `api/emodul.yaml`), authenticated
/// with an API token generated on emodul.pl.
class EmodulClient {
  /// Throws [FormatException] if [token] isn't a JWT carrying `user_id`.
  EmodulClient(this._http, this._token) : _userId = _userIdFromToken(_token);

  static final _api = Uri.parse('https://emodul.eu/api/v1/');
  static const _timeout = Duration(seconds: 15);

  final http.Client _http;
  final String _token;
  final int _userId;

  Future<List<Module>> fetchModules() async {
    final json = await _send('GET', 'modules');
    return _parse(
      () => (json as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(Module.fromJson)
          .toList(),
    );
  }

  Future<List<Zone>> fetchZones(String moduleUdid) async {
    final json = await _send('GET', 'modules/$moduleUdid');
    return _parse(() => Zone.listFromModuleData(json as Map<String, dynamic>));
  }

  /// Overrides the zone's schedule with [celsius]: for [duration] if given,
  /// after which the zone returns to its schedule, otherwise permanently.
  Future<void> setZoneTemperature(
    String moduleUdid,
    Zone zone,
    double celsius, {
    Duration? duration,
  }) async {
    await _send(
      'POST',
      'modules/$moduleUdid/zones',
      body: {
        'mode': {
          'id': zone.modeId,
          'parentId': zone.id,
          'mode': duration == null ? 'constantTemp' : 'timeLimit',
          'constTempTime': duration?.inMinutes ?? 0,
          'setTemperature': toTenths(celsius),
          'scheduleIndex': 0,
        },
      },
    );
  }

  /// Sends a request under `users/{user_id}/` and decodes the JSON response.
  Future<Object?> _send(String method, String userPath, {Object? body}) async {
    final request = http.Request(
      method,
      _api.resolve('users/$_userId/$userPath'),
    )..headers['Authorization'] = 'Bearer $_token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      final streamed = await _http.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed).timeout(_timeout);
    } on TimeoutException {
      throw const EmodulException(Strings.serverTimeout);
    } on http.ClientException catch (e) {
      throw EmodulException(Strings.connectionFailed(e.message));
    }

    if (response.statusCode == 401) {
      throw const EmodulException(Strings.tokenRevoked);
    }
    if (response.statusCode >= 300) {
      throw EmodulException(Strings.serverError(response.statusCode));
    }
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const EmodulException(Strings.unreadableResponse);
    }
  }
}

/// A response that doesn't match the spec becomes an [EmodulException] the
/// screens show, instead of an uncaught error that leaves them loading forever.
T _parse<T>(T Function() parse) {
  try {
    return parse();
  } on TypeError {
    throw const EmodulException(Strings.unexpectedData);
  } on NoSuchMethodError {
    throw const EmodulException(Strings.unexpectedData);
  }
}

int _userIdFromToken(String token) {
  if (token.isEmpty) throw const FormatException(Strings.tokenMissing);
  final parts = token.split('.');
  if (parts.length != 3) throw const FormatException(Strings.tokenNotJwt);
  final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
  final userId = (jsonDecode(payload) as Map<String, dynamic>)['user_id'];
  if (userId is! int) throw const FormatException(Strings.tokenWithoutUserId);
  return userId;
}
