import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:workzen/utils/logger.dart';
import '../app_constants.dart';
import '../models/user_model.dart';
import 'user_provider.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GetStorage _storage = GetStorage();

  User? _user;
  UserModel? _userModel;
  bool _isLoading = false;

  User? get user => _user;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _userModel?.isAdmin ?? false;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    _user = _auth.currentUser;
    if (_user != null) {
      await _fetchUserData();
      await _updateFcmToken();
    }
  }

  Future<void> _fetchUserData() async {
    try {
      DocumentSnapshot userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(_user!.uid)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        logDebug("User data from Firestore - profileImageUrl: ${userData['profileImageUrl']}");
        logDebug("User data from Firestore - profileImageUrl type: ${userData['profileImageUrl'].runtimeType}");
        logDebug("User data from Firestore - all keys: ${userData.keys.toList()}");
        _userModel = UserModel.fromJson(userData);
        logDebug("User data fetched successfully: ${_userModel?.name}");
        logDebug("User role: ${_userModel?.isAdmin == true ? 'Admin' : _userModel?.isSubAdmin == true ? 'Sub Admin' : 'User'}");
        logDebug("UserModel - id: ${_userModel?.id}, email: ${_userModel?.email}, employeeId: ${_userModel?.employeeId}, department: ${_userModel?.department}, role: ${_userModel?.role}, isAdmin: ${_userModel?.isAdmin}, isSubAdmin: ${_userModel?.isSubAdmin}, officeLatitude: ${_userModel?.officeLatitude}, officeLongitude: ${_userModel?.officeLongitude}");
        logDebug("UserModel profileImageUrl after parsing: ${_userModel?.profileImageUrl}");
        logDebug("UserModel profileImageUrl type after parsing: ${_userModel?.profileImageUrl.runtimeType}");
      } else {
        logDebug("User document does not exist in Firestore");
      }
    } catch (e) {
      logDebug("Error fetching user data: $e");

      // Handle specific Firestore errors
      if (e.toString().contains('permission-denied')) {
        logDebug(
          'Permission denied for Firestore access - rules may need time to propagate',
        );
      } else if (e.toString().contains('not-found')) {
        logDebug('User document not found in Firestore');
      }
    }
  }

  // Public method to refresh user data
  Future<void> refreshUserData() async {
    if (_user != null) {
      logDebug("refreshUserData called for user: ${_user!.uid}");
      await _fetchUserData();
      logDebug("After _fetchUserData - _userModel profileImageUrl: ${_userModel?.profileImageUrl}");
      notifyListeners();
      logDebug("notifyListeners() called");
    } else {
      logDebug("refreshUserData called but _user is null");
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = result.user;
      await _fetchUserData();

      // Always get fresh FCM token after successful login
      await _getFreshFcmTokenAndUpdate();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      logDebug("Login error: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> signup(
    String name,
    String email,
    String password,
    String secretCode,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = result.user;

      // Get FCM token
      String fcmToken = _storage.read('fcmtoken') ?? '';

      // Generate employee ID for admin users
      String? employeeId;
      if (secretCode == AppConstants.adminCode) {
        final userProvider = UserProvider();
        employeeId = await userProvider.generateNextEmployeeId();
      }

      // Create user model
      UserModel newUser = UserModel(
        id: _user!.uid,
        name: name,
        email: email,
        fcmToken: fcmToken,
        isAdmin: secretCode == AppConstants.adminCode,
        employeeId: employeeId,
        department: secretCode == AppConstants.adminCode ? 'HR' : null,
        role: secretCode == AppConstants.adminCode ? 'admin' : 'employee',
        createdAt: DateTime.now(),
        userId: _user!.uid,
      );

      // Save to Firestore with error handling
      try {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(_user!.uid)
            .set(newUser.toJson());
        print('User data saved to Firestore successfully');
      } catch (firestoreError) {
        // logDebug("Firestore error during signup: $firestoreError");

        // Handle specific Firestore errors
        if (firestoreError.toString().contains('permission-denied')) {
          _isLoading = false;
          notifyListeners();
          return {
            'success': false,
            'error':
                'Database permissions not configured. Please contact the administrator to set up Firestore security rules.',
            'errorType': 'permission_denied',
          };
        } else if (firestoreError.toString().contains('does not exist') ||
            firestoreError.toString().contains('NOT_FOUND') ||
            firestoreError.toString().contains('not-found')) {
          _isLoading = false;
          notifyListeners();
          return {
            'success': false,
            'error':
                'Database not found. Please contact the administrator to create the Firestore database.',
            'errorType': 'database_not_found',
          };
        }

        // For other Firestore errors, still try to continue
        //logDebug('Continuing signup despite Firestore error');
      }

      // FCM token already saved to Firestore above
      // logDebug('FCM token saved for new user: ${_user!.uid}');

      _userModel = newUser;
      _isLoading = false;
      notifyListeners();
      return {'success': true, 'message': 'Account created successfully!'};
    } catch (e) {
      // logDebug("Signup error: $e");
      _isLoading = false;
      notifyListeners();

      // Handle specific Firebase Auth errors
      String errorMessage = 'Signup failed. Please try again.';
      if (e.toString().contains('email-already-in-use')) {
        errorMessage =
            'This email is already registered. Please use a different email.';
      } else if (e.toString().contains('weak-password')) {
        errorMessage =
            'Password is too weak. Please choose a stronger password.';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Invalid email address. Please check and try again.';
      }

      return {
        'success': false,
        'error': errorMessage,
        'errorType': 'auth_error',
      };
    }
  }

  Future<void> logout() async {
    try {
      if (_user != null) {
        // logDebug('Logging out user: ${_user!.uid}');

        // Only clear from local storage to force fresh token on next login
        await _storage.remove('fcmtoken');

        // Delete the FCM token from Firebase Messaging to ensure fresh token on next login
        try {
          await FirebaseMessaging.instance.deleteToken();
          //  logDebug('FCM token deleted from Firebase Messaging');
        } catch (e) {
          ////   logDebug('Error deleting FCM token from Firebase Messaging: $e');
        }

        // Keep the FCM token in Firestore and Realtime Database for the user
        //  logDebug('FCM token preserved in databases for user: ${_user!.uid}');
      }

      await _auth.signOut();
      _user = null;
      _userModel = null;
      notifyListeners();
      logDebug('User logged out successfully');
    } catch (e) {
      logDebug("Logout error: $e");
    }
  }

  Future<void> _updateFcmToken() async {
    if (_user != null) {
      try {
        // Try to get fresh FCM token from Firebase Messaging
        String? fcmToken = await FirebaseMessaging.instance.getToken();

        if (fcmToken != null && fcmToken.isNotEmpty) {
          logDebug('Fresh FCM token obtained: $fcmToken');
          // Store in local storage for future use
          await _storage.write('fcmtoken', fcmToken);
          // Update in databases
          await updateFcmToken(fcmToken);
        } else {
          // Fallback to stored token
          String storedToken = _storage.read('fcmtoken') ?? '';
          if (storedToken.isNotEmpty) {
            logDebug('Using stored FCM token: $storedToken');
            await updateFcmToken(storedToken);
          } else {
            logDebug('No FCM token available - notifications may not work');
          }
        }
      } catch (e) {
        logDebug('Error getting FCM token: $e');
        // Try fallback to stored token
        String storedToken = _storage.read('fcmtoken') ?? '';
        if (storedToken.isNotEmpty) {
          logDebug('Using stored FCM token as fallback: $storedToken');
          await updateFcmToken(storedToken);
        }
      }
    }
  }

  // New method to always get fresh FCM token for login
  Future<void> _getFreshFcmTokenAndUpdate() async {
    if (_user != null) {
      try {
        logDebug('Getting fresh FCM token for user login: ${_user!.uid}');

        // Force get a fresh FCM token from Firebase Messaging
        String? fcmToken = await FirebaseMessaging.instance.getToken();

        if (fcmToken != null && fcmToken.isNotEmpty) {
          logDebug('Fresh FCM token obtained for login: $fcmToken');
          // Store in local storage
          await _storage.write('fcmtoken', fcmToken);
          // Update in databases immediately
          await updateFcmToken(fcmToken);
        } else {
          logDebug('Failed to get fresh FCM token - trying to delete token');
          // If we can't get a token, try to delete the old token
          await FirebaseMessaging.instance.deleteToken();
          // Try again after deletion
          fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null && fcmToken.isNotEmpty) {
            logDebug('Fresh FCM token obtained after deletion: $fcmToken');
            await _storage.write('fcmtoken', fcmToken);
            await updateFcmToken(fcmToken);
          } else {
            logDebug(
              'Still no FCM token available after deletion - notifications may not work',
            );
          }
        }
      } catch (e) {
        logDebug('Error getting fresh FCM token for login: $e');
        // As a last resort, clear any stored token to force refresh
        await _storage.remove('fcmtoken');
      }
    }
  }

  Future<bool> updateFcmToken(String token) async {
    try {
      if (_user == null) {
        logDebug('Cannot update FCM token: User not logged in');
        return false;
      }

      logDebug('Updating FCM token for user ${_user!.uid}: $token');

      // Update in Firestore with error handling
      try {
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(_user!.uid)
            .update({'fcmToken': token});
        logDebug('FCM token updated successfully in Firestore');
      } catch (firestoreError) {
        logDebug('Error updating FCM token in Firestore: $firestoreError');

        // Handle specific Firestore errors
        if (firestoreError.toString().contains('permission-denied')) {
          logDebug(
            'Permission denied for Firestore token update - rules may need time to propagate',
          );
        } else if (firestoreError.toString().contains('not-found')) {
          logDebug('User document not found in Firestore for token update');
        }
      }

      // Update local user model
      if (_userModel != null) {
        _userModel = UserModel(
          id: _userModel!.id,
          name: _userModel!.name,
          email: _userModel!.email,
          fcmToken: token,
          isAdmin: _userModel!.isAdmin,
          profileImageUrl: _userModel!.profileImageUrl,
          employeeId: _userModel!.employeeId,
          department: _userModel!.department,
          createdAt: _userModel!.createdAt,
          joiningDate: _userModel!.joiningDate,
          role: _userModel!.role,
          isCasualLeave: _userModel!.isCasualLeave,
          totalExperience: _userModel!.totalExperience,
          emergencyContactNumber: _userModel!.emergencyContactNumber,
          isSubAdmin: _userModel!.isSubAdmin,
          officeLatitude: _userModel!.officeLatitude,
          officeLongitude: _userModel!.officeLongitude,
          userId: _userModel!.userId,
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      logDebug('Error updating FCM token: $e');
      return false;
    }
  }

  Future<void> checkAuthState() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Check if user is logged in
      _user = _auth.currentUser;
      if (_user != null) {
        await _fetchUserData();
        await _updateFcmToken();
      }
    } catch (e) {
      logDebug("Error checking auth state: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> resetPassword(String email) async {
    logDebug("resetPassword called with email: $email");
    try {
      logDebug("Calling sendPasswordResetEmail...");
      await _auth.sendPasswordResetEmail(email: email);
      logDebug("sendPasswordResetEmail completed successfully");
      return {
        'success': true,
        'message': 'Password reset email sent successfully!',
      };
    } on FirebaseAuthException catch (e) {
      logDebug("FirebaseAuthException: code=${e.code}, message=${e.message}");
      String errorMessage = 'Failed to send reset email.';
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found with this email address.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address.';
      }
      return {
        'success': false,
        'error': errorMessage,
      };
    } catch (e) {
      logDebug("Reset password error: $e");
      logDebug("Error type: ${e.runtimeType}");
      return {
        'success': false,
        'error': 'An error occurred. Please try again.',
      };
    }
  }
}
