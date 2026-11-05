import 'dart:convert';
import 'package:workzen/constants/firestore_constants.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workzen/utils/logger.dart';

class FCMService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Android notification channel the app's pushes use (created in
  /// PushNotificationsService.initAfterLogin).
  static const String notificationChannelId = 'workzen_channel';

  // Constants
  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/firebase.messaging',
  ];

  /// Gets the FCM token. On iOS the APNS token must exist first, so wait for it
  /// (up to ~3s). Returns null on the iOS simulator / when APNS is unavailable.
  static Future<String?> getFcmToken() async {
    final messaging = FirebaseMessaging.instance;
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      String? apns = await messaging.getAPNSToken();
      for (var i = 0; i < 3 && apns == null; i++) {
        await Future.delayed(const Duration(seconds: 1));
        apns = await messaging.getAPNSToken();
      }
      if (apns == null) {
        logDebug('APNS token not available (simulator or push not set up)');
        return null;
      }
    }
    return messaging.getToken();
  }

  // Send notification to a specific user by userId
  Future<bool> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      logDebug('Attempting to send notification to user: $userId');

      // One read gives the push token and how many pushes the user has not yet
      // seen (the number already on their app icon)
      final userRef = _firestore
          .collection(FirestoreCollections.users)
          .doc(userId);
      final userData = (await userRef.get()).data();
      final String? token = userData?[FirestoreFields.fcmToken]?.toString();
      final unreadValue = userData?[FirestoreFields.unreadNotifications];
      final int unread = unreadValue is num ? unreadValue.toInt() : 0;

      if (token == null || token.isEmpty) {
        logDebug('FCM token not found for user: $userId');
        return false;
      }

      logDebug(
        'Found FCM token for user $userId: ${token.substring(0, 20)}...',
      );

      // Send notification; the icon badge shows the count including this one
      bool success = await _sendWithServiceAccount(
        token: token,
        title: title,
        body: body,
        data: data,
        badge: unread + 1,
      );

      if (success) {
        logDebug('Notification sent successfully to user: $userId');
        // Remember it: the user's phone sets this back to 0 when the app opens
        try {
          await userRef.update({
            FirestoreFields.unreadNotifications: FieldValue.increment(1),
          });
        } catch (e) {
          logDebug('Could not update the unread count of $userId: $e');
        }
      } else {
        logDebug('Failed to send notification to user: $userId');
      }

      return success;
    } catch (e) {
      logDebug('Error in sendNotificationToUser: $e');
      return false;
    }
  }

  /// Sends a notification to every user (admins, sub admins and employees),
  /// except [excludeUserId] (the person who caused it). Each phone's icon badge
  /// goes up by one, like any other push. One read of the users collection
  /// gives all the tokens; the access token is fetched once and the pushes go
  /// out ten at a time. Returns how many were sent.
  Future<int> sendNotificationToAll({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? excludeUserId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(FirestoreCollections.users)
          .get();
      final accessToken = await getAccessToken();
      if (accessToken == null) return 0;

      final targets = snapshot.docs.where((doc) {
        if (doc.id == excludeUserId) return false;
        final token = doc.data()[FirestoreFields.fcmToken]?.toString() ?? '';
        return token.isNotEmpty;
      }).toList();

      var sent = 0;
      const parallel = 10;
      for (var i = 0; i < targets.length; i += parallel) {
        final end = i + parallel > targets.length ? targets.length : i + parallel;
        await Future.wait(
          targets.sublist(i, end).map((doc) async {
            final values = doc.data();
            final unreadValue = values[FirestoreFields.unreadNotifications];
            final unread = unreadValue is num ? unreadValue.toInt() : 0;

            final ok = await _sendWithServiceAccount(
              token: values[FirestoreFields.fcmToken].toString(),
              title: title,
              body: body,
              data: data,
              badge: unread + 1,
              accessToken: accessToken,
            );
            if (!ok) return;
            sent++;
            try {
              await doc.reference.update({
                FirestoreFields.unreadNotifications: FieldValue.increment(1),
              });
            } catch (e) {
              logDebug('Could not update the unread count of ${doc.id}: $e');
            }
          }),
        );
      }
      logDebug('Notification sent to $sent of ${targets.length} users');
      return sent;
    } catch (e) {
      logDebug('Error in sendNotificationToAll: $e');
      return 0;
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
    int? badge,
    String? accessToken,
  }) async {
    try {
      logDebug(
        'Sending notification with service account to token: ${token.substring(0, 20)}...',
      );

      // Get access token (a caller sending many reuses one)
      accessToken ??= await getAccessToken();
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
          // iOS: without these the push arrives silently (no sound) and may be
          // delayed; "badge" is the number on the app icon, shown even when the
          // app is closed. Android: deliver straight away, on the app's own
          // channel (created at login, so it pops up with sound), and
          // notification_count is the number some launchers show on the icon.
          'apns': {
            'headers': {'apns-priority': '10'},
            'payload': {
              'aps': {'sound': 'default', if (badge != null) 'badge': badge},
            },
          },
          'android': {
            'priority': 'high',
            'notification': {
              'channel_id': notificationChannelId,
              if (badge != null) 'notification_count': badge,
            },
          },
          'data': {
            ...?data?.map((key, value) => MapEntry(key, value.toString())),
            // The background handler shows this on the app icon
            if (badge != null) 'unread': badge.toString(),
          },
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
          .collection(FirestoreCollections.users)
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
            await _firestore
                .collection(FirestoreCollections.users)
                .doc(userId)
                .update({'fcmToken': ''});
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
