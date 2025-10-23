import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:workzen/screens/splash_scren.dart';
import 'package:provider/provider.dart';
import 'package:get_storage/get_storage.dart';
import 'providers/auth_provider.dart';
import 'providers/leave_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/user_provider.dart';
import 'screens/auth/login_screen.dart';
import 'services/fcm_service.dart';
import 'services/notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await GetStorage.init();
  await PushNotificationsService().init();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LeaveProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Attendance Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.indigo,
          accentColor: Colors.amber,
          backgroundColor: Colors.white,
          cardColor: Colors.white,
          errorColor: Colors.red,
        ),
        fontFamily: 'Poppins',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.indigo,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
