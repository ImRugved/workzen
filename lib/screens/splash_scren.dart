import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:workzen/utils/logger.dart';
import '../providers/auth_provider.dart';
import '../constants/const_textstyle.dart';

import 'admin/dashboard/admin_dashboard_screen.dart';
import 'auth/login_screen.dart';
import 'user/dashboard/user_dashboard_screen.dart';
import '../providers/security_provider.dart';
import 'app_unlock_screen.dart';
import 'app_unlock_pin_setup_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_animationController);

    _animationController.forward();

    // Defer auth check until after build phase is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndNavigate();
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Wait for auth state check to complete
    await authProvider.checkAuthState();

    // Ensure minimum animation time (800ms) has passed
    await Future.delayed(const Duration(milliseconds: 800));

    // FCM token updates are now handled individually by each user's auth provider
    // No need to update all users' tokens from splash screen

    if (mounted) {
      logDebug('Splash screen navigation check:');
      logDebug('- isLoggedIn: ${authProvider.isLoggedIn}');
      logDebug('- isAdmin: ${authProvider.isAdmin}');
      logDebug('- user: ${authProvider.user?.uid}');
      logDebug('- userModel: ${authProvider.userModel?.name}');

      if (authProvider.isLoggedIn && authProvider.userModel != null) {
        // User is logged in and user data is loaded
        logDebug('Navigating to dashboard - isAdmin: ${authProvider.isAdmin}');

        // Check security settings
        final securityProvider = Provider.of<SecurityProvider>(
          context,
          listen: false,
        );
        await securityProvider.initializeSecurity(authProvider.userModel!.id);

        // Check if app unlock PIN exists (mandatory)
        final hasPin = await securityProvider.hasAppUnlockPIN(
          authProvider.userModel!.id,
        );

        final targetScreen = (authProvider.isAdmin || authProvider.userModel?.isSubAdmin == true)
            ? const AdminDashboardScreen()
            : const UserDashboardScreen();

        if (!hasPin) {
          // PIN not set - show setup screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => AppUnlockPinSetupScreen(isFirstTime: true),
            ),
          );
        } else {
          // PIN exists - show unlock screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => AppUnlockScreen(child: targetScreen),
            ),
          );
        }
      } else {
        // User is not logged in or user data not loaded, navigate to login screen
        logDebug(
          'User not logged in or data not loaded, navigating to login screen',
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } else {
      logDebug('Splash screen widget not mounted, skipping navigation');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo.shade700, Colors.indigo.shade400],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // App Logo
                Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    size: 80.r,
                    color: Colors.indigo,
                  ),
                ),
                SizedBox(height: 30.h),
                // App Name
                Center(
                  child: Text(
                    'Attendance Management',
                    style: getTextTheme().headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                SizedBox(height: 10.h),
                Text(
                  'Manage your leaves easily',
                  style: getTextTheme().bodyLarge?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                SizedBox(height: 40.h),
                // Loading indicator
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
