import 'package:get/get.dart';
import '../screens/splash_scren.dart';
import '../screens/update_check_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/admin/dashboard/admin_dashboard_screen.dart';
import '../screens/admin/admin_attendance_screen.dart';
import '../screens/admin/announcements_screen.dart';
import '../screens/admin/employee_of_month_screen.dart';
import '../screens/admin/company_rules_screen.dart';
import '../screens/admin/leave_requests_screen.dart';
import '../screens/admin/holiday_management_screen.dart';
import '../screens/admin/manage_employee_leave_screen.dart';
import '../screens/admin/employee_onboarding_screen.dart';
import '../screens/admin/employee_management_screen.dart';
import '../screens/user/dashboard/user_dashboard_screen.dart';
import '../screens/user/apply_leave_screen.dart';
import '../screens/user/attendance_history_screen.dart';
import '../screens/user/attendance_screen.dart';
import '../screens/user/employee_directory_screen.dart';
import '../screens/user/leave_history_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/newsletter_screen.dart';
import '../screens/admin/newsletter_editor_screen.dart';
import '../screens/company_rules_view_screen.dart';
import '../screens/security_settings_screen.dart';

class Routes {
  static final pages = [
    // Splash screen
    GetPage(
      name: '/splash_screen',
      page: () => const SplashScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // All announcements (opened from the admin Info tab)
    GetPage(
      name: '/announcements_screen',
      page: () => const AnnouncementsScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // Newsletter: company news, read by everyone (opened from the Info tab)
    GetPage(
      name: '/newsletter_screen',
      page: () => const NewsletterScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // Write a newsletter post (admin and sub admins with the permission)
    GetPage(
      name: '/newsletter_editor_screen',
      page: () => const NewsletterEditorScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // Notifications: birthdays, employee of the month, announcements (opened
    // from the bell on the admin and employee home screens)
    GetPage(
      name: '/notifications_screen',
      page: () => const NotificationsScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // Company rules in view mode (opened from the Profile screen)
    GetPage(
      name: '/company_rules_view_screen',
      page: () => const CompanyRulesViewScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // Company rules editor (opened from the admin Info tab)
    GetPage(
      name: '/company_rules_screen',
      page: () => const CompanyRulesScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // Employee of the month, every month (opened from the admin Info tab)
    GetPage(
      name: '/employee_of_month_screen',
      page: () => const EmployeeOfMonthScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    // Employee directory (opened from the Info tab)
    GetPage(
      name: '/employee_directory_screen',
      page: () => const EmployeeDirectoryScreen(),
      transition: Transition.rightToLeft,
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
      page: () => const AdminDashboardScreen(),
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
      name: '/holiday_management_screen',
      page: () => const HolidayManagementScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),

    GetPage(
      name: '/manage_employee_leave_screen',
      page: () => const ManageEmployeeLeaveScreen(),
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
      page: () => const UserDashboardScreen(),
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

    // Security settings screen
    GetPage(
      name: '/security_settings_screen',
      page: () => const SecuritySettingsScreen(),
      transition: Transition.rightToLeft,
      transitionDuration: const Duration(milliseconds: 300),
    ),
  ];

  // Route names as constants for easy access
  static const String splashScreen = '/splash_screen';
  static const String updateCheckScreen = '/update_check_screen';
  static const String employeeDirectoryScreen = '/employee_directory_screen';
  static const String announcementsScreen = '/announcements_screen';
  static const String employeeOfMonthScreen = '/employee_of_month_screen';
  static const String companyRulesScreen = '/company_rules_screen';
  static const String notificationsScreen = '/notifications_screen';
  static const String newsletterScreen = '/newsletter_screen';
  static const String newsletterEditorScreen = '/newsletter_editor_screen';
  static const String companyRulesViewScreen = '/company_rules_view_screen';
  static const String loginScreen = '/login_screen';
  static const String signupScreen = '/signup_screen';
  static const String adminDashboard = '/admin_dashboard';
  static const String adminAttendanceScreen = '/admin_attendance_screen';
  static const String leaveRequestsScreen = '/leave_requests_screen';
  static const String holidayManagementScreen = '/holiday_management_screen';
  static const String manageEmployeeLeaveScreen =
      '/manage_employee_leave_screen';
  static const String employeeOnboardingScreen = '/employee_onboarding_screen';
  static const String employeeManagementScreen = '/employee_management_screen';
  static const String userDashboard = '/user_dashboard';
  static const String applyLeaveScreen = '/apply_leave_screen';
  static const String attendanceHistoryScreen = '/attendance_history_screen';
  static const String attendanceScreen = '/attendance_screen';
  static const String leaveHistoryScreen = '/leave_history_screen';
  static const String profileScreen = '/profile_screen';
}
