import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_storage/get_storage.dart';
import 'package:workzen/app_constants.dart';
import 'package:workzen/providers/auth_provider.dart' as auth;

class PushNotificationsService {
  final GetStorage box = GetStorage();
  static final _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final auth.AuthProvider authProvider = auth.AuthProvider();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize notification permissions and settings after login
  Future<void> initAfterLogin() async {
    try {
      log('Initializing notification service after login');

      // Firebase Messaging Permission Configuration
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );

      // Get FCM token with error handling
      String? token;
      try {
        token = await _firebaseMessaging.getToken();
        log("FCM token obtained: $token");

        if (token != null) {
          // Save token to local storage
          await box.write("fcmtoken", token);

          // Update token in Firestore and Realtime Database
          await _updateFCMToken(token);
        } else {
          log("FCM token is null, skipping token operations");
        }
      } catch (tokenError) {
        log("Error getting FCM token: $tokenError");
        log("Continuing without FCM token - push notifications may not work");
        // Don't rethrow - allow app to continue without FCM
      }

      // Set up token refresh listener with error handling
      try {
        _firebaseMessaging.onTokenRefresh.listen(
          (newToken) {
            log("FCM token refreshed: $newToken");
            _updateFCMToken(newToken);
          },
          onError: (error) {
            log("Error in token refresh listener: $error");
          },
        );
      } catch (listenerError) {
        log("Error setting up token refresh listener: $listenerError");
      }

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        log('User granted notification permission');
      } else {
        log('User declined or has not accepted notification permission');
      }

      // Flutter Local Notifications Initialization
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestSoundPermission: true,
            requestBadgePermission: true,
            requestAlertPermission: true,
          );

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: onNotificationTap,
        onDidReceiveBackgroundNotificationResponse: onNotificationTap,
      );

      // Configure Firebase Messaging handlers
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      log('Notification service initialized successfully after login');
    } catch (e) {
      log('Error initializing notification service after login: $e');
      log('App will continue without full notification functionality');
      // Don't rethrow - allow app to continue
    }
  }

  Future<void> _updateFCMToken(String? token) async {
    if (token == null || token.isEmpty) {
      log('Cannot update FCM token: Token is empty');
      return;
    }

    try {
      // Get the current authenticated user
      User? currentUser = _auth.currentUser;

      // Check if user is logged in
      if (currentUser != null) {
        String userId = currentUser.uid;
        log('Updating FCM token for user $userId: $token');

        // Update in Firestore only
        try {
          await FirebaseFirestore.instance
              .collection(AppConstants.usersCollection)
              .doc(userId)
              .update({'fcmToken': token});
          log('FCM token updated successfully in Firestore');
        } catch (firestoreError) {
          log('Error updating FCM token in Firestore: $firestoreError');

          // Handle specific Firestore errors
          if (firestoreError.toString().contains('permission-denied')) {
            log(
              'Permission denied for Firestore token update - rules may need time to propagate',
            );
          } else if (firestoreError.toString().contains('not-found')) {
            log('User document not found in Firestore for token update');
          }
        }
      } else {
        log('Cannot update FCM token: User not logged in');
      }
    } catch (e) {
      log('Error updating FCM token: $e');
    }
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    log('Received foreground message: ${message.messageId}');

    // Show local notification for foreground messages
    _showLocalNotification(message);
  }

  // Handle message opened app
  void _handleMessageOpenedApp(RemoteMessage message) {
    log('Message opened app: ${message.messageId}');

    // Handle navigation based on message data
    _handleNotificationNavigation(message.data);
  }

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'workzen_channel',
            'WorkZen Notifications',
            channelDescription: 'Notifications for WorkZen app',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: false,
          );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await flutterLocalNotificationsPlugin.show(
        message.hashCode,
        message.notification?.title ?? 'WorkZen',
        message.notification?.body ?? 'You have a new notification',
        platformChannelSpecifics,
        payload: message.data.toString(),
      );
    } catch (e) {
      log('Error showing local notification: $e');
    }
  }

  // Handle notification navigation
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    try {
      // Navigate based on notification type
      if (data.containsKey('type')) {
        String type = data['type'];

        switch (type) {
          case 'leave_request':
            // Navigate to leave requests screen
            break;
          case 'attendance':
            // Navigate to attendance screen
            break;
          default:
            // Navigate to dashboard
            break;
        }
      }
    } catch (e) {
      log('Error handling notification navigation: $e');
    }
  }

  // Handle notification tap
  static void onNotificationTap(NotificationResponse notificationResponse) {
    log('Notification tapped: ${notificationResponse.payload}');

    // Handle notification tap navigation
    // You can parse the payload and navigate accordingly
  }

  // Request notification permissions (iOS specific)
  Future<void> requestIOSPermissions() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(badge: true);
  }
}
