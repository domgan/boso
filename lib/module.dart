/// A controller registered on the eModul account, e.g. an L-4X WiFi.
class Module {
  const Module({required this.udid, required this.name});

  factory Module.fromJson(Map<String, dynamic> json) =>
      Module(udid: json['udid'] as String, name: json['name'] as String);

  final String udid;
  final String name;
}
