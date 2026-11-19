import 'dart:convert';

import 'package:boso/emodul_client.dart';
import 'package:boso/module.dart';
import 'package:boso/screens/zones_screen.dart';
import 'package:boso/strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes.dart';

const _module = Module(udid: 'abc', name: 'L-4X WiFi');

final _salon = {
  'zones': {
    'elements': [
      {
        'zone': {
          'id': 101,
          'currentTemperature': 223,
          'setTemperature': 219,
          'flags': {'relayState': 'off'},
          'visibility': true,
        },
        'description': {'name': 'Salon'},
        'mode': {'id': 210},
      },
    ],
  },
};

/// Pumps the zones screen against a fake eModul that serves [_salon] and
/// records every temperature change posted to it.
Future<List<Map<String, dynamic>>> _pumpScreen(
  WidgetTester tester, {
  int postStatus = 200,
}) async {
  final posted = <Map<String, dynamic>>[];
  final client = EmodulClient(
    MockClient((request) async {
      if (request.method == 'GET') return jsonResponse(_salon);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      posted.add(body['mode'] as Map<String, dynamic>);
      return postStatus == 200
          ? jsonResponse({'id': 210})
          : http.Response('oops', postStatus);
    }),
    validToken,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: ZonesScreen(client: client, module: _module),
    ),
  );
  await tester.pumpAndSettle();
  return posted;
}

Future<void> _tapIncrease(WidgetTester tester) async {
  await tester.tap(find.byTooltip(Strings.increase('Salon')));
  await tester.pump();
}

bool _isSelected(WidgetTester tester, String label) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label)).selected;

void main() {
  testWidgets('taps are batched into one permanent change after the delay', (
    tester,
  ) async {
    final posted = await _pumpScreen(tester);

    await _tapIncrease(tester);
    await _tapIncrease(tester);

    expect(find.text('22,5°C'), findsOneWidget);
    expect(_isSelected(tester, Strings.permanent), isTrue);
    expect(posted, isEmpty);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(posted, hasLength(1));
    expect(posted.single['setTemperature'], 225);
    expect(posted.single['mode'], 'constantTemp');
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('picking a duration keeps the chips open and sends it later', (
    tester,
  ) async {
    final posted = await _pumpScreen(tester);

    await _tapIncrease(tester);
    await tester.tap(find.text(Strings.hours(4)));
    await tester.pump();

    expect(_isSelected(tester, Strings.hours(4)), isTrue);
    expect(_isSelected(tester, Strings.permanent), isFalse);
    expect(posted, isEmpty);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(posted.single['mode'], 'timeLimit');
    expect(posted.single['constTempTime'], 240);
    expect(posted.single['setTemperature'], 220);
  });

  testWidgets('a failed change restores the previous temperature', (
    tester,
  ) async {
    await _pumpScreen(tester, postStatus: 500);

    await _tapIncrease(tester);
    expect(find.text('22,0°C'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('21,9°C'), findsOneWidget);
    expect(
      find.text(Strings.changeFailed('Salon', Strings.serverError(500))),
      findsOneWidget,
    );
  });
}
