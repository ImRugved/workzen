import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../app_constants.dart';

class TokenUpdater {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Updates FCM tokens for all users in the database
  static Future<void> updateAllUserTokens() async {
    try {
      // Get current FCM token
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        log('Cannot update tokens: Current token is empty');
        return;
      }

      log('Current FCM token: $token');

      // Get all users from Firestore
      final usersSnapshot =
          await _firestore.collection(AppConstants.usersCollection).get();

      log('Found ${usersSnapshot.docs.length} users to update');

      // Update each user's token in Realtime Database
      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final userData = userDoc.data();

        // Check if user has a token in Firestore
        if (userData.containsKey('fcmToken')) {
          final storedToken = userData['fcmToken'];

          // Save token to Realtime Database
          await _database.ref('userTokens/$userId').set(storedToken);
          log('Updated token for user $userId in Realtime Database');
        } else {
          log('User $userId has no FCM token in Firestore');
        }
      }

      log('Token update completed for all users');
    } catch (e) {
      log('Error updating tokens: $e');
    }
  }

  /// Updates FCM token for a specific user
  static Future<void> updateUserToken(String userId) async {
    try {
      // Get user from Firestore
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        log('User $userId not found in Firestore');
        return;
      }

      final userData = userDoc.data();
      if (userData == null) {
        log('User data is null for user $userId');
        return;
      }

      // Check if user has a token in Firestore
      if (userData.containsKey('fcmToken')) {
        final storedToken = userData['fcmToken'];

        // Save token to Realtime Database
        await _database.ref('userTokens/$userId').set(storedToken);
        log('Updated token for user $userId in Realtime Database');
      } else {
        log('User $userId has no FCM token in Firestore');
      }
    } catch (e) {
      log('Error updating token for user $userId: $e');
    }
  }
}
