import 'package:material_ui/material_ui.dart';

import '../emodul_client.dart';
import '../module.dart';
import '../strings.dart';
import '../widgets/error_view.dart';
import 'zones_screen.dart';

/// Loads the account's controllers. With exactly one (the usual case) it goes
/// straight to that controller's zones; otherwise the user picks one.
class ModulesScreen extends StatefulWidget {
  const ModulesScreen({super.key, required this.client});

  final EmodulClient client;

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  List<Module>? _modules;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final modules = await widget.client.fetchModules();
      if (!mounted) return;
      setState(() => _modules = modules);
    } on EmodulException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  void _retry() {
    setState(() => _error = null);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final modules = _modules;
    if (modules != null && modules.length == 1) {
      return ZonesScreen(client: widget.client, module: modules.single);
    }
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.pickController)),
      body: _buildBody(modules),
    );
  }

  Widget _buildBody(List<Module>? modules) {
    if (_error != null) return ErrorView(message: _error!, onRetry: _retry);
    if (modules == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (modules.isEmpty) {
      return const Center(child: Text(Strings.noControllers));
    }
    return ListView(
      children: [
        for (final module in modules)
          ListTile(
            title: Text(module.name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    ZonesScreen(client: widget.client, module: module),
              ),
            ),
          ),
      ],
    );
  }
}
