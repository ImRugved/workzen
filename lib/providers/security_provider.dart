import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:workzen/utils/logger.dart';
import '../services/auth_security_service.dart';
import 'package:local_auth/local_auth.dart';

class SecurityProvider with ChangeNotifier {
  final AuthSecurityService _securityService = AuthSecurityService();

  bool _biometricEnabled = false;
  bool _hasAppUnlockPin = false;
  bool _isLoading = false;
  bool _isDeviceSupported = false;
  List<BiometricType> _availableBiometrics = [];

  bool get biometricEnabled => _biometricEnabled;
  bool get hasAppUnlockPin => _hasAppUnlockPin;
  bool get isLoading => _isLoading;
  bool get isDeviceSupported => _isDeviceSupported;
  List<BiometricType> get availableBiometrics => _availableBiometrics;

  // Initialize security settings
  Future<void> initializeSecurity(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Check device support
      _isDeviceSupported = await _securityService.isDeviceSupported();
      if (_isDeviceSupported) {
        _availableBiometrics = await _securityService.getAvailableBiometrics();
      }

      // Load security settings from Firestore
      final settings = await _securityService.getSecuritySettings(userId);
      if (settings != null) {
        _biometricEnabled = settings['biometricEnabled'] ?? false;
        _hasAppUnlockPin = settings['hasAppUnlockPin'] ?? false;
      }
    } catch (e) {
      logDebug('Error initializing security: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Toggle biometric enabled
  Future<bool> toggleBiometric(String userId, bool enabled) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _securityService.updateBiometricEnabled(
        userId,
        enabled,
      );
      if (success) {
        _biometricEnabled = enabled;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      logDebug('Error toggling biometric: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Setup App Unlock PIN (6 digits - mandatory)
  Future<bool> setupAppUnlockPIN(String userId, String pin) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _securityService.saveAppUnlockPIN(userId, pin);
      if (success) {
        _hasAppUnlockPin = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      logDebug('Error setting up app unlock PIN: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Verify App Unlock PIN
  Future<bool> verifyAppUnlockPIN(String userId, String pin) async {
    try {
      return await _securityService.verifyAppUnlockPIN(userId, pin);
    } catch (e) {
      logDebug('Error verifying app unlock PIN: $e');
      return false;
    }
  }

  // Check if app unlock PIN exists
  Future<bool> hasAppUnlockPIN(String userId) async {
    try {
      return await _securityService.hasAppUnlockPIN(userId);
    } catch (e) {
      logDebug('Error checking app unlock PIN: $e');
      return false;
    }
  }

  // Authenticate with biometrics
  Future<bool> authenticateWithBiometrics({
    String reason = 'Please authenticate to unlock the app',
  }) async {
    try {
      return await _securityService.authenticateWithBiometrics(reason: reason);
    } catch (e) {
      logDebug('Error authenticating with biometrics: $e');
      return false;
    }
  }

  // Check if lock is required (PIN is mandatory, so always true if user is logged in)
  Future<bool> isLockRequired(String userId) async {
    try {
      // App unlock PIN is mandatory, so always require lock (either PIN setup or unlock)
      return true;
    } catch (e) {
      logDebug('Error checking lock requirement: $e');
      return true; // Default to requiring lock
    }
  }
}
