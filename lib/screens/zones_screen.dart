import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../emodul_client.dart';
import '../module.dart';
import '../widgets/error_view.dart';
import '../zone.dart';

const _step = 0.5;
const _minTemperature = 5.0;
const _maxTemperature = 35.0;

/// Waits for the user to stop tapping before sending, so five taps on "+"
/// become one request instead of five.
const _sendDelay = Duration(seconds: 1);

typedef _PendingChange = ({Timer timer, double target, double previous});

class ZonesScreen extends StatefulWidget {
  const ZonesScreen({super.key, required this.client, required this.module});

  final EmodulClient client;
  final Module module;

  @override
  State<ZonesScreen> createState() => _ZonesScreenState();
}

class _ZonesScreenState extends State<ZonesScreen> {
  List<Zone>? _zones;
  String? _error;
  final Map<int, _PendingChange> _pending = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final change in _pending.values) {
      change.timer.cancel();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final zones = await widget.client.fetchZones(widget.module.udid);
      if (!mounted) return;
      setState(() {
        _error = null;
        // Keep showing targets the user picked but that aren't sent yet.
        _zones = [
          for (final zone in zones)
            _pending[zone.id] == null
                ? zone
                : zone.copyWith(setTemperature: _pending[zone.id]!.target),
        ];
      });
    } on EmodulException catch (e) {
      if (!mounted) return;
      if (_zones == null) {
        setState(() => _error = e.message);
      } else {
        _showSnackBar(e.message);
      }
    }
  }

  void _retry() {
    setState(() => _error = null);
    _load();
  }

  void _changeTemperature(Zone zone, double delta) {
    final target = (zone.setTemperature + delta)
        .clamp(_minTemperature, _maxTemperature)
        .toDouble();
    if (target == zone.setTemperature) return;

    final existing = _pending[zone.id];
    existing?.timer.cancel();
    _pending[zone.id] = (
      timer: Timer(_sendDelay, () => _send(zone.id)),
      target: target,
      previous: existing?.previous ?? zone.setTemperature,
    );
    setState(() => _replaceZone(zone.copyWith(setTemperature: target)));
  }

  Future<void> _send(int zoneId) async {
    final change = _pending.remove(zoneId);
    if (change == null) return;
    final zone = _zones!.firstWhere((z) => z.id == zoneId);
    try {
      await widget.client.setZoneTemperature(
        widget.module.udid,
        zone,
        change.target,
      );
    } on EmodulException catch (e) {
      if (!mounted) return;
      // A newer tap already replaced this target; don't undo it.
      if (!_pending.containsKey(zoneId)) {
        setState(
          () => _replaceZone(zone.copyWith(setTemperature: change.previous)),
        );
      }
      _showSnackBar(
        '${zone.name}: nie udało się ustawić temperatury. ${e.message}',
      );
    }
  }

  void _replaceZone(Zone updated) {
    _zones = [
      for (final zone in _zones!) zone.id == updated.id ? updated : zone,
    ];
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.module.name)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final zones = _zones;
    if (_error != null) return ErrorView(message: _error!, onRetry: _retry);
    if (zones == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (zones.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Brak stref w tym sterowniku')),
            ),
          for (final zone in zones)
            _ZoneCard(
              zone: zone,
              onDecrease: zone.setTemperature > _minTemperature
                  ? () => _changeTemperature(zone, -_step)
                  : null,
              onIncrease: zone.setTemperature < _maxTemperature
                  ? () => _changeTemperature(zone, _step)
                  : null,
            ),
        ],
      ),
    );
  }
}

class _ZoneCard extends StatelessWidget {
  const _ZoneCard({
    required this.zone,
    required this.onDecrease,
    required this.onIncrease,
  });

  final Zone zone;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final current = zone.currentTemperature;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(zone.name, style: textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        current == null
                            ? 'Brak odczytu'
                            : 'Teraz ${_formatCelsius(current)}',
                      ),
                      if (zone.isHeating) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.local_fire_department,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                          semanticLabel: 'Grzeje',
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Obniż temperaturę: ${zone.name}',
              icon: const Icon(Icons.remove),
              onPressed: onDecrease,
            ),
            SizedBox(
              width: 80,
              child: Text(
                _formatCelsius(zone.setTemperature),
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall,
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Podnieś temperaturę: ${zone.name}',
              icon: const Icon(Icons.add),
              onPressed: onIncrease,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatCelsius(double celsius) =>
    '${celsius.toStringAsFixed(1).replaceAll('.', ',')}°C';
