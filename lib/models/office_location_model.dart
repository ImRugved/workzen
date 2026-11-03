/// Where the office is, stored in organization_details/office_location. Punch in,
/// punch out and breaks are only allowed within [radiusMeters] of this point.
class OfficeLocationModel {
  /// Radius used when the admin does not choose one.
  static const double defaultRadius = 20;

  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  const OfficeLocationModel({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.radiusMeters = defaultRadius,
  });

  /// Returns null when the document is missing or has no coordinates.
  static OfficeLocationModel? tryFromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final lat = json['latitude'];
    final lng = json['longitude'];
    if (lat is! num || lng is! num) return null;

    final radius = json['radiusMeters'];
    final address = json['address']?.toString().trim();
    return OfficeLocationModel(
      name: json['name']?.toString() ?? 'Office',
      address: address == null || address.isEmpty ? null : address,
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      radiusMeters: radius is num && radius > 0
          ? radius.toDouble()
          : defaultRadius,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radiusMeters,
  };
}
