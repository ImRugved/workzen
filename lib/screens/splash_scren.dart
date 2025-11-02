import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

import 'admin/dashboard/admin_dashboard_screen.dart';
import 'auth/login_screen.dart';
import 'user/dashboard/user_dashboard_screen.dart';

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
      log('Splash screen navigation check:');
      log('- isLoggedIn: ${authProvider.isLoggedIn}');
      log('- isAdmin: ${authProvider.isAdmin}');
      log('- user: ${authProvider.user?.uid}');
      log('- userModel: ${authProvider.userModel?.name}');

      if (authProvider.isLoggedIn && authProvider.userModel != null) {
        // User is logged in and user data is loaded, navigate to appropriate dashboard
        log('Navigating to dashboard - isAdmin: ${authProvider.isAdmin}');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => authProvider.isAdmin
                ? const AdminDashboardScreen()
                : const UserDashboardScreen(),
          ),
        );
      } else {
        // User is not logged in or user data not loaded, navigate to login screen
        log(
          'User not logged in or data not loaded, navigating to login screen',
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } else {
      log('Splash screen widget not mounted, skipping navigation');
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
                  padding: const EdgeInsets.all(20),
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
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    size: 80,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 30),
                // App Name
                Center(
                  child: Text(
                    'Attendance Management',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                const Text(
                  'Manage your leaves easily',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 40),
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
