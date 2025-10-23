import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import '../app_constants.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
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
    _isLoading = true;
    notifyListeners();

    try {
      DocumentSnapshot userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(_user!.uid)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        _userModel = UserModel.fromJson(userData);
      }
    } catch (e) {
      log("Error fetching user data: $e");
    }

    _isLoading = false;
    notifyListeners();
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
      await _updateFcmToken();
      return true;
    } catch (e) {
      log("Login error: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signup(
      String name, String email, String password, String secretCode) async {
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

      // Create user model
      UserModel newUser = UserModel(
        id: _user!.uid,
        name: name,
        email: email,
        fcmToken: fcmToken,
        isAdmin: secretCode == AppConstants.adminCode,
      );

      // Save to Firestore
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(_user!.uid)
          .set(newUser.toJson());

      // Save to Realtime Database
      if (fcmToken.isNotEmpty) {
        await _database.ref('userTokens/${_user!.uid}').set(fcmToken);
        log('FCM token saved to Realtime Database for new user: ${_user!.uid}');
      }

      _userModel = newUser;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      log("Signup error: $e");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      // Clear FCM token before logout
      if (_user != null) {
        await updateFcmToken('');
      }

      await _auth.signOut();
      _user = null;
      _userModel = null;
      notifyListeners();
    } catch (e) {
      log("Logout error: $e");
    }
  }

  Future<void> _updateFcmToken() async {
    if (_user != null) {
      String fcmToken = _storage.read('fcmtoken') ?? '';
      if (fcmToken.isNotEmpty) {
        await updateFcmToken(fcmToken);
      }
    }
  }

  Future<bool> updateFcmToken(String token) async {
    try {
      if (_user == null) {
        log('Cannot update FCM token: User not logged in');
        return false;
      }

      log('Updating FCM token for user ${_user!.uid}: $token');

      // Update in Firestore
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(_user!.uid)
          .update({'fcmToken': token});

      // Update in Realtime Database
      if (token.isNotEmpty) {
        await _database.ref('userTokens/${_user!.uid}').set(token);
      } else {
        await _database.ref('userTokens/${_user!.uid}').remove();
      }

      log('FCM token updated successfully in both Firestore and Realtime Database');

      if (_userModel != null) {
        _userModel = UserModel(
          id: _userModel!.id,
          name: _userModel!.name,
          email: _userModel!.email,
          fcmToken: token,
          isAdmin: _userModel!.isAdmin,
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      log('Error updating FCM token: $e');
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
      log("Error checking auth state: $e");
    }

    _isLoading = false;
    notifyListeners();
  }
}
