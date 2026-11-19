/// A heating zone (room) reported by eModul. Temperatures are in °C.
class Zone {
  const Zone({
    required this.id,
    required this.modeId,
    required this.name,
    required this.currentTemperature,
    required this.setTemperature,
    required this.isHeating,
  });

  final int id;
  final int modeId;
  final String name;

  /// Null when the room sensor isn't reporting.
  final double? currentTemperature;
  final double setTemperature;
  final bool isHeating;

  Zone copyWith({required double setTemperature}) => Zone(
    id: id,
    modeId: modeId,
    name: name,
    currentTemperature: currentTemperature,
    setTemperature: setTemperature,
    isHeating: isHeating,
  );

  /// Parses `zones.elements` from `GET /users/{id}/modules/{udid}`,
  /// skipping zones hidden in eModul.
  static List<Zone> listFromModuleData(Map<String, dynamic> moduleData) {
    final zones = moduleData['zones'] as Map<String, dynamic>?;
    final elements = zones?['elements'] as List<dynamic>? ?? const [];
    return elements
        .cast<Map<String, dynamic>>()
        .where((element) => element['zone']['visibility'] != false)
        .map(Zone._fromElement)
        .toList();
  }

  factory Zone._fromElement(Map<String, dynamic> element) {
    final zone = element['zone'] as Map<String, dynamic>;
    final current = zone['currentTemperature'] as int?;
    return Zone(
      id: zone['id'] as int,
      modeId: element['mode']['id'] as int,
      name: element['description']['name'] as String,
      currentTemperature: current == null ? null : current / 10,
      setTemperature: (zone['setTemperature'] as int) / 10,
      isHeating: zone['flags']['relayState'] == 'on',
    );
  }
}

/// eModul sends and expects temperatures in tenths of a degree.
int toTenths(double celsius) => (celsius * 10).round();
