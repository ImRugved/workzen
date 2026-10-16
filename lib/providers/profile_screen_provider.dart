import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../models/personal_info_model.dart';
import '../services/supabase_service.dart';
import '../utils/logger.dart';
import 'auth_provider.dart';

/// State of the profile screen: image upload, edit mode of the personal
/// details and logout progress. The user data itself comes from
/// [AuthProvider]. Scoped to the screen.
class ProfileScreenProvider with ChangeNotifier {
  bool _isUploading = false;
  bool _isEditingPersonal = false;
  bool _isLoggingOut = false;
  bool _disposed = false;

  bool get isUploading => _isUploading;
  bool get isEditingPersonal => _isEditingPersonal;
  bool get isLoggingOut => _isLoggingOut;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void startEditing() {
    _isEditingPersonal = true;
    _notify();
  }

  void stopEditing() {
    _isEditingPersonal = false;
    _notify();
  }

  /// Saves the personal details and leaves edit mode on success. Returns an
  /// error message, or null on success.
  Future<String?> savePersonalInfo(
    AuthProvider auth,
    PersonalInfoModel info,
  ) async {
    final error = await auth.updatePersonalInfo(info);
    if (error == null) stopEditing();
    return error;
  }

  /// Uploads a new profile picture and refreshes the user. Returns an error
  /// message, or null on success.
  Future<String?> uploadProfileImage(AuthProvider auth, Uint8List bytes) async {
    final userId = auth.user?.uid;
    if (userId == null) return 'You are not logged in';

    _isUploading = true;
    _notify();
    try {
      final imageUrl = await SupabaseService.uploadProfileImage(userId, bytes);
      if (imageUrl.isEmpty) {
        return 'Failed to upload image. Please try again.';
      }

      // Give Firestore a moment, then reload the user for the new image URL
      await Future.delayed(const Duration(milliseconds: 500));
      await auth.refreshUserData();
      return null;
    } catch (e) {
      logDebug('Error uploading profile image: $e');
      return 'Upload error: $e';
    } finally {
      _isUploading = false;
      _notify();
    }
  }

  /// Logs out; returns an error message, or null on success.
  Future<String?> logout(AuthProvider auth) async {
    _isLoggingOut = true;
    _notify();
    try {
      await auth.logout();
      return null;
    } catch (e) {
      logDebug('Logout error: $e');
      _isLoggingOut = false;
      _notify();
      return 'Logout failed: $e';
    }
  }
}
