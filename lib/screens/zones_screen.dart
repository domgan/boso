import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../emodul_client.dart';
import '../module.dart';
import '../strings.dart';
import '../widgets/error_view.dart';
import '../zone.dart';

const _minTemperature = 5.0;
const _maxTemperature = 35.0;

/// Sends this long after the last tap on −/+ or a duration chip, so five taps
/// on "+" become one request and there's time to pick a duration.
const _sendDelay = Duration(seconds: 3);

/// Null means permanent ([Strings.permanent]).
const _durations = <Duration?>[
  null,
  Duration(hours: 1),
  Duration(hours: 2),
  Duration(hours: 4),
  Duration(hours: 8),
];

typedef _PendingChange = ({
  Timer timer,
  double target,
  double previous,
  Duration? duration,
});

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

  void _changeTemperature(Zone zone, {required bool up}) {
    final target = stepTemperature(
      zone.setTemperature,
      up: up,
    ).clamp(_minTemperature, _maxTemperature).toDouble();
    if (target == zone.setTemperature) return;

    final existing = _pending[zone.id];
    setState(() {
      _schedule(
        zone.id,
        target: target,
        previous: existing?.previous ?? zone.setTemperature,
        duration: existing?.duration,
      );
      _replaceZone(zone.copyWith(setTemperature: target));
    });
  }

  void _pickDuration(int zoneId, Duration? duration) {
    final existing = _pending[zoneId];
    if (existing == null) return;
    setState(
      () => _schedule(
        zoneId,
        target: existing.target,
        previous: existing.previous,
        duration: duration,
      ),
    );
  }

  /// Replaces the zone's pending change and restarts its send countdown.
  void _schedule(
    int zoneId, {
    required double target,
    required double previous,
    required Duration? duration,
  }) {
    _pending[zoneId]?.timer.cancel();
    _pending[zoneId] = (
      timer: Timer(_sendDelay, () => _send(zoneId)),
      target: target,
      previous: previous,
      duration: duration,
    );
  }

  Future<void> _send(int zoneId) async {
    final change = _pending[zoneId];
    if (change == null) return;
    setState(() => _pending.remove(zoneId));
    final zone = _zones!.firstWhere((z) => z.id == zoneId);
    try {
      await widget.client.setZoneTemperature(
        widget.module.udid,
        zone,
        change.target,
        duration: change.duration,
      );
    } on EmodulException catch (e) {
      if (!mounted) return;
      // A newer tap already replaced this target; don't undo it.
      if (!_pending.containsKey(zoneId)) {
        setState(
          () => _replaceZone(zone.copyWith(setTemperature: change.previous)),
        );
      }
      _showSnackBar(Strings.changeFailed(zone.name, e.message));
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
              child: Center(child: Text(Strings.noZones)),
            ),
          for (final zone in zones)
            _ZoneCard(
              zone: zone,
              onDecrease: zone.setTemperature > _minTemperature
                  ? () => _changeTemperature(zone, up: false)
                  : null,
              onIncrease: zone.setTemperature < _maxTemperature
                  ? () => _changeTemperature(zone, up: true)
                  : null,
              pending: _pending[zone.id],
              onPickDuration: (duration) => _pickDuration(zone.id, duration),
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
    required this.pending,
    required this.onPickDuration,
  });

  final Zone zone;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  /// The change waiting to be sent; the duration chips show while it exists.
  final _PendingChange? pending;
  final void Function(Duration? duration) onPickDuration;

  @override
  Widget build(BuildContext context) {
    final pending = this.pending;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTemperatureRow(context),
            if (pending != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final duration in _durations)
                    ChoiceChip(
                      label: Text(
                        duration == null
                            ? Strings.permanent
                            : Strings.hours(duration.inHours),
                      ),
                      selected: duration == pending.duration,
                      onSelected: (_) => onPickDuration(duration),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTemperatureRow(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final current = zone.currentTemperature;
    return Row(
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
                        ? Strings.noReading
                        : Strings.now(_formatCelsius(current)),
                  ),
                  if (zone.isHeating) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.local_fire_department,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                      semanticLabel: Strings.heating,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: Strings.decrease(zone.name),
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
          tooltip: Strings.increase(zone.name),
          icon: const Icon(Icons.add),
          onPressed: onIncrease,
        ),
      ],
    );
  }
}

String _formatCelsius(double celsius) =>
    '${celsius.toStringAsFixed(1).replaceAll('.', ',')}°C';
