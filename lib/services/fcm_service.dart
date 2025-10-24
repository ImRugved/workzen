import 'dart:convert';
import 'dart:developer';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
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
      log('Attempting to send notification to user: $userId');

      // Get user's FCM token
      String? token = await _userProvider.getUserFcmToken(userId);

      if (token == null || token.isEmpty) {
        log('FCM token not found for user: $userId');
        return false;
      }

      log('Found FCM token for user $userId: ${token.substring(0, 20)}...');

      // Send notification
      bool success = await _sendWithServiceAccount(
        token: token,
        title: title,
        body: body,
        data: data,
      );

      if (success) {
        log('Notification sent successfully to user: $userId');
      } else {
        log('Failed to send notification to user: $userId');
      }

      return success;
    } catch (e) {
      log('Error in sendNotificationToUser: $e');
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
      log('Sending notification with service account method');
      log('Token: $token');
      log('Title: $title');
      log('Body: $body');
      log('Data: $data');

      // Use service account method
      final result = await _sendWithServiceAccount(
        token: token,
        title: title,
        body: body,
        data: data,
      );

      if (result) {
        log('Notification sent successfully with service account method');
      } else {
        log('Failed to send notification with service account method');
      }

      return result;
    } catch (e) {
      log('Error sending notification: $e');
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
      log(
        'Sending notification with service account to token: ${token.substring(0, 20)}...',
      );

      // Get access token
      final String? accessToken = await getAccessToken();
      if (accessToken == null) {
        log('Failed to get access token');
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

      log('FCM message payload: ${jsonEncode(message)}');

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

      log('FCM response status: ${response.statusCode}');
      log('FCM response body: ${response.body}');

      if (response.statusCode == 200) {
        log('Notification sent successfully');
        return true;
      } else {
        log(
          'Failed to send notification. Status: ${response.statusCode}, Body: ${response.body}',
        );

        // Check for invalid token errors
        if (response.body.contains('INVALID_ARGUMENT') ||
            response.body.contains('UNREGISTERED') ||
            response.body.contains('NOT_FOUND')) {
          log('Invalid or unregistered token detected, cleaning up...');
          await cleanupInvalidToken(token);
        }

        return false;
      }
    } catch (e) {
      log('Error in _sendWithServiceAccount: $e');
      return false;
    }
  }

  // Clean up invalid FCM token
  Future<void> cleanupInvalidToken(String token) async {
    try {
      log('Cleaning up invalid token: $token');

      // Find users with this token in Firestore
      final querySnapshot = await _firestore
          .collection('users')
          .where('fcmToken', isEqualTo: token)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        log('Found ${querySnapshot.docs.length} users with invalid token');

        // Update each user document
        for (var doc in querySnapshot.docs) {
          final userId = doc.id;
          log('Removing invalid token from user: $userId');

          // Remove token from Firestore only
          try {
            await _firestore.collection('users').doc(userId).update({
              'fcmToken': '',
            });
            log('Invalid token removed from Firestore for user: $userId');
          } catch (firestoreError) {
            log(
              'Error removing token from Firestore for user $userId: $firestoreError',
            );

            // Handle specific Firestore errors
            if (firestoreError.toString().contains('permission-denied')) {
              log(
                'Permission denied for Firestore token cleanup - rules may need time to propagate',
              );
            } else if (firestoreError.toString().contains('not-found')) {
              log('User document not found in Firestore for token cleanup');
            }
          }
        }
      } else {
        log('No users found with this invalid token');
      }
    } catch (e) {
      log('Error cleaning up invalid token: $e');
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
      log('Error getting access token: $e');
      return null;
    }
  }
}
