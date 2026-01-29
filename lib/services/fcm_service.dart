import 'dart:convert';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workzen/utils/logger.dart';
import '../providers/user_provider.dart';

class FCMService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserProvider _userProvider = UserProvider();

  // Constants
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/firebase.messaging',
  ];

  // Send notification to a specific user by userId
  Future<bool> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      logDebug('Attempting to send notification to user: $userId');

      // Get user's FCM token
      String? token = await _userProvider.getUserFcmToken(userId);

      if (token == null || token.isEmpty) {
        logDebug('FCM token not found for user: $userId');
        return false;
      }

      logDebug(
        'Found FCM token for user $userId: ${token.substring(0, 20)}...',
      );

      // Send notification
      bool success = await _sendWithServiceAccount(
        token: token,
        title: title,
        body: body,
        data: data,
      );

      if (success) {
        logDebug('Notification sent successfully to user: $userId');
      } else {
        logDebug('Failed to send notification to user: $userId');
      }

      return success;
    } catch (e) {
      logDebug('Error in sendNotificationToUser: $e');
      return false;
    }
  }

  // Send notification with FCM token
  Future<bool> sendNotification({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      logDebug('Sending notification with service account method');
      logDebug('Token: $token');
      logDebug('Title: $title');
      logDebug('Body: $body');
      logDebug('Data: $data');

      // Use service account method
      final result = await _sendWithServiceAccount(
        token: token,
        title: title,
        body: body,
        data: data,
      );

      if (result) {
        logDebug('Notification sent successfully with service account method');
      } else {
        logDebug('Failed to send notification with service account method');
      }

      return result;
    } catch (e) {
      logDebug('Error sending notification: $e');
      return false;
    }
  }

  // Send notification using service account
  Future<bool> _sendWithServiceAccount({
    required String token,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      logDebug(
        'Sending notification with service account to token: ${token.substring(0, 20)}...',
      );

      // Get access token
      final String? accessToken = await getAccessToken();
      if (accessToken == null) {
        logDebug('Failed to get access token');
        return false;
      }

      // Load service account credentials to get project ID
      final String serviceAccountJson = await rootBundle.loadString(
        'assets/service.json',
      );
      final Map<String, dynamic> serviceAccount = jsonDecode(
        serviceAccountJson,
      );
      final String projectId = serviceAccount['project_id'];

      // Prepare the message
      final Map<String, dynamic> message = {
        'message': {
          'token': token,
          'notification': {'title': title, 'body': body},
          'data':
              data?.map((key, value) => MapEntry(key, value.toString())) ?? {},
        },
      };

      logDebug('FCM message payload: ${jsonEncode(message)}');

      // Send the notification
      final response = await http.post(
        Uri.parse(
          'https://fcm.googleapis.com/v1/projects/$projectId/messages:send',
        ),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(message),
      );

      logDebug('FCM response status: ${response.statusCode}');
      logDebug('FCM response body: ${response.body}');

      if (response.statusCode == 200) {
        logDebug('Notification sent successfully');
        return true;
      } else {
        logDebug(
          'Failed to send notification. Status: ${response.statusCode}, Body: ${response.body}',
        );

        // Check for invalid token errors
        if (response.body.contains('INVALID_ARGUMENT') ||
            response.body.contains('UNREGISTERED') ||
            response.body.contains('NOT_FOUND')) {
          logDebug('Invalid or unregistered token detected, cleaning up...');
          await cleanupInvalidToken(token);
        }

        return false;
      }
    } catch (e) {
      logDebug('Error in _sendWithServiceAccount: $e');
      return false;
    }
  }

  // Clean up invalid FCM token
  Future<void> cleanupInvalidToken(String token) async {
    try {
      logDebug('Cleaning up invalid token: $token');

      // Find users with this token in Firestore
      final querySnapshot = await _firestore
          .collection('users')
          .where('fcmToken', isEqualTo: token)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        logDebug('Found ${querySnapshot.docs.length} users with invalid token');

        // Update each user document
        for (var doc in querySnapshot.docs) {
          final userId = doc.id;
          logDebug('Removing invalid token from user: $userId');

          // Remove token from Firestore only
          try {
            await _firestore.collection('users').doc(userId).update({
              'fcmToken': '',
            });
            logDebug('Invalid token removed from Firestore for user: $userId');
          } catch (firestoreError) {
            logDebug(
              'Error removing token from Firestore for user $userId: $firestoreError',
            );

            // Handle specific Firestore errors
            if (firestoreError.toString().contains('permission-denied')) {
              logDebug(
                'Permission denied for Firestore token cleanup - rules may need time to propagate',
              );
            } else if (firestoreError.toString().contains('not-found')) {
              logDebug(
                'User document not found in Firestore for token cleanup',
              );
            }
          }
        }
      } else {
        logDebug('No users found with this invalid token');
      }
    } catch (e) {
      logDebug('Error cleaning up invalid token: $e');
    }
  }

  // Get access token using service account
  Future<String?> getAccessToken() async {
    try {
      // Load service account JSON
      final String serviceJson = await rootBundle.loadString(
        'assets/service.json',
      );
      final Map<String, dynamic> serviceAccount = jsonDecode(serviceJson);

      // Create credentials
      final credentials = ServiceAccountCredentials.fromJson(serviceAccount);

      // Get access token
      final client = http.Client();
      AccessCredentials accessCredentials;

      try {
        accessCredentials = await obtainAccessCredentialsViaServiceAccount(
          credentials,
          _scopes,
          client,
        );
        return accessCredentials.accessToken.data;
      } finally {
        client.close();
      }
    } catch (e) {
      logDebug('Error getting access token: $e');
      return null;
    }
  }
}
