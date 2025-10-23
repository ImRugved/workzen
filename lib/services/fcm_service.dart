import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../app_constants.dart';
import '../providers/user_provider.dart';
import 'package:googleapis/fcm/v1.dart' as fcm;

class FCMService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final UserProvider _userProvider = UserProvider();
  final String serverKey =
      'AAAA-Ow-Ixs:APA91bGXYXTpnXQZnGxHxVQYQbOyoMDmQDxDQQZYHvawzwkHGZvuJnEQJuCDZpOr-_0YnPFmGE9X-_RRK-3ZtAQJhQZB_-xvV_J_PQNJKUeUjHN-ydZHvdQVPIYEXYf4amkUQxlnlQZl'; // Your actual FCM server key

  // Constants
  static const String _fcmEndpoint = 'https://fcm.googleapis.com/fcm/send';
  static const String _fcmV1Endpoint =
      'https://fcm.googleapis.com/v1/projects/mounarchtech-ac3b9/messages:send';
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/firebase.messaging'
  ];

  // Send notification to a specific user by userId
  Future<bool> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      log('Sending notification to user: $userId');
      log('Notification title: $title');
      log('Notification body: $body');
      log('Notification data: $data');

      // Get user's FCM token using the new method from UserProvider
      final token = await _userProvider.getUserFcmToken(userId);

      if (token == null || token.isEmpty) {
        log('FCM token not found for user: $userId');
        return false;
      }

      log('Found FCM token for user $userId: $token');

      // Send notification with the token
      final result = await sendNotification(
        token: token,
        title: title,
        body: body,
        data: data,
      );

      if (result) {
        log('Notification sent successfully to user: $userId');
      } else {
        log('Failed to send notification to user: $userId');
      }

      return result;
    } catch (e) {
      log('Error sending notification to user: $e');
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
      // Validate token
      if (token.isEmpty) {
        log('Cannot send notification: Token is empty');
        return false;
      }

      log('Attempting to send notification using service account');
      log('Loading service account credentials');

      // Load service account credentials
      final serviceAccountJson =
          await rootBundle.loadString('assets/service.json');
      final serviceAccount =
          ServiceAccountCredentials.fromJson(jsonDecode(serviceAccountJson));

      log('Service account credentials loaded successfully');
      log('Obtaining access token');

      // Get access token
      final client = await clientViaServiceAccount(serviceAccount,
          ['https://www.googleapis.com/auth/firebase.messaging']);
      final accessToken = client.credentials.accessToken.data;

      log('Access token obtained: ${accessToken.substring(0, 10)}...');

      // Extract project ID from service account email
      // Service account emails are in the format: name@project-id.iam.gserviceaccount.com
      final String projectId = serviceAccount.email.split('@')[1].split('.')[0];
      log('Project ID extracted from service account: $projectId');

      // Create FCM API client
      final fcmApi = fcm.FirebaseCloudMessagingApi(client);

      // Construct message payload with data converted to strings
      final Map<String, String> stringData = {};
      if (data != null) {
        data.forEach((key, value) {
          stringData[key] = value.toString();
        });
      }

      final message = fcm.Message(
        token: token,
        notification: fcm.Notification(
          title: title,
          body: body,
        ),
        data: stringData,
      );

      log('Sending message to FCM API');

      // Send message
      final response = await fcmApi.projects.messages.send(
        fcm.SendMessageRequest(message: message),
        'projects/$projectId',
      );

      log('FCM API response: ${response.name}');

      client.close();
      return true;
    } catch (e) {
      log('Error sending notification with service account: $e');

      // Check if the error is due to an unregistered token
      if (e.toString().contains('unregistered') ||
          e.toString().contains('not-registered') ||
          e.toString().contains('invalid-argument')) {
        log('Token appears to be invalid or unregistered');
        _cleanupInvalidToken(token);
      }

      return false;
    }
  }

  // Clean up invalid token
  Future<void> _cleanupInvalidToken(String token) async {
    try {
      log('Cleaning up invalid token: $token');

      // Find user with this token in Firestore
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

          // Remove token from Firestore
          await _firestore.collection('users').doc(userId).update({
            'fcmToken': '',
          });

          // Remove token from Realtime Database
          await _database.ref('userTokens/$userId').remove();

          log('Invalid token removed for user: $userId');
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
      final String serviceJson =
          await rootBundle.loadString('assets/service.json');
      final Map<String, dynamic> serviceAccount = jsonDecode(serviceJson);

      // Create credentials
      final credentials = ServiceAccountCredentials.fromJson(serviceAccount);

      // Get access token
      final client = http.Client();
      AccessCredentials accessCredentials;

      try {
        accessCredentials = await obtainAccessCredentialsViaServiceAccount(
            credentials, _scopes, client);
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
