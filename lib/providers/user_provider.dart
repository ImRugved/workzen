import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../app_constants.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  List<UserModel> _employees = [];

  bool get isLoading => _isLoading;
  List<UserModel> get employees => _employees;

  // Get all employees
  Future<List<UserModel>> getEmployees({bool silent = false}) async {
    try {
      _isLoading = true;
      if (!silent) notifyListeners();

      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('role', isEqualTo: AppConstants.employeeRole)
          .get();

      _employees =
          snapshot.docs.map((doc) => UserModel.fromJson(doc.data())).toList();

      _isLoading = false;
      if (!silent) notifyListeners();

      return _employees;
    } catch (e) {
      _isLoading = false;
      if (!silent) notifyListeners();
      print('Error getting employees: $e');
      return [];
    }
  }

  // Get employee by ID
  Future<UserModel?> getEmployeeById(String id) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(id)
          .get();

      if (doc.exists) {
        return UserModel.fromJson(doc.data()!);
      }

      return null;
    } catch (e) {
      print('Error getting employee by ID: $e');
      return null;
    }
  }

  // Get all admins
  Future<List<UserModel>> getAdmins() async {
    try {
      final snapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('role', isEqualTo: AppConstants.adminRole)
          .get();

      return snapshot.docs
          .map((doc) => UserModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting admins: $e');
      return [];
    }
  }

  // Update user FCM token
  Future<bool> updateUserFcmToken(String userId, String token) async {
    try {
      // Validate token
      if (token.isEmpty) {
        log('Cannot update FCM token: Token is empty');
        return false;
      }

      log('Updating FCM token for user $userId: $token');

      // Update in Firestore only
      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({'fcmToken': token});

      log('FCM token updated successfully in Firestore');
      return true;
    } catch (e) {
      log('Error updating FCM token: $e');
      return false;
    }
  }

  // Get user FCM token
  Future<String?> getUserFcmToken(String userId) async {
    try {
      log('Getting FCM token for user $userId');

      // Get from Firestore only
      final docSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();

      if (docSnapshot.exists && docSnapshot.data()!.containsKey('fcmToken')) {
        final token = docSnapshot.data()!['fcmToken'] as String;
        log('Found FCM token in Firestore: $token');
        return token;
      }

      log('FCM token not found for user $userId');
      return null;
    } catch (e) {
      log('Error getting FCM token: $e');
      return null;
    }
  }

  // Update user data
  Future<bool> updateUserData(String userId, Map<String, dynamic> data) async {
    try {
      _isLoading = true;
      notifyListeners();

      log('Updating user data for $userId');
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update(data);

      _isLoading = false;
      notifyListeners();

      log('User data updated successfully');
      return true;
    } catch (e) {
      log('Error updating user data: $e');
      return false;
    }
  }

  // Remove user FCM token (for logout)
  Future<bool> removeUserFcmToken(String userId) async {
    try {
      log('Removing FCM token for user $userId');

      // Remove from Firestore only
      await FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update({'fcmToken': FieldValue.delete()});

      log('FCM token removed successfully from Firestore');
      return true;
    } catch (e) {
      log('Error removing user FCM token: $e');
      return false;
    }
  }
}
