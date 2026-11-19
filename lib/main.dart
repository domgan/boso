import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import 'emodul_client.dart';
import 'screens/modules_screen.dart';
import 'strings.dart';

/// Baked in at build time: `--dart-define-from-file=secrets.json`.
const _token = String.fromEnvironment('EMODUL_TOKEN');

void main() => runApp(BosoApp(home: _home()));

Widget _home() {
  try {
    return ModulesScreen(client: EmodulClient(http.Client(), _token));
  } on FormatException catch (e) {
    return _BuildConfigError(e.message);
  }
}

class BosoApp extends StatelessWidget {
  const BosoApp({super.key, required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    const seed = Colors.deepOrange;
    return MaterialApp(
      title: 'boso',
      theme: ThemeData(colorSchemeSeed: seed),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark),
      home: home,
    );
  }
}

class _BuildConfigError extends StatelessWidget {
  const _BuildConfigError(this.reason);

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            Strings.buildConfigError(reason),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
