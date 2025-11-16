import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart';
import '../app_constants.dart';

class AuthSecurityService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check if device supports biometric authentication
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      log('Error checking device support: $e');
      return false;
    }
  }

  // Check available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      log('Error getting available biometrics: $e');
      return [];
    }
  }

  // Check if biometrics are available
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      log('Error checking biometrics: $e');
      return false;
    }
  }

  // Authenticate with biometrics
  Future<bool> authenticateWithBiometrics({
    String reason = 'Please authenticate to continue',
    bool biometricOnly = false,
  }) async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: true,
        ),
      );
      return didAuthenticate;
    } catch (e) {
      log('Error authenticating with biometrics: $e');
      // Check error type and handle accordingly
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('no biometric hardware') ||
          errorString.contains('notavailable')) {
        log('No biometric hardware available');
      } else if (errorString.contains('lockout') ||
          errorString.contains('temporarily locked')) {
        log('Biometric temporarily locked out');
      } else if (errorString.contains('cancel') ||
          errorString.contains('user canceled')) {
        log('User canceled authentication');
      }
      return false;
    }
  }

  // Get security settings from Firestore
  Future<Map<String, dynamic>?> getSecuritySettings(String userId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection('security')
          .doc('settings')
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      log('Error getting security settings: $e');
      return null;
    }
  }

  // Save security settings to Firestore
  Future<bool> saveSecuritySettings(
    String userId,
    Map<String, dynamic> settings,
  ) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection('security')
          .doc('settings')
          .set(settings, SetOptions(merge: true));
      return true;
    } catch (e) {
      log('Error saving security settings: $e');
      return false;
    }
  }

  // Update biometric enabled status
  Future<bool> updateBiometricEnabled(String userId, bool enabled) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection('security')
          .doc('settings')
          .set({
            'biometricEnabled': enabled,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      return true;
    } catch (e) {
      log('Error updating biometric enabled: $e');
      return false;
    }
  }

  // Save App Unlock PIN (6 digits - mandatory)
  Future<bool> saveAppUnlockPIN(String userId, String pin) async {
    try {
      // In production, PIN should be hashed before storing
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection('security')
          .doc('settings')
          .set({
            'appUnlockPin': pin,
            'hasAppUnlockPin': true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      return true;
    } catch (e) {
      log('Error saving app unlock PIN: $e');
      return false;
    }
  }

  // Verify App Unlock PIN
  Future<bool> verifyAppUnlockPIN(String userId, String pin) async {
    try {
      final settings = await getSecuritySettings(userId);
      if (settings != null && settings['appUnlockPin'] == pin) {
        return true;
      }
      return false;
    } catch (e) {
      log('Error verifying app unlock PIN: $e');
      return false;
    }
  }

  // Check if app unlock PIN exists
  Future<bool> hasAppUnlockPIN(String userId) async {
    try {
      final settings = await getSecuritySettings(userId);
      return settings != null && (settings['hasAppUnlockPin'] == true);
    } catch (e) {
      log('Error checking app unlock PIN: $e');
      return false;
    }
  }

  // Get biometric type name
  String getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.iris:
        return 'Iris';
      case BiometricType.strong:
        return 'Strong Biometric';
      case BiometricType.weak:
        return 'Weak Biometric';
    }
  }
}
