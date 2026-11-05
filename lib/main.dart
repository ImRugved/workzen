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
import 'providers/my_data_provider.dart';
import 'providers/update_check_provider.dart';
import 'providers/company_info_provider.dart';
import 'providers/notification_feed_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'services/badge_service.dart';
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
        // The signed-in user's own attendance, requests and leave balances:
        // one live listener each for the session, shared by every employee
        // screen, started on login and stopped on logout
        ChangeNotifierProxyProvider<AuthProvider, MyDataProvider>(
          create: (_) => MyDataProvider(),
          update: (_, auth, my) {
            final uid = auth.user?.uid;
            if (uid != null) {
              my!.start(uid);
            } else {
              my!.stop();
            }
            return my;
          },
        ),
        ChangeNotifierProxyProvider<MyDataProvider, RequestProvider>(
          create: (_) => RequestProvider(),
          update: (_, my, requests) => requests!..setMyData(my),
        ),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        // Software updates (Shorebird): one state shared by the update screen
        // and the banner on both dashboards
        ChangeNotifierProvider(create: (_) => UpdateCheckProvider()),
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
        // Info page content (announcements, employee of the month, rules):
        // started at login and stopped on logout, so the bell on the home
        // screens can count what is new in it
        ChangeNotifierProxyProvider<AuthProvider, CompanyInfoProvider>(
          create: (_) => CompanyInfoProvider(),
          update: (_, auth, info) {
            if (auth.isLoggedIn) {
              info!.start();
            } else {
              info!.stop();
            }
            return info;
          },
        ),
        // What the Notifications screen shows and the bell counts: birthdays
        // today, the employee of the month and the announcements
        ChangeNotifierProxyProvider3<
          CompanyInfoProvider,
          AuthProvider,
          OrganizationProvider,
          NotificationFeedProvider
        >(
          create: (_) => NotificationFeedProvider(),
          update: (_, info, auth, org, feed) =>
              feed!..update(info: info, auth: auth, org: org),
        ),
        // Punches and breaks are checked against the office the admin set
        ChangeNotifierProxyProvider2<
          OrganizationProvider,
          MyDataProvider,
          AttendanceProvider
        >(
          create: (_) => AttendanceProvider(),
          update: (_, org, my, attendance) => attendance!
            ..setOfficeLocation(org.officeLocation)
            ..setMyData(my),
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
        // and the user's live attendance and requests
        ChangeNotifierProxyProvider2<
          OrganizationProvider,
          MyDataProvider,
          CalendarProvider
        >(
          create: (_) => CalendarProvider(),
          update: (_, org, my, calendar) => calendar!
            ..setOrganization(org.officeHours, org.holidays)
            ..setMyData(my),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Options passed explicitly: iOS has no GoogleService-Info.plist in the project
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
  // The sender puts the user's unread count in the message: show it on the icon
  // whenever this code gets to run (the phone shows the push itself either way)
  final unread = int.tryParse('${message.data['unread'] ?? ''}');
  if (unread != null) await BadgeService.set(unread);
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
        title: 'SeenIT',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        // The rich text editor (company rules) needs its own texts
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        initialRoute: '/splash_screen',
        getPages: Routes.pages,
      ),
    );
  }
}
