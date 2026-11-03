import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:workzen/constants/firestore_constants.dart';
import 'package:workzen/utils/logger.dart';

/// Reads the identity of the phone the app is running on. Used to bind an
/// employee account to one device for attendance.
class DeviceService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // Why the phone's details could not be read the last time, for messages
  String? _lastReadError;

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
      _lastReadError = '$e';
    }

    return {FirestoreFields.deviceId: null};
  }

  Future<String?> getDeviceId() async {
    final info = await getDeviceInfo();
    return info[FirestoreFields.deviceId] as String?;
  }

  DocumentReference<Map<String, dynamic>> _securityDoc(String uid) =>
      FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection(FirestoreSubCollections.security)
          .doc(FirestoreDocs.securitySettings);

  /// True when [uid] already has a phone saved in users/{uid}/security/settings.
  Future<bool> hasRegisteredDevice(String uid) async {
    try {
      final snapshot = await _securityDoc(uid).get();
      final device = snapshot.data()?[FirestoreFields.deviceInfo];
      return device is Map && device[FirestoreFields.deviceId] != null;
    } catch (e) {
      logDebug('Error reading registered device: $e');
      return false;
    }
  }

  /// Binds [uid] to this phone: sets isFirstLogin and saves the device details
  /// in one batch, so the two can never disagree. Returns null on success, or a
  /// short reason it could not be done.
  Future<String?> registerDevice(String uid) async {
    final info = await getDeviceInfo();
    logDebug('Registering device for $uid: $info');
    if (info[FirestoreFields.deviceId] == null) {
      return 'Unable to read this phone\'s ID. ${_lastReadError ?? 'Please try again.'}';
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      batch.update(firestore.collection(FirestoreCollections.users).doc(uid), {
        FirestoreFields.isFirstLogin: true,
      });
      batch.set(_securityDoc(uid), {
        FirestoreFields.deviceInfo: {
          ...info,
          'registeredAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await batch.commit();
      logDebug('Device registered for user $uid');
      return null;
    } catch (e) {
      logDebug('Error registering device: $e');
      // The reason is included: release builds print no logs
      return 'Could not register your device: $e';
    }
  }
}
