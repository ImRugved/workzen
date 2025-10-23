import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_storage/get_storage.dart';
import 'package:workzen/app_constants.dart';
import 'package:workzen/providers/auth_provider.dart' as auth;
import 'package:provider/provider.dart';
import '../main.dart';

class PushNotificationsService {
  final GetStorage box = GetStorage();
  static final _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final auth.AuthProvider authProvider = auth.AuthProvider();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Initialize notification permissions and settings
  Future<void> init() async {
    log('Initializing notification service');
    // Firebase Messaging Permission Configuration
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // Get FCM token
    final token = await _firebaseMessaging.getToken();
    log("FCM token obtained: $token");

    // Save token to local storage
    await box.write("fcmtoken", token);

    // Update token in Firestore and Realtime Database
    await _updateFCMToken(token);

    // Set up token refresh listener
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      log("FCM token refreshed: $newToken");
      _updateFCMToken(newToken);
    });

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

        // Update in Firestore
        await FirebaseFirestore.instance
            .collection(AppConstants.usersCollection)
            .doc(userId)
            .update({'fcmToken': token});

        // Update in Realtime Database
        await _database.ref('userTokens/$userId').set(token);

        log(
          'FCM token updated successfully in both Firestore and Realtime Database',
        );
      } else {
        log('Cannot update FCM token: User not logged in');
      }
    } catch (e) {
      log('Error updating FCM token: $e');
    }
  }

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    log('Received foreground message: ${message.notification?.title}');
    _showLocalNotification(message);
  }

  // Handle message when app is opened from notification
  void _handleMessageOpenedApp(RemoteMessage message) {
    log('Message opened app: ${message.notification?.title}');
    navigatorKey.currentState?.pushNamed("/notification", arguments: message);
  }

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    // Android Notification Details
    const AndroidNotificationDetails
    androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'high_importance_channel', // Must match channel_id in AndroidManifest.xml
      'High Importance Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    // iOS Notification Details
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    // Notification Details
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // Show the notification
    await flutterLocalNotificationsPlugin.show(
      message.hashCode, // Use a unique ID
      message.notification?.title,
      message.notification?.body,
      platformChannelSpecifics,
      payload: message.data.toString(),
    );
  }

  // Handle notification tap
  @pragma('vm:entry-point')
  static void onNotificationTap(NotificationResponse notificationResponse) {
    log('Notification Tapped: ${notificationResponse.payload}');
    navigatorKey.currentState?.pushNamed(
      "/notification",
      arguments: notificationResponse.payload,
    );
  }

  // Method to show a simple notification
  Future<void> showSimpleNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          importance: Importance.high,
          priority: Priority.high,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 2147483647,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  // Method to set notification count (badge)
  Future<void> setCount({required int count}) async {
    await GetStorage().write('notiCount', count);

    // For iOS badge count
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(badge: true);
  }
}
