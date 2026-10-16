import 'package:cloud_firestore/cloud_firestore.dart';

/// The phone an account is bound to (users/{uid}/security/settings.deviceInfo).
class DeviceInfoModel {
  final String? deviceId;
  final String platform;
  final String manufacturer;
  final String model;
  final String osVersion;
  final DateTime? registeredAt;

  const DeviceInfoModel({
    required this.deviceId,
    this.platform = '',
    this.manufacturer = '',
    this.model = '',
    this.osVersion = '',
    this.registeredAt,
  });

  factory DeviceInfoModel.fromJson(Map<String, dynamic> json) {
    final registered = json['registeredAt'];
    return DeviceInfoModel(
      deviceId: json['deviceId'] as String?,
      platform: (json['platform'] ?? '').toString(),
      manufacturer: (json['manufacturer'] ?? '').toString(),
      model: (json['model'] ?? '').toString(),
      osVersion: (json['osVersion'] ?? '').toString(),
      registeredAt: registered is Timestamp ? registered.toDate() : null,
    );
  }

  /// "samsung SM-A546E"
  String get displayName => '$manufacturer $model'.trim();

  /// "android 14"
  String get displayOs => '$platform $osVersion'.trim();
}

/// users/{uid}/security/settings: app-unlock PIN, biometric flag and the
/// registered device.
class SecuritySettingsModel {
  final String? appUnlockPin;
  final bool hasAppUnlockPin;
  final bool biometricEnabled;
  final DeviceInfoModel? deviceInfo;

  const SecuritySettingsModel({
    this.appUnlockPin,
    this.hasAppUnlockPin = false,
    this.biometricEnabled = false,
    this.deviceInfo,
  });

  factory SecuritySettingsModel.fromJson(Map<String, dynamic> json) {
    final device = json['deviceInfo'];
    return SecuritySettingsModel(
      appUnlockPin: json['appUnlockPin'] as String?,
      hasAppUnlockPin: json['hasAppUnlockPin'] == true,
      biometricEnabled: json['biometricEnabled'] == true,
      deviceInfo: device is Map
          ? DeviceInfoModel.fromJson(Map<String, dynamic>.from(device))
          : null,
    );
  }
}
