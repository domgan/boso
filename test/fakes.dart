import 'dart:convert';

import 'package:http/http.dart' as http;

/// Unsigned JWT shaped like the API tokens generated on emodul.pl.
String fakeToken(Map<String, dynamic> payload) {
  String part(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part(payload)}.signature';
}

final validToken = fakeToken({'user_id': 42, 'is_generated': true, 'iat': 1});

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);
