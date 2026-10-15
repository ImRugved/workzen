import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:workzen/constants/firestore_constants.dart';
import 'package:workzen/utils/logger.dart';

/// Reads the identity of the phone the app is running on. Used to bind an
/// employee account to one device for attendance.
class DeviceService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Returns deviceId, platform, manufacturer, model and osVersion.
  /// deviceId is null when it cannot be read (unsupported platform).
  Future<Map<String, dynamic>> getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        final androidId = await const AndroidId().getId();
        return {
          FirestoreFields.deviceId: androidId,
          'platform': 'android',
          'manufacturer': info.manufacturer,
          'model': info.model,
          'osVersion': info.version.release,
        };
      }

      if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return {
          FirestoreFields.deviceId: info.identifierForVendor,
          'platform': 'ios',
          'manufacturer': 'Apple',
          'model': info.utsname.machine,
          'osVersion': info.systemVersion,
        };
      }
    } catch (e) {
      logDebug('Error reading device info: $e');
    }

    return {FirestoreFields.deviceId: null};
  }

  Future<String?> getDeviceId() async {
    final info = await getDeviceInfo();
    return info[FirestoreFields.deviceId] as String?;
  }
}
