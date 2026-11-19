import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'module.dart';
import 'zone.dart';

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
    final json = await _send('GET', 'modules') as List<dynamic>;
    return json.cast<Map<String, dynamic>>().map(Module.fromJson).toList();
  }

  Future<List<Zone>> fetchZones(String moduleUdid) async {
    final json = await _send('GET', 'modules/$moduleUdid');
    return Zone.listFromModuleData(json as Map<String, dynamic>);
  }

  /// Sets a constant temperature, which overrides the zone's schedule.
  Future<void> setZoneTemperature(
    String moduleUdid,
    Zone zone,
    double celsius,
  ) async {
    await _send(
      'POST',
      'modules/$moduleUdid/zones',
      body: {
        'mode': {
          'id': zone.modeId,
          'parentId': zone.id,
          'mode': 'constantTemp',
          'constTempTime': 0,
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
      throw const EmodulException('Serwer eModul nie odpowiada');
    } on http.ClientException catch (e) {
      throw EmodulException('Brak połączenia z eModul (${e.message})');
    }

    if (response.statusCode == 401) {
      throw const EmodulException(
        'Token API jest nieważny. Wygeneruj nowy na emodul.pl i zbuduj apkę ponownie.',
      );
    }
    if (response.statusCode >= 300) {
      throw EmodulException('eModul zwrócił błąd ${response.statusCode}');
    }
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const EmodulException('Niezrozumiała odpowiedź z eModul');
    }
  }
}

int _userIdFromToken(String token) {
  if (token.isEmpty) throw const FormatException('Brak tokena API');
  final parts = token.split('.');
  if (parts.length != 3) throw const FormatException('Token API nie jest JWT');
  final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
  final userId = (jsonDecode(payload) as Map<String, dynamic>)['user_id'];
  if (userId is! int) throw const FormatException('Token API bez user_id');
  return userId;
}
