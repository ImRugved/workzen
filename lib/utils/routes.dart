import 'package:get/get.dart';
import '../screens/splash_scren.dart';
import '../screens/update_check_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/admin/admin_attendance_screen.dart';
import '../screens/admin/leave_requests_screen.dart';
import '../screens/admin/employee_onboarding_screen.dart';
import '../screens/admin/employee_management_screen.dart';
import '../screens/user/user_dashboard.dart';
import '../screens/user/apply_leave_screen.dart';
import '../screens/user/attendance_history_screen.dart';
import '../screens/user/attendance_screen.dart';
import '../screens/user/leave_history_screen.dart';
import '../screens/profile_screen.dart';

class Routes {
  static final pages = [
    // Splash screen
    GetPage(
      name: '/splash_screen',
      page: () => const SplashScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // Update check screen
    GetPage(
      name: '/update_check_screen',
      page: () => const UpdateCheckScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // Auth screens
    GetPage(
      name: '/login_screen',
      page: () => const LoginScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    GetPage(
      name: '/signup_screen',
      page: () => const SignupScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // Admin screens
    GetPage(
      name: '/admin_dashboard',
      page: () => const AdminDashboard(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    GetPage(
      name: '/admin_attendance_screen',
      page: () => const AdminAttendanceScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    GetPage(
      name: '/leave_requests_screen',
      page: () => const LeaveRequestsScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    GetPage(
      name: '/employee_onboarding_screen',
      page: () => const EmployeeOnboardingScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    GetPage(
      name: '/employee_management_screen',
      page: () => const EmployeeManagementScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // User screens
    GetPage(
      name: '/user_dashboard',
      page: () => const UserDashboard(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    GetPage(
      name: '/apply_leave_screen',
      page: () => const ApplyLeaveScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    GetPage(
      name: '/attendance_history_screen',
      page: () => const AttendanceHistoryScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    GetPage(
      name: '/attendance_screen',
      page: () => const AttendanceScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    GetPage(
      name: '/leave_history_screen',
      page: () => const LeaveHistoryScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // Profile screen
    GetPage(
      name: '/profile_screen',
      page: () => const ProfileScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
  ];

  // Route names as constants for easy access
  static const String splashScreen = '/splash_screen';
  static const String updateCheckScreen = '/update_check_screen';
  static const String loginScreen = '/login_screen';
  static const String signupScreen = '/signup_screen';
  static const String adminDashboard = '/admin_dashboard';
  static const String adminAttendanceScreen = '/admin_attendance_screen';
  static const String leaveRequestsScreen = '/leave_requests_screen';
  static const String employeeOnboardingScreen = '/employee_onboarding_screen';
  static const String employeeManagementScreen = '/employee_management_screen';
  static const String userDashboard = '/user_dashboard';
  static const String applyLeaveScreen = '/apply_leave_screen';
  static const String attendanceHistoryScreen = '/attendance_history_screen';
  static const String attendanceScreen = '/attendance_screen';
  static const String leaveHistoryScreen = '/leave_history_screen';
  static const String profileScreen = '/profile_screen';
}