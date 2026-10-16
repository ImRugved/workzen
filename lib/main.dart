import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'constants/app_theme.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workzen/firebase_options.dart';
import 'package:workzen/utils/routes.dart';
import 'package:workzen/config/supabase_config.dart';
import 'package:provider/provider.dart';
import 'package:get_storage/get_storage.dart';
import 'providers/auth_provider.dart';
import 'providers/request_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/user_provider.dart';
import 'providers/onboarding_provider.dart';
import 'providers/employee_management_provider.dart';
import 'providers/security_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/calendar_provider.dart';
import 'providers/organization_provider.dart';
import 'services/fcm_service.dart';
import 'services/notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  await GetStorage.init();

  // Note: Push notification initialization moved to dashboard screens
  // to request permissions after user login instead of before splash screen

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RequestProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        // Organization data: one live listener per session, started on login
        // and stopped on logout, shared by every screen
        ChangeNotifierProxyProvider<AuthProvider, OrganizationProvider>(
          create: (_) => OrganizationProvider(),
          update: (_, auth, org) {
            if (auth.isLoggedIn) {
              org!.start();
            } else {
              org!.stop();
            }
            return org;
          },
        ),
        ChangeNotifierProxyProvider<OrganizationProvider, OnboardingProvider>(
          create: (_) => OnboardingProvider(),
          update: (_, org, onboarding) =>
              onboarding!..setLeaveConfig(org.leaveConfig),
        ),
        ChangeNotifierProvider(create: (_) => EmployeeManagementProvider()),
        ChangeNotifierProvider(create: (_) => SecurityProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        // Calendar colours follow the admin's live office hours and holidays
        ChangeNotifierProxyProvider<OrganizationProvider, CalendarProvider>(
          create: (_) => CalendarProvider(),
          update: (_, org, calendar) =>
              calendar!..setOrganization(org.officeHours, org.holidays),
        ),
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
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      useInheritedMediaQuery: true,
      minTextAdapt: true,
      splitScreenMode: true,
      // builder (not child) so the theme below is built after ScreenUtil is
      // initialised and can use .sp / .w / .h / .r
      builder: (context, _) => GetMaterialApp(
        title: 'SeenWork',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        initialRoute: '/splash_screen',
        getPages: Routes.pages,
      ),
    );
  }
}
